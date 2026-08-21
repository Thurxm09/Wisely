# ============================================================
#  Schema.Tests.ps1 - Validation JSON Schema de profiles.json
# ============================================================

BeforeAll {
    $script:SchemaPath = "$PSScriptRoot/../schemas/profiles.schema.json"
    $script:RealProfilesPath = "$PSScriptRoot/../data/profiles.json"

    function script:Test-AgainstSchema {
        param([Parameter(Mandatory)][string]$Json)
        Test-Json -Json $Json -SchemaFile $script:SchemaPath
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
