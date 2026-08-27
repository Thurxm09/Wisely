# Glossaire — Wisely

## Concepts produit

| Terme | Signification |
|-------|---------------|
| Wisely | Nom du projet — définitif. Les mentions résiduelles de `wsl-switch` (notamment sur le site) sont des vestiges à corriger, pas un nom alternatif |
| Les quatre objets | Le vocabulaire du produit : **État** (quel est l'état réel ?), **Cause** (pourquoi ?), **Politique** (qu'est-ce qui est permis ?), **Action** (que peut-on faire sans danger ?). Voir `VISION.md` |
| La boucle | Le modèle produit : observer → **expliquer** → recommander → agir → vérifier. Wisely ne détient historiquement que le maillon « agir ». « Expliquer » est un maillon nommé depuis le 2026-08-27 : c'est un livrable, pas un sous-produit |
| **L'écart** | La relation entre l'**État** observé et la **Politique** de ressources : la distance entre ce que WSL2 consomme et ce qu'on l'autorise à consommer. **Requalifié le 2026-08-27** : modèle interne puissant pour les ressources à plafond configurable (mémoire, CPU exposé, swap), il n'est plus l'ontologie du produit — il ne dit rien du cache, de l'I/O ou du disque, et masque que 8 Go consommés ne sont pas 8 Go nécessaires. Voir `decisions/0013-...` |
| Le filtre de périmètre | Le test qui remplace « est-ce une opération sur l'écart ? » : servir un des quatre objets pour un maillon nommé, désigner une case de `PROBLEM.md` §3 et une situation de `USE-CASES.md`, ne tomber dans aucun non-but |
| Classe de mesure | **Directe**, **attribuée**, **estimée** ou **corrélée**. Propriété de la mesure, visible côté utilisateur. Une mesure attribuée dit « ce qui est rattachable à X », jamais « ce que X consomme » (`RESOURCE-MODEL.md`) |
| Portée (`scope`) | `host`, `vm`, `distro`, `process` ou `policy`. Mélanger deux portées sans le dire est le bug qui a rendu l'alerte RAM indéclenchable |
| Provenance | Pour chaque clé de `.wslconfig` : « gérée par Wisely » ou « externe ». Face lisible du principe 8, posée par le principe 14 |
| `wisely diagnose` | La commande d'entrée du produit, planifiée au palier P2. **Anciennement `wisely doctor`**, renommée avant écriture le 2026-08-27 : le nom annonce la valeur plutôt qu'une catégorie d'outil |
| Barrière de validation | Le palier P3 de `ROADMAP.md`, **bloquant** : aucun palier au-delà ne démarre avant que quelqu'un d'autre que le mainteneur se soit servi de l'outil |
| Doctrine de lecture | Le contrat définissant ce que Wisely lit dans une distribution Linux et ce qu'il ne lira jamais (`DOCTRINE-LECTURE.md`) |
| Profil dérivé | Un profil exprimé comme une politique résolue sur la machine réelle (« laisser 8 Go à Windows ») plutôt qu'en gigaoctets absolus. Planifié v3.1, voir `decisions/0006-profils-derives.md` |

## Environnement WSL2

| Terme | Signification |
|-------|---------------|
| `.wslconfig` | Fichier de configuration globale de WSL2, dans le profil utilisateur Windows. **Fichier partagé** : il peut contenir des réglages posés par l'utilisateur, Docker Desktop, WSL Settings ou une politique d'entreprise. Les chemins de swap utilisent des slashs (`C:/Temp/wsl-swap.vhdx`) |
| `wsl.conf` | Configuration **par distribution**, à l'intérieur de Linux. Wisely n'y touche pas |
| `vmmem` / `VmmemWSL` | Processus Windows agrégeant toute la consommation WSL2. **Deux noms selon la version de Windows** : le code ne cherche aujourd'hui que `vmmem`, ce qui rend l'observation inopérante sur Windows 11 récent (corrigé en v2.5) |
| `autoMemoryReclaim` | Réglage `.wslconfig` (`gradual` / `dropcache`) rendant à Windows la mémoire cache inactive. Pas actif par défaut. Répond en partie au grief fondateur du projet — voir hypothèse A2. **Change la signification de la mesure mémoire, pas seulement sa valeur** : aucune recommandation de plafond ne se formule sans indiquer son état |
| `MemAvailable` / `MemFree` | Deux champs de `/proc/meminfo` régulièrement confondus. `MemFree` est presque toujours bas et ce n'est **pas** un problème — Linux utilise la RAM libre comme cache. `MemAvailable` est le bon chiffre pour « reste-t-il de la marge ? » |
| RSS | Mémoire résidente d'un processus, **pages partagées incluses**. La somme des RSS peut donc dépasser la mémoire réellement occupée : elle n'est jamais présentée comme la consommation totale (`RESOURCE-MODEL.md` §4.4) |
| `loadavg` | Moyenne des tâches exécutables **ou en attente d'I/O ininterruptible**. Ce n'est pas un pourcentage CPU, et il n'existe pas d'« écart CPU » |
| `sparseVhd` | Réglage rendant le disque virtuel creux, avec désallocation automatique. **Rend `Optimize-VHD` inopérant** ; la méthode correcte devient `fstrim` depuis Linux |
| `ext4.vhdx` | Le disque virtuel stockant le système de fichiers d'une distribution. Grossit à l'écriture et ne se réduit pas de lui-même sans `sparseVhd` |
| WSL Settings | Application graphique officielle de Microsoft (`wslsettings.exe`, WinUI 3) qui édite `.wslconfig`. Wisely ne doit pas la concurrencer sur l'édition |

