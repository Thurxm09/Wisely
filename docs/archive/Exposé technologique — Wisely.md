> # ARCHIVE — document historique, ne pas suivre
>
> **Ce document est archivé et n'est plus une référence.** Il a été rédigé à
> l'époque de la v2.0 et une partie de son contenu est aujourd'hui livrée,
> périmée, ou factuellement fausse.
>
> Exemples de dérive, pour situer le niveau de confiance à lui accorder :
> il recommande d'implémenter en v2.1 le JSON Schema et la suite Pester
> (livrés depuis), de publier sur Winget « en v2.1 ou v2.2 » (désormais
> repoussé en v4.0, voir `../decisions/0009-distribution-apres-le-produit.md`),
> et il ne connaît ni `autoMemoryReclaim`, ni `sparseVhd`, ni l'application
> WSL Settings de Microsoft — trois éléments qui changent l'analyse.
>
> Il est conservé parce qu'il documente un état de la réflexion technique, et
> que certaines de ses pistes (agent de métriques côté WSL2, parseur robuste)
> ont été reprises sous une autre forme dans `../decisions/`.
>
> **Pour l'état à jour :** `../PROBLEM.md`, `../VISION.md`, `../ROADMAP.md`,
> `../decisions/`.
>
> *Archivé le 2026-08-26.*

---

# Exposé technologique — Wisely
## Technologies, langages et outils pour faire évoluer le projet
 
> **Objectif de ce document :** fournir une carte technologique complète et des recommandations concrètes d'intégration, ancrées dans les axes d'évolution de la roadmap v2.1 → v4.0.
 
---
 
## Table des matières
 
