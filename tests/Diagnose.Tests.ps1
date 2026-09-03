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

    It "retourne une table vide (jamais `$null) quand .wslconfig est absent" {
        $result = Get-WslConfigRawKeys
        ($null -eq $result) | Should -Be $false
        $result.Count | Should -Be 0
    }

    It "extrait cle -> valeur brute de la section [wsl2] uniquement" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4GB`nautoMemoryReclaim=gradual`n[experimental]`nsparseVhd=true`n"
        $keys = Get-WslConfigRawKeys
        $keys.Contains("memory") | Should -Be $true
        $keys["memory"] | Should -Be "4GB"
        $keys.Contains("autoMemoryReclaim") | Should -Be $true
        $keys["autoMemoryReclaim"] | Should -Be "gradual"
        $keys.Contains("sparseVhd") | Should -Be $false
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
        Mock Test-Path -ParameterFilter { $Path -ne $script:lxssRoot } -MockWith {
            [System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path)
        }
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
            Mock Test-Path -ParameterFilter { $Path -ne $script:lxssRoot } -MockWith {
                [System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path)
            }
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

Describe "Get-DiagnoseReport - enums fermes (RESOURCE-MODEL.md SS2-3)" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        Set-TestUserProfile -Path $script:testRoot
        New-TestProfilesJson -Config (script:New-TestConfig)
        Clear-ProfileConfigCache
        Enable-WslMocks
        Mock Get-GuestReadConsentState { "unset" }
    }

    AfterEach {
        Restore-TestUserProfile
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "chaque ligne du rapport porte un Scope dans l'enum ferme de RESOURCE-MODEL.md SS3 (Portees)" {
        $report = Get-DiagnoseReport
        foreach ($line in $report.Lines) {
            $line.Scope | Should -BeIn @("host", "vm", "distro", "process", "policy")
        }
    }

    It "chaque ligne du rapport porte une Class dans l'enum ferme de RESOURCE-MODEL.md SS2 (taxonomie)" {
        $report = Get-DiagnoseReport
        foreach ($line in $report.Lines) {
            $line.Class | Should -BeIn @("directe", "attribuee", "estimee", "correlee")
        }
    }

    It "chaque ligne du rapport porte une Confidence dans l'enum ferme de RESOURCE-MODEL.md SS3 (Niveaux de confiance)" {
        $report = Get-DiagnoseReport
        foreach ($line in $report.Lines) {
            $line.Confidence | Should -BeIn @("haute", "moyenne", "basse")
        }
    }

    It "Get-WslCeilingInfo.Scope vaut 'host' (jamais l'ancienne chaine malformee 'GLOBAL - ...')" {
        $ceiling = Get-WslCeilingInfo
        $ceiling.Scope | Should -Be "host"
        $ceiling.ScopeNote | Should -Match "pas par-distribution"
    }

    It "Get-WslCeilingInfo calcule RatioOfHostPct pour une valeur memory= en MB, pas seulement en GB" {
        New-TestWslConfig -Content "[wsl2]`nmemory=4096MB`n"
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function script:Get-CimInstance { }
        }
        Mock Get-CimInstance { [PSCustomObject]@{ TotalVisibleMemorySize = 16 * 1MB } }

        $ceiling = Get-WslCeilingInfo
        $ceiling.MemoryCeiling  | Should -Be "4096MB"
        $ceiling.HostTotalRamGB | Should -Be 16
        $ceiling.RatioOfHostPct | Should -Be 25
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

    It "lookup insensible a la casse : une cle geree tapee en majuscules est quand meme reconnue" {
        $output = (Show-DiagnoseExplain -Key "MEMORY" 6>&1 | Out-String)
        $output | Should -Match "geree par Wisely"
    }

    It "lookup insensible a la casse : une cle connue non geree tapee en majuscules est quand meme reconnue" {
        $output = (Show-DiagnoseExplain -Key "AUTOMEMORYRECLAIM" 6>&1 | Out-String)
        $output | Should -Match "n'est pas geree par Wisely"
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

    It "n'echoue pas sur une entree valide en JSON mais sans action/profile (edition manuelle, entree legacy)" {
        Set-Content -Path (Get-HistoryPath) -Value '[{"timestamp":"2026-09-01 10:00:00"}]' -Encoding UTF8
        { Show-DiagnoseHistory } | Should -Not -Throw
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

# ============================================================
#  Expurgation (-Redact) - contrat de securite
#
#  Ces tests valent contrat : SECURITY.md promet a un testeur que la
#  sortie expurgee est collable dans une issue publique. Une regression
#  ici est une vulnerabilite au sens du perimetre declare, pas un bug
#  d'affichage.
# ============================================================

Describe "ConvertTo-RedactedDiagnoseReport - ce qui ne doit jamais survivre" {

    BeforeEach {
        function script:New-RedactTestReport {
            param([string[]]$Distros = @("Ubuntu-22.04", "Ubuntu"), [string]$VhdxReason = "")
            $vhdxValue = if ($VhdxReason) { "indisponible - $VhdxReason" } else { "42.5" }
            $vhdxUnit  = if ($VhdxReason) { "" } else { "GB" }
            return [PSCustomObject]@{
                GeneratedAt = "2026-09-03 10:00:00"
                Distro      = $Distros[0]
                Lines       = @(
                    [PSCustomObject]@{ Question = "que se passe-t-il"; Label = "Distributions actives"; Value = ($Distros -join ", "); Unit = ""; Scope = "host"; Class = "directe"; Confidence = "haute"; Source = "wsl --list --running --quiet" }
                    [PSCustomObject]@{ Question = "que se passe-t-il"; Label = "Taille VHDX ($($Distros[0]))"; Value = $vhdxValue; Unit = $vhdxUnit; Scope = "distro"; Class = "directe"; Confidence = "haute"; Source = "registre Lxss + taille fichier ext4.vhdx" }
                )
                Ceiling     = [PSCustomObject]@{ MemoryCeiling = "8GB"; HostTotalRamGB = 16.0; RatioOfHostPct = 50; Scope = "host"; ScopeNote = "s'applique a toutes les distributions" }
                Attribution = [PSCustomObject]@{
                    Available = $true; Distro = $Distros[0]
                    MemTotalGB = 7.8; MemAvailableGB = 4.1; CachedGB = 3.2; UsedGB = 3.7
                    AttributedGB = 4.1; UnattributedGB = -0.4
                    Processes = @(
                        [PSCustomObject]@{ Command = "acme-client-api"; RssGB = 2.1 }
                        [PSCustomObject]@{ Command = "node";            RssGB = 1.2 }
                    )
                }
            }
        }
    }

    It "aucun nom de distribution ne survit, y compris quand un nom est prefixe d'un autre" {
        # Piege 2 de l'en-tete de section : "Ubuntu" substitue avant
        # "Ubuntu-22.04" laisserait "distro-N-22.04" en clair.
        $json = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport) | ConvertTo-Json -Depth 6
        $json | Should -Not -Match "Ubuntu"
        $json | Should -Not -Match "distro-\d+-22"
    }

    It "deux distributions distinctes recoivent deux pseudonymes distincts" {
        $r = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)
        ($r.Lines | Where-Object { $_.Label -eq "Distributions actives" }).Value | Should -Be "distro-1, distro-2"
    }

    It "aucun nom de processus ne survit, generique compris" {
        $json = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport) | ConvertTo-Json -Depth 6
        $json | Should -Not -Match "acme-client-api"
        $json | Should -Not -Match '"node"'
    }

    It "les processus sont numerotes par RSS decroissant, ordre deja etabli par Get-DiagnoseMemoryAttribution" {
        $r = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)
        $r.Attribution.Processes[0].Command | Should -Be "proc-1"
        $r.Attribution.Processes[1].Command | Should -Be "proc-2"
    }

    It "aucun chemin absolu ni nom d'utilisateur Windows ne survit dans Reason (fuite reelle de Get-DistroVhdxInfo)" {
        # Piege 1 : Get-DistroVhdxInfo place $vhdxPath complet dans Reason,
        # rendu tel quel dans la valeur de la ligne "Taille VHDX".
        $leak = "Fichier ext4.vhdx introuvable a l'emplacement attendu : C:\Users\jdupont\AppData\Local\wsl\Ubuntu-22.04\ext4.vhdx"
        $json = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport -VhdxReason $leak) | ConvertTo-Json -Depth 6
        $json | Should -Not -Match "jdupont"
        $json | Should -Not -Match "AppData"
        $json | Should -Match ([regex]::Escape($script:RedactedPathPlaceholder))
    }

    It "expurger un chemin ne mange pas la phrase qui le contient" {
        $leak = "Fichier ext4.vhdx introuvable a l'emplacement attendu : C:\Temp\x.vhdx"
        $r = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport -VhdxReason $leak)
        ($r.Lines | Where-Object { $_.Label -like "Taille VHDX*" }).Value | Should -Match "introuvable a l'emplacement attendu"
    }

    It "expurge aussi la raison d'un cas degrade, sans la perdre" {
        $rep = New-RedactTestReport
        $rep.Attribution = [PSCustomObject]@{ Available = $false; Reason = "Plusieurs distributions actives (Ubuntu-22.04, Debian) - precise -Distro <nom>." }
        $r = ConvertTo-RedactedDiagnoseReport -Report $rep
        $r.Attribution.Reason | Should -Match "Plusieurs distributions actives"
        $r.Attribution.Reason | Should -Not -Match "Ubuntu"
        $r.Attribution.Reason | Should -Not -Match "Debian"
    }
}

