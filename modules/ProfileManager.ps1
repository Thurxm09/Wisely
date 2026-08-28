# ============================================================
#  ProfileManager.ps1 - Gestion des profils WSL2
#  Dot-source depuis wisely.ps1
#  Utilise $Global:WSLRoot defini dans le script principal
# ============================================================

function Get-ProfilesPath  { Join-Path $Global:WSLRoot "data\profiles.json" }
function Get-BackupDir     { Join-Path $Global:WSLRoot "data\backups" }
function Get-WslConfigPath { Join-Path $env:USERPROFILE ".wslconfig" }

# Ancien emplacement (backup unique, pre-v2.1) - conserve uniquement pour
# la migration transparente vers l'historique glissant dans Backup-WslConfig.
function Get-LegacyBackupPath { Join-Path $Global:WSLRoot "data\wslconfig.backup" }

# ---- Lecture de la configuration ------------------------------------
# Memoisation : Get-ProfileConfig est appelee tres frequemment (menu,
# status, switch...) pour un fichier qui ne change qu'a l'ecriture. Le
# cache vit pour la duree du processus wisely.ps1 (pas de TTL necessaire)
# et est invalide explicitement via Clear-ProfileConfigCache partout ou
# profiles.json est reecrit.

$script:ProfileConfigCache = $null

function Get-ProfileConfig {
    if ($null -ne $script:ProfileConfigCache) {
        return $script:ProfileConfigCache
    }
    $path = Get-ProfilesPath
    if (-not (Test-Path $path)) {
        throw "profiles.json introuvable. Chemin attendu : $path"
    }
    $raw = Get-Content $path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "profiles.json est vide. Chemin : $path"
    }
    try {
        $parsed = $raw | ConvertFrom-Json
    } catch {
        throw "profiles.json est corrompu (JSON invalide). Detail : $_"
    }
    if ($null -eq $parsed.profiles) {
        throw "profiles.json incomplet - cle manquante : 'profiles'"
    }
    $script:ProfileConfigCache = $parsed
    return $script:ProfileConfigCache
}

function Clear-ProfileConfigCache {
    $script:ProfileConfigCache = $null
}

