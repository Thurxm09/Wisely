\# Audit de qualité — Wisely v2.0

&#x20;

> Document généré le 2026-03-27 suite à l'audit complet du repository.  

> Référence : audit initial réalisé avant le commit de refactorisation.

&#x20;

\---

&#x20;

\## Résumé exécutif

&#x20;

L'audit initial a identifié \*\*15 problèmes\*\* répartis sur trois niveaux de priorité.  

Après revue du code actuel, \*\*15 sur 15 ont été corrigés\*\*.  

Deux nouvelles incohérences mineures ont été détectées lors de cette revue de suivi — depuis corrigées et reverifiees (voir N-1/N-2 plus bas et le recapitulatif final).

&#x20;

| Priorité | Initial | Corrigé | Restant |

|----------|---------|---------|---------|

| 🔴 Critique | 5 | 5 | 0 |

| 🟠 Important | 6 | 6 | 0 |

| 🟡 Secondaire | 4 | 4 | 0 |

| 🆕 Nouveau | 2 | 2 | 0 |

| \*\*Total\*\* | \*\*17\*\* | \*\*17\*\* | \*\*0\*\* |

&#x20;

\---

&#x20;

\## Détail par finding

&#x20;

\### 🔴 Critique

&#x20;

\---

&#x20;

\#### C-1 — `exit` dans des fichiers dot-sourcés

&#x20;

\*\*Fichier :\*\* `modules/ProfileManager.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* Les fonctions `Get-ProfileConfig` et autres appelaient `exit 1` directement. Comme ces modules sont dot-sourcés dans le scope du script principal, un `exit` ne termine pas le script — il ferme la \*\*session PowerShell entière de l'utilisateur\*\*. Un `profiles.json` corrompu pouvait donc fermer tous les terminaux ouverts sans avertissement.

&#x20;

\*\*Correction appliquée :\*\* Tous les `exit` dans les modules ont été remplacés par des `throw`. Le script principal `wisely.ps1` attrape ces exceptions avec `try/catch` et appelle `exit 1` en lieu et place — ce qui est correct puisqu'on est dans le script racine, pas dans un module dot-sourcé.

&#x20;

```powershell

\# Avant (dangereux)

function Get-ProfileConfig {

&#x20;   if (-not (Test-Path $path)) {

&#x20;       Write-Host "  ERREUR : profiles.json introuvable." -ForegroundColor Red

&#x20;       exit 1  # Fermait la session PowerShell de l'utilisateur

&#x20;   }

}

&#x20;

\# Après (robuste)

function Get-ProfileConfig {

&#x20;   if (-not (Test-Path $path)) {

&#x20;       throw "profiles.json introuvable. Chemin attendu : $path"

&#x20;   }

}

```

&#x20;

\---

&#x20;

\#### C-2 — Rapport hebdomadaire automatique non implémenté

&#x20;

\*\*Fichier :\*\* `modules/Monitor.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* Le README affirmait qu'un rapport était généré automatiquement chaque lundi à 09h00 via le Planificateur de tâches, mais `Start-WslMonitor` n'enregistrait qu'une seule tâche (le monitoring RAM). La feature était documentée mais pas implémentée.

&#x20;

\*\*Correction appliquée :\*\* `Start-WslMonitor` enregistre désormais une deuxième tâche planifiée (`WSL2-WeeklyReport`) avec un trigger hebdomadaire (`-Weekly -DaysOfWeek Monday -At "09:00"`). `Stop-WslMonitor` la désinscrit également. Les deux noms de tâches sont déclarés en constantes de scope script.

&#x20;

```powershell

\# Tâche rapport hebdomadaire (lundi 09h00)

$weeklyTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:00"

Register-ScheduledTask `

&#x20;   -TaskName $script:WEEKLY\_TASK\_NAME -Action $weeklyAction -Trigger $weeklyTrigger `

&#x20;   -Settings $weeklySettings -RunLevel Highest -Force | Out-Null

```

&#x20;

\---

&#x20;

\#### C-3 — Settings JSON ignorés par le monitoring

&#x20;

\*\*Fichier :\*\* `modules/Monitor.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* `data/profiles.json` exposait `monitorThreshold` et `monitorIntervalSeconds` comme paramètres de configuration, mais ces valeurs étaient ignorées. `Start-WslMonitor` utilisait des valeurs hardcodées (`80%`, `1 minute`), rendant ces settings complètement fantômes.

&#x20;

\*\*Correction appliquée :\*\* `Start-WslMonitor` lit maintenant ces valeurs depuis `profiles.json` via `Get-ProfileConfig`, avec fallback sur les valeurs par défaut en cas d'erreur de parsing. L'intervalle en secondes est converti en minutes pour le Task Scheduler avec un minimum d'1 minute.

&#x20;

```powershell

$config      = Get-ProfileConfig

$threshold   = if ($config.settings.monitorThreshold)      { \[int]$config.settings.monitorThreshold }      else { 80 }

$intervalSec = if ($config.settings.monitorIntervalSeconds) { \[int]$config.settings.monitorIntervalSeconds } else { 60 }

$intervalMin = \[math]::Max(1, \[math]::Ceiling($intervalSec / 60))

```

&#x20;

\---

&#x20;

\#### C-4 — Validation de schéma insuffisante dans `Import-Profiles`

&#x20;

\*\*Fichier :\*\* `modules/ProfileManager.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* `Import-Profiles` ne vérifiait que la validité syntaxique du JSON, pas son schéma. N'importe quel JSON valide (même `{"hello":"world"}`) passait la validation et remplaçait entièrement `profiles.json`, laissant l'outil dans un état cassé.

&#x20;

\*\*Correction appliquée :\*\* Trois garde-fous supplémentaires ont été ajoutés après le parsing : présence de la clé `profiles`, présence de la clé `version`, et nombre de profils supérieur à zéro.

&#x20;

```powershell

$imported = try { Get-Content $Path -Raw | ConvertFrom-Json } catch { throw "JSON invalide dans '$Path' : $\_" }

if ($null -eq $imported.profiles) { throw "Le fichier importe ne contient pas de cle 'profiles'." }

if ($null -eq $imported.version)  { throw "Le fichier importe ne contient pas de cle 'version'." }

if (@($imported.profiles.PSObject.Properties).Count -eq 0) { throw "Aucun profil defini dans le fichier importe." }

```

&#x20;

\---

&#x20;

\#### C-5 — Collision avec la variable automatique `$profile`

&#x20;

\*\*Fichier :\*\* `modules/ProfileManager.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* Dans `Set-WslProfile`, la variable locale `$profile = $prop.Value` écrasait silencieusement la variable automatique PowerShell `$profile` (qui pointe vers les scripts de profil utilisateur). Cela ne cassait pas l'exécution grâce au scoping, mais provoquait un avertissement PSScriptAnalyzer et une confusion de lecture garantie.

&#x20;

\*\*Correction appliquée :\*\* Renommée en `$profileDef` dans `Set-WslProfile` et `ConvertTo-WslConfigContent`. Le paramètre `Profile` de `Write-SwitchLog` a également été renommé en `ProfileKey` pour cohérence.

&#x20;

\---

&#x20;

\### 🟠 Important

&#x20;

\---

&#x20;

\#### I-1 — `$TASK\_NAME` polluait le scope global

