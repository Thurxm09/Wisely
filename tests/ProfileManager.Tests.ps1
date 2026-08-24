# ============================================================
#  ProfileManager.Tests.ps1 - Tests Pester pour modules/ProfileManager.ps1
#  Cible en priorite : Get-ProfileConfig et Import-Profiles (docs/ROADMAP.md)
# ============================================================

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/../modules/Logger.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"

    # Definie ici (scope script, pas dans un simple "function" au niveau
    # racine du fichier) : Pester 6 n'expose pas les fonctions declarees
    # hors BeforeAll/BeforeEach aux blocs It (phase "run" separee de la
    # phase "discovery").
    function script:Get-ValidProfilesConfig {
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
}

# NOTE : $script:ProfileConfigCache est partage par tous les Describe
# puisque ProfileManager.ps1 n'est dot-source qu'une seule fois pour tout
# le fichier (BeforeAll) - sans reset, un test peut lire silencieusement
# le profiles.json mis en cache par un test precedent au lieu du sien.
# Un BeforeEach global hors Describe serait la solution la plus sure,
# mais Pester 6 le rejette ("Each test setup is not supported in root") :
# chaque Describe ci-dessous appelle donc Clear-ProfileConfigCache en
# premiere ligne de son propre BeforeEach.

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
        # Test-ProfileDefinition (appelee sur chaque profil importe depuis
        # AUDIT.md C-1) verifie le nombre de CPU via Get-CimInstance -
        # absente sur le runner Linux de la CI, meme piege que "wsl".
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 8 } }
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

    Context "quand un profil du fichier importe est invalide" {

        BeforeEach {
            New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        }

        It "leve une exception quand un profil a une memoire mal formee" {
            $config = Get-ValidProfilesConfig
            $config.profiles.web.memory = "pasunememoire"
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:importSource -Encoding UTF8

            { Import-Profiles -Path $script:importSource } | Should -Throw "*memoire invalide*"
        }

        It "leve une exception quand un profil demande plus de CPU que la machine n'en a" {
            $config = Get-ValidProfilesConfig
            $config.profiles.web.processors = 99

            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:importSource -Encoding UTF8

            { Import-Profiles -Path $script:importSource } | Should -Throw "*CPU invalide*"
        }

        It "leve une exception quand un champ contient une injection de nouvelle ligne" {
            $config = Get-ValidProfilesConfig
            $config.profiles.web.swappiness = "10`nnestedVirtualization=true"
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:importSource -Encoding UTF8

            { Import-Profiles -Path $script:importSource } | Should -Throw "*swappiness*"
        }

        It "ne modifie pas profiles.json quand la validation echoue" {
            $config = Get-ValidProfilesConfig
            $config.profiles.web.memory = "pasunememoire"
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $script:importSource -Encoding UTF8

            try { Import-Profiles -Path $script:importSource } catch { }

            $result = Get-ProfileConfig
            $result.profiles.web.memory | Should -Not -Be "pasunememoire"
        }
    }
}