function Get-WiselyProfileMarker {
    <#
    .SYNOPSIS
        Lit la cle "profile=" dans la section [wisely] d'un .wslconfig
        (deja charge en lignes). C'est l'identite marquee du profil actif
        - voir PRINCIPLES.md principe 9 : ne jamais deviner une identite a
        partir d'une valeur qui peut coincider entre deux profils (ex:
        memoire identique). Retourne $null si la section ou la cle est
        absente (fichier non gere par Wisely, ou ecrit avant v2.5).
    #>
    param([string[]]$Lines)
    $sectionStart = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq "[wisely]") { $sectionStart = $i; break }
    }
    if ($sectionStart -eq -1) { return $null }
    for ($i = $sectionStart + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[.+\]\s*$') { break }
        if ($Lines[$i] -match '^\s*profile\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

function Get-ActiveProfile {
    param([PSCustomObject]$Config = $null)
    $wslConfig = Get-WslConfigPath
    if (-not (Test-Path $wslConfig)) {
        return [PSCustomObject]@{ name = "Non configure"; key = ""; memory = "N/A"; processors = "?" }
    }
    $lines = Get-Content $wslConfig -Encoding UTF8
    $mem   = ($lines | Where-Object { $_ -match "^memory=" }     | Select-Object -First 1) -replace "memory=", ""
    $cpu   = ($lines | Where-Object { $_ -match "^processors=" } | Select-Object -First 1) -replace "processors=", ""

    $markedKey = Get-WiselyProfileMarker -Lines $lines
    if (-not $markedKey) {
        return [PSCustomObject]@{ name = "Personnalise"; key = "custom"; memory = $mem; processors = $cpu }
    }

    try {
        $cfg     = if ($null -ne $Config) { $Config } else { Get-ProfileConfig }
        $matched = $cfg.profiles.PSObject.Properties |
                   Where-Object { $_.Name -eq $markedKey } |
                   Select-Object -First 1
        return [PSCustomObject]@{
            name       = if ($matched) { $matched.Value.displayName } else { "Modifie (profil '$markedKey' introuvable)" }
            key        = if ($matched) { $matched.Name } else { "custom" }
            memory     = $mem
            processors = $cpu
        }
    } catch {
        return [PSCustomObject]@{ name = "?"; key = ""; memory = $mem; processors = $cpu }
    }
}

function Format-StatusShort {
    param([Parameter(Mandatory)][PSCustomObject]$ActiveProfile)
    return "[WSL:$($ActiveProfile.name) $($ActiveProfile.memory)]"
}

# ---- Integrite & backup ---------------------------------------------

function Test-WslConfigIntegrity {
    $wslConfig = Get-WslConfigPath
    if (-not (Test-Path $wslConfig)) { return $false }
    $content  = Get-Content $wslConfig -Raw -Encoding UTF8
    $required = @("[wsl2]", "memory=", "processors=")
    foreach ($key in $required) {
        if ($content -notmatch [regex]::Escape($key)) {
            Write-Warning "Cle manquante dans .wslconfig : $key"
            return $false
        }
    }
    return $true
}

function Get-BackupHistoryMax {
    $default = 5
    try {
        $cfg = Get-ProfileConfig
        # Un $backupHistoryMax negatif ou nul rendrait la purge de
        # Backup-WslConfig destructrice (elle supprimerait TOUS les
        # backups, y compris le tout nouveau) - on retombe sur le defaut
        # plutot que d'accepter une valeur qui casse la reversibilite.
        if ($cfg.settings.backupHistoryMax -and [int]$cfg.settings.backupHistoryMax -gt 0) {
            return [int]$cfg.settings.backupHistoryMax
        }
        return $default
    } catch {
        return $default
    }
}

function Get-BackupEnabled {
    $default = $true
    try {
        $cfg = Get-ProfileConfig
        if ($null -ne $cfg.settings.backupEnabled) { return [bool]$cfg.settings.backupEnabled }
        return $default
    } catch {
        return $default
    }
}

function Backup-WslConfig {
    <#
    .SYNOPSIS
        Sauvegarde .wslconfig dans un historique glissant horodate
        (data/backups/wslconfig_<timestamp>.backup), purge au-dela de
        backupHistoryMax (defaut 5, configurable dans profiles.json).
    #>
    $src = Get-WslConfigPath
    if (-not (Test-Path $src)) { return }
    if (-not (Get-BackupEnabled)) { return }

    $dir = Get-BackupDir
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # Migration transparente : recupere l'ancien backup unique s'il existe
    # encore et que le nouvel historique est vide, pour ne pas perdre le
    # filet de securite deja en place chez un utilisateur existant. Suffixe
    # "_legacy" (pas juste l'horodatage) : evite toute collision de nom
    # avec le nouveau backup cree juste apres si les deux tombent dans la
    # meme seconde (horodatage a la seconde pres).
    $legacy = Get-LegacyBackupPath
    if ((Test-Path $legacy) -and (@(Get-ChildItem $dir -Filter "wslconfig_*.backup" -ErrorAction SilentlyContinue)).Count -eq 0) {
        $legacyStamp = (Get-Item $legacy).LastWriteTime.ToString("yyyyMMdd_HHmmss")
        Copy-Item $legacy (Join-Path $dir "wslconfig_${legacyStamp}_legacy.backup") -Force
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $src (Join-Path $dir "wslconfig_$stamp.backup") -Force

    $max = Get-BackupHistoryMax
    $all = Get-ChildItem $dir -Filter "wslconfig_*.backup" | Sort-Object Name
    if ($all.Count -gt $max) {
        # [math]::Max en defense en profondeur (au cas ou $max serait
        # neanmoins negatif un jour) : ne jamais purger plus que ce qui
        # depasse reellement la limite.
        $toRemove = [math]::Max(0, $all.Count - $max)
        if ($toRemove -gt 0) {
            $all | Select-Object -First $toRemove | Remove-Item -Force
        }
    }
}

function Get-LatestBackup {
    $dir = Get-BackupDir
    if (-not (Test-Path $dir)) { return $null }
    return Get-ChildItem $dir -Filter "wslconfig_*.backup" | Sort-Object Name | Select-Object -Last 1
}

function Invoke-Rollback {
    $latest = Get-LatestBackup
    if ($null -eq $latest) {
        Write-Host ""
        Write-Host "  Aucun backup disponible - rollback impossible." -ForegroundColor Red
        Write-Host ""
        return
    }
    Write-Host ""
    Write-Host "  Rollback en cours..." -ForegroundColor Yellow
    Write-Host "  Restauration depuis : $($latest.Name)" -ForegroundColor Gray
    Write-Host "  Arret de WSL2..." -ForegroundColor Gray
    wsl --shutdown
    Start-Sleep -Seconds 2
    Copy-Item $latest.FullName (Get-WslConfigPath) -Force
    Write-Host "  .wslconfig restaure." -ForegroundColor Green
    $restored = Get-ActiveProfile
    Write-Host "  Profil restaure : $($restored.name) ($($restored.memory) / $($restored.processors) CPU)" -ForegroundColor Cyan
    Write-Host ""
    Write-SwitchLog -Action "ROLLBACK" -ProfileKey $restored.key -Details "Restaure depuis $($latest.Name)"
}

# ---- Generation & application ---------------------------------------
# Note : swapFile utilise des slashes forward (C:/Temp/...)
# WSL2 et Windows acceptent les deux formats dans .wslconfig
# Cela evite le probleme d'echappement du backslash

function Resolve-ProfilePaths {
    <#
    .SYNOPSIS
        Etend les variables d'environnement (%TEMP%, %USERPROFILE%,
        %LOCALAPPDATA%) dans le swapFile d'un profil et normalise le
        resultat en forward slashes. Retourne une copie du profil - ne
        mute jamais l'original, pour ne pas corrompre le cache
        $script:ProfileConfigCache.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$ProfileDef)
    $copy = $ProfileDef | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $expanded = [System.Environment]::ExpandEnvironmentVariables($copy.swapFile)
    $copy.swapFile = $expanded -replace "\\", "/"
    return $copy
}

function Test-SwapFilePath {
    <#
    .SYNOPSIS
        Verifie que le repertoire cible d'un swapFile existe avant toute
        ecriture dans .wslconfig. Leve une exception explicite sinon
        (principe "failing fast et bruyant" du projet) plutot que de
        laisser WSL2 demarrer avec une erreur silencieuse de swap.
    #>
    param([Parameter(Mandatory)][string]$SwapFile)
    $dir = Split-Path $SwapFile -Parent
    if ([string]::IsNullOrWhiteSpace($dir)) {
        throw "Chemin de swapFile invalide : '$SwapFile'."
    }
    if (-not (Test-Path $dir)) {
        throw "Repertoire du swap file introuvable : $dir (swapFile : $SwapFile)."
    }
}

function Show-WslConfigDiff {
    <#
    .SYNOPSIS
        Affiche un diff ligne a ligne entre l'ancien et le nouveau contenu
        de .wslconfig (utilise par Set-WslProfile -ShowDiff).
    #>
    param([string]$Old = "", [string]$New = "")
    $oldLines = @($Old -split "`n" | Where-Object { $_ -ne "" })
    $newLines = @($New -split "`n" | Where-Object { $_ -ne "" })
    # DarkRed (pas Red) pour les lignes supprimees : Red est reserve aux
    # messages d'erreur (convention utilisee par le mode -Quiet pour savoir
    # quoi laisser passer), un diff n'est pas une erreur.
    Write-Host "  Diff .wslconfig :" -ForegroundColor DarkGray
    foreach ($line in $oldLines) {
        if ($newLines -notcontains $line) { Write-Host "    - $line" -ForegroundColor DarkRed }
    }
    foreach ($line in $newLines) {
        if ($oldLines -notcontains $line) { Write-Host "    + $line" -ForegroundColor Green }
    }
    Write-Host ""
}

function Set-IniSectionKeys {
    <#
    .SYNOPSIS
        Fusionne des cles key=value dans une section INI nommee, sans
        toucher au reste du contenu - c'est le mecanisme qui rend
        l'ecriture de .wslconfig non destructive (principe 8 : ne jamais
        detruire ce qu'on ne gere pas). Une cle geree deja presente est
        mise a jour en place (position preservee) ; une cle geree absente
        est ajoutee a la fin de la section. Toute autre ligne de la
        section (cle non geree, commentaire) et toute autre section du
        fichier restent inchangees, y compris leur ordre. Si la section
        n'existe pas, elle est ajoutee a la fin du fichier.
    .PARAMETER Content
        Contenu existant du fichier, ou chaine vide si le fichier n'existe
        pas encore.
    .PARAMETER Section
        Nom de la section, sans crochets (ex: "wsl2").
    .PARAMETER KeyValues
        Dictionnaire ordonne cle -> valeur des cles gerees a ecrire.
    .NOTES
        Les fins de ligne du fichier resultant sont normalisees en LF,
        comme le reste du code de ce projet (voir ConvertTo-WslConfigContent
        historique). Les parseurs INI, y compris celui de WSL2, tolerent
        LF aussi bien que CRLF.
    #>
    param(
        [string]$Content,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$KeyValues
    )
    $lines = if ([string]::IsNullOrEmpty($Content)) { @() } else { @($Content -split "`r`n|`n") }
    $sectionHeader = "[$Section]"
    $sectionStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq $sectionHeader) { $sectionStart = $i; break }
    }

    if ($sectionStart -eq -1) {
        $newLines = [System.Collections.Generic.List[string]]::new()
        foreach ($l in $lines) { $newLines.Add($l) }
        if ($newLines.Count -gt 0 -and $newLines[$newLines.Count - 1] -ne "") { $newLines.Add("") }
        $newLines.Add($sectionHeader)
        foreach ($k in $KeyValues.Keys) { $newLines.Add("$k=$($KeyValues[$k])") }
        return ($newLines -join "`n")
    }

    $sectionEnd = $lines.Count
    for ($i = $sectionStart + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[.+\]\s*$') { $sectionEnd = $i; break }
    }

    $remainingKeys = [ordered]@{}
    foreach ($k in $KeyValues.Keys) { $remainingKeys[$k] = $KeyValues[$k] }

    $newLines = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -le $sectionStart; $i++) { $newLines.Add($lines[$i]) }
    for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
        $line = $lines[$i]
        $matchedKey = $null
        foreach ($k in $remainingKeys.Keys) {
            if ($line -match "^\s*$([regex]::Escape($k))\s*=") { $matchedKey = $k; break }
        }
        if ($matchedKey) {
            $newLines.Add("$matchedKey=$($remainingKeys[$matchedKey])")
            $remainingKeys.Remove($matchedKey)
        } else {
            $newLines.Add($line)
        }
    }
    foreach ($k in $remainingKeys.Keys) { $newLines.Add("$k=$($remainingKeys[$k])") }
    for ($i = $sectionEnd; $i -lt $lines.Count; $i++) { $newLines.Add($lines[$i]) }

    return ($newLines -join "`n")
}

