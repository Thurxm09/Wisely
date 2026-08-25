# ============================================================
#  Monitor.Tests.ps1 - Tests Pester pour modules/Monitor.ps1
# ============================================================

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/../modules/Monitor.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"

    # Definie ici (scope script) : Pester 6 n'expose pas les fonctions
    # declarees hors BeforeAll/BeforeEach aux blocs It (voir
    # ProfileManager.Tests.ps1 pour le meme raisonnement).
    function script:Get-ValidProfilesConfig {
        param([hashtable]$Settings = @{})
        return @{
            version  = "2.0.0"
            profiles = @{
                web = @{
                    displayName = "WEB"
                    description = "Profil de test"
                    color       = "Green"
                    memory      = "4GB"
                    processors  = 3
                    swap        = "2GB"
                    swapFile    = "/tmp/wisely-test-swap.vhdx"
                    swappiness  = 10
                }
            }
            settings = $Settings
        }
    }

    function script:Enable-ScheduledTaskMocks {
        <#
        .SYNOPSIS
            Stub puis mock les cmdlets du module ScheduledTasks (Windows-only,
            absentes sur le runner Linux de la CI - meme piege que "wsl", voir
            TestHelpers.ps1). Get-ScheduledTask renvoie $null par defaut
            (aucune tache existante) ; chaque test peut la re-mocker.
        #>
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { function script:Get-ScheduledTask { } }
        if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) { function script:Register-ScheduledTask { } }
        if (-not (Get-Command Unregister-ScheduledTask -ErrorAction SilentlyContinue)) { function script:Unregister-ScheduledTask { } }
        # Declare -Execute/-Argument explicitement (contrairement aux autres
        # stubs sans bloc de parametres) : Pester a besoin de connaitre le
        # nom des parametres pour que -ParameterFilter { $Argument -match ... }
        # puisse s'y referer dans les tests de seuil/intervalle ci-dessous.
        if (-not (Get-Command New-ScheduledTaskAction -ErrorAction SilentlyContinue)) {
            function script:New-ScheduledTaskAction {
                param($Execute, $Argument)
                $null = $Execute
                $null = $Argument
            }
        }
        if (-not (Get-Command New-ScheduledTaskTrigger -ErrorAction SilentlyContinue)) { function script:New-ScheduledTaskTrigger { } }
        if (-not (Get-Command New-ScheduledTaskSettingsSet -ErrorAction SilentlyContinue)) { function script:New-ScheduledTaskSettingsSet { } }

        Mock Get-ScheduledTask { $null }
        Mock Register-ScheduledTask {}
        Mock Unregister-ScheduledTask {}
        Mock New-ScheduledTaskAction { [PSCustomObject]@{} }
        Mock New-ScheduledTaskTrigger { [PSCustomObject]@{} }
        Mock New-ScheduledTaskSettingsSet { [PSCustomObject]@{} }
    }

    function script:New-TestMonitorScripts {
        <#
        .SYNOPSIS
            Cree modules/MonitorTask.ps1 (et modules/WeeklyReport.ps1 sauf
            -SkipWeekly) sous $Global:WSLRoot, comme au demarrage reel de
            wisely.ps1, pour satisfaire les Test-Path de Start-WslMonitor.
        #>
        param([switch]$SkipWeekly)
        $modulesDir = Join-Path $Global:WSLRoot "modules"
        New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
        Set-Content -Path (Join-Path $modulesDir "MonitorTask.ps1") -Value "" -Encoding UTF8
        if (-not $SkipWeekly) {
            Set-Content -Path (Join-Path $modulesDir "WeeklyReport.ps1") -Value "" -Encoding UTF8
        }
    }
}

