# ============================================================
#  Diagnose.ps1 - wisely diagnose (P2/v3.0 "Diagnostic")
#  Dot-source depuis wisely.ps1, apres GuestReader.ps1
#  Utilise $Global:WSLRoot defini dans le script principal
#
#  Toutes les fonctions de ce palier, y compris l'affichage, vivent ici -
#  contrairement au pattern P1 (Show-GuestReadConsentStatus/
#  Show-GuestMemInfo restent directement dans wisely.ps1) : le volume de
#  logique/affichage de ce palier depasse ce que P1 portait.
#
#  Contrat : docs/RESOURCE-MODEL.md, docs/DOCTRINE-LECTURE.md, docs/ROADMAP.md
# ============================================================

# ---- Cles .wslconfig gerees par Wisely --------------------------------
# Identique aux cles ecrites par ConvertTo-WslConfigContent
# (modules/ProfileManager.ps1) - toute autre cle presente dans .wslconfig
# est "connue" (voir $script:KnownWslConfigKeys) ou "inconnue".

$script:WiselyManagedWslConfigKeys = @(
    "memory", "processors", "swap", "swapFile", "kernelCommandLine"
)

# ---- Cles .wslconfig connues mais non gerees ---------------------------
# Liste versionnee comme $script:GuestReadCommands (GuestReader.ps1) : toute
# correction passe par une entree CHANGELOG (pas d'ADR requise, rien ici
# n'est securitaire). A verifier contre la documentation Microsoft actuelle
# avant merge.

$script:KnownWslConfigKeys = [ordered]@{
    "autoMemoryReclaim" = @{
        Summary = "Controle si/comment WSL2 restitue a Windows la memoire liberee cote invite (gradual/dropcache/disabled)."
        CoveredByWslSettings = $true
    }
    "sparseVhd" = @{
        Summary = "Active le VHDX sparse : le disque virtuel peut se retrecir apres suppression de donnees a l'interieur."
        CoveredByWslSettings = $true
    }
    "networkingMode" = @{
        Summary = "Choisit le mode reseau de WSL2 (NAT, mirrored, virtioproxy)."
        CoveredByWslSettings = $true
    }
    "dnsTunneling" = @{
        Summary = "Active le tunneling DNS (mode reseau mirrored)."
        CoveredByWslSettings = $true
    }
    "firewall" = @{
        Summary = "Active l'integration du pare-feu Windows avec le reseau WSL2 (mode mirrored)."
        CoveredByWslSettings = $true
    }
    "autoProxy" = @{
        Summary = "Applique automatiquement les parametres de proxy HTTP Windows a l'interieur de WSL2."
        CoveredByWslSettings = $true
    }
    "guiApplications" = @{
        Summary = "Active ou desactive le support des applications graphiques (WSLg)."
        CoveredByWslSettings = $true
    }
    "nestedVirtualization" = @{
        Summary = "Active la virtualisation imbriquee a l'interieur de la VM WSL2."
        CoveredByWslSettings = $false
    }
    "vmIdleTimeout" = @{
        Summary = "Delai d'inactivite avant l'arret automatique de la VM WSL2."
        CoveredByWslSettings = $false
    }
    "debugConsole" = @{
        Summary = "Active une console de debogage pour la VM WSL2 au demarrage."
        CoveredByWslSettings = $false
    }
    "safeMode" = @{
        Summary = "Demarre la VM WSL2 en mode sans echec (pilotes minimaux), pour depanner une installation corrompue."
        CoveredByWslSettings = $false
    }
}

# ---- Lecture .wslconfig -------------------------------------------------

function Get-WslConfigRawKeys {
    <#
    .SYNOPSIS
        Lit .wslconfig et retourne les cles brutes presentes dans la
        section [wsl2], pour distinguer gerees/connues/inconnues.
        Ne retourne jamais $null : liste vide si le fichier est absent.
    #>
    $path = Get-WslConfigPath
    if (-not (Test-Path $path)) { return @() }

    $lines = Get-Content $path -Encoding UTF8
    $inSection = $false
    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[.+\]$') {
            $inSection = ($trimmed -eq "[wsl2]")
            continue
        }
        if ($inSection -and $trimmed -match '^([A-Za-z0-9_]+)\s*=') {
            $keys.Add($matches[1])
        }
    }
    return @($keys)
}