function ConvertTo-WslConfigContent {
    <#
    .SYNOPSIS
        Genere le contenu de .wslconfig pour un profil, en fusionnant dans
        le contenu existant plutot qu'en le remplacant (principe 8 : ne
        jamais detruire ce qu'on ne gere pas). Seules les cles gerees par
        Wisely dans [wsl2], plus la cle profile= dans [wisely], sont
        touchees - toute autre cle, tout autre commentaire, toute autre
        section (autoMemoryReclaim, sparseVhd, [experimental], etc., poses
        par l'utilisateur, Docker Desktop ou WSL Settings) sont preserves
        tels quels.
    .PARAMETER ExistingContent
        Contenu actuel de .wslconfig, ou chaine vide si le fichier n'existe
        pas encore. Omis, se comporte comme une creation a partir de rien.
    .PARAMETER ProfileKey
        Cle du profil (ex: "web"), marquee dans une section [wisely]
        dediee pour que Get-ActiveProfile identifie le profil actif sans
        deviner (principe 9) - deux profils de memoire identique restent
        distinguables. Omise, aucun marqueur n'est ecrit.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$ProfileDef,
        [string]$ProfileKey = "",
        [string]$ExistingContent = ""
    )
    $wsl2Keys = [ordered]@{
        memory             = $ProfileDef.memory
        processors         = $ProfileDef.processors
        swap               = $ProfileDef.swap
        swapFile           = $ProfileDef.swapFile
        kernelCommandLine  = "sysctl.vm.swappiness=$($ProfileDef.swappiness)"
    }
    $content = Set-IniSectionKeys -Content $ExistingContent -Section "wsl2" -KeyValues $wsl2Keys
    if ($ProfileKey) {
        $wiselyKeys = [ordered]@{ profile = $ProfileKey }
        $content = Set-IniSectionKeys -Content $content -Section "wisely" -KeyValues $wiselyKeys
    }
    return $content
}

