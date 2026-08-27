---
name: wisely-conventions
description: Conventions de code et contexte du projet Wisely (wisely), un CLI PowerShell qui transforme l'etat reel des ressources WSL2 en decisions explicables et en actions sures, via .wslconfig et data/profiles.json. A utiliser des qu'une session travaille dans ce repo -- edition de wisely.ps1, modules/*.ps1 (ProfileManager, Logger, Monitor, MonitorTask, WeeklyReport), data/profiles.json, docs/ (PROBLEM, VISION, USE-CASES, PRINCIPLES, DOCTRINE-LECTURE, RESOURCE-MODEL, ASSUMPTIONS, ROADMAP, decisions/, audits/, AUDIT, TASKS), ou tests Pester -- meme si la demande ne mentionne pas explicitement "Wisely". Suivre systematiquement les regles de code PowerShell du projet, son architecture actuelle et l'ordre de priorite courant avant de proposer une implementation.
---

# Wisely — Conventions et contexte du projet

Wisely est un outil CLI PowerShell maintenu en solo par Thuram (GitHub `Thurxm09`), qui pilote l'allocation de ressources de WSL2 sous Windows via des profils JSON, un menu interactif, un monitoring passif et un reporting.

**Direction produit revue le 2026-08-26, puis revisee le 2026-08-27** apres adoption d'un audit strategique externe (`docs/decisions/0013-adoption-audit-strategique-externe.md`).

La capacite fondamentale visee est de **transformer l'etat reel des ressources WSL2 en decisions explicables et en actions sures** (`docs/VISION.md`). Le vocabulaire du produit tient en quatre objets — **Etat, Cause, Politique, Action** — et une boucle : observer -> **expliquer** -> recommander -> agir -> verifier.

**L'ecart** (distance entre consomme et autorise) n'est plus l'ontologie du produit : c'est la relation entre l'Etat observe et la Politique, modele interne des ressources a plafond configurable. Il ne dit rien du cache, de l'I/O ni du disque, et il masque que 8 Go consommes ne sont pas 8 Go necessaires.

Quatre consequences a connaitre avant toute proposition :

1. **Le filtre de perimetre a change.** Ce n'est plus « est-ce une operation sur l'ecart ? » mais : servir un des quatre objets pour un maillon nomme de la boucle, designer une case de `docs/PROBLEM.md` §3 et une situation de `docs/USE-CASES.md`, et ne tomber dans aucun non-but declare dans `docs/VISION.md`. Une reponse absente est un signal d'arret.
2. **Aucune grandeur ne s'affiche sans son entree dans `docs/RESOURCE-MODEL.md`** — portee, source, classe (directe/attribuee/estimee/correlee), confiance. Deux regles dures : la somme des RSS n'est jamais presentee comme la RAM consommee (pages partagees comptees plusieurs fois), et il n'y a pas d'« ecart CPU » (`loadavg` n'est pas un pourcentage, `nproc` ne mesure aucun usage).
3. **Le projet ne doit pas etre concu autour de la machine du mainteneur** : les profils absolus en Go sont un defaut identifie, corrige au palier P7.
4. L'affirmation historique « Windows n'offre aucun mecanisme natif » est **fausse depuis** que Microsoft livre l'application WSL Settings.

**Barriere de validation.** Le palier P3 de `docs/ROADMAP.md` est **bloquant** : aucun palier au-dela ne demarre avant que quelqu'un d'autre que le mainteneur se soit servi de l'outil. C'est la seconde regle d'ordonnancement, a cote de « on ne construit pas sur une mesure qui ment ».

Version actuelle : lire `VERSION` a la racine du repo (ne pas la coder en dur ici). Repo : `git@github.com:Thurxm09/Wisely.git`.

Toute la documentation de fond vit dans `docs/`, **un document par question** : `PROBLEM.md` (quel probleme, pour qui), `VISION.md` (la capacite fondamentale), `USE-CASES.md` (les situations reelles, jamais des personas), `PRINCIPLES.md` (les criteres d'arbitrage), `DOCTRINE-LECTURE.md` (ce que Wisely a le droit de lire dans Linux), `RESOURCE-MODEL.md` (ce que chaque chiffre signifie — les deux listes de commandes doivent rester identiques), `ASSUMPTIONS.md` (ce qui n'est pas verifie, plus le journal de validation), `ROADMAP.md` (les paliers et leur ordre), `decisions/` (les ADR), `AUDIT.md` (audit qualite du code), `TASKS.md` (taches courantes).

Deux repertoires qui ne font **pas** foi : `docs/audits/` (audits strategiques externes, archives integralement, chacun avec son ADR de reponse — a ne pas confondre avec `AUDIT.md`) et `docs/archive/` (documents historiques perimes, a **ne pas suivre**).

Consulte ces fichiers directement plutot que de supposer leur contenu.

## Skills de process

Ce repo installe aussi `using-superpowers` et `caveman` (`.claude/skills/`). Ils s'appliquent a toute session Wisely comme a n'importe quelle autre — ce ne sont pas des options isolees reservees a d'autres projets :

- **`using-superpowers`** — impose de verifier, avant toute reponse ou action (y compris une question de clarification), si un skill de process (brainstorming, systematic-debugging, ...) s'applique, et de le faire passer avant les skills d'implementation. Ce skill-ci (`wisely-conventions`) fournit le contexte projet ; il ne remplace pas un skill de process quand la tache en appelle un.
- **`caveman`** — mode de communication compresse, active par `/caveman`. S'applique a la conversation, jamais aux artefacts persistants : commits, PR, docs (`docs/*.md`), et tout contenu de `AUDIT.md`/ADR restent en prose normale.

Voir directement `.claude/skills/using-superpowers/SKILL.md` et `.claude/skills/caveman/SKILL.md` pour le detail — ne pas dupliquer leur contenu ici.

## Conventions de code PowerShell

Ces règles viennent de retours d'expérience concrets sur ce projet, pas de préférences arbitraires — les respecter évite de réintroduire des bugs déjà rencontrés.

- **Réécrire les `.ps1` en entier plutôt que patcher.** Le patch incrémental (edits regex ciblés) a été une source récurrente de bugs sur ce projet. Pour toute modification structurelle d'un fichier `.ps1`, régénère le fichier complet. Un correctif d'une ligne à très haute confiance (ex. typo, valeur littérale) peut rester un edit ciblé — mais dès que la logique change, réécris.
- **ASCII pur visé pour tout `.ps1`** (caractères spéciaux via `[char]0xXXXX`, ex. pour les caractères de dessin de boîte de l'UI terminal). C'est la convention documentée en tête de `wisely.ps1`, qui la respecte intégralement. Elle n'est en revanche pas encore pleinement respectée partout : `modules/Logger.ps1` et `modules/ProfileManager.ps1` contiennent aujourd'hui quelques caractères accentués français résiduels. Le code neuf ou réécrit doit être ASCII-clean ; ne corrige pas la dérive existante d'un fichier en incidental d'une tâche non liée, sauf si on te le demande explicitement.
- **`([string]$char * $n)`** pour la répétition de caractères (pas de boucle, pas de `-join`).
- **`throw`, jamais `exit`, dans les modules dot-sourcés.** `wisely.ps1` dot-source `modules/ProfileManager.ps1`, `modules/Logger.ps1` et `modules/Monitor.ps1` dans son propre scope — un `exit` dans un module dot-sourcé ferme la session PowerShell entière de l'utilisateur, pas seulement le script (c'était le finding C-1 de l'audit qualité). Le script principal attrape ces exceptions via `try/catch` et appelle `exit 1` lui-même, ce qui est correct puisqu'il est à la racine. Exception légitime : `modules/MonitorTask.ps1` et `modules/WeeklyReport.ps1` sont exécutés en standalone par le Planificateur de tâches Windows (pas dot-sourcés) et utilisent donc `exit 0` à bon droit — ne change pas ce pattern.
- **`$script:` plutôt que `$Global:`** pour l'état interne à un module (mémoïsation, constantes comme `$script:TASK_NAME`/`$script:WEEKLY_TASK_NAME` dans `Monitor.ps1`). Exception documentée et acceptée : `$Global:WSLRoot`, injecté par `wisely.ps1`, est le contrat cross-module qui donne aux modules dot-sourcés la racine du repo — ce n'est pas de la mémoïsation, donc ça ne contredit pas la règle `$script:`.
- **Scripts bootstrap Python ASCII-safe** (réécriture complète du fichier cible, sortie `[OK]`/`[SKIP]`) comme mécanisme standard quand la tâche consiste à générer/livrer de nouveaux fichiers plutôt qu'éditer du code existant.

## Carte d'architecture

Vérifiée sur le code actuel — en cas de doute, relis le fichier plutôt que de te fier à un résumé qui pourrait dater.

- **`wisely.ps1`** (racine, ~540 lignes) -- point d'entree unique et orchestrateur. Aucun couplage entre modules : ils ne se connaissent pas entre eux. Flags : `-Profil`, `-DryRun`, `-Force`, `-Rollback`, `-History`, `-Export`, `-Import`, `-NewProfile`, `-Monitor`, `-Report`, `-Clean`, `-Status`, `-Short`, `-Snapshot`, `-Watch`, `-Interval`, `-Version`, `-Verbose`, `-Quiet`. Dashboard `-Status` : barre RAM, profil actif, historique ; `-Watch` : rafraichissement continu.
- **`modules/ProfileManager.ps1`** -- coeur metier : `Get-ProfileConfig` (memoise, `Clear-ProfileConfigCache` pour invalider), `Get-ActiveProfile`, `Set-WslProfile` (backup, garde-fou sessions actives, ecriture, validation post-ecriture, rollback auto), `Test-ProfileDefinition` (validation partagee entre creation et import), `New-CustomProfile`, `New-SnapshotProfile`, `Import-Profiles`/`Export-Profiles`, `Invoke-Rollback`, `Backup-WslConfig`, `Resolve-ProfilePaths`, `Get-WslActiveSessions`/`Confirm-WslShutdown` (v2.4), `Get-AvailableRamGB`.
- **`modules/Logger.ps1`** — `Write-SwitchLog`, `Show-SwitchHistory` (lit/écrit `data/history.json`).
- **`modules/Monitor.ps1`** — `Start-WslMonitor`/`Stop-WslMonitor`/`Get-MonitorStatus`, enregistre deux tâches planifiées Windows (monitoring RAM + rapport hebdo lundi 09h). Les deux vérifient les droits admin avant d'agir (`Register-ScheduledTask`/`Unregister-ScheduledTask` les requièrent).
- **`modules/MonitorTask.ps1`, `modules/WeeklyReport.ps1`** — standalone, exécutés directement par le Planificateur de tâches, jamais dot-sourcés, utilisent `$PSScriptRoot` (pas `$Global:WSLRoot`, indisponible hors du script principal) et `exit 0`.
- **`data/profiles.json`** — source de vérité externe unique pour les profils et paramètres. Schéma : `version` (string), `profiles` (objet par clé, ex. `web`/`data`/`base`, chacun avec `displayName`, `description`, `color`, `memory`, `processors`, `swap`, `swapFile`, `swappiness`), `settings` (`monitorThreshold`, `monitorIntervalSeconds`, `historyMaxEntries`, `backupEnabled`, `backupHistoryMax`), valide par `schemas/profiles.schema.json` en CI. Consulte le fichier directement plutôt que de te fier à ce résumé s'il évolue.
- **`.wslconfig`** (`C:\Users\othur\.wslconfig` côté hôte) — les chemins de swap doivent utiliser des slashs forward même en contexte Windows (ex. `C:/Temp/wsl-swap.vhdx`).
- **CI** (`.github/workflows/ci.yml`) — syntax check de tous les `*.ps1`, `Invoke-ScriptAnalyzer -Severity Warning` avec 7 règles exclues et justifiées en commentaire, validation du schéma minimal de `data/profiles.json`. Autres workflows : `release.yml` (ZIP + GitHub Release), `bump-version.yml` (bump semver + CHANGELOG + tag), `codeql.yml`.
- **`docs/`** — voir la carte documentaire en tete de ce skill. `decisions/` contient les ADR numerotes ; `archive/` des documents perimes conserves pour memoire.

## Principes directeurs du projet

Tires de `docs/PRINCIPLES.md` -- ce sont des criteres de conception, pas des regles de style. Une proposition qui en viole plusieurs a la fois ne doit pas etre implementee, quel que soit son attrait technique. **Lis le fichier** : ce resume ne s'y substitue pas, et plusieurs principes y portent une revision datee.

Les sept historiques : zero configuration requise pour commencer ; reversibilite systematique ; echouer vite et bruyamment ; scriptabilite de premiere classe ; source de verite unique (`data/profiles.json`) ; minimalisme fonctionnel ; compatibilite descendante des profils.

Les cinq ajoutes le 2026-08-26, chacun ne d'une defaillance constatee dans le code :

- **Ne jamais detruire ce qu'on ne gere pas.** `.wslconfig` est un fichier PARTAGE (utilisateur, Docker Desktop, WSL Settings, politique d'entreprise). Wisely ne touche qu'aux cles qu'il gere.
- **Ne jamais mesurer ce qu'on ne peut pas attribuer.** Une mesure qui echoue doit le dire : une metrique degradee en `$null` silencieux est pire que pas de metrique.
- **Aucune recommandation sans la mesure qui la source.** Jamais "mets 6 Go" ; toujours "6 Go, parce que ton pic mesure sur 14 jours est 5,4 Go".
- **Annoncer le cout avant de le faire payer.** Le switch interrompt tout l'environnement Linux : dire ce qui va etre perdu, precisement.
- **La confiance se declare avant de s'exercer.** Toute extension de portee est documentee avant d'etre implementee (`docs/DOCTRINE-LECTURE.md`).

## Ordre de priorite courant

Paliers revises le 2026-08-27 (`docs/ROADMAP.md`). **Deux** regles d'ordonnancement : on ne construit ni diagnostic ni recommandation sur une mesure qui ment ; et on ne construit pas au-dela d'une capacite qu'on n'a pas confrontee a un utilisateur. Avancer un palier a la fois, dans cet ordre, sauf indication contraire explicite.

1. **P0 / v2.5 "Verite" -- livree.** Cinq correctifs, chacun sa PR, developpes en TDD : detection `VmmemWSL` en plus de `vmmem` ; seuil d'alerte rapporte au plafond WSL2 et non a la RAM totale (melange de portees) ; `ramDeltaGB` retire (mesure non attribuable, pas corrigee -- le vrai remplacement est P6) ; identite du profil actif marquee dans une section `[wisely]` de `.wslconfig` au lieu d'etre devinee par egalite de RAM ; ecriture de `.wslconfig` non destructive via `Set-IniSectionKeys` (fusion des cles gerees, cles et sections non gerees preservees -- autoMemoryReclaim, sparseVhd, `[experimental]`, etc.).
2. **P1 / v2.6 "Contrat"** -- prochaine priorite. Implementation de `docs/DOCTRINE-LECTURE.md` (liste fermee de commandes, consentement explicite, degradation propre).
3. **P2 / v3.0 "Diagnostic"** -- `wisely diagnose`, Etat et Cause avec leurs classes de mesure, annonce du cout avant le geste. Prerequis : `docs/RESOURCE-MODEL.md` fait foi.
4. **P3 -- barriere de validation, BLOQUANTE.** Publier `wisely diagnose` seul et le confronter a des utilisateurs externes. **Aucun palier au-dela ne demarre avant.** Resultats consignes dans le journal de validation de `docs/ASSUMPTIONS.md`.

Puis P4 (historique de consommation), P5 (recommandation sourcee), P6 (verification avant/apres), P7 (profils derives), P8 (disque), P9 (distribution). Noter que l'historique passe **avant** la recommandation : une recommandation sourcee par un pic sur 14 jours exige que l'historique existe.

**Retire de la roadmap, ne pas reproposer sans nouvelle decision** : spike Terminal.Gui (annule, ADR 0007), `-Reclaim` via `Optimize-VHD` (casse sur VHD sparse, ADR 0010), import/export de profils, `-Snapshot`. Reporte avec motif : auto-switch (ADR 0011), hooks, profils d'equipe.

## Etat de l'audit qualite

`docs/AUDIT.md` documente deux campagnes : l'audit initial v2.0 (15 findings, tous corriges) et l'audit general v2.3 (21 constats, tous traites). Les findings N-1 et N-2 y sont desormais marques corriges et reverifies -- l'ancien ecart doc/code est resolu.

**Defauts connus, non encore corriges, planifies en v2.5** -- ne pas les traiter comme des bugs a signaler, ils sont deja documentes :

- `Get-Process -Name "vmmem"` ne trouve rien sur Windows 11 recent (`VmmemWSL`), ce qui rend toute la couche d'observation silencieusement inoperante.
- Le seuil d'alerte compare la part de WSL2 dans la RAM **totale** a 80 %, alors que le plafond livre le plus large est de 6 Go : l'alerte ne peut pas se declencher.
- `ramDeltaGB` mesure l'arret de la session precedente mais est attribue au profil cible.
- `ConvertTo-WslConfigContent` reecrit `.wslconfig` en entier et efface les cles non gerees ; `Test-WslConfigIntegrity` ne verifie que les cles que Wisely vient d'ecrire, donc ne peut pas detecter la perte.
- `Get-ActiveProfile` identifie le profil actif par egalite de valeur memoire : deux profils de 4 Go sont indiscernables.

En cas de divergence entre un document et le code, **le code est la source de verite** : signale l'ecart plutot que de corriger silencieusement le document.

## Rigueur de diagnostic

Une anomalie signalee comme "probablement un probleme d'environnement/sandbox" n'est **pas** une conclusion tant qu'elle n'a pas ete activement verifiee : isole le diff en cause, lis la documentation officielle ou la source primaire pertinente, reproduis le comportement de facon deterministe. Ce n'est qu'apres cette verification que l'hypothese "environnement" peut etre acceptee -- et si elle est refutee, corrige le code qui a le bug, ne contourne pas le test qui l'a revele (pas de skip, pas de note de "limitation connue" en remplacement d'un vrai correctif).

Exemple concret (session du 2026-08-26, `wisely-site`) : un test e2e sur `og:image` echouait, d'abord attribue a "un probleme d'environnement/sandbox preexistant". La lecture de la documentation officielle Next.js sur la fusion des `Metadata` par segment de route a revele la cause reelle -- une fusion *shallow* qui ecrase un `openGraph.images` genere par convention de fichier des qu'un segment enfant redefinit `openGraph` sans `images`. Correctif : un helper `openGraphImages()` partage, spreade dans chaque `openGraph`. Le pattern a retenir : hypothese initiale commode ("c'est l'environnement") -> verification par doc officielle -> cause reelle dans le code -> vrai correctif.

## Workflow git

- `git pull --rebase` en cas de divergence.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, etc.), souvent avec référence de PR.
- Commits signés/vérifiés GPG (WSL2 et Windows) — ne jamais désactiver la signature.

## Stack et environnement

PowerShell 5.1 + 7 (chemins `$PROFILE` distincts : `Documents\WindowsPowerShell\` pour 5.1 vs `Documents\PowerShell\` pour 7 ; l'alias `wisely` est résolu via un symlink des fichiers de profil entre les deux versions — contournement en place, résolution long terme différée en v2.2). WSL2/Ubuntu, VS Code, GitHub CLI, Docker Desktop, conda/miniforge, pyenv, nvm, pnpm. Terminal : Oh My Posh (thème Tokyo Night), Cascadia Code NF, eza, bat, fd-find, ripgrep, btop, lazygit, zoxide, fzf. Tests : Pester (en CI depuis v2.1, couvre ProfileManager, Logger, Monitor, MonitorTask, WeeklyReport, Schema), PSScriptAnalyzer, CodeQL et Semgrep en CI.
