# ============================================================
#  GuestReader.Tests.ps1 - Tests Pester pour modules/GuestReader.ps1
#  Lecture in-distro sous contrat (P1/v2.6)
# ============================================================

BeforeAll {
    . "$PSScriptRoot/../modules/ProfileManager.ps1"
    . "$PSScriptRoot/../modules/Logger.ps1"
    . "$PSScriptRoot/../modules/GuestReader.ps1"
    . "$PSScriptRoot/TestHelpers.ps1"

    function script:New-TestConfig {
        return @{ version = "2.6.0"; profiles = @{ web = @{ displayName = "WEB"; memory = "4GB"; processors = 3; swap = "3GB" } } }
    }
}

Describe "Liste fermee des commandes invite" {

    It "expose exactement les 6 cles attendues" {
        (Get-GuestReadCommandKeys) | Should -Be @("MemInfo", "LoadAvg", "Uptime", "DiskRoot", "Nproc", "ProcRss")
    }

    It "MemInfo est de portee distro, classe directe, commande 'cat /proc/meminfo'" {
        $cmd = $script:GuestReadCommands["MemInfo"]
        $cmd.Scope | Should -Be "distro"
        $cmd.Class | Should -Be "directe"
        ($cmd.Args -join " ") | Should -Be "cat /proc/meminfo"
    }

    It "LoadAvg est de portee distro, classe directe, commande 'cat /proc/loadavg'" {
        $cmd = $script:GuestReadCommands["LoadAvg"]
        $cmd.Scope | Should -Be "distro"
        $cmd.Class | Should -Be "directe"
        ($cmd.Args -join " ") | Should -Be "cat /proc/loadavg"
    }

    It "Uptime est de portee distro, classe directe, commande 'cat /proc/uptime'" {
        $cmd = $script:GuestReadCommands["Uptime"]
        $cmd.Scope | Should -Be "distro"
        $cmd.Class | Should -Be "directe"
        ($cmd.Args -join " ") | Should -Be "cat /proc/uptime"
    }

    It "DiskRoot est de portee distro, classe directe, commande 'df -P /'" {
        $cmd = $script:GuestReadCommands["DiskRoot"]
        $cmd.Scope | Should -Be "distro"
        $cmd.Class | Should -Be "directe"
        ($cmd.Args -join " ") | Should -Be "df -P /"
    }

    It "Nproc est de portee distro, classe directe, commande 'nproc'" {
        $cmd = $script:GuestReadCommands["Nproc"]
        $cmd.Scope | Should -Be "distro"
        $cmd.Class | Should -Be "directe"
        ($cmd.Args -join " ") | Should -Be "nproc"
    }

    It "ProcRss est de portee process, classe attribuee, commande 'ps -eo rss,comm --sort=-rss'" {
        $cmd = $script:GuestReadCommands["ProcRss"]
        $cmd.Scope | Should -Be "process"
        $cmd.Class | Should -Be "attribuee"
        ($cmd.Args -join " ") | Should -Be "ps -eo rss,comm --sort=-rss"
    }

    It "ne derive pas de docs/DOCTRINE-LECTURE.md (chaque commande y est citee telle quelle)" {
        $doctrine = Get-Content "$PSScriptRoot/../docs/DOCTRINE-LECTURE.md" -Raw
        foreach ($key in Get-GuestReadCommandKeys) {
            $commandString = ($script:GuestReadCommands[$key].Args -join " ")
            $doctrine | Should -Match ([regex]::Escape($commandString))
        }
    }

    It "ne derive pas de docs/RESOURCE-MODEL.md (chaque commande y est citee telle quelle)" {
        $resourceModel = Get-Content "$PSScriptRoot/../docs/RESOURCE-MODEL.md" -Raw
        foreach ($key in Get-GuestReadCommandKeys) {
            $commandString = ($script:GuestReadCommands[$key].Args -join " ")
            $resourceModel | Should -Match ([regex]::Escape($commandString))
        }
    }

    It "aucun appel 'wsl -d' n'existe hors de modules/GuestReader.ps1" {
        $offenders = Select-String -Path "$PSScriptRoot/../modules/*.ps1", "$PSScriptRoot/../wisely.ps1" -Pattern "wsl\s+-d\b|wsl'\s*-ArgumentList|-FilePath\s+.wsl." |
                     Where-Object { $_.Path -notlike "*GuestReader.ps1" }
        $offenders | Should -BeNullOrEmpty
    }

    It "leve une erreur explicite pour une cle hors liste, sans jamais atteindre Invoke-GuestProcess" {
        Mock Invoke-GuestProcess {}
        { Invoke-GuestRead -CommandKey "Rm" -Distro "Ubuntu" } | Should -Throw "*Rm*"
        Should -Invoke Invoke-GuestProcess -Times 0
    }
}

