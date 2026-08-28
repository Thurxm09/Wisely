# Wisely - Changelog

## Non publie

### P1 / v2.6 "Contrat" -- premiere lecture in-distro, sous consentement explicite

- **Nouveau module `modules/GuestReader.ps1`** : premiere capacite de Wisely a lire *dans* une distribution WSL2 deja demarree, plutot que de se limiter a ce que Windows expose (`vmmem`/`VmmemWSL`, `.wslconfig`). Perimetre deja autorise par ecrit dans `docs/DOCTRINE-LECTURE.md` et `docs/decisions/0008-lecture-in-distro.md`, jamais implemente jusqu'ici
- **Liste fermee de six commandes invite**, une seule constante (`$script:GuestReadCommands`), identique terme a terme a `docs/DOCTRINE-LECTURE.md` §2.3 et `docs/RESOURCE-MODEL.md` §8 : `MemInfo`, `LoadAvg`, `Uptime`, `DiskRoot`, `Nproc`, `ProcRss`. L'application est structurelle, pas seulement documentee -- un seul primitif (`Invoke-GuestProcess`) sait lancer un processus externe, et un seul orchestrateur (`Invoke-GuestRead`) est autorise a l'appeler avec `wsl`, apres validation de la cle contre cette liste
- **Consentement explicite, revocable, desactive par defaut** : `settings.guestReadConsent` (`data/profiles.json`) a deux etats sur disque (`granted`/`revoked`) et trois en comportement -- la cle absente se lit `unset` (jamais demande), ce qui rend le defaut desactive sans toucher au `data/profiles.json` livre ni au schema. Pilotable via `wisely -Consent grant|revoke|status`. Chaque changement journalise une entree `CONSENT` dans l'historique (`Write-SwitchLog`)
- **Degradation propre au refus** : `Invoke-GuestRead` leve une erreur explicite (jamais `$null`, jamais d'estimation de repli) pour une cle hors liste, un consentement `unset`/`revoked` (avec l'instruction exacte `wisely -Consent grant`), ou l'absence de la distribution ciblee parmi les sessions actives -- Wisely ne demarre jamais une distribution arretee
- **`wisely -GuestInfo [-Distro <nom>]`** : premiere lecture utile de `/proc/meminfo`, distinguant `MemAvailableGB` (marge reelle) de `CachedGB` (`Cached` + `Buffers`, recuperable mais pas de la consommation) -- `docs/RESOURCE-MODEL.md` §4.3. Sans `-Distro`, resout via les sessions actives (message explicite si aucune ou plusieurs)
- Aucun changement a `docs/DOCTRINE-LECTURE.md`, `docs/RESOURCE-MODEL.md` ni `data/profiles.json` : ce sont deja des documents de contrat ecrits pour couvrir exactement cette implementation, et l'absence de `guestReadConsent` dans le fichier livre est le defaut voulu
- **Correctif incident** : `Write-SwitchLog` (`modules/Logger.ps1`) ecrivait un objet JSON nu au lieu d'un tableau a une seule entree (`ConvertTo-Json` sans `-AsArray` collabe les tableaux d'un element), violant `schemas/history.schema.json` des le tout premier evenement historise sur une installation neuve. Trouve en developpant la validation de schema de l'entree `CONSENT`, corrige a la racine (`-AsArray` ajoute)
- Developpe en TDD : nouveau `tests/GuestReader.Tests.ps1` (liste fermee, derive doc/code, absence de tout appel `wsl -d` hors du module, consentement, degradation, resolution de distribution, `Invoke-GuestProcess` isole avec timeout/echec/code de sortie non nul, `Invoke-GuestRead` avec le primitif mocke, `ConvertFrom-MemInfo`), extension de `tests/Schema.Tests.ps1` (`guestReadConsent` valide/rejete, entree `CONSENT` reelle contre `schemas/history.schema.json`). 216 cas `It` au total dans la suite (compte statique)
- **Validation dans cette session** : `Invoke-Pester`/`Invoke-ScriptAnalyzer` n'ont pas pu etre executes ici -- PowerShell Gallery (`www.powershellgallery.com`) est bloque par la politique reseau sortante de cet environnement (403 confirme sur le tunnel du proxy). Substitue par verification syntaxique AST (`[System.Management.Automation.Language.Parser]::ParseFile`, ce que fait le syntax-check de la CI), validation `Test-Json` de `schemas/profiles.schema.json`/`schemas/history.schema.json` (documents reels et synthetiques), et scripts de verification fonctionnelle manuels executant le code reel (non mocke, hors `Get-WslActiveSessions`) contre une racine isolee. La CI execute la suite Pester/ScriptAnalyzer complete au push
- Premier des quatre livrables de P1 / v2.6 "Contrat" (`docs/ROADMAP.md`)

### Securite -- injection possible via la cle d'un profil (post P0/v2.5)