function Get-AutoMemoryReclaimStatus {
    <#
    .SYNOPSIS
        Etat de la cle autoMemoryReclaim, portee "policy"
        (docs/RESOURCE-MODEL.md SS4.5) - jamais de recommandation de
        plafond sans mentionner cet etat.
    #>
    $wslConfig = Get-WslConfigPath
    if (-not (Test-Path $wslConfig)) {
        return [PSCustomObject]@{ Value = "non configure (pas de .wslconfig)"; Scope = "policy"; Present = $false }
    }

    $lines = Get-Content $wslConfig -Encoding UTF8
    $line = $lines | Where-Object { $_ -match '^\s*autoMemoryReclaim\s*=\s*(.+)$' } | Select-Object -First 1
    if ($null -eq $line) {
        return [PSCustomObject]@{ Value = "non configure (defaut Windows)"; Scope = "policy"; Present = $false }
    }
    $null = ($line -match '^\s*autoMemoryReclaim\s*=\s*(.+)$')
    return [PSCustomObject]@{ Value = $matches[1].Trim(); Scope = "policy"; Present = $true }
}

function Get-WslCeilingInfo {
    <#
    .SYNOPSIS
        Plafond RAM/CPU configure dans .wslconfig, rapporte a la RAM
        totale de l'hote (Win32_OperatingSystem, deja autorise -
        docs/RESOURCE-MODEL.md SS4.1). Le plafond est GLOBAL, pas
        par-distribution (docs/USE-CASES.md S4) - le dit explicitement.
    #>
    $wslConfig = Get-WslConfigPath
    $memory = $null
    $processors = $null
    if (Test-Path $wslConfig) {
        $lines = Get-Content $wslConfig -Encoding UTF8
        $memLine = $lines | Where-Object { $_ -match '^\s*memory\s*=\s*(.+)$' } | Select-Object -First 1
        if ($memLine -match '^\s*memory\s*=\s*(.+)$') { $memory = $matches[1].Trim() }
        $cpuLine = $lines | Where-Object { $_ -match '^\s*processors\s*=\s*(.+)$' } | Select-Object -First 1
        if ($cpuLine -match '^\s*processors\s*=\s*(.+)$') { $processors = $matches[1].Trim() }
    }

    $hostTotalGB = $null
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $hostTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    } catch {
        Write-Verbose "Get-WslCeilingInfo : lecture Win32_OperatingSystem echouee : $_"
    }

    $ratioPct = $null
    if ($memory -match '^(\d+)GB$' -and $null -ne $hostTotalGB -and $hostTotalGB -gt 0) {
        $ratioPct = [math]::Round(([double]$matches[1] / $hostTotalGB) * 100, 0)
    }

    return [PSCustomObject]@{
        MemoryCeiling     = if ($memory)     { $memory }     else { "non configure" }
        ProcessorsCeiling = if ($processors) { $processors } else { "non configure" }
        HostTotalRamGB    = $hostTotalGB
        RatioOfHostPct    = $ratioPct
        Scope             = "GLOBAL - s'applique a toutes les distributions, pas par-distribution"
    }
}

# ---- VHDX : completion documentaire RESOURCE-MODEL.md SS8 --------------

