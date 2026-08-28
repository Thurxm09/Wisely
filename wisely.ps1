# ============================================================
#  Wisely v2.0 - Thuram Dev Setup
# ============================================================
#
#  USAGE
#  -----
#  .\wisely.ps1                    -> menu interactif
#  .\wisely.ps1 web                -> switch direct
#  .\wisely.ps1 data -DryRun       -> simulation sans ecriture
#  .\wisely.ps1 data -Force        -> switch sans confirmation (sessions WSL2 actives ignorees)
#  .\wisely.ps1 -Rollback          -> restauration backup
#  .\wisely.ps1 -History           -> voir l'historique
#  .\wisely.ps1 -NewProfile "perf 8GB 4 Description"
#  .\wisely.ps1 -Export            -> exporter profils
#  .\wisely.ps1 -Import path.json  -> importer profils
#  .\wisely.ps1 -Watch             -> dashboard temps reel (Ctrl+C pour quitter)
#  .\wisely.ps1 -Consent grant     -> autoriser la lecture in-distro (desactivee par defaut)
#  .\wisely.ps1 -Consent status    -> voir l'etat du consentement
#  .\wisely.ps1 -GuestInfo         -> memoire in-distro (MemAvailable / Cached)
#
# ============================================================

#Requires -Version 5.1

param(
    [string]$Profil     = "",
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Rollback,
    [switch]$History,
    [switch]$Export,
    [string]$Import     = "",
    [string]$NewProfile = "",
    [string]$Monitor    = "",
    [switch]$Report,
    [switch]$Clean,
    [switch]$Status,
    [switch]$Short,
    [switch]$Snapshot,
    [switch]$Watch,
    [int]$Interval     = 3,
    [switch]$Version,
    [switch]$Verbose,
    [switch]$Quiet,
    [string]$Consent    = "",
    [switch]$GuestInfo,
    [string]$Distro     = ""
)
# Note : $Verbose/$Quiet sont des switches "maison", pas le parametre commun
# -Verbose de [CmdletBinding()]. Ce script reste volontairement une fonction
# "basic" (aucun [Parameter()] dans ce bloc) : ajouter [CmdletBinding()] ici
# rendrait -Verbose reserve par PowerShell et casserait cette declaration.

# ---- Bootstrap ------------------------------------------------------

$Global:WSLRoot = $PSScriptRoot

. (Join-Path $PSScriptRoot "modules\ProfileManager.ps1")
. (Join-Path $PSScriptRoot "modules\Logger.ps1")
. (Join-Path $PSScriptRoot "modules\Monitor.ps1")
. (Join-Path $PSScriptRoot "modules\GuestReader.ps1")

# ---- Mode silencieux (-Quiet) ----------------------------------------
# Redefinit Write-Host pour ne laisser passer que les messages d'erreur
# (convention du projet : -ForegroundColor Red == erreur, verifie sur tous
# les appels Write-Host existants des 4 fichiers .ps1). Aucune modification
# des appels Write-Host existants n'est necessaire : ce shadow est defini
# avant que la moindre fonction dot-sourcee ne s'execute reellement.
# L'historique JSON (Write-SwitchLog) n'est jamais concerne : il ecrit via
# Set-Content, pas Write-Host, donc reste trace meme en mode silencieux.

$script:QuietMode = $Quiet.IsPresent

function Write-Host {
    # Pas de ValueFromPipeline : aucun appel Write-Host du projet n'utilise
    # le pipeline (verifie), et l'accepter sans bloc process serait de toute
    # facon incorrect (PSUseProcessBlockForPipelineCommand).
    param(
        [Parameter(Position = 0)][object]$Object,
        [switch]$NoNewline,
        [System.ConsoleColor]$ForegroundColor,
        [System.ConsoleColor]$BackgroundColor
    )
    if ($script:QuietMode -and $ForegroundColor -ne "Red") { return }
    $params = @{}
    if ($PSBoundParameters.ContainsKey('Object'))         { $params.Object = $Object }
    if ($NoNewline)                                       { $params.NoNewline = $true }
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $params.ForegroundColor = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $params.BackgroundColor = $BackgroundColor }
    Microsoft.PowerShell.Utility\Write-Host @params
}

