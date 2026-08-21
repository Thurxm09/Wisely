# ============================================================
#  Logger.Tests.ps1 - Tests Pester pour modules/Logger.ps1
# ============================================================

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/../modules/Logger.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "Write-SwitchLog" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "cree l'historique et ajoute une entree avec la bonne forme" {
        Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "4GB, 3 CPU"

        $history = Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json
        $history = @($history)

        $history.Count | Should -Be 1
        $history[0].action | Should -Be "SWITCH"
        $history[0].profile | Should -Be "web"
        $history[0].details | Should -Be "4GB, 3 CPU"
        $history[0].timestamp | Should -Not -BeNullOrEmpty
    }

    It "empile les entrees dans l'ordre chronologique" {
        Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "premier"
        Write-SwitchLog -Action "SWITCH" -ProfileKey "data" -Details "second"

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)

        $history.Count | Should -Be 2
        $history[0].details | Should -Be "premier"
        $history[1].details | Should -Be "second"
    }

    It "ne plante pas si history.json est corrompu, et repart d'un historique vide" {
        Set-Content -Path (Get-HistoryPath) -Value "{ pas du JSON valide" -Encoding UTF8

        { Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "apres corruption" } | Should -Not -Throw

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history.Count | Should -Be 1
        $history[0].details | Should -Be "apres corruption"
    }
}

Describe "Show-SwitchHistory" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne leve pas d'exception quand history.json est absent" {
        { Show-SwitchHistory } | Should -Not -Throw
    }

    It "ne leve pas d'exception avec une seule entree" {
        Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "test"
        { Show-SwitchHistory } | Should -Not -Throw
    }

    It "ne leve pas d'exception avec plusieurs entrees et -Last" {
        1..5 | ForEach-Object { Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "entree $_" }
        { Show-SwitchHistory -Last 3 } | Should -Not -Throw
    }
}

Describe "Write-SwitchLog - historyMaxEntries configurable" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "garde 100 entrees par defaut quand historyMaxEntries n'est pas configure" {
        1..5 | ForEach-Object { Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "entree $_" }

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history.Count | Should -Be 5
    }

    It "n'ecrete l'historique qu'au-dela de historyMaxEntries configure dans profiles.json" {
        New-TestProfilesJson -Config @{ profiles = @{}; settings = @{ historyMaxEntries = 3 } }

        1..5 | ForEach-Object { Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "entree $_" }

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history.Count | Should -Be 3
        $history[0].details | Should -Be "entree 3"
        $history[-1].details | Should -Be "entree 5"
    }
}
