# ============================================================
#  GuestReader.ps1 - Lecture in-distro sous contrat (P1/v2.6)
#  Dot-source depuis wisely.ps1
#  Utilise $Global:WSLRoot defini dans le script principal
#
#  Liste fermee, consentement explicite, degradation propre.
#  Contrat : docs/DOCTRINE-LECTURE.md, docs/RESOURCE-MODEL.md,
#  decisions/0008-lecture-in-distro.md
# ============================================================

# ---- Liste fermee de commandes invite --------------------------------
# Identique terme a terme a docs/DOCTRINE-LECTURE.md SS2.3 et
# docs/RESOURCE-MODEL.md SS8. Invoke-GuestProcess est le seul primitif
# capable de lancer "wsl", et Invoke-GuestRead est le seul appelant
# autorise a l'utiliser avec "wsl" - aucun autre site d'appel ne peut
# atteindre "wsl" avec une chaine hors des cles ci-dessous.

$script:GuestReadCommands = [ordered]@{
    "MemInfo"  = @{ Scope = "distro";  Class = "directe";   Args = @("cat", "/proc/meminfo") }
    "LoadAvg"  = @{ Scope = "distro";  Class = "directe";   Args = @("cat", "/proc/loadavg") }
    "Uptime"   = @{ Scope = "distro";  Class = "directe";   Args = @("cat", "/proc/uptime") }
    "DiskRoot" = @{ Scope = "distro";  Class = "directe";   Args = @("df", "-P", "/") }
    "Nproc"    = @{ Scope = "distro";  Class = "directe";   Args = @("nproc") }
    "ProcRss"  = @{ Scope = "process"; Class = "attribuee"; Args = @("ps", "-eo", "rss,comm", "--sort=-rss") }
}

$script:GuestReadTimeoutMs = 5000

function Get-GuestReadCommandKeys {
    <#
    .SYNOPSIS
        Expose les cles de la liste fermee de commandes invite, pour
        affichage (-Consent status) et tests (derive doc/code).
    #>
    return @($script:GuestReadCommands.Keys)
}

# ---- Consentement : desactive par defaut, revocable ------------------
# Stockage a deux etats sur disque ("granted"/"revoked"), trois etats en
# comportement : la cle absente du JSON se lit comme "unset" (jamais
# demande). C'est ce qui rend le defaut desactive sans toucher au
# data/profiles.json livre ni au schema (additionalProperties: false).

function Get-GuestReadConsentState {
    <#
    .SYNOPSIS
        Retourne l'etat de consentement a la lecture invite :
        "unset" (jamais demande), "granted" ou "revoked".
    #>
    $config = Get-ProfileConfig
    if ($null -eq $config.settings) { return "unset" }
    $value = $config.settings.guestReadConsent
    if ([string]::IsNullOrEmpty($value)) { return "unset" }
    return $value
}

function Set-GuestReadConsentState {
    <#
    .SYNOPSIS
        Accorde ou revoque le consentement a la lecture invite.
    .PARAMETER State
        "granted" ou "revoked".
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("granted", "revoked")]
        [string]$State
    )
    $config = Get-ProfileConfig
    if ($null -eq $config.settings) {
        $config | Add-Member -MemberType NoteProperty -Name "settings" -Value ([PSCustomObject]@{}) -Force
    }
    $config.settings | Add-Member -MemberType NoteProperty -Name "guestReadConsent" -Value $State -Force
    $config | ConvertTo-Json -Depth 10 | Set-Content (Get-ProfilesPath) -Encoding UTF8
    Clear-ProfileConfigCache
    Write-SwitchLog -Action "CONSENT" -Details "guestReadConsent=$State"
}

# ---- Primitif isole : le seul point de lancement de processus --------

