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

BeforeAll {
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
        # Get-CimInstance (module CimCmdlets) n'existe pas sur le runner
        # Linux de la CI - meme piege que "wsl", stub avant de mocker.
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Get-CimInstance { [PSCustomObject]@{ TotalVisibleMemorySize = 16000000 } }
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne fait rien si le process vmmem est absent" {
        Mock Get-Process { $null }

        Invoke-TestMonitorTask

        Test-Path (Get-TestCooldownPath) | Should -Be $false
        Should -Invoke -CommandName Get-CimInstance -Times 0 -Exactly
    }

    It "n'ecrit pas de cooldown quand la RAM utilisee reste sous le seuil" {
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 8000000000 } }

        Invoke-TestMonitorTask -ThresholdPct 80

        Test-Path (Get-TestCooldownPath) | Should -Be $false
    }

    It "ecrit un cooldown horodate quand la RAM utilisee depasse le seuil" {
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 8000000000 } }

        Invoke-TestMonitorTask -ThresholdPct 40

        Test-Path (Get-TestCooldownPath) | Should -Be $true
        {
            [datetime]::ParseExact((Get-Content (Get-TestCooldownPath) -Raw).Trim(), "yyyy-MM-dd HH:mm:ss", $null)
        } | Should -Not -Throw
    }

    It "ne reecrit pas une alerte recente (cooldown actif)" {
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 8000000000 } }
        $cooldownPath = Get-TestCooldownPath
        $recentAlert = (Get-Date).AddMinutes(-5).ToString("yyyy-MM-dd HH:mm:ss")
        $recentAlert | Set-Content -Path $cooldownPath -Encoding ASCII

        Invoke-TestMonitorTask -ThresholdPct 40 -CooldownMin 30

        (Get-Content $cooldownPath -Raw).Trim() | Should -Be $recentAlert
    }

    It "declenche une nouvelle alerte si le cooldown precedent est expire" {
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 8000000000 } }
        $cooldownPath = Get-TestCooldownPath
        $oldAlert = (Get-Date).AddMinutes(-45).ToString("yyyy-MM-dd HH:mm:ss")
        $oldAlert | Set-Content -Path $cooldownPath -Encoding ASCII

        Invoke-TestMonitorTask -ThresholdPct 40 -CooldownMin 30

        (Get-Content $cooldownPath -Raw).Trim() | Should -Not -Be $oldAlert
    }

    It "s'auto-repare quand le fichier cooldown est corrompu (illisible)" {
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 8000000000 } }
        $cooldownPath = Get-TestCooldownPath
        "pas-une-date-valide" | Set-Content -Path $cooldownPath -Encoding ASCII

        { Invoke-TestMonitorTask -ThresholdPct 40 -CooldownMin 30 } | Should -Not -Throw

        $newContent = (Get-Content $cooldownPath -Raw).Trim()
        {
            [datetime]::ParseExact($newContent, "yyyy-MM-dd HH:mm:ss", $null)
        } | Should -Not -Throw
        (Get-Content (Get-TestErrorLogPath) -Raw) | Should -Match "cooldown"
    }

    It "n'ecrit pas de cooldown et journalise l'erreur quand la mesure RAM (CIM) echoue" {
        Mock Get-Process { [PSCustomObject]@{ WorkingSet64 = 8000000000 } }
        Mock Get-CimInstance { throw "WMI indisponible" }

        { Invoke-TestMonitorTask -ThresholdPct 40 } | Should -Not -Throw

        Test-Path (Get-TestCooldownPath) | Should -Be $false
        (Get-Content (Get-TestErrorLogPath) -Raw) | Should -Match "Mesure RAM impossible"
    }
}