Describe "Resolve-ProfilePaths" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:originalTemp = $env:TEMP
        $script:originalUserProfile = $env:USERPROFILE
        $script:originalLocalAppData = $env:LOCALAPPDATA
    }

    AfterEach {
        $env:TEMP = $script:originalTemp
        $env:USERPROFILE = $script:originalUserProfile
        $env:LOCALAPPDATA = $script:originalLocalAppData
    }

    It "etend %TEMP% dans swapFile" {
        $env:TEMP = "C:/Users/test/AppData/Local/Temp"
        $original = [PSCustomObject]@{ displayName = "TEST"; swapFile = "%TEMP%/wisely-swap.vhdx" }

        $resolved = Resolve-ProfilePaths -ProfileDef $original

        $resolved.swapFile | Should -Be "C:/Users/test/AppData/Local/Temp/wisely-swap.vhdx"
    }

    It "etend %USERPROFILE% dans swapFile" {
        $env:USERPROFILE = "C:/Users/test"
        $original = [PSCustomObject]@{ displayName = "TEST"; swapFile = "%USERPROFILE%/wisely-swap.vhdx" }

        $resolved = Resolve-ProfilePaths -ProfileDef $original

        $resolved.swapFile | Should -Be "C:/Users/test/wisely-swap.vhdx"
    }

    It "etend %LOCALAPPDATA% dans swapFile" {
        $env:LOCALAPPDATA = "C:/Users/test/AppData/Local"
        $original = [PSCustomObject]@{ displayName = "TEST"; swapFile = "%LOCALAPPDATA%/wisely-swap.vhdx" }

        $resolved = Resolve-ProfilePaths -ProfileDef $original

        $resolved.swapFile | Should -Be "C:/Users/test/AppData/Local/wisely-swap.vhdx"
    }

    It "laisse un chemin litteral inchange" {
        $original = [PSCustomObject]@{ displayName = "TEST"; swapFile = "C:/Temp/wsl-swap.vhdx" }

        $resolved = Resolve-ProfilePaths -ProfileDef $original

        $resolved.swapFile | Should -Be "C:/Temp/wsl-swap.vhdx"
    }

    It "ne mute jamais l'objet original passe en parametre" {
        $env:TEMP = "C:/Users/test/AppData/Local/Temp"
        $original = [PSCustomObject]@{ displayName = "TEST"; swapFile = "%TEMP%/wisely-swap.vhdx" }

        Resolve-ProfilePaths -ProfileDef $original | Out-Null

        $original.swapFile | Should -Be "%TEMP%/wisely-swap.vhdx"
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

Describe "Get-AvailableRamGB" {

    BeforeEach {
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
    }

    It "convertit FreePhysicalMemory (KB) en GB arrondi a 2 decimales" {
        Mock Get-CimInstance { [PSCustomObject]@{ FreePhysicalMemory = 8000000 } }

        Get-AvailableRamGB | Should -Be 7.63
    }

    It "retourne `$null si la mesure echoue, sans lever d'exception" {
        Mock Get-CimInstance { throw "WMI indisponible" }

        { Get-AvailableRamGB } | Should -Not -Throw
        Get-AvailableRamGB | Should -Be $null
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

    It "accepte et etend un profil dont le swapFile utilise %TEMP%" {
        $config = Get-ValidProfilesConfig
        $config.profiles.web.swapFile = "%TEMP%/wisely-swap.vhdx"
        New-TestProfilesJson -Config $config
        $originalTemp = $env:TEMP
        $env:TEMP = $script:testRoot

        try {
            { Set-WslProfile -Key "web" -DryRun } | Should -Not -Throw
        } finally {
            $env:TEMP = $originalTemp
        }
    }
}

Describe "Set-WslProfile - switch reussi et metriques (RAM, temps de redemarrage)" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        Enable-WslMocks
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        $config = Get-ValidProfilesConfig
        $config.profiles.web.swapFile = Join-Path $script:testRoot "wsl-swap.vhdx"
        New-TestProfilesJson -Config $config
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "applique le profil, ecrit .wslconfig et journalise un SWITCH" {
        Mock Get-CimInstance { [PSCustomObject]@{ FreePhysicalMemory = 8000000 } }

        Set-WslProfile -Key "web"

        (Get-Content (Get-WslConfigPath) -Raw) | Should -Match "memory=4GB"
        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history[-1].action | Should -Be "SWITCH"
        $history[-1].profile | Should -Be "web"
    }

    It "mesure et journalise le delta de RAM disponible (avant/apres)" {
        $script:ramCallCount = 0
        Mock Get-CimInstance {
            $script:ramCallCount++
            if ($script:ramCallCount -eq 1) {
                return [PSCustomObject]@{ FreePhysicalMemory = 4000000 }
            }
            return [PSCustomObject]@{ FreePhysicalMemory = 6000000 }
        }

        Set-WslProfile -Key "web"

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $entry = $history[-1]
        $entry.ramDeltaGB | Should -Be 1.91
        $entry.details | Should -Match "RAM \+1.91GB"
    }

    It "journalise quand meme restartSeconds si la mesure RAM echoue (metrique optionnelle)" {
        Mock Get-CimInstance { throw "WMI indisponible" }

        { Set-WslProfile -Key "web" } | Should -Not -Throw

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $entry = $history[-1]
        $entry.ramDeltaGB | Should -Be $null
        $entry.restartSeconds | Should -Not -BeNullOrEmpty
        $entry.details | Should -Not -Match "RAM"
    }

    It "declenche un rollback automatique quand .wslconfig est invalide apres ecriture" {
        Mock Get-CimInstance { [PSCustomObject]@{ FreePhysicalMemory = 8000000 } }
        Mock Test-WslConfigIntegrity { $false }
        $dir = Get-BackupDir
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -Path (Join-Path $dir "wslconfig_20200101_000000.backup") -Value "[wsl2]`nmemory=2GB`n" -Encoding UTF8

        Set-WslProfile -Key "web"

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history[-1].action | Should -Be "ROLLBACK"
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

    Context "backupEnabled = `$false" {

        It "ne cree aucun backup quand backupEnabled est desactive dans profiles.json" {
            $config = Get-ValidProfilesConfig
            $config.settings.backupEnabled = $false
            New-TestProfilesJson -Config $config

            Backup-WslConfig

            Test-Path (Get-BackupDir) | Should -Be $false
        }
    }
}

Describe "Get-BackupHistoryMax" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "retombe sur le defaut (5) quand backupHistoryMax est negatif" {
        $config = Get-ValidProfilesConfig
        $config.settings.backupHistoryMax = -1
        New-TestProfilesJson -Config $config

        Get-BackupHistoryMax | Should -Be 5
    }

    It "retombe sur le defaut (5) quand backupHistoryMax est nul" {
        $config = Get-ValidProfilesConfig
        $config.settings.backupHistoryMax = 0
        New-TestProfilesJson -Config $config

        Get-BackupHistoryMax | Should -Be 5
    }

    It "utilise backupHistoryMax tel quel quand il est positif" {
        $config = Get-ValidProfilesConfig
        $config.settings.backupHistoryMax = 3
        New-TestProfilesJson -Config $config

        Get-BackupHistoryMax | Should -Be 3
    }
}

Describe "Test-WslConfigIntegrity" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "retourne `$false quand .wslconfig est absent" {
        Test-WslConfigIntegrity | Should -Be $false
    }

    It "retourne `$false quand la section [wsl2] est absente" {
        New-TestWslConfig -Content "memory=4GB`nprocessors=3`n"
        Test-WslConfigIntegrity | Should -Be $false
    }

    It "retourne `$false quand la cle memory= est absente" {
        New-TestWslConfig -Content "[wsl2]`nprocessors=3`n"
        Test-WslConfigIntegrity | Should -Be $false
    }

    It "retourne `$false quand la cle processors= est absente" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`n"
        Test-WslConfigIntegrity | Should -Be $false
    }

    It "retourne `$true quand les trois cles requises sont presentes" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
        Test-WslConfigIntegrity | Should -Be $true
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
        # Import-Profiles et New-CustomProfile (Test-ProfileDefinition,
        # AUDIT.md C-1) appellent Get-CimInstance - absente sur le runner
        # Linux de la CI, meme piege que "wsl".
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 8 } }
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
        # Get-CimInstance (module CimCmdlets) n'existe pas sur le runner
        # Linux de la CI - meme piege que "wsl" (Pester refuse de mocker
        # une commande totalement introuvable), on la stub d'abord.
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
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

