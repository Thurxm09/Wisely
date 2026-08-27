# Memory

## Me

Thuram (GitHub: Thurxm09), développeur solo — niveau débutant/intermédiaire en PowerShell, mais code produit de niveau pro. Machine : HP All-in-One (i5, 16GB RAM, 512GB NVMe), Windows 11 Pro, WSL2/Ubuntu. Les 16GB sont une vraie contrainte (WSL2 + VS Code + navigateur en simultané) — c'est la raison d'être du projet.

## Projet principal

| Nom | Quoi |
|-----|------|
| **Wisely** | Outil CLI PowerShell qui transforme l'etat reel des ressources WSL2 en decisions explicables et en actions sures, sur Windows. v2.1 (tests Pester, validation swap, backup versionne, cache memoise, flags -Verbose/-Quiet), v2.2 (CONTRIBUTING + templates, variables d'environnement dans `swapFile`, JSON Schema, `-Status -Short`, `-Snapshot`), v2.3 (observabilite : metriques post-switch, rapports enrichis, `-Watch`, Semgrep en CI) et v2.4 (garde-fou WSL2 avant shutdown + refondation documentaire, spike Terminal.Gui annule) livrees. Direction produit revue le 2026-08-26, puis **revisee le 2026-08-27** apres adoption d'un audit strategique externe : voir `docs/VISION.md` et `docs/decisions/0013-adoption-audit-strategique-externe.md`. |

## Termes

| Terme | Signification |
|------|---------|
| **Les quatre objets** | Le vocabulaire du produit : Etat, Cause, Politique, Action (`docs/VISION.md`) |
| **La boucle** | observer -> **expliquer** -> recommander -> agir -> verifier. "Expliquer" est un maillon nomme, pas un sous-produit |
| **L'ecart** | Relation entre l'Etat observe et la Politique de ressources. **Requalifie le 2026-08-27** : modele interne des ressources a plafond configurable, plus l'ontologie du produit -- il ne dit rien du cache ni du disque, et masque que 8 Go consommes ne sont pas 8 Go necessaires |
| **Classe de mesure** | directe / attribuee / estimee / correlee. La somme des RSS n'est jamais la RAM consommee ; il n'y a pas d'ecart CPU (`docs/RESOURCE-MODEL.md`) |
| `.wslconfig` | Config WSL2, chemin `C:\Users\othur\.wslconfig` -- fichier PARTAGE, slashs pour les chemins de swap |
| `vmmem` / `VmmemWSL` | Deux noms selon la version de Windows ; le code cherchait auparavant seulement `vmmem`, corrige en P0/v2.5 -- `Get-Process -Name "VmmemWSL", "vmmem"` desormais |
| `wisely -Status` | Dashboard integre : barre RAM, profil actif, 3 derniers historiques |
| `wisely diagnose` | La commande d'entree du produit, planifiee au palier P2. Anciennement `wisely doctor`, renommee avant ecriture |
| `Get-ProfileConfig` / `Import-Profiles` | Fonctions ciblees en priorite par les tests Pester |
| Docs de fond | `PROBLEM` (le probleme), `VISION` (la capacite), `USE-CASES` (les situations), `PRINCIPLES` (les arbitrages), `DOCTRINE-LECTURE` (le contrat de lecture), `RESOURCE-MODEL` (ce que signifient les chiffres), `ASSUMPTIONS` (l'incertitude + journal de validation), `ROADMAP` (l'ordre), `decisions/` (les ADR), `audits/` (audits strategiques externes -- ne font pas foi) |

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
- Ordre de priorite (revise le 2026-08-27, voir `docs/ROADMAP.md`) : **P0 / v2.5 "Verite" livree** (les cinq correctifs de mesures fausses, une PR par correctif) -- **prochaine priorite : P1 / v2.6 "Contrat"** (lecture in-distro), puis P2 / v3.0 "Diagnostic" (`wisely diagnose`), puis **P3, barriere de validation bloquante**. Deux regles d'ordonnancement : on ne construit ni diagnostic ni recommandation sur une mesure qui ment ; et on ne construit pas au-dela d'une capacite qu'on n'a pas confrontee a un utilisateur
- Aime comprendre le code en profondeur, pas juste livrer des features
- Préfère avancer une feature à la fois, bien comprise, avant de passer à la suivante
- Utilise des scripts bootstrap Python (ASCII-safe, réécriture complète, sortie `[OK]`/`[SKIP]`) comme mécanisme standard de livraison de fichiers générés

## Stack

PowerShell 5.1 + 7, WSL2/Ubuntu, VS Code, GitHub CLI, Docker Desktop, conda/miniforge, pyenv, nvm, pnpm. Terminal : Oh My Posh (Tokyo Night), Cascadia Code NF, eza, bat, fd-find, ripgrep, btop, lazygit, zoxide, fzf. Tests : Pester (CI, en place depuis v2.1), PSScriptAnalyzer (CI, en place).