Describe "ConvertTo-RedactedDiagnoseReport - ce qui doit survivre intact" {

    BeforeEach {
        function script:New-RedactTestReport {
            return [PSCustomObject]@{
                GeneratedAt = "2026-09-03 10:00:00"
                Distro      = "Ubuntu"
                Lines       = @(
                    [PSCustomObject]@{ Question = "que se passe-t-il"; Label = "Distributions actives"; Value = "Ubuntu"; Unit = ""; Scope = "host"; Class = "directe"; Confidence = "haute"; Source = "wsl --list --running --quiet" }
                    [PSCustomObject]@{ Question = "que se passe-t-il"; Label = "Taille VHDX (Ubuntu)"; Value = "42.5"; Unit = "GB"; Scope = "distro"; Class = "directe"; Confidence = "haute"; Source = "registre Lxss" }
                )
                Ceiling     = [PSCustomObject]@{ MemoryCeiling = "8GB"; HostTotalRamGB = 16.0; RatioOfHostPct = 50; Scope = "host"; ScopeNote = "s'applique a toutes les distributions" }
                Attribution = [PSCustomObject]@{
                    Available = $true; Distro = "Ubuntu"
                    MemTotalGB = 7.8; MemAvailableGB = 4.1; CachedGB = 3.2; UsedGB = 3.7
                    AttributedGB = 4.1; UnattributedGB = -0.4
                    Processes = @([PSCustomObject]@{ Command = "node"; RssGB = 1.2 })
                }
            }
        }
    }

    It "toute valeur numerique survit, y compris un reste non attribue negatif (RESOURCE-MODEL.md SS4.4)" {
        $r = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)
        $r.Attribution.UnattributedGB | Should -Be -0.4
        $r.Attribution.CachedGB       | Should -Be 3.2
        $r.Attribution.MemAvailableGB | Should -Be 4.1
        $r.Attribution.Processes[0].RssGB | Should -Be 1.2
        ($r.Lines | Where-Object { $_.Label -like "Taille VHDX*" }).Value | Should -Be "42.5"
    }

    It "portee, classe, confiance et unite survivent sur chaque ligne - un rapport expurge reste exploitable" {
        $r = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)
        foreach ($line in $r.Lines) {
            $line.Scope      | Should -Not -BeNullOrEmpty
            $line.Class      | Should -Not -BeNullOrEmpty
            $line.Confidence | Should -Not -BeNullOrEmpty
        }
        ($r.Lines | Where-Object { $_.Label -like "Taille VHDX*" }).Unit | Should -Be "GB"
    }

    It "le plafond et son ratio survivent tels quels" {
        $r = ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)
        $r.Ceiling.RatioOfHostPct | Should -Be 50
        $r.Ceiling.HostTotalRamGB | Should -Be 16.0
        $r.Ceiling.MemoryCeiling  | Should -Be "8GB"
    }

    It "'8GB' n'est pas ampute par la substitution : la frontiere de jeton exclut un chiffre a gauche" {
        $rep = New-RedactTestReport
        $rep.Lines[0].Value = "Ubuntu"
        $rep.Lines[1].Value = "plafond 8GB, hote 16 GB"
        $r = ConvertTo-RedactedDiagnoseReport -Report $rep
        $r.Lines[1].Value | Should -Match "8GB"
    }
}