# ---- Garde-fou WSL2 actif avant shutdown -----------------------------

function Test-WiselyNonInteractive {
    <#
    .SYNOPSIS
        Indique si la session courante n'a pas d'entree utilisateur
        disponible (ex. tache planifiee, pipeline CI, entree redirigee).
        Isole le check .NET statique dans une fonction nommee pour que
        les tests Pester puissent la mocker.
    #>
    return [Console]::IsInputRedirected
}

function Get-WslActiveSessions {
    <#
    .SYNOPSIS
        Liste les distributions WSL2 actuellement en cours d'execution.
        Fail open : ne leve jamais d'exception, retourne @() si "wsl" est
        introuvable ou si la commande echoue, pour ne pas regresser le
        switch existant si la detection echoue.
    #>
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        return @()
    }
    try {
        $rawOutput = wsl --list --running --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "wsl --list --running a retourne un code d'erreur ($LASTEXITCODE)."
            return @()
        }
        $distros = $rawOutput |
                   ForEach-Object { ($_ -replace "`0", "").Trim() } |
                   Where-Object { $_ -ne "" }
        return @($distros)
    } catch {
        Write-Verbose "Get-WslActiveSessions a echoue : $_"
        return @()
    }
}

function Get-DistroTopProcesses {
    <#
    .SYNOPSIS
        Parse la sortie de "ps -eo rss,comm --sort=-rss" (deja triee par
        empreinte memoire decroissante) et retourne les N processus les
        plus attribues. Isole de Confirm-WslShutdown pour rester testable
        sans mock de Invoke-GuestRead. N'invente rien : une ligne qui ne
        correspond pas au format attendu est ignoree plutot que de
        produire une entree partielle.
    #>
    param(
        [Parameter(Mandatory)][string]$RawOutput,
        [int]$Top = 5
    )
    $processes = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($line in ($RawOutput -split "`n" | Select-Object -Skip 1)) {
        if ($line -match '^\s*(\d+)\s+(\S+)') {
            $processes.Add([PSCustomObject]@{
                Comm  = $Matches[2]
                RssGB = [math]::Round([double]$Matches[1] / 1MB, 2)
            })
        }
    }
    return @($processes | Select-Object -First $Top)
}

