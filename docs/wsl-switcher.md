# WSL Switcher

**Statut :** v2.0.0 stable publiée (GitHub), v2.1 en développement actif.

**Description :** Outil CLI PowerShell qui gère dynamiquement les profils de ressources WSL2 (RAM, CPU) sur Windows, avec monitoring et reporting. Né d'une contrainte matérielle réelle (16GB RAM, workloads WSL2 + VS Code + navigateur en simultané).

**Repo :** `git@github.com:Thurxm09/wsl-switch.git`

## Déjà livré (v2.0 → début v2.1)

- Chronomètre de switch (`[System.Diagnostics.Stopwatch]`)
- Dashboard `wsl-switch -Status` (barre RAM, profil actif, historique)
- Commits GPG signés/vérifiés (WSL2 + Windows)
- Dotfiles synchronisés (Oh My Posh Tokyo Night, config partagée PS5.1/PS7/Zsh)
- Bug d'alias PS7 résolu par symlink des fichiers de profil

## Priorités v2.1 (ordre voulu par Thuram)

1. Tests Pester — `Get-ProfileConfig`, `Import-Profiles` (dette technique n°1)
2. Validation du chemin du swap file
3. Backup versionné avec historique glissant
4. Flags `-Verbose` / `-Quiet`
5. Fix troncature visuelle de la barre RAM
6. Cache mémoïsé (`$script:`, invalidation via `Clear-ProfileConfigCache`)

## Reporté en v2.2

CONTRIBUTING.md, templates issue/PR, résolution long terme de l'alias PS7, JSON Schema pour `profiles.json`.

## Vision long terme (voir ROADMAP.md)

Trois paliers de maturité : (1) outil personnel de référence — situation actuelle ; (2) outil open-source distribué (Winget / PowerShell Gallery, suite de tests, v3.x) ; (3) outil de référence de l'écosystème WSL avec hooks et intégrations (v4.x+).
