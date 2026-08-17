# Tasks

## Active

- [ ] **Pester tests — Get-ProfileConfig et Import-Profiles** - dette technique prioritaire avant tout autre chantier structurel (v2.1)
- [ ] **Validation du chemin du swap file** - v2.1
- [ ] **Backup versionné avec historique glissant** - v2.1
- [ ] **Flags -Verbose / -Quiet** - v2.1
- [ ] **Fix bug visuel de troncature de la barre RAM** - `wsl-switch -Status`, v2.1
- [ ] **Cache mémoïsé pour Get-ProfileConfig** - via variables `$script:`, invalidation par `Clear-ProfileConfigCache`, v2.1

## Waiting On

## Someday

- [ ] **CONTRIBUTING.md** - v2.2
- [ ] **Templates issue/PR** - v2.2
- [ ] **Résolution long terme de l'alias PS7** - v2.2 (contournement déjà en place via symlink des profils)
- [ ] **JSON Schema pour profiles.json** - v2.2
- [ ] **Upgrade RAM 32GB (2x8GB DDR4-2666 SO-DIMM)** - matériel, à l'étude
- [ ] **Extension SSD** - slot M.2 confirmé libre, à l'étude

## Done

- [x] ~~v2.0.0 stable publiée sur GitHub, toutes les conclusions d'audit résolues~~
- [x] ~~Chronomètre de switch via [System.Diagnostics.Stopwatch]~~
- [x] ~~Dashboard `wsl-switch -Status`~~
- [x] ~~Commits signés/vérifiés GPG (WSL2 + Windows)~~
- [x] ~~Dotfiles synchronisés sur repo privé~~
- [x] ~~Remote SSH configuré pour le repo wsl-switch~~
- [x] ~~Bug d'alias PS7 résolu (symlink profils PS5.1/PS7)~~
