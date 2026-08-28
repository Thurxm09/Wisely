# ============================================================
#  Diagnose.Tests.ps1 - Tests Pester pour modules/Diagnose.ps1
#  wisely diagnose (P2/v3.0 "Diagnostic")
# ============================================================

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/../modules/Logger.ps1"
    . "$PSScriptRoot/../modules/GuestReader.ps1"
    . "$PSScriptRoot/../modules/Diagnose.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"

    function script:New-TestConfig {
        return @{ version = "3.0.0"; profiles = @{ web = @{ displayName = "WEB"; memory = "4GB"; processors = 3; swap = "3GB" } } }
    }
}

Describe "Cles fermees .wslconfig (WiselyManagedWslConfigKeys / KnownWslConfigKeys)" {

    It "expose exactement les 5 cles gerees par Wisely (ConvertTo-WslConfigContent)" {
        $script:WiselyManagedWslConfigKeys | Should -Be @("memory", "processors", "swap", "swapFile", "kernelCommandLine")
    }

    It "expose exactement les 11 cles connues non gerees, dans l'ordre documente" {
        @($script:KnownWslConfigKeys.Keys) | Should -Be @(
            "autoMemoryReclaim", "sparseVhd", "networkingMode", "dnsTunneling", "firewall",
            "autoProxy", "guiApplications", "nestedVirtualization", "vmIdleTimeout", "debugConsole", "safeMode"
        )
    }

    It "chaque cle connue porte Summary (texte non vide) et CoveredByWslSettings (bool), rien d'autre" {
        foreach ($key in $script:KnownWslConfigKeys.Keys) {
            $info = $script:KnownWslConfigKeys[$key]
            $info.Keys.Count | Should -Be 2
            $info.Summary | Should -Not -BeNullOrEmpty
            $info.CoveredByWslSettings | Should -BeOfType [bool]
        }
    }

    It "aucune cle geree par Wisely n'apparait aussi dans la liste des cles connues non gerees" {
        foreach ($key in $script:WiselyManagedWslConfigKeys) {
            $script:KnownWslConfigKeys.Contains($key) | Should -Be $false
        }
    }
}