&#x20;

\*\*Fichier :\*\* `modules/Monitor.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* `$TASK\_NAME = "WSL2-RamMonitor"` au niveau module était dot-sourcé dans le scope du script principal, devenant une variable globale de facto, écrasable accidentellement.

&#x20;

\*\*Correction appliquée :\*\* Les deux noms de tâche sont désormais déclarés en constantes de scope script avec `Set-Variable -Option Constant -Scope Script`, ce qui empêche toute réassignation accidentelle et les limite proprement au module.

&#x20;

```powershell

Set-Variable -Name TASK\_NAME        -Value "WSL2-RamMonitor"   -Option Constant -Scope Script

Set-Variable -Name WEEKLY\_TASK\_NAME -Value "WSL2-WeeklyReport"  -Option Constant -Scope Script

```

&#x20;

\---

&#x20;

\#### I-2 — `Get-WeeklyReport` dans Logger.ps1 était du code mort

&#x20;

\*\*Fichier :\*\* `modules/Logger.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* `Logger.ps1` contenait une fonction `Get-WeeklyReport` jamais appelée nulle part. La vraie génération de rapport était dans `WeeklyReport.ps1`. Ce doublon créait de la confusion pour tout nouveau contributeur.

&#x20;

\*\*Correction appliquée :\*\* La fonction orpheline a été supprimée de `Logger.ps1`. Le module ne contient plus que `Get-HistoryPath`, `Write-SwitchLog` et `Show-SwitchHistory`, qui correspondent exactement à sa responsabilité déclarée.

&#x20;

\---

&#x20;

\#### I-3 — Aucune vérification des droits administrateur pour le monitoring

&#x20;

\*\*Fichier :\*\* `modules/Monitor.ps1`  

\*\*Statut :\*\* ✅ Corrigé (partiellement — voir I-3b ci-dessous)

&#x20;

\*\*Problème initial :\*\* `Register-ScheduledTask -RunLevel Highest` nécessite des droits élevés. En terminal non-admin, la commande échouait avec une erreur Windows cryptique sans message explicatif.

&#x20;

\*\*Correction appliquée :\*\* `Start-WslMonitor` vérifie les droits en début de fonction et affiche un message d'erreur actionnable avant de retourner proprement.

&#x20;

```powershell

$isAdmin = (\[Security.Principal.WindowsPrincipal]\[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(

&#x20;   \[Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {

&#x20;   Write-Host "  ERREUR : Le demarrage du monitoring requiert des droits administrateur." -ForegroundColor Red

&#x20;   Write-Host "  Relancez PowerShell en tant qu'Administrateur." -ForegroundColor Gray

&#x20;   return

}

```

&#x20;

\---

&#x20;

\#### I-4 — Encodage ASCII pour les rapports français

&#x20;

\*\*Fichier :\*\* `modules/WeeklyReport.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* `Set-Content $reportPath -Encoding ASCII` mutilait tous les caractères accentués du contenu des rapports (généré en français).

&#x20;

\*\*Correction appliquée :\*\* Encodage passé à `UTF8` sur la ligne d'écriture du rapport.

&#x20;

\---

&#x20;

\#### I-5 — Parsing de `-NewProfile` non sécurisé

&#x20;

\*\*Fichier :\*\* `wisely.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* La clé de profil n'était soumise à aucune validation de format. Une clé avec des espaces, des caractères spéciaux ou commençant par un chiffre était acceptée et pouvait provoquer des comportements inattendus dans le JSON ou lors des lookups.

&#x20;

\*\*Correction appliquée :\*\* Un guard regex est appliqué avant l'appel à `New-CustomProfile` :

&#x20;

```powershell

if ($parts\[0] -notmatch "^\[a-zA-Z]\[a-zA-Z0-9\_-]\*$") {

&#x20;   Write-Host "  ERREUR : La cle de profil doit etre un identifiant alphanumerique (ex: gaming, ml-heavy)." -ForegroundColor Red

&#x20;   exit 1

}

```

&#x20;

\---

&#x20;

\#### I-6 — PSScriptAnalyzer configuré trop permissif en CI

&#x20;

\*\*Fichier :\*\* `.github/workflows/ci.yml`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* PSScriptAnalyzer était lancé uniquement sur les erreurs (`-Severity Error`), laissant passer les avertissements couvrant des cas importants (collision `$profile`, variables non utilisées, etc.).

&#x20;

\*\*Correction appliquée :\*\* Passage à `-Severity Warning` avec une liste d'exclusions explicites et \*\*commentées\*\* pour les règles délibérément acceptées dans ce projet. Chaque exclusion est justifiée en ligne, ce qui est essentiel pour un projet open-source où d'autres développeurs peuvent contribuer.

&#x20;

```powershell

$excludeRules = @(

&#x20;   'PSAvoidUsingCmdletAliases',       # short aliases intentional in non-library scripts

&#x20;   'PSAvoidUsingWriteHost',           # Write-Host intentional for interactive terminal UI

&#x20;   'PSAvoidGlobalVars',               # $Global:WSLRoot is the documented cross-module contract

&#x20;   # ...

)

$results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning -ExcludeRule $excludeRules

```

&#x20;

\---

&#x20;

\### 🟡 Secondaire

&#x20;

\---

&#x20;

\#### S-1 — Lecture disque à chaque frame du menu interactif

&#x20;

\*\*Fichier :\*\* `wisely.ps1`, `modules/ProfileManager.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* La boucle interactive rafraîchissait l'affichage à chaque keystroke via `Show-Header` → `Get-ActiveProfile` → `Get-ProfileConfig` → lecture disque. Inutile puisque le profil actif ne change que lors d'un switch effectif.

&#x20;

\*\*Correction appliquée :\*\* `Get-ActiveProfile` accepte désormais un paramètre optionnel `$Config`. Dans `Show-InteractiveMenu`, `Get-ProfileConfig` est appelé une seule fois en entrée de fonction et la config est transmise à `Get-ActiveProfile -Config $config`, évitant toute relecture disque dans la boucle.

&#x20;

```powershell

function Show-InteractiveMenu {

&#x20;   $config = Get-ProfileConfig          # Une seule lecture disque

&#x20;   $active = Get-ActiveProfile -Config $config   # Config réutilisée

&#x20;   # ...boucle sans I/O inutile

}

```

&#x20;

\---

&#x20;

\#### S-2 — Limite CPU arbitraire à 8 cœurs

&#x20;

\*\*Fichier :\*\* `modules/ProfileManager.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* La validation `$Processors -gt 8` rejetait des configurations parfaitement valides sur des machines Ryzen 9, Threadripper ou workstations multi-cœurs.

&#x20;

\*\*Correction appliquée :\*\* La borne supérieure est maintenant lue dynamiquement depuis WMI, ce qui la rend universelle et auto-documentée dans le message d'erreur.

&#x20;

```powershell

$maxCpu = (Get-CimInstance Win32\_ComputerSystem).NumberOfLogicalProcessors

if ($Processors -lt 1 -or $Processors -gt $maxCpu) {

&#x20;   throw "Nombre de CPU invalide : $Processors. Attendu : entre 1 et $maxCpu (processeurs logiques disponibles)."

}

```

&#x20;

\---

&#x20;