Describe "Consentement (Get/Set-GuestReadConsentState)" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        New-TestProfilesJson -Config (script:New-TestConfig)
        Clear-ProfileConfigCache
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "retourne 'unset' quand settings est absent du tout" {
        Get-GuestReadConsentState | Should -Be "unset"
    }

    It "retourne 'unset' quand settings existe mais sans guestReadConsent" {
        New-TestProfilesJson -Config (@{ version = "2.6.0"; profiles = @{}; settings = @{ backupEnabled = $true } })
        Clear-ProfileConfigCache
        Get-GuestReadConsentState | Should -Be "unset"
    }

    It "Set-GuestReadConsentState 'granted' persiste et se relit" {
        Set-GuestReadConsentState -State "granted"
        Get-GuestReadConsentState | Should -Be "granted"
    }

    It "Set-GuestReadConsentState 'revoked' persiste et se relit, distinct de 'unset'" {
        Set-GuestReadConsentState -State "revoked"
        Get-GuestReadConsentState | Should -Be "revoked"
        Get-GuestReadConsentState | Should -Not -Be "unset"
    }

    It "journalise une entree CONSENT a chaque changement" {
        Set-GuestReadConsentState -State "granted"
        $history = @(Get-Content (Get-HistoryPath) -Raw | ConvertFrom-Json)
        $history.Count | Should -Be 1
        $history[0].action | Should -Be "CONSENT"
        $history[0].details | Should -Be "guestReadConsent=granted"
    }

    It "Invoke-GuestRead leve une erreur explicite pour 'unset', mentionnant l'activation" {
        Mock Invoke-GuestProcess {}
        { Invoke-GuestRead -CommandKey "MemInfo" -Distro "Ubuntu" } | Should -Throw "*wisely -Consent grant*"
        Should -Invoke Invoke-GuestProcess -Times 0
    }

    It "Invoke-GuestRead leve une erreur explicite pour 'revoked', distincte du cas 'unset'" {
        Set-GuestReadConsentState -State "revoked"
        Mock Invoke-GuestProcess {}
        { Invoke-GuestRead -CommandKey "MemInfo" -Distro "Ubuntu" } | Should -Throw "*revoked*"
        Should -Invoke Invoke-GuestProcess -Times 0
    }
}

Describe "Invoke-GuestRead - validation de la distribution" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        New-TestProfilesJson -Config (script:New-TestConfig)
        Clear-ProfileConfigCache
        Set-GuestReadConsentState -State "granted"
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "leve une erreur explicite quand aucune distribution n'est active (jamais de demarrage implicite)" {
        Mock Get-WslActiveSessions { @() }
        Mock Invoke-GuestProcess {}
        { Invoke-GuestRead -CommandKey "MemInfo" -Distro "Ubuntu" } | Should -Throw "*Aucune distribution*"
        Should -Invoke Invoke-GuestProcess -Times 0
    }

    It "leve une erreur explicite quand -Distro n'est pas parmi les distributions actives" {
        Mock Get-WslActiveSessions { @("Ubuntu-22.04") }
        Mock Invoke-GuestProcess {}
        { Invoke-GuestRead -CommandKey "MemInfo" -Distro "Debian" } | Should -Throw "*Debian*"
        Should -Invoke Invoke-GuestProcess -Times 0
    }
}

Describe "Invoke-GuestProcess" {

    BeforeAll {
        $script:SelfExe = (Get-Process -Id $PID).Path
    }

    It "retourne Success=true et remplit Output en cas de succes rapide" {
        $result = Invoke-GuestProcess -FilePath $script:SelfExe -ArgumentList @("-NoProfile", "-Command", "Write-Output 'hello'") -TimeoutMs 10000
        $result.Success | Should -Be $true
        $result.Output.Trim() | Should -Be "hello"
        $result.TimedOut | Should -Be $false
    }

    It "retourne Success=false et TimedOut=true en cas de depassement du delai" {
        $result = Invoke-GuestProcess -FilePath $script:SelfExe -ArgumentList @("-NoProfile", "-Command", "Start-Sleep -Seconds 30") -TimeoutMs 500
        $result.Success | Should -Be $false
        $result.TimedOut | Should -Be $true
        $result.Error | Should -Not -BeNullOrEmpty
    }

    It "remplit Error (jamais vide) pour un code de sortie non nul" {
        $result = Invoke-GuestProcess -FilePath $script:SelfExe -ArgumentList @("-NoProfile", "-Command", "exit 3") -TimeoutMs 10000
        $result.Success | Should -Be $false
        $result.ExitCode | Should -Be 3
        $result.Error | Should -Not -BeNullOrEmpty
    }

    It "remplit Error pour un executable introuvable" {
        $result = Invoke-GuestProcess -FilePath "wisely-executable-introuvable-xyz" -ArgumentList @() -TimeoutMs 5000
        $result.Success | Should -Be $false
        $result.Error | Should -Not -BeNullOrEmpty
    }
}