$dataDir = Join-Path $PSScriptRoot "data"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }

function Get-AppVersion {
    $versionFile = Join-Path $PSScriptRoot "VERSION"
    if (Test-Path $versionFile) { return (Get-Content $versionFile -Raw).Trim() }
    return "2.1.0"
}

$Global:AppVersion = Get-AppVersion

# ---- Caracteres Unicode exprimes via [char] -------------------------
# Aucun octet non-ASCII dans ce fichier source.
# Le terminal affiche les vrais glyphes ; le fichier reste ASCII pur.
#
# U+2551 : double vertical bar  ||
# U+2550 : double horizontal    ==
# U+2554 : top-left corner      [=
# U+2557 : top-right corner     =]
# U+255A : bottom-left corner   [=
# U+255D : bottom-right corner  =]
# U+2560 : left tee             |=
# U+2563 : right tee            =|
# U+2588 : full block           ##
# U+2591 : light shade          ::

$C_VERT   = [char]0x2551   # ||
$C_HORIZ  = [char]0x2550   # ==
$C_TL     = [char]0x2554   # top-left
$C_TR     = [char]0x2557   # top-right
$C_BL     = [char]0x255A   # bottom-left
$C_BR     = [char]0x255D   # bottom-right
$C_LT     = [char]0x2560   # left tee
$C_RT     = [char]0x2563   # right tee
$C_FULL   = [char]0x2588   # full block
$C_LIGHT  = [char]0x2591   # light shade
$C_DASH   = [char]0x2500   # thin horizontal dash

# Largeur interieure de la boite : 47 chars (nombre de == dans le header)
$BOX_W = 47

# Lignes de structure precalculees
$LINE_TOP = "  " + $C_TL + ([string]$C_HORIZ * $BOX_W) + $C_TR
$LINE_MID = "  " + $C_LT + ([string]$C_HORIZ * $BOX_W) + $C_RT
$LINE_BOT = "  " + $C_BL + ([string]$C_HORIZ * $BOX_W) + $C_BR
$LINE_SEP = "  " + $C_VERT + ([string]$C_DASH  * $BOX_W) + $C_VERT

# Constantes de layout pour les lignes de contenu
# Structure : "  " + $C_VERT + cursor(4) + content(43) + $C_VERT
# Total ligne : 2 + 1 + 4 + 43 + 1 = 51 == longueur de $LINE_TOP
$CURSOR_W  = 4
$CONTENT_W = $BOX_W - $CURSOR_W   # 43
$LABEL_W   = 14
$DESC_W    = 22
$MEM_W     = $CONTENT_W - $LABEL_W - $DESC_W   # 7

# ---- Utilitaires display --------------------------------------------

function Format-String {
    param([string]$s, [int]$n)
    if ($s.Length -gt $n) { return $s.Substring(0, $n) }
    return $s.PadRight($n)
}

function New-BoxLine {
    # Construit une ligne encadree : "  || cursor content ||"
    # Une seule string, un seul Write-Host => alignement garanti
    param([string]$cursor, [string]$content)
    return "  " + $C_VERT + $cursor + (Format-String $content $CONTENT_W) + $C_VERT
}

function Get-RamInfo {
    # Resiliente comme Get-VmmemStats (modules/) : $null
    # en cas d'echec plutot qu'un crash de tout wisely.ps1 sur le chemin
    # par defaut (menu interactif) si Get-CimInstance echoue (voir AUDIT.md).
    try {
        $os    = Get-CimInstance Win32_OperatingSystem
        $total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $free  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $used  = [math]::Round($total - $free, 1)
        $pct   = [math]::Round($used / $total * 100, 0)
        return [PSCustomObject]@{ total = $total; used = $used; pct = $pct }
    } catch {
        return $null
    }
}

