# WSL Switcher — État des lieux & Guide d'intégration TUI Studio
## Document d'architecture et de stratégie — v1.0
 
> Analyse réalisée sur la base des sources v2.0.0 : `wsl-switch.ps1`, modules, `AUDIT.md`, `ROADMAP.md`, `wsl-switcher-expose-technologies.md`, workflows CI/CD, `profiles.json`, `README.md`, `CHANGELOG.md`.
 
---
 
## Table des matières
 
1. [État des lieux complet du projet](#1-état-des-lieux-complet-du-projet)
2. [Évaluation du niveau d'avancement](#2-évaluation-du-niveau-davancement)
3. [Guide d'intégration TUI Studio](#3-guide-dintégration-tui-studio)
4. [Roadmap d'intégration](#4-roadmap-dintégration)
5. [Recommandations professionnelles finales](#5-recommandations-professionnelles-finales)
---
 
## 1. État des lieux complet du projet
 
### 1.1 Objectif global
 
WSL Switcher est un outil PowerShell permettant de gérer dynamiquement les ressources allouées à WSL2 (RAM, CPU, swap) via un système de profils JSON, un menu interactif, un monitoring passif en arrière-plan et un reporting hebdomadaire automatisé. Il répond à un problème réel et sous-adressé dans l'écosystème Windows/WSL2 : l'absence d'outil natif de gestion contextuelle des ressources.
 
### 1.2 Architecture actuelle
 
```
wsl-switch.ps1                  ← Point d'entrée unique (orchestrateur)
modules/
  ProfileManager.ps1            ← CRUD profils, backup, rollback, import/export
  Logger.ps1                    ← Historique JSON, affichage console
  Monitor.ps1                   ← Contrôle Task Scheduler (start/stop/status)
  MonitorTask.ps1               ← Script exécuté par la tâche planifiée
  WeeklyReport.ps1              ← Génération des rapports hebdomadaires
data/
  profiles.json                 ← Source de vérité (profils + settings)
  history.json                  ← Généré à runtime (non versionné)
  reports/                      ← Rapports hebdomadaires (non versionnés)
.github/workflows/
  ci.yml                        ← Lint + PSScriptAnalyzer + validation JSON
  release.yml                   ← ZIP + GitHub Release
  bump-version.yml              ← Bump VERSION + CHANGELOG + tag
  codeql.yml                    ← Analyse sécurité automatique
```
 
**Principe architectural clé :** couplage zéro entre modules. Le script principal est le seul orchestrateur. Les modules ne se connaissent pas entre eux.
 
### 1.3 Fonctionnalités existantes
 
| Fonctionnalité | Module | Statut |
|---|---|---|
| Menu interactif (flèches + Entrée) | `wsl-switch.ps1` | ✅ Stable |
| Switch direct via CLI (`wsl-switch web`) | `wsl-switch.ps1` | ✅ Stable |
| Mode DryRun | `ProfileManager.ps1` | ✅ Stable |
| Backup automatique avant switch | `ProfileManager.ps1` | ✅ Stable (1 seul backup) |
| Rollback instantané | `ProfileManager.ps1` | ✅ Stable |
| Validation post-écriture `.wslconfig` | `ProfileManager.ps1` | ✅ Stable |
| Historique JSON des opérations | `Logger.ps1` | ✅ Stable |
| Affichage historique console | `Logger.ps1` | ✅ Stable |
| Monitoring RAM via Task Scheduler | `Monitor.ps1` + `MonitorTask.ps1` | ✅ Stable |
| Alertes Toast Windows natives | `MonitorTask.ps1` | ✅ Stable |
| Rapport hebdomadaire auto (lundi 09h) | `Monitor.ps1` + `WeeklyReport.ps1` | ✅ Stable |
| Création de profils personnalisés | `ProfileManager.ps1` | ✅ Stable |
| Import/Export profils JSON | `ProfileManager.ps1` | ✅ Stable |
| Validation schéma à l'import | `ProfileManager.ps1` | ✅ Stable |
| Nettoyage `-Clean` | `wsl-switch.ps1` | ✅ Stable |
| CI/CD complet (lint, release, bump) | `.github/workflows/` | ✅ Stable |
| Alias global PowerShell | `README.md` (manuel) | ⚠️ Manuel |
| `wsl-switch -Status` | — | ❌ Absent |
| Chronométrage du switch | — | ❌ Absent |
| Backup versionné (N backups) | — | ❌ Absent |
| Validation chemin `swapFile` | — | ❌ Absent |
| Flags `-Verbose` / `-Quiet` | — | ❌ Absent |
| Cache mémoire `Get-ProfileConfig` | — | ❌ Absent |
| Tests Pester | — | ❌ Absent |
 
### 1.4 Qualité générale du code
 
#### Forces techniques
 
**Architecture**
- Point d'entrée unique avec couplage zéro entre modules — décision de conception solide et rare pour un projet PS solo.
- Source de vérité JSON externe : aucun profil hardcodé dans le code. L'ajout d'un profil ne nécessite aucune modification de code.
- Gestion Unicode propre via `[char]0xXXXX` : fichiers sources ASCII purs, rendu terminal correct. Solution non évidente, bien exécutée.
- Rollback défensif : backup automatique + validation post-écriture + rollback automatique si `.wslconfig` invalide.
**Robustesse**
- Pattern `throw` dans les modules / `try-catch + exit 1` dans le script principal : cohérent et correct pour PowerShell.
- Validation de schéma JSON à l'import : 3 garde-fous (clé `profiles`, clé `version`, count > 0).
- Check admin pour `Start-WslMonitor` et `Stop-WslMonitor`.
- Lecture disque découplée de la boucle de menu (S-1 de l'audit corrigé).
**CI/CD**
- PSScriptAnalyzer à `-Severity Warning` avec exclusions commentées et justifiées — signal de maturité rare.
- CodeQL configuré.
- `bump-version.yml` avec bump sémantique automatisé + tag + CHANGELOG.
- `release.yml` avec ZIP automatique.
**Documentation**
- `AUDIT.md` exhaustif avec findings prioritisés, corrections documentées, récapitulatif tabulaire.
- `ROADMAP.md` stratégique sur 3 horizons temporels avec principes directeurs.
- `SECURITY.md` avec politique de divulgation responsable.
- `CHANGELOG.md` structuré par version.
- `README.md` complet avec référence des commandes, architecture, configuration avancée.
#### Faiblesses techniques
 
**Dette technique prioritaire**
1. **Absence totale de tests** — Le projet n'a aucune couverture Pester. Chaque modification est un saut de foi. C'est la dette technique principale identifiée dans le ROADMAP.md et l'exposé technologique.
2. **Installation manuelle** — Clone Git + modification manuelle du `$PROFILE`. Pas de package manager, pas d'installateur.
3. **Alias non disponible en PS7** — Problème identifié et documenté, non résolu. PS7 (Microsoft Store) utilise un `$PROFILE` distinct de PS5.1.
**Findings ouverts (AUDIT.md)**
- N-1 : Badge LICENSE README affiché MIT au lieu de GPL v3 — corrigé visuellement dans le badge depuis mais mérite vérification.
- N-2 : `Stop-WslMonitor` sans check admin — corrigé dans le code fourni (Monitor.ps1 actuel contient bien le check).
> Note : en relisant `Monitor.ps1`, le check admin est bien présent dans `Stop-WslMonitor`. N-2 est probablement résolu mais non mis à jour dans `AUDIT.md`.
 
**Features v2.1 non implémentées**
- `wsl-switch -Status`
- Chronométrage du switch (`[Stopwatch]`)
- Validation `swapFile`
- `-Verbose` / `-Quiet`
- Backup versionné
- Cache `Get-ProfileConfig`
### 1.5 Cohérence globale
 
Le projet est remarquablement cohérent pour un projet solo. Les décisions d'architecture sont documentées, les conventions sont appliquées uniformément, les commentaires sont présents et pertinents. La gestion des chemins est asymétrique (justifiée structurellement : `$Global:WSLRoot` pour les modules appelés via le script principal, `$PSScriptRoot` pour les modules appelés directement par le Task Scheduler) — mais mériterait un commentaire explicatif dans le code.
 
### 1.6 Maintenabilité
 
**Bonne.** La structure modulaire facilite les modifications isolées. La source de vérité JSON réduit les points de modification. L'absence de tests réduit la confiance lors des refactorings, mais l'architecture modulaire limite les effets de bord.
 
### 1.7 Robustesse actuelle
 
**Bonne à très bonne.** Les chemins critiques (switch, import, rollback) sont couverts par des mécanismes de protection. Les cas d'erreur sont gérés explicitement. Le seul angle mort significatif est l'absence de backup versionné et de détection de WSL2 actif avant shutdown.
 
### 1.8 Niveau de préparation pour diffusion GitHub/public
 
**Très bon pour un projet v2.x.** Le projet dispose de :
- `README.md` complet et professionnel
- `LICENSE` (GPL v3)
- `SECURITY.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md` absent (identifié dans la roadmap v2.2)
- CI/CD fonctionnel
- CodeQL actif
- Release automatisée
Il manque `CONTRIBUTING.md` et les templates d'issues/PRs pour passer au niveau "prêt pour contributions externes". C'est planifié v2.2.
 
---
 
## 2. Évaluation du niveau d'avancement
 
### 2.1 Fonctionnalités finalisées (v2.0.0 stable)
 
Tout ce qui est listé comme ✅ dans le tableau 1.3. Le core est complet, stable, et en production.
 
### 2.2 Fonctionnalités partiellement terminées
 
- **Alias global** : fonctionne en PS5.1, non résolu en PS7.
- **AUDIT.md** : N-2 probablement résolu dans le code mais non mis à jour dans le document.
### 2.3 Fonctionnalités instables
 
Aucune instabilité identifiée dans la v2.0.0. Les bugs préexistants ont été corrigés (transient error messages, `exit` dans les modules, etc.).
 
### 2.4 Fonctionnalités manquantes critiques (v2.1 plannifiées)
 
Par ordre de priorité :
1. **`wsl-switch -Status`** — La commande la plus demandée, prérequis à l'intégration Oh My Posh et VS Code.
2. **Tests Pester** — Dette technique principale. Bloque la contribution externe et la confiance lors des refactorings.
3. **Chronométrage du switch** — ROI UX immédiat pour 5 lignes de code.
4. **Backup versionné** — Sécurité utilisateur (rollback multi-générations).
5. **Validation `swapFile`** — Bug silencieux fréquent à corriger.
### 2.5 Priorités techniques immédiates
 
```
URGENCE HAUTE
├── Pester (premiers tests sur Get-ProfileConfig + Import-Profiles)
├── wsl-switch -Status
└── Chronométrage switch ([Stopwatch])
 
URGENCE MOYENNE
├── Backup versionné (5 backups glissants)
├── Validation swapFile
├── Cache Get-ProfileConfig
└── AUDIT.md mise à jour (N-2 résolu)
 
URGENCE FAIBLE
├── CONTRIBUTING.md
├── Templates issues/PRs
├── Alias PS7
└── JSON Schema profiles.json
```
 
---
 
## 3. Guide d'intégration TUI Studio
 
### 3.1 Présentation de TUI Studio
 
#### Ce que c'est
 
TUI Studio est un éditeur visuel drag-and-drop pour concevoir des Text User Interfaces (TUI) — pense Figma, mais pour le terminal. Il offre un canvas avec prévisualisation ANSI en temps réel, une vingtaine de composants (Box, Button, Table, List, ProgressBar, Modal, Spinner, Tabs, etc.), des modes de layout Flexbox/Grid/Absolu, et des thèmes intégrés (Dracula, Nord, Monokai, Tokyo Night...).
 
Les projets sont sauvegardés en fichiers `.tui` (JSON portable). L'outil génère du code pour plusieurs frameworks : Ink (Node.js), BubbleTea (Go), Blessed (Node.js), Textual (Python), OpenTUI, Tview (Go).
 
#### Son fonctionnement
 
1. Designer visuellement sur le canvas
2. Prévisualiser en temps réel le rendu ANSI
3. Exporter le code vers le framework cible
#### Ses avantages
 
- Prototypage ultra-rapide (minutes vs heures)
- Prévisualisation fidèle du rendu terminal
- Accélère la communication de design
- Thèmes prêts à l'emploi
#### Ses limites — et c'est ici que les choses deviennent intéressantes
 
**Limites critiques pour WSL Switcher :**
 
| Limite | Impact sur le projet |
|---|---|
| **Export de code en alpha non fonctionnel** | L'export vers n'importe quel framework ne fonctionne pas encore |
| **Aucun support PowerShell** | Les 6 frameworks cibles sont Ink, BubbleTea, Blessed, Textual, OpenTUI, Tview — zéro PS |
| **Outil de design, pas de développement** | Ne gère pas la logique métier, les états, les événements |
| **macOS/Windows app** | L'outil tourne sur le poste de développement, pas dans le terminal cible |
 
### 3.2 Analyse de compatibilité
 
#### Compatibilité avec PowerShell
 
**Directe : nulle.**
 
TUI Studio exporte vers des frameworks JavaScript, Go et Python. PowerShell n'est pas dans la liste et ne le sera probablement pas à court terme. Il n'existe pas de binding officiel entre TUI Studio et l'écosystème .NET/PowerShell.
 
L'écosystème PowerShell dispose de son propre toolkit TUI natif : **Terminal.Gui** (anciennement `gui.cs`), une bibliothèque .NET open-source qui génère des interfaces terminales riches et que PowerShell peut consommer via `Add-Type` ou en tant que module.
 
#### Compatibilité avec l'architecture actuelle
 
TUI Studio est un outil de **design**, pas un framework d'exécution. La vraie question n'est donc pas "TUI Studio est-il compatible avec PowerShell ?" mais "Comment TUI Studio s'intègre-t-il dans le workflow de développement du projet ?".
 
Réponse : **en tant qu'outil de prototypage et de spécification**, TUI Studio est entièrement compatible avec n'importe quelle stack. Les designs produits servent de cahier des charges précis pour l'implémentation.
 
#### Contraintes potentielles
 
1. **Pas d'export PS** → Toute implémentation devra être faite manuellement en PowerShell (ou via Terminal.Gui)
2. **Alpha software** → L'export de code étant non fonctionnel, TUI Studio est aujourd'hui un outil de wireframing uniquement
3. **Courbe d'apprentissage** → Apprendre un outil supplémentaire pour un bénéfice indirect
4. **Alignement** → Si l'interface PowerShell évolue vers Terminal.Gui, la structure du code change significativement
#### Impact sur les performances
 
Aucun impact en production. TUI Studio n'est pas embarqué dans le projet — c'est un outil de développement externe.
 
#### Impact sur la maintenabilité
 
**Positif à long terme** si utilisé comme outil de documentation visuelle de l'interface. Les fichiers `.tui` peuvent être versionnés dans le repo comme "source de vérité UI".
 
**Neutre à court terme** si l'export de code reste non fonctionnel.
 
### 3.3 Stratégie d'intégration — La vraie voie
 
#### Le constat brutal
 
TUI Studio ne peut pas générer de PowerShell. Point final. Deux chemins s'offrent au projet :
 
**Chemin A — TUI Studio comme outil de design + implémentation PowerShell manuelle**
 
Utiliser TUI Studio pour concevoir l'interface cible, puis implémenter manuellement les composants en PowerShell pur (comme aujourd'hui, mais avec une spec visuelle précise). C'est le chemin de la continuité.
 
**Chemin B — TUI Studio comme outil de design + Terminal.Gui comme moteur d'exécution**
 
Utiliser TUI Studio pour la conception, Terminal.Gui (bibliothèque .NET) comme couche de rendu — accessible depuis PowerShell via `Add-Type`. C'est le chemin de l'ambition technique.
 
**Recommandation :** Chemin A pour la v2.x, Chemin B à évaluer en v3.x.
 
#### Chemin A : Workflow hybride Design → Implémentation PowerShell
 
```
TUI Studio (design visuel)
        ↓
   .tui JSON versionnés (specs UI)
        ↓
Implémentation manuelle en PowerShell
(traduction fidèle du design en code)
        ↓
   Terminal PowerShell
```
 
**Ce que TUI Studio apporte concrètement :**
- Prototypage de la future interface (Status dashboard, monitoring live, profils enrichis)
- Spécification précise pour chaque écran (ce que le code doit produire)
- Documentation visuelle versionnable
- Exploration des thèmes (Nord, Tokyo Night, Dracula → traduits en couleurs PowerShell)
#### Chemin B : Intégration Terminal.Gui
 
Terminal.Gui est la bibliothèque TUI de référence pour .NET. Elle est activement maintenue par Microsoft (via la NuGet Gallery), compatible PS5.1 et PS7, et produit des interfaces comparable à celles de `htop`, `lazygit`, etc.
 
```powershell
# Exemple d'intégration Terminal.Gui dans PowerShell
Add-Type -Path "$PSScriptRoot\libs\Terminal.Gui.dll"
[Terminal.Gui.Application]::Init()
 
$window = [Terminal.Gui.Window]::new()
$window.Title = "WSL Switcher v2"
 
$listView = [Terminal.Gui.ListView]::new()
$listView.SetSource([System.Collections.ArrayList]@("WEB (2GB)", "DATA SCIENCE (6GB)", "BASE (1GB)"))
 
$window.Add($listView)
[Terminal.Gui.Application]::Top.Add($window)
[Terminal.Gui.Application]::Run()
[Terminal.Gui.Application]::Shutdown()
```
 
TUI Studio peut être utilisé pour **concevoir** cette interface — puis le design est **traduit** en Terminal.Gui (pas d'export direct, mais le mapping composant-à-composant est intuitif).
 
### 3.4 Design de la future interface
 
Voici la spécification des écrans à designer dans TUI Studio, avec les composants recommandés.
 
#### Écran 1 : Menu principal
 
```
┌─ WSL Switcher v2.x ─────────────────────────────────┐
│  RAM  ████████░░  78%  (12.4 / 16.0 GB)             │
│  Profil actif : WEB (2GB / 3 CPU)                   │
├──────────────────────────────────────────────────────┤
│                                                      │
│  > ● WEB          Brave + VS Code + WSL léger  2GB  │
│    ○ DATA SCIENCE  Jupyter + Pandas + ML       6GB  │
│    ○ BASE          Mode minimal                1GB  │
│                                                      │
├──────────────────────────────────────────────────────┤
│    ─ Historique        ─ Rollback        ─ Status   │
│    ─ Rapport           ─ Quitter                    │
└──────────────────────────────────────────────────────┘
   ↑↓ Naviguer   Entrée Sélectionner   Q Quitter
```
 
**Composants TUI Studio :** `Box` (cadre principal), `ProgressBar` (RAM), `List` (profils), `Text` (infos), `Menu` (actions)
 
#### Écran 2 : Dashboard Status (`wsl-switch -Status`)
 
```
┌─ WSL Switcher — Status ─────────────────────────────┐
│                                                      │
│  SYSTÈME                                             │
│  RAM Windows    ████████░░  78%  (12.4 / 16.0 GB)  │
│  RAM WSL2       █████░░░░░  52%   (3.1 / 6.0 GB)   │
│                                                      │
│  PROFIL ACTIF                                        │
│  Nom          WEB                                    │
│  RAM allouée  2 GB                                   │
│  CPU alloués  3 processors                           │
│  Swap         3 GB                                   │
│                                                      │
│  MONITORING                                          │
│  État         ● ACTIF (Ready)                       │
│  Seuil        80%                                    │
│  Dernière alerte  2026-05-14 09:32                  │
│                                                      │
│  HISTORIQUE (3 derniers)                             │
│  2026-05-15 09:12  SWITCH → WEB       (4.2s)        │
│  2026-05-14 14:30  SWITCH → DATA      (5.8s)        │
│  2026-05-13 08:55  SWITCH → WEB       (3.9s)        │
│                                                      │
└──────────────────────────────────────────────────────┘
```
 
**Composants TUI Studio :** `Box` sections, `ProgressBar` (RAM), `Table` (historique), `Text` coloré par état
 
#### Écran 3 : Monitoring live (`wsl-switch -Watch` — roadmap v2.3)
 
```
┌─ WSL Switcher — Live Monitor ──────────── Refresh: 5s ┐
│                                                        │
│  RAM Windows  ████████████████░░░░  80%  12.8/16.0 GB │
│  RAM WSL2     ████████░░░░░░░░░░░░  52%   3.1/6.0 GB  │
│  CPU vmmem    ██░░░░░░░░░░░░░░░░░░  12%                │
│                                                        │
│  Processus WSL2                                        │
│  ┌────────────────────────────────────────────────┐   │
│  │  PID    NOM              RAM      CPU           │   │
│  │  1234   python3          1.2 GB   8%            │   │
│  │  5678   node             0.4 GB   2%            │   │
│  │  9012   zsh              0.1 GB   0%            │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  Alertes (dernières 24h)                               │
│  ⚠ 14:30  RAM WSL2 > 80% — Switch recommandé          │
│                                                        │
└────────────────────────────────────────────────────────┘
   Q Quitter   S Switch   R Forcer refresh
```
 
**Composants TUI Studio :** `ProgressBar` x3, `Table` (processus), `List` (alertes), `Spinner` (refresh), `Tabs`
 
#### Écran 4 : Gestion des profils enrichie
 
```
┌─ WSL Switcher — Profils ────────────────────────────┐
│                                                      │
│  ┌──────────┬────────┬─────┬──────┬──────────────┐  │
│  │ NOM      │ RAM    │ CPU │ SWAP │ DESCRIPTION   │  │
│  ├──────────┼────────┼─────┼──────┼──────────────┤  │
│  │ ● WEB    │ 2 GB   │  3  │ 3 GB │ VS Code+Brave│  │
│  │   DATA   │ 6 GB   │  5  │ 2 GB │ Jupyter+ML   │  │
│  │   BASE   │ 1 GB   │  2  │ 1 GB │ Mode minimal │  │
│  └──────────┴────────┴─────┴──────┴──────────────┘  │
│                                                      │
│  [+ Nouveau profil]  [Éditer]  [Supprimer]           │
│  [Exporter JSON]     [Importer JSON]                 │
│                                                      │
└──────────────────────────────────────────────────────┘
```
 
**Composants TUI Studio :** `Table`, `Button` row
 
### 3.5 Implémentation technique
 
#### Structure de fichiers recommandée pour TUI Studio
 
```
WSL-Switch/
├── design/                    ← Nouveau dossier (versionné dans Git)
│   ├── screens/
│   │   ├── main-menu.tui
│   │   ├── status-dashboard.tui
│   │   ├── live-monitor.tui
│   │   └── profile-manager.tui
│   ├── components/            ← Composants réutilisables
│   │   ├── ram-bar.tui
│   │   └── profile-row.tui
│   └── themes/
│       └── wsl-switch-theme.tui
├── wsl-switch.ps1
├── modules/
│   ...
```
 
#### Organisation du code pour l'interface actuelle (Chemin A — PowerShell pur)
 
La traduction du design TUI Studio vers PowerShell suit ce mapping :
 
| Composant TUI Studio | Équivalent PowerShell actuel | Équivalent Terminal.Gui (Chemin B) |
|---|---|---|
| `Box` | `$LINE_TOP` / `Make-BoxLine` | `Window`, `FrameView` |
| `ProgressBar` | `Get-RamBar` (blocs Unicode) | `ProgressBar` |
| `List` | Boucle + `Write-Host` avec cursor | `ListView` |
| `Table` | Affichage tabulaire manuel | `TableView` |
| `Text` coloré | `Write-Host -ForegroundColor` | `Label` |
| `Spinner` | — (absent) | `SpinnerView` |
| `Modal` | — (absent) | `Dialog` |
 
#### Snippet d'intégration : implémentation du chronomètre (Chemin A, prioritaire)
 
```powershell
# Dans ProfileManager.ps1, fonction Set-WslProfile
function Set-WslProfile {
    param(
        [Parameter(Mandatory)][string]$Key,
        [switch]$DryRun
    )
    # ...code existant...
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    wsl --shutdown
    Start-Sleep -Seconds 2
    Set-Content -Path (Get-WslConfigPath) -Value $content -Encoding UTF8
    
    $stopwatch.Stop()
    $elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
    
    Write-Host "  OK - $($profileDef.displayName) actif en ${elapsed}s" -ForegroundColor Green
    Write-SwitchLog -Action "SWITCH" -ProfileKey $Key -Details "$($profileDef.memory), $($profileDef.processors) CPU, ${elapsed}s"
}
```
 
#### Snippet d'intégration : implémentation de `wsl-switch -Status`
 
```powershell
# Dans wsl-switch.ps1 — ajouter le paramètre -Status
param(
    # ...params existants...
    [switch]$Status
)
 
# Dans le point d'entrée
if ($Status) {
    Show-StatusDashboard
    exit
}
 
# Nouvelle fonction dans wsl-switch.ps1
function Show-StatusDashboard {
    $config  = Get-ProfileConfig
    $active  = Get-ActiveProfile -Config $config
    $ram     = Get-RamInfo
    $ramBar  = Get-RamBar -Pct $ram.pct
    $ramColor = if ($ram.pct -ge 80) { "Red" } elseif ($ram.pct -ge 60) { "Yellow" } else { "Green" }
 
    # Statut monitoring
    $monTask  = Get-ScheduledTask -TaskName "WSL2-RamMonitor" -ErrorAction SilentlyContinue
    $monState = if ($monTask) { "ACTIF ($($monTask.State))" } else { "INACTIF" }
    $monColor = if ($monTask) { "Green" } else { "DarkGray" }
    
    # Derniere alerte
    $cooldown = Join-Path $Global:WSLRoot "data\monitor_cooldown.txt"
    $lastAlert = if (Test-Path $cooldown) { (Get-Content $cooldown -Raw).Trim() } else { "Aucune" }
 
    Clear-Host
    Write-Host ""
    Write-Host $LINE_TOP -ForegroundColor Cyan
    Write-Host (Make-BoxLine "    " "   WSL2 Profile Switcher  v$($Global:AppVersion) — Status") -ForegroundColor Cyan
    Write-Host $LINE_MID -ForegroundColor Cyan
    Write-Host (Make-BoxLine "    " "  RAM Windows  $ramBar  $($ram.pct)%  ($($ram.used)/$($ram.total) GB)") -ForegroundColor $ramColor
    Write-Host $LINE_SEP -ForegroundColor DarkGray
    Write-Host (Make-BoxLine "    " "  Profil actif : $($active.name)") -ForegroundColor White
    Write-Host (Make-BoxLine "    " "  RAM allouee  : $($active.memory)") -ForegroundColor Gray
    Write-Host (Make-BoxLine "    " "  CPU alloues  : $($active.processors)") -ForegroundColor Gray
    Write-Host $LINE_SEP -ForegroundColor DarkGray
    Write-Host (Make-BoxLine "    " "  Monitoring   : $monState") -ForegroundColor $monColor
    Write-Host (Make-BoxLine "    " "  Derniere alerte : $lastAlert") -ForegroundColor Gray
    Write-Host $LINE_BOT -ForegroundColor Cyan
    Write-Host ""
}
```
 
#### Snippet d'intégration : cache Get-ProfileConfig
 
```powershell
# En haut de ProfileManager.ps1 (après les fonctions Get-ProfilesPath, etc.)
$script:ProfileConfigCache = $null
 
function Get-ProfileConfig {
    if ($null -ne $script:ProfileConfigCache) {
        return $script:ProfileConfigCache
    }
    $path = Get-ProfilesPath
    # ...code de lecture/validation existant...
    $script:ProfileConfigCache = $parsed
    return $parsed
}
 
function Clear-ProfileConfigCache {
    $script:ProfileConfigCache = $null
}
# Appeler Clear-ProfileConfigCache dans Set-WslProfile et Import-Profiles
```
 
#### Intégration Terminal.Gui (Chemin B — référence pour v3.x)
 
```powershell
# Install-TerminalGui.ps1 — script d'installation optionnel
$nugetUrl = "https://www.nuget.org/api/v2/package/Terminal.Gui"
$libsDir  = Join-Path $PSScriptRoot "libs"
if (-not (Test-Path $libsDir)) { New-Item -ItemType Directory $libsDir | Out-Null }
 
# Download et extraction du package NuGet
Invoke-WebRequest -Uri $nugetUrl -OutFile "$libsDir\terminal.gui.nupkg"
Expand-Archive "$libsDir\terminal.gui.nupkg" -DestinationPath "$libsDir\terminal.gui" -Force
$dll = Get-ChildItem "$libsDir\terminal.gui" -Recurse -Filter "Terminal.Gui.dll" |
       Where-Object { $_.FullName -match "netstandard" } | Select-Object -First 1
Copy-Item $dll.FullName "$libsDir\Terminal.Gui.dll"
 
# Usage dans wsl-switch.ps1
Add-Type -Path (Join-Path $PSScriptRoot "libs\Terminal.Gui.dll")
 
function Show-TuiMenu {
    [Terminal.Gui.Application]::Init()
    
    $win = [Terminal.Gui.Window]@{ Title = "WSL Switcher v$($Global:AppVersion)" }
    
    $items = [System.Collections.ArrayList]::new()
    $config = Get-ProfileConfig
    foreach ($key in $config.profiles.PSObject.Properties.Name) {
        $p = $config.profiles.$key
        [void]$items.Add("$($p.displayName.PadRight(16)) $($p.memory) / $($p.processors) CPU")
    }
    
    $list = [Terminal.Gui.ListView]@{
        X = 2; Y = 2; Width = 44; Height = $items.Count
    }
    $list.SetSource($items)
    
    $btnSwitch = [Terminal.Gui.Button]@{
        X = 2; Y = $items.Count + 4; Text = "Activer"
    }
    $btnSwitch.add_Clicked({
        $key = $config.profiles.PSObject.Properties.Name[$list.SelectedItem]
        [Terminal.Gui.Application]::RequestStop()
        Set-WslProfile -Key $key
    })
    
    $win.Add($list, $btnSwitch)
    [Terminal.Gui.Application]::Top.Add($win)
    [Terminal.Gui.Application]::Run()
    [Terminal.Gui.Application]::Shutdown()
}
```
 
### 3.6 Risques et limites
 
| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Export TUI Studio reste en alpha / non livré | Élevée | Moyen | Utiliser comme outil de design uniquement — l'export n'est pas dans la valeur ajoutée pour ce projet |
| Adoption de Terminal.Gui complexifie la maintenance | Moyenne | Élevé | Ne pas adopter Terminal.Gui avant v3.x, attendre la maturité de la base de code testée |
| TUI Studio ajoute une dépendance outil externe | Faible | Faible | Outil de design, non embarqué — aucun impact sur le runtime |
| Design TUI Studio non aligné avec les contraintes PowerShell | Moyenne | Moyen | Valider chaque composant contre l'implémentation PS avant de finaliser le design |
| Fragmentation de la maintenance (2 renderers : PS pur + Terminal.Gui) | Élevée si B | Élevé | Choisir l'un ou l'autre, pas les deux en parallèle |
 
### 3.7 Alternatives pertinentes
 
Si l'objectif final est une interface TUI riche et productive, voici les alternatives à TUI Studio pour WSL Switcher :
 
| Outil | Langage | Maturité | Pertinence |
|---|---|---|---|
| **Terminal.Gui** | .NET/C# (PowerShell-compatible) | Très mature | ⭐⭐⭐⭐⭐ — La meilleure option PS |
| **Spectre.Console** | .NET/C# (via Add-Type) | Très mature | ⭐⭐⭐⭐ — Rendu riche, tables, barres de progression |
| **PowerShell natif amélioré** | PowerShell pur | Stable | ⭐⭐⭐ — Continuité, zéro dépendance |
| **Textual** (Python) | Python | Mature | ⭐⭐ — Nécessite de migrer hors PS |
| **BubbleTea** | Go | Mature | ⭐ — Réécriture complète |
 
**Recommandation claire :** pour rester dans l'écosystème PowerShell/.NET, Terminal.Gui + Spectre.Console sont les options les plus cohérentes avec l'architecture existante. TUI Studio sert d'outil de design, pas de framework d'exécution.
 
---
 
## 4. Roadmap d'intégration
 
### Phase 1 — TUI Studio comme outil de design (v2.1 — immédiat)
 
**Durée estimée :** 1-2 semaines en parallèle du développement des features v2.1
 
**Objectif :** utiliser TUI Studio pour concevoir les écrans manquants (`-Status`, `-Watch`) et valider l'UX avant implémentation.
 
| Étape | Action | Difficulté | Livrable |
|---|---|---|---|
| 1 | Installer TUI Studio | Triviale | — |
| 2 | Choisir un thème cohérent avec la palette actuelle (Tokyo Night ou Nord) | Triviale | Thème `.tui` |
| 3 | Designer l'écran Status Dashboard | Faible | `design/screens/status-dashboard.tui` |
| 4 | Designer l'écran Live Monitor | Faible | `design/screens/live-monitor.tui` |
| 5 | Implémenter `wsl-switch -Status` en PowerShell depuis le design | Faible | Feature complète |
| 6 | Implémenter le chronométrage de switch | Triviale | 5 lignes dans Set-WslProfile |
| 7 | Versionner les fichiers `.tui` dans `design/` | Triviale | Dossier versionné |
 
**Estimation de difficulté globale : 2/10**
 
### Phase 2 — Évaluation Terminal.Gui (v2.3 — expérimental)
 
**Durée estimée :** 2-4 semaines
 
**Objectif :** créer un prototype de menu principal avec Terminal.Gui pour évaluer la viabilité du Chemin B.
 
| Étape | Action | Difficulté | Livrable |
|---|---|---|---|
| 1 | Créer `Install-TerminalGui.ps1` (téléchargement DLL) | Faible | Script d'install |
| 2 | Prototype menu principal Terminal.Gui (feature flag) | Moyenne | `modules/TuiRenderer.ps1` |
| 3 | Évaluation : UX, performances, complexité maintenance | Faible | Go/No-go décision |
| 4 | Décision : Chemin A (PS pur) ou Chemin B (Terminal.Gui) | — | ADR documenté |
 
**Estimation de difficulté globale : 5/10**
 
### Phase 3 — Migration interface (v3.0 — si Chemin B validé)
 
**Durée estimée :** 4-8 semaines
 
**Objectif :** migrer l'interface vers Terminal.Gui avec TUI Studio comme outil de design continu.
 
| Étape | Action | Difficulté | Livrable |
|---|---|---|---|
| 1 | Extraire la logique d'affichage dans `MenuRenderer.ps1` | Moyenne | Module isolé |
| 2 | Implémenter les 4 écrans principaux en Terminal.Gui | Élevée | Interface complète |
| 3 | Tests Pester pour les composants d'interface | Moyenne | Couverture UI |
| 4 | Migration `Show-InteractiveMenu` → Terminal.Gui | Élevée | Menu principal refactorisé |
| 5 | Documentation de l'architecture UI | Faible | Section ARCHITECTURE.md |
 
**Estimation de difficulté globale : 7/10**
 
---
 
## 5. Recommandations professionnelles finales
 
### Ce qu'il faut faire
 
**Immédiatement (v2.1)**
1. **Installer TUI Studio et designer les écrans manquants** — coût presque nul, bénéfice de clarté UX immédiat.
2. **Implémenter `wsl-switch -Status`** depuis le design TUI Studio.
3. **Implémenter le chronométrage** (5 lignes, ROI immédiat).
4. **Écrire les premiers tests Pester** — `Get-ProfileConfig` et `Import-Profiles` en priorité.
5. **Mettre à jour `AUDIT.md`** — N-2 est résolu dans le code, le document ne le reflète pas.
**À planifier (v2.2)**
6. **Versionner les fichiers `.tui`** dans `design/` comme documentation visuelle de l'interface.
7. **Rédiger `CONTRIBUTING.md`** — prérequis à toute contribution externe.
8. **Résoudre l'alias PS7** — problème identifié et ouvert depuis trop longtemps.
 
**À évaluer (v2.3)**
9. **Prototype Terminal.Gui** pour évaluer le Chemin B sans engagement.
10. **Cache `Get-ProfileConfig`** — prépare les features futures sans overhead visible.
 
### Ce qu'il faut éviter
 
1. **Ne pas attendre l'export TUI Studio** — il n'est pas fonctionnel, et même quand il le sera, il ne supportera pas PowerShell. TUI Studio est un outil de design, pas un générateur de code PowerShell.
2. **Ne pas adopter Terminal.Gui avant d'avoir des tests** — migrer l'interface vers un nouveau framework sans filet de sécurité Pester est exactement la situation que l'audit a identifiée comme risque majeur.
3. **Ne pas utiliser TUI Studio pour gérer la logique métier** — c'est un outil de layout, pas un framework d'application. La logique de switch, de backup, et de monitoring reste entièrement dans les modules PowerShell.
4. **Ne pas refactoriser l'interface et les fonctionnalités en même temps** — une chose à la fois. Interface d'abord avec TUI Studio comme spec, puis implémentation.
5. **Ne pas distribuer les fichiers `.tui` comme livrable utilisateur** — c'est de la documentation développeur. Le README n'a pas à en parler.
### Principes directeurs de l'intégration
 
- **TUI Studio = Figma du terminal** : il sert à concevoir et communiquer, pas à coder.
- **La valeur de TUI Studio pour WSL Switcher est dans le prototypage, pas dans l'export.**
- **Le code PowerShell reste la source de vérité d'exécution** — les fichiers `.tui` sont la source de vérité de design.
- **Toute migration vers Terminal.Gui doit être précédée d'une suite de tests Pester.**
---
 
## Annexe — Matrice de décision TUI Studio vs Terminal.Gui
 
```
USAGE                              TUI STUDIO    TERMINAL.GUI    PS PUR
────────────────────────────────────────────────────────────────────────
Prototypage visuel rapide          ⭐⭐⭐⭐⭐       ❌             ❌
Documentation UI versionnable      ⭐⭐⭐⭐⭐       ❌             ❌
Génération de code PowerShell      ❌             ⭐⭐⭐⭐         ⭐⭐⭐⭐⭐
Composants riches (table, modal)   ✅ (design)    ⭐⭐⭐⭐⭐        ⭐⭐ (manuel)
Compatibilité PS5.1                N/A            ⭐⭐⭐⭐         ⭐⭐⭐⭐⭐
Zéro dépendance externe            ✅ (design)    ❌              ⭐⭐⭐⭐⭐
Courbe d'apprentissage             Faible         Moyenne         Nulle
Maintenabilité long terme          N/A            Bonne           Bonne
Pertinence pour v2.x               ⭐⭐⭐⭐⭐       ❌              ⭐⭐⭐⭐⭐
Pertinence pour v3.x               ⭐⭐⭐⭐         ⭐⭐⭐⭐⭐        ⭐⭐⭐
```
 
---
 
*Document produit sur la base du code source v2.0.0, de l'AUDIT.md, du ROADMAP.md et de l'exposé technologique.*
*Prochaine révision recommandée : après publication de la v2.1.*