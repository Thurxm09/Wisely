# Script autonome execute directement par le Planificateur de taches
# Windows (JAMAIS dot-source) - "exit" est correct ici, contrairement aux
# modules/*.ps1 dot-sources dans wisely.ps1 qui doivent utiliser "throw".
param([int]$ThresholdPct = 80, [int]$CooldownMin = 30)

$scriptDir    = $PSScriptRoot
$cooldownFile = Join-Path $scriptDir "..\data\monitor_cooldown.txt"
$errorLog     = Join-Path $scriptDir "..\data\monitor_errors.txt"

function Write-MonitorTaskError {
    param([string]$Message)
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" | Add-Content $errorLog -Encoding ASCII
}

# "vmmem" sur les versions plus anciennes de Windows, "VmmemWSL" sur
# Windows 11 recent - les deux noms sont acceptes (v2.5, voir
# RESOURCE-MODEL.md).
$vmmem = Get-Process -Name "VmmemWSL", "vmmem" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $vmmem) { exit 0 }

try {
    $os        = Get-CimInstance Win32_OperatingSystem
    $totalKB   = $os.TotalVisibleMemorySize
    $usedByWsl = [math]::Round($vmmem.WorkingSet64 / 1KB, 0)
    $pct       = [math]::Round($usedByWsl / $totalKB * 100, 0)
} catch {
    # Sans cette mesure, on ne sait pas si le seuil est depasse - on
    # journalise et on s'arrete plutot que de planter silencieusement a
    # chaque execution planifiee (voir AUDIT.md, dette de resilience v2.3).
    Write-MonitorTaskError "Mesure RAM impossible : $_"
    exit 0
}

if ($pct -lt $ThresholdPct) { exit 0 }

if (Test-Path $cooldownFile) {
    try {
        $lastAlert = [datetime]::ParseExact(
            (Get-Content $cooldownFile -Raw).Trim(),
            "yyyy-MM-dd HH:mm:ss", $null
        )
        if ((New-TimeSpan -Start $lastAlert -End (Get-Date)).TotalMinutes -lt $CooldownMin) { exit 0 }
    } catch {
        # Fichier cooldown illisible/corrompu : on journalise et on
        # continue - le seuil est deja depasse, mieux vaut alerter (et
        # regenerer un cooldown valide juste apres) que de rester
        # silencieux indefiniment a cause d'un fichier casse une fois.
        Write-MonitorTaskError "Fichier cooldown illisible, ignore : $_"
    }
}

(Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Set-Content $cooldownFile -Encoding ASCII

$usedGB  = [math]::Round($vmmem.WorkingSet64 / 1GB, 1)
$totalGB = [math]::Round($totalKB / 1MB, 1)
$appId   = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

$xml = "<toast><visual><binding template='ToastGeneric'>" +
       "<text>WSL2 - Alerte memoire</text>" +
       "<text>RAM : $pct% utilise ($usedGB GB / $totalGB GB)</text>" +
       "<text>Pensez a switcher vers un profil plus leger.</text>" +
       "</binding></visual></toast>"

try {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime]
    $doc = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $doc.LoadXml($xml)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($doc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
} catch {
    Write-MonitorTaskError "Toast error : $_"
}
