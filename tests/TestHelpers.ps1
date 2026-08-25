# ============================================================
#  TestHelpers.ps1 - Utilitaires partages pour les tests Pester
#  Dot-source depuis les fichiers *.Tests.ps1 (jamais execute seul)
# ============================================================
#
#  Piege connu (voir docs/ROADMAP.md paragraphe 7) : les tests tournent
#  aussi sur un runner Linux en CI. Verifie empiriquement sur ce runner :
#  Join-Path "$root" "data\profiles.json" normalise bel et bien le
#  backslash en separateur reel (donne "$root/data/profiles.json"), donc
#  "data" doit exister comme un vrai sous-dossier - contrairement a
#  l'hypothese initiale. $env:USERPROFILE est egalement vide par defaut.
#  Ces helpers passent toujours par les vraies fonctions
#  Get-ProfilesPath / Get-WslConfigPath / Get-HistoryPath plutot que de
#  recomposer un chemin a la main, pour rester valables sur les deux
#  plateformes quel que soit le comportement reel de Join-Path.

function New-TestWslRoot {
    <#
    .SYNOPSIS
        Cree un dossier temporaire isole (avec son sous-dossier "data",
        comme le fait wisely.ps1 au demarrage) et le declare comme
        $Global:WSLRoot.
    #>
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("wisely-test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root "data") -Force | Out-Null
    $Global:WSLRoot = $root
    return $root
}

function Remove-TestWslRoot {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-TestUserProfile {
    <#
    .SYNOPSIS
        Redirige $env:USERPROFILE vers le dossier sandbox, pour que
        Get-WslConfigPath (Join-Path $env:USERPROFILE ".wslconfig")
        reste valide meme sur un runner Linux ou USERPROFILE est vide.
    #>
    param([Parameter(Mandatory)][string]$Path)
    $script:WiselyTestOriginalUserProfile = $env:USERPROFILE
    $env:USERPROFILE = $Path
}

function Restore-TestUserProfile {
    $env:USERPROFILE = $script:WiselyTestOriginalUserProfile
}

function New-TestProfilesJson {
    <#
    .SYNOPSIS
        Ecrit un profiles.json de test a l'emplacement reellement resolu
        par Get-ProfilesPath (jamais un chemin recompose a la main).
    #>
    param([Parameter(Mandatory)]$Config)
    $path = Get-ProfilesPath
    $dir  = Split-Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Set-TestProfilesRaw {
    <#
    .SYNOPSIS
        Ecrit un contenu brut (potentiellement invalide, y compris vide)
        a l'emplacement reellement resolu par Get-ProfilesPath. Cree le
        dossier parent si besoin, comme New-TestProfilesJson.
    #>
    param([string]$Content = "")
    $path = Get-ProfilesPath
    $dir  = Split-Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $path -Value $Content -Encoding UTF8
    return $path
}

function New-TestWslConfig {
    <#
    .SYNOPSIS
        Ecrit un .wslconfig de test a l'emplacement reellement resolu
        par Get-WslConfigPath.
    #>
    param([string]$Content = "[wsl2]`nmemory=4GB`nprocessors=3`n")
    $path = Get-WslConfigPath
    $dir  = Split-Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $path -Value $Content -Encoding UTF8
    return $path
}

function Enable-WslMocks {
    <#
    .SYNOPSIS
        Empeche les tests de toucher au systeme reel : mock la commande
        externe "wsl" (wsl --shutdown, wsl --list --running --quiet) et
        Start-Sleep. "wsl" n'existe pas du tout sur le runner Linux de la
        CI - Pester refuse de mocker une commande introuvable, donc on la
        stub d'abord si necessaire.
    .PARAMETER RunningDistros
        Distributions a renvoyer pour "wsl --list --running --quiet".
        Vide par defaut (aucune session WSL2 active), pour preserver le
        comportement des tests existants qui n'en ont pas besoin.
    .NOTES
        Get-WslActiveSessions verifie $LASTEXITCODE apres l'appel a "wsl"
        pour decider si la commande a reussi. Mocker "wsl" remplace l'appel
        natif par une fonction PowerShell - or une fonction n'ecrit jamais
        $LASTEXITCODE (seuls les executables natifs le font). Sans reset
        explicite ici, $LASTEXITCODE garde la valeur laissee par le dernier
        appel natif execute ailleurs dans le processus de test (potentiellement
        non-zero), et Get-WslActiveSessions prend alors systematiquement la
        branche "echec" (fail open, retourne @()) sans tenir compte de la
        sortie du mock. D'ou le reset a 0 a chaque invocation du mock.
    #>
    param([string[]]$RunningDistros = @())

    $runningDistrosSnapshot = $RunningDistros

    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        function script:wsl { }
    }
    $mockBody = {
        $global:LASTEXITCODE = 0
        if ($args -contains '--list') {
            return $runningDistrosSnapshot
        }
    }.GetNewClosure()
    Mock wsl $mockBody
    Mock Start-Sleep {}
}