1. [Langages complémentaires à PowerShell](#1-langages-complémentaires-à-powershell)
2. [Frameworks et bibliothèques](#2-frameworks-et-bibliothèques)
3. [Outils DevOps](#3-outils-devops)
4. [Améliorer la sécurité](#4-améliorer-la-sécurité)
5. [Améliorer la robustesse](#5-améliorer-la-robustesse)
6. [Améliorer la performance](#6-améliorer-la-performance)
7. [Améliorer la portabilité](#7-améliorer-la-portabilité)
8. [Recommandations d'intégration priorisées](#8-recommandations-dintégration-priorisées)
9. [Matrice de décision](#9-matrice-de-décision)
---
 
## 1. Langages complémentaires à PowerShell
 
> PowerShell reste le langage principal et ne doit pas être remplacé. Il est parfaitement adapté à l'orchestration Windows, à l'interaction avec le système de fichiers, le registre, et le Task Scheduler. Les langages ci-dessous comblent ses angles morts spécifiques.
 
---
 
### 1.1 C# — Le complément naturel
 
**Pourquoi c'est pertinent pour Wisely**
 
PowerShell est bâti sur .NET. C# est le langage natif de .NET. Quand une opération est difficile ou lente en PowerShell, elle devient triviale en C#. Les deux langages partagent exactement les mêmes bibliothèques — zéro friction d'intégration.
 
**Cas d'usage concrets dans le projet**
 
| Problème actuel | Solution en C# |
|---|---|
| Les APIs Windows Runtime (Toast) nécessitent une syntaxe PowerShell contournée | Une classe C# propre expose `SendToast(string title, string body)` |
| La lecture de `.wslconfig` est faite ligne par ligne avec des regex fragiles | Un parser `IniFile` en C# est robuste et réutilisable |
| L'API REST locale (roadmap v4.0) nécessite `HttpListener` PowerShell — verbose | `ASP.NET Core Minimal API` en C# : 10 lignes pour un endpoint complet |
| La future extension VS Code doit être en TypeScript/Node, mais le backend peut parler C# | Interop propre via stdin/stdout ou named pipes |
 
**Comment intégrer**
 
PowerShell peut compiler et utiliser du C# à la volée via `Add-Type` :
 
```powershell
$csharpCode = @"
using System;
using System.IO;
 
public class WslConfigParser {
    public static string GetValue(string filePath, string key) {
        foreach (var line in File.ReadAllLines(filePath)) {
            if (line.StartsWith(key + "="))
                return line.Substring(key.Length + 1);
        }
        return null;
    }
}
"@
 
Add-Type -TypeDefinition $csharpCode -Language CSharp
$mem = [WslConfigParser]::GetValue("$env:USERPROFILE\.wslconfig", "memory")
```
 
**Niveau d'effort :** moyen. Nécessite de connaître les bases de C#.  
**Recommandation :** À introduire pour les composants à forte complexité logique (parser, API REST, UI native).
 
---
 
### 1.2 Python — Le couteau suisse du data et de l'automation
 
**Pourquoi c'est pertinent pour Wisely**
 
Tu travailles déjà avec Python (FastAPI, Pandas, Conda) côté WSL. Python peut jouer un rôle complémentaire sur deux fronts : les scripts de build/packaging Windows-side, et les composants qui tournent côté Linux (dans WSL2 lui-même).
 
**Cas d'usage concrets dans le projet**
 
| Cas d'usage | Détail |
|---|---|
| **Scripts de build** | Générer les bootstraps de déploiement (tu l'as déjà fait — les `Write-Phase*.py`) |
| **Tests cross-platform** | Pytest peut tester la logique de `profiles.json` indépendamment de PowerShell |
| **Analyse de `history.json`** | Un notebook Jupyter pour visualiser les patterns d'utilisation |
| **Agent côté WSL2** | Un script Python dans WSL2 qui expose des métriques réelles (mémoire effective, processus actifs) via une socket Unix — bien plus précis que `vmmem` |
| **Companion CLI Linux** | Un binaire Python (packagé avec PyInstaller) qui tourne dans WSL2 et dialogue avec le switcher Windows |
 
**L'angle "agent WSL2 côté Linux" mérite d'être détaillé**
 
```python
# Côté WSL2 (Linux) - agent.py
import psutil
import socket
import json
 
def get_wsl_metrics():
    mem = psutil.virtual_memory()
    return {
        "ram_total_gb": round(mem.total / 1e9, 1),
        "ram_used_gb": round(mem.used / 1e9, 1),
        "ram_percent": mem.percent,
        "processes": len(psutil.pids())
    }
 
# Expose via socket Unix → lisible depuis PowerShell Windows
```
 
Côté PowerShell, on lirait ces métriques via `wsl python3 agent.py` — bien plus fiable que le proxy `vmmem`.
 
**Niveau d'effort :** faible (tu maîtrises déjà Python).  
**Recommandation :** Utiliser Python pour les scripts de build et l'agent de métriques WSL2.
 
---
 
### 1.3 Rust — La performance et la robustesse à long terme
 
**Pourquoi c'est pertinent pour Wisely**
 
Rust produit des binaires natifs, sans runtime, très performants et mémoire-safe. C'est le langage de référence pour les outils CLI système modernes (`ripgrep`, `bat`, `fd`, `exa`, `starship`). Tu utilises déjà `starship` — il est écrit en Rust.
 
**Cas d'usage concrets dans le projet**
 
| Cas d'usage | Détail |
|---|---|
| **Binaire CLI cross-platform** | Un exécutable `wisely.exe` qui ne nécessite pas PowerShell du tout |
| **Parser `.wslconfig` robuste** | Rust + la crate `ini` pour un parsing parfait et typé |
| **Monitoring haute fréquence** | Rust peut interroger les APIs Windows de performance toutes les secondes sans overhead |
| **Distribution Winget** | Un `.exe` Rust est plus facile à packager pour Winget qu'un module PowerShell |
 
**Concrètement — à quel horizon ?**
 
Rust est pertinent en **v4.0**, pas avant. Il implique une courbe d'apprentissage significative et un refactoring structurel. Mais si tu vises un outil de référence dans l'écosystème WSL (vision long terme de la roadmap), un binaire natif est la destination naturelle.
 
```toml
# Cargo.toml d'un futur wisely en Rust
[dependencies]
clap = { version = "4", features = ["derive"] }   # CLI parser
serde = { version = "1", features = ["derive"] }   # JSON
serde_json = "1"
ini = "1"                                           # Parser .wslconfig
windows = { version = "0.52", features = [         # APIs Windows natives
    "Win32_System_TaskScheduler",
    "UI_Notifications",
]}
```
 
**Niveau d'effort :** élevé. Nécessite un investissement d'apprentissage sérieux.  
**Recommandation :** À envisager uniquement après stabilisation des features en v3.x.
 
---
 
### 1.4 TypeScript / Node.js — L'écosystème VS Code
 
**Pourquoi c'est pertinent pour Wisely**
 
La roadmap v4.0 mentionne une intégration VS Code. Les extensions VS Code sont obligatoirement en TypeScript/JavaScript. C'est le seul langage valable pour ce cas d'usage précis.
 
**Cas d'usage concrets dans le projet**
 
| Cas d'usage | Détail |
|---|---|
| **Extension VS Code** | Afficher le profil actif dans la status bar, déclencher un switch depuis la palette |
| **Interface web légère** | Un dashboard HTML/JS pour visualiser `history.json` et les rapports |
| **Companion app Electron** | Une GUI native Windows légère (alternative à WinForms C#) |
 
**Exemple — extension VS Code minimaliste**
 
```typescript
// extension.ts
import * as vscode from 'vscode';
import { exec } from 'child_process';
 
export function activate(context: vscode.ExtensionContext) {
    const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left);
    
    // Lire le profil actif en appelant wisely -Version (ou status futur)
    exec('powershell -Command "wisely status"', (err, stdout) => {
        statusBar.text = `$(database) WSL: ${stdout.trim()}`;
        statusBar.show();
    });
 
    context.subscriptions.push(
        vscode.commands.registerCommand('wisely.switch', async () => {
            const profile = await vscode.window.showQuickPick(['web', 'data', 'base']);
            if (profile) exec(`powershell -Command "wisely ${profile}"`);
        })
    );
}
```
 
**Niveau d'effort :** moyen.  
**Recommandation :** À intégrer en v3.x ou v4.0, uniquement si la commande `wisely status` existe (prérequis logique).
 
---
 
### 1.5 YAML / JSON Schema — Les langages de configuration
 
**Pourquoi c'est pertinent pour Wisely**
 
`profiles.json` est la source de vérité du projet. Mais aujourd'hui, rien ne valide sa structure formellement (en dehors du code PowerShell). Un JSON Schema permet de valider `profiles.json` avec des outils standards, d'avoir l'autocomplétion dans VS Code, et de détecter les erreurs avant même d'exécuter l'outil.
 
**Implémentation concrète**
 
```json
// profiles.schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Wisely Configuration",
  "type": "object",
  "required": ["version", "profiles", "settings"],
  "properties": {
    "version": { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "profiles": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["displayName", "memory", "processors"],
        "properties": {
          "memory": { "type": "string", "pattern": "^\\d+GB$" },
          "processors": { "type": "integer", "minimum": 1, "maximum": 64 },
          "swappiness": { "type": "integer", "minimum": 0, "maximum": 100 }
        }
      }
    }
  }
}
```
 
En ajoutant `"$schema": "./profiles.schema.json"` dans `profiles.json`, VS Code valide et autocomplète automatiquement.
 
**Niveau d'effort :** très faible.  
**Recommandation :** À implémenter dès la v2.1 — ROI immédiat, zéro dépendance.
 
---
 
## 2. Frameworks et bibliothèques
 
### 2.1 Pester — Tests unitaires PowerShell
 
**Ce que c'est**
 
Pester est le framework de test officiel de l'écosystème PowerShell. C'est l'équivalent de pytest pour Python ou Jest pour JavaScript. Il est intégré nativement dans Windows et dans VS Code avec une extension dédiée.
 
**Pourquoi c'est critique pour le projet**
 
Aujourd'hui, chaque modification du code est un saut de foi. Sans tests, tu ne sais pas si un changement dans `ProfileManager.ps1` casse quelque chose dans le menu interactif. La roadmap identifie ça comme la dette technique principale.
 
**Exemples de tests prioritaires**
 
```powershell
# tests/ProfileManager.Tests.ps1
 
Describe "Get-ProfileConfig" {
    Context "Fichier valide" {
        BeforeEach {
            # Créer un profiles.json minimal dans un dossier temporaire
            $Global:WSLRoot = $TestDrive
            New-Item "$TestDrive\data" -ItemType Directory -Force | Out-Null
            @{
                version  = "2.0.0"
                profiles = @{ web = @{ memory = "2GB"; processors = 3 } }
                settings = @{}
            } | ConvertTo-Json | Set-Content "$TestDrive\data\profiles.json"
            
            . "$PSScriptRoot\..\modules\ProfileManager.ps1"
        }
        
        It "retourne un objet avec une clé 'profiles'" {
            $result = Get-ProfileConfig
            $result.profiles | Should -Not -BeNullOrEmpty
        }
        
        It "retourne la bonne version" {
            (Get-ProfileConfig).version | Should -Be "2.0.0"
        }
    }
    
    Context "Fichier absent" {
        BeforeEach {
            $Global:WSLRoot = "C:\chemin\qui\nexiste\pas"
            . "$PSScriptRoot\..\modules\ProfileManager.ps1"
        }
        
        It "lève une exception avec un message explicite" {
            { Get-ProfileConfig } | Should -Throw -ExpectedMessage "profiles.json introuvable"
        }
    }
}
 
Describe "Set-WslProfile avec DryRun" {
    It "ne modifie pas .wslconfig en mode DryRun" {
        # Mock wsl --shutdown pour ne pas impacter le système
        Mock -CommandName wsl -MockWith { }
        
        $contentBefore = Get-Content "$env:USERPROFILE\.wslconfig" -Raw
        Set-WslProfile -Key "web" -DryRun
        $contentAfter  = Get-Content "$env:USERPROFILE\.wslconfig" -Raw
        
        $contentAfter | Should -Be $contentBefore
    }
}
```
 
**Fonctionnalités clés de Pester**
 
| Fonctionnalité | Utilité dans Wisely |
|---|---|
| `Mock -CommandName wsl` | Simuler `wsl --shutdown` sans impacter le système |
| `$TestDrive` | Dossier temporaire isolé par test — pas de pollution de l'environnement |
| `Should -Throw` | Vérifier qu'une exception est levée avec le bon message |
| `BeforeEach` / `AfterEach` | Setup/teardown pour chaque test |
| `InModuleScope` | Tester des fonctions internes d'un module |
 
**Intégration CI**
 
```yaml
# Dans ci.yml — ajouter après PSScriptAnalyzer
- name: Run Pester tests
  shell: pwsh
  run: |
    Install-Module Pester -Force -Scope CurrentUser
    $result = Invoke-Pester -Path ./tests -PassThru -OutputFormat NUnitXml -OutputFile test-results.xml
    if ($result.FailedCount -gt 0) { exit 1 }
```
 
**Niveau d'effort :** moyen (apprentissage initial, puis fluide).  
**Recommandation :** Priorité absolue avant d'ajouter de nouvelles features. Commencer par tester `Get-ProfileConfig` et `Import-Profiles`.
 
---
 
### 2.2 PSScriptAnalyzer — Analyse statique
 
**Ce que c'est**
 
Déjà intégré dans ton CI. Mais son potentiel est sous-exploité. PSScriptAnalyzer peut être configuré avec des règles custom pour des conventions spécifiques au projet.
 
**Extensions concrètes**
 
```powershell
# PSScriptAnalyzerSettings.psd1 — fichier de config dédié
@{
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable          = $true
            IndentationSize = 4
            Kind            = 'space'
        }
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing = @{
            Enable = $true
        }
    }
}
```
 
**Niveau d'effort :** très faible.  
**Recommandation :** Ajouter un fichier `PSScriptAnalyzerSettings.psd1` en v2.1.
 
---
 
### 2.3 `platyPS` — Documentation automatique
 
**Ce que c'est**
 
`platyPS` est un module Microsoft officiel qui génère de la documentation Markdown depuis les commentaires `.SYNOPSIS` / `.DESCRIPTION` / `.PARAMETER` déjà présents dans ton code.
 
**Workflow concret**
 
```powershell
# 1. Générer la doc depuis le code
Import-Module platyPS
New-MarkdownHelp -Module Wisely -OutputFolder ./docs/cmdlets
 
# 2. Résultat : un fichier Markdown par fonction
# docs/cmdlets/Set-WslProfile.md
# docs/cmdlets/Get-ProfileConfig.md
# docs/cmdlets/Write-SwitchLog.md
# etc.
```
 
Le code de `Logger.ps1` a déjà les bons commentaires — `platyPS` les transformerait automatiquement en documentation exploitable sur un site GitHub Pages.
 
**Niveau d'effort :** très faible.  
**Recommandation :** À intégrer en v2.2 lors de la phase "DX & Documentation".
 
---
 
### 2.4 `Terminal-Icons` et `Oh My Posh` — Intégration prompt
 
**Ce que c'est**
 
Oh My Posh est le framework de customisation de prompt que tu utilises probablement avec Starship. Il supporte des segments custom en PowerShell qui peuvent afficher n'importe quelle information.
 
**Segment Oh My Posh pour Wisely**
 
```json
// Dans le thème Oh My Posh de l'utilisateur
{
  "type": "command",
  "style": "powerline",
  "foreground": "#00ff00",
  "background": "#333333",
  "properties": {
    "command": "wisely status --short 2>$null",
    "shell": "powershell"
  }
}
```
 
Résultat dans le prompt : `[WSL:WEB 2GB]` — visible en permanence, aucune commande à taper.
 
**Niveau d'effort :** très faible (snippet à documenter, pas de code à écrire).  
**Recommandation :** À documenter en v2.2. Prérequis : la commande `wisely status` doit exister.
 
---
 
### 2.5 `Spectre.Console` — UI terminal avancée (via C#)
 
**Ce que c'est**
 
Spectre.Console est une bibliothèque .NET qui permet de créer des interfaces terminal riches : tableaux colorés, barres de progression animées, spinners, prompts interactifs, arbres hiérarchiques. Elle est utilisée par des outils comme `dotnet publish`.
 
**Cas d'usage dans Wisely**
 
```csharp
// Exemple conceptuel — menu avec Spectre.Console
var profile = AnsiConsole.Prompt(
    new SelectionPrompt<string>()
        .Title("[cyan]Sélectionner un profil WSL2[/]")
        .AddChoices(new[] { "⚡ WEB (2GB)", "🔬 DATA SCIENCE (6GB)", "💤 BASE (1GB)" })
);
 
AnsiConsole.Progress()
    .Start(ctx => {
        var task = ctx.AddTask("Arrêt de WSL2...");
        // wsl --shutdown
        task.Value = 100;
    });
```
 
C'est une alternative au rendu Unicode manuel actuel de `wisely.ps1` — avec animations, couleurs ANSI complètes, et support de toutes les tailles de terminal.
 
**Niveau d'effort :** élevé (nécessite de migrer le rendu vers C#).  
**Recommandation :** À considérer uniquement si une réécriture partielle est envisagée en v3.x ou v4.0.
 
---
 
## 3. Outils DevOps
 
### 3.1 Tests et qualité
 
#### Codecov — Couverture de code
 
**Ce que c'est**  
Codecov collecte les rapports de couverture de tests et les affiche sur le dépôt GitHub avec un badge et des visualisations.
 
**Intégration CI**
 
```yaml
# ci.yml — après les tests Pester
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    files: ./coverage.xml
    token: ${{ secrets.CODECOV_TOKEN }}
```
 
Badge dans le README : `![Coverage](https://codecov.io/gh/Thurxm09/Wisely/badge.svg)`
 
**Niveau d'effort :** très faible (15 minutes de configuration).  
**Recommandation :** À ajouter dès que les tests Pester sont en place.
 
---
 
#### Stale Bot — Gestion automatique des issues
 
**Ce que c'est**  
Une GitHub Action qui marque automatiquement les issues sans activité comme "stale" après N jours, puis les ferme si toujours inactives.
 
```yaml
# .github/workflows/stale.yml
name: Mark stale issues
on:
  schedule:
    - cron: '0 0 * * *'
jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: 'Cette issue est inactive depuis 30 jours.'
          days-before-stale: 30
          days-before-close: 7
```
 
**Niveau d'effort :** très faible.  
**Recommandation :** À activer quand le projet commence à recevoir des contributions externes.
 
---
 
### 3.2 Packaging et distribution
 
#### PowerShell Gallery — Distribution comme module
 
**Ce que c'est**  
La plateforme officielle Microsoft de distribution de modules PowerShell. `Install-Module Wisely -Scope CurrentUser` à la place du clone Git manuel.
 
**Structure du module**
 
```
Wisely/
├── Wisely.psd1        ← Manifest (métadonnées, version, exports)
├── Wisely.psm1        ← Point d'entrée du module
├── Public/               ← Fonctions exportées (accessibles à l'utilisateur)
│   ├── Invoke-WslSwitch.ps1
│   ├── Get-WslProfile.ps1
│   └── Set-WslProfile.ps1
├── Private/              ← Fonctions internes (modules actuels renommés)
│   ├── ProfileManager.ps1
│   ├── Logger.ps1
│   ├── Monitor.ps1
│   └── WeeklyReport.ps1
└── data/
    └── profiles.json
```
 
**Le manifest `.psd1`**
 
```powershell
# Wisely.psd1
@{
    ModuleVersion   = '3.0.0'
    GUID            = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author          = 'Thuram'
    Description     = 'WSL2 resource profile switcher with monitoring and reporting'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Invoke-WslSwitch', 'Get-WslProfile', 'Set-WslProfile')
    PrivateData     = @{
        PSData = @{
            Tags       = @('WSL', 'WSL2', 'Windows', 'DevOps', 'RAM', 'Memory')
            ProjectUri = 'https://github.com/Thurxm09/Wisely'
            LicenseUri = 'https://github.com/Thurxm09/Wisely/blob/main/LICENSE'
        }
    }
}
```
 
**Publication automatique via GitHub Actions**
 
```yaml
# release.yml — ajouter cette étape après la création de la release
- name: Publish to PowerShell Gallery
  shell: pwsh
  run: |
    Publish-Module -Path ./Wisely -NuGetApiKey ${{ secrets.PSGALLERY_API_KEY }}
```
 
**Niveau d'effort :** moyen (refactoring de structure nécessaire).  
**Recommandation :** Objectif v3.0. La structure actuelle est déjà quasi-compatible.
 
---
 
#### Winget — Distribution Windows native
 
**Ce que c'est**  
Le gestionnaire de paquets natif de Windows 11/10. `winget install Thuram.Wisely` — sans aucun Git, aucune PowerShell Gallery.
 
**Le manifest Winget**
 
```yaml
# manifests/t/Thuram/Wisely/2.0.0/Thuram.Wisely.yaml
PackageIdentifier: Thuram.Wisely
PackageVersion: "2.0.0"
PackageName: Wisely
Publisher: Thuram
License: GPL-3.0
InstallerType: zip
Installers:
  - Architecture: x64
    InstallerUrl: https://github.com/Thurxm09/Wisely/releases/download/v2.0.0/wisely-v2.0.0.zip
    InstallerSha256: <hash>
```
 
La soumission se fait via une Pull Request sur le dépôt `microsoft/winget-pkgs`.
 
**Niveau d'effort :** faible (fichier YAML à soumettre).  
**Recommandation :** À faire en v2.1 ou v2.2 — l'impact de visibilité est immédiat.
 
---
 
#### Chocolatey — Distribution Windows communautaire
 
**Ce que c'est**  
Alternative à Winget, plus ancienne et avec une communauté plus large pour les outils dev. `choco install wisely`.
 
**Niveau d'effort :** faible (similaire à Winget).  
**Recommandation :** Optionnel, à envisager après Winget si l'adoption le justifie.
 
---
 
### 3.3 Observabilité et monitoring CI
 
#### GitHub Actions — Améliorer le pipeline existant
 
**Ce que le pipeline actuel fait déjà bien**
- Validation syntaxe PowerShell
- PSScriptAnalyzer `-Severity Warning`
- Validation `profiles.json`
- Release automatique avec ZIP
**Ce qui manque**
 
```yaml
# Ajouts recommandés dans ci.yml
 
# 1. Tests Pester (priorité max)
- name: Run Pester tests
  shell: pwsh
  run: Invoke-Pester -Path ./tests -PassThru | Export-Clixml ./test-results.xml
 
# 2. Vérification de la signature des scripts (pour les envs enterprise)
- name: Check script encoding (ASCII compliance)
  run: |
    find . -name "*.ps1" -not -name "MonitorTask.ps1" | while read f; do
      if grep -P "[\x80-\xFF]" "$f"; then
        echo "::error file=$f::Non-ASCII characters found"
        exit 1
      fi
    done
 
# 3. Vérifier que VERSION et CHANGELOG sont cohérents
- name: Validate version consistency
  run: |
    VERSION=$(cat VERSION)
    if ! grep -q "## v$VERSION" CHANGELOG.md; then
      echo "::error::VERSION ($VERSION) has no matching entry in CHANGELOG.md"
      exit 1
    fi
```
 
**Niveau d'effort :** faible.  
**Recommandation :** Ajouter les 3 étapes ci-dessus en v2.1.
 
---
 
#### Dependabot — Mise à jour automatique des dépendances
 
**Ce que c'est**  
Un bot GitHub qui ouvre automatiquement des PRs quand des versions des GitHub Actions utilisées dans les workflows sont mises à jour.
 
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```
 
**Niveau d'effort :** trivial (un fichier YAML de 8 lignes).  
**Recommandation :** À ajouter immédiatement — `checkout@v4`, `codeql-action/init@v4`, etc. restent ainsi toujours à jour.
 
---
 
## 4. Améliorer la sécurité
 
### 4.1 Signature des scripts PowerShell
 
**Le problème actuel**
 
Dans les environnements d'entreprise avec la politique `AllSigned`, tout script non signé est refusé. Wisely est aujourd'hui inutilisable dans ce contexte.
 
**La solution : certificat de code auto-signé**
 
```powershell
# Générer un certificat auto-signé (une fois)
$cert = New-SelfSignedCertificate `
    -Subject "CN=Wisely Code Signing" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsage DigitalSignature `
    -Type CodeSigningCert
 
# Signer tous les scripts
Get-ChildItem -Recurse -Filter "*.ps1" | ForEach-Object {
    Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $cert
}
```
 
**Intégration CI avec un certificat d'organisation**
 
Pour un projet open-source sérieux, une variante plus robuste utilise un certificat via GitHub Secrets :
 
```yaml
# release.yml
- name: Sign PowerShell scripts
  shell: pwsh
  run: |
    $certBytes = [Convert]::FromBase64String("${{ secrets.CODE_SIGNING_CERT }}")
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes, "${{ secrets.CERT_PASSWORD }}")
    Get-ChildItem -Recurse -Filter "*.ps1" | ForEach-Object {
        Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $cert
    }
```
 
**Niveau d'effort :** moyen.  
**Recommandation :** Implémenter en v2.x avec un certificat auto-signé + documentation d'installation.
 
---
 
### 4.2 Validation renforcée des entrées utilisateur
 
**Ce qui existe déjà :** validation de la clé de profil via regex dans `wisely.ps1`, validation du schéma JSON dans `Import-Profiles`.
 
**Ce qui manque**
 
```powershell
# 1. Valider que swapFile pointe vers un répertoire existant
function Test-SwapFilePath {
    param([string]$SwapFilePath)
    $dir = Split-Path $SwapFilePath -Parent
    # Normaliser les slashes forward → backslash pour Test-Path Windows
    $dirNormalized = $dir -replace '/', '\'
    if (-not (Test-Path $dirNormalized)) {
        throw "Le répertoire du swapFile n'existe pas : $dirNormalized. Créez-le ou modifiez 'swapFile' dans profiles.json."
    }
}
 
# 2. Sanitiser le chemin swapFile contre les injections
function Test-SafeSwapFilePath {
    param([string]$Path)
    # Rejeter tout chemin contenant des caractères dangereux pour .wslconfig
    if ($Path -match '[;`"<>|&]') {
        throw "Le chemin swapFile contient des caractères non autorisés."
    }
}
```
 
**Niveau d'effort :** très faible.  
**Recommandation :** À intégrer dans `Get-ProfileConfig` et `Set-WslProfile` en v2.1.
 
---
 
### 4.3 Secrets et données sensibles
 
**Risque actuel :** les scripts de déploiement (`Write-Phase*.ps1`) sont dans le `.gitignore` mais pourraient contenir des chemins spécifiques à la machine. `history.json` enregistre le `$env:USERNAME`.
 
**Bonnes pratiques à implémenter**
 
```powershell
# Anonymiser le username dans les rapports publics
$reportEntry = @{
    timestamp = $entry.timestamp
    action    = $entry.action
    profile   = $entry.profile
    # Ne pas inclure $entry.user dans les exports/rapports partagés
}
```
 
**`git-secrets`** — un outil qui empêche le commit accidentel de secrets (API keys, passwords, chemins sensibles) dans Git. S'intègre en pre-commit hook.
 
```bash
# Installation (dans WSL2)
git secrets --install
git secrets --register-aws  # Patterns de détection AWS par défaut
# Ajouter des patterns custom
git secrets --add 'USERPROFILE'
git secrets --add 'othur'  # Ton nom d'utilisateur
```
 
**Niveau d'effort :** faible.  
**Recommandation :** `git-secrets` en v2.1, anonymisation des rapports en v2.2.
 
---
 
### 4.4 Audit et traçabilité
 
**Ce qui existe :** `history.json` avec timestamp, action, profil, username.
 
**Ce qui manque :** intégrité des logs. Un utilisateur pourrait modifier `history.json` manuellement sans que ça soit détectable.
 
**Solution légère :** checksum des entrées de log.
 
```powershell
function Write-SwitchLog {
    # ... code existant ...
    
    # Ajouter un hash de l'entrée pour détecter les modifications
    $entryJson = $entry | ConvertTo-Json -Compress
    $hash = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($entryJson)
    $entry | Add-Member -MemberType NoteProperty -Name "_hash" -Value (
        [BitConverter]::ToString($hash.ComputeHash($bytes)) -replace '-', ''
    )
}
```
 
**Niveau d'effort :** faible.  
**Recommandation :** À considérer si le projet évolue vers des environnements d'entreprise (v3.x).
 
---
 
## 5. Améliorer la robustesse
 
### 5.1 Backup versionné
 
**Le problème actuel**
 
Il n'existe qu'un seul backup de `.wslconfig`. Trois switchs en cascade → impossible de revenir à l'état d'il y a deux switchs.
 
**Solution**
 
```powershell
function Backup-WslConfig {
    param([int]$MaxBackups = 5)
    $src = Get-WslConfigPath
    if (-not (Test-Path $src)) { return }
    
    $backupDir  = Join-Path $Global:WSLRoot "data\backups"
    $backupFile = Join-Path $backupDir ("wslconfig_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".bak")
    
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory $backupDir | Out-Null }
    
    Copy-Item $src $backupFile -Force
    
    # Rotation : garder seulement les $MaxBackups derniers
    $allBackups = Get-ChildItem $backupDir -Filter "wslconfig_*.bak" | Sort-Object Name
    if ($allBackups.Count -gt $MaxBackups) {
        $allBackups | Select-Object -First ($allBackups.Count - $MaxBackups) | Remove-Item -Force
    }
}
```
 
La commande `-Rollback` liste ensuite les backups disponibles et laisse choisir.
 
**Niveau d'effort :** faible.  
**Recommandation :** À implémenter en v2.1.
 
---
 
### 5.2 Détection de WSL2 actif avant shutdown
 
**Le problème actuel**
 
`wsl --shutdown` est appelé sans vérifier si des processus critiques tournent dans WSL2 (serveur de dev, compilation en cours, notebook Jupyter). Une fermeture brutale peut corrompre des fichiers ou perdre du travail.
 
**Solution**
 
```powershell
function Get-WslActiveSessions {
    # Lister les distributions WSL2 en cours d'exécution
    $wslList = wsl --list --running --quiet 2>$null
    return @($wslList | Where-Object { $_ -ne "" })
}
 
function Confirm-WslShutdown {
    $sessions = Get-WslActiveSessions
    if ($sessions.Count -eq 0) { return $true }  # Rien ne tourne → OK
    
    Write-Host ""
    Write-Host "  ATTENTION : Les distributions suivantes sont actives :" -ForegroundColor Yellow
    $sessions | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
    Write-Host "  Un arrêt forcé peut interrompre des processus en cours." -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "  Continuer ? (o/n)"
    return $confirm -eq "o"
}
```
 
**Niveau d'effort :** faible.  
**Recommandation :** À intégrer dans `Set-WslProfile` en v2.1. Option `-Force` pour bypasser la confirmation dans les scripts automatisés.
 
---
 
### 5.3 Migration automatique du schéma `profiles.json`
 
**Le problème actuel**
 
Si le schéma de `profiles.json` évolue entre deux versions majeures (ajout d'une clé obligatoire, renommage), les utilisateurs qui mettent à jour sans lire le CHANGELOG auront un outil cassé.
 
**Solution**
 
```powershell
function Invoke-SchemaMigration {
    param([PSCustomObject]$Config)
    
    $currentSchemaVersion = "2.0.0"
    $fileVersion = $Config.version
    
    if ($fileVersion -eq $currentSchemaVersion) { return $Config }
    
    # Migration 1.x → 2.0
    if ($fileVersion -match "^1\.") {
        Write-Host "  Migration du schéma 1.x → 2.0..." -ForegroundColor Yellow
        
        # Ajouter la section settings si absente
        if ($null -eq $Config.settings) {
            $Config | Add-Member -MemberType NoteProperty -Name "settings" -Value @{
                monitorThreshold       = 80
                monitorIntervalSeconds = 30
                historyMaxEntries      = 100
                backupEnabled          = $true
            }
        }
        # Ajouter swappiness à chaque profil si absent
        $Config.profiles.PSObject.Properties | ForEach-Object {
            if ($null -eq $_.Value.swappiness) {
                $_.Value | Add-Member -MemberType NoteProperty -Name "swappiness" -Value 10
            }
        }
        $Config.version = $currentSchemaVersion
        $Config | ConvertTo-Json -Depth 10 | Set-Content (Get-ProfilesPath) -Encoding UTF8
        Write-Host "  Migration réussie." -ForegroundColor Green
    }
    
    return $Config
}
```
 
Appeler `Invoke-SchemaMigration` au début de `Get-ProfileConfig`.
 
**Niveau d'effort :** moyen.  
**Recommandation :** Implémenter en v3.0 avant la publication sur PowerShell Gallery.
 
---
 
## 6. Améliorer la performance
 
### 6.1 Éliminer les lectures disque redondantes
 
**État actuel**
 
`Get-ProfileConfig` lit `profiles.json` à chaque appel. Dans le flux `Set-WslProfile`, il est appelé une fois. C'est déjà optimisé. La lecture disque à chaque frame du menu a déjà été corrigée (S-1 de l'audit).
 
**Ce qui reste à optimiser : le démarrage**
 
Au lancement du script, les 3 modules sont dot-sourcés séquentiellement. Si le projet grossit avec plus de modules, ce temps peut augmenter. Solution : lazy loading — ne charger un module que quand il est nécessaire.
 
```powershell
# Chargement conditionnel — ne charger Monitor.ps1 que si -Monitor est utilisé
if ($Monitor -ne "") {
    . (Join-Path $PSScriptRoot "modules\Monitor.ps1")
    # ... traitement Monitor ...
    exit
}
```
 
**Niveau d'effort :** faible.  
**Recommandation :** À implémenter quand le nombre de modules dépasse 5-6.
 
---
 
### 6.2 Cache en mémoire pour `Get-ProfileConfig`
 
**Le problème :** si une feature future appelle `Get-ProfileConfig` plusieurs fois dans une même exécution, le fichier est relu à chaque fois.
 
**Solution : memoïsation simple**
 
```powershell
# En haut de ProfileManager.ps1
$script:ProfileConfigCache = $null
 
function Get-ProfileConfig {
    if ($null -ne $script:ProfileConfigCache) {
        return $script:ProfileConfigCache
    }
    # ... code existant de lecture et validation ...
    $script:ProfileConfigCache = $parsed
    return $parsed
}
 
function Clear-ProfileConfigCache {
    $script:ProfileConfigCache = $null
}
```
 
`Clear-ProfileConfigCache` est appelé après chaque `Set-WslProfile` ou `Import-Profiles` pour invalider le cache.
 
**Niveau d'effort :** très faible.  
**Recommandation :** À intégrer en v2.1.
 
---
 
### 6.3 Mesure du temps de switch
 
**Le problème :** on ne sait pas combien de temps prend réellement un switch. Sur ta machine (HP EliteOne i5-9600), `wsl --shutdown` peut prendre entre 3 et 15 secondes selon la charge.
 
**Solution**
 
```powershell
function Set-WslProfile {
    # ...
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    wsl --shutdown
    Start-Sleep -Seconds 2
    Set-Content -Path (Get-WslConfigPath) -Value $content -Encoding UTF8
    
    $stopwatch.Stop()
    $elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
    
    Write-Host "  OK - $($profileDef.displayName) actif en ${elapsed}s" -ForegroundColor Green
    Write-SwitchLog -Action "SWITCH" -Details "$($profileDef.memory), ${elapsed}s"
}
```
 
Ce chrono est aussi précieux pour le rapport hebdomadaire : "temps moyen de switch cette semaine : 4.2s".
 
**Niveau d'effort :** trivial.  
**Recommandation :** À implémenter immédiatement — 5 lignes de code, impact UX immédiat.
 
---
 
## 7. Améliorer la portabilité
 
### 7.1 Variables d'environnement dans `profiles.json`
 
**Le problème actuel**
 
```json
"swapFile": "C:/Temp/wsl-swap.vhdx"
```
 
Ce chemin est hardcodé. Sur une autre machine où `C:/Temp/` n'existe pas, ou pour un utilisateur qui préfère `D:/WSL/`, il faut modifier `profiles.json` manuellement — cassant la portabilité des profils partagés.
 
**Solution**
 
```powershell
function Resolve-ProfilePaths {
    param([PSCustomObject]$ProfileDef)
    
    # Résoudre les variables d'environnement dans swapFile
    $swapFile = $ProfileDef.swapFile
    $swapFile = $swapFile -replace '%USERPROFILE%', $env:USERPROFILE
    $swapFile = $swapFile -replace '%TEMP%', $env:TEMP
    $swapFile = $swapFile -replace '%LOCALAPPDATA%', $env:LOCALAPPDATA
    $swapFile = [System.Environment]::ExpandEnvironmentVariables($swapFile)
    
    $resolved = $ProfileDef | ConvertTo-Json | ConvertFrom-Json  # Deep copy
    $resolved.swapFile = $swapFile -replace '\\', '/'  # Normaliser en forward slashes
    return $resolved
}
```
 
Appeler `Resolve-ProfilePaths` dans `ConvertTo-WslConfigContent` avant de générer le fichier.
 
Dans `profiles.json`, l'utilisateur peut alors écrire :
 
```json
"swapFile": "%TEMP%/wsl-swap.vhdx"
```
 
**Niveau d'effort :** faible.  
**Recommandation :** À implémenter en v2.1 — valeur immédiate pour tous les utilisateurs qui partagent des profils.
 
---
 
### 7.2 PowerShell 7+ — Compatibilité étendue
 
**Le projet cible actuellement PowerShell 5.1** (inclus dans Windows). PowerShell 7+ apporte des avantages significatifs :
 
| Fonctionnalité PS7+ | Utilité dans Wisely |
|---|---|
| `?? =` (null-coalescing assignment) | Remplace les `if ($null -eq ...) { ... = default }` |
| `ForEach-Object -Parallel` | Traitement parallèle pour futures features multi-WSL |
| Meilleur support des erreurs | `$Error` plus structuré, try/catch plus prévisible |
| Cross-platform | Le code fonctionne sur macOS/Linux (pertinent pour les tests CI) |
| `ConvertTo-Json` avec meilleur encodage | Moins de problèmes d'accents dans les rapports |
 
**Stratégie de compatibilité**
 
```powershell
# Détecter la version et adapter
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # Syntaxe moderne PS7
    $threshold ??= 80
} else {
    # Fallback PS5.1
    if ($null -eq $threshold) { $threshold = 80 }
}
```
 
**`#Requires -Version 7.0`** dans `wisely.ps1` forcerait PS7 — à ne faire que si les gains sont significatifs et si l'impact utilisateur est communiqué clairement.
 
**Niveau d'effort :** faible à moyen (audit du code pour compatibilité).  
**Recommandation :** Tester sur PS7 en v2.x, documenter la compatibilité. Migrer en PS7 uniquement en v3.x si l'adoption le justifie.
 
---
 
### 7.3 Support multi-machines via profils distants
 
**Le problème :** les profils sont stockés localement dans `data/profiles.json`. Sur deux machines différentes, tu dois maintenir deux fichiers séparément.
 
**Solution légère : URL source dans les profils**
 
```json
{
  "settings": {
    "profilesSource": "https://raw.githubusercontent.com/Thurxm09/Wisely/main/community-profiles/ml-stack.json"
  }
}
```
 
```powershell
function Sync-RemoteProfiles {
    $source = (Get-ProfileConfig).settings.profilesSource
    if ($null -eq $source) { return }
    
    try {
        $remote = Invoke-RestMethod -Uri $source -TimeoutSec 5
        # Merger les profils distants avec les profils locaux
        # (profils locaux ont la priorité en cas de conflit)
    } catch {
        Write-Host "  Sync profils distants échouée (mode hors-ligne)." -ForegroundColor DarkGray
    }
}
```
 
**Niveau d'effort :** moyen.  
**Recommandation :** À envisager en v3.x avec la bibliothèque de profils communautaires.
 
---
 
## 8. Recommandations d'intégration priorisées
 
### Horizon court terme (v2.1 — 1 mois)
 
Ces éléments sont **indépendants les uns des autres**, à faible risque, et ont un ROI immédiat.
 
| # | Quoi | Pourquoi | Effort |
|---|---|---|---|
| 1 | **Pester — premiers tests** | Filet de sécurité avant toute évolution | Moyen |
| 2 | **Chronométrage du switch** | UX immédiate, `[Stopwatch]` = 5 lignes | Trivial |
| 3 | **Backup versionné (5 backups)** | Rollback sur N générations | Faible |
| 4 | **Validation du chemin `swapFile`** | Correction bug silencieux fréquent | Très faible |
| 5 | **Variables d'env dans `profiles.json`** | Portabilité inter-machines | Faible |
| 6 | **JSON Schema pour `profiles.json`** | Autocomplétion VS Code + validation | Très faible |
| 7 | **Dependabot pour les Actions** | Sécurité des dépendances CI | Trivial |
| 8 | **Cache `Get-ProfileConfig`** | Préparation pour features futures | Très faible |
| 9 | **Détection WSL2 actif avant shutdown** | Prévention perte de travail | Faible |
| 10 | **Vérification cohérence VERSION/CHANGELOG** | Qualité des releases | Très faible |
 
### Horizon moyen terme (v2.2–v3.0 — 1 à 6 mois)
 
| # | Quoi | Pourquoi | Effort |
|---|---|---|---|
| 1 | **Suite Pester complète** | Prérequis pour contributions externes | Moyen |
| 2 | **platyPS — documentation auto** | Documentation API sans effort | Très faible |
| 3 | **Signature des scripts** | Accès aux environnements enterprise | Moyen |
| 4 | **Publication Winget** | Visibilité et adoption | Faible |
| 5 | **Publication PowerShell Gallery** | Distribution standard PS | Moyen |
| 6 | **Migration schéma `profiles.json`** | Pérennité des upgrades | Moyen |
| 7 | **Commande `wisely status`** | Prérequis Oh My Posh + VS Code | Faible |
| 8 | **Snippet Oh My Posh** | Vecteur de découverte organique | Très faible |
| 9 | **Codecov** | Signal de confiance pour contributeurs | Très faible |
 
### Horizon long terme (v4.0 — 6 à 24 mois)
 
| # | Quoi | Pourquoi | Effort |
|---|---|---|---|
| 1 | **Agent Python côté WSL2** | Métriques réelles vs proxy `vmmem` | Moyen |
| 2 | **C# pour le parser `.wslconfig`** | Robustesse face aux évolutions MS | Élevé |
| 3 | **Extension VS Code (TypeScript)** | Intégration écosystème dev | Élevé |
| 4 | **API REST locale** | Interopérabilité avec d'autres outils | Élevé |
| 5 | **Réécriture Rust** | Performance, distribution native, Winget facilité | Très élevé |
 
---
 
## 9. Matrice de décision
 
```
                    IMPACT
                    Faible          Moyen           Fort
                 ┌──────────────┬──────────────┬──────────────┐
          Trivial │ Dependabot   │ Chrono switch│ JSON Schema  │
                  │ Stale Bot    │              │ Oh My Posh   │
         ─────────┼──────────────┼──────────────┼──────────────┤
  EFFORT   Faible │ Cache config │ Winget       │ Pester init  │
                  │              │ swapFile val.│ Backup versionné │
         ─────────┼──────────────┼──────────────┼──────────────┤
           Moyen  │ PS7 compat.  │ Migration    │ Pester complet│
                  │              │ schéma       │ Signature     │
                  │              │              │ PSGallery     │
         ─────────┼──────────────┼──────────────┼──────────────┤
           Élevé  │              │ C# parser    │ Extension VS Code│
                  │              │ API REST     │ Agent Python  │
         ─────────┼──────────────┼──────────────┼──────────────┤
     Très élevé   │              │              │ Rust rewrite  │
                  └──────────────┴──────────────┴──────────────┘
 
LÉGENDE : Commencer en haut à droite (fort impact, effort trivial/faible)
          Progresser vers le bas au fur et à mesure de la maturité du projet
```
 
---
 
## Résumé exécutif
 
**Ce qu'il faut faire maintenant (avant la prochaine feature)**
 
1. Pester — les tests sont le prérequis à tout le reste
2. Chrono de switch — 5 lignes, impact UX immédiat
3. JSON Schema — autocomplétion VS Code gratuite
**Ce qu'il faut planifier pour la v3.0**
 
- PowerShell Gallery (distribution)
- Migration automatique du schéma (pérennité)
- Suite de tests complète (ouverture aux contributions)
**Ce qu'il ne faut pas faire trop tôt**
 
- Rust (courbe d'apprentissage vs ROI incertain à ce stade)
- Extension VS Code (dépend de `wisely status` qui n'existe pas encore)
- API REST locale (dépend d'une adoption suffisante pour justifier la complexité)
**Le principe directeur :** chaque couche technologique ajoutée doit résoudre un problème réel et documenté dans la roadmap, pas être ajoutée pour sa valeur intrinsèque.
 
---
 
*Document rédigé en référence à la roadmap v1.0 et à l'audit qualité v2.0.0*  
*Prochaine révision recommandée : après publication de la v3.0*