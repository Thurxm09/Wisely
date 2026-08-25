# Contribuer à Wisely

Merci de vouloir contribuer. Ce document décrit l'environnement de dev, les conventions de code et le workflow de PR.

## Prérequis

- **Windows 10/11** avec WSL2 configuré (Wisely pilote `.wslconfig`, il ne fonctionne pas sous Linux/macOS)
- **PowerShell 5.1+** pour exécuter `wisely.ps1` (compatibilité runtime historique)
- **PowerShell 7+** recommandé pour le développement (nécessaire pour `Test-Json`, utilisé par la CI et `tests/Schema.Tests.ps1`)
- [Pester](https://pester.dev/) ≥ 5.5.0 et [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) pour les tests et le lint en local

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

## Setup

```powershell
git clone https://github.com/Thurxm09/Wisely.git
cd Wisely
```

Aucune étape de build : `wisely.ps1` et les modules dans `modules/` s'exécutent directement.

## Conventions de code

- **ASCII pur** dans tous les fichiers `.ps1` — pas de caractères Unicode directs (accents, guillemets typographiques, etc.). Utiliser `[char]0xXXXX` si un caractère spécifique est nécessaire.
- **Réécriture complète** des fichiers `.ps1` modifiés plutôt que des patchs incrémentaux ciblés — un patch regex partiel sur un fichier PowerShell est une source récurrente de bugs subtils.
- `throw`, jamais `exit`, dans les modules dot-sourcés (`modules/*.ps1`) — seul `wisely.ps1` (le point d'entrée) peut appeler `exit`.
- Scope `$script:` préféré à `$Global:` pour la mémoïsation interne aux modules ; `$Global:WSLRoot` reste le seul contrat global documenté entre modules.
- `([string]$char * $n)` pour la répétition de caractères plutôt que d'autres idiomes.
- Pas de nouvelle dépendance externe sans discussion préalable (issue) — Wisely vise à rester un outil autonome avec un minimum de modules tiers.

## Tests

Toute nouvelle fonction dans `modules/` doit être couverte par des tests Pester dans `tests/`.

```powershell
Import-Module Pester -MinimumVersion 5.5.0
Invoke-Pester -Path tests -Output Detailed
```

Conventions des tests existants (voir `tests/*.Tests.ps1`) :

- `BeforeAll` dot-source les modules une seule fois pour tout le fichier.
- Utiliser les helpers de `tests/TestHelpers.ps1` (`New-TestWslRoot`, `Set-TestUserProfile`, `New-TestProfilesJson`, `New-TestWslConfig`, `Enable-WslMocks`, etc.) plutôt que de recréer des fixtures ad hoc.
- Isoler chaque `Describe` avec son propre `BeforeEach`/`AfterEach` (nettoyage de répertoire temporaire, restauration de `$env:USERPROFILE`) — l'état partagé entre blocs (comme le cache de profils) doit être explicitement réinitialisé.
- Mocker les cmdlets Windows-only (`Get-CimInstance`, `wsl`, etc.) : elles n'existent pas sur le runner CI Linux, donc les stubber en fonctions no-op avant de les mocker si besoin.

## Validation avant de pousser

La CI (`.github/workflows/ci.yml`, runner `ubuntu-latest`) exécute à chaque push/PR :

1. Vérification de syntaxe PowerShell sur tous les `.ps1`
2. [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) (règles exclues documentées dans le workflow)
3. Suite Pester complète (`tests/`)
4. Validation de `data/profiles.json` contre `schemas/profiles.schema.json` (`Test-Json`)

En parallèle, deux analyses de sécurité tournent sur des workflows dédiés (push/PR + planifiées chaque semaine) :

- [CodeQL](https://codeql.github.com/) (`.github/workflows/codeql.yml`) — langage `actions`, analyse les workflows GitHub Actions eux-mêmes.
- [Semgrep](https://semgrep.dev/) (`.github/workflows/semgrep.yml`) — `--config=auto` (détecte automatiquement les rulesets pertinents selon les langages présents dans le dépôt, y compris les futurs ajouts hors PowerShell) + `p/secrets` et `p/github-actions` en complément explicite (rulesets ciblés qu'`auto` ne couvre pas forcément). Rulesets publics du registre Semgrep, aucun compte/token requis.

Reproduire ces vérifications en local avant de pousser évite des allers-retours CI inutiles.

## Note sur l'alias PowerShell 7

L'exécution de `wisely` comme commande globale sous PS7 est déjà résolue via un symlink documenté dans le README (voir section Installation) — ce n'est plus un sujet ouvert, pas besoin de proposer un nouveau mécanisme d'alias.

## Workflow de PR

1. Une branche par changement logique, un scope clair.
2. Commits atomiques avec des messages descriptifs.
3. Avant d'ouvrir la PR :
   - [ ] Les tests Pester passent en local (ou via CI)
   - [ ] PSScriptAnalyzer ne remonte aucun avertissement
   - [ ] Toute nouvelle fonction dans `modules/` a des tests associés
   - [ ] `data/profiles.json` reste valide contre le schéma si modifié
   - [ ] La documentation (README, `docs/`) est mise à jour si le comportement change
4. Décrire dans la PR ce qui change et pourquoi, pas seulement le quoi.
5. La CI doit être verte avant la revue.

## Signaler un bug ou proposer une fonctionnalité

Utiliser les templates d'issue disponibles à la création d'une nouvelle issue sur GitHub — ils indiquent les informations utiles à fournir (contexte, étapes de reproduction, comportement attendu).