Describe "Format-StatusShort" {

    It "formate le profil actif en une ligne compacte '[WSL:nom memoire]'" {
        $activeProfile = [PSCustomObject]@{ name = "WEB"; memory = "4GB" }

        Format-StatusShort -ActiveProfile $activeProfile | Should -Be "[WSL:WEB 4GB]"
    }
}

Describe "New-SnapshotProfile" {

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

    It "leve une exception si aucun .wslconfig n'est actif" {
        { New-SnapshotProfile } | Should -Throw "*Aucun .wslconfig actif*"
    }

    It "cree un profil snapshot a partir du profil actif, avec le top des process en description" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
        Mock Get-Process {
            @(
                [PSCustomObject]@{ ProcessName = "chrome"; WorkingSet64 = 500MB }
                [PSCustomObject]@{ ProcessName = "code"; WorkingSet64 = 400MB }
            )
        }

        $key = New-SnapshotProfile

        $key | Should -Match "^snapshot-\d{8}-\d{6}$"
        $config = Get-ProfileConfig
        $config.profiles.$key.memory | Should -Be "4GB"
        $config.profiles.$key.processors | Should -Be 3
        $config.profiles.$key.description | Should -Match "chrome"
    }

    It "invalide le cache de facon transparente" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
        Mock Get-Process { @([PSCustomObject]@{ ProcessName = "test"; WorkingSet64 = 100MB }) }

        Get-ProfileConfig | Out-Null

        $key = New-SnapshotProfile

        (Get-ProfileConfig).profiles.$key.memory | Should -Be "4GB"
    }

    It "enregistre une entree CUSTOM dans l'historique" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
        Mock Get-Process { @([PSCustomObject]@{ ProcessName = "test"; WorkingSet64 = 100MB }) }

        $key = New-SnapshotProfile

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $entry = $history | Where-Object { $_.profile -eq $key }
        $entry.action | Should -Be "CUSTOM"
    }
}