Describe "Start-WslMonitor" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Enable-ScheduledTaskMocks
        Mock Test-IsAdminUser { $true }
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne fait rien si l'utilisateur n'est pas administrateur" {
        Mock Test-IsAdminUser { $false }

        Start-WslMonitor

        Should -Invoke -CommandName Register-ScheduledTask -Times 0 -Exactly
    }

    It "ne fait rien si MonitorTask.ps1 est introuvable" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null

        Start-WslMonitor

        Should -Invoke -CommandName Register-ScheduledTask -Times 0 -Exactly
    }

    It "enregistre la tache de monitoring RAM et la tache de rapport hebdomadaire quand tout est en place" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        New-TestMonitorScripts

        Start-WslMonitor

        Should -Invoke -CommandName Register-ScheduledTask -Times 2 -Exactly
    }

    It "n'enregistre pas la tache hebdomadaire si WeeklyReport.ps1 est absent" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        New-TestMonitorScripts -SkipWeekly

        Start-WslMonitor

        Should -Invoke -CommandName Register-ScheduledTask -Times 1 -Exactly
    }

    It "desenregistre une tache existante avant de la recreer" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        New-TestMonitorScripts
        Mock Get-ScheduledTask { [PSCustomObject]@{ State = "Running" } }

        Start-WslMonitor

        Should -Invoke -CommandName Unregister-ScheduledTask -Times 2 -Exactly
    }

    It "utilise les valeurs par defaut (80%, 30s) quand settings n'est pas configure" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig -Settings @{}) | Out-Null
        New-TestMonitorScripts

        Start-WslMonitor

        Should -Invoke -CommandName New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter {
            $Argument -match "-ThresholdPct 80"
        }
    }

    It "utilise le seuil configure dans profiles.json (pas de reglages fantomes, cf. AUDIT.md C-3)" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig -Settings @{ monitorThreshold = 90; monitorIntervalSeconds = 120 }) | Out-Null
        New-TestMonitorScripts

        Start-WslMonitor

        Should -Invoke -CommandName New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter {
            $Argument -match "-ThresholdPct 90"
        }
    }

    It "retombe sur les valeurs par defaut si settings contient une valeur non numerique" {
        New-TestProfilesJson -Config (Get-ValidProfilesConfig -Settings @{ monitorThreshold = "pas-un-nombre" }) | Out-Null
        New-TestMonitorScripts

        { Start-WslMonitor } | Should -Not -Throw

        Should -Invoke -CommandName New-ScheduledTaskAction -Times 1 -Exactly -ParameterFilter {
            $Argument -match "-ThresholdPct 80"
        }
    }
}

Describe "Stop-WslMonitor" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        Enable-ScheduledTaskMocks
        Mock Test-IsAdminUser { $true }
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne fait rien si l'utilisateur n'est pas administrateur (AUDIT.md N-2)" {
        Mock Test-IsAdminUser { $false }

        Stop-WslMonitor

        Should -Invoke -CommandName Get-ScheduledTask -Times 0 -Exactly
        Should -Invoke -CommandName Unregister-ScheduledTask -Times 0 -Exactly
    }

    It "indique que le monitoring n'est pas actif si aucune tache n'existe, sans lever d'exception" {
        { Stop-WslMonitor } | Should -Not -Throw

        Should -Invoke -CommandName Unregister-ScheduledTask -Times 0 -Exactly
    }

    It "desenregistre la tache RAM et la tache hebdomadaire quand elles existent" {
        Mock Get-ScheduledTask { [PSCustomObject]@{ State = "Ready" } }

        Stop-WslMonitor

        Should -Invoke -CommandName Unregister-ScheduledTask -Times 2 -Exactly
    }
}