\#### S-3 — `$MyInvocation` au lieu de `$PSScriptRoot` dans MonitorTask

&#x20;

\*\*Fichier :\*\* `modules/MonitorTask.ps1`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* `Split-Path -Parent $MyInvocation.MyCommand.Path` pouvait retourner une valeur vide ou incorrecte selon le contexte d'appel (notamment depuis le Task Scheduler selon les versions de PowerShell).

&#x20;

\*\*Correction appliquée :\*\* Remplacement par `$scriptDir = $PSScriptRoot`, variable automatique garantissant toujours le répertoire du script en cours d'exécution.

&#x20;

\---

&#x20;

\#### S-4 — Script CHANGELOG fragile dans bump-version.yml

&#x20;

\*\*Fichier :\*\* `.github/workflows/bump-version.yml`  

\*\*Statut :\*\* ✅ Corrigé

&#x20;

\*\*Problème initial :\*\* Le script bash utilisait `head -1` pour récupérer la première ligne du CHANGELOG. Toute modification future de l'en-tête (badge, ligne vide, commentaire) aurait produit un CHANGELOG malformé silencieusement.

&#x20;

\*\*Correction appliquée :\*\* Remplacement par un script `awk` qui cherche explicitement la première ligne commençant par `# ` (titre de niveau 1 Markdown), indépendamment de la position physique dans le fichier.

&#x20;

```bash

awk -v ver="$NEW\_VERSION" -v date="$DATE" -v entry="$ENTRY" '

&#x20; /^# / \&\& !inserted {

&#x20;   print; print ""; print "## " ver " - " date; print ""; print entry; print ""

&#x20;   inserted=1; next

&#x20; }

&#x20; { print }

' CHANGELOG.md > CHANGELOG.tmp \&\& mv CHANGELOG.tmp CHANGELOG.md

```

&#x20;

\---

&#x20;

\### 🆕 Nouvelles incohérences détectées lors de la revue de suivi

&#x20;

\---

&#x20;

\#### N-1 — Badge LICENSE dans le README toujours à "MIT" alors que la licence est GPL v3

&#x20;

\*\*Fichier :\*\* `README.md`  

\*\*Priorité :\*\* 🟠 Important  

\*\*Statut :\*\* ✅ Corrigé (revérifié v2.3 : `README.md` affiche `License-GPL--v3-blue`)

&#x20;

\*\*Problème :\*\* Le fichier `LICENSE` a été migré de MIT vers GPL v3 (correctement). Le bas du README a été mis à jour en conséquence (`"Distribué sous licence GNU GENERAL PUBLIC v3.0"`). Cependant, le badge en haut du README pointe toujours vers l'ancienne licence :

&#x20;

```markdown

!\[License](https://img.shields.io/badge/License-MIT-green)

```

&#x20;

Pour un projet open-source, l'affichage de la mauvaise licence dans le badge est une information légalement incorrecte visible immédiatement par tout visiteur du dépôt.

&#x20;

\*\*Correction à appliquer :\*\*

&#x20;

```markdown

!\[License](https://img.shields.io/badge/License-GPL--v3-blue)

```

&#x20;

\---

&#x20;

\#### N-2 — `Stop-WslMonitor` ne vérifie pas les droits administrateur

&#x20;

\*\*Fichier :\*\* `modules/Monitor.ps1`  

\*\*Priorité :\*\* 🟡 Secondaire  

\*\*Statut :\*\* ✅ Corrigé (revérifié v2.3 : `Stop-WslMonitor` a le meme check admin que `Start-WslMonitor`, desormais factorise dans `Test-IsAdminUser`)

&#x20;

\*\*Problème :\*\* Le check admin a été ajouté dans `Start-WslMonitor`, mais `Stop-WslMonitor` appelle `Unregister-ScheduledTask` qui nécessite également des droits élevés. En terminal non-admin, la commande `wisely -Monitor stop` échouera avec une erreur Windows au lieu d'un message explicatif.

&#x20;

\*\*Correction à appliquer :\*\* Ajouter le même bloc de vérification en début de `Stop-WslMonitor` :

&#x20;

```powershell

function Stop-WslMonitor {

&#x20;   $isAdmin = (\[Security.Principal.WindowsPrincipal]\[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(

&#x20;       \[Security.Principal.WindowsBuiltinRole]::Administrator)

&#x20;   if (-not $isAdmin) {

&#x20;       Write-Host "  ERREUR : L'arret du monitoring requiert des droits administrateur." -ForegroundColor Red

&#x20;       Write-Host "  Relancez PowerShell en tant qu'Administrateur." -ForegroundColor Gray

&#x20;       return

&#x20;   }

&#x20;   # ... suite inchangée

}

```

&#x20;

\---

&#x20;

\## Analyse structurelle globale

&#x20;

\### Points forts de l'architecture

&#x20;

L'architecture du projet présente plusieurs décisions de conception solides qui méritent d'être soulignées.

&#x20;

\*\*Point d'entrée unique.\*\* `wisely.ps1` est le seul orchestre. Les modules ne se connaissent pas entre eux. Ce couplage zéro entre modules facilite considérablement la maintenabilité et les tests futurs.

&#x20;

\*\*Source de vérité JSON externe.\*\* Tous les profils et paramètres sont dans `data/profiles.json`. Aucun comportement métier n'est hardcodé dans le code PowerShell — à l'exception du chemin du fichier swap, qui est un défaut raisonnable.

&#x20;

\*\*Gestion Unicode propre.\*\* L'utilisation de `\[char]0xXXXX` pour les caractères de dessin de boîte évite élégamment les problèmes d'encodage de fichier source tout en produisant un rendu terminal correct. C'est une solution non évidente et bien exécutée.

&#x20;

\*\*Rollback défensif.\*\* Le backup automatique avant chaque écriture, couplé à la validation post-écriture avec rollback automatique, représente exactement le niveau de prudence attendu pour un outil système modifiant des fichiers de configuration actifs.

&#x20;

\### Cohérence de la gestion des erreurs

&#x20;

Après correction, le projet présente une gestion des erreurs cohérente et à deux niveaux. Les modules signalent via `throw`, le script principal attrape via `try/catch` et décide de la sortie. Ce pattern est le bon pour PowerShell et il est maintenant appliqué uniformément.

&#x20;

\### Gestion des chemins

&#x20;

Après les corrections, la gestion des chemins reste légèrement hétérogène entre les modules. `ProfileManager.ps1` et `Monitor.ps1` utilisent `$Global:WSLRoot` (injecté par le script principal), tandis que `WeeklyReport.ps1` et `MonitorTask.ps1` utilisent `$PSScriptRoot` (variable automatique du script courant). Les deux approches sont correctes dans leur contexte respectif, mais il convient de noter que `WeeklyReport.ps1` et `MonitorTask.ps1` sont les deux seuls modules appelés directement par le Task Scheduler sans passer par le script principal — c'est pourquoi ils ne peuvent pas dépendre de `$Global:WSLRoot`. Cette asymétrie est donc structurellement justifiée, mais mériterait un commentaire explicatif dans le code.

&#x20;

\---

&#x20;

\## Récapitulatif final

&#x20;

| # | Finding | Fichier | Priorité | Statut |

|---|---------|---------|----------|--------|

