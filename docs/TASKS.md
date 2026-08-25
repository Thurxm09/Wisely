# Tasks

## Active

## Someday

- [ ] **Upgrade RAM 32GB (2x8GB DDR4-2666 SO-DIMM)** - matériel, à l'étude
- [ ] **Extension SSD** - slot M.2 confirmé libre, à l'étude
- [ ] **Test `Get-VmmemStats` : sortie anticipée en cours d'échantillonnage** (voir AUDIT.md v2.3 T-5)
- [ ] **Revalider/nettoyer les exclusions PSScriptAnalyzer** (voir AUDIT.md v2.3 T-7)
- [ ] **Tests Pester sur le schéma des `settings` de `profiles.json`** (voir AUDIT.md v2.3 T-11)

## Done

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
