# ============================================================
#  Logger.ps1 — Historique des switchs de profil
#  Dot-sourcé depuis wisely.ps1
#  Utilise $Global:WSLRoot défini dans le script principal
# ============================================================

function Get-HistoryPath {
    Join-Path $Global:WSLRoot "data\history.json"
}

function Get-HistoryMaxEntries {
    $default = 100
    try {
        $cfg = Get-ProfileConfig
        if ($cfg.settings.historyMaxEntries) { return [int]$cfg.settings.historyMaxEntries }
        return $default
    } catch {
        return $default
    }
}

function Write-SwitchLog {
    <#
    .SYNOPSIS
        Enregistre un événement dans l'historique JSON.
    .PARAMETER Action
        Type d'action : SWITCH | ROLLBACK | CUSTOM | IMPORT | EXPORT
    .PARAMETER ProfileKey
        Clé du profil concerné (ex: "web", "data")
    .PARAMETER Details
        Informations complémentaires libres
    .PARAMETER RamDeltaGB
        Delta de RAM Windows disponible entre avant et après le switch
        (positif = RAM libérée, négatif = RAM consommée). $null si non
        mesurable (ex: Get-CimInstance indisponible). Metrique v2.3
        (observabilite) - voir docs/ROADMAP.md Axe 6.
    .PARAMETER RestartSeconds
        Temps mesuré de l'arrêt WSL2 (wsl --shutdown + délai de
        stabilisation). $null si non applicable. Metrique v2.3.
    #>
    param(
        [Parameter(Mandatory)][string]$Action,
        [string]$ProfileKey = "N/A",
        [string]$Details = "",
        [Nullable[double]]$RamDeltaGB = $null,
        [Nullable[double]]$RestartSeconds = $null
    )

    $historyPath = Get-HistoryPath

    # $env:USERNAME est propre a Windows ; $env:USER est l'equivalent sur
    # WSL2/Linux (ex: Pester en CI sur ubuntu-latest) ou l'un des deux peut
    # etre absent selon le contexte d'execution.
    $currentUser = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { "unknown" }

    $entry = [PSCustomObject]@{
        timestamp      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        action         = $Action
        profile        = $ProfileKey
        details        = $Details
        user           = $currentUser
        ramDeltaGB     = $RamDeltaGB
        restartSeconds = $RestartSeconds
    }

    # Charger l'historique existant ou initialiser
    $history = @()
    if (Test-Path $historyPath) {
        try {
            $raw = Get-Content $historyPath -Raw -Encoding UTF8
            $parsed = $raw | ConvertFrom-Json
            if ($null -ne $parsed) { $history = @($parsed) }
        }
        catch {
            # Fichier corrompu — on repart d'un historique vide sans crasher
            $history = @()
        }
    }

    $history += $entry

    # Écrêtage : on garde les N dernières entrées
    $maxEntries = Get-HistoryMaxEntries
    if ($history.Count -gt $maxEntries) {
        $history = $history[($history.Count - $maxEntries)..($history.Count - 1)]
    }

    $history | ConvertTo-Json -Depth 5 | Set-Content $historyPath -Encoding UTF8
}

function Show-SwitchHistory {
    <#
    .SYNOPSIS
        Affiche les derniers switchs de profil dans le terminal.
    .PARAMETER Last
        Nombre d'entrées à afficher (défaut : 10)
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
        $history = $raw | ConvertFrom-Json
    } catch {
        # Meme resilience que Write-SwitchLog face a un history.json
        # corrompu : message explicite plutot qu'une exception non geree
        # (wisely -History l'appelle sans try/catch autour).
        Write-Host ""
        Write-Host "  Historique corrompu, illisible." -ForegroundColor Gray
        Write-Host ""
        return
    }

    if ($null -eq $history -or @($history).Count -eq 0) {
        Write-Host ""
        Write-Host "  Historique vide." -ForegroundColor Gray
        Write-Host ""
        return
    }

    $history = @($history)
    $recent  = $history | Select-Object -Last $Last

    Write-Host ""
    Write-Host "  Historique — $Last derniers événements" -ForegroundColor Cyan
    Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
    Write-Host "  DATE/HEURE            ACTION    PROFIL     DETAILS" -ForegroundColor DarkGray
    Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray

    foreach ($entry in $recent) {
        $profileColor = switch ($entry.profile) {
            "web"   { "Green" }
            "data"  { "Yellow" }
            "base"  { "Cyan" }
            default { "Gray" }
        }
        $actionColor = switch ($entry.action) {
            "SWITCH"   { "White" }
            "ROLLBACK" { "DarkYellow" }
            "CUSTOM"   { "Magenta" }
            default    { "Gray" }
        }

        Write-Host "  $($entry.timestamp)  " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($entry.action.PadRight(10))" -NoNewline -ForegroundColor $actionColor
        Write-Host "$($entry.profile.PadRight(11))" -NoNewline -ForegroundColor $profileColor
        Write-Host "$($entry.details)" -ForegroundColor DarkGray
    }

    Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray
    Write-Host ""
}
