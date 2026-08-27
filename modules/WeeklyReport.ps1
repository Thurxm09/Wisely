# WeeklyReport.ps1
# Genere un rapport hebdomadaire depuis history.json.
# Peut etre appele manuellement ou par tache planifiee.
#
# Script autonome execute directement par le Planificateur de taches
# Windows (JAMAIS dot-source) - "exit" est correct ici, contrairement aux
# modules/*.ps1 dot-sources dans wisely.ps1 qui doivent utiliser "throw".

param([switch]$Silent)

$historyPath = Join-Path $PSScriptRoot "..\data\history.json"
$reportsDir  = Join-Path $PSScriptRoot "..\data\reports"

if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir | Out-Null
}

if (-not (Test-Path $historyPath)) {
    if (-not $Silent) { Write-Host "  Aucun historique disponible." -ForegroundColor Gray }
    exit 0
}

try {
    $history = @(Get-Content $historyPath -Raw | ConvertFrom-Json)
} catch {
    # history.json corrompu : ce script tourne sans surveillance (tache
    # planifiee -Silent chaque lundi) - on journalise plutot que de
    # planter silencieusement et de ne plus jamais produire de rapport.
    if (-not $Silent) { Write-Host "  Historique corrompu, illisible." -ForegroundColor Gray }
    exit 0
}
if ($history.Count -eq 0) {
    if (-not $Silent) { Write-Host "  Historique vide." -ForegroundColor Gray }
    exit 0
}

$weekAgo = (Get-Date).AddDays(-7)

# Chaque entree est validee individuellement (try/catch autour du parsing
# du timestamp) : une seule entree malformee ne doit pas faire echouer
# tout le rapport - elle est simplement exclue.
$switches = @($history | Where-Object {
    if ($_.action -ne "SWITCH") { return $false }
    try {
        return ([datetime]::ParseExact($_.timestamp, "yyyy-MM-dd HH:mm:ss", $null) -ge $weekAgo)
    } catch {
        return $false
    }
})

# ---- Construction du rapport ----------------------------------------

$lines = @()
$lines += "Wisely - Rapport hebdomadaire"
$lines += "Genere le : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "Periode   : $($weekAgo.ToString('yyyy-MM-dd')) -> $(Get-Date -Format 'yyyy-MM-dd')"
$lines += "=" * 50

if ($switches.Count -eq 0) {
    $lines += ""
    $lines += "Aucun switch enregistre cette semaine."
    $lines += ""
} else {
    $lines += ""
    $lines += "Repartition par profil :"
    $lines += "-" * 30

    $grouped  = $switches | Group-Object -Property profile | Sort-Object Count -Descending
    $dominant = $grouped | Select-Object -First 1
    $total    = $switches.Count

    foreach ($g in $grouped) {
        $pct = [math]::Round($g.Count / $total * 100, 0)
        $bar = "#" * [math]::Round($pct / 5)
        $lines += ("  " + $g.Name.PadRight(16) + $bar.PadRight(20) + " $($g.Count)x ($pct%)")
    }

    $lines += ""
    $lines += "Profil dominant   : $($dominant.Name.ToUpper()) ($($dominant.Count) activations)"
    $lines += "Total de switchs  : $total"

    $byDay = $switches | Group-Object {
        [datetime]::ParseExact($_.timestamp, "yyyy-MM-dd HH:mm:ss", $null).DayOfWeek
    } | Sort-Object Count -Descending | Select-Object -First 1
    if ($byDay) { $lines += "Jour le plus actif: $($byDay.Name) ($($byDay.Count) switchs)" }

    $byHour = $switches | Group-Object {
        [datetime]::ParseExact($_.timestamp, "yyyy-MM-dd HH:mm:ss", $null).Hour
    } | Sort-Object Count -Descending | Select-Object -First 1
    if ($byHour) { $lines += "Heure de pointe   : $($byHour.Name)h00 ($($byHour.Count) switchs)" }

    $lines += ""
    $lines += "-" * 30
    $lines += ""
    $lines += "Derniers switchs (5) :"
    $switches | Select-Object -Last 5 | ForEach-Object {
        $lines += ("  " + $_.timestamp + "  " + $_.profile.PadRight(14) + $_.details)
    }
}

$cooldown = Join-Path $PSScriptRoot "..\data\monitor_cooldown.txt"
if (Test-Path $cooldown) {
    $lines += ""
    $lines += "Derniere alerte RAM : $((Get-Content $cooldown -Raw).Trim())"
}

$errors = Join-Path $PSScriptRoot "..\data\monitor_errors.txt"
if ((Test-Path $errors) -and (Get-Content $errors).Count -gt 0) {
    $lines += "Erreurs Toast       : $((Get-Content $errors).Count) (voir data\monitor_errors.txt)"
}

$lines += ""
$lines += "=" * 50
$lines += "Fin du rapport."

# ---- Ecriture + rotation (12 max) -----------------------------------

$reportPath = Join-Path $reportsDir ("report_" + (Get-Date -Format "yyyy-MM-dd") + ".txt")
$lines | Set-Content $reportPath -Encoding UTF8

$allReports = Get-ChildItem $reportsDir -Filter "report_*.txt" | Sort-Object Name
if ($allReports.Count -gt 12) {
    $allReports | Select-Object -First ($allReports.Count - 12) | Remove-Item -Force
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  Rapport genere : $reportPath" -ForegroundColor Green
    Write-Host ""
    $lines | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
}
