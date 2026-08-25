# Vision stratégique & Roadmap — Wisely
 
> Document de stratégie produit long terme — version 1.0  
> Rédigé après stabilisation de la v2.0.0 et complétion de l'audit qualité.
 
---
 
## Table des matières
 
1. [Analyse du positionnement actuel](#1-analyse-du-positionnement-actuel)
2. [Vision long terme](#2-vision-long-terme)
3. [Axes d'évolution majeurs](#3-axes-dévolution-majeurs)
4. [Roadmap structurée](#4-roadmap-structurée)
5. [Fonctionnalités avancées pertinentes](#5-fonctionnalités-avancées-pertinentes)
6. [Packaging, distribution & documentation](#6-packaging-distribution--documentation)
7. [Stratégie de test](#7-stratégie-de-test)
8. [Risques long terme](#8-risques-long-terme)
9. [Principes directeurs](#9-principes-directeurs)
10. [Questions ouvertes](#10-questions-ouvertes)
---
 
## 1. Analyse du positionnement actuel
 
### Cas d'usage couverts
 
Wisely répond aujourd'hui à un problème réel et précis : la rigidité de la configuration mémoire de WSL2. Windows ne propose aucun mécanisme natif pour basculer dynamiquement entre des allocations de ressources selon le contexte de travail. L'outil couvre aujourd'hui trois grandes situations : le développement web léger (VS Code + navigateur), la data science intensive (Jupyter, Pandas, ML), et le mode minimal de conservation de RAM. Il ajoute à cela une couche de monitoring passif via le Task Scheduler, un historique des opérations, et un système d'import/export de profils.
 
### Public cible actuel
 
Le public cible est le développeur Windows solo, expérimenté, qui travaille quotidiennement avec WSL2 et jongle entre plusieurs contextes techniques. Il sait ce qu'est `.wslconfig`, comprend la notion de profil mémoire, et est capable d'exécuter un script PowerShell. C'est un early adopter technophile, pas un utilisateur grand public.
 
### Forces actuelles
 
L'outil a plusieurs atouts structurels solides. L'architecture modulaire avec point d'entrée unique est une base propre pour évoluer sans régression. La source de vérité JSON externe signifie que l'ajout d'un profil ne nécessite pas de toucher au code — c'est une décision d'extensibilité fondamentale. L'UX terminal (menu interactif, boîte Unicode, barre RAM colorée) est soignée pour un outil de ce type. Le système de rollback défensif est ce qu'on attend d'un outil système qui touche à des fichiers de configuration critiques. Enfin, la CI/CD avec PSScriptAnalyzer et validation JSON est un signal de maturité rare pour un projet PowerShell solo.
 
### Limites structurelles
 
Plusieurs limites bloquent le passage à une adoption plus large. L'installation est entièrement manuelle — pas de package manager, pas d'installateur, juste un clone Git et une modification du `$PROFILE`. L'absence de tests automatisés (unitaires, intégration) rend chaque refactoring risqué et décourage les contributions externes. Le projet ne dispose d'aucune forme d'observabilité réelle : on sait quand un switch a eu lieu, mais on ne mesure pas l'impact réel sur la RAM disponible ni le temps de démarrage WSL2. La dépendance au processus `vmmem` comme proxy de consommation WSL2 est une heuristique fragile — elle confond la RAM allouée avec la RAM réellement consommée par les workloads Linux. Enfin, le projet est entièrement couplé à Windows + WSL2 + PowerShell 5.1, ce qui le positionne sur un segment précis mais sans possibilité d'évolution vers d'autres contextes.
 
---
 
## 2. Vision long terme
 
### Le rôle que peut jouer Wisely dans l'écosystème dev
 
WSL2 est devenu la norme de développement sur Windows. Microsoft l'a intégré profondément dans VS Code, Windows Terminal, et Docker Desktop. Des millions de développeurs Windows travaillent quotidiennement dans un environnement hybride Windows/Linux, sans jamais avoir les bons outils pour gérer la frontière entre les deux. Wisely peut devenir **la couche de gestion des ressources WSL2 qui manque à Windows nativement**.
 
La vision n'est pas de concurrencer WSL2 lui-même, ni de remplacer Windows Terminal. C'est de devenir l'outil que tout développeur Windows installe en même temps que WSL2 — exactement comme on installe `ripgrep` ou `bat` juste après avoir configuré son shell. Un utilitaire de référence, discret, fiable, que personne ne remet en question une fois installé.
 
### Niveau de maturité visé
 
La trajectoire se décompose en trois niveaux de maturité successifs :
 
**Niveau 1 — Outil personnel de référence (situation actuelle → v2.x).** L'outil est stable, audité, bien documenté. Il résout parfaitement son problème initial. Il s'installe facilement et s'intègre naturellement dans le workflow d'un développeur solo.
 
**Niveau 2 — Outil open-source adopté (v3.x).** L'outil est distribuable via Winget et/ou un module PowerShell Gallery. Il dispose d'une suite de tests qui permet à des contributeurs externes de proposer des PRs sans craindre de casser quoi que ce soit. La documentation couvre des guides, des exemples de profils par stack technique, et un changelog clair. Une petite communauté gravite autour du projet.
 
**Niveau 3 — Outil de référence dans l'écosystème WSL (v4.x et au-delà).** L'outil s'intègre avec les outils existants (Windows Terminal, VS Code, Dev Home). Il propose une API ou un système de hooks permettant à d'autres outils de déclencher des switchs de profil automatiquement. Il gère des contextes multi-machines et des configurations d'équipe.
 
---
 
## 3. Axes d'évolution majeurs
 
### Axe 1 — Technique : Architecture & Extensibilité
 
**Système de hooks / callbacks.** Aujourd'hui, un switch de profil est une action atomique et fermée : on écrit `.wslconfig`, on shutdown WSL2, c'est tout. La vraie valeur long terme serait de permettre l'exécution d'actions personnalisées avant et après un switch — par exemple, fermer des processus consommateurs, sauvegarder un état, envoyer une notification à un autre outil. Un système de hooks défini dans `profiles.json` (scripts `pre-switch` et `post-switch`) permettrait cette extensibilité sans modifier le code source.
 
```json
"web": {
  "hooks": {
    "pre-switch": "C:/Scripts/close-docker.ps1",
    "post-switch": "C:/Scripts/notify-teams.ps1"
  }
}
```
 
Complexité : **Moyenne.** La logique d'invocation est simple, mais la gestion des erreurs dans les hooks (timeout, exit code non-zéro) doit être robuste — **décision confirmée (voir §10)** : le comportement en cas d'échec (`abort`/`continue`) sera configurable par l'utilisateur au niveau de chaque règle, plutôt qu'imposé globalement par l'outil. Impact : **Moyen terme**, différenciant pour les usages avancés.
 
**Abstraction du backend de configuration.** Actuellement, `ProfileManager.ps1` écrit directement dans `.wslconfig`. Si Microsoft modifie la structure de ce fichier dans une future version de WSL2 (ce qui s'est déjà produit avec l'introduction de `networkingMode`), l'outil devra être modifié en profondeur. Introduire une couche d'abstraction `ConfigWriter` qui centralise la génération du contenu `.wslconfig` faciliterait l'adaptation à ces changements futurs.
 
Complexité : **Faible à moyenne.** Impact : **Long terme**, dette technique préventive.
 
**Support des variables d'environnement dans les profils.** Permettre des chemins dynamiques dans `profiles.json` via des variables système (`%USERPROFILE%`, `%TEMP%`) rendrait les profils portables entre machines sans modification manuelle.
 
Complexité : **Faible.** Impact : **Court terme**, valeur immédiate pour le partage de profils.
 
---
 
### Axe 2 — Produit : Features à forte valeur
 
**Profils contextuels automatiques (auto-switch).** C'est la feature produit la plus impactante envisageable. L'idée est de définir des règles d'activation automatique d'un profil selon le contexte : processus actifs, heure de la journée, présence d'un fichier dans un répertoire courant, état du réseau. Un développeur pourrait définir "passer en mode DATA quand Jupyter est actif" ou "passer en mode BASE après 22h00". Cela transforme l'outil d'un switcher manuel en un **gestionnaire de ressources adaptatif**.
 
Complexité : **Élevée.** Nécessite un moteur de règles, une tâche planifiée dédiée, et une logique de priorité entre règles concurrentes. Impact : **Long terme**, potentiellement la feature la plus différenciante.
 
**Profils de snapshot.** Permettre de capturer l'état courant de WSL2 (RAM allouée, nombre de CPUs, processus actifs côté Windows) et de l'enregistrer comme profil temporaire. Utile pour documenter pourquoi une configuration fonctionne bien pour un workload particulier.
 
Complexité : **Faible.** Impact : **Court terme**, valeur éducative et exploratoire.
 
**Bibliothèque de profils communautaires.** Un dépôt GitHub secondaire (ou un répertoire `community-profiles/` dans le repo principal) où des contributeurs partagent des profils prêts à l'emploi pour des stacks précises : Docker + Kubernetes, Machine Learning, Rust, Go, Game Dev. L'outil pourrait intégrer une commande `wisely -Browse` qui liste et télécharge ces profils.
 
Complexité : **Faible côté code** (c'est principalement de la gouvernance de contenu). Impact : **Moyen terme**, fort effet de communauté et d'adoption.
 
**Multi-profils simultanés (profils composites).** Certains utilisateurs ont des setups complexes où ils souhaiteraient appliquer un profil "mémoire" indépendamment d'un profil "réseau" ou "kernel". La notion de profil composite (couches superposables) est ambitieuse mais cohérente avec la direction de `.wslconfig` elle-même.
 
Complexité : **Élevée.** Impact : **Long terme**, niche mais puissant pour les power users.
 
---
 
### Axe 3 — Expérience utilisateur (DX)
 
**Mode verbeux et mode silencieux.** Aujourd'hui, l'output est fixe. Un flag `-Verbose` qui affiche le diff exact de `.wslconfig` avant/après le switch, et un flag `-Quiet` qui supprime tout output sauf les erreurs, répondraient à deux besoins distincts : le debug et l'intégration dans des scripts automatisés.
 
Complexité : **Faible.** Impact : **Court terme**, essentiel pour la scriptabilité.
 
**Temps de switch mesuré et affiché.** Afficher le temps écoulé entre le `wsl --shutdown` et la confirmation de succès donnerait un feedback concret sur les performances réelles. Sur des machines lentes, ce chiffre peut varier de 3 à 15 secondes — le savoir aide à calibrer les attentes.
 
Complexité : **Très faible.** Impact : **Court terme**, amélioration UX immédiate.
 
**Commande `wisely status` dédiée.** Aujourd'hui, pour connaître le profil actif, il faut ouvrir le menu interactif ou inspecter `.wslconfig` manuellement. Une commande `wisely status` qui affiche en une ligne le profil actif, la RAM allouée, et l'état du monitoring serait utile pour l'intégration dans des prompts shell (Windows Terminal, Oh My Posh).
 
Complexité : **Faible.** Impact : **Court terme**, très utilisé une fois disponible.
 
**Fragment de prompt pour Windows Terminal / Oh My Posh.** Proposer un snippet officiel permettant d'afficher le profil WSL actif dans le prompt terminal. C'est un vecteur de découverte organique du projet : les développeurs qui voient `[WSL:WEB]` dans le prompt de quelqu'un d'autre vont naturellement chercher comment reproduire ça.
 
Complexité : **Très faible** (c'est de la documentation, pas du code). Impact : **Moyen terme**, viral dans la communauté Windows Terminal.
 
---
 
### Axe 4 — Open-source : Adoption & Contributions
 
**CONTRIBUTING.md détaillé.** Un guide de contribution qui explique l'architecture, les conventions de nommage, le workflow de PR, et les critères d'acceptation. Sans ça, les contributions externes arrivent dans le désordre et créent plus de travail de review qu'elles n'en économisent.
 
Complexité : **Très faible.** Impact : **Court terme**, prérequis à toute contribution externe sérieuse.
 
**Templates d'issues et de PRs GitHub.** Des formulaires structurés pour les rapports de bug (version PS, version Windows, configuration WSL2) et les demandes de features évitent les issues incomplètes et accélèrent considérablement le triage.
 
Complexité : **Très faible.** Impact : **Court terme.**
 
**Galerie de profils dans le README.** Quelques profils concrets et commentés pour des stacks populaires (Node.js + Docker, Python ML, Rust) dans la documentation principale. C'est le meilleur argument de vente pour un nouvel utilisateur qui hésite à adopter l'outil.
 
Complexité : **Très faible.** Impact : **Court terme**, premier point de contact utilisateur.
 
**Système de versioning des profils JSON.** La clé `version` dans `profiles.json` existe déjà — mais elle n'est pas exploitée pour gérer les migrations. Quand le schéma évolue entre deux versions majeures de l'outil, un mécanisme de migration automatique (ou au moins de détection d'incompatibilité) protège les utilisateurs qui mettent à jour sans lire le CHANGELOG.
 
Complexité : **Moyenne.** Impact : **Moyen terme**, critique pour la pérennité à mesure que le schéma évolue.
 
---
 
### Axe 5 — Sécurité & Fiabilité
 
**Signature des scripts PowerShell.** Pour les environnements d'entreprise avec des politiques `AllSigned`, les scripts non signés sont simplement refusés. Signer les scripts avec un certificat de code (même auto-signé avec instructions d'installation) ouvrirait le projet à un public corporate qui en est aujourd'hui exclu par défaut.
 
Complexité : **Moyenne** (processus CI/CD à mettre en place). Impact : **Moyen terme**, débloque un segment d'utilisateurs entier.
 
**Validation du chemin du swapFile.** Aujourd'hui, `swapFile` dans le profil est copié tel quel dans `.wslconfig` sans vérifier que le répertoire cible existe. Si `C:/Temp/` n'existe pas sur la machine cible, WSL2 démarre avec une erreur silencieuse au niveau du swap. Une validation préalable avec message explicite éviterait ce cas de support fréquent.
 
Complexité : **Très faible.** Impact : **Court terme**, réduction des rapports de bugs.
 
**Backup versionné des `.wslconfig`.** Le système de backup actuel ne conserve qu'un seul backup (le dernier). Si un utilisateur effectue trois switchs en cascade et veut revenir à l'état d'il y a deux switchs, c'est impossible. Un historique glissant de N backups (configurable, défaut 5) résoudrait ce cas edge sans complexifier l'interface.
 
Complexité : **Faible.** Impact : **Court terme**, sécurité utilisateur renforcée.
 
**Détection de WSL2 en cours d'exécution avant shutdown.** Émettre un avertissement (ou demander confirmation) si des processus Linux actifs sont détectés avant d'exécuter `wsl --shutdown`. Fermer brutalement une session avec des processus en cours peut corrompre des fichiers ou perdre du travail non sauvegardé.
 
Complexité : **Moyenne** (interroger WSL2 pour lister les distributions actives). Impact : **Moyen terme**, prévention d'une perte de données réelle.
 
---
 
### Axe 6 — Observabilité & Monitoring

**Statut : axe retenu pour v2.3** (voir §4) — les trois features ci-dessous forment le scope complet du prochain cycle.
 
**Métriques réelles post-switch.** Après avoir appliqué un profil et redémarré WSL2, mesurer et logger la RAM effectivement disponible côté Windows, le delta de RAM libérée, et le temps de redémarrage WSL2. Ces métriques permettraient de valider que le switch a eu l'effet escompté — ce qui n'est aujourd'hui pas mesurable.
 
Complexité : **Faible à moyenne.** Impact : **Moyen terme**, transforme l'outil d'un configurateur en un observateur de performance réel.
 
**Dashboard de monitoring en temps réel.** Une commande `wisely -Watch` qui affiche un tableau de bord rafraîchi toutes les N secondes : RAM WSL2, CPU vmmem, profil actif, dernière alerte. Pas besoin d'ouvrir le Task Manager pour voir l'impact de WSL2 sur la machine.
 
Complexité : **Moyenne.** Impact : **Moyen terme**, feature visible et attractive pour la démonstration.
 
**Corrélation RAM / profil dans les rapports.** Les rapports hebdomadaires actuels comptent les switchs mais ne mesurent pas l'impact réel. Ajouter la RAM moyenne libérée/consommée par profil au moment du switch (depuis `ramDeltaGB`, journalisé par `Write-SwitchLog` depuis l'étape 2) transformerait le rapport en un outil d'aide à la décision : "cette semaine, passer en WEB a libéré en moyenne 1.4GB." Cette valeur est un delta mesuré *au moment du switch*, pas un usage moyen soutenu pendant que le profil reste actif — elle ne permet donc pas de conclure qu'un profil est "surdimensionné" par rapport à sa mémoire configurée (deux grandeurs différentes), volontairement pas de comparaison à `profiles.json` dans le rapport.
 
Complexité : **Moyenne** (nécessite de stocker des séries temporelles légères). Impact : **Moyen terme**, valeur analytique forte.
 
---
 
## 4. Roadmap structurée
 
### Court terme — v2.1 à v2.3 (Quick wins, 1 à 3 mois)
 
Ces évolutions sont toutes indépendantes les unes des autres et peuvent être livrées dans n'importe quel ordre sans risque architectural. Elles augmentent immédiatement la valeur perçue et la robustesse.
 
**v2.1 — Polish & Fiabilité (livrée)**
 
Livré : suite de tests **Pester** en CI (`Get-ProfileConfig`, `Import-Profiles`, `Logger`), validation du chemin `swapFile` avant l'écriture, backup versionné avec historique glissant (`backupHistoryMax`), cache mémoïsé pour `Get-ProfileConfig` (`Clear-ProfileConfigCache`), flags `-Verbose` et `-Quiet`, correction du bug de troncature de la barre RAM (`wisely -Status`).
 
Reporté à v2.2 : correction du badge LICENSE (MIT → GPL v3) dans le README, check admin dans `Stop-WslMonitor`, support des variables d'environnement dans `swapFile` (`%TEMP%`, `%USERPROFILE%`), commande dédiée `wisely status`, affichage du temps de switch mesuré.
 
**v2.2 — DX & Documentation (livrée)**
 
Livré : `CONTRIBUTING.md`, templates d'issues et PRs GitHub, galerie de profils par stack dans le README, snippet Oh My Posh / Windows Terminal Prompt, commande `wisely -Snapshot` pour capturer le profil courant, JSON Schema pour `profiles.json`, intégrité des réglages (`historyMaxEntries`, `backupEnabled`, `monitorIntervalSeconds`). Repris de v2.1 : variables d'environnement dans `swapFile` (`%TEMP%`, `%USERPROFILE%`, `%LOCALAPPDATA%`), commande `wisely -Status -Short` (en remplacement de la sous-commande `wisely status` initialement envisagée).
 
**v2.3 — Observabilité (livrée)**
 
Scope détaillé, à livrer dans cet ordre (Axe 6 complet, voir §3) :

1. **Prérequis — combler la dette de tests.** `Monitor.ps1`, `MonitorTask.ps1` et `WeeklyReport.ps1` n'ont aujourd'hui aucune couverture Pester alors que ce sont exactement les modules que ce cycle va faire évoluer. Écrire `tests/Monitor.Tests.ps1`, `tests/MonitorTask.Tests.ps1` et `tests/WeeklyReport.Tests.ps1` (mocks des cmdlets Windows-only, conventions `TestHelpers.ps1`) avant d'ajouter les nouvelles métriques — cohérent avec la priorité déjà appliquée en v2.1 ("tests avant tout chantier structurel"). Vérifier et clore le finding N-2 de `AUDIT.md` (check admin dans `Stop-WslMonitor`, statut ambigu entre le corps du texte et le tableau récap).
2. **Métriques réelles post-switch.** Mesurer et logger la RAM Windows disponible avant/après switch (delta) et le temps de redémarrage WSL2, en étendant le chronométrage déjà en place. Stockage dans le JSON existant (`history.json` ou fichier dédié) — pas de nouvelle dépendance externe.
3. **Rapports hebdomadaires enrichis.** Ajouter la RAM moyenne libérée/consommée par profil au moment du switch dans `WeeklyReport.ps1`, à partir de `ramDeltaGB` (métriques de l'étape 2) — critère d'acceptation : une section "RAM libérée/consommée en moyenne au switch" apparaît dans un rapport réel généré par l'outil dès qu'au moins une entrée de la semaine porte la mesure, absente sinon. Pas de comparaison à la mémoire configurée du profil (voir note de l'Axe 6 : delta au switch ≠ usage soutenu).
4. **`wisely -Watch`.** Dashboard temps réel (RAM WSL2, CPU vmmem, profil actif, dernière alerte), rendu terminal natif cohérent avec le style Unicode déjà en place dans `wisely -Status`.
5. **Audit rafraîchi ciblé.** Repasser un audit léger (format `AUDIT.md`) sur les modules touchés par ce cycle (Monitor, MonitorTask, WeeklyReport + nouveau code de métriques/`-Watch`), en clarifiant l'incohérence N-1/N-2 du dernier audit (daté v2.0).

**Explicitement hors scope de v2.3 :** l'évaluation expérimentale de Terminal.Gui (Phase 2 du guide `Wisely — État des lieux & Guide d'intégration TUIStudio.md`), bien que ce document la situe en v2.3. Elle est sciemment reportée à un axe séparé pour respecter le principe "une feature bien comprise à la fois avant de passer à la suivante" (`docs/CLAUDE.md`) — mélanger un chantier d'observabilité et une exploration d'architecture UI dans le même cycle dilue les deux.
 
---
 
### Moyen terme — v3.0 (Évolutions structurantes, 3 à 9 mois)
 
La v3.0 est une version majeure qui introduit des changements architecturaux et ouvre le projet à la contribution externe et à une distribution plus large.
 
**v3.0 — Distribution & Tests**
 
Publier l'outil sur **PowerShell Gallery** comme module `Wisely`, sous l'organisation GitHub **Wisely** à créer (décision confirmée, voir §10). Cela permet `Install-Module Wisely` et une mise à jour via `Update-Module` — c'est le changement d'adoption le plus impactant possible. (La suite de tests **Pester**, avec mocks des appels système type `wsl --shutdown`, a été livrée en avance de calendrier en v2.1 — voir §7.) Intégrer la publication automatique sur PowerShell Gallery dans le workflow `release.yml`. Implémenter le système de hooks `pre-switch` / `post-switch`, avec un comportement en cas d'échec (`abort`/`continue`) configurable par l'utilisateur au niveau de chaque règle (décision confirmée, voir §10). Implémenter la migration automatique du schéma `profiles.json` entre versions. Valider et assurer la compatibilité PowerShell 7+ en parallèle du support PowerShell 5.1 existant (décision confirmée, voir §10) — pas de dépréciation de 5.1.
 
---
 
### Long terme — v4.0 et au-delà (Vision ambitieuse, 9 à 24 mois)
 
Ces évolutions supposent une communauté active et une base de code robustement testée. Elles ne doivent pas être anticipées prématurément — leur valeur dépend entièrement du niveau d'adoption atteint.
 
**v4.0 — Intelligence & Écosystème**
 
Moteur de règles pour l'auto-switch contextuel. Intégration VS Code (extension ou command palette hook). Intégration Windows Dev Home. Bibliothèque de profils communautaires avec commande `wisely -Browse`. Support des profils composites (couches superposables). Exploration d'une interface graphique légère (Windows Forms ou WPF minimaliste) pour les utilisateurs moins à l'aise avec la CLI.
 
---
 
## 5. Fonctionnalités avancées pertinentes
 
Cette section détaille les trois features avancées les plus susceptibles d'apporter une vraie valeur différenciante, par ordre de priorité décroissante.
 
### Auto-switch contextuel
 
C'est la feature qui transforme Wisely de "switcher manuel" en "gestionnaire adaptatif". Le principe est un moteur de règles léger défini dans `profiles.json` :
 
```json
"rules": [
  {
    "name": "ML active",
    "condition": { "process": "jupyter-notebook" },
    "profile": "data",
    "priority": 10
  },
  {
    "name": "Après 22h00",
    "condition": { "time": "22:00-08:00" },
    "profile": "base",
    "priority": 5
  }
]
```
 
Une tâche planifiée évalue ces règles toutes les N minutes. Si une règle de priorité supérieure change, un switch automatique est déclenché. L'utilisateur peut désactiver temporairement l'auto-switch avec `wisely -AutoSwitch off`. L'historique trace explicitement les switchs automatiques vs manuels.
 
### Intégration prompt terminal
 
Un module compagnon léger (`WiselyPrompt`) qui expose une fonction `Get-WslSwitchStatus` retournant le profil actif sous forme structurée. Cette fonction peut être appelée depuis n'importe quel thème Oh My Posh ou profil Windows Terminal pour afficher dynamiquement le profil actif dans le prompt. La valeur est double : utile pour l'utilisateur, viral pour la découverte du projet.
 
### API locale légère
 
Pour permettre l'intégration avec VS Code et d'autres outils, une API REST locale minimaliste exposée via `HttpListener` PowerShell natif. Deux endpoints suffisent : `GET /status` (profil actif, RAM, état monitoring) et `POST /switch/{profil}`. Cela permet à une extension VS Code de déclencher un switch de profil depuis la palette de commandes, sans ouvrir un terminal. C'est ambitieux mais techniquement faisable en PowerShell pur.
 
---
 
## 6. Packaging, distribution & documentation
 
### PowerShell Gallery (priorité haute)
 
C'est le vecteur de distribution le plus naturel pour un module PowerShell — décision confirmée (voir §10) sous une organisation GitHub **Wisely** à créer. La publication requiert la transformation du projet en module structuré (fichier `.psd1` manifest + fichier `.psm1` qui dot-source les modules existants). La structure actuelle est déjà compatible avec cette transformation — c'est un refactoring de surface, pas une réécriture.
 
```
Wisely/
├── Wisely.psd1          ← Module manifest (version, auteur, exports)
├── Wisely.psm1          ← Point d'entrée du module (dot-sources)
├── Public/                 ← Fonctions exportées
│   └── Invoke-WslSwitch.ps1
├── Private/                ← Fonctions internes (modules actuels)
│   ├── ProfileManager.ps1
│   ├── Logger.ps1
│   ├── Monitor.ps1
│   └── WeeklyReport.ps1
└── data/
    └── profiles.json
```
 
La commande d'installation devient `Install-Module Wisely -Scope CurrentUser`, sans clone Git, sans modification manuelle du `$PROFILE`.
 
### Winget (priorité moyenne)
 
Microsoft Winget est le package manager natif de Windows 11 et Windows 10 récent. Soumettre un manifest Winget permettrait `winget install Wisely` pour les utilisateurs qui préfèrent ce vecteur. Cela nécessite uniquement un fichier YAML de manifest et le respect du processus de soumission de la communauté Winget. C'est une étape de visibilité plus que de distribution.
 
### GitHub Releases (existant, à améliorer)
 
Le workflow `release.yml` génère déjà un ZIP pour chaque tag. Deux améliorations : inclure un script `Install.ps1` dans le ZIP qui automatise l'installation et la configuration du `$PROFILE`, et générer un hash SHA256 du ZIP pour permettre la vérification d'intégrité.
 
### Documentation
 
La documentation doit évoluer sur trois niveaux complémentaires. Le **README principal** reste la vitrine du projet — il gagnera à intégrer un GIF de démonstration du menu interactif (enregistré avec `ttyd` ou `asciinema` converti en GIF). Un **wiki GitHub** ou un site **GitHub Pages** (simple, statique) accueillerait les guides approfondis : guide d'installation avancée, galerie de profils, guide de contribution, FAQ. Enfin, une **documentation en ligne des fonctions PowerShell** générée automatiquement depuis les commentaires `.SYNOPSIS` / `.DESCRIPTION` existants via `PlatyPS` (outil Microsoft officiel pour la doc PowerShell).
 
---
 
## 7. Stratégie de test
 
L'absence de tests automatisés est la principale dette technique du projet. Elle n'empêche pas le fonctionnement, mais elle bloque la contribution externe et rend chaque évolution risquée. La stratégie proposée est progressive et pragmatique.
 
### Phase 1 — Tests unitaires avec Pester (livrée en v2.1)
 
**Pester** est le framework de test natif de l'écosystème PowerShell, supporté nativement dans VS Code et intégrable en CI. `Get-ProfileConfig` et `Import-Profiles` sont couverts en CI depuis la v2.1, ainsi que `Logger.ps1`. Reste à étendre à `New-CustomProfile` (validation des paramètres) et `ConvertTo-WslConfigContent` (génération du fichier), par ordre de criticité.
 
Les fonctions qui interagissent avec le système (`wsl --shutdown`, `Register-ScheduledTask`, lecture de `.wslconfig`) doivent être testées avec des **mocks Pester** qui simulent ces appels sans effets de bord réels. Cela permet d'exécuter les tests sur n'importe quel runner CI, même sans WSL2 installé.
 
```powershell
# Exemple de test unitaire Pester pour Get-ProfileConfig
Describe "Get-ProfileConfig" {
    Context "quand profiles.json est valide" {
        It "retourne un objet avec une clé 'profiles'" {
            # Arrange : créer un profil JSON minimal dans un répertoire temporaire
            $testRoot = New-TempDir
            $Global:WSLRoot = $testRoot
            @{ version = "2.0.0"; profiles = @{ web = @{ memory = "2GB" } } } |
                ConvertTo-Json | Set-Content "$testRoot\data\profiles.json"
            # Act
            $result = Get-ProfileConfig
            # Assert
            $result.profiles | Should -Not -BeNullOrEmpty
        }
    }
    Context "quand profiles.json est absent" {
        It "lève une exception avec un message explicite" {
            $Global:WSLRoot = "C:\chemin\qui\nexiste\pas"
            { Get-ProfileConfig } | Should -Throw -ExpectedMessage "profiles.json introuvable"
        }
    }
}
```
 
### Phase 2 — Tests d'intégration
 
Des tests d'intégration plus lourds qui exercent des flux complets (`Set-WslProfile` → vérification du contenu de `.wslconfig` généré → `Invoke-Rollback` → vérification de la restauration) dans un répertoire temporaire isolé. Ces tests nécessitent un environnement Windows mais pas WSL2 actif.
 
### Phase 3 — CI avec couverture
 
Intégrer l'exécution des tests Pester dans `ci.yml`, avec rapport de couverture publié sur Codecov ou sur le summary GitHub Actions. Un badge de couverture dans le README est un signal de confiance immédiat pour les nouveaux contributeurs.
 
---
 
## 8. Risques long terme
 
### Dette technique par accumulation de features
 
Le risque le plus courant sur un projet qui grossit sans tests : chaque nouvelle feature ajoute de la complexité implicite, et sans filet de sécurité, les régressions s'accumulent silencieusement. La mitigation est directe — implémenter Pester avant d'ajouter des features de complexité moyenne ou haute.
 
### Fragmentation du schéma `profiles.json`
 
À mesure que de nouvelles clés sont ajoutées au schéma (hooks, règles d'auto-switch, métriques), le fichier devient plus complexe et les profils partagés entre utilisateurs peuvent devenir incompatibles. La mitigation est le versioning de schéma avec migration automatique et la backward compatibility stricte (nouvelles clés optionnelles, jamais de suppression de clé sans période de dépréciation).
 
### Couplage fort à l'implémentation actuelle de WSL2
 
Microsoft a déjà modifié le comportement de WSL2 et le format de `.wslconfig` plusieurs fois (introduction de `networkingMode`, `dnsTunneling`, `autoMemoryReclaim` en 2023-2024). Le projet dépend d'une lecture directe de ce fichier, ce qui le rend vulnérable aux changements de format. La mitigation est la couche d'abstraction `ConfigWriter` mentionnée en Axe 1, qui centralise la génération du contenu et facilite l'adaptation.
 
### Dépendance au processus `vmmem` comme proxy RAM
 
Cette heuristique est documentée et acceptée, mais elle a des limites. Sur certaines configurations (WSL2 avec `autoMemoryReclaim` activé, Windows 11 22H2+), la relation entre `vmmem.WorkingSet64` et la RAM réellement consommée par les workloads Linux est moins directe. Une future version devrait explorer les APIs WSL2 officielles (`wsl --list --verbose`, performance counters Windows) pour une mesure plus précise.
 
### Complexité croissante du code de menu interactif
 
Le menu interactif dans `wisely.ps1` est aujourd'hui la partie la plus monolithique du code — environ 80 lignes de logique de rendu imbriquée. Si le menu gagne de nouvelles entrées (profils composites, règles d'auto-switch, statut des tâches planifiées), cette section deviendra difficile à maintenir. La mitigation est une extraction anticipée vers un module `MenuRenderer.ps1` qui sépare la logique d'affichage de la logique de navigation.
 
### Gouvernance solo
 
Un projet maintenu par une seule personne a un bus factor de 1. Si le mainteneur principal n'est plus disponible pendant plusieurs mois, les PRs et issues s'accumulent, la communauté naissante se décourage, et le projet fork. La mitigation est documentaire d'abord (CONTRIBUTING.md clair, architecture documentée) puis organisationnelle (identifier et onboarder un ou deux co-mainteneurs de confiance dès qu'une communauté commence à se former). **Décision confirmée (voir §10) :** le projet passera sous une organisation GitHub **Wisely** (à créer), mutualisée avec la publication PowerShell Gallery, précisément pour préparer cette transition hors gouvernance solo.
 
---
 
## 9. Principes directeurs
 
Ces principes doivent servir de filtre pour toutes les décisions d'évolution futures. Une feature qui viole plusieurs d'entre eux simultanément ne doit pas être implémentée, peu importe son attrait apparent.
 
**Zéro configuration requise pour commencer.** Un utilisateur qui installe l'outil doit pouvoir exécuter `wisely` immédiatement, sans modifier aucun fichier. Les profils par défaut doivent couvrir 80% des cas d'usage sans personnalisation. La personnalisation est possible mais jamais obligatoire.
 
**Réversibilité systématique.** Toute action qui modifie l'état du système (switch, import, rollback) doit être réversible. Aucune opération destructive irréversible ne doit être possible sans confirmation explicite. Le backup existe pour les fichiers ; les logs existent pour les actions.
 
**Failing fast et bruyant.** Une erreur vaut mieux qu'un comportement silencieux incorrect. Si quelque chose ne va pas — fichier manquant, JSON invalide, droits insuffisants — l'outil doit le dire clairement, immédiatement, avec un message qui indique quoi faire. Pas de dégradation gracieuse qui masque un problème réel.
 
**Scriptabilité de première classe.** Chaque action réalisable via le menu interactif doit être réalisable via une commande CLI directe, avec des codes de sortie standard (`0` pour succès, `1` pour erreur). Les scripts d'automatisation sont des citoyens de première classe, pas des cas secondaires.
 
**Source de vérité unique.** `profiles.json` est et reste la seule source de vérité pour les profils et les paramètres. Aucun comportement métier ne doit être hardcodé dans le code si sa valeur est susceptible de varier selon le contexte ou l'utilisateur. Les constantes techniques (noms de tâches planifiées, clés requises dans `.wslconfig`) sont des exceptions acceptables.
 
**Minimalisme fonctionnel.** Chaque feature ajoutée doit justifier sa présence par une vraie valeur utilisateur documentée. "C'est cool" ou "c'est possible" ne sont pas des justifications suffisantes. La question à poser avant chaque ajout est : "Combien d'utilisateurs réels en ont explicitement besoin, et à quelle fréquence ?"
 
**Compatibilité descendante des profils.** Une mise à jour de l'outil ne doit jamais casser un `profiles.json` existant. Les nouvelles clés de schéma sont optionnelles avec des valeurs par défaut documentées. Une migration automatique doit être proposée si le schéma évolue de manière incompatible.
 
---
 
## 10. Décisions stratégiques
 
Ces questions étaient structurantes pour affiner la vision produit (anciennement « Questions ouvertes »). Elles ont été tranchées avec le mainteneur le 2026-08-25 et orientent désormais les priorités de la roadmap et les choix d'architecture.
 
**Sur l'audience cible :** L'outil vise-t-il exclusivement les développeurs solo, ou y a-t-il une ambition de support des configurations d'équipe (profils partagés via un dépôt d'entreprise) ?
 
**Décision :** Non, pas exclusivement solo. Il y a une ambition de support des configurations d'équipe. Cela conforte la trajectoire déjà esquissée au Niveau 3 (§2 — « contextes multi-machines et configurations d'équipe ») et doit être gardé à l'esprit dans la conception du système de distribution de profils (bibliothèque communautaire, §3 Axe 2) : prévoir dès que possible un mode de partage de profils qui ne suppose pas un utilisateur unique.
 
**Sur la distribution :** La publication sur PowerShell Gallery est-elle envisagée ? Si oui, sous quel nom d'organisation ?
 
**Décision :** Oui, confirmée. Publication sous une organisation GitHub **Wisely**, à créer (le mainteneur est actuellement seul, sans organisation existante — la création de cette organisation est donc un prérequis administratif, à planifier avant ou en tout début de v3.0). Cette même organisation sert aussi la gouvernance du projet (voir décision suivante).
 
**Sur les tests :** Existe-t-il un environnement de développement dédié pour les tests d'intégration (machine Windows avec WSL2) ? Ou faut-il concevoir la stratégie de test pour fonctionner entièrement sans WSL2 (mocks complets) ?
 
**Décision :** Une machine perso avec WSL2 est disponible, mais la stratégie de test retenue est conçue pour fonctionner **entièrement sans WSL2** (mocks complets) — cohérent avec l'approche déjà en place en Phase 1/2 (§7), et nécessaire pour que la CI et de futurs contributeurs externes puissent exécuter la suite sans environnement Windows+WSL2 dédié.
 
**Sur l'auto-switch contextuel :** Cette feature est-elle dans la vision du projet, ou préférez-vous garder le principe d'un outil manuel, explicite, et sous contrôle total de l'utilisateur ?
 
**Décision :** Non tranchée pour l'instant, volontairement reportée. L'auto-switch reste dans la vision long terme (v4.0, §3 Axe 2) mais son adoption n'est pas engagée : la décision sera prise plus tard, à l'écoute des retours des utilisateurs, une fois qu'une communauté existe pour se prononcer sur le compromis contrôle manuel vs automatisation.
 
**Sur les hooks :** Si un hook `pre-switch` / `post-switch` échoue (timeout, exception), le switch doit-il être abandonné, poursuivi, ou l'utilisateur doit-il choisir au moment de la définition de la règle ?
 
**Décision :** Le choix est laissé à l'utilisateur, au niveau de la règle elle-même (par exemple une clé `on-failure: abort` / `continue` par hook dans `profiles.json`), plutôt qu'un comportement global imposé par l'outil.
 
**Sur la gouvernance :** Y a-t-il une intention de passer le projet sous une organisation GitHub (plutôt qu'un compte personnel) pour faciliter l'ajout de co-mainteneurs ?
 
**Décision :** Oui. L'organisation GitHub **Wisely** (mutualisée avec la publication PowerShell Gallery, voir ci-dessus) sera créée pour faciliter l'ajout futur de co-mainteneurs et réduire le risque de gouvernance solo identifié en §8.
 
**Sur la compatibilité PowerShell 7+ :** Y a-t-il une intention de supporter PS7, ou la compatibilité 5.1 est-elle une contrainte non négociable ?
 
**Décision :** Support de PowerShell 7+ voulu, **en parallèle** de PowerShell 5.1 — pas de dépréciation de 5.1. Les deux versions doivent rester compatibles simultanément.
 
---
 
*Document vivant — à réviser à chaque release majeure ou inflexion stratégique significative.*  
*Dernière révision : 2026-08-25 (intégration des décisions stratégiques de §10).*  
*Prochain point de revue recommandé : après publication de la v2.2.*