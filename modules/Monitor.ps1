Set-Variable -Name TASK_NAME         -Value "WSL2-RamMonitor"       -Option Constant -Scope Script
Set-Variable -Name WEEKLY_TASK_NAME  -Value "WSL2-WeeklyReport"     -Option Constant -Scope Script

function Start-WslMonitor {
    param([int]$CooldownMin = 30)

    # Verification des droits administrateur
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "  ERREUR : Le demarrage du monitoring requiert des droits administrateur." -ForegroundColor Red
        Write-Host "  Relancez PowerShell en tant qu'Administrateur." -ForegroundColor Gray
        return
    }

    # Lecture des parametres depuis profiles.json
    $config = Get-ProfileConfig
    try {
        $threshold   = if ($config.settings.monitorThreshold)      { [int]$config.settings.monitorThreshold }      else { 80 }
        $intervalSec = if ($config.settings.monitorIntervalSeconds) { [int]$config.settings.monitorIntervalSeconds } else { 30 }
    } catch {
        Write-Host "  AVERTISSEMENT : valeur numerique invalide dans settings (monitorThreshold / monitorIntervalSeconds). Valeurs par defaut utilisees." -ForegroundColor DarkYellow
        $threshold   = 80
        $intervalSec = 30
    }
    $intervalMin = [math]::Max(1, [math]::Ceiling($intervalSec / 60))

    $taskScript = Join-Path $Global:WSLRoot "modules\MonitorTask.ps1"
    if (-not (Test-Path $taskScript)) {
        Write-Host "  ERREUR : MonitorTask.ps1 introuvable." -ForegroundColor Red
        return
    }

    # --- Tache de monitoring RAM ---
    $existing = Get-ScheduledTask -TaskName $script:TASK_NAME -ErrorAction SilentlyContinue
    if ($existing) { Unregister-ScheduledTask -TaskName $script:TASK_NAME -Confirm:$false }

    $psArgs  = "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass " +
               "-File `"$taskScript`" -ThresholdPct $threshold -CooldownMin $CooldownMin"
    $action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $psArgs
    $trigger  = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $intervalMin) -Once -At (Get-Date)
    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew `
        -StartWhenAvailable

    Register-ScheduledTask `
        -TaskName $script:TASK_NAME -Action $action -Trigger $trigger `
        -Settings $settings -RunLevel Highest -Force | Out-Null

    # --- Tache de rapport hebdomadaire (lundi 09h00) ---
    $weeklyScript  = Join-Path $Global:WSLRoot "modules\WeeklyReport.ps1"
    $existingWeekly = Get-ScheduledTask -TaskName $script:WEEKLY_TASK_NAME -ErrorAction SilentlyContinue
    if ($existingWeekly) { Unregister-ScheduledTask -TaskName $script:WEEKLY_TASK_NAME -Confirm:$false }

    if (Test-Path $weeklyScript) {
        $weeklyArgs     = "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File `"$weeklyScript`" -Silent"
        $weeklyAction   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $weeklyArgs
        $weeklyTrigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:00"
        $weeklySettings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
            -MultipleInstances IgnoreNew `
            -StartWhenAvailable

        Register-ScheduledTask `
            -TaskName $script:WEEKLY_TASK_NAME -Action $weeklyAction -Trigger $weeklyTrigger `
            -Settings $weeklySettings -RunLevel Highest -Force | Out-Null
    }

    Write-Host ""
    Write-Host "  Monitoring demarre." -ForegroundColor Green
    Write-Host "  Seuil    : $threshold% RAM" -ForegroundColor Gray
    Write-Host "  Intervalle : toutes les $intervalMin min ($intervalSec s)" -ForegroundColor Gray
    Write-Host "  Cooldown : alerte max toutes les $CooldownMin min" -ForegroundColor Gray
    Write-Host "  Rapport  : chaque lundi a 09h00 (tache planifiee)" -ForegroundColor Gray
    Write-Host "  Mode     : tache planifiee Windows (sans terminal)" -ForegroundColor Gray
    Write-Host ""
}

function Stop-WslMonitor {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "  ERREUR : L'arret du monitoring requiert des droits administrateur." -ForegroundColor Red
        Write-Host "  Relancez PowerShell en tant qu'Administrateur." -ForegroundColor Gray
        return
    }

    $existing = Get-ScheduledTask -TaskName $script:TASK_NAME -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "  Le monitoring n'est pas actif." -ForegroundColor Gray
        return
    }
    Unregister-ScheduledTask -TaskName $script:TASK_NAME -Confirm:$false

    $existingWeekly = Get-ScheduledTask -TaskName $script:WEEKLY_TASK_NAME -ErrorAction SilentlyContinue
    if ($existingWeekly) { Unregister-ScheduledTask -TaskName $script:WEEKLY_TASK_NAME -Confirm:$false }

    Write-Host "  Monitoring arrete." -ForegroundColor Yellow
    Write-Host ""
}

function Get-MonitorStatus {
    $task     = Get-ScheduledTask -TaskName $script:TASK_NAME -ErrorAction SilentlyContinue
    $cooldown = Join-Path $Global:WSLRoot "data\monitor_cooldown.txt"
    $errors   = Join-Path $Global:WSLRoot "data\monitor_errors.txt"
    Write-Host ""
    if ($task) {
        $sc = switch ($task.State) { "Running"{"Green"} "Ready"{"Cyan"} default{"Gray"} }
        Write-Host "  Monitoring    : ACTIF ($($task.State))" -ForegroundColor $sc
    } else {
        Write-Host "  Monitoring    : INACTIF" -ForegroundColor DarkGray
    }
    $last = if (Test-Path $cooldown) { (Get-Content $cooldown -Raw).Trim() } else { "aucune" }
    Write-Host "  Derniere alerte : $last" -ForegroundColor Gray
    if ((Test-Path $errors) -and ((Get-Content $errors).Count -gt 0)) {
        Write-Host "  Erreurs toast : voir data\monitor_errors.txt" -ForegroundColor DarkYellow
    }
    Write-Host ""
}