function Confirm-WslShutdown {
    <#
    .SYNOPSIS
        Verifie qu'aucune distribution WSL2 active ne sera interrompue
        sans confirmation avant un "wsl --shutdown". Retourne $true si le
        shutdown peut se poursuivre, $false sinon. Sous consentement de
        lecture invitee accorde (P1, modules/GuestReader.ps1), tente
        d'annoncer precisement ce qui va etre interrompu - les processus
        les plus attribues par distribution active - plutot que la seule
        liste des distributions (PRINCIPLES.md, principe 11 : "annoncer
        le cout avant de le faire payer").
    .PARAMETER TopProcessCount
        Nombre de processus les plus attribues affiches par distribution.
    #>
    param([int]$TopProcessCount = 5)

    $activeSessions = Get-WslActiveSessions
    if ($activeSessions.Count -eq 0) {
        return $true
    }

    Write-Host ""
    Write-Host "  ATTENTION - Distribution(s) WSL2 active(s) :" -ForegroundColor Yellow
    foreach ($distro in $activeSessions) {
        Write-Host "    - $distro" -ForegroundColor Yellow
    }
    Write-Host "  Un arret force peut interrompre des process en cours et corrompre des fichiers non sauvegardes." -ForegroundColor Yellow

    # Degradation propre a deux niveaux : consentement absent/revoque ->
    # message + suggestion ci-dessous ; consentement accorde mais lecture
    # invitee en echec (distro sans process listable, timeout...) -> capture
    # locale, silence (Write-Verbose seulement), jamais d'echec de la
    # confirmation elle-meme. Get-GuestReadConsentState peut lever si
    # profiles.json est absent/corrompu - traite comme "unset".
    $consent = "unset"
    try { $consent = Get-GuestReadConsentState } catch { Write-Verbose "Lecture du consentement impossible : $_" }

    if ($consent -eq "granted") {
        foreach ($distro in $activeSessions) {
            try {
                $rawOutput = Invoke-GuestRead -CommandKey "ProcRss" -Distro $distro
                $topProcs  = Get-DistroTopProcesses -RawOutput $rawOutput -Top $TopProcessCount
                if ($topProcs.Count -gt 0) {
                    Write-Host "  Ce qui va etre interrompu dans '$distro' (par empreinte memoire) :" -ForegroundColor Yellow
                    foreach ($p in $topProcs) {
                        Write-Host "    - $($p.Comm) ($($p.RssGB) Go)" -ForegroundColor Gray
                    }
                }
            } catch {
                Write-Verbose "Detail des process de '$distro' indisponible avant l'arret : $_"
            }
        }
    } else {
        Write-Host "  Detail des process non disponible (consentement de lecture invitee : $consent) - activez-le avec : wisely -Consent grant" -ForegroundColor DarkGray
    }

    if (Test-WiselyNonInteractive) {
        Write-Host "  Session non-interactive detectee - relancez avec -Force pour continuer malgre tout." -ForegroundColor Red
        Write-Host ""
        return $false
    }

    $answer = Read-Host "  Continuer ? (o/n)"
    Write-Host ""
    return ($answer -eq "o")
}

function Set-WslProfile {
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$DryRun,
        [switch]$ShowDiff,
        [switch]$Force
    )
    $config = Get-ProfileConfig
    $prop   = $config.profiles.PSObject.Properties | Where-Object { $_.Name -eq $Key }
    if ($null -eq $prop) {
        throw "Profil '$Key' introuvable. Profils disponibles : $($config.profiles.PSObject.Properties.Name -join ', ')"
    }
    $profileDef = Resolve-ProfilePaths -ProfileDef $prop.Value
    try {
        Test-SwapFilePath -SwapFile $profileDef.swapFile
    } catch {
        throw "Validation du profil '$Key' echouee : $_"
    }
    $oldContent = if (Test-Path (Get-WslConfigPath)) { Get-Content (Get-WslConfigPath) -Raw -Encoding UTF8 } else { "" }
    $content = ConvertTo-WslConfigContent -ProfileDef $profileDef -ProfileKey $Key -ExistingContent $oldContent

    if ($DryRun) {
        Write-Host ""
        Write-Host "  DRY-RUN - Simulation (aucune ecriture)" -ForegroundColor DarkYellow
        Write-Host "  Profil  : $($profileDef.displayName)" -ForegroundColor Yellow
        Write-Host "  Memoire : $($profileDef.memory)" -ForegroundColor Gray
        Write-Host "  CPU     : $($profileDef.processors)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Contenu .wslconfig simule :" -ForegroundColor DarkGray
        $content -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Write-Host ""
        return
    }

    $forcedActiveSessions = @()
    if ($Force) {
        $forcedActiveSessions = Get-WslActiveSessions
    } elseif (-not (Confirm-WslShutdown)) {
        Write-Host "  Switch de profil annule (session(s) WSL2 active(s), confirmation refusee)." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    Backup-WslConfig
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ""
    Write-Host "  Activation du profil $($profileDef.displayName)..." -ForegroundColor $profileDef.color
    Write-Host "  Arret de WSL2..." -ForegroundColor Gray
    $restartStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    wsl --shutdown
    Start-Sleep -Seconds 2
    $restartStopwatch.Stop()
    $restartSeconds = [math]::Round($restartStopwatch.Elapsed.TotalSeconds, 1)
    Set-Content -Path (Get-WslConfigPath) -Value $content -Encoding UTF8

    if (-not (Test-WslConfigIntegrity)) {
        Write-Host "  ERREUR : .wslconfig invalide apres ecriture. Rollback automatique." -ForegroundColor Red
        Invoke-Rollback
        return
    }

    if ($ShowDiff) { Show-WslConfigDiff -Old $oldContent -New $content }

    $stopwatch.Stop()
    $elapsed  = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

    Write-Host "  OK - $($profileDef.displayName) actif en ${elapsed}s - $($profileDef.memory) / $($profileDef.processors) CPU" -ForegroundColor Green
    Write-Host "  WSL2 demarrera avec ce profil au prochain lancement." -ForegroundColor DarkGray
    Write-Host ""

    $details = "$($profileDef.memory), $($profileDef.processors) CPU, ${elapsed}s"
    if ($forcedActiveSessions.Count -gt 0) {
        $details += ", Force (sessions actives ignorees : $($forcedActiveSessions -join ', '))"
    }
    Write-SwitchLog -Action "SWITCH" -ProfileKey $Key -Details $details -RestartSeconds $restartSeconds
}

# ---- Profils personnalises ------------------------------------------

function Test-ProfileDefinition {
    <#
    .SYNOPSIS
        Valide un profil (memoire, CPU, absence de retour a la ligne dans
        les champs interpoles tels quels dans .wslconfig par
        ConvertTo-WslConfigContent). Factorisee entre New-CustomProfile et
        Import-Profiles pour que tout profil qui entre dans le systeme -
        cree localement ou importe depuis un fichier externe - passe par
        la meme validation (voir AUDIT.md : Import-Profiles ne validait
        auparavant que la presence des cles 'profiles'/'version', jamais
        le contenu de chaque profil avant de l'ecrire dans .wslconfig et
        de redemarrer WSL2 avec).
    .PARAMETER Key
        Cle du profil, uniquement pour un message d'erreur explicite.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$ProfileDef, [string]$Key = "?")

    if ($Key -match "[`r`n]") {
        throw "Profil '$Key' : la cle du profil contient un retour a la ligne, refusee (risque d'injection dans .wslconfig - la cle est ecrite telle quelle dans la section [wisely])."
    }
    if ("$($ProfileDef.memory)" -notmatch "^\d+GB$") {
        throw "Profil '$Key' : format memoire invalide '$($ProfileDef.memory)'. Attendu : ex. 4GB, 8GB, 12GB"
    }
    $maxCpu = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    if ($ProfileDef.processors -lt 1 -or $ProfileDef.processors -gt $maxCpu) {
        throw "Profil '$Key' : nombre de CPU invalide '$($ProfileDef.processors)'. Attendu : entre 1 et $maxCpu (processeurs logiques disponibles)."
    }
    foreach ($field in @("swap", "swapFile", "swappiness", "displayName", "description", "color")) {
        $value = $ProfileDef.$field
        if (($null -ne $value) -and ("$value" -match "[`r`n]")) {
            throw "Profil '$Key' : le champ '$field' contient un retour a la ligne, refuse (risque d'injection dans .wslconfig)."
        }
    }
}

function New-CustomProfile {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Memory,
        [Parameter(Mandatory)][int]$Processors,
        [string]$Description = "Profil personnalise",
        [string]$Swap        = "2GB",
        [int]$Swappiness     = 10
    )
    $newProfile = [PSCustomObject]@{
        displayName = $Key.ToUpper()
        description = $Description
        color       = "Magenta"
        memory      = $Memory
        processors  = $Processors
        swap        = $Swap
        swapFile    = "%TEMP%/wisely-swap.vhdx"
        swappiness  = $Swappiness
    }
    Test-ProfileDefinition -ProfileDef $newProfile -Key $Key
    $config = Get-ProfileConfig
    $config.profiles | Add-Member -MemberType NoteProperty -Name $Key.ToLower() -Value $newProfile -Force
    $config | ConvertTo-Json -Depth 10 | Set-Content (Get-ProfilesPath) -Encoding UTF8
    Clear-ProfileConfigCache
    Write-Host "  OK - Profil '$($Key.ToUpper())' cree ($Memory / $Processors CPU)." -ForegroundColor Green
    Write-SwitchLog -Action "CUSTOM" -ProfileKey $Key.ToLower() -Details "Cree : $Memory, $Processors CPU"
}