Describe "ConvertTo-RedactedDiagnoseReport - stabilite, non-mutation, signalement" {

    BeforeEach {
        function script:New-RedactTestReport {
            return [PSCustomObject]@{
                GeneratedAt = "2026-09-03 10:00:00"
                Distro      = "Ubuntu"
                Lines       = @([PSCustomObject]@{ Question = "q"; Label = "Distributions actives"; Value = "Ubuntu"; Unit = ""; Scope = "host"; Class = "directe"; Confidence = "haute"; Source = "wsl" })
                Ceiling     = $null
                Attribution = $null
            }
        }
    }

    It "deux expurgations du meme rapport produisent exactement le meme resultat" {
        $rep = New-RedactTestReport
        $a = ConvertTo-RedactedDiagnoseReport -Report $rep | ConvertTo-Json -Depth 6
        $b = ConvertTo-RedactedDiagnoseReport -Report $rep | ConvertTo-Json -Depth 6
        $a | Should -Be $b
    }

    It "le rapport d'origine n'est jamais mute - Show-DiagnoseReport peut encore etre appele dessus" {
        $rep = New-RedactTestReport
        $before = $rep | ConvertTo-Json -Depth 6
        $null = ConvertTo-RedactedDiagnoseReport -Report $rep
        ($rep | ConvertTo-Json -Depth 6) | Should -Be $before
    }

    It "RedactionApplied marque le rapport, pour qu'un testeur sache qu'il ne lit pas ses vraies valeurs" {
        (ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)).RedactionApplied | Should -BeTrue
    }

    It "un identifiant homographe d'une unite est expurge quand meme, et signale (jamais de fuite silencieuse)" {
        # Piege 3 : abimer visiblement le rapport vaut mieux que fuiter en
        # silence. C'est l'arbitrage du principe 9.
        $rep = New-RedactTestReport
        $rep.Distro = "GB"
        $rep.Lines[0].Value = "GB"
        $r = ConvertTo-RedactedDiagnoseReport -Report $rep
        $r.Lines[0].Value | Should -Be "distro-1"
        @($r.RedactionWarnings).Count | Should -BeGreaterThan 0
    }

    It "un rapport sans avertissement porte une liste vide, jamais `$null" {
        (ConvertTo-RedactedDiagnoseReport -Report (New-RedactTestReport)).RedactionWarnings | Should -Not -BeNullOrEmpty -Because "la propriete existe toujours"
    }
}

Describe "ConvertTo-DiagnoseJson" {

    It "serialise Attribution.Processes sans le degrader en chaine de type (profondeur suffisante)" {
        $rep = [PSCustomObject]@{
            GeneratedAt = "x"; Distro = ""
            Lines = @([PSCustomObject]@{ Question = "q"; Label = "l"; Value = "v"; Unit = ""; Scope = "host"; Class = "directe"; Confidence = "haute"; Source = "s" })
            Ceiling = $null
            Attribution = [PSCustomObject]@{ Available = $true; Distro = "Ubuntu"; Processes = @([PSCustomObject]@{ Command = "node"; RssGB = 1.2 }) }
        }
        $json = ConvertTo-DiagnoseJson -Report $rep
        $json | Should -Not -Match "System\.Object\["
        $json | Should -Not -Match "System\.Management\.Automation"
        @(($json | ConvertFrom-Json).Attribution.Processes).Count | Should -Be 1
    }
}