function Get-DistroVhdxInfo {
    <#
    .SYNOPSIS
        Localise et mesure le VHDX d'une distribution WSL2 via le
        registre (HKCU:\...\Lxss\{GUID}\BasePath, puis taille du fichier
        ext4.vhdx) - jamais son contenu, jamais son ouverture. Ne
        retourne jamais $null en silence : Reason explicite si le
        registre ou le fichier est absent.
    #>
    param([Parameter(Mandatory)][string]$Distro)

    $result = [PSCustomObject]@{
        Distro   = $Distro
        SizeGB   = $null
        BasePath = $null
        Success  = $false
        Reason   = ""
    }

    $lxssRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    if (-not (Test-Path $lxssRoot)) {
        $result.Reason = "Cle de registre Lxss introuvable."
        return $result
    }

    $match = Get-ChildItem $lxssRoot -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DistributionName -eq $Distro
    } | Select-Object -First 1

    if ($null -eq $match) {
        $result.Reason = "Distribution '$Distro' non trouvee dans le registre Lxss."
        return $result
    }

    $basePath = (Get-ItemProperty $match.PSPath -ErrorAction SilentlyContinue).BasePath
    if ([string]::IsNullOrEmpty($basePath)) {
        $result.Reason = "Cle BasePath absente pour '$Distro'."
        return $result
    }
    $result.BasePath = $basePath

    $vhdxPath = Join-Path $basePath "ext4.vhdx"
    if (-not (Test-Path $vhdxPath)) {
        $result.Reason = "Fichier ext4.vhdx introuvable a l'emplacement attendu : $vhdxPath"
        return $result
    }

    $result.SizeGB  = [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
    $result.Success = $true
    $result.Reason  = "OK"
    return $result
}

# ---- Distributions --------------------------------------------------

function Get-DistroInventory {
    <#
    .SYNOPSIS
        Enumere les distributions actives - reutilise Get-WslActiveSessions
        (modules/ProfileManager.ps1) plutot que d'appeler "wsl" a nouveau.
    #>
    return @(Get-WslActiveSessions)
}

# ---- Attribution memoire (P1/GuestReader) -------------------------------

function Get-DiagnoseMemoryAttribution {
    <#
    .SYNOPSIS
        Combine MemInfo et ProcRss (Invoke-GuestRead, GuestReader.ps1) pour
        attribuer la memoire invitee par processus. Le reste "non
        attribue" peut etre negatif (docs/RESOURCE-MODEL.md SS4.4 - pages
        partagees comptees plusieurs fois dans la somme des RSS) et le dit
        explicitement plutot que de clamper a zero. Retourne un statut
        "indisponible" nomme, jamais un $null silencieux, quand le
        consentement n'est pas accorde ou qu'aucune session n'est active.
    #>
    param([string]$Distro = "")

    $consent = Get-GuestReadConsentState
    if ($consent -ne "granted") {
        return [PSCustomObject]@{
            Available = $false
            Reason    = "Consentement de lecture invitee non accorde (etat : $consent). Active-le avec : wisely -Consent grant"
        }
    }

    if ($Distro -eq "") {
        $activeSessions = Get-WslActiveSessions
        if ($activeSessions.Count -eq 0) {
            return [PSCustomObject]@{ Available = $false; Reason = "Aucune distribution WSL2 active." }
        }
        if ($activeSessions.Count -gt 1) {
            return [PSCustomObject]@{
                Available = $false
                Reason    = "Plusieurs distributions actives ($($activeSessions -join ', ')) - precise -Distro <nom>."
            }
        }
        $Distro = $activeSessions[0]
    }

    try {
        $memRaw = Invoke-GuestRead -CommandKey "MemInfo" -Distro $Distro
        $mem    = ConvertFrom-MemInfo -RawOutput $memRaw

        $procRaw   = Invoke-GuestRead -CommandKey "ProcRss" -Distro $Distro
        $processes = [System.Collections.Generic.List[PSCustomObject]]::new()
        $totalRssGB = 0.0
        foreach ($line in ($procRaw -split "`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^(\d+)\s+(\S+)$') {
                $rssGB = [math]::Round([double]$matches[1] / 1MB, 3)
                $processes.Add([PSCustomObject]@{ Command = $matches[2]; RssGB = $rssGB })
                $totalRssGB += $rssGB
            }
        }

        $usedGB         = [math]::Round($mem.MemTotalGB - $mem.MemAvailableGB, 2)
        $attributedGB   = [math]::Round($totalRssGB, 2)
        $unattributedGB = [math]::Round($usedGB - $attributedGB, 2)

        return [PSCustomObject]@{
            Available      = $true
            Distro         = $Distro
            MemTotalGB     = $mem.MemTotalGB
            MemAvailableGB = $mem.MemAvailableGB
            CachedGB       = $mem.CachedGB
            UsedGB         = $usedGB
            AttributedGB   = $attributedGB
            UnattributedGB = $unattributedGB
            Processes      = @($processes | Sort-Object RssGB -Descending)
        }
    } catch {
        return [PSCustomObject]@{ Available = $false; Reason = "$_" }
    }
}