| C-1 | `exit` dans modules dot-sourcés | ProfileManager.ps1 | 🔴 Critique | ✅ Corrigé |

| C-2 | Rapport hebdo auto non implémenté | Monitor.ps1 | 🔴 Critique | ✅ Corrigé |

| C-3 | Settings JSON ignorés par le monitor | Monitor.ps1 | 🔴 Critique | ✅ Corrigé |

| C-4 | Validation schéma import insuffisante | ProfileManager.ps1 | 🔴 Critique | ✅ Corrigé |

| C-5 | Collision `$profile` variable réservée | ProfileManager.ps1 | 🔴 Critique | ✅ Corrigé |

| I-1 | `$TASK\_NAME` scope global | Monitor.ps1 | 🟠 Important | ✅ Corrigé |

| I-2 | `Get-WeeklyReport` code mort | Logger.ps1 | 🟠 Important | ✅ Corrigé |

| I-3 | Pas de check admin pour `Start-WslMonitor` | Monitor.ps1 | 🟠 Important | ✅ Corrigé |

| I-4 | Encodage ASCII pour rapports FR | WeeklyReport.ps1 | 🟠 Important | ✅ Corrigé |

| I-5 | Parsing `-NewProfile` non sécurisé | wisely.ps1 | 🟠 Important | ✅ Corrigé |

| I-6 | PSScriptAnalyzer trop permissif | ci.yml | 🟠 Important | ✅ Corrigé |

| S-1 | Lecture disque à chaque frame menu | wisely.ps1 | 🟡 Secondaire | ✅ Corrigé |

| S-2 | Limite CPU arbitraire à 8 cœurs | ProfileManager.ps1 | 🟡 Secondaire | ✅ Corrigé |

| S-3 | `$MyInvocation` au lieu de `$PSScriptRoot` | MonitorTask.ps1 | 🟡 Secondaire | ✅ Corrigé |

| S-4 | Script CHANGELOG fragile | bump-version.yml | 🟡 Secondaire | ✅ Corrigé |

| N-1 | Badge LICENSE incorrect (MIT vs GPL v3) | README.md | 🟠 Important | ✅ Corrigé |

| N-2 | Pas de check admin pour `Stop-WslMonitor` | Monitor.ps1 | 🟡 Secondaire | ✅ Corrigé |

&#x20;

\---

&#x20;

\*Audit réalisé sur la version 2.0.0 — Prochain audit recommandé à la prochaine release majeure ou après ajout de fonctionnalités système.\*

---

## Audit v2.3 (Général) — 2026-08-24

> Contrairement à l'audit initial (v2.0) et au suivi ciblé N-1/N-2, cette passe couvre **l'ensemble du dépôt** — pas seulement les modules touchés par v2.3 — via trois agents d'investigation parallèles (résilience aux données corrompues, sécurité/validation, cohérence documentaire). Les IDs de cette section sont préfixés `v2.3-` pour rester distincts de la numérotation C/I/S de l'audit initial ci-dessus.

### 🔴 Critique

---

#### v2.3-C-1 — `Import-Profiles` n'importe aucune validation du contenu des profils importés

**Fichier :** `modules/ProfileManager.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** `Import-Profiles` ne vérifiait que la présence des clés `profiles`/`version` (C-4 de l'audit initial) — jamais le **contenu** de chaque profil avant de l'écrire dans `profiles.json` et de l'utiliser pour réécrire `.wslconfig`/redémarrer WSL2. Un fichier importé avec `"memory": "n'importe quoi"`, un nombre de CPU hors limites, ou un champ contenant un retour à la ligne (injection dans `.wslconfig`, qui est un fichier `key=value` interprété ligne par ligne) passait intégralement.

**Correction appliquée :** Nouvelle fonction `Test-ProfileDefinition`, factorisée entre `New-CustomProfile` (qui validait déjà partiellement, en ligne) et `Import-Profiles` (qui ne validait pas du tout) — chaque profil qui entre dans le système, créé localement ou importé, passe désormais par la même validation : format mémoire (`^\d+GB$`), plage CPU (`1..NumberOfLogicalProcessors` réels de la machine), et absence de `\r`/`\n` dans les champs interpolés tels quels (`swap`, `swapFile`, `swappiness`, `displayName`, `description`, `color`).

```powershell
function Test-ProfileDefinition {
    param([Parameter(Mandatory)][PSCustomObject]$ProfileDef, [string]$Key = "?")
    if ("$($ProfileDef.memory)" -notmatch "^\d+GB$") {
        throw "Profil '$Key' : format memoire invalide '$($ProfileDef.memory)'."
    }
    $maxCpu = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    if ($ProfileDef.processors -lt 1 -or $ProfileDef.processors -gt $maxCpu) {
        throw "Profil '$Key' : nombre de CPU invalide '$($ProfileDef.processors)'."
    }
    foreach ($field in @("swap", "swapFile", "swappiness", "displayName", "description", "color")) {
        if ("$($ProfileDef.$field)" -match "[`r`n]") {
            throw "Profil '$Key' : le champ '$field' contient un retour a la ligne, refuse."
        }
    }
}
```

---

### 🟠 Important

---

#### v2.3-I-1 — `Get-BackupHistoryMax` pouvait rendre la purge des backups destructrice

**Fichier :** `modules/ProfileManager.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** Rien n'empêchait `backupHistoryMax` d'être 0 ou négatif dans `profiles.json`. `Backup-WslConfig` calcule `$toRemove = [math]::Max(0, $all.Count - $max)` : avec `$max <= 0`, `$toRemove` devient `$all.Count` (ou plus), supprimant **tous** les backups existants, y compris celui qui vient d'être créé — le mécanisme de sécurité de rollback se détruisant lui-même.

**Correction appliquée :** `Get-BackupHistoryMax` retombe sur le défaut (5) si la valeur configurée n'est pas strictement positive, au lieu de faire confiance telle quelle à `profiles.json`.

```powershell
if ($cfg.settings.backupHistoryMax -and [int]$cfg.settings.backupHistoryMax -gt 0) {
    return [int]$cfg.settings.backupHistoryMax
}
return $default
```

---

#### v2.3-I-2 — `MonitorTask.ps1` : mesure RAM non protégée, crash silencieux de la tâche planifiée

**Fichier :** `modules/MonitorTask.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** Le bloc `Get-CimInstance Win32_OperatingSystem` + calcul du pourcentage RAM n'était protégé par aucun `try/catch`. Ce script tourne sans supervision via le Planificateur de tâches Windows (`WSL2-RamMonitor`) — une exception WMI (service arrêté, permissions, etc.) faisait échouer la tâche sans aucune trace exploitable, désactivant silencieusement toute alerte RAM.

**Correction appliquée :** Le bloc de mesure est encadré d'un `try/catch` qui journalise l'échec dans `data/monitor_errors.txt` (nouveau fichier, même répertoire que `monitor_cooldown.txt`) via une fonction `Write-MonitorTaskError`, puis sort proprement (`exit 0`) plutôt que de planter.

---

#### v2.3-I-3 — `MonitorTask.ps1` : un fichier cooldown corrompu bloquait définitivement les alertes

**Fichier :** `modules/MonitorTask.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** `[datetime]::ParseExact` sur le contenu de `monitor_cooldown.txt` n'était pas protégé. Un fichier corrompu (édition manuelle, écriture partielle suite à une coupure) faisait planter la tâche à **chaque exécution suivante**, sans jamais se réparer tout seul ni journaliser quoi que ce soit — RAM alerting mort silencieusement jusqu'à intervention manuelle.