Describe "Get-ActiveProfile" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "retourne 'Non configure' quand .wslconfig est absent" {
        $result = Get-ActiveProfile

        $result.name | Should -Be "Non configure"
        $result.key | Should -Be ""
        $result.memory | Should -Be "N/A"
    }

    It "reconnait le profil actif quand la memoire correspond a un profil connu" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null

        $result = Get-ActiveProfile

        $result.name | Should -Be "WEB"
        $result.key | Should -Be "web"
        $result.processors | Should -Be "3"
    }

    It "retourne 'Personnalise' quand la memoire ne correspond a aucun profil connu" {
        New-TestWslConfig -Content "[wsl2]`nmemory=7GB`nprocessors=3`n"
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null

        $result = Get-ActiveProfile

        $result.name | Should -Be "Personnalise"
        $result.key | Should -Be "custom"
    }

    It "retient le premier profil du fichier en cas de memoire identique entre plusieurs profils" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nprocessors=3`n"
        # JSON brut plutot qu'une hashtable : l'ordre des proprietes d'une
        # hashtable @{} n'est pas garanti, ce test depend explicitement de
        # l'ordre "alpha avant beta".
        $json = '{"profiles":{"alpha":{"displayName":"ALPHA","memory":"4GB"},"beta":{"displayName":"BETA","memory":"4GB"}}}'
        $config = $json | ConvertFrom-Json

        $result = Get-ActiveProfile -Config $config

        $result.key | Should -Be "alpha"
    }
}

Describe "Export-Profiles" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        $script:exportPath = Join-Path $script:testRoot "export.json"
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "copie profiles.json vers le chemin cible" {
        Export-Profiles -Path $script:exportPath

        Test-Path $script:exportPath | Should -Be $true
        $exported = Get-Content $script:exportPath -Raw | ConvertFrom-Json
        $exported.profiles.web.memory | Should -Be "4GB"
    }

    It "journalise une entree EXPORT avec le chemin cible" {
        Export-Profiles -Path $script:exportPath

        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history[-1].action | Should -Be "EXPORT"
        $history[-1].details | Should -Be $script:exportPath
    }
}

Describe "New-CustomProfile" {

    BeforeEach {
        Clear-ProfileConfigCache
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        New-TestProfilesJson -Config (Get-ValidProfilesConfig) | Out-Null
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Get-CimInstance { [PSCustomObject]@{ NumberOfLogicalProcessors = 8 } }
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "leve une exception quand la memoire est mal formee" {
        { New-CustomProfile -Key "gaming" -Memory "pasunememoire" -Processors 2 } | Should -Throw "*memoire invalide*"
    }

    It "leve une exception quand le nombre de CPU est 0" {
        { New-CustomProfile -Key "gaming" -Memory "8GB" -Processors 0 } | Should -Throw "*CPU invalide*"
    }

    It "leve une exception quand le nombre de CPU depasse les CPU logiques disponibles" {
        { New-CustomProfile -Key "gaming" -Memory "8GB" -Processors 99 } | Should -Throw "*CPU invalide*"
    }

    It "cree un profil avec la forme attendue quand les parametres sont valides" {
        New-CustomProfile -Key "gaming" -Memory "8GB" -Processors 4 -Description "Jeux"

        $profile = (Get-ProfileConfig).profiles.gaming
        $profile.displayName | Should -Be "GAMING"
        $profile.description | Should -Be "Jeux"
        $profile.memory | Should -Be "8GB"
        $profile.processors | Should -Be 4
    }
}
