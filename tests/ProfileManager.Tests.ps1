# ============================================================
#  ProfileManager.Tests.ps1 - Tests Pester pour modules/ProfileManager.ps1
#  Cible en priorite : Get-ProfileConfig et Import-Profiles (docs/ROADMAP.md)
# ============================================================

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/../modules/Logger.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"
}

# NOTE : $script:ProfileConfigCache est partage par tous les Describe
# puisque ProfileManager.ps1 n'est dot-source qu'une seule fois pour tout
# le fichier (BeforeAll) - sans reset, un test peut lire silencieusement
# le profiles.json mis en cache par un test precedent au lieu du sien.
# Un BeforeEach global hors Describe serait la solution la plus sure,
# mais Pester 6 le rejette ("Each test setup is not supported in root") :
# chaque Describe ci-dessous appelle donc Clear-ProfileConfigCache en
# premiere ligne de son propre BeforeEach.

function Get-ValidProfilesConfig {
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
            base = @{
                displayName = "BASE"
                description = "Mode minimal"
                color       = "Cyan"
                memory      = "2GB"
                processors  = 2
                swap        = "2GB"
                swapFile    = "/tmp/wisely-test-swap.vhdx"
                swappiness  = 20
            }
        }
        settings = @{
            monitorThreshold        = 80
            monitorIntervalSeconds  = 30
            historyMaxEntries       = 100
            backupEnabled           = $true
            backupHistoryMax        = 5
        }
    }
}

Describe "Get-ProfileConfig" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    Context "quand profiles.json est valide" {

        It "retourne un objet avec une cle 'profiles' non vide" {
            New-TestProfilesJson -Config (Get-ValidProfilesConfig)
            $result = Get-ProfileConfig
            $result.profiles | Should -Not -BeNullOrEmpty
        }

        It "expose les proprietes du profil tel qu'ecrites dans le fichier" {
            New-TestProfilesJson -Config (Get-ValidProfilesConfig)
            $result = Get-ProfileConfig
            $result.profiles.web.memory | Should -Be "4GB"
            $result.profiles.web.processors | Should -Be 3
            $result.profiles.base.displayName | Should -Be "BASE"
        }
    }

    Context "quand profiles.json est absent" {

        It "leve une exception avec le message attendu" {
            { Get-ProfileConfig } | Should -Throw "*profiles.json introuvable*"
        }
    }

    Context "quand profiles.json est vide" {

        It "leve une exception mentionnant un fichier vide" {
            Set-TestProfilesRaw -Content ""
            { Get-ProfileConfig } | Should -Throw "*profiles.json est vide*"
        }

        It "leve la meme exception pour un fichier ne contenant que des espaces" {
            Set-TestProfilesRaw -Content "   `n  "
            { Get-ProfileConfig } | Should -Throw "*profiles.json est vide*"
        }
    }

    Context "quand profiles.json contient un JSON invalide" {

        It "leve une exception mentionnant un JSON invalide" {
            Set-TestProfilesRaw -Content "{ ceci n est pas du JSON valide"
            { Get-ProfileConfig } | Should -Throw "*JSON invalide*"
        }
    }

    Context "quand la cle 'profiles' est manquante" {

        It "leve une exception mentionnant la cle manquante" {
            New-TestProfilesJson -Config @{ version = "2.0.0" }
            { Get-ProfileConfig } | Should -Throw "*cle manquante*"
        }
    }
}

