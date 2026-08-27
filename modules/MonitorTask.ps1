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

function Get-WslMemoryCeilingBytes {
    <#
    .SYNOPSIS
        Lit le plafond memoire configure dans .wslconfig (memory=), en
        octets. C'est la Politique au sens de RESOURCE-MODEL.md, la seule
        portee valide pour un pourcentage d'usage WSL2 - la RAM totale de
        la machine (portee host) n'est jamais le bon denominateur.
        Retourne $null si .wslconfig est absent, illisible, ou si la cle
        memory= est absente ou dans un format non reconnu (entier suivi
        de GB ou MB) - jamais une supposition a la place d'une mesure
        (principe 9).
    #>
    $configPath = Join-Path $env:USERPROFILE ".wslconfig"
    if (-not (Test-Path $configPath)) { return $null }
    try {
        $line = Get-Content $configPath -ErrorAction Stop |
                Where-Object { $_ -match "^memory=" } |
                Select-Object -First 1
    } catch {
        return $null
    }
    if (-not $line) { return $null }
    $value = $line -replace "^memory=", ""
    if ($value -match "^(\d+)\s*GB$")  { return [int64]$Matches[1] * 1GB }
    if ($value -match "^(\d+)\s*MB$")  { return [int64]$Matches[1] * 1MB }
    return $null
}

# "vmmem" sur les versions plus anciennes de Windows, "VmmemWSL" sur
# Windows 11 recent - les deux noms sont acceptes (v2.5, voir
# RESOURCE-MODEL.md).
$vmmem = Get-Process -Name "VmmemWSL", "vmmem" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $vmmem) { exit 0 }

$ceilingBytes = Get-WslMemoryCeilingBytes
if (-not $ceilingBytes) {
    # Sans plafond connu, aucun pourcentage n'a de sens - on journalise et
    # on s'arrete plutot que de deviner ou de planter silencieusement a
    # chaque execution planifiee (voir AUDIT.md, dette de resilience v2.3 ;
    # RESOURCE-MODEL.md, ne jamais melanger les portees).
    Write-MonitorTaskError "Plafond WSL2 introuvable ou illisible dans .wslconfig - alerte ignoree"
    exit 0
}
$pct = [math]::Round($vmmem.WorkingSet64 / $ceilingBytes * 100, 0)

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

$usedGB    = [math]::Round($vmmem.WorkingSet64 / 1GB, 1)
$ceilingGB = [math]::Round($ceilingBytes / 1GB, 1)
$appId     = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

$xml = "<toast><visual><binding template='ToastGeneric'>" +
       "<text>WSL2 - Alerte memoire</text>" +
       "<text>RAM : $pct% du plafond utilise ($usedGB GB / $ceilingGB GB)</text>" +
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