# ---- Orchestrateur -----------------------------------------------------

function Get-DiagnoseReport {
    <#
    .SYNOPSIS
        Orchestrateur du diagnostic. Retourne un objet structure ou
        chaque ligne porte Value/Unit/Scope/Class/Confidence/Source,
        alignes sur le contrat de metrique de docs/RESOURCE-MODEL.md SS3
        - testable sans parser du texte.
    #>
    param([string]$Distro = "")

    $lines = [System.Collections.Generic.List[PSCustomObject]]::new()

    $wslConfigExists = Test-Path (Get-WslConfigPath)
    $wslConfigValid  = if ($wslConfigExists) { Test-WslConfigIntegrity } else { $false }
    $lines.Add([PSCustomObject]@{
        Question = "que se passe-t-il"; Label = ".wslconfig"
        Value    = if (-not $wslConfigExists) { "absent" } elseif ($wslConfigValid) { "valide" } else { "invalide" }
        Unit = ""; Scope = "host"; Class = "directe"; Confidence = "haute"; Source = "Test-WslConfigIntegrity"
    })

    $reclaim = Get-AutoMemoryReclaimStatus
    $lines.Add([PSCustomObject]@{
        Question = "que se passe-t-il"; Label = "autoMemoryReclaim"
        Value    = $reclaim.Value
        Unit = ""; Scope = $reclaim.Scope; Class = "directe"; Confidence = "haute"; Source = ".wslconfig"
    })

    $rawKeys = Get-WslConfigRawKeys
    $sparseVhdPresent = "sparseVhd" -in $rawKeys
    $lines.Add([PSCustomObject]@{
        Question = "que se passe-t-il"; Label = "sparseVhd"
        Value    = if ($sparseVhdPresent) { "presente dans .wslconfig (regime non determine - hors perimetre P2)" } else { "absente" }
        Unit = ""; Scope = "policy"; Class = "directe"; Confidence = "haute"; Source = ".wslconfig"
    })

    $distros = Get-DistroInventory
    $lines.Add([PSCustomObject]@{
        Question = "que se passe-t-il"; Label = "Distributions actives"
        Value    = if ($distros.Count -eq 0) { "aucune" } else { $distros -join ", " }
        Unit = ""; Scope = "host"; Class = "directe"; Confidence = "haute"; Source = "wsl --list --running --quiet"
    })

    foreach ($d in $distros) {
        $vhdx = Get-DistroVhdxInfo -Distro $d
        $lines.Add([PSCustomObject]@{
            Question = "que se passe-t-il"; Label = "Taille VHDX ($d)"
            Value    = if ($vhdx.Success) { $vhdx.SizeGB } else { "indisponible - $($vhdx.Reason)" }
            Unit = if ($vhdx.Success) { "GB" } else { "" }
            Scope = "distro"; Class = "directe"; Confidence = "haute"
            Source = "registre Lxss + taille fichier ext4.vhdx"
        })
    }

    $ceiling = Get-WslCeilingInfo
    $ceilingDetail = if ($ceiling.RatioOfHostPct) {
        " (soit $($ceiling.RatioOfHostPct)% de la RAM hote, $($ceiling.HostTotalRamGB) GB)"
    } else { "" }
    $lines.Add([PSCustomObject]@{
        Question = "pourquoi"; Label = "Plafond RAM (.wslconfig)"
        Value    = "$($ceiling.MemoryCeiling)$ceilingDetail"
        Unit = ""; Scope = $ceiling.Scope; Class = "directe"; Confidence = "haute"; Source = ".wslconfig + Win32_OperatingSystem"
    })

    $consent = Get-GuestReadConsentState
    $lines.Add([PSCustomObject]@{
        Question = "que puis-je faire"; Label = "Consentement lecture invitee"
        Value    = $consent
        Unit = ""; Scope = "policy"; Class = "directe"; Confidence = "haute"; Source = "profiles.json settings.guestReadConsent"
    })

    $attribution = Get-DiagnoseMemoryAttribution -Distro $Distro
    if ($attribution.Available) {
        $lines.Add([PSCustomObject]@{
            Question = "est-ce dangereux"; Label = "Memoire attribuee ($($attribution.Distro))"
            Value    = "$($attribution.AttributedGB) GB attribues sur $($attribution.UsedGB) GB utilises - $($attribution.UnattributedGB) GB non attribue"
            Unit = "GB"; Scope = "process"; Class = "attribuee"; Confidence = "moyenne"
            Source = "ps -eo rss,comm --sort=-rss (Invoke-GuestRead)"
        })
    } else {
        $lines.Add([PSCustomObject]@{
            Question = "est-ce dangereux"; Label = "Memoire attribuee"
            Value    = "indisponible - $($attribution.Reason)"
            Unit = ""; Scope = "process"; Class = "attribuee"; Confidence = "basse"; Source = "Invoke-GuestRead"
        })
    }

    return [PSCustomObject]@{
        GeneratedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Distro      = $Distro
        Lines       = @($lines)
        Ceiling     = $ceiling
        Attribution = $attribution
    }
}