Describe "Import-Profiles" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        $script:importSource = Join-Path $script:testRoot "import-source.json"
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    Context "quand le fichier a importer est introuvable" {

        It "leve une exception avec le message attendu" {
            $missing = Join-Path $script:testRoot "nexiste-pas.json"
            { Import-Profiles -Path $missing } | Should -Throw "*Fichier introuvable*"
        }
    }

    Context "quand le fichier a importer contient un JSON invalide" {

        It "leve une exception mentionnant un JSON invalide" {
            Set-Content -Path $script:importSource -Value "{ pas du JSON valide" -Encoding UTF8
            { Import-Profiles -Path $script:importSource } | Should -Throw "*JSON invalide*"
        }
    }

    Context "quand la cle 'profiles' est absente du fichier importe" {

        It "leve une exception mentionnant la cle 'profiles'" {
            @{ version = "2.0.0" } | ConvertTo-Json | Set-Content -Path $script:importSource -Encoding UTF8
            { Import-Profiles -Path $script:importSource } | Should -Throw "*cle 'profiles'*"
        }
    }

    Context "quand la cle 'version' est absente du fichier importe" {

        It "leve une exception mentionnant la cle 'version'" {
            @{ profiles = (Get-ValidProfilesConfig).profiles } | ConvertTo-Json -Depth 10 |
                Set-Content -Path $script:importSource -Encoding UTF8
            { Import-Profiles -Path $script:importSource } | Should -Throw "*cle 'version'*"
        }
    }

    Context "quand le fichier importe ne contient aucun profil" {

        It "leve une exception mentionnant l'absence de profil" {
            @{ version = "2.0.0"; profiles = @{} } | ConvertTo-Json | Set-Content -Path $script:importSource -Encoding UTF8
            { Import-Profiles -Path $script:importSource } | Should -Throw "*Aucun profil defini*"
        }
    }

    Context "quand le fichier importe est valide" {

        BeforeEach {
            # Pre-cree le profiles.json de destination (et son dossier parent)
            # pour que Copy-Item vers Get-ProfilesPath reste valide sur toutes
            # les plateformes, y compris Windows ou "data\" est un vrai sous-dossier.
            New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        }

        It "remplace le contenu de profiles.json par le fichier importe" {
            $config = Get-ValidProfilesConfig
            $config.version = "9.9.9"
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:importSource -Encoding UTF8

            Import-Profiles -Path $script:importSource

            $result = Get-ProfileConfig
            $result.version | Should -Be "9.9.9"
            $result.profiles.web.memory | Should -Be "4GB"
        }

        It "n'echoue pas meme sans .wslconfig prealable (aucun backup a faire)" {
            $config = Get-ValidProfilesConfig
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:importSource -Encoding UTF8

            { Import-Profiles -Path $script:importSource } | Should -Not -Throw
        }
    }
}

Describe "Test-SwapFilePath" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne leve pas d'exception quand le repertoire cible existe" {
        $swapFile = Join-Path $script:testRoot "wsl-swap.vhdx"
        { Test-SwapFilePath -SwapFile $swapFile } | Should -Not -Throw
    }

    It "leve une exception explicite quand le repertoire cible est introuvable" {
        $missingDir = Join-Path $script:testRoot "nexiste-pas"
        $swapFile   = Join-Path $missingDir "wsl-swap.vhdx"
        { Test-SwapFilePath -SwapFile $swapFile } | Should -Throw "*Repertoire du swap file introuvable*"
    }
}

Describe "Set-WslProfile - validation du swap file" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        Enable-WslMocks
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "rejette un profil dont le swapFile pointe vers un repertoire inexistant, sans jamais appeler wsl" {
        $config = Get-ValidProfilesConfig
        $missingDir = Join-Path $script:testRoot "nexiste-pas"
        $config.profiles.web.swapFile = Join-Path $missingDir "wsl-swap.vhdx"
        New-TestProfilesJson -Config $config

        { Set-WslProfile -Key "web" } | Should -Throw "*Validation du profil*"
        Should -Invoke -CommandName wsl -Times 0 -Exactly
    }

    It "rejette aussi en mode -DryRun (fail-fast avant tout effet de bord)" {
        $config = Get-ValidProfilesConfig
        $missingDir = Join-Path $script:testRoot "nexiste-pas"
        $config.profiles.web.swapFile = Join-Path $missingDir "wsl-swap.vhdx"
        New-TestProfilesJson -Config $config

        { Set-WslProfile -Key "web" -DryRun } | Should -Throw "*Validation du profil*"
    }

    It "accepte un profil dont le swapFile pointe vers un repertoire existant" {
        $config = Get-ValidProfilesConfig
        $config.profiles.web.swapFile = Join-Path $script:testRoot "wsl-swap.vhdx"
        New-TestProfilesJson -Config $config

        { Set-WslProfile -Key "web" -DryRun } | Should -Not -Throw
    }
}