**Correction appliquée :** Le parsing est encadré d'un `try/catch` : en cas d'échec, l'erreur est journalisée (`Write-MonitorTaskError`) et le script **continue** (n'exit pas) pour déclencher l'alerte du jour, qui réécrit un cooldown valide — auto-réparation au prochain cycle plutôt que blocage permanent.

---

#### v2.3-I-4 — `WeeklyReport.ps1` : `history.json` corrompu faisait échouer la tâche planifiée

**Fichier :** `modules/WeeklyReport.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** `Get-Content $historyPath -Raw | ConvertFrom-Json` n'était protégé par aucun `try/catch`. Cette tâche tourne chaque lundi via le Planificateur de tâches en mode `-Silent` — un `history.json` corrompu la faisait échouer silencieusement, sans rapport, sans diagnostic, et sans plus jamais en produire tant que le fichier restait corrompu.

**Correction appliquée :** Encadré d'un `try/catch` : message "Historique corrompu, illisible." en mode non-silencieux, sortie propre (`exit 0`) dans tous les cas.

---

#### v2.3-I-5 — `WeeklyReport.ps1` : une seule entrée malformée faisait échouer tout le rapport

**Fichier :** `modules/WeeklyReport.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** Le filtre `$switches` appelait `[datetime]::ParseExact($_.timestamp, ...)` sans protection pour chaque entrée de l'historique. Une seule entrée au timestamp malformé (édition manuelle, futur bug d'écriture) faisait planter la génération du rapport entier plutôt que d'être simplement exclue.

**Correction appliquée :** Le parsing du timestamp est encadré d'un `try/catch` par entrée à l'intérieur du `Where-Object` — une entrée illisible est exclue silencieusement, le reste du rapport se génère normalement.

---

#### v2.3-I-6 — `Show-SwitchHistory` plantait sur un `history.json` corrompu

**Fichier :** `modules/Logger.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** Contrairement à `WeeklyReport.ps1` (tâche planifiée sans supervision), `Show-SwitchHistory` est appelée de façon interactive (`wisely -Status`, historique). Elle ne protégeait pas non plus son `ConvertFrom-Json` — un `history.json` corrompu faisait planter la commande en pleine session utilisateur au lieu d'afficher un message clair.

**Correction appliquée :** Même pattern try/catch que `WeeklyReport.ps1` : message "Historique corrompu, illisible." et retour propre.

---

#### v2.3-I-7 — Le workflow de release ne vérifiait pas que `VERSION` correspond au tag publié

**Fichier :** `.github/workflows/release.yml`
**Statut :** ✅ Corrigé

**Problème initial :** Rien n'empêchait de pousser un tag `vX.Y.Z` alors que le fichier `VERSION` du commit ciblé contenait encore une autre valeur (oubli de bump, rerun sur le mauvais commit) — l'archive de release publiée aurait alors embarqué un `VERSION` désynchronisé du tag GitHub, sans qu'aucune étape ne le détecte.

**Correction appliquée :** Nouvelle étape entre la lecture de `VERSION` et l'extraction du changelog : compare `VERSION` au tag (sans le préfixe `v`) et fait échouer la release avec une annotation `::error::` explicite en cas de désaccord.

---

### 🟡 Secondaire

---

#### v2.3-S-1 — Caractères non-ASCII résiduels dans du code `.ps1`

**Fichiers :** `modules/Logger.ps1`, `modules/ProfileManager.ps1`
**Statut :** ✅ Corrigé (partiel, volontairement — voir note)

**Problème initial :** Le projet impose l'ASCII pur pour tout `.ps1` (Unicode via `[char]0xXXXX`, convention déjà bien établie pour le dessin de boîtes dans `wisely.ps1`). `Show-SwitchHistory` (`Logger.ps1`) construisait ses lignes de séparation avec un tiret cadratin Unicode littéral (`──────`) au lieu de `([string]$C_DASH * $n)`/`("-" * $n)`, et une exception dans `ProfileManager.ps1` utilisait un tiret cadratin (`—`) au lieu d'un trait d'union ASCII.

**Correction appliquée :** Les séparateurs de `Show-SwitchHistory` remplacés par `("  " + ("-" * 50))` ; le tiret cadratin du message d'exception remplacé par un trait d'union. **Note :** les caractères accentués résiduels dans la prose des commentaires/docstrings (ex. `"événements"`) n'ont délibérément **pas** été touchés — l'incohérence mécanique et à haute confiance (séparateurs de dessin, message utilisateur) est distincte de la dérive résiduelle en prose de commentaire, hors scope d'une correction incidente.

---

#### v2.3-S-2 — `README.md` : exemple `profiles.json` désynchronisé du fichier réel

**Fichier :** `README.md`
**Statut :** ✅ Corrigé

**Problème initial :** L'exemple de configuration montrait `"version": "2.0"` (le vrai `data/profiles.json` utilise un format sémantique `X.Y.Z`) et `"memory": "2GB"` pour le profil web (la vraie valeur est `4GB`) — un nouveau contributeur copiant l'exemple obtiendrait une configuration qui ne correspond pas au comportement réel de l'outil.

**Correction appliquée :** `"version": "2.0.0"`, `"memory": "4GB"` pour le profil web, vérifiés contre `data/profiles.json` réel.

---

#### v2.3-S-3 — `README.md` : badge de version obsolète

**Fichier :** `README.md`
**Statut :** ✅ Corrigé

**Problème initial :** Le badge affichait `2.1.0` alors que le projet est en v2.2 livrée (v2.3 en cours à la date de cet audit).

**Correction appliquée :** Badge mis à jour vers `2.2.0`.

---

#### v2.3-S-4 — `README.md` : section "Contenu du rapport" ne mentionne pas la RAM par profil (v2.3)

**Fichier :** `README.md`
**Statut :** ✅ Corrigé

**Problème initial :** La brique "rapports hebdomadaires enrichis" (v2.3, PR #22) ajoute une section RAM moyenne libérée/consommée par profil au rapport généré, mais la liste à puces du README décrivant le contenu du rapport n'avait pas été mise à jour en conséquence.

**Correction appliquée :** Ajout de la puce documentant la RAM libérée/consommée en moyenne au switch, avec la précision qu'il s'agit d'un delta mesuré au switch et non d'un usage soutenu.

---

#### v2.3-S-5 — `README.md` : référence de commandes incomplète

**Fichier :** `README.md`
**Statut :** ✅ Corrigé

**Problème initial :** Plusieurs flags/commandes livrés en v2.2/v2.3 n'apparaissaient pas dans la section de référence des commandes : `-Verbose`, `wisely -Status -Short`, `wisely -Snapshot`, `wisely -Version`, `wisely <profil> -Quiet`.

**Correction appliquée :** Ajout d'un bloc `# ── Observation ──` et d'un bloc `# ── Sortie ──` couvrant ces commandes, à l'endroit logique de la référence de commandes existante.

---

#### v2.3-S-6 — `docs/wisely.md` : bannière de statut avec une formulation obsolète

