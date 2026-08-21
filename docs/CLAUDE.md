# Memory

## Me

Thuram (GitHub: Thurxm09), développeur solo — niveau débutant/intermédiaire en PowerShell, mais code produit de niveau pro. Machine : HP All-in-One (i5, 16GB RAM, 512GB NVMe), Windows 11 Pro, WSL2/Ubuntu. Les 16GB sont une vraie contrainte (WSL2 + VS Code + navigateur en simultané) — c'est la raison d'être du projet.

## Projet principal

| Nom | Quoi |
|-----|------|
| **Wisely** | Outil CLI PowerShell pour gérer dynamiquement des profils de ressources WSL2 (RAM, CPU, monitoring, reporting). Passé d'un script basique à un outil modulaire pro. v2.1.0 (tests Pester, validation swap, backup versionné, cache mémoïsé, flags -Verbose/-Quiet, fix barre RAM) et v2.2 (CONTRIBUTING.md + templates, variables d'environnement dans `swapFile`, intégrité des réglages, JSON Schema `profiles.json`, `wisely -Status -Short`, `wisely -Snapshot`, galerie README + snippet Oh My Posh) livrées ; v2.3 (observabilité) cadrée : tests Pester Monitor/MonitorTask/WeeklyReport, métriques post-switch, rapports enrichis, `wisely -Watch`, audit rafraîchi — évaluation Terminal.Gui volontairement hors scope. |

## Termes

| Terme | Signification |
|------|---------|
| `.wslconfig` | Fichier de config WSL2, chemin `C:\Users\othur\.wslconfig` — les chemins de swap doivent utiliser des slashs (`C:/Temp/wsl-swap.vhdx`) |
| `wisely -Status` | Dashboard intégré : barre RAM, profil actif, 3 derniers historiques |
| `Get-ProfileConfig` / `Import-Profiles` | Fonctions ciblées en priorité par les tests Pester |
| AUDIT.md / ROADMAP.md | Docs de suivi d'état et de vision stratégique du projet |

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
- Priorité tests Pester avant tout chantier structurel : atteinte en v2.1 (suite Pester en CI) — DX & documentation livrée en v2.2 — prochaine priorité : observabilité (v2.3)
- Aime comprendre le code en profondeur, pas juste livrer des features
- Préfère avancer une feature à la fois, bien comprise, avant de passer à la suivante
- Utilise des scripts bootstrap Python (ASCII-safe, réécriture complète, sortie `[OK]`/`[SKIP]`) comme mécanisme standard de livraison de fichiers générés

## Stack

PowerShell 5.1 + 7, WSL2/Ubuntu, VS Code, GitHub CLI, Docker Desktop, conda/miniforge, pyenv, nvm, pnpm. Terminal : Oh My Posh (Tokyo Night), Cascadia Code NF, eza, bat, fd-find, ripgrep, btop, lazygit, zoxide, fzf. Tests : Pester (CI, en place depuis v2.1), PSScriptAnalyzer (CI, en place).