Describe "Get-WslConfigRawKeys" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
        Restore-TestUserProfile
    }

    It "retourne un tableau vide (jamais `$null) quand .wslconfig est absent" {
        $result = Get-WslConfigRawKeys
        $result | Should -Not -Be $null
        @($result).Count | Should -Be 0
    }

    It "extrait les cles de la section [wsl2] uniquement" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nautoMemoryReclaim=gradual`n[experimental]`nsparseVhd=true`n"
        $keys = Get-WslConfigRawKeys
        $keys | Should -Contain "memory"
        $keys | Should -Contain "autoMemoryReclaim"
        $keys | Should -Not -Contain "sparseVhd"
    }
}

Describe "Get-DistroVhdxInfo - localisation registre + taille fichier (jamais `$null en silence)" {

    BeforeEach {
        $script:lxssRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    }

    It "Reason explicite quand la cle de registre Lxss est absente" {
        Mock Test-Path -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith { $false }

        $result = Get-DistroVhdxInfo -Distro "Ubuntu"
        $result.Success | Should -Be $false
        $result.SizeGB | Should -Be $null
        $result.Reason | Should -Match "Cle de registre Lxss introuvable"
    }

    It "Reason explicite quand la distribution n'a pas d'entree dans le registre Lxss" {
        Mock Test-Path -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith { $true }
        Mock Get-ChildItem -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith { @() }

        $result = Get-DistroVhdxInfo -Distro "Ubuntu"
        $result.Success | Should -Be $false
        $result.Reason | Should -Match "Distribution 'Ubuntu' non trouvee"
    }

    It "Reason explicite quand BasePath est absent pour la distribution trouvee" {
        Mock Test-Path -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith { $true }
        Mock Get-ChildItem -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith {
            @([PSCustomObject]@{ PSPath = "HKCU:\...\Lxss\{fake-guid}" })
        }
        Mock Get-ItemProperty -ParameterFilter { $Path -eq "HKCU:\...\Lxss\{fake-guid}" } -MockWith {
            [PSCustomObject]@{ DistributionName = "Ubuntu"; BasePath = $null }
        }

        $result = Get-DistroVhdxInfo -Distro "Ubuntu"
        $result.Success | Should -Be $false
        $result.Reason | Should -Match "Cle BasePath absente"
    }

    It "Reason explicite quand BasePath resout mais ext4.vhdx n'existe pas a cet emplacement" {
        $fakeBasePath = Join-Path ([System.IO.Path]::GetTempPath()) ("wisely-vhdx-missing-" + [guid]::NewGuid().ToString("N"))

        Mock Test-Path -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith { $true }
        Mock Get-ChildItem -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith {
            @([PSCustomObject]@{ PSPath = "HKCU:\...\Lxss\{fake-guid}" })
        }
        Mock Get-ItemProperty -ParameterFilter { $Path -eq "HKCU:\...\Lxss\{fake-guid}" } -MockWith {
            [PSCustomObject]@{ DistributionName = "Ubuntu"; BasePath = $fakeBasePath }
        }

        $result = Get-DistroVhdxInfo -Distro "Ubuntu"
        $result.Success | Should -Be $false
        $result.BasePath | Should -Be $fakeBasePath
        $result.Reason | Should -Match "ext4.vhdx introuvable"
    }

    It "Success=`$true et SizeGB mesure quand le registre et le fichier resolvent" {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wisely-vhdx-ok-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $vhdxPath = Join-Path $tempDir "ext4.vhdx"
        [System.IO.File]::WriteAllBytes($vhdxPath, [byte[]]::new(10MB))

        try {
            Mock Test-Path -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith { $true }
            Mock Get-ChildItem -ParameterFilter { $Path -eq $script:lxssRoot } -MockWith {
                @([PSCustomObject]@{ PSPath = "HKCU:\...\Lxss\{fake-guid}" })
            }
            Mock Get-ItemProperty -ParameterFilter { $Path -eq "HKCU:\...\Lxss\{fake-guid}" } -MockWith {
                [PSCustomObject]@{ DistributionName = "Ubuntu"; BasePath = $tempDir }
            }

            $result = Get-DistroVhdxInfo -Distro "Ubuntu"
            $result.Success | Should -Be $true
            $result.Reason | Should -Be "OK"
            $result.SizeGB | Should -BeGreaterThan 0
            $result.BasePath | Should -Be $tempDir
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Get-DiagnoseMemoryAttribution" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        New-TestProfilesJson -Config (script:New-TestConfig)
        Clear-ProfileConfigCache
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "Available=`$false, raison explicite, quand le consentement n'est pas accorde" {
        Mock Get-GuestReadConsentState { "unset" }

        $result = Get-DiagnoseMemoryAttribution
        $result.Available | Should -Be $false
        $result.Reason | Should -Match "Consentement de lecture invitee non accorde"
        $result.Reason | Should -Match "wisely -Consent grant"
    }

    It "Available=`$false, raison explicite, quand aucune distribution n'est active" {
        Set-GuestReadConsentState -State "granted"
        Mock Get-WslActiveSessions { @() }

        $result = Get-DiagnoseMemoryAttribution
        $result.Available | Should -Be $false
        $result.Reason | Should -Match "Aucune distribution WSL2 active"
    }

    It "Available=`$false, raison explicite, quand plusieurs distributions actives sans -Distro" {
        Set-GuestReadConsentState -State "granted"
        Mock Get-WslActiveSessions { @("Ubuntu-22.04", "Debian") }

        $result = Get-DiagnoseMemoryAttribution
        $result.Available | Should -Be $false
        $result.Reason | Should -Match "Plusieurs distributions actives"
        $result.Reason | Should -Match "precise -Distro"
    }

    It "cas nominal : attribue la memoire par processus et signale un reste 'non attribue' negatif tel quel" {
        Set-GuestReadConsentState -State "granted"
        Mock Get-WslActiveSessions { @("Ubuntu-22.04") }

        $memRaw = @"
MemTotal:        8000000 kB
MemFree:          500000 kB
MemAvailable:    3000000 kB
Buffers:          100000 kB
Cached:          1500000 kB
"@
        $procRaw = @"
   3000000 python3
   3000000 node
"@
        Mock Invoke-GuestRead -ParameterFilter { $CommandKey -eq "MemInfo" } -MockWith { $memRaw }
        Mock Invoke-GuestRead -ParameterFilter { $CommandKey -eq "ProcRss" } -MockWith { $procRaw }

        $result = Get-DiagnoseMemoryAttribution -Distro "Ubuntu-22.04"

        $result.Available | Should -Be $true
        $result.Distro | Should -Be "Ubuntu-22.04"
        $result.Processes.Count | Should -Be 2
        $result.AttributedGB | Should -BeGreaterThan $result.UsedGB
        $result.UnattributedGB | Should -BeLessThan 0
    }

    It "Available=`$false, raison explicite, quand Invoke-GuestRead leve une exception (jamais de degradation silencieuse)" {
        Set-GuestReadConsentState -State "granted"
        Mock Get-WslActiveSessions { @("Ubuntu-22.04") }
        Mock Invoke-GuestRead { throw "boom invite" }

        $result = Get-DiagnoseMemoryAttribution -Distro "Ubuntu-22.04"
        $result.Available | Should -Be $false
        $result.Reason | Should -Match "boom invite"
    }
}

Describe "Show-DiagnoseExplain - les 3 branches (geree / connue non geree / inconnue)" {

    It "cle geree par Wisely : message vert renvoyant vers l'affichage normal" {
        $output = (Show-DiagnoseExplain -Key "memory" 6>&1 | Out-String)
        $output | Should -Match "geree par Wisely"
    }

    It "cle connue non geree : Summary + mention WSL Settings quand CoveredByWslSettings" {
        $output = (Show-DiagnoseExplain -Key "autoMemoryReclaim" 6>&1 | Out-String)
        $output | Should -Match "n'est pas geree par Wisely"
        $output | Should -Match ([regex]::Escape($script:KnownWslConfigKeys["autoMemoryReclaim"].Summary))
        $output | Should -Match "WSL Settings"
    }

    It "cle connue non geree et non couverte par WSL Settings : le dit explicitement" {
        $output = (Show-DiagnoseExplain -Key "vmIdleTimeout" 6>&1 | Out-String)
        $output | Should -Match "Non exposee dans WSL Settings"
    }

    It "cle inconnue : message explicite 'non reconnue', jamais inventee" {
        $output = (Show-DiagnoseExplain -Key "cleInexistanteXyz" 6>&1 | Out-String)
        $output | Should -Match "n'est pas reconnue"
    }
}

Describe "Get-DiagnoseHistoryClassification - attribuable et les 3 raisons d'ecart" {

    It "attribuable quand SWITCH, restartSeconds mesure, profil connu" {
        $entry = [PSCustomObject]@{ action = "SWITCH"; restartSeconds = 4.2; profile = "web" }
        $cls = Get-DiagnoseHistoryClassification -Entry $entry -KnownProfileKeys @("web", "data")
        $cls.Attributable | Should -Be $true
        $cls.Reason | Should -Be ""
    }

    It "ecarte : action hors SWITCH" {
        $entry = [PSCustomObject]@{ action = "CONSENT"; restartSeconds = $null; profile = $null }
        $cls = Get-DiagnoseHistoryClassification -Entry $entry -KnownProfileKeys @("web")
        $cls.Attributable | Should -Be $false
        $cls.Reason | Should -Match "hors perimetre du switch - CONSENT"
    }

    It "ecarte : restartSeconds non mesure" {
        $entry = [PSCustomObject]@{ action = "SWITCH"; restartSeconds = $null; profile = "web" }
        $cls = Get-DiagnoseHistoryClassification -Entry $entry -KnownProfileKeys @("web")
        $cls.Attributable | Should -Be $false
        $cls.Reason | Should -Match "temps d'arret non mesure"
    }

    It "ecarte : profil renomme ou supprime depuis" {
        $entry = [PSCustomObject]@{ action = "SWITCH"; restartSeconds = 3.1; profile = "profil-disparu" }
        $cls = Get-DiagnoseHistoryClassification -Entry $entry -KnownProfileKeys @("web", "data")
        $cls.Attributable | Should -Be $false
        $cls.Reason | Should -Match "profil renomme ou supprime depuis"
    }
}

Describe "Show-DiagnoseHistory - degradation propre" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "message explicite quand aucun historique n'existe" {
        $output = (Show-DiagnoseHistory 6>&1 | Out-String)
        $output | Should -Match "Aucun historique disponible"
    }

    It "message explicite quand l'historique est corrompu" {
        Set-Content -Path (Get-HistoryPath) -Value "{ceci n'est pas du json" -Encoding UTF8
        $output = (Show-DiagnoseHistory 6>&1 | Out-String)
        $output | Should -Match "Historique corrompu"
    }

    It "message explicite quand l'historique est vide" {
        Set-Content -Path (Get-HistoryPath) -Value "[]" -Encoding UTF8
        $output = (Show-DiagnoseHistory 6>&1 | Out-String)
        $output | Should -Match "Historique vide"
    }
}

