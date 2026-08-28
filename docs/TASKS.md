# Tasks

> Ordre de priorite et motifs : `ROADMAP.md`. Decisions de retrait : `decisions/`.

## Active

P0 / v2.5 "Verite" et P1 / v2.6 "Contrat" sont termines (voir Done ci-dessous).
Prochain palier : P2 / v3.0 "Diagnostic" (`ROADMAP.md`). Pas encore decoupe en
taches unitaires ici.

## Experiences a mener (hors code)

Cout quasi nul, fort pouvoir de refutation. Seuils de succes et resultats :
**journal de validation** de `ASSUMPTIONS.md` -- un seuil fixe apres coup ne
refute rien.

- [ ] **E1 - lire `data/history.json`** (10 min) : combien de switchs reels depuis la mise en service ? Teste A5
- [ ] **E2 - activer `autoMemoryReclaim=gradual` une semaine** : le besoin de baisser le plafond diminue-t-il ? Teste A2
- [ ] **E3 - publier `wisely diagnose` seul** (palier P3, bloquant) : quelqu'un l'utilise-t-il ? Teste A1 et A9
- [ ] **E4 - temps pour identifier la cause** : Gestionnaire des taches seul vs htop seul vs Wisely. Teste A9 et A10
- [ ] **E5 - sortie brute vs sortie sourcee** : laquelle declenche l'action ? Teste A11

## Annule

- [x] ~~**Spike Terminal.Gui (experimental)**~~ - **annule** le 2026-08-26, pas reporte. Aucun probleme utilisateur adosse, justifie par un document lui-meme perime, ne s'exprime pas comme une operation sur l'ecart. Voir `decisions/0007-annulation-spike-terminal-gui.md`
- [x] ~~**`wisely -Reclaim` via `Optimize-VHD`**~~ - **retire** : `Optimize-VHD` echoue sur les VHD sparse. L'axe disque est repris autrement en v3.3. Voir `decisions/0010-retrait-reclaim-optimize-vhd.md`

## Someday

- [ ] **Upgrade RAM 32GB (2x8GB DDR4-2666 SO-DIMM)** - materiel, a l'etude. Note : rendra les trois profils absolus livres denues de sens, ce que v3.1 corrige a la racine
- [ ] **Extension SSD** - slot M.2 confirme libre, a l'etude
- [ ] **Resynchroniser le depot `wisely-site`** - son changelog (`src/content/changelog.ts`) s'arrete a l'entree v2.0.0 alors que Wisely est a v2.4.0/P0-v2.5 (verifie le 2026-08-27 ; aucune mention residuelle de `wsl-switch` trouvee, deja nettoyee). Prerequis de v4.0, passe dediee

## Done