function Invoke-GuestProcess {
    <#
    .SYNOPSIS
        Lance un executable externe avec timeout explicite. Isole (comme
        Test-WiselyNonInteractive) pour rester mockable par Pester - un
        "wsl" natif ne peut pas etre encapsule avec timeout sans
        Start-Job (qui casserait la visibilite des Mock), et "wsl" est
        absent sur les runners CI (ubuntu-latest).
    .OUTPUTS
        Objet { Success; Output; Error; ExitCode; TimedOut } - jamais
        $null, jamais d'exception avalee.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutMs = $script:GuestReadTimeoutMs
    )

    $result = [PSCustomObject]@{
        Success  = $false
        Output   = ""
        Error    = ""
        ExitCode = $null
        TimedOut = $false
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $process = $null
    try {
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $psi
        $null = $process.Start()

        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if ($process.WaitForExit($TimeoutMs)) {
            $result.Output   = $stdoutTask.GetAwaiter().GetResult()
            $result.Error    = $stderrTask.GetAwaiter().GetResult()
            $result.ExitCode = $process.ExitCode
            $result.Success  = ($process.ExitCode -eq 0)
            if (-not $result.Success -and [string]::IsNullOrEmpty($result.Error)) {
                $result.Error = "Code de sortie non nul : $($result.ExitCode)"
            }
        } else {
            $result.TimedOut = $true
            $result.Error    = "Timeout apres ${TimeoutMs}ms."
            try { $process.Kill() } catch { Write-Verbose "Echec de l'arret force du processus en timeout (deja termine ?) : $_" }
        }
    } catch {
        $result.Error = "Echec du lancement de '$FilePath' : $_"
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }

    return $result
}

# ---- Orchestrateur : seul appelant de "wsl" ---------------------------

function Invoke-GuestRead {
    <#
    .SYNOPSIS
        Execute une commande de la liste fermee dans une distribution
        WSL2 deja demarree, sous consentement explicite. Seul appelant
        de Invoke-GuestProcess avec "wsl".
    .PARAMETER CommandKey
        Une des cles de $script:GuestReadCommands.
    .PARAMETER Distro
        Nom exact d'une distribution retournee par Get-WslActiveSessions.
        Jamais interpole depuis une autre source, jamais demarree
        implicitement si arretee.
    #>
    param(
        [Parameter(Mandatory)][string]$CommandKey,
        [Parameter(Mandatory)][string]$Distro
    )

    if (-not $script:GuestReadCommands.Contains($CommandKey)) {
        $validKeys = (Get-GuestReadCommandKeys) -join ", "
        throw "Commande invite inconnue : '$CommandKey'. Cles valides : $validKeys"
    }

    $consent = Get-GuestReadConsentState
    if ($consent -ne "granted") {
        throw "Lecture invite refusee (consentement : $consent). Active-la avec : wisely -Consent grant"
    }

    $activeSessions = Get-WslActiveSessions
    if ($activeSessions.Count -eq 0) {
        throw "Aucune distribution WSL2 active. Wisely ne demarre jamais une distribution arretee."
    }
    if ($Distro -notin $activeSessions) {
        $activeList = $activeSessions -join ", "
        throw "Distribution '$Distro' non active. Distributions actives : $activeList"
    }

    $commandArgs = $script:GuestReadCommands[$CommandKey].Args
    $wslArgs = @("-d", $Distro, "--") + $commandArgs

    $result = Invoke-GuestProcess -FilePath "wsl" -ArgumentList $wslArgs

    if (-not $result.Success) {
        $reason = if ($result.TimedOut) { "timeout" } else { $result.Error }
        throw "Lecture invite '$CommandKey' sur '$Distro' a echoue : $reason"
    }

    return $result.Output
}

# ---- Interpretation : /proc/meminfo -----------------------------------

function ConvertFrom-MemInfo {
    <#
    .SYNOPSIS
        Parse la sortie de "cat /proc/meminfo" (cles en kB) vers des
        valeurs en Go. Distingue MemAvailable (marge reelle) de Cached
        (recuperable, pas de la consommation) - docs/RESOURCE-MODEL.md SS4.3.
        Leve une erreur explicite si un champ requis manque - jamais de
        valeur inventee en repli.
    #>
    param(
        [Parameter(Mandatory)][string]$RawOutput
    )

    $fields = @{}
    foreach ($line in ($RawOutput -split "`n")) {
        if ($line -match '^(\w+):\s+(\d+)\s*kB') {
            $fields[$matches[1]] = [double]$matches[2]
        }
    }

    $requiredFields = @("MemTotal", "MemFree", "MemAvailable", "Cached")
    foreach ($field in $requiredFields) {
        if (-not $fields.ContainsKey($field)) {
            throw "Champ requis absent de /proc/meminfo : '$field'."
        }
    }

    $buffers = if ($fields.ContainsKey("Buffers")) { $fields["Buffers"] } else { 0 }

    return [PSCustomObject]@{
        MemTotalGB     = [math]::Round($fields["MemTotal"] / 1MB, 2)
        MemFreeGB      = [math]::Round($fields["MemFree"] / 1MB, 2)
        MemAvailableGB = [math]::Round($fields["MemAvailable"] / 1MB, 2)
        CachedGB       = [math]::Round(($fields["Cached"] + $buffers) / 1MB, 2)
    }
}