Describe "Discipline de lecture VHDX - aucun acces registre/fichier hors de Diagnose.ps1" {

    It "aucune reference a Lxss ou ext4.vhdx n'existe hors de modules/Diagnose.ps1" {
        $offenders = Select-String -Path "$PSScriptRoot/../modules/*.ps1", "$PSScriptRoot/../wisely.ps1" -Pattern "Lxss|ext4\.vhdx" |
                     Where-Object { $_.Path -notlike "*Diagnose.ps1" }
        $offenders | Should -BeNullOrEmpty
    }
}

Describe "Completion documentaire VHDX (RESOURCE-MODEL.md SS8 / DOCTRINE-LECTURE.md SS2.3)" {

    It "RESOURCE-MODEL.md documente la lecture VHDX (registre Lxss + BasePath + ext4.vhdx, jamais le contenu)" {
        $doc = Get-Content "$PSScriptRoot/../docs/RESOURCE-MODEL.md" -Raw
        $doc | Should -Match ([regex]::Escape("Lxss"))
        $doc | Should -Match ([regex]::Escape("BasePath"))
        $doc | Should -Match ([regex]::Escape("ext4.vhdx"))
        $doc | Should -Match "jamais son contenu"
    }

    It "DOCTRINE-LECTURE.md documente la meme lecture VHDX (registre Lxss + BasePath + ext4.vhdx, jamais le contenu)" {
        $doc = Get-Content "$PSScriptRoot/../docs/DOCTRINE-LECTURE.md" -Raw
        $doc | Should -Match ([regex]::Escape("Lxss"))
        $doc | Should -Match ([regex]::Escape("BasePath"))
        $doc | Should -Match ([regex]::Escape("ext4.vhdx"))
        $doc | Should -Match "jamais une ouverture du contenu"
    }
}
