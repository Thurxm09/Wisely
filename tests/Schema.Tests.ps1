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

Describe "history.schema.json" {

    BeforeAll {
        . "$PSScriptRoot/../modules/ProfileManager.ps1"
        . "$PSScriptRoot/../modules/Logger.ps1"
        . "$PSScriptRoot/TestHelpers.ps1"
    }

    It "valide un historique vide" {
        Test-AgainstHistorySchema -Json "[]" | Should -Be $true
    }

    It "valide un historique reel produit par Write-SwitchLog (avec et sans metriques v2.3)" {
        $testRoot = New-TestWslRoot
        try {
            Write-SwitchLog -Action "SWITCH" -ProfileKey "web" -Details "4GB, 3 CPU" -RamDeltaGB 1.5 -RestartSeconds 2.3
            Write-SwitchLog -Action "ROLLBACK" -ProfileKey "web" -Details "restaure"
            Write-SwitchLog -Action "EXPORT" -Details "C:/export.json"

            $json = Get-Content (Get-HistoryPath) -Raw
            Test-AgainstHistorySchema -Json $json | Should -Be $true
        } finally {
            Remove-TestWslRoot -Path $testRoot
        }
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