**Fichier :** `docs/wisely.md`
**Statut :** ✅ Corrigé

**Problème initial :** La bannière en tête de document indiquait "...v2.2 est livrée et v2.3 est cadrée", devenue inexacte au fil de l'avancement de v2.3 (le document est explicitement un instantané figé — la formulation elle-même ne devait pas dépendre du jalon courant).

**Correction appliquée :** Reformulée en "le statut ci-dessous ne sera plus mis à jour", indépendante de tout jalon futur.

---

#### v2.3-S-7 — `docs/glossary.md` : termes v2.3 absents du glossaire

**Fichier :** `docs/glossary.md`
**Statut :** ✅ Corrigé

**Problème initial :** Les termes introduits par v2.3 (`ramDeltaGB`, `restartSeconds`, `wisely -Watch`, `Get-WatchSnapshot`/`Get-VmmemStats`, `Test-IsAdminUser`) n'étaient pas encore référencés dans le glossaire, alors que les termes v2.1/v2.2 l'étaient tous.

**Correction appliquée :** 5 nouvelles entrées ajoutées, dans le même format que les entrées existantes.

---

### Constats non corrigés dans cette passe (mis à jour depuis)

Au moment de cette passe d'audit (2026-08-24), deux catégories de constats n'avaient **pas** donné lieu à une correction de code :

- **Reportés au backlog** (`docs/TASKS.md`, section Someday) car non urgents et hors du périmètre "correction sûre et bon marché" de cet audit : absence de schéma formalisé pour `history.json` (contrairement à `profiles.json` depuis v2.2) ; absence de test couvrant une sortie anticipée en cours d'échantillonnage dans `Get-VmmemStats` ; exclusions PSScriptAnalyzer à revalider/nettoyer ; actions GitHub non épinglées par SHA (durcissement supply-chain) ; absence de tests Pester sur le schéma des `settings` de `profiles.json`.
- **Signalé sans correction, décision produit à trancher par l'utilisateur** : `CHANGELOG.md`/`VERSION`/`ROADMAP.md` ne reflétaient pas encore l'état "v2.3 complet" — un choix de timing de release, pas un bug, donc volontairement non tranché par cet audit.

**Les cinq constats reportés au backlog ont depuis tous été traités** (voir `docs/TASKS.md`, section Someday, chaque entrée cochée y pointe vers le commit/PR correspondant) : schéma `schemas/history.schema.json` ajouté, test de sortie anticipée de `Get-VmmemStats` écrit dans `tests/Monitor.Tests.ps1`, exclusions PSScriptAnalyzer revalidées et deux d'entre elles retirées de `ci.yml`, Actions GitHub épinglées par SHA, tests Pester ajoutés sur le schéma `settings` dans `tests/Schema.Tests.ps1`. Le tableau détaillé ci-dessous (T-4, T-5, T-7, T-9, T-11) reflète déjà cet état corrigé. Le point F5 (timing CHANGELOG/VERSION/ROADMAP) est lui aussi resolu par la marche normale du projet : v2.3.0 a été formellement publiée le 2026-08-25 (`CHANGELOG.md`), et le projet a depuis avance jusqu'a v2.4.0 puis au palier P0/v2.5.

### Récapitulatif — Audit v2.3 (Général)

Compteurs de la passe d'audit elle-même (2026-08-24), conservés tels quels pour l'historique :

