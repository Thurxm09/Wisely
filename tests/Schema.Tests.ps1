# ============================================================
#  Schema.Tests.ps1 - Validation JSON Schema de profiles.json et
#  history.json
# ============================================================

BeforeAll {
    $script:SchemaPath = "$PSScriptRoot/../schemas/profiles.schema.json"
    $script:RealProfilesPath = "$PSScriptRoot/../data/profiles.json"
    $script:HistorySchemaPath = "$PSScriptRoot/../schemas/history.schema.json"

    function script:Test-AgainstSchema {
        param([Parameter(Mandatory)][string]$Json)
        Test-Json -Json $Json -SchemaFile $script:SchemaPath
    }

    function script:Test-AgainstHistorySchema {
        param([Parameter(Mandatory)][string]$Json)
        Test-Json -Json $Json -SchemaFile $script:HistorySchemaPath
    }
}

Describe "profiles.schema.json" {

    It "valide le vrai data/profiles.json" {
        $json = Get-Content $script:RealProfilesPath -Raw
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "rejette un document sans la cle 'profiles'" {
        $json = @{ version = "2.1.0" } | ConvertTo-Json
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette un profil avec un type invalide (processors en chaine)" {
        $doc = @{
            version  = "2.1.0"
            profiles = @{
                web = @{
                    displayName = "WEB"
                    memory      = "4GB"
                    processors  = "trois"
                    swap        = "3GB"
                }
            }
        }
        $json = $doc | ConvertTo-Json -Depth 10
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette une propriete inconnue au niveau d'un profil" {
        $doc = @{
            version  = "2.1.0"
            profiles = @{
                web = @{
                    displayName = "WEB"
                    memory      = "4GB"
                    processors  = 3
                    swap        = "3GB"
                    unknownProp = "oops"
                }
            }
        }
        $json = $doc | ConvertTo-Json -Depth 10
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }
}

Describe "profiles.schema.json - settings" {

    BeforeAll {
        function script:New-TestDoc {
            param([hashtable]$Settings)
            $doc = @{
                version  = "2.1.0"
                profiles = @{
                    web = @{
                        displayName = "WEB"
                        memory      = "4GB"
                        processors  = 3
                        swap        = "3GB"
                    }
                }
            }
            if ($null -ne $Settings) {
                $doc.settings = $Settings
            }
            return $doc | ConvertTo-Json -Depth 10
        }
    }

    It "valide un document sans la cle 'settings' (optionnelle)" {
        $json = script:New-TestDoc -Settings $null
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "valide un objet 'settings' complet avec des valeurs correctes" {
        $json = script:New-TestDoc -Settings @{
            monitorThreshold       = 80
            monitorIntervalSeconds = 30
            historyMaxEntries      = 100
            backupEnabled          = $true
            backupHistoryMax       = 5
        }
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "valide un objet 'settings' partiel (sous-ensemble des cles)" {
        $json = script:New-TestDoc -Settings @{ monitorThreshold = 90 }
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "valide un objet 'settings' vide" {
        $json = script:New-TestDoc -Settings @{}
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "rejette monitorThreshold au-dessus de 100" {
        $json = script:New-TestDoc -Settings @{ monitorThreshold = 101 }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette monitorThreshold negatif" {
        $json = script:New-TestDoc -Settings @{ monitorThreshold = -1 }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette monitorIntervalSeconds a zero (exclusiveMinimum)" {
        $json = script:New-TestDoc -Settings @{ monitorIntervalSeconds = 0 }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette historyMaxEntries a zero (exclusiveMinimum)" {
        $json = script:New-TestDoc -Settings @{ historyMaxEntries = 0 }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette backupHistoryMax negatif" {
        $json = script:New-TestDoc -Settings @{ backupHistoryMax = -5 }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette backupEnabled d'un type invalide (chaine)" {
        $json = script:New-TestDoc -Settings @{ backupEnabled = "oui" }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette monitorThreshold d'un type invalide (chaine)" {
        $json = script:New-TestDoc -Settings @{ monitorThreshold = "80" }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette une propriete inconnue au niveau de 'settings'" {
        $json = script:New-TestDoc -Settings @{ unknownSetting = "oops" }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "valide guestReadConsent = 'granted'" {
        $json = script:New-TestDoc -Settings @{ guestReadConsent = "granted" }
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "valide guestReadConsent = 'revoked'" {
        $json = script:New-TestDoc -Settings @{ guestReadConsent = "revoked" }
        Test-AgainstSchema -Json $json | Should -Be $true
    }

    It "rejette guestReadConsent hors enum" {
        $json = script:New-TestDoc -Settings @{ guestReadConsent = "unset" }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette guestReadConsent d'un type invalide (booleen)" {
        $json = script:New-TestDoc -Settings @{ guestReadConsent = $true }
        Test-AgainstSchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }
}

Describe "history.schema.json" {

    BeforeAll {
        . "$PSScriptRoot/../modules/ProfileManager.ps1"
        . "$PSScriptRoot/../modules/Logger.ps1"
        . "$PSScriptRoot/TestHelpers.ps1"
    }

    It "valide un historique vide" {
        Test-AgainstHistorySchema -Json "[]" | Should -Be $true
    }

    It "valide un historique reel produit par Write-SwitchLog (avec et sans metrique v2.3)" {
        $testRoot = New-TestWslRoot
        try {
            Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "4GB, 3 CPU" -RestartSeconds 2.3
            Write-SwitchLog -Action "ROLLBACK" -ProfileKey "web" -Details "restaure"
            Write-SwitchLog -Action "EXPORT" -Details "C:/export.json"

            $json = Get-Content (Get-HistoryPath) -Raw
            Test-AgainstHistorySchema -Json $json | Should -Be $true
        } finally {
            Remove-TestWslRoot -Path $testRoot
        }
    }

    It "valide une entree CONSENT reelle produite par Write-SwitchLog" {
        $testRoot = New-TestWslRoot
        try {
            Write-SwitchLog -Action "CONSENT" -Details "guestReadConsent=granted"

            $json = Get-Content (Get-HistoryPath) -Raw
            Test-AgainstHistorySchema -Json $json | Should -Be $true
        } finally {
            Remove-TestWslRoot -Path $testRoot
        }
    }

    It "valide toujours une entree historique qui porte encore ramDeltaGB (donnees pre-v2.5)" {
        $doc = @(
            @{
                timestamp  = "2026-08-25 10:00:00"
                action     = "SWITCH"
                profile    = "web"
                details    = "4GB, 3 CPU"
                user       = "test"
                ramDeltaGB = 1.5
            }
        ) | ConvertTo-Json -Depth 5 -AsArray

        Test-AgainstHistorySchema -Json $doc | Should -Be $true
    }

    It "rejette une entree avec une action inconnue" {
        $doc = @(
            @{
                timestamp = "2026-08-25 10:00:00"
                action    = "TELEPORT"
                profile   = "web"
                details   = ""
                user      = "thuram"
            }
        )
        $json = $doc | ConvertTo-Json -Depth 10
        Test-AgainstHistorySchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette une entree avec ramDeltaGB d'un type invalide (chaine)" {
        $doc = @(
            @{
                timestamp  = "2026-08-25 10:00:00"
                action     = "SWITCH"
                profile    = "web"
                details    = ""
                user       = "thuram"
                ramDeltaGB = "beaucoup"
            }
        )
        $json = $doc | ConvertTo-Json -Depth 10
        Test-AgainstHistorySchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }

    It "rejette une propriete inconnue au niveau d'une entree" {
        $doc = @(
            @{
                timestamp   = "2026-08-25 10:00:00"
                action      = "SWITCH"
                profile     = "web"
                details     = ""
                user        = "thuram"
                unknownProp = "oops"
            }
        )
        $json = $doc | ConvertTo-Json -Depth 10
        Test-AgainstHistorySchema -Json $json -ErrorAction SilentlyContinue | Should -Be $false
    }
}