## Code

| Terme | Signification |
|-------|---------------|
| `profiles.json` | Source de vérité externe des profils et réglages, validée par `schemas/profiles.schema.json` |
| `history.json` | Journal des opérations, validé par `schemas/history.schema.json`. **Aussi un jeu de données** : sa lecture teste l'hypothèse A5 (voir `ASSUMPTIONS.md`, expérience E1) |
| `Get-ProfileConfig` / `Import-Profiles` | Lecture et import de `profiles.json` — cibles prioritaires des tests Pester et de la mémoïsation |
| `Clear-ProfileConfigCache` | Invalidation du cache mémoïsé, appelée après toute réécriture de `profiles.json` |
| `Get-ActiveProfile` | Identifie le profil actif **par égalité de valeur mémoire** (`modules/ProfileManager.ps1:64`) — deux profils de même taille sont indiscernables. Défaut corrigé en P0 / v2.5 |
| `ConvertTo-WslConfigContent` | Génère le contenu de `.wslconfig`. **Réécrit aujourd'hui le fichier entier**, effaçant les clés non gérées — corrigé en v2.5 (principe 8) |
| `Test-ProfileDefinition` | Validation partagée par `New-CustomProfile` et `Import-Profiles` : tout profil entrant passe par la même porte |
| `ramDeltaGB` | Champ de `history.json` : delta de RAM Windows disponible mesuré au switch. **Mesure en réalité l'arrêt de la session précédente**, tout en étant attribué au profil cible — corrigé ou retiré en v2.5 |
| `restartSeconds` | Champ de `history.json` : durée mesurée de l'arrêt WSL2 lors d'un switch |
| `Get-WatchSnapshot` / `Get-VmmemStats` | Collecte de données pure et testable, séparée de la boucle d'affichage — motif attendu pour toute nouvelle mesure |
| `Get-WslActiveSessions` / `Confirm-WslShutdown` | Garde-fou v2.4 : détecte les distributions actives avant `wsl --shutdown`, avec bypass `-Force`. À étendre en v3.0 pour dire *ce qui* va être interrompu |
| `Test-WiselyNonInteractive` | Isole le test d'entrée redirigée pour le rendre mockable en test |
| `Test-IsAdminUser` | Vérification des droits administrateur, partagée entre démarrage et arrêt du monitoring |
| PS5.1 / PS7 | Deux versions de PowerShell aux chemins `$PROFILE` distincts. Supportées en parallèle, voir `decisions/0003-powershell-5-et-7.md` |

## Documentation

| Document | Question à laquelle il répond seul |
|-------|---------------|
| `PROBLEM.md` | Quel problème, pour qui, avec quelles preuves ? |
| `VISION.md` | Quelle capacité fondamentale ? |
| `PRINCIPLES.md` | Comment trancher sans rouvrir le débat ? |
| `DOCTRINE-LECTURE.md` | Que lit Wisely dans Linux, et que ne lira-t-il jamais ? |
| `ASSUMPTIONS.md` | Que croyons-nous sans l'avoir vérifié ? |
| `USE-CASES.md` | Dans quelles situations concrètes quelqu'un aurait-il besoin de Wisely ? |
| `RESOURCE-MODEL.md` | Que signifie chaque chiffre affiché, et lequel refuse-t-on d'afficher ? |
| `ROADMAP.md` | Qu'est-ce qu'on fait ensuite, et pourquoi dans cet ordre ? |
| `decisions/` | Pourquoi a-t-on tranché ainsi, et quand ? |
| `AUDIT.md` | Quels défauts de qualité ont été constatés et corrigés ? |
| `TASKS.md` | Qu'est-ce qui est en cours ? |
| `refondation-wisely.html` | Document de travail de l'analyse stratégique du 2026-08-26 — trace du raisonnement, à ouvrir dans un navigateur. Ce sont les documents ci-dessus qui font foi |
| `audits/` | Audits **stratégiques** externes, archivés intégralement et jamais réécrits. Ne font pas foi ; chacun a son ADR de réponse. **À ne pas confondre avec `AUDIT.md`**, qui est l'audit qualité du code |
| `archive/` | Documents historiques conservés pour mémoire — **ne pas suivre** |
