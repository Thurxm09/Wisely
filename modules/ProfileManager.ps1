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
        throw "profiles.json incomplet — cle manquante : 'profiles'"
    }
    $script:ProfileConfigCache = $parsed
    return $script:ProfileConfigCache
}

function Clear-ProfileConfigCache {
    $script:ProfileConfigCache = $null
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
    try {
        $cfg     = if ($null -ne $Config) { $Config } else { Get-ProfileConfig }
        $matched = $cfg.profiles.PSObject.Properties |
                   Where-Object { $_.Value.memory -eq $mem } |
                   Select-Object -First 1
        return [PSCustomObject]@{
            name       = if ($matched) { $matched.Value.displayName } else { "Personnalise" }
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
        if ($cfg.settings.backupHistoryMax) { return [int]$cfg.settings.backupHistoryMax }
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
        $all | Select-Object -First ($all.Count - $max) | Remove-Item -Force
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

function ConvertTo-WslConfigContent {
    param([Parameter(Mandatory)][PSCustomObject]$ProfileDef)
    $swapFile = $ProfileDef.swapFile
    return @"
[wsl2]
memory=$($ProfileDef.memory)
processors=$($ProfileDef.processors)
swap=$($ProfileDef.swap)
swapFile=$swapFile
kernelCommandLine=sysctl.vm.swappiness=$($ProfileDef.swappiness)
"@
}

function Get-AvailableRamGB {
    <#
    .SYNOPSIS
        RAM Windows disponible (en GB), mesuree avant/apres un switch pour
        calculer le delta reel libere - Axe 6 (Observabilite), v2.3.
        Retourne $null si la mesure echoue (ex: Get-CimInstance
        indisponible) plutot que de faire echouer le switch pour une
        metrique optionnelle.
    #>
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        return [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    } catch {
        return $null
    }
}

function Set-WslProfile {
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$DryRun,
        [switch]$ShowDiff
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
    $content = ConvertTo-WslConfigContent -ProfileDef $profileDef

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

    $oldContent = if (Test-Path (Get-WslConfigPath)) { Get-Content (Get-WslConfigPath) -Raw -Encoding UTF8 } else { "" }
    $ramBefore  = Get-AvailableRamGB

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
    $ramAfter = Get-AvailableRamGB
    $ramDelta = if (($null -ne $ramBefore) -and ($null -ne $ramAfter)) { [math]::Round($ramAfter - $ramBefore, 2) } else { $null }
    $ramSign  = if (($null -ne $ramDelta) -and ($ramDelta -ge 0)) { "+" } else { "" }

    Write-Host "  OK - $($profileDef.displayName) actif en ${elapsed}s - $($profileDef.memory) / $($profileDef.processors) CPU" -ForegroundColor Green
    if ($null -ne $ramDelta) {
        Write-Host "  RAM Windows disponible : ${ramSign}${ramDelta}GB (arret WSL2 mesure : ${restartSeconds}s)" -ForegroundColor Gray
    }
    Write-Host "  WSL2 demarrera avec ce profil au prochain lancement." -ForegroundColor DarkGray
    Write-Host ""

    $details = "$($profileDef.memory), $($profileDef.processors) CPU, ${elapsed}s"
    if ($null -ne $ramDelta) { $details += ", RAM ${ramSign}${ramDelta}GB" }
    Write-SwitchLog -Action "SWITCH" -ProfileKey $Key -Details $details -RamDeltaGB $ramDelta -RestartSeconds $restartSeconds
}

# ---- Profils personnalises ------------------------------------------

function New-CustomProfile {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Memory,
        [Parameter(Mandatory)][int]$Processors,
        [string]$Description = "Profil personnalise",
        [string]$Swap        = "2GB",
        [int]$Swappiness     = 10
    )
    if ($Memory -notmatch "^\d+GB$") {
        throw "Format memoire invalide : '$Memory'. Attendu : ex. 4GB, 8GB, 12GB"
    }
    $maxCpu = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    if ($Processors -lt 1 -or $Processors -gt $maxCpu) {
        throw "Nombre de CPU invalide : $Processors. Attendu : entre 1 et $maxCpu (processeurs logiques disponibles)."
    }
    $config     = Get-ProfileConfig
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
    $imported = try { Get-Content $Path -Raw | ConvertFrom-Json } catch { throw "JSON invalide dans '$Path' : $_" }
    if ($null -eq $imported.profiles) { throw "Le fichier importe ne contient pas de cle 'profiles'." }
    if ($null -eq $imported.version)  { throw "Le fichier importe ne contient pas de cle 'version'." }
    if (@($imported.profiles.PSObject.Properties).Count -eq 0) { throw "Aucun profil defini dans le fichier importe." }
    Backup-WslConfig
    Copy-Item $Path (Get-ProfilesPath) -Force
    Clear-ProfileConfigCache
    Write-Host "  OK - $(@($imported.profiles.PSObject.Properties).Count) profil(s) importes depuis : $Path" -ForegroundColor Green
    Write-SwitchLog -Action "IMPORT" -Details $Path
}