Describe "Invoke-GuestRead - integration (Invoke-GuestProcess mocke)" {

    BeforeEach {
        $script:testRoot = New-TestWslRoot
        New-TestProfilesJson -Config (script:New-TestConfig)
        Clear-ProfileConfigCache
        Set-GuestReadConsentState -State "granted"
        Mock Get-WslActiveSessions { @("Ubuntu-22.04") }
    }

    AfterEach {
        Remove-TestWslRoot -Path $script:testRoot
    }

    It "construit exactement '-d <distro> -- cat /proc/meminfo' pour MemInfo" {
        Mock Invoke-GuestProcess {
            return [PSCustomObject]@{ Success = $true; Output = "MemTotal:  8000000 kB"; Error = ""; ExitCode = 0; TimedOut = $false }
        }
        Invoke-GuestRead -CommandKey "MemInfo" -Distro "Ubuntu-22.04" | Out-Null
        Should -Invoke Invoke-GuestProcess -Times 1 -ParameterFilter {
            $FilePath -eq "wsl" -and ($ArgumentList -join " ") -eq "-d Ubuntu-22.04 -- cat /proc/meminfo"
        }
    }

    It "retourne la sortie stdout brute telle quelle en cas de succes" {
        Mock Invoke-GuestProcess { [PSCustomObject]@{ Success = $true; Output = "sortie brute"; Error = ""; ExitCode = 0; TimedOut = $false } }
        Invoke-GuestRead -CommandKey "MemInfo" -Distro "Ubuntu-22.04" | Should -Be "sortie brute"
    }

    It "propage une erreur explicite (jamais degradee en silence) si Invoke-GuestProcess echoue" {
        Mock Invoke-GuestProcess { [PSCustomObject]@{ Success = $false; Output = ""; Error = "boom"; ExitCode = 1; TimedOut = $false } }
        { Invoke-GuestRead -CommandKey "MemInfo" -Distro "Ubuntu-22.04" } | Should -Throw "*boom*"
    }
}

Describe "ConvertFrom-MemInfo" {

    It "extrait MemAvailableGB distinct de MemFreeGB depuis une sortie realiste" {
        $raw = @"
MemTotal:        8000000 kB
MemFree:          500000 kB
MemAvailable:    3000000 kB
Buffers:          100000 kB
Cached:          1500000 kB
SwapTotal:       2000000 kB
SwapFree:        2000000 kB
"@
        $mem = ConvertFrom-MemInfo -RawOutput $raw
        $mem.MemFreeGB | Should -Not -Be $mem.MemAvailableGB
        $mem.MemAvailableGB | Should -BeGreaterThan $mem.MemFreeGB
    }

    It "additionne Cached et Buffers" {
        $raw = @"
MemTotal:        8000000 kB
MemFree:          500000 kB
MemAvailable:    3000000 kB
Buffers:          100000 kB
Cached:          1500000 kB
"@
        $mem = ConvertFrom-MemInfo -RawOutput $raw
        $expectedCachedGB = [math]::Round((1500000 + 100000) / 1MB, 2)
        $mem.CachedGB | Should -Be $expectedCachedGB
    }

    It "tolere l'absence de Buffers sans lever d'exception" {
        $raw = @"
MemTotal:        8000000 kB
MemFree:          500000 kB
MemAvailable:    3000000 kB
Cached:          1500000 kB
"@
        { ConvertFrom-MemInfo -RawOutput $raw } | Should -Not -Throw
        $mem = ConvertFrom-MemInfo -RawOutput $raw
        $expectedCachedGB = [math]::Round(1500000 / 1MB, 2)
        $mem.CachedGB | Should -Be $expectedCachedGB
    }

    It "leve une erreur explicite si un champ requis manque (MemAvailable)" {
        $raw = @"
MemTotal:        8000000 kB
MemFree:          500000 kB
Cached:          1500000 kB
"@
        { ConvertFrom-MemInfo -RawOutput $raw } | Should -Throw "*MemAvailable*"
    }
}