function Get-RamBar {
    param([int]$Pct)
    $filled = [math]::Round($Pct / 10)
    $empty  = 10 - $filled
    return ([string]$C_FULL * $filled) + ([string]$C_LIGHT * $empty)
}

function Get-RamLine {
    <#
    .SYNOPSIS
        Construit la ligne RAM (barre + stats, ou message "indisponible")
        partagee par Show-Header et Show-StatusDashboard - un seul point
        de calcul de largeur pour ne pas reintroduire le bug de
        troncature deja corrige une fois (largeur calculee dynamiquement
        a partir du prefixe/de la barre reels, voir AUDIT.md).
    #>
    param([string]$Prefix = "  RAM  ")
    $ram = Get-RamInfo
    if ($null -eq $ram) {
        return [PSCustomObject]@{ content = $Prefix + "indisponible"; color = "DarkGray" }
    }
    $bar     = Get-RamBar -Pct $ram.pct
    $color   = if ($ram.pct -ge 80) { "Red" } elseif ($ram.pct -ge 60) { "Yellow" } else { "Green" }
    $stats   = " " + $ram.pct + "%  (" + $ram.used + "/" + $ram.total + " GB)"
    $content = $Prefix + $bar + (Format-String $stats ($CONTENT_W - $Prefix.Length - $bar.Length))
    return [PSCustomObject]@{ content = $content; color = $color }
}

function Show-StatusDashboard {
    $config  = Get-ProfileConfig
    $active  = Get-ActiveProfile -Config $config
    $ramLine = Get-RamLine

    # Statut monitoring
    $monTask  = Get-ScheduledTask -TaskName "WSL2-RamMonitor" -ErrorAction SilentlyContinue
    $monState = if ($monTask) { "ACTIF ($($monTask.State))" } else { "INACTIF" }
    $monColor = if ($monTask) { "Green" } else { "DarkGray" }

    # Derniere alerte
    $cooldown  = Join-Path $Global:WSLRoot "data\monitor_cooldown.txt"
    $lastAlert = if (Test-Path $cooldown) { (Get-Content $cooldown -Raw).Trim() } else { "Aucune" }

    # Historique (3 derniers switchs)
    $histPath = Join-Path $Global:WSLRoot "data\history.json"
    $lastSwitches = @()
    if (Test-Path $histPath) {
        $history = Get-Content $histPath -Raw | ConvertFrom-Json
        $lastSwitches = @($history) | Where-Object { $_.action -eq "SWITCH" } | Select-Object -Last 3
    }

    Clear-Host
    Write-Host ""
    Write-Host $LINE_TOP -ForegroundColor Cyan
    Write-Host (New-BoxLine "    " "   Wisely  v$($Global:AppVersion) -- Status") -ForegroundColor Cyan
    Write-Host $LINE_MID -ForegroundColor Cyan
    Write-Host (New-BoxLine "    " $ramLine.content) -ForegroundColor $ramLine.color
    Write-Host $LINE_SEP -ForegroundColor DarkGray
    Write-Host (New-BoxLine "    " "  Profil actif : $($active.name)") -ForegroundColor White
    Write-Host (New-BoxLine "    " "  RAM allouee  : $($active.memory)") -ForegroundColor Gray
    Write-Host (New-BoxLine "    " "  CPU alloues  : $($active.processors)") -ForegroundColor Gray
    Write-Host $LINE_SEP -ForegroundColor DarkGray
    Write-Host (New-BoxLine "    " "  Monitoring   : $monState") -ForegroundColor $monColor
    Write-Host (New-BoxLine "    " "  Derniere alerte : $lastAlert") -ForegroundColor Gray
    Write-Host $LINE_SEP -ForegroundColor DarkGray
    Write-Host (New-BoxLine "    " "  Historique (3 derniers switchs)") -ForegroundColor DarkGray
    if ($lastSwitches.Count -eq 0) {
        Write-Host (New-BoxLine "    " "  Aucun switch enregistre") -ForegroundColor DarkGray
    } else {
        foreach ($s in $lastSwitches) {
            $line = "  $($s.timestamp)  $($s.profile.PadRight(10)) $($s.details)"
            Write-Host (New-BoxLine "    " $line) -ForegroundColor Gray
        }
    }
    Write-Host $LINE_BOT -ForegroundColor Cyan
    Write-Host ""
}