Describe "Get-MonitorStatus" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        Enable-ScheduledTaskMocks
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne leve pas d'exception quand aucune tache n'existe" {
        { Get-MonitorStatus } | Should -Not -Throw
    }

    It "affiche INACTIF quand aucune tache n'existe" {
        $output = Get-MonitorStatus 6>&1 | Out-String
        $output | Should -Match "INACTIF"
    }

    It "affiche ACTIF et l'etat de la tache quand elle existe" {
        Mock Get-ScheduledTask { [PSCustomObject]@{ State = "Running" } }

        $output = Get-MonitorStatus 6>&1 | Out-String
        $output | Should -Match "ACTIF"
        $output | Should -Match "Running"
    }

    It "affiche la derniere alerte quand le fichier cooldown existe" {
        $cooldown = Join-Path $Global:WSLRoot "data\monitor_cooldown.txt"
        Set-Content -Path $cooldown -Value "2026-08-21 10:00:00" -Encoding UTF8

        $output = Get-MonitorStatus 6>&1 | Out-String
        $output | Should -Match "2026-08-21 10:00:00"
    }

    It "signale les erreurs toast quand le fichier d'erreurs n'est pas vide" {
        $errorsFile = Join-Path $Global:WSLRoot "data\monitor_errors.txt"
        Set-Content -Path $errorsFile -Value "[2026-08-21 10:00:00] Toast error : test" -Encoding UTF8

        $output = Get-MonitorStatus 6>&1 | Out-String
        $output | Should -Match "Erreurs toast"
    }
}

Describe "Get-VmmemStats" {

    BeforeEach {
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Start-Sleep {}
        Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 4 } }
    }

    It "retourne `$null si vmmem est absent" {
        Mock Get-Process { $null }

        Get-VmmemStats | Should -Be $null
    }

    It "calcule le pourcentage CPU par delta entre deux echantillons" {
        $script:sampleCount = 0
        Mock Get-Process {
            $script:sampleCount++
            $cpu = if ($script:sampleCount -eq 1) { 10.0 } else { 10.1 }
            [PSCustomObject]@{ CPU = $cpu; WorkingSet64 = 2GB }
        }

        $result = Get-VmmemStats -SampleMs 200

        $result.cpuPct | Should -Be 12.5
        $result.ramGB | Should -Be 2
    }

    It "plafonne a 0 si le delta est negatif (bruit de mesure)" {
        $script:sampleCount = 0
        Mock Get-Process {
            $script:sampleCount++
            $cpu = if ($script:sampleCount -eq 1) { 10.5 } else { 10.4 }
            [PSCustomObject]@{ CPU = $cpu; WorkingSet64 = 1GB }
        }

        (Get-VmmemStats -SampleMs 200).cpuPct | Should -Be 0
    }

    It "retourne `$null si la mesure echoue, sans lever d'exception" {
        Mock Get-Process { throw "erreur" }

        { Get-VmmemStats } | Should -Not -Throw
        Get-VmmemStats | Should -Be $null
    }

    It "retourne `$null si vmmem disparait entre les deux echantillons" {
        $script:sampleCount = 0
        Mock Get-Process {
            $script:sampleCount++
            if ($script:sampleCount -eq 1) {
                [PSCustomObject]@{ CPU = 10.0; WorkingSet64 = 2GB }
            } else {
                $null
            }
        }

        { Get-VmmemStats } | Should -Not -Throw
        Get-VmmemStats | Should -Be $null
    }
}

Describe "Get-WatchSnapshot" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Start-Sleep {}
        Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 4 } }
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "expose le profil actif, 'Aucune' alerte, et des stats vmmem nulles si vmmem est absent" {
        Mock Get-Process { $null }

        $snap = Get-WatchSnapshot

        $snap.activeProfile | Should -Be "WEB"
        $snap.activeMemory | Should -Be "4GB"
        $snap.lastAlert | Should -Be "Aucune"
        $snap.vmmemRamGB | Should -Be $null
        $snap.vmmemCpuPct | Should -Be $null
    }

    It "inclut la derniere alerte quand le fichier cooldown existe" {
        Mock Get-Process { $null }
        Set-Content -Path (Join-Path $Global:WSLRoot "data\monitor_cooldown.txt") -Value "2026-08-21 10:00:00" -Encoding UTF8

        (Get-WatchSnapshot).lastAlert | Should -Be "2026-08-21 10:00:00"
    }

    It "inclut les stats vmmem quand le process existe" {
        Mock Get-Process { [PSCustomObject]@{ CPU = 5.0; WorkingSet64 = 3GB } }

        $snap = Get-WatchSnapshot

        $snap.vmmemRamGB | Should -Be 3
        $snap.vmmemCpuPct | Should -Not -BeNullOrEmpty
    }
}
