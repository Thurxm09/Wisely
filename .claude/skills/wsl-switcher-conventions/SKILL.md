---
name: wsl-switcher-conventions
description: Conventions de code et contexte du projet WSL Switcher (wsl-switch), un CLI PowerShell qui gere dynamiquement les profils de ressources WSL2 (RAM, CPU, swap) via .wslconfig et data/profiles.json. A utiliser des qu'une session travaille dans ce repo -- edition de wsl-switch.ps1, modules/*.ps1 (ProfileManager, Logger, Monitor, MonitorTask, WeeklyReport), data/profiles.json, docs/ (AUDIT.md, ROADMAP.md, TASKS.md), ou tests Pester -- meme si la demande ne mentionne pas explicitement "WSL Switcher". Suivre systematiquement les regles de code PowerShell du projet, son architecture actuelle et l'ordre de priorite v2.1 avant de proposer une implementation.
---

# WSL Switcher — Conventions et contexte du projet

WSL Switcher est un outil CLI PowerShell personnel maintenu en solo par Thuram (GitHub `Thurxm09`) sur une machine à 16 Go de RAM (HP All-in-One, i5) faisant tourner WSL2/Ubuntu, VS Code et un navigateur en simultané. Cette contrainte mémoire est la raison d'être du projet : Windows n'offre aucun mécanisme natif pour basculer dynamiquement l'allocation RAM/CPU de WSL2 selon le contexte de travail (dev web léger, data science intensive, mode minimal). L'outil résout ce problème via des profils JSON, un menu interactif, un monitoring passif et un reporting hebdomadaire.

Version actuelle : lire `VERSION` à la racine du repo pour la valeur exacte (ne pas la coder en dur ici, elle évolue). État au moment de la rédaction de ce skill : v2.0.0 stable publiée, v2.1 en développement actif. Repo : `git@github.com:Thurxm09/wsl-switch.git`.

Toute la documentation de fond du projet vit dans `docs/` : `AUDIT.md` (audit qualité détaillé), `ROADMAP.md` (vision stratégique et principes directeurs), `TASKS.md` (liste de tâches courante), plus deux documents d'analyse ponctuels (état des lieux / intégration TUI Studio, exposé technologique). Consulte ces fichiers directement plutôt que de supposer leur contenu — ce skill en résume les points structurants mais ne s'y substitue pas.

## Conventions de code PowerShell

Ces règles viennent de retours d'expérience concrets sur ce projet, pas de préférences arbitraires — les respecter évite de réintroduire des bugs déjà rencontrés.