function Show-WslWatch {
    <#
    .SYNOPSIS
        Dashboard temps reel : RAM/CPU vmmem, profil actif, derniere
        alerte, rafraichi toutes les -Interval secondes jusqu'a Ctrl+C.
        Axe 6 (Observabilite), v2.3. La collecte des donnees (testable)
        vit dans Get-WatchSnapshot (modules/Monitor.ps1) ; cette fonction
        ne fait que boucler et afficher, comme Show-StatusDashboard.
    #>
    param([int]$IntervalSeconds = 3)

    while ($true) {
        $snap = Get-WatchSnapshot

        Clear-Host
        Write-Host ""
        Write-Host $LINE_TOP -ForegroundColor Cyan
        Write-Host (New-BoxLine "    " "   Wisely  v$($Global:AppVersion) -- Watch") -ForegroundColor Cyan
        Write-Host $LINE_MID -ForegroundColor Cyan

        if ($null -ne $snap.vmmemRamGB) {
            $vmmemColor = if ($snap.vmmemCpuPct -ge 80) { "Red" } elseif ($snap.vmmemCpuPct -ge 40) { "Yellow" } else { "Green" }
            Write-Host (New-BoxLine "    " "  RAM vmmem   : $($snap.vmmemRamGB) GB") -ForegroundColor $vmmemColor
            Write-Host (New-BoxLine "    " "  CPU vmmem   : $($snap.vmmemCpuPct)%") -ForegroundColor $vmmemColor
        } else {
            Write-Host (New-BoxLine "    " "  vmmem       : introuvable (WSL2 inactif ?)") -ForegroundColor DarkGray
        }
        Write-Host $LINE_SEP -ForegroundColor DarkGray
        Write-Host (New-BoxLine "    " "  Profil actif : $($snap.activeProfile) ($($snap.activeMemory))") -ForegroundColor White
        Write-Host $LINE_SEP -ForegroundColor DarkGray
        Write-Host (New-BoxLine "    " "  Derniere alerte : $($snap.lastAlert)") -ForegroundColor Gray
        Write-Host $LINE_BOT -ForegroundColor Cyan
        Write-Host "  Rafraichi toutes les ${IntervalSeconds}s - Ctrl+C pour quitter" -ForegroundColor DarkGray
        Write-Host ""

        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Show-Header {
    param([string]$ActiveName = "?", [string]$ActiveMem = "?")

    $ramLine = Get-RamLine

    Clear-Host
    Write-Host ""
    Write-Host $LINE_TOP -ForegroundColor Cyan
    Write-Host (New-BoxLine "    " "   Wisely  v$($Global:AppVersion)   ") -ForegroundColor Cyan
    Write-Host $LINE_MID -ForegroundColor Cyan

    Write-Host (New-BoxLine "    " $ramLine.content) -ForegroundColor $ramLine.color

    # Ligne profil actif
    $profileStr = "  Profil actif : " + $ActiveName + " (" + $ActiveMem + ")"
    Write-Host (New-BoxLine "    " $profileStr) -ForegroundColor White

    Write-Host $LINE_MID -ForegroundColor Cyan
}

# ---- Menu interactif ------------------------------------------------

function Show-InteractiveMenu {

    $config      = Get-ProfileConfig
    $active      = Get-ActiveProfile -Config $config
    $profileKeys = $config.profiles.PSObject.Properties.Name

    $menuItems = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($key in $profileKeys) {
        $p = $config.profiles.$key
        $menuItems.Add([PSCustomObject]@{
            type        = "profile"
            key         = $key
            label       = $p.displayName
            description = $p.description
            memory      = $p.memory
            color       = $p.color
            isActive    = ($key -eq $active.key)
        })
    }

    $menuItems.Add([PSCustomObject]@{ type="separator"; key=""; label=""; description=""; memory=""; color="DarkGray"; isActive=$false })
    $menuItems.Add([PSCustomObject]@{ type="action"; key="history";  label="Historique"; description=""; memory=""; color="Gray";       isActive=$false })
    $menuItems.Add([PSCustomObject]@{ type="action"; key="rollback"; label="Rollback";   description=""; memory=""; color="DarkYellow"; isActive=$false })
    $menuItems.Add([PSCustomObject]@{ type="action"; key="quit";     label="Quitter";    description=""; memory=""; color="DarkGray";   isActive=$false })

    # [int[]] explicite pour eviter le bug de cast PS sur tableau scalaire
    [int[]]$selectableIdx = @(
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            if ($menuItems[$i].type -ne "separator") { $i }
        }
    )
    [int]$pos = 0

    do {
        [int]$currentIdx = $selectableIdx[$pos]
        Show-Header -ActiveName $active.name -ActiveMem $active.memory

        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            $item       = $menuItems[$i]
            $isSelected = ($i -eq $currentIdx)

            if ($item.type -eq "separator") {
                Write-Host $LINE_SEP -ForegroundColor DarkGray
                continue
            }

            $cursor = if ($isSelected) { "  > " } else { "    " }

            if ($item.type -eq "profile") {
                $memRaw  = if ($item.memory)   { "(" + $item.memory + ")" } else { "" }
                $mark    = if ($item.isActive) { "[v]" } else { "" }

                $label   = Format-String $item.label         $LABEL_W
                $desc    = Format-String $item.description   $DESC_W
                $mem     = Format-String ($memRaw + $mark)   $MEM_W
                $content = $label + $desc + $mem

                $color = if ($isSelected) { "Yellow" } else { $item.color }
                Write-Host (New-BoxLine $cursor $content) -ForegroundColor $color
            }
            else {
                $content = Format-String $item.label $CONTENT_W
                $color   = if ($isSelected) { "Yellow" } else { $item.color }
                Write-Host (New-BoxLine $cursor $content) -ForegroundColor $color
            }
        }

        Write-Host $LINE_BOT -ForegroundColor Cyan
        Write-Host "    haut/bas Naviguer   Entree Selectionner   Q Quitter" -ForegroundColor DarkGray
        Write-Host ""

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            "UpArrow"   { if ($pos -gt 0)                        { $pos-- } }
            "DownArrow" { if ($pos -lt $selectableIdx.Count - 1) { $pos++ } }
            "Enter"     { return $menuItems[$currentIdx].key }
            "Q"         { return "quit" }
            "Escape"    { return "quit" }
        }

    } while ($true)
}