- **`Test-ProfileDefinition` validait tous les champs interpoles dans `.wslconfig` sauf la cle du profil elle-meme.** Depuis les correctifs P0/v2.5 "identite du profil actif" et "ecriture non destructive", cette cle est ecrite telle quelle dans une section `[wisely]` de `.wslconfig`. Une cle important un `\r\n` (via `Import-Profiles`, ou affichee/transmise telle quelle par le menu interactif) pouvait injecter une section ou une cle `.wslconfig` arbitraire au switch suivant -- y compris `[wsl2]`/`kernelCommandLine`, sur un fichier de config systeme Windows que `wsl.exe` utilise reellement
- `Test-ProfileDefinition` rejette desormais toute cle contenant `\r`/`\n`, avec le meme mecanisme que les autres champs deja proteges. Couvre `New-CustomProfile` et `Import-Profiles` sans toucher a leurs appelants (point de passage unique depuis v2.3-C-1, `docs/AUDIT.md`)
- Trouve lors d'une revue de code post-fusion du palier P0/v2.5. Developpe en TDD : nouveaux tests sur `Import-Profiles` et `New-CustomProfile`. Suite complete : 180 tests, 0 echec, aucune regression
- Detail complet : `docs/AUDIT.md` (v2.5-C-1)

### v2.5 "Verite" -- cinquieme correctif, cycle termine (ecriture non destructive de .wslconfig)

- **`.wslconfig` n'est plus jamais reecrit entierement, seulement fusionne.** Nouvelle primitive `Set-IniSectionKeys` (`modules/ProfileManager.ps1`) : remplace ou ajoute les cles gerees dans une section INI nommee, sans toucher au reste -- toute autre cle, tout autre commentaire, toute autre section (`autoMemoryReclaim`, `sparseVhd`, `nestedVirtualization`, `[experimental]`, poses par l'utilisateur, Docker Desktop ou WSL Settings) sont preserves tels quels. `ConvertTo-WslConfigContent` l'utilise pour `[wsl2]` (les cinq cles gerees) et pour `[wisely]` (le marqueur d'identite du correctif precedent)
- `Set-WslProfile` lit desormais `.wslconfig` existant **avant** de calculer le contenu a ecrire (au lieu de generer un contenu neuf independamment du fichier), pour que la fusion ait quelque chose dans lequel fusionner
- Debloque la situation S5 (`docs/USE-CASES.md`) et les contextes Docker Desktop et poste d'entreprise (`docs/PROBLEM.md` section 4) -- l'outil etait jusqu'ici activement nuisible pour ces deux contextes, un simple switch de profil detruisant leur configuration `.wslconfig`
- Developpe en TDD : nouveau `Describe "Set-IniSectionKeys"` (6 tests couvrant creation, mise a jour en place, ajout, preservation de cle et de section non gerees, ajout de section absente), tests etendus sur `ConvertTo-WslConfigContent` et sur `Set-WslProfile` (preservation d'une cle et d'une section non gerees lors d'un switch reel). Tous verifies en echec pour la bonne raison avant le correctif
- Suite complete : 178 tests, 0 echec, aucune regression
- **Cinquieme et dernier correctif de P0 / v2.5 "Verite"** (`docs/TASKS.md`) : le cycle est termine. Cinq PR, une par correctif, chacune developpee en TDD. Prochaine priorite : P1 / v2.6 "Contrat" (`docs/ROADMAP.md`)

### v2.5 "Verite" -- quatrieme correctif (identite du profil actif marquee)

- **`Get-ActiveProfile` ne devine plus l'identite par egalite de valeur memoire** : deux profils de meme taille (ex. deux profils a 4GB) etaient indiscernables, et le code retenait arbitrairement le premier du fichier. `ConvertTo-WslConfigContent` marque desormais le profil switche dans une section `[wisely]` dediee de `.wslconfig` (`profile=<cle>`), ajoutee apres la section `[wsl2]`
- Nouveau `Get-WiselyProfileMarker` (`modules/ProfileManager.ps1`) lit ce marqueur ; `Get-ActiveProfile` l'utilise comme source d'identite unique. Sans marqueur (fichier ecrit avant v2.5, ou `.wslconfig` non gere par Wisely), retourne honnetement "Personnalise" plutot que de deviner par coincidence de valeur (principe 9)
- Si le marqueur pointe vers une cle de profil qui n'existe plus (renommee ou supprimee depuis), le signale explicitement plutot que de se rabattre en silence
- Developpe en TDD : tests reecrits sur `Get-ActiveProfile` (marqueur present, absent, profil introuvable, deux profils de memoire identique correctement distingues), nouveaux tests directs sur `ConvertTo-WslConfigContent`, test bout-en-bout confirmant qu'un switch reel est ensuite reconnu par `Get-ActiveProfile`. Fixture de `Monitor.Tests.ps1` mise a jour (dependait implicitement de l'ancienne identification par memoire)
- Suite complete : 169 tests, 0 echec, aucune regression
- Quatrieme des cinq correctifs de P0 / v2.5 "Verite" (`docs/TASKS.md`) ; un dernier reste a faire (ecriture non destructive de `.wslconfig`)

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