- **Réécrire les `.ps1` en entier plutôt que patcher.** Le patch incrémental (edits regex ciblés) a été une source récurrente de bugs sur ce projet. Pour toute modification structurelle d'un fichier `.ps1`, régénère le fichier complet. Un correctif d'une ligne à très haute confiance (ex. typo, valeur littérale) peut rester un edit ciblé — mais dès que la logique change, réécris.
- **ASCII pur visé pour tout `.ps1`** (caractères spéciaux via `[char]0xXXXX`, ex. pour les caractères de dessin de boîte de l'UI terminal). C'est la convention documentée en tête de `wsl-switch.ps1`, qui la respecte intégralement. Elle n'est en revanche pas encore pleinement respectée partout : `modules/Logger.ps1` et `modules/ProfileManager.ps1` contiennent aujourd'hui quelques caractères accentués français résiduels. Le code neuf ou réécrit doit être ASCII-clean ; ne corrige pas la dérive existante d'un fichier en incidental d'une tâche non liée, sauf si on te le demande explicitement.
- **`([string]$char * $n)`** pour la répétition de caractères (pas de boucle, pas de `-join`).
- **`throw`, jamais `exit`, dans les modules dot-sourcés.** `wsl-switch.ps1` dot-source `modules/ProfileManager.ps1`, `modules/Logger.ps1` et `modules/Monitor.ps1` dans son propre scope — un `exit` dans un module dot-sourcé ferme la session PowerShell entière de l'utilisateur, pas seulement le script (c'était le finding C-1 de l'audit qualité). Le script principal attrape ces exceptions via `try/catch` et appelle `exit 1` lui-même, ce qui est correct puisqu'il est à la racine. Exception légitime : `modules/MonitorTask.ps1` et `modules/WeeklyReport.ps1` sont exécutés en standalone par le Planificateur de tâches Windows (pas dot-sourcés) et utilisent donc `exit 0` à bon droit — ne change pas ce pattern.
- **`$script:` plutôt que `$Global:`** pour l'état interne à un module (mémoïsation, constantes comme `$script:TASK_NAME`/`$script:WEEKLY_TASK_NAME` dans `Monitor.ps1`). Exception documentée et acceptée : `$Global:WSLRoot`, injecté par `wsl-switch.ps1`, est le contrat cross-module qui donne aux modules dot-sourcés la racine du repo — ce n'est pas de la mémoïsation, donc ça ne contredit pas la règle `$script:`.
- **Scripts bootstrap Python ASCII-safe** (réécriture complète du fichier cible, sortie `[OK]`/`[SKIP]`) comme mécanisme standard quand la tâche consiste à générer/livrer de nouveaux fichiers plutôt qu'éditer du code existant.

## Carte d'architecture

Vérifiée sur le code actuel — en cas de doute, relis le fichier plutôt que de te fier à un résumé qui pourrait dater.

- **`wsl-switch.ps1`** (racine, ~420 lignes) — point d'entrée unique et orchestrateur. Aucun couplage entre modules : ils ne se connaissent pas entre eux. Flags : `-Profil`, `-DryRun`, `-Rollback`, `-History`, `-Export`, `-Import`, `-NewProfile`, `-Monitor`, `-Report`, `-Clean`, `-Status`, `-Version`. Dashboard `-Status` : barre RAM, profil actif, historique.
- **`modules/ProfileManager.ps1`** — coeur métier : `Get-ProfileConfig` (lit/parse `data/profiles.json`, `throw` si absent/corrompu), `Get-ActiveProfile`, `Set-WslProfile` (écrit `.wslconfig`, backup avant écriture, validation post-écriture, rollback auto si invalide), `New-CustomProfile`, `Import-Profiles`/`Export-Profiles`, `Invoke-Rollback`, `Test-WslConfigIntegrity`.
- **`modules/Logger.ps1`** — `Write-SwitchLog`, `Show-SwitchHistory` (lit/écrit `data/history.json`).
- **`modules/Monitor.ps1`** — `Start-WslMonitor`/`Stop-WslMonitor`/`Get-MonitorStatus`, enregistre deux tâches planifiées Windows (monitoring RAM + rapport hebdo lundi 09h). Les deux vérifient les droits admin avant d'agir (`Register-ScheduledTask`/`Unregister-ScheduledTask` les requièrent).
- **`modules/MonitorTask.ps1`, `modules/WeeklyReport.ps1`** — standalone, exécutés directement par le Planificateur de tâches, jamais dot-sourcés, utilisent `$PSScriptRoot` (pas `$Global:WSLRoot`, indisponible hors du script principal) et `exit 0`.
- **`data/profiles.json`** — source de vérité externe unique pour les profils et paramètres. Schéma : `version` (string), `profiles` (objet par clé, ex. `web`/`data`/`base`, chacun avec `displayName`, `description`, `color`, `memory`, `processors`, `swap`, `swapFile`, `swappiness`), `settings` (`monitorThreshold`, `monitorIntervalSeconds`, `historyMaxEntries`, `backupEnabled`). Consulte le fichier directement plutôt que de te fier à ce résumé s'il évolue.
- **`.wslconfig`** (`C:\Users\othur\.wslconfig` côté hôte) — les chemins de swap doivent utiliser des slashs forward même en contexte Windows (ex. `C:/Temp/wsl-swap.vhdx`).
- **CI** (`.github/workflows/ci.yml`) — syntax check de tous les `*.ps1`, `Invoke-ScriptAnalyzer -Severity Warning` avec 7 règles exclues et justifiées en commentaire, validation du schéma minimal de `data/profiles.json`. Autres workflows : `release.yml` (ZIP + GitHub Release), `bump-version.yml` (bump semver + CHANGELOG + tag), `codeql.yml`.
- **`docs/`** — `AUDIT.md`, `ROADMAP.md`, `TASKS.md`, et deux documents d'analyse (état des lieux/TUI Studio, exposé technologique).

## Principes directeurs du projet

Tirés de `docs/ROADMAP.md` §9 — ce sont des critères de conception, pas seulement des règles de style. Une feature qui en viole plusieurs à la fois ne devrait pas être implémentée, quel que soit son attrait apparent :

- **Zéro configuration requise pour commencer** — les profils par défaut doivent couvrir la majorité des cas sans personnalisation.
- **Réversibilité systématique** — toute action qui modifie l'état du système (switch, import, rollback) doit être réversible ; pas d'opération destructive sans confirmation.
- **Failing fast et bruyant** — une erreur explicite vaut mieux qu'un comportement silencieux incorrect.
- **Scriptabilité de première classe** — toute action du menu interactif doit être réalisable en CLI directe, avec des codes de sortie standards (0 succès, 1 erreur).
- **Source de vérité unique** — `data/profiles.json` reste la seule source de vérité pour les profils et paramètres ; pas de comportement métier hardcodé si sa valeur peut varier.
- **Minimalisme fonctionnel** — chaque feature doit justifier une vraie valeur utilisateur documentée, pas juste "c'est possible".
- **Compatibilité descendante des profils** — une mise à jour de l'outil ne doit jamais casser un `profiles.json` existant ; nouvelles clés optionnelles avec valeurs par défaut.

## Priorités v2.1

Ordre fixe confirmé par `docs/TASKS.md` et `docs/ROADMAP.md` — avancer une feature à la fois, dans cet ordre, sauf indication contraire explicite :

1. **Tests Pester pour `Get-ProfileConfig` et `Import-Profiles`** — priorité absolue, bloque tout autre chantier structurel. Aucun dossier `tests/` n'existe encore dans le repo : c'est un travail entièrement greenfield, pas un ajout à une suite existante.
2. **Validation du chemin du swap file** — vérifier que le répertoire cible de `swapFile` existe avant l'écriture dans `.wslconfig`.
3. **Backup versionné avec historique glissant** — actuellement un seul backup de `.wslconfig` est conservé ; passer à N backups (rotation).
4. **Flags `-Verbose`/`-Quiet`**.
5. **Fix du bug visuel de troncature de la barre RAM** dans `wsl-switch -Status`.
6. **Cache mémoïsé pour `Get-ProfileConfig`** via `$script:ProfileConfigCache`, invalidé par une fonction `Clear-ProfileConfigCache` (à créer) appelée après `Set-WslProfile`, `Import-Profiles`, `New-CustomProfile`.

## État de l'audit qualité

`docs/AUDIT.md` documente un audit complet (15 findings initiaux : 5 critiques, 6 importants, 4 secondaires), tous corrigés dans le code actuel.

Deux points à connaître :
- **`Clear-ProfileConfigCache` n'existe pas encore** dans `modules/ProfileManager.ps1` — c'est l'item 6 de la liste v2.1 ci-dessus, pas une fonction déjà appelable. Ne suppose jamais qu'elle existe.
- **Écart doc/code sur deux findings mineurs (N-1, N-2)** : `docs/AUDIT.md` les liste encore comme non corrigés (badge LICENSE README à "MIT" au lieu de "GPL-v3" ; absence de check admin dans `Stop-WslMonitor`), mais le code actuel montre que les deux sont en réalité déjà résolus — le README affiche bien le badge GPL-v3, et `Stop-WslMonitor` contient bien le bloc de vérification admin. En cas de divergence entre `docs/AUDIT.md` et le code, traite le code comme source de vérité et signale l'écart à Thuram plutôt que de corriger silencieusement le document.

La vision long terme à 3 paliers de maturité (outil personnel de référence → outil open-source distribué v3.x via Winget/PowerShell Gallery avec suite de tests → outil de référence de l'écosystème WSL v4.x+ avec hooks/intégrations) est détaillée dans `docs/ROADMAP.md` §2.

## Workflow git

- `git pull --rebase` en cas de divergence.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, etc.), souvent avec référence de PR.
- Commits signés/vérifiés GPG (WSL2 et Windows) — ne jamais désactiver la signature.

## Stack et environnement

PowerShell 5.1 + 7 (chemins `$PROFILE` distincts : `Documents\WindowsPowerShell\` pour 5.1 vs `Documents\PowerShell\` pour 7 ; l'alias `wsl-switch` est résolu via un symlink des fichiers de profil entre les deux versions — contournement en place, résolution long terme différée en v2.2). WSL2/Ubuntu, VS Code, GitHub CLI, Docker Desktop, conda/miniforge, pyenv, nvm, pnpm. Terminal : Oh My Posh (thème Tokyo Night), Cascadia Code NF, eza, bat, fd-find, ripgrep, btop, lazygit, zoxide, fzf. Tests : Pester (à venir, voir priorités v2.1), PSScriptAnalyzer (déjà en CI).