# ---- Lecture in-distro (P1/v2.6) -------------------------------------

function Show-GuestReadConsentStatus {
    <#
    .SYNOPSIS
        Affiche l'etat courant du consentement a la lecture in-distro
        et les commandes couvertes par la liste fermee.
    #>
    $state = Get-GuestReadConsentState
    $color = switch ($state) {
        "granted" { "Green" }
        "revoked" { "Yellow" }
        default   { "DarkGray" }
    }
    Write-Host ""
    Write-Host "  Consentement lecture in-distro : $state" -ForegroundColor $color
    if ($state -ne "granted") {
        Write-Host "  Pour activer : .\wisely.ps1 -Consent grant" -ForegroundColor DarkGray
    }
    Write-Host "  Commandes couvertes (liste fermee) : $((Get-GuestReadCommandKeys) -join ', ')" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-GuestMemInfo {
    <#
    .SYNOPSIS
        Affiche la memoire in-distro (MemAvailable = marge reelle,
        distinct de Cached = recuperable, pas de la consommation),
        docs/RESOURCE-MODEL.md SS4.3.
    #>
    param([string]$Distro = "")

    if ($Distro -eq "") {
        $activeSessions = Get-WslActiveSessions
        if ($activeSessions.Count -eq 0) {
            Write-Host "  Aucune distribution WSL2 active. Wisely ne demarre jamais une distribution arretee." -ForegroundColor Red
            return
        }
        if ($activeSessions.Count -gt 1) {
            Write-Host "  Plusieurs distributions actives : $($activeSessions -join ', ')" -ForegroundColor Red
            Write-Host "  Precise avec -Distro <nom>." -ForegroundColor DarkGray
            return
        }
        $Distro = $activeSessions[0]
    }

    $rawOutput = Invoke-GuestRead -CommandKey "MemInfo" -Distro $Distro
    $mem = ConvertFrom-MemInfo -RawOutput $rawOutput

    Write-Host ""
    Write-Host "  Memoire in-distro ($Distro)" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * 40)) -ForegroundColor DarkGray
    Write-Host "  MemTotal      : $($mem.MemTotalGB) GB" -ForegroundColor Gray
    Write-Host "  MemAvailable  : $($mem.MemAvailableGB) GB  (marge reelle)" -ForegroundColor Green
    Write-Host "  Cached        : $($mem.CachedGB) GB  (recuperable, pas de la consommation)" -ForegroundColor DarkGray
    Write-Host "  MemFree       : $($mem.MemFreeGB) GB" -ForegroundColor DarkGray
    Write-Host ""
}