| Priorité | Détectés | Corrigés (a l'epoque) | Reportés (backlog, a l'epoque) | Signalés (décision utilisateur, a l'epoque) |
|----------|----------|----------|---------------------|----------------------------------|
| 🔴 Critique | 1 | 1 | 0 | 0 |
| 🟠 Important | 7 | 7 | 0 | 0 |
| 🟡 Secondaire | 7 | 7 | 0 | 0 |
| Hors sévérité (dette/doc) | 6 | 0 | 5 | 1 |
| **Total** | **21** | **15** | **5** | **1** |

**État actuel** (verifie dans le code et `docs/TASKS.md`) : les 5 constats "backlog" sont corrigés, et le constat F5 est resolu par la publication normale des versions -- il ne reste **aucun** constat ouvert issu de cet audit.

| # | Finding | Fichier | Priorité | Statut |
|---|---------|---------|----------|--------|
| v2.3-C-1 | `Import-Profiles` sans validation de contenu | ProfileManager.ps1 | 🔴 Critique | ✅ Corrigé |
| v2.3-I-1 | `Get-BackupHistoryMax` purge destructrice possible | ProfileManager.ps1 | 🟠 Important | ✅ Corrigé |
| v2.3-I-2 | Mesure RAM non protégée (MonitorTask) | MonitorTask.ps1 | 🟠 Important | ✅ Corrigé |
| v2.3-I-3 | Cooldown corrompu bloquait les alertes | MonitorTask.ps1 | 🟠 Important | ✅ Corrigé |
| v2.3-I-4 | `history.json` corrompu faisait échouer le rapport hebdo | WeeklyReport.ps1 | 🟠 Important | ✅ Corrigé |
| v2.3-I-5 | Entrée malformée faisait échouer tout le rapport | WeeklyReport.ps1 | 🟠 Important | ✅ Corrigé |
| v2.3-I-6 | `Show-SwitchHistory` plantait sur historique corrompu | Logger.ps1 | 🟠 Important | ✅ Corrigé |
| v2.3-I-7 | Pas de vérif `VERSION` vs tag en release | release.yml | 🟠 Important | ✅ Corrigé |
| v2.3-S-1 | Caractères non-ASCII résiduels (séparateurs, throw) | Logger.ps1, ProfileManager.ps1 | 🟡 Secondaire | ✅ Corrigé |
| v2.3-S-2 | Exemple `profiles.json` désynchronisé | README.md | 🟡 Secondaire | ✅ Corrigé |
| v2.3-S-3 | Badge de version obsolète | README.md | 🟡 Secondaire | ✅ Corrigé |
| v2.3-S-4 | RAM par profil absente de "Contenu du rapport" | README.md | 🟡 Secondaire | ✅ Corrigé |
| v2.3-S-5 | Référence de commandes incomplète | README.md | 🟡 Secondaire | ✅ Corrigé |
| v2.3-S-6 | Bannière de statut obsolète | docs/wisely.md | 🟡 Secondaire | ✅ Corrigé |
| v2.3-S-7 | Termes v2.3 absents du glossaire | docs/glossary.md | 🟡 Secondaire | ✅ Corrigé |
| T-4 | Pas de schéma formalisé pour `history.json` | data/history.json | — | ✅ Corrigé |
| T-5 | `Get-VmmemStats` : pas de test sortie anticipée | Monitor.ps1 | — | ✅ Corrigé |
| T-7 | Exclusions PSScriptAnalyzer à revalider | ci.yml | — | ✅ Corrigé |
| T-9 | Actions GitHub non épinglées par SHA | .github/workflows/*.yml | — | ✅ Corrigé |
| T-11 | Pas de tests sur le schéma `settings` | data/profiles.json | — | ✅ Corrigé |
| F5 | Timing de bump CHANGELOG/VERSION/ROADMAP pour "v2.3 complet" | CHANGELOG.md, VERSION, ROADMAP.md | — | ✅ Resolu (v2.3.0 publiee le 2026-08-25, projet avance depuis a v2.4.0/P0-v2.5) |

---

*Audit général réalisé sur `main` après le merge de la PR #23 (dashboard `wisely -Watch`, dernière brique v2.3 planifiée). Méthode : trois agents d'investigation parallèles (résilience, sécurité/validation, cohérence documentaire) sur l'ensemble du dépôt, triage manuel, correction directe des constats sûrs et bon marché, report au backlog des constats plus structurants, signalement sans correction des décisions de timing produit.*

---

### 🔴 Critique (post-v2.5)

---

#### v2.5-C-1 — `Test-ProfileDefinition` validait tous les champs interpolés dans `.wslconfig` sauf la clé du profil elle-même

**Fichier :** `modules/ProfileManager.ps1`
**Statut :** ✅ Corrigé

**Problème initial :** v2.3-C-1 avait fait de `Test-ProfileDefinition` le point de passage unique pour tout profil entrant (créé localement ou importé), avec un contrôle explicite d'absence de `\r`/`\n` sur `swap`, `swapFile`, `swappiness`, `displayName`, `description`, `color` — mais jamais sur la **clé** du profil (`$Key`, nom de propriété JSON dans `profiles.json`). Entre-temps, P0/v2.5 (`ConvertTo-WslConfigContent`, correctif "identité du profil actif") a commencé à écrire cette clé telle quelle dans `.wslconfig`, dans une nouvelle section `[wisely]` (`profile=<cle>`) ; le correctif suivant du même palier ("écriture non destructive") l'a fait transiter par la primitive de fusion générique `Set-IniSectionKeys`. Une clé important un `\r\n` embarqué injectait donc une section ou une clé `.wslconfig` arbitraire (y compris `[wsl2]`/`kernelCommandLine`) au switch suivant. Le vecteur est réaliste : `Import-Profiles` documente elle-même un fichier importé comme "une entree externe" nécessitant la même validation qu'un profil créé localement, un cas d'usage explicite de partage de "pack de profils" ; et le menu interactif (`wisely.ps1`, `Show-InteractiveMenu`) affiche et transmet les clés de `profiles.json` telles quelles, sans que l'utilisateur ait besoin de les taper lui-même. Trouvé lors d'une revue de code post-fusion du palier P0/v2.5 (`.claude/skills/requesting-code-review`).

**Correction appliquée :** `Test-ProfileDefinition` rejette désormais toute clé contenant `\r`/`\n`, avec le même message d'erreur explicite que pour les autres champs (`"la cle du profil contient un retour a la ligne, refusee (risque d'injection dans .wslconfig ...)"`). Comme `Test-ProfileDefinition` est déjà le point de passage unique (v2.3-C-1), le correctif couvre `New-CustomProfile` et `Import-Profiles` sans toucher à leurs appelants.

```powershell
if ($Key -match "[`r`n]") {
    throw "Profil '$Key' : la cle du profil contient un retour a la ligne, refusee (risque d'injection dans .wslconfig - la cle est ecrite telle quelle dans la section [wisely])."
}
```

Développé en TDD : nouveau test sur `Import-Profiles` (clé important `\r\n[wsl2]\r\nmemory=999GB` — construite via l'indexeur de hashtable, `Add-Member` sur un hashtable n'étant pas serialisé par `ConvertTo-Json` de la même façon qu'une propriété native, piège découvert en écrivant le test) et sur `New-CustomProfile`. Suite complète : 180 tests, 0 échec, aucune régression.


---

## Audit v3.0 (GuestReader / Diagnose, jamais couverts par une passe precedente) — 2026-09-02

> Les audits precedents (v2.0, v2.3, v2.5-C-1 ci-dessus) n'ont jamais couvert `modules/GuestReader.ps1` (livre en P1/v2.6, apres l'audit v2.3) ni `modules/Diagnose.ps1` (livre en P2/v3.0, le plus recent module du repo). Cette passe cible ces deux modules en priorite, plus une relecture croisee de `wisely.ps1` et des workflows CI pour tout ce que les audits precedents n'auraient pas couvert. Methode : trois agents d'investigation en parallele (GuestReader/Diagnose ; wisely.ps1 + modules deja audites, en recoupement ; schemas/workflows/coherence doc-code), chaque constat retenu re-verifie manuellement, ligne par ligne, avant correction.

### 🔴 Critique

---

#### v3.0-C-1 — `Invoke-GuestProcess` ne gerait pas l'encodage UTF-16LE de la sortie de `wsl.exe`

**Fichier :** `modules/GuestReader.ps1`
**Statut :** ✅ Corrige

**Probleme initial :** `wsl.exe` emet sa sortie en UTF-16LE quand stdout/stderr sont redirigees (bug WSL bien documente, pas un choix de Wisely). Le code contournait deja ce probleme ailleurs pour le meme executable (`Get-WslActiveSessions`, `modules/ProfileManager.ps1` : `($_ -replace "\`0", "")` sur la sortie de `wsl --list --running`), mais `Invoke-GuestProcess` — le seul point de lancement de `wsl` pour les six commandes invite de P1 (MemInfo, LoadAvg, Uptime, DiskRoot, Nproc, ProcRss) — decodait `ReadToEndAsync()` avec l'encodage par defaut, produisant des chaines truffees de NUL. Consequence verifiee : `ConvertFrom-MemInfo` levait "Champ requis absent de /proc/meminfo" et `Get-DiagnoseMemoryAttribution` (P2) rapportait silencieusement "indisponible" alors que la commande WSL avait reellement reussi. Aucun test ne couvrait ce chemin : les tests `Invoke-GuestProcess` existants invoquent `pwsh.exe`/`powershell.exe`, jamais `wsl.exe`.

**Correction appliquee :** `StandardOutputEncoding`/`StandardErrorEncoding` fixes a `[System.Text.Encoding]::Unicode` uniquement quand `$FilePath` designe `wsl` (comparaison sur le nom de fichier sans extension, insensible a la casse) — pour ne pas casser les tests existants qui invoquent la fonction avec un autre executable dont la sortie est deja en UTF-8/ASCII normal.

### 🟠 Important

---

#### v3.0-I-1 — `Show-DiagnoseHistory` plantait sur une entree d'historique sans `action`/`profile`

**Fichier :** `modules/Diagnose.ps1`
**Statut :** ✅ Corrige

**Probleme initial :** `PadRight()` etait appele directement sur `$entry.action`/`$entry.profile` sans protection contre `$null`, alors que `Get-DiagnoseHistoryClassification` (appelee juste avant, meme fonction) tolere deja une entree partielle. Une entree valide en JSON mais sans `action`/`profile` (edition manuelle, entree legacy) faisait planter toute la vue `wisely -Diagnose -History` avec une erreur d'appel de methode sur une valeur nulle — a l'oppose du principe explicite de la fonction ("plutot qu'un rapport silencieusement clairseme").

**Correction appliquee :** interpolation en chaine avant `PadRight` (`"$($entry.action)"` / `"$($entry.profile)"`) — un `$null` interpole devient `""`, plus de plantage. Nouveau test dans `tests/Diagnose.Tests.ps1` couvrant une entree sans ces deux champs.

---

#### v3.0-I-2 — `Get-WslCeilingInfo` ignorait silencieusement les valeurs `memory=...MB`

**Fichier :** `modules/Diagnose.ps1`
**Statut :** ✅ Corrige

**Probleme initial :** le regex de calcul du ratio host (`RatioOfHostPct`) ne reconnaissait que les valeurs entieres en Go (`^(\d+)GB$`). Un `.wslconfig` avec `memory=4096MB` (syntaxe WSL2 valide) faisait disparaitre silencieusement le pourcentage de RAM hote, alors que `MemoryCeiling` continuait d'afficher "4096MB" — degradation partielle incoherente, sans aucune indication a l'utilisateur.

**Correction appliquee :** regex etendu a `^(\d+)(GB|MB)$`, conversion en Go avant le calcul du ratio. Nouveau test avec une valeur en MB et `Get-CimInstance` mocke.

---

#### v3.0-I-3 — `-Explain` sans `-Diagnose` etait ignore en silence, contrairement aux autres flags mal utilises

**Fichier :** `wisely.ps1`
**Statut :** ✅ Corrige

**Probleme initial :** `$Explain` n'etait lu que dans le bloc `if ($Diagnose)`. Taper `wisely -Explain <cle>` en oubliant `-Diagnose` traversait tous les blocs de dispatch sans y correspondre et atterrissait silencieusement dans le menu interactif — contrairement a `-Monitor`/`-Consent`, qui repondent tous deux par un message d'usage explicite et un code de sortie non nul en cas de mauvais usage.

**Correction appliquee :** garde explicite ajoutee avant le bloc `-Diagnose`, au meme niveau que les autres dispatches top-level : `-Explain` sans `-Diagnose` affiche desormais "Usage : -Diagnose -Explain <cle>" et sort en erreur.

### 🟡 Mineur

---

#### v3.0-S-1 — `Show-DiagnoseExplain` : lookup de cle sensible a la casse

**Fichier :** `modules/Diagnose.ps1`
**Statut :** ✅ Corrige

**Probleme initial :** la cle passee a `-Explain` etait comparee telle quelle aux listes fermees de cles `.wslconfig`, sans normalisation — contrairement a `-Consent`/`-Monitor`, qui normalisent en minuscules avant dispatch. `wisely -Diagnose -Explain AUTOMEMORYRECLAIM` repondait "n'est pas reconnue" alors que la cle existe, juste en majuscules.

**Correction appliquee :** recherche insensible a la casse dans les deux listes fermees. Deux nouveaux tests (cle geree et cle connue non geree, toutes deux tapees en majuscules).

---

#### v3.0-S-2 — `New-SnapshotProfile` contournait `Test-ProfileDefinition`

**Fichier :** `modules/ProfileManager.ps1`
**Statut :** ✅ Corrige

**Probleme initial :** ecrivait un nouveau profil dans `profiles.json` sans passer par `Test-ProfileDefinition`, alors que `New-CustomProfile` et `Import-Profiles` l'appellent tous les deux — cassant, pour ce troisieme point d'entree, l'invariant documente en commentaire ("tout profil qui entre dans le systeme ... passe par la meme validation", voir v2.3-C-1 ci-dessus). Risque pratique faible (les valeurs proviennent d'un profil actif deja valide a sa creation), mais sans garantie ni test.

**Correction appliquee :** `Test-ProfileDefinition` appelee avant l'ecriture, comme dans `New-CustomProfile`. Nouveau test verifiant le rejet d'un profil actif dont le nombre de CPU depasse les processeurs logiques disponibles.

### Ecarte apres verification (pas de correction)

- **Dispatch `wisely.ps1` : flags top-level mutuellement exclusifs sans validation** (ex. `wisely -Status -Diagnose` execute silencieusement seulement `-Status`) — reel, mais restructurer les ~15 blocs `if/exit` sequentiels est le changement le plus a risque de cette passe ; ne casse rien, ignore juste un flag surnumeraire. Propose comme suivi separe et delibere.
- **`Report.Distro` (`Diagnose.ps1`) porte l'argument brut `-Distro`, pas le distro resolu** — verifie : aucun code ne lit `Report.Distro` aujourd'hui. Sans effet observable.
- **`Show-DiagnoseHistory -Last` jamais expose en CLI** — cablage requerrait un nouveau flag `-Last` sur `wisely.ps1` : une fonctionnalite, pas un correctif.
- **`docs/ROADMAP.md` verdicts `REMOVE` sur Import/Export/`-Snapshot`/rapport hebdo alors qu'ils restent livres et documentes** — relu en contexte : ce tableau est une classification prospective ("a faire plus tard", deux entrees pointent vers un ADR), pas une affirmation sur l'etat actuel. Pas une derive documentaire.
- **`.github/workflows/powershell.yml` : pin `microsoft/psscriptanalyzer-action` sans commentaire de version** (seul pin des 7 workflows sans `# vX.Y.Z`, convention T-9) — verification du tag correspondant au SHA impossible depuis ce sandbox (pas d'acces reseau au depot tiers hors du perimetre de session). Non corrige plutot que d'inventer un numero de version non verifie.

### Contrainte de validation de cette session

Contrairement aux sessions precedentes (v2.6, v3.0 ci-dessus), qui avaient `pwsh` mais pas d'acces a PowerShell Gallery, **cette session n'a aucun runtime `pwsh` installe** (`which pwsh` echoue) — ni execution de la suite Pester, ni meme verification syntaxique AST possibles ici. Verification faite par relecture manuelle stricte de chaque diff (coherence des accolades, portee des variables, correspondance avec le comportement des tests existants deja lus en detail) et par recoupement avec un contournement deja valide en production pour le meme probleme (v3.0-C-1). Nouveaux cas de test Pester ecrits pour v3.0-I-1, v3.0-I-2, v3.0-S-1 et v3.0-S-2, suivant le style des tests existants, mais **non executes** — a confirmer avec `Invoke-Pester ./tests` sur une machine disposant de `pwsh`.

### Recapitulatif — Audit v3.0

| # | Finding | Fichier | Priorite | Statut |
|---|---------|---------|----------|--------|
| v3.0-C-1 | `wsl.exe` UTF-16LE non gere dans `Invoke-GuestProcess` | GuestReader.ps1 | 🔴 Critique | ✅ Corrige |
| v3.0-I-1 | `Show-DiagnoseHistory` plantait sur entree sans action/profile | Diagnose.ps1 | 🟠 Important | ✅ Corrige |
| v3.0-I-2 | `Get-WslCeilingInfo` ignorait `memory=...MB` | Diagnose.ps1 | 🟠 Important | ✅ Corrige |
| v3.0-I-3 | `-Explain` sans `-Diagnose` ignore en silence | wisely.ps1 | 🟠 Important | ✅ Corrige |
| v3.0-S-1 | `Show-DiagnoseExplain` sensible a la casse | Diagnose.ps1 | 🟡 Mineur | ✅ Corrige |
| v3.0-S-2 | `New-SnapshotProfile` contournait `Test-ProfileDefinition` | ProfileManager.ps1 | 🟡 Mineur | ✅ Corrige |

*Audit realise sur `main`/`claude/bonjour-4x687t`, portant sur l'integralite du depot avec un focus sur les modules P1/P2 jamais audites. Verification : relecture manuelle ligne a ligne (pas d'execution Pester possible dans ce sandbox — voir "Contrainte de validation" ci-dessus).*
