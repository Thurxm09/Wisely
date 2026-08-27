# Wisely - Changelog

## Non publie

### v2.5 "Verite" -- troisieme correctif (ramDeltaGB retire)

- **`ramDeltaGB` retire, pas corrige** : la mesure prise autour de `wsl --shutdown` dans `Set-WslProfile` reflete l'arret de la session PRECEDENTE, tout en etant attribuee au profil CIBLE dans l'historique -- une mesure non attribuable au sens du principe 9. `Get-AvailableRamGB` (fonction dediee a cette seule mesure) et l'affichage "RAM Windows disponible : ..." sont retires de `modules/ProfileManager.ps1`
- Le parametre `-RamDeltaGB` est retire de `Write-SwitchLog` (`modules/Logger.ps1`) -- plus aucune nouvelle entree d'historique ne l'ecrit. `data/history.json` garde `ramDeltaGB` comme cle optionnelle du schema, pour la lecture retro-compatible des entrees existantes
- La section "RAM liberee/consommee en moyenne au switch" est retiree du rapport hebdomadaire (`modules/WeeklyReport.ps1`), conformement a `docs/TASKS.md` : elle etait entierement construite sur cette mesure non attribuable
- Le vrai remplacement (contrat avant/apres mesure apres redemarrage effectif) reste planifie au palier P6 de `docs/ROADMAP.md`, deliberement hors scope de ce correctif -- P0 n'ajoute aucune fonctionnalite visible
- Developpe en TDD : tests reecrits dans `Logger.Tests.ps1`, `ProfileManager.Tests.ps1`, `WeeklyReport.Tests.ps1` et `Schema.Tests.ps1` (retrait des tests devenus obsoletes, ajout d'un test de compatibilite retroactive du schema), verifies en echec pour la bonne raison avant le correctif. Suite complete : 164 tests, 0 echec, aucune regression
- Troisieme des cinq correctifs de P0 / v2.5 "Verite" (`docs/TASKS.md`) ; deux restent a faire

### v2.5 "Verite" -- deuxieme correctif (seuil d'alerte au bon denominateur)

- **Seuil rapporte au plafond WSL2, pas a la RAM totale** : l'alerte comparait la part de WSL2 dans la RAM *totale* de la machine a un seuil de 80 % -- avec un plafond livre de 6 Go maximum, elle ne pouvait mathematiquement pas se declencher. Elle compare desormais l'usage au plafond configure dans `.wslconfig` (`memory=`, accepte GB et MB). `modules/MonitorTask.ps1` (`Get-WslMemoryCeilingBytes`, nouvelle)
- **`Get-CimInstance`/`Win32_OperatingSystem` retire** de `MonitorTask.ps1` : la RAM totale de la machine n'a plus sa place dans ce calcul (melange de portees, `docs/RESOURCE-MODEL.md` section 3)
- Sans plafond connu (`.wslconfig` absent, illisible, ou sans cle `memory=` reconnue), l'alerte est ignoree et journalisee explicitement plutot que de deviner -- principe 9
- Le message de la notification toast reflete le nouveau denominateur (`% du plafond utilise`, pas `% de RAM utilise`)
- Developpe en TDD : suite de tests reecrite dans `tests/MonitorTask.Tests.ps1` (11 tests, dont trois nouveaux cas -- plafond absent, cle `memory=` absente, plafond exprime en MB), verifiee en echec pour la bonne raison avant le correctif
- Deuxieme des cinq correctifs de P0 / v2.5 "Verite" (`docs/TASKS.md`) ; trois restent a faire

### v2.5 "Verite" -- premier correctif (detection du processus WSL2)

- **Detection VmmemWSL** : `Get-Process -Name "vmmem"` ne trouvait rien sur Windows 11 recent, ou le processus s'appelle `VmmemWSL` -- toute la couche d'observation (`wisely -Watch`, l'alerte de `MonitorTask.ps1`) etait silencieusement inoperante sur ces machines. Les deux noms sont desormais acceptes (`Get-Process -Name "VmmemWSL", "vmmem"`). `modules/Monitor.ps1` (`Get-VmmemStats`), `modules/MonitorTask.ps1`
- Developpe en TDD : deux tests Pester ecrits et verifies en echec avant le correctif, dans `tests/Monitor.Tests.ps1` et `tests/MonitorTask.Tests.ps1`
- Premier des cinq correctifs de P0 / v2.5 "Verite" (`docs/TASKS.md`) ; les quatre autres restent a faire

### Adoption de l'audit strategique externe d'aout 2026

- **Direction produit revisee** : la capacite fondamentale devient *transformer l'etat reel des ressources WSL2 en decisions explicables et en actions sures*. Categorie : WSL2 Resource Intelligence & Control. Promesse : *Comprendre WSL. Agir en confiance.* Voir `docs/decisions/0013-adoption-audit-strategique-externe.md`, qui revise 0005 sans l'annuler
- **L'ecart requalifie** : il devient la relation entre l'Etat observe et la Politique de ressources, modele interne des ressources a plafond configurable, et cesse d'etre l'ontologie du produit. Motif : il ne modelise ni le cache, ni l'I/O, ni le disque, et il masque que 8 Go consommes ne sont pas 8 Go necessaires
- **`docs/VISION.md` reecrit** autour de quatre objets (Etat, Cause, Politique, Action) et d'une boucle ou *expliquer* est un maillon nomme. Le test de perimetre de l'ecart est remplace par un filtre a trois questions, pour que la vision conserve son pouvoir de refus
- **`docs/RESOURCE-MODEL.md`** (nouveau) : ce que signifie chaque chiffre affiche, et lequel Wisely refuse d'afficher. Taxonomie directe/attribuee/estimee/correlee, contrat de metrique (portee, source, fraicheur, confiance), et deux regles dures -- la somme des RSS n'est jamais la RAM consommee, il n'y a pas d'ecart CPU
- **`docs/USE-CASES.md`** (nouveau) : sept situations reelles, en remplacement du raisonnement par metier
- **`docs/PRINCIPLES.md`** : principe 1 reformule (configuration technique vs consentement utilisateur), principe 9 renforce, principes 13 (expliquer avant de recommander) et 14 (la provenance est visible) ajoutes
- **`docs/PROBLEM.md`** : le probleme enonce cote utilisateur d'abord ; segment primaire par situation, les segments A-F devenant des contextes
- **`docs/ROADMAP.md`** : paliers de capacites validables. Nouveau palier P3, **barriere de validation bloquante**. L'historique remonte avant la recommandation -- la dependance etait inversee. `wisely doctor` renomme **`wisely diagnose`** avant ecriture. Rapport hebdomadaire requalifie CHANGE -> REMOVE
- **`docs/ASSUMPTIONS.md`** : hypotheses A9, A10, A11 ajoutees ; A5 reformulee autour de la frequence des problemes non expliques plutot que des switchs ; **journal de validation** ouvert, avec les experiences E4 et E5
- **`docs/audits/`** (nouveau) : l'audit archive integralement, jamais reecrit, avec un README qui le distingue de `docs/AUDIT.md` (audit qualite du code) et pose la regle -- un audit ne fait jamais foi, et chacun a son ADR de reponse
- `README.md`, `docs/glossary.md`, `docs/CLAUDE.md`, `docs/TASKS.md` et le skill `wisely-conventions` resynchronises

> Aucun changement de code de production. La priorite d'implementation reste **P0 / v2.5 "Verite"**, inchangee : on ne construit ni diagnostic ni recommandation sur une mesure qui ment.

## v2.4.0 - 2026-08-26

### v2.4 - Garde-fou shutdown & refondation documentaire

- Garde-fou WSL2 actif avant `wsl --shutdown` : `Get-WslActiveSessions` et `Confirm-WslShutdown` dans `ProfileManager.ps1`, avec flag `-Force` pour l'usage script/automatise et `Test-WiselyNonInteractive` pour les sessions sans entree utilisateur
- Refondation de l'architecture documentaire : un document par question - `docs/PROBLEM.md` (le probleme, independamment de toute solution), `docs/VISION.md` (la capacite fondamentale), `docs/PRINCIPLES.md` (les criteres d'arbitrage), `docs/DOCTRINE-LECTURE.md` (contrat de lecture dans la distribution Linux, ecrit avant l'implementation), `docs/ASSUMPTIONS.md` (registre des hypotheses non validees)
- `docs/decisions/` : 12 ADR dates et revisables, remplacant le paragraphe monolithique de decisions strategiques de l'ancien ROADMAP
- `docs/ROADMAP.md` reduit a son seul metier (les versions et leur ordre) ; positionnement, principes et decisions deplaces dans les documents dedies
- **Spike Terminal.Gui annule** (et non reporte) : aucun probleme utilisateur adosse, justifie par un document lui-meme perime - voir `docs/decisions/0007-annulation-spike-terminal-gui.md`
- Suppression de `docs/wisely.md` (instantane fige redondant) et du guide TUIStudio (perime) ; l'expose technologique est archive dans `docs/archive/` avec un avertissement
- `docs/refondation-wisely.html` : document de travail de l'analyse strategique (six directions comparees, cartographie du probleme, etat de l'art verifie, roadmap reclassee, hypotheses a valider), conserve comme trace du raisonnement
- `docs/glossary.md`, `docs/CLAUDE.md` et le skill `wisely-conventions` resynchronises sur la nouvelle structure

> Aucun changement de code de production dans la partie documentaire de cette version.

## v2.3.0 - 2026-08-25

### v2.3 - Observabilite

- Suite de tests Pester pour Monitor.ps1, MonitorTask.ps1, WeeklyReport.ps1 (dette technique prealable)
- Metriques reelles post-switch : RAM liberee/consommee (Get-AvailableRamGB) et temps de redemarrage WSL2
- Rapports hebdomadaires enrichis avec la RAM moyenne liberee/consommee par profil au switch
- wisely -Watch : dashboard temps reel (RAM/CPU vmmem, profil actif, derniere alerte)
- Audit general (whole-repo) : 15 constats corriges, 5 reportes au backlog
- Semgrep integre a la CI (scan --config=auto + p/secrets + p/github-actions, sur push/PR et hebdomadaire) en complement de CodeQL
- Actions GitHub epinglees par SHA, injections shell corrigees dans les workflows


## v2.2.0 - 2026-08-21

### v2.2 - DX & Documentation

- Chemins swapFile resolus via variables d'environnement (%TEMP%, %USERPROFILE%, %LOCALAPPDATA%)
- Integrite des reglages : historyMaxEntries, backupEnabled, fix du fallback monitorIntervalSeconds
- Validation JSON Schema de profiles.json en CI (schemas/profiles.schema.json)
- Commande wisely -Status -Short pour l'integration prompt (Oh My Posh, Windows Terminal)
- Commande wisely -Snapshot pour capturer l'etat courant en nouveau profil
- CONTRIBUTING.md et templates d'issue/PR
- README : galerie de profils par usage + snippet Oh My Posh
- Housekeeping : badge de version, doc a jour


## v2.1.0 - 2026-08-20

### v2.1 - Polish & Fiabilite

- Suite de tests Pester (tests/), integree a la CI - dette technique prioritaire du ROADMAP resolue
- Validation du chemin du swap file avant ecriture dans .wslconfig
- Backup versionne avec historique glissant (data/backups/, settings.backupHistoryMax, defaut 5)
- Cache memoise pour Get-ProfileConfig (Clear-ProfileConfigCache)
- Flags -Verbose (diff .wslconfig avant/apres switch) et -Quiet
- Fix du bug de troncature de la barre RAM dans wisely -Status


## v2.0.0 - 2026-03-18

### Architecture
- Refactoring complet : script monolithique -> structure modulaire 5 fichiers
- Profils externalises dans data/profiles.json (plus de code a modifier)
- Separation claire : logique metier / interface / monitoring / reporting

### Phase 1 - Foundation
- Menu interactif a navigation clavier (fleches + Entree)
- Backup automatique de .wslconfig avant chaque switch
- Rollback instantane via wisely -Rollback
- Validation post-ecriture avec rollback automatique si .wslconfig invalide
- Historique complet des operations dans data/history.json
- Mode simulation -DryRun sans ecriture systeme
- Creation de profils personnalises via CLI
- Import / export des profils en JSON

### Phase 2 - Monitoring RAM
- Surveillance RAM WSL2 via tache planifiee Windows (sans terminal ouvert)
- Detection du process vmmem comme proxy de la consommation WSL2
- Alertes Toast Windows natives via API Windows Runtime
- Systeme de cooldown (30 min entre deux alertes)
- Commandes : -Monitor start|stop|status

### Phase 3 - Reporting
- Rapport hebdomadaire automatique chaque lundi a 09h00
- Generation manuelle via wisely -Report
- Contenu : repartition par profil, profil dominant, heure de pointe, derniers switchs
- Sauvegarde dans data/reports/report_YYYY-MM-DD.txt
- Rotation automatique : 12 rapports maximum conserves

### Ameliorations transversales
- Alias global PowerShell wisely (disponible partout sans cd)
- Validation du JSON profiles.json au demarrage avec messages d'erreur actionnables
- Commande wisely -Clean pour purger les fichiers temporaires

---

## v1.0 - Initial

- Switch entre profils WEB (2GB) et DATA SCIENCE (6GB)
- Affichage du profil actif et de la RAM Windows
- Aide utilisateur basique
