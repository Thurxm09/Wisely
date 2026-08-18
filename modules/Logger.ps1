# ============================================================
#  Logger.ps1 — Historique des switchs de profil
#  Dot-sourcé depuis wisely.ps1
#  Utilise $Global:WSLRoot défini dans le script principal
# ============================================================

function Get-HistoryPath {
    Join-Path $Global:WSLRoot "data\history.json"
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
    #>
    param(
        [Parameter(Mandatory)][string]$Action,
        [string]$ProfileKey = "N/A",
        [string]$Details = ""
    )

    $historyPath = Get-HistoryPath

    $entry = [PSCustomObject]@{
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        action    = $Action
        profile   = $ProfileKey
        details   = $Details
        user      = $env:USERNAME
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
    $maxEntries = 100
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
    $history = $raw | ConvertFrom-Json

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
    Write-Host "  ──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  DATE/HEURE            ACTION    PROFIL     DETAILS" -ForegroundColor DarkGray
    Write-Host "  ──────────────────────────────────────────────────" -ForegroundColor DarkGray

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

    Write-Host "  ──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}