# ============================================================
#  ProfileManager.ps1 - Gestion des profils WSL2
#  Dot-source depuis wisely.ps1
#  Utilise $Global:WSLRoot defini dans le script principal
# ============================================================

function Get-ProfilesPath  { Join-Path $Global:WSLRoot "data\profiles.json" }
function Get-BackupPath    { Join-Path $Global:WSLRoot "data\wslconfig.backup" }
function Get-WslConfigPath { Join-Path $env:USERPROFILE ".wslconfig" }

# ---- Lecture de la configuration ------------------------------------

function Get-ProfileConfig {
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
    return $parsed
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

function Backup-WslConfig {
    $src = Get-WslConfigPath
    if (Test-Path $src) { Copy-Item $src (Get-BackupPath) -Force }
}

function Invoke-Rollback {
    $backupPath = Get-BackupPath
    if (-not (Test-Path $backupPath)) {
        Write-Host ""
        Write-Host "  Aucun backup disponible - rollback impossible." -ForegroundColor Red
        Write-Host ""
        return
    }
    Write-Host ""
    Write-Host "  Rollback en cours..." -ForegroundColor Yellow
    Write-Host "  Arret de WSL2..." -ForegroundColor Gray
    wsl --shutdown
    Start-Sleep -Seconds 2
    Copy-Item $backupPath (Get-WslConfigPath) -Force
    Write-Host "  .wslconfig restaure." -ForegroundColor Green
    $restored = Get-ActiveProfile
    Write-Host "  Profil restaure : $($restored.name) ($($restored.memory) / $($restored.processors) CPU)" -ForegroundColor Cyan
    Write-Host ""
    Write-SwitchLog -Action "ROLLBACK" -ProfileKey $restored.key -Details "Restaure depuis backup"
}

# ---- Generation & application ---------------------------------------
# Note : swapFile utilise des slashes forward (C:/Temp/...)
# WSL2 et Windows acceptent les deux formats dans .wslconfig
# Cela evite le probleme d'echappement du backslash

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

function Set-WslProfile {
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$DryRun
    )
    $config = Get-ProfileConfig
    $prop   = $config.profiles.PSObject.Properties | Where-Object { $_.Name -eq $Key }
    if ($null -eq $prop) {
        throw "Profil '$Key' introuvable. Profils disponibles : $($config.profiles.PSObject.Properties.Name -join ', ')"
    }
    $profileDef = $prop.Value
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

    Backup-WslConfig
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ""
    Write-Host "  Activation du profil $($profileDef.displayName)..." -ForegroundColor $profileDef.color
    Write-Host "  Arret de WSL2..." -ForegroundColor Gray
    wsl --shutdown
    Start-Sleep -Seconds 2
    Set-Content -Path (Get-WslConfigPath) -Value $content -Encoding UTF8

    if (-not (Test-WslConfigIntegrity)) {
        Write-Host "  ERREUR : .wslconfig invalide apres ecriture. Rollback automatique." -ForegroundColor Red
        Invoke-Rollback
        return
    }

    $stopwatch.Stop()
    $elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
    Write-Host "  OK - $($profileDef.displayName) actif en ${elapsed}s - $($profileDef.memory) / $($profileDef.processors) CPU" -ForegroundColor Green    
    Write-Host "  WSL2 demarrera avec ce profil au prochain lancement." -ForegroundColor DarkGray
    Write-Host ""
    Write-SwitchLog -Action "SWITCH" -ProfileKey $Key -Details "$($profileDef.memory), $($profileDef.processors) CPU, ${elapsed}s"}

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
        swapFile    = "C:/Temp/wsl-swap.vhdx"
        swappiness  = $Swappiness
    }
    $config.profiles | Add-Member -MemberType NoteProperty -Name $Key.ToLower() -Value $newProfile -Force
    $config | ConvertTo-Json -Depth 10 | Set-Content (Get-ProfilesPath) -Encoding UTF8
    Write-Host "  OK - Profil '$($Key.ToUpper())' cree ($Memory / $Processors CPU)." -ForegroundColor Green
    Write-SwitchLog -Action "CUSTOM" -ProfileKey $Key.ToLower() -Details "Cree : $Memory, $Processors CPU"
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
    Write-Host "  OK - $(@($imported.profiles.PSObject.Properties).Count) profil(s) importes depuis : $Path" -ForegroundColor Green
    Write-SwitchLog -Action "IMPORT" -Details $Path
}
