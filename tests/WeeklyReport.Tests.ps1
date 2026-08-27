# ============================================================
#  WeeklyReport.Tests.ps1 - Tests Pester pour modules/WeeklyReport.ps1
# ============================================================
#
#  WeeklyReport.ps1 n'est jamais dot-source (il utilise "exit" en tete de
#  script - meme raison que MonitorTask.Tests.ps1). Il est execute via
#  l'operateur d'appel "&" sur une copie du script reelle placee sous
#  $Global:WSLRoot/modules, car le script derive ses chemins de
#  $PSScriptRoot et non de $Global:WSLRoot (voir AUDIT.md).

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"

    function script:Invoke-TestWeeklyReport {
        param([switch]$Silent)
        $modulesDir = Join-Path $Global:WSLRoot "modules"
        New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
        $dest = Join-Path $modulesDir "WeeklyReport.ps1"
        Copy-Item -Path "$PSScriptRoot/../modules/WeeklyReport.ps1" -Destination $dest -Force
        if ($Silent) {
            return (& $dest -Silent 6>&1 | Out-String)
        }
        return (& $dest 6>&1 | Out-String)
    }

    function script:New-TestHistoryEntry {
        param(
            [string]$ProfileKey,
            [datetime]$When,
            [string]$Details = "test",
            [Nullable[double]]$RamDeltaGB = $null
        )
        return @{
            action     = "SWITCH"
            profile    = $ProfileKey
            details    = $Details
            timestamp  = $When.ToString("yyyy-MM-dd HH:mm:ss")
            ramDeltaGB = $RamDeltaGB
        }
    }

    function script:Set-TestHistory {
        param([array]$Entries)
        $historyPath = Join-Path $Global:WSLRoot "data\history.json"
        $Entries | ConvertTo-Json -Depth 5 -AsArray | Set-Content -Path $historyPath -Encoding UTF8
    }

    function script:Get-TestReportPath {
        param([datetime]$Date = (Get-Date))
        Join-Path $Global:WSLRoot ("data\reports\report_" + $Date.ToString("yyyy-MM-dd") + ".txt")
    }
}

Describe "WeeklyReport.ps1 - cas vides" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "cree le dossier reports meme sans historique, mais n'ecrit aucun rapport" {
        Invoke-TestWeeklyReport -Silent

        Test-Path (Join-Path $Global:WSLRoot "data\reports") | Should -Be $true
        Test-Path (Get-TestReportPath) | Should -Be $false
    }

    It "signale l'absence d'historique en mode non silencieux" {
        $output = Invoke-TestWeeklyReport

        $output | Should -Match "Aucun historique disponible"
    }

    It "ne produit aucune sortie en mode -Silent quand l'historique est absent" {
        $output = Invoke-TestWeeklyReport -Silent

        $output | Should -BeNullOrEmpty
    }

    It "signale un historique vide sans lever d'exception" {
        Set-TestHistory -Entries @()

        { Invoke-TestWeeklyReport } | Should -Not -Throw
        Test-Path (Get-TestReportPath) | Should -Be $false
    }

    It "signale un historique corrompu (JSON invalide) sans lever d'exception" {
        $historyPath = Join-Path $Global:WSLRoot "data\history.json"
        Set-Content -Path $historyPath -Value "{ pas du JSON valide" -Encoding UTF8

        $output = Invoke-TestWeeklyReport

        $output | Should -Match "Historique corrompu"
        Test-Path (Get-TestReportPath) | Should -Be $false
    }

    It "ne produit aucune sortie en mode -Silent meme quand l'historique est corrompu" {
        $historyPath = Join-Path $Global:WSLRoot "data\history.json"
        Set-Content -Path $historyPath -Value "{ pas du JSON valide" -Encoding UTF8

        { Invoke-TestWeeklyReport -Silent } | Should -Not -Throw

        $output = Invoke-TestWeeklyReport -Silent
        $output | Should -BeNullOrEmpty
    }
}