function New-SnapshotProfile {
    param([int]$ProcessCount = 5)
    if (-not (Test-Path (Get-WslConfigPath))) {
        throw "Aucun .wslconfig actif. Impossible de creer un snapshot sans profil actif."
    }
    $active    = Get-ActiveProfile
    $key       = "snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $topProcs  = Get-Process |
                 Sort-Object -Property WorkingSet64 -Descending |
                 Select-Object -First $ProcessCount -ExpandProperty ProcessName

    $config     = Get-ProfileConfig
    $newProfile = [PSCustomObject]@{
        displayName = $key.ToUpper()
        description = "Snapshot du $(Get-Date -Format 'yyyy-MM-dd HH:mm') - Top process : $($topProcs -join ', ')"
        color       = "Magenta"
        memory      = $active.memory
        processors  = [int]$active.processors
        swap        = "2GB"
        swapFile    = "%TEMP%/wisely-swap.vhdx"
        swappiness  = 10
    }
    $config.profiles | Add-Member -MemberType NoteProperty -Name $key -Value $newProfile -Force
    $config | ConvertTo-Json -Depth 10 | Set-Content (Get-ProfilesPath) -Encoding UTF8
    Clear-ProfileConfigCache
    Write-SwitchLog -Action "CUSTOM" -ProfileKey $key -Details "Snapshot cree : $($active.memory), $($active.processors) CPU"
    return $key
}

