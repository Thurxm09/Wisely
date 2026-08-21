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

Deux nouvelles incohérences mineures ont été détectées lors de cette revue de suivi.

&#x20;

| Priorité | Initial | Corrigé | Restant |

|----------|---------|---------|---------|

| 🔴 Critique | 5 | 5 | 0 |

| 🟠 Important | 6 | 6 | 0 |

| 🟡 Secondaire | 4 | 4 | 0 |

| 🆕 Nouveau | 2 | 0 | 2 |

| \*\*Total\*\* | \*\*15\*\* | \*\*15\*\* | \*\*2\*\* |

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

