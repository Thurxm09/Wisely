# ============================================================
#  MonitorTask.Tests.ps1 - Tests Pester pour modules/MonitorTask.ps1
# ============================================================
#
#  MonitorTask.ps1 n'est jamais dot-source (il utilise "exit" en tete de
#  script, un dot-source terminerait tout le process Pester). Il est
#  execute exactement comme le fait le Planificateur de taches Windows :
#  via l'operateur d'appel "&", sur une copie du script reelle placee
#  sous $Global:WSLRoot/modules (le script derive ses chemins de
#  $PSScriptRoot, pas de $Global:WSLRoot - voir AUDIT.md).
#
#  Depuis v2.5, le seuil d'alerte porte sur le plafond WSL2 configure
#  dans .wslconfig (memory=), et non plus sur la RAM totale de la
#  machine - voir docs/RESOURCE-MODEL.md section 3 (melange de portees) et
#  docs/TASKS.md. Get-CimInstance/Win32_OperatingSystem n'est donc plus
#  utilise par ce script.

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"

    function script:Invoke-TestMonitorTask {
        param([int]$ThresholdPct = 80, [int]$CooldownMin = 30)
        $modulesDir = Join-Path $Global:WSLRoot "modules"
        New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
        $dest = Join-Path $modulesDir "MonitorTask.ps1"
        Copy-Item -Path "$PSScriptRoot/../modules/MonitorTask.ps1" -Destination $dest -Force
        & $dest -ThresholdPct $ThresholdPct -CooldownMin $CooldownMin
    }

    function script:Get-TestCooldownPath { Join-Path $Global:WSLRoot "data\monitor_cooldown.txt" }
    function script:Get-TestErrorLogPath { Join-Path $Global:WSLRoot "data\monitor_errors.txt" }
}

Describe "MonitorTask.ps1" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne fait rien si le process vmmem est absent" {
        Mock Get-Process { $null }

        Invoke-TestMonitorTask

        Test-Path (Get-TestCooldownPath) | Should -Be $false
    }

    It "detecte VmmemWSL quand vmmem est absent (Windows 11 recent)" {
        New-TestWslConfig | Out-Null
        Mock Get-Process {
            if ($Name -contains "VmmemWSL") {
                [PSCustomObject]@{ WorkingSet64 = 3GB }
            } else {
                $null
            }
        }

        Invoke-TestMonitorTask -ThresholdPct 40

        Test-Path (Get-TestCooldownPath) | Should -Be $true
    }

    It "calcule le pourcentage par rapport au plafond WSL2 configure, pas a la RAM totale" {
        # Plafond 4GB (fixture par defaut de New-TestWslConfig), 3GB utilises = 75%.
        # Sur une machine a, disons, 32GB de RAM totale, 3GB ne represente que
        # ~9% de la RAM physique - l'ancien calcul (RAM totale) ne se serait
        # jamais declenche a un seuil de 80%. C'est exactement le bug corrige.
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n" | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }

        Invoke-TestMonitorTask -ThresholdPct 70

        Test-Path (Get-TestCooldownPath) | Should -Be $true
    }

    It "n'ecrit pas de cooldown quand l'usage reste sous le seuil du plafond" {
        # 3GB / 4GB = 75%, sous un seuil de 80%.
        New-TestWslConfig | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }

        Invoke-TestMonitorTask -ThresholdPct 80

        Test-Path (Get-TestCooldownPath) | Should -Be $false
    }

    It "ecrit un cooldown horodate quand l'usage depasse le seuil du plafond" {
        # 3GB / 4GB = 75%, au-dessus d'un seuil de 40%.
        New-TestWslConfig | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }

        Invoke-TestMonitorTask -ThresholdPct 40

        Test-Path (Get-TestCooldownPath) | Should -Be $true
        {
            [datetime]::ParseExact((Get-Content (Get-TestCooldownPath) -Raw).Trim(), "yyyy-MM-dd HH:mm:ss", $null)
        } | Should -Not -Throw
    }

    It "ne reecrit pas une alerte recente (cooldown actif)" {
        New-TestWslConfig | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }
        $cooldownPath = Get-TestCooldownPath
        $recentAlert = (Get-Date).AddMinutes(-5).ToString("yyyy-MM-dd HH:mm:ss")
        $recentAlert | Set-Content -Path $cooldownPath -Encoding ASCII

        Invoke-TestMonitorTask -ThresholdPct 40 -CooldownMin 30

        (Get-Content $cooldownPath -Raw).Trim() | Should -Be $recentAlert
    }

    It "declenche une nouvelle alerte si le cooldown precedent est expire" {
        New-TestWslConfig | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }
        $cooldownPath = Get-TestCooldownPath
        $oldAlert = (Get-Date).AddMinutes(-45).ToString("yyyy-MM-dd HH:mm:ss")
        $oldAlert | Set-Content -Path $cooldownPath -Encoding ASCII

        Invoke-TestMonitorTask -ThresholdPct 40 -CooldownMin 30

        (Get-Content $cooldownPath -Raw).Trim() | Should -Not -Be $oldAlert
    }

    It "s'auto-repare quand le fichier cooldown est corrompu (illisible)" {
        New-TestWslConfig | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }
        $cooldownPath = Get-TestCooldownPath
        "pas-une-date-valide" | Set-Content -Path $cooldownPath -Encoding ASCII

        { Invoke-TestMonitorTask -ThresholdPct 40 -CooldownMin 30 } | Should -Not -Throw

        $newContent = (Get-Content $cooldownPath -Raw).Trim()
        {
            [datetime]::ParseExact($newContent, "yyyy-MM-dd HH:mm:ss", $null)
        } | Should -Not -Throw
        (Get-Content (Get-TestErrorLogPath) -Raw) | Should -Match "cooldown"
    }

    It "n'ecrit pas de cooldown et journalise l'erreur quand .wslconfig est absent" {
        # Pas de New-TestWslConfig ici : aucun plafond connu, donc aucun
        # pourcentage significatif calculable (principe 9 - une mesure qui
        # echoue doit le dire, jamais se rabattre sur une supposition).
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }

        { Invoke-TestMonitorTask -ThresholdPct 40 } | Should -Not -Throw

        Test-Path (Get-TestCooldownPath) | Should -Be $false
        (Get-Content (Get-TestErrorLogPath) -Raw) | Should -Match "[Pp]lafond"
    }

    It "n'ecrit pas de cooldown et journalise l'erreur quand .wslconfig n'a pas de cle memory=" {
        New-TestWslConfig -Content "[wsl2]`nprocessors=3`n" | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }

        { Invoke-TestMonitorTask -ThresholdPct 40 } | Should -Not -Throw

        Test-Path (Get-TestCooldownPath) | Should -Be $false
        (Get-Content (Get-TestErrorLogPath) -Raw) | Should -Match "[Pp]lafond"
    }

    It "accepte un plafond exprime en MB" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4096MB`nprocessors=3`n" | Out-Null
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 3GB } }

        Invoke-TestMonitorTask -ThresholdPct 40

        Test-Path (Get-TestCooldownPath) | Should -Be $true
    }
}