function Export-Profiles {
    param([string]$Path = ".\wsl-profiles-export.json")
    Copy-Item (Get-ProfilesPath) $Path -Force
    Write-Host "  OK - Profils exportes vers : $Path" -ForegroundColor Green
    Write-SwitchLog -Action "EXPORT" -Details $Path
}

function Import-Profiles {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { throw "Fichier introuvable : $Path" }
    $imported = try { Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "JSON invalide dans '$Path' : $_" }
    if ($null -eq $imported.profiles) { throw "Le fichier importe ne contient pas de cle 'profiles'." }
    if ($null -eq $imported.version)  { throw "Le fichier importe ne contient pas de cle 'version'." }
    $profileProps = @($imported.profiles.PSObject.Properties)
    if ($profileProps.Count -eq 0) { throw "Aucun profil defini dans le fichier importe." }
    # Chaque profil importe passe par la meme validation qu'un profil cree
    # via -NewProfile - un fichier importe est une entree externe au meme
    # titre (voir AUDIT.md).
    foreach ($prop in $profileProps) {
        Test-ProfileDefinition -ProfileDef $prop.Value -Key $prop.Name
    }
    Backup-WslConfig
    Copy-Item $Path (Get-ProfilesPath) -Force
    Clear-ProfileConfigCache
    Write-Host "  OK - $($profileProps.Count) profil(s) importes depuis : $Path" -ForegroundColor Green
    Write-SwitchLog -Action "IMPORT" -Details $Path
}