Describe "Backup-WslConfig" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        New-TestWslConfig | Out-Null
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne fait rien si aucun .wslconfig n'existe" {
        Remove-Item (Get-WslConfigPath) -Force
        { Backup-WslConfig } | Should -Not -Throw
        Test-Path (Get-BackupDir) | Should -Be $false
    }

    It "cree un premier backup horodate au premier appel (fallback backupHistoryMax=5 si profiles.json absent)" {
        Backup-WslConfig
        $files = @(Get-ChildItem (Get-BackupDir) -Filter "wslconfig_*.backup")
        $files.Count | Should -Be 1
    }

    It "purge les plus anciens backups au-dela de backupHistoryMax" {
        $config = Get-ValidProfilesConfig
        $config.settings.backupHistoryMax = 3
        New-TestProfilesJson -Config $config

        $dir = Get-BackupDir
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        # Fabrique 5 backups pre-existants, horodates dans le passe (tries avant
        # celui que Backup-WslConfig va creer avec l'horodatage du jour).
        1..5 | ForEach-Object {
            $name = "wslconfig_2020010{0}_000000.backup" -f $_
            Set-Content -Path (Join-Path $dir $name) -Value "fixture-$_" -Encoding UTF8
        }

        Backup-WslConfig

        $remaining = @(Get-ChildItem $dir -Filter "wslconfig_*.backup" | Sort-Object Name)
        $remaining.Count | Should -Be 3
        $remaining[-1].Name | Should -Not -Match "^wslconfig_2020"
    }

    It "migre l'ancien backup unique pre-v2.1 s'il existe encore" {
        $legacy = Get-LegacyBackupPath
        Set-Content -Path $legacy -Value "ancien-backup" -Encoding UTF8

        Backup-WslConfig

        $files = @(Get-ChildItem (Get-BackupDir) -Filter "wslconfig_*.backup")
        $files.Count | Should -Be 2
    }
}

Describe "Invoke-Rollback" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        Enable-WslMocks
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "affiche un message et ne fait rien quand aucun backup n'existe" {
        { Invoke-Rollback } | Should -Not -Throw
        Test-Path (Get-WslConfigPath) | Should -Be $false
    }

    It "restaure le backup le plus recent et journalise un ROLLBACK" {
        $dir = Get-BackupDir
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -Path (Join-Path $dir "wslconfig_20200101_000000.backup") -Value "[wsl2]`nmemory=2GB`n" -Encoding UTF8
        Set-Content -Path (Join-Path $dir "wslconfig_20260101_000000.backup") -Value "[wsl2]`nmemory=6GB`n" -Encoding UTF8

        Invoke-Rollback

        (Get-Content (Get-WslConfigPath) -Raw) | Should -Match "memory=6GB"

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history[-1].action | Should -Be "ROLLBACK"
        $history[-1].details | Should -Match "wslconfig_20260101_000000.backup"
    }
}

Describe "Get-ProfileConfig cache" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "ne relit pas le fichier au second appel (le cache survit meme si le fichier disparait)" {
        Get-ProfileConfig | Out-Null
        Remove-Item (Get-ProfilesPath) -Force

        { Get-ProfileConfig } | Should -Not -Throw
        (Get-ProfileConfig).profiles.web.memory | Should -Be "4GB"
    }

    It "Clear-ProfileConfigCache force un re-read depuis le disque" {
        Get-ProfileConfig | Out-Null
        Remove-Item (Get-ProfilesPath) -Force

        Clear-ProfileConfigCache

        { Get-ProfileConfig } | Should -Throw "*profiles.json introuvable*"
    }

    It "Import-Profiles invalide le cache de facon transparente" {
        Get-ProfileConfig | Out-Null

        $newConfig = Get-ValidProfilesConfig
        $newConfig.version = "3.0.0"
        $importSource = Join-Path $script:testRoot "import-source.json"
        $newConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $importSource -Encoding UTF8

        Import-Profiles -Path $importSource

        (Get-ProfileConfig).version | Should -Be "3.0.0"
    }

    It "New-CustomProfile invalide le cache de facon transparente" {
        Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 8 } }

        Get-ProfileConfig | Out-Null

        New-CustomProfile -Key "gaming" -Memory "8GB" -Processors 1 -Description "Test"

        (Get-ProfileConfig).profiles.gaming.memory | Should -Be "8GB"
    }
}

Describe "Show-WslConfigDiff" {

    It "ne leve pas d'exception avec deux contenus vides" {
        { Show-WslConfigDiff -Old "" -New "" } | Should -Not -Throw
    }

    It "n'affiche que les lignes qui changent reellement" {
        $old = "[wsl2]`nmemory=2GB`nprocessors=2`nswap=2GB`n"
        $new = "[wsl2]`nmemory=4GB`nprocessors=3`nswap=2GB`n"

        $output = Show-WslConfigDiff -Old $old -New $new 6>&1 | Out-String

        $output | Should -Match "- memory=2GB"
        $output | Should -Match "\+ memory=4GB"
        $output | Should -Match "- processors=2"
        $output | Should -Match "\+ processors=3"
        # Ligne identique dans old/new : ne doit apparaitre ni en '-' ni en '+'
        $output | Should -Not -Match "[+-] swap=2GB"
    }
}
