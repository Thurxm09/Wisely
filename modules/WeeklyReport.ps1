# WeeklyReport.ps1
# Genere un rapport hebdomadaire depuis history.json.
# Peut etre appele manuellement ou par tache planifiee.

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

$history = @(Get-Content $historyPath -Raw | ConvertFrom-Json)
if ($history.Count -eq 0) {
    if (-not $Silent) { Write-Host "  Historique vide." -ForegroundColor Gray }
    exit 0
}

$weekAgo = (Get-Date).AddDays(-7)

$switches = @($history | Where-Object {
    $_.action -eq "SWITCH" -and
    [datetime]::ParseExact($_.timestamp, "yyyy-MM-dd HH:mm:ss", $null) -ge $weekAgo
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

    # RAM moyenne observee par profil (Axe 6 - Observabilite, v2.3). Basee
    # sur ramDeltaGB (delta de RAM Windows disponible mesure au moment du
    # switch, journalise par Write-SwitchLog depuis v2.3 - voir
    # modules/Logger.ps1). N'est PAS un usage moyen soutenu pendant que le
    # profil est actif : uniquement les profils ayant au moins une mesure
    # dans la fenetre de 7 jours apparaissent (historique pre-v2.3 ou
    # mesure indisponible sur la machine => silencieusement omis).
    $ramLines = @()
    foreach ($g in $grouped) {
        $ramValues = @($g.Group | Where-Object { $null -ne $_.ramDeltaGB } | ForEach-Object { $_.ramDeltaGB })
        if ($ramValues.Count -eq 0) { continue }
        $avgRam = [math]::Round(($ramValues | Measure-Object -Average).Average, 1)
        $sign   = if ($avgRam -ge 0) { "+" } else { "" }
        $ramLines += ("  " + $g.Name.PadRight(16) + "${sign}${avgRam}GB")
    }
    if ($ramLines.Count -gt 0) {
        $lines += ""
        $lines += "RAM liberee/consommee en moyenne au switch (+ = liberee, - = consommee) :"
        $lines += "-" * 30
        $lines += $ramLines
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