Describe "WeeklyReport.ps1 - generation du rapport" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "genere un rapport avec repartition par profil et profil dominant" {
        Set-TestHistory -Entries @(
            (New-TestHistoryEntry -ProfileKey "web"  -When (Get-Date).AddHours(-2))
            (New-TestHistoryEntry -ProfileKey "web"  -When (Get-Date).AddHours(-1))
            (New-TestHistoryEntry -ProfileKey "data" -When (Get-Date).AddMinutes(-30))
        )

        Invoke-TestWeeklyReport -Silent

        Test-Path (Get-TestReportPath) | Should -Be $true
        $content = Get-Content (Get-TestReportPath) -Raw
        $content | Should -Match "Repartition par profil"
        $content | Should -Match "Profil dominant\s*:\s*WEB \(2 activations\)"
        $content | Should -Match "Total de switchs\s*:\s*3"
    }

    It "ignore les switchs vieux de plus de 7 jours" {
        Set-TestHistory -Entries @(
            (New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddDays(-10))
            (New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-1))
            (New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-2))
        )

        Invoke-TestWeeklyReport -Silent

        $content = Get-Content (Get-TestReportPath) -Raw
        $content | Should -Match "Total de switchs\s*:\s*2"
    }

    It "inclut la derniere alerte RAM et les erreurs toast quand ces fichiers existent" {
        Set-TestHistory -Entries @((New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-1)))
        Set-Content -Path (Join-Path $Global:WSLRoot "data\monitor_cooldown.txt") -Value "2026-08-21 10:00:00" -Encoding UTF8
        Set-Content -Path (Join-Path $Global:WSLRoot "data\monitor_errors.txt") -Value "[2026-08-21 10:00:00] Toast error : test" -Encoding UTF8

        Invoke-TestWeeklyReport -Silent

        $content = Get-Content (Get-TestReportPath) -Raw
        $content | Should -Match "Derniere alerte RAM"
        $content | Should -Match "Erreurs Toast"
    }

    It "exclut une entree au timestamp malforme sans faire echouer tout le rapport" {
        $goodEntry = New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-1)
        $badEntry  = New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-2)
        $badEntry.timestamp = "pas-un-timestamp-valide"

        Set-TestHistory -Entries @($goodEntry, $badEntry)

        { Invoke-TestWeeklyReport -Silent } | Should -Not -Throw

        $content = Get-Content (Get-TestReportPath) -Raw
        $content | Should -Match "Total de switchs\s*:\s*1"
    }

    It "conserve au maximum 12 rapports (rotation, plus ancien supprime en premier)" {
        $reportsDir = Join-Path $Global:WSLRoot "data\reports"
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
        1..12 | ForEach-Object {
            $day = "2020-01-{0:D2}" -f $_
            Set-Content -Path (Join-Path $reportsDir "report_$day.txt") -Value "ancien rapport" -Encoding UTF8
        }
        Set-TestHistory -Entries @((New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-1)))

        Invoke-TestWeeklyReport -Silent

        $remaining = Get-ChildItem $reportsDir -Filter "report_*.txt"
        $remaining.Count | Should -Be 12
        Test-Path (Join-Path $reportsDir "report_2020-01-01.txt") | Should -Be $false
        Test-Path (Get-TestReportPath) | Should -Be $true
    }
}

Describe "WeeklyReport.ps1 - section RAM moyenne par profil retiree (v2.5)" {
    # La section "RAM liberee/consommee en moyenne au switch" reposait sur
    # ramDeltaGB, qui mesurait en realite l'arret de la session PRECEDENTE
    # tout en etant attribue au profil CIBLE - une mesure non attribuable
    # (RESOURCE-MODEL.md, grandeurs refusees ; principe 9). Retiree du
    # rapport, comme l'exige docs/TASKS.md, plutot que corrigee : le vrai
    # remplacement (contrat avant/apres post-restart) est planifie P6.

    BeforeEach {
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "n'affiche jamais la section RAM moyenne, meme si l'historique porte encore ramDeltaGB (donnees pre-v2.5)" {
        Set-TestHistory -Entries @(
            (New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-2) -RamDeltaGB 1.2)
            (New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-1) -RamDeltaGB 1.6)
        )

        Invoke-TestWeeklyReport -Silent

        $content = Get-Content (Get-TestReportPath) -Raw
        $content | Should -Not -Match "RAM liberee/consommee en moyenne au switch"
    }

    It "n'affiche pas la section sur un historique sans ramDeltaGB non plus" {
        Set-TestHistory -Entries @(
            (New-TestHistoryEntry -ProfileKey "web" -When (Get-Date).AddHours(-1))
        )

        Invoke-TestWeeklyReport -Silent

        $content = Get-Content (Get-TestReportPath) -Raw
        $content | Should -Not -Match "RAM liberee/consommee en moyenne au switch"
    }
}
