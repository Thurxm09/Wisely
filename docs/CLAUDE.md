# Memory

## Me

Thuram (GitHub: Thurxm09), développeur solo — niveau débutant/intermédiaire en PowerShell, mais code produit de niveau pro. Machine : HP All-in-One (i5, 16GB RAM, 512GB NVMe), Windows 11 Pro, WSL2/Ubuntu. Les 16GB sont une vraie contrainte (WSL2 + VS Code + navigateur en simultané) — c'est la raison d'être du projet.

## Projet principal

| Nom | Quoi |
|-----|------|
| **Wisely** | Outil CLI PowerShell qui relie ce que WSL2 consomme a ce qu'on l'autorise a consommer, sur Windows. v2.1 (tests Pester, validation swap, backup versionne, cache memoise, flags -Verbose/-Quiet), v2.2 (CONTRIBUTING + templates, variables d'environnement dans `swapFile`, JSON Schema, `-Status -Short`, `-Snapshot`), v2.3 (observabilite : metriques post-switch, rapports enrichis, `-Watch`, Semgrep en CI) et v2.4 (garde-fou WSL2 avant shutdown + refondation documentaire, spike Terminal.Gui annule) livrees. Direction produit revue le 2026-08-26 : voir `docs/VISION.md`. |

## Termes

| Terme | Signification |
|------|---------|
| **L'ecart** | Concept central du produit : distance entre ce que WSL2 consomme et ce qu'on l'autorise a consommer (`docs/VISION.md`) |
| `.wslconfig` | Config WSL2, chemin `C:\Users\othur\.wslconfig` -- fichier PARTAGE, slashs pour les chemins de swap |
| `vmmem` / `VmmemWSL` | Deux noms selon la version de Windows ; le code ne cherche que `vmmem` (corrige en v2.5) |
| `wisely -Status` | Dashboard integre : barre RAM, profil actif, 3 derniers historiques |
| `Get-ProfileConfig` / `Import-Profiles` | Fonctions ciblees en priorite par les tests Pester |
| Docs de fond | `PROBLEM` (le probleme), `VISION` (la capacite), `PRINCIPLES` (les arbitrages), `DOCTRINE-LECTURE` (le contrat de lecture), `ASSUMPTIONS` (l'incertitude), `ROADMAP` (l'ordre), `decisions/` (les ADR) |

## Repos

- `git@github.com:Thurxm09/Wisely.git`
- `git@github.com:Thurxm09/dotfiles.git` (privé)

## Préférences & principes techniques

- Toujours réécrire les fichiers `.ps1` en entier plutôt que patcher (regex incrémental = bugs récurrents)
- ASCII pur obligatoire pour tout `.ps1` (Unicode → `[char]0xXXXX`)
- `([string]$char * $n)` pour la répétition de caractères
- `throw`, jamais `exit`, dans les modules dot-sourcés
- `git pull --rebase` en cas de divergence
- Scope `$script:` préféré à `$Global:` pour la mémoïsation
- Ordre de priorite (refonte du 2026-08-26, voir `docs/ROADMAP.md`) : v2.4 clot -- **prochaine priorite : v2.5 "Verite"** (corriger les mesures fausses avant toute nouvelle feature), puis v2.6 "Contrat" (doctrine de lecture in-distro), puis v3.0 "L'ecart". Regle d'ordonnancement : on ne construit ni diagnostic ni recommandation sur une mesure qui ment
- Aime comprendre le code en profondeur, pas juste livrer des features
- Préfère avancer une feature à la fois, bien comprise, avant de passer à la suivante
- Utilise des scripts bootstrap Python (ASCII-safe, réécriture complète, sortie `[OK]`/`[SKIP]`) comme mécanisme standard de livraison de fichiers générés

## Stack

PowerShell 5.1 + 7, WSL2/Ubuntu, VS Code, GitHub CLI, Docker Desktop, conda/miniforge, pyenv, nvm, pnpm. Terminal : Oh My Posh (Tokyo Night), Cascadia Code NF, eza, bat, fd-find, ripgrep, btop, lazygit, zoxide, fzf. Tests : Pester (CI, en place depuis v2.1), PSScriptAnalyzer (CI, en place).