# ---- Point d'entree -------------------------------------------------

if ($Status) {
    if ($Short) {
        Write-Output (Format-StatusShort -ActiveProfile (Get-ActiveProfile))
    } else {
        Show-StatusDashboard
    }
    exit
}

if ($Watch) {
    Show-WslWatch -IntervalSeconds $Interval
    exit
}

if ($Snapshot) {
    try {
        $key = New-SnapshotProfile
        Write-Host "  OK - Snapshot '$key' cree a partir du profil actif." -ForegroundColor Green
        Write-Host "  Pour y revenir : .\wisely.ps1 $key" -ForegroundColor DarkGray
    } catch {
        Write-Host "ERREUR : $_" -ForegroundColor Red
        exit 1
    }
    exit
}

if ($Version) {
    Write-Host "Wisely v$($Global:AppVersion)" -ForegroundColor Cyan
    exit
}

if ($Monitor -ne "") {
    switch ($Monitor.ToLower()) {
        "start"  { Start-WslMonitor; exit }
        "stop"   { Stop-WslMonitor;  exit }
        "status" { Get-MonitorStatus; exit }
        default  { Write-Host "Usage : -Monitor start|stop|status" -ForegroundColor Red; exit 1 }
    }
}
if ($Consent -ne "") {
    switch ($Consent.ToLower()) {
        "grant"  { Set-GuestReadConsentState -State "granted"; Show-GuestReadConsentStatus; exit }
        "revoke" { Set-GuestReadConsentState -State "revoked"; Show-GuestReadConsentStatus; exit }
        "status" { Show-GuestReadConsentStatus; exit }
        default  { Write-Host "Usage : -Consent grant|revoke|status" -ForegroundColor Red; exit 1 }
    }
}
if ($GuestInfo) {
    try   { Show-GuestMemInfo -Distro $Distro }
    catch { Write-Host "ERREUR : $_" -ForegroundColor Red; exit 1 }
    exit
}
if ($Clean) {
    $reportsDir  = Join-Path $PSScriptRoot "data\reports"
    $cooldown    = Join-Path $PSScriptRoot "data\monitor_cooldown.txt"
    $errors      = Join-Path $PSScriptRoot "data\monitor_errors.txt"
    $cleaned     = 0
    if (Test-Path $reportsDir) {
        $all = Get-ChildItem $reportsDir -Filter "report_*.txt" | Sort-Object Name
        if ($all.Count -gt 12) {
            $toDelete = $all | Select-Object -First ($all.Count - 12)
            $toDelete | Remove-Item -Force
            $cleaned += $toDelete.Count
            Write-Host "  Rapports supprimes : $($toDelete.Count)" -ForegroundColor Gray
        } else {
            Write-Host "  Rapports : rien a purger ($($all.Count)/12)" -ForegroundColor DarkGray
        }
    }
    foreach ($tmp in @($cooldown, $errors)) {
        if (Test-Path $tmp) {
            Remove-Item $tmp -Force
            Write-Host "  Supprime : $(Split-Path $tmp -Leaf)" -ForegroundColor Gray
            $cleaned++
        }
    }
    Write-Host ""
    if ($cleaned -eq 0) { Write-Host "  Rien a nettoyer." -ForegroundColor DarkGray }
    else { Write-Host "  Nettoyage termine ($cleaned element(s) supprimes)." -ForegroundColor Green }
    Write-Host ""
    exit
}
if ($Report)  { & (Join-Path $PSScriptRoot "modules\WeeklyReport.ps1"); exit }
if ($Rollback) { Invoke-Rollback; exit }
if ($History)  { Show-SwitchHistory; exit }
if ($Export)   { Export-Profiles; exit }