- [x] ~~P1 / v2.6 "Contrat" - premiere lecture in-distro sous consentement explicite~~ (2026-08-28 - nouveau `modules/GuestReader.ps1` : liste fermee de six commandes invite (`MemInfo`, `LoadAvg`, `Uptime`, `DiskRoot`, `Nproc`, `ProcRss`), identique a `DOCTRINE-LECTURE.md`/`RESOURCE-MODEL.md` et verifiee par un test de derive doc/code ; consentement `settings.guestReadConsent` a trois etats (`unset`/`granted`/`revoked`), desactive par defaut, pilotable via `wisely -Consent grant|revoke|status`, journalise dans l'historique ; degradation propre (jamais de `$null` silencieux) pour cle hors liste, consentement refuse, ou distribution absente/non demarree ; `wisely -GuestInfo` distingue `MemAvailableGB` de `CachedGB`. Correctif incident : `Write-SwitchLog` (`Logger.ps1`) collabait un historique a une seule entree en objet JSON nu au lieu d'un tableau (`-AsArray` ajoute). Detail complet : `CHANGELOG.md`)
- [x] ~~P0 / v2.5 "Verite" - corriger les mesures fausses avant toute nouvelle fonctionnalite~~ (2026-08-27 - cinq correctifs : detection `VmmemWSL` en plus de `vmmem` ; seuil d'alerte rapporte au plafond `.wslconfig` plutot qu'a la RAM totale (`Get-CimInstance` retire de `MonitorTask.ps1`) ; `ramDeltaGB` retire (mesure non attribuable, pas corrige - le vrai remplacement est planifie P6) ; identite du profil actif marquee dans une section `[wisely]` de `.wslconfig` plutot que devinee par egalite de memoire ; ecriture de `.wslconfig` non destructive via `Set-IniSectionKeys`, qui fusionne les cles gerees sans toucher aux cles et sections non gerees (autoMemoryReclaim, sparseVhd, `[experimental]`, etc.) - debloque la situation S5 et les contextes Docker Desktop et poste d'entreprise. Chaque correctif developpe en TDD, une PR par correctif. Detail complet : `CHANGELOG.md`)
- [x] ~~Injection possible via la cle d'un profil dans `.wslconfig`~~ (2026-08-27 - trouve en revue de code post-fusion de P0/v2.5 : `Test-ProfileDefinition` validait tous les champs interpoles dans `.wslconfig` sauf la cle du profil elle-meme, ecrite telle quelle depuis les deux derniers correctifs P0/v2.5. Rejette desormais toute cle contenant `\r`/`\n`. Voir `AUDIT.md` v2.5-C-1, `CHANGELOG.md`)

- [x] ~~Adoption de l'audit strategique externe d'aout 2026~~ (2026-08-27 - audit archive integralement dans `docs/audits/` avec son README ; ADR 0013 ; VISION reecrit autour des quatre objets Etat/Cause/Politique/Action et d'une boucle ou "expliquer" est un maillon nomme ; `RESOURCE-MODEL.md` et `USE-CASES.md` crees ; PRINCIPLES 1 et 9 revises, 13 et 14 ajoutes ; PROBLEM enonce cote utilisateur ; ROADMAP en paliers validables avec barriere de validation bloquante ; A9/A10/A11 et journal de validation. Aucun changement de code de production)
- [x] ~~Refondation documentaire (phase 10)~~ (v2.4 - PROBLEM/VISION/PRINCIPLES/DOCTRINE-LECTURE/ASSUMPTIONS + 12 ADR dans `decisions/` ; ROADMAP reduit a son seul metier ; guide TUIStudio et `wisely.md` supprimes, expose technologique archive)
- [x] ~~Tests Pester sur le schéma des `settings` de `profiles.json`~~ (voir AUDIT.md v2.3 T-11 — nouveau Describe "profiles.schema.json - settings" dans `tests/Schema.Tests.ps1` : 12 cas couvrant absence/presence partielle/vide de `settings`, bornes `exclusiveMinimum`/`maximum`, types invalides et propriete inconnue, chaque cas revalide manuellement via `Test-Json` faute d'acces a PSGallery dans le sandbox)
- [x] ~~Revalider/nettoyer les exclusions PSScriptAnalyzer~~ (voir AUDIT.md v2.3 T-7 — `PSAvoidUsingCmdletAliases` et `PSUseApprovedVerbs` retirées de `ci.yml` : aucun alias detecte via parsing AST, et les fonctions citees dans le commentaire (`Fit-String`/`Make-BoxLine`) n'existent plus, remplacees par `Format-String`/`New-BoxLine` avec verbes approuves ; les 6 autres exclusions revalidees comme toujours necessaires)
- [x] ~~Test `Get-VmmemStats` : sortie anticipée en cours d'échantillonnage~~ (voir AUDIT.md v2.3 T-5 — nouveau test Pester dans `tests/Monitor.Tests.ps1` couvrant la disparition de `vmmem` entre les deux échantillons, distinct du cas déjà couvert d'absence totale de `vmmem`)
- [x] ~~Schéma formalisé pour `history.json`~~ (voir AUDIT.md v2.3 T-4 — `schemas/history.schema.json`, valide via Pester sur des entrées réelles produites par `Write-SwitchLog`, corrige au passage `user` non cross-platform sur `$env:USERNAME`)
- [x] ~~Épingler les Actions GitHub par SHA~~ (voir AUDIT.md v2.3 T-9 — remonte comme vrai constat par le premier scan Semgrep en CI : `actions/checkout`, `github/codeql-action/init`, `github/codeql-action/analyze` dans les 5 workflows)
- [x] ~~Corriger l'injection de commande via interpolation `github.event.inputs.*`/`github.ref_name` non protegee dans des blocs `run:`~~ (`bump-version.yml`, `release.yml` — deplace en `env:`, autre constat reel remonte par le premier scan Semgrep)
- [x] ~~Ajouter Semgrep aux checks CI~~ (`.github/workflows/semgrep.yml` — `p/secrets`, `p/github-actions`, `p/security-audit`, sur push/PR + planifie chaque semaine, aucun compte/token requis)
- [x] ~~Audit général (whole-repo) v2.3~~ (v2.3 - AUDIT.md, 15 constats corrigés, 5 reportés au backlog, 1 signalé comme décision utilisateur)
- [x] ~~`wisely -Watch` (dashboard temps réel)~~ (v2.3 - RAM/CPU vmmem, profil actif, derniere alerte, `Get-WatchSnapshot`/`Get-VmmemStats` dans `Monitor.ps1`)
- [x] ~~Enrichir les rapports hebdomadaires avec la RAM moyenne par profil~~ (v2.3 - section "RAM liberee/consommee en moyenne au switch" dans `WeeklyReport.ps1`, basee sur `ramDeltaGB`)
- [x] ~~Métriques réelles post-switch (RAM delta, temps de redémarrage WSL2)~~ (v2.3 - `Get-AvailableRamGB`, `Write-SwitchLog -RamDeltaGB/-RestartSeconds`)
- [x] ~~Tests Pester pour Monitor.ps1, MonitorTask.ps1, WeeklyReport.ps1~~ (v2.3, prerequis avant metriques/-Watch)
- [x] ~~Verifier/clore le finding N-2 d'AUDIT.md~~ (v2.3 - deja corrige dans le code, statut du doc mis a jour)
- [x] ~~CONTRIBUTING.md~~ (v2.2)
- [x] ~~Templates issue/PR~~ (v2.2)
- [x] ~~JSON Schema pour profiles.json~~ (v2.2)
- [x] ~~Support des variables d'environnement dans `swapFile`~~ (`%TEMP%`, `%USERPROFILE%`, `%LOCALAPPDATA%`) (v2.2, reporté de v2.1)
- [x] ~~Commande `wisely -Status -Short` (intégration prompt)~~ (v2.2, reporté de v2.1 en tant que `wisely status`)
- [x] ~~Commande `wisely -Snapshot` (capture du profil courant)~~ (v2.2)
- [x] ~~README : galerie de profils par stack + snippet Oh My Posh / Windows Terminal~~ (v2.2)
- [x] ~~Pester tests — Get-ProfileConfig et Import-Profiles (+ Logger, swap, backup, diff)~~ (v2.1)
- [x] ~~Validation du chemin du swap file~~ (v2.1)
- [x] ~~Backup versionné avec historique glissant (`backupHistoryMax`)~~ (v2.1)
- [x] ~~Flags -Verbose / -Quiet~~ (v2.1)
- [x] ~~Fix bug visuel de troncature de la barre RAM (`wisely -Status`)~~ (v2.1)
- [x] ~~Cache mémoïsé pour Get-ProfileConfig (`Clear-ProfileConfigCache`)~~ (v2.1)
- [x] ~~v2.1.0 taguée et publiée sur GitHub~~
- [x] ~~Skills Claude Code persistants vendorisés (task-observer, superpowers) dans Wisely et wisely-site~~
- [x] ~~v2.0.0 stable publiée sur GitHub, toutes les conclusions d'audit résolues~~
- [x] ~~Chronomètre de switch via [System.Diagnostics.Stopwatch]~~
- [x] ~~Dashboard `wisely -Status`~~
- [x] ~~Commits signés/vérifiés GPG (WSL2 + Windows)~~
- [x] ~~Dotfiles synchronisés sur repo privé~~
- [x] ~~Remote SSH configuré pour le repo wisely~~
- [x] ~~Bug d'alias PS7 résolu (symlink profils PS5.1/PS7)~~
- [x] ~~Corriger le badge LICENSE (MIT → GPL v3) dans le README~~
- [x] ~~Check admin dans `Stop-WslMonitor`~~
- [x] ~~Afficher le temps de switch mesuré~~