# ---- Affichage -----------------------------------------------------

function Show-DiagnoseReport {
    <#
    .SYNOPSIS
        Rend le rapport de Get-DiagnoseReport dans l'ordre impose par
        docs/ROADMAP.md : que se passe-t-il / pourquoi / dangereux / que
        faire / est-ce que ca vaut le coup.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$Report)

    $order = @("que se passe-t-il", "pourquoi", "est-ce dangereux", "que puis-je faire")
    $titles = [ordered]@{
        "que se passe-t-il" = "QUE SE PASSE-T-IL ?"
        "pourquoi"          = "POURQUOI ?"
        "est-ce dangereux"  = "EST-CE DANGEREUX ?"
        "que puis-je faire" = "QUE PUIS-JE FAIRE ?"
    }

    Write-Host ""
    Write-Host "  Wisely -- Diagnostic" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * 60)) -ForegroundColor DarkGray

    foreach ($question in $order) {
        $questionLines = @($Report.Lines | Where-Object { $_.Question -eq $question })
        Write-Host ""
        Write-Host "  $($titles[$question])" -ForegroundColor Yellow
        if ($questionLines.Count -eq 0) {
            Write-Host "    (rien a signaler)" -ForegroundColor DarkGray
            continue
        }
        foreach ($line in $questionLines) {
            $unitStr = if ($line.Unit) { " $($line.Unit)" } else { "" }
            Write-Host "    $($line.Label) : $($line.Value)$unitStr" -ForegroundColor Gray
            Write-Host "      [$($line.Scope) / $($line.Class) / confiance $($line.Confidence)]" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  EST-CE QUE CA VAUT LE COUP DE CHANGER QUELQUE CHOSE ?" -ForegroundColor Yellow
    if ($Report.Attribution.Available -and $Report.Attribution.UnattributedGB -lt 0) {
        Write-Host "    Reste non attribue negatif ($($Report.Attribution.UnattributedGB) GB) - pages partagees comptees" -ForegroundColor DarkGray
        Write-Host "    plusieurs fois dans la somme des RSS (docs/RESOURCE-MODEL.md SS4.4). Pas une anomalie." -ForegroundColor DarkGray
    } elseif ($Report.Ceiling.RatioOfHostPct -and $Report.Ceiling.RatioOfHostPct -ge 80) {
        Write-Host "    Plafond configure a $($Report.Ceiling.RatioOfHostPct)% de la RAM hote - marge de manoeuvre reduite." -ForegroundColor DarkGray
    } else {
        Write-Host "    Rien de mesure ici ne signale un changement necessaire." -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Show-DiagnoseExplain {
    <#
    .SYNOPSIS
        Explique une cle .wslconfig : geree par Wisely, connue mais non
        geree ($script:KnownWslConfigKeys), ou inconnue (jamais inventee).
    #>
    param([Parameter(Mandatory)][string]$Key)

    Write-Host ""
    if ($Key -in $script:WiselyManagedWslConfigKeys) {
        Write-Host "  '$Key' est geree par Wisely." -ForegroundColor Green
        Write-Host "  Voir l'affichage normal (wisely -Status, ou le profil actif) pour sa valeur courante." -ForegroundColor DarkGray
    } elseif ($script:KnownWslConfigKeys.Contains($Key)) {
        $info = $script:KnownWslConfigKeys[$Key]
        Write-Host "  '$Key' n'est pas geree par Wisely." -ForegroundColor Yellow
        Write-Host "  $($info.Summary)" -ForegroundColor Gray
        if ($info.CoveredByWslSettings) {
            Write-Host "  Deja couverte par l'application WSL Settings (Microsoft)." -ForegroundColor DarkGray
        } else {
            Write-Host "  Non exposee dans WSL Settings - modification manuelle de .wslconfig requise." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  '$Key' n'est pas reconnue." -ForegroundColor Red
        Write-Host "  Ni geree par Wisely, ni dans la liste des cles .wslconfig connues." -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Get-DiagnoseHistoryClassification {
    <#
    .SYNOPSIS
        Classe une entree d'historique existant (data/history.json) comme
        attribuable ou ecartee (avec raison). N'introduit aucune nouvelle
        piste de consommation - etend la lecture de l'historique de switch
        existant ; la vraie historisation de consommation est le mandat
        de P4.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Entry,
        [string[]]$KnownProfileKeys = @()
    )

    if ($Entry.action -ne "SWITCH") {
        return [PSCustomObject]@{ Attributable = $false; Reason = "hors perimetre du switch - $($Entry.action)" }
    }
    if ($null -eq $Entry.restartSeconds) {
        return [PSCustomObject]@{ Attributable = $false; Reason = "temps d'arret non mesure" }
    }
    if ($Entry.profile -notin $KnownProfileKeys) {
        return [PSCustomObject]@{ Attributable = $false; Reason = "profil renomme ou supprime depuis" }
    }
    return [PSCustomObject]@{ Attributable = $true; Reason = "" }
}

function Show-DiagnoseHistory {
    <#
    .SYNOPSIS
        Affiche l'historique de switch existant avec sa classification
        d'attribuabilite (Get-DiagnoseHistoryClassification), plutot
        qu'un rapport silencieusement clairseme (principe 9).
    #>
    param([int]$Last = 10)

    $historyPath = Get-HistoryPath
    if (-not (Test-Path $historyPath)) {
        Write-Host ""
        Write-Host "  Aucun historique disponible." -ForegroundColor Gray
        Write-Host ""
        return
    }

    $raw = Get-Content $historyPath -Raw -Encoding UTF8
    try {
        $history = @(($raw | ConvertFrom-Json))
    } catch {
        Write-Host ""
        Write-Host "  Historique corrompu, illisible." -ForegroundColor Gray
        Write-Host ""
        return
    }

    if ($history.Count -eq 0) {
        Write-Host ""
        Write-Host "  Historique vide." -ForegroundColor Gray
        Write-Host ""
        return
    }

    $knownProfileKeys = @()
    try { $knownProfileKeys = @((Get-ProfileConfig).profiles.PSObject.Properties.Name) } catch { $knownProfileKeys = @() }

    $recent = $history | Select-Object -Last $Last

    Write-Host ""
    Write-Host "  Historique -- attribuabilite ($Last derniers evenements)" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * 60)) -ForegroundColor DarkGray

    foreach ($entry in $recent) {
        $cls   = Get-DiagnoseHistoryClassification -Entry $entry -KnownProfileKeys $knownProfileKeys
        $label = if ($cls.Attributable) { "attribuable" } else { "ecarte ($($cls.Reason))" }
        $color = if ($cls.Attributable) { "Green" } else { "DarkGray" }
        Write-Host "  $($entry.timestamp)  $($entry.action.PadRight(10)) $($entry.profile.PadRight(11)) $label" -ForegroundColor $color
    }

    Write-Host ("  " + ("-" * 60)) -ForegroundColor DarkGray
    Write-Host ""
}