if ($Import -ne "") {
    try   { Import-Profiles -Path $Import }
    catch { Write-Host "ERREUR : $_" -ForegroundColor Red; exit 1 }
    exit
}

if ($NewProfile -ne "") {
    $parts = $NewProfile -split "\s+"
    if ($parts.Count -lt 3) {
        Write-Host "Usage : -NewProfile 'nomCle XGBRAM NbCPU [description]'" -ForegroundColor Red
        exit 1
    }
    if ($parts[0] -notmatch "^[a-zA-Z][a-zA-Z0-9_-]*$") {
        Write-Host "  ERREUR : La cle de profil doit etre un identifiant alphanumerique (ex: gaming, ml-heavy)." -ForegroundColor Red
        exit 1
    }
    $desc = if ($parts.Count -ge 4) { $parts[3..($parts.Count-1)] -join " " } else { "Profil personnalise" }
    try   { New-CustomProfile -Key $parts[0] -Memory $parts[1] -Processors ([int]$parts[2]) -Description $desc }
    catch { Write-Host "ERREUR : $_" -ForegroundColor Red; exit 1 }
    exit
}

if ($Profil -ne "") {
    try   { Set-WslProfile -Key $Profil.ToLower() -DryRun:$DryRun -ShowDiff:$Verbose -Force:$Force }
    catch { Write-Host "ERREUR : $_" -ForegroundColor Red; exit 1 }
    exit
}

if ($script:QuietMode) {
    # -Quiet sans flag d'action mene au menu interactif : le desactiver
    # plutot que de rendre le menu inutilisable (rien ne s'afficherait).
    $script:QuietMode = $false
    Microsoft.PowerShell.Utility\Write-Host "  '-Quiet' est ignore en mode menu interactif." -ForegroundColor DarkGray
}

# Mode par defaut : menu interactif
do {
    $choice = Show-InteractiveMenu

    switch ($choice) {
        "quit" {
            Clear-Host
            exit
        }
        "history" {
            Show-SwitchHistory
            Write-Host "  Appuyez sur Entree pour continuer..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "rollback" {
            Invoke-Rollback
            Write-Host "  Appuyez sur Entree pour continuer..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        default {
            if ($choice -ne "") {
                try {
                    Set-WslProfile -Key $choice -ShowDiff:$Verbose -Force:$Force
                    Write-Host "  Appuyez sur Entree pour continuer..." -ForegroundColor DarkGray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                catch {
                    Write-Host ""
                    Write-Host "  ERREUR : $_" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "  Appuyez sur Entree pour continuer..." -ForegroundColor DarkGray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
        }
    }

} while ($true)
