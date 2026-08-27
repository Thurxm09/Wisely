# Discipline d'ingenierie et qualite du code -- detail complet

Ce fichier est le complement de la section "Discipline d'ingenierie et qualite du code" de `SKILL.md`. Il ne remplace ni `docs/PRINCIPLES.md` (les criteres d'arbitrage produit), ni `docs/AUDIT.md` (l'etat reel des findings) -- il donne le cadre de raisonnement generique qui s'applique a n'importe quelle modification de code sur ce depot, illustre avec les fichiers et fonctions reels de Wisely.

## Pourquoi ce fichier existe

"Ca marche et la CI est verte" n'est pas un critere suffisant sur ce projet. L'historique d'audit du projet (`docs/AUDIT.md`, ADR associes) montre que du code qui passait les checks a quand meme produit, a un moment donne, des defauts reels -- tous corriges depuis (livres en P0/v2.5), mais dont la lecon reste valable pour tout code nouveau :

- une detection silencieusement inoperante (`VmmemWSL` non reconnu, corrige) ;
- une mesure attribuee au mauvais profil (`ramDeltaGB`, retire) ;
- une ecriture destructive sur un fichier partage (`.wslconfig` reecrit en entier, cles non gerees perdues -- corrige par la fusion via `Set-IniSectionKeys`) ;
- une identification ambigue de l'etat actif (`Get-ActiveProfile` par egalite de valeur RAM -- corrige par le marqueur `[wisely]`) ;
- un `exit` dans un module dot-source qui fermait la session PowerShell entiere de l'utilisateur (finding C-1, corrige de longue date).

Ces cinq exemples couvrent a eux seuls : hypothese non verifiee, erreur d'attribution, effet de bord destructif sur une ressource partagee, ambiguite d'etat, et erreur non maitrisee qui echappe a son perimetre. Ce sont exactement les categories que la discipline ci-dessous vise a empecher de se reproduire.

**Attention a la fraicheur de cette liste** : si un jour un de ces points devait de nouveau etre "non corrige" dans `docs/AUDIT.md` ou dans la section "Etat de l'audit qualite" de `SKILL.md`, verifie l'implementation reelle dans `modules/*.ps1` avant de faire confiance au document -- en cas de divergence, le code fait foi.

## Les criteres de qualite a maximiser simultanement

Pour toute modification, ne te limite pas a "est-ce que ca marche ?". Cherche a maximiser ensemble :

1. **Pertinence** -- la solution repond au besoin reel identifie dans `docs/PROBLEM.md`/`docs/USE-CASES.md`, sans complexite ajoutee.
2. **Clarte** -- comprehensible sans devoir reconstruire mentalement l'intention de l'auteur ; noms explicites, fonctions a responsabilite unique (`Get-ProfileConfig` lit et memoise, `Set-WslProfile` ecrit et bascule -- pas les deux a la fois).
3. **Professionnalisme** -- respecte les conventions PowerShell du projet (section dediee de `SKILL.md`) et les standards d'ingenierie generaux ci-dessous.
4. **Robustesse** -- cas nominal, limites, erreurs et entrees inattendues geres explicitement (ex. `Test-ProfileDefinition` valide un profil avant creation *et* avant import -- la meme fonction, pas deux validations divergentes).
5. **Securite** -- donnees, chemins, droits, dependances traites de facon sure (voir section dediee plus bas).
6. **Fiabilite** -- comportement deterministe et verifiable ; deux executions avec le meme `data/profiles.json` produisent le meme resultat.
7. **Maintenabilite** -- modifiable plus tard sans dette disproportionnee.
8. **Evolutivite** -- ne bloque pas la roadmap (`docs/ROADMAP.md`) ; ex. ne code pas en dur une hypothese que P7 (profils non absolus) devra defaire.
9. **Testabilite** -- couvert par Pester de facon verifiable, pas seulement "ca a l'air de marcher en local".
10. **Observabilite** -- toute erreur ou comportement critique doit pouvoir etre diagnostique. `Write-SwitchLog`/`data/history.json` est le mecanisme d'observabilite existant du projet : une nouvelle erreur importante doit y transiter (ou dans le mecanisme equivalent du module concerne), pas dans un `Write-Host` isole qui disparait de l'historique.
11. **Performance** -- CPU/memoire/disque utilises raisonnablement. `Get-ProfileConfig` memoise deja son resultat (`Clear-ProfileConfigCache` pour invalider) precisement pour eviter de relire `data/profiles.json` a chaque appel -- tout nouveau code qui lit ce fichier doit passer par cette memoisation plutot que de la contourner.
12. **Coherence architecturale** -- respecte les responsabilites existantes : aucun couplage entre modules (`wisely.ps1` orchestre, les modules ne se connaissent pas entre eux -- voir "Carte d'architecture").

Cet ordre n'est pas un classement absolu : quand une contrainte du projet impose un autre arbitrage (ex. un principe de `docs/PRINCIPLES.md` l'emporte), identifie-la explicitement plutot que de l'ignorer silencieusement.

## Methode de raisonnement, en detail

### 1. Comprendre

Avant d'ecrire quoi que ce soit, identifie precisement :

- le comportement attendu et le comportement actuel (relis le fichier concerne, ne suppose pas depuis un resume qui pourrait dater -- meme regle que "Carte d'architecture" dans `SKILL.md`) ;
- les entrees/sorties (ex. un chiffre affiche par `-Status` : d'ou vient-il, quelle classe de mesure selon `docs/RESOURCE-MODEL.md` -- directe/attribuee/estimee/correlee ?) ;
- les contraintes (perimetre de lecture autorise par `docs/DOCTRINE-LECTURE.md`, principes de `docs/PRINCIPLES.md`) ;
- les effets de bord possibles, en particulier sur `.wslconfig` (fichier partage avec Docker Desktop, WSL Settings, l'utilisateur) et sur une session WSL active (`Get-WslActiveSessions`/`Confirm-WslShutdown`) ;
- les zones sensibles : ecriture de fichier, arret de session, taches planifiees Windows (droits admin requis).

### 2. Inspecter

Cherche d'abord si une solution existe deja :

- `docs/PRINCIPLES.md` pour les criteres d'arbitrage deja tranches ;
- `docs/RESOURCE-MODEL.md` pour ce qu'un chiffre a le droit de signifier (ex. ne jamais presenter une somme de RSS comme la RAM consommee, ne jamais parler d'"ecart CPU") ;
- `docs/DOCTRINE-LECTURE.md` pour ce que Wisely a le droit de lire dans Linux ;
- `docs/AUDIT.md` et `decisions/*.md` (ADR) pour comprendre pourquoi le code est ecrit comme il l'est -- un choix qui semble etrange a premiere vue est parfois un correctif deliberement documente (ex. `$Global:WSLRoot` est une exception documentee a la regle `$script:`, pas un oubli) ;
- les fonctions deja presentes dans `modules/ProfileManager.ps1`, `modules/Logger.ps1`, `modules/Monitor.ps1` avant d'en creer une nouvelle ;
- `tests/*.Tests.ps1` pour voir comment un comportement voisin est deja teste.

Prefere systematiquement reutiliser une abstraction coherente avec l'existant plutot que d'en inventer une nouvelle sans necessite.

### 3. Concevoir

Determine la solution la plus simple qui satisfait reellement le besoin, en comparant implicitement les alternatives sur : simplicite, robustesse, securite, lisibilite, maintenabilite, performance, evolutivite. Simple ne veut pas dire naif -- une solution simple doit rester robuste. N'ajoute pas d'abstraction, de dependance ou de configuration qu'aucune situation reelle de `docs/USE-CASES.md` n'exige.

### 4. Implementer

Ecris le code de facon explicite, idiomatique PowerShell, coherente avec les conventions du projet (section dediee de `SKILL.md`), faiblement couplee, testable, et defensive quand c'est necessaire -- pas systematiquement : un `try/catch` qui ne fait qu'emballer une operation qui ne peut pas realistement echouer ajoute du bruit sans robustesse reelle.

### 5. Verifier

Relis ta propre implementation a la recherche de : erreurs non gerees, cas limites (profil inexistant, `data/profiles.json` absent ou corrompu, session WSL deja active), entrees invalides, effets de bord non voulus, regressions sur un profil ou un comportement existant, problemes de concurrence (deux executions de `-Monitor` en parallele, tache planifiee qui chevauche un switch manuel), problemes de performance (lecture repetee de `data/profiles.json` sans passer par la memoisation), incoherences avec l'architecture (un module qui se met a dependre d'un autre).

### 6. Valider

Utilise les mecanismes de validation reellement presents dans ce depot :

- `Invoke-Pester` sur les fichiers `tests/*.Tests.ps1` concernes par le changement ;
- `Invoke-ScriptAnalyzer -Severity Warning` sur tout `.ps1` modifie (memes regles que la CI, voir `.github/workflows/ci.yml`) ;
- la validation de schema (`schemas/profiles.schema.json`, `schemas/history.schema.json`) si `data/profiles.json` ou le format d'historique changent ;
- CodeQL/Semgrep tournent en CI mais ne remplacent pas une relecture manuelle orientee securite avant de pousser.

"Le code semble correct" n'equivaut jamais a une validation.

## Standards par theme

### Gestion des erreurs

Ne masque jamais une erreur importante. Pour toute operation susceptible d'echouer (lecture/ecriture de `.wslconfig`, appel a `wsl.exe`, `Register-ScheduledTask`, parsing JSON) : comment l'echec survient, comment il est detecte, comment il est propage (`throw` dans un module dot-source, jamais `exit` -- deja la regle documentee, et c'etait le finding C-1), si et ou il doit etre journalise (`Write-SwitchLog`), quelles donnees doivent etre preservees avant de propager (ex. backup avant ecriture, deja le pattern de `Backup-WslConfig`). Un `catch` generique qui masque la cause reelle (`catch { }` ou `catch { Write-Host "erreur" }` sans plus) n'est jamais acceptable pour une operation qui touche `.wslconfig`, un profil ou une session WSL.

### Validation des donnees

Traite comme potentiellement invalide toute donnee qui vient de l'exterieur du processus courant :

- `data/profiles.json` (fichier editable a la main par l'utilisateur) -- valide via `Test-ProfileDefinition` et `schemas/profiles.schema.json`, jamais suppose bien forme ;
- la sortie de commandes externes (`wsl.exe`, `Get-Process`, `Get-CimInstance`) -- ne suppose jamais qu'un processus attendu existe (le gap `VmmemWSL`, corrige depuis, etait une consequence directe d'avoir code en dur un seul nom de processus) ;
- `.wslconfig` lui-meme, fichier partage modifiable par Docker Desktop, WSL Settings ou l'utilisateur en dehors de Wisely ;
- toute variable d'environnement ou parametre de configuration.

Valide aux frontieres (a l'entree d'une fonction publique d'un module, pas eparpille dans tout l'appelant) et utilise des contrats explicites (`Test-ProfileDefinition` est deja ce contrat pour un profil).

### Securite

Avant de finaliser une modification, verifie explicitement : pas de secret en dur dans le code (chemins comme `C:\Users\othur\.wslconfig` sont une convention documentee, pas un identifiant sensible -- ne pas confondre) ; les chemins de swap utilisent des slashs forward meme sous Windows ; les operations necessitant des droits admin (`Register-ScheduledTask`/`Unregister-ScheduledTask`) verifient ces droits avant d'agir, comme le fait deja `Monitor.ps1` ; aucune commande externe n'est construite par concatenation de chaines a partir d'une entree non validee (injection de commande) ; les logs (`data/history.json`) ne contiennent pas de donnee sensible ; une erreur remontee a l'utilisateur ne revele pas plus d'information interne que necessaire.

### Performance

N'optimise pas prematurement, mais ne cree pas de probleme evident. `Get-ProfileConfig` memoise deja la lecture de `data/profiles.json` -- tout code qui a besoin de la configuration doit passer par cette fonction plutot que relire le fichier. Un scan repete de processus (`Get-Process`) dans une boucle serree de monitoring doit etre delibere, pas accidentel.

### Couplage et responsabilites

Respecte la regle deja etablie dans "Carte d'architecture" : aucun couplage entre modules, `wisely.ps1` seul orchestre. N'ajoute pas un appel direct d'un module vers un autre (`Monitor.ps1` qui appellerait directement une fonction de `ProfileManager.ps1`, par exemple) sans passer par l'orchestrateur ou sans que ce soit un choix delibere et documente.

### Reutilisation

Avant de creer une nouvelle fonction, verifie que `Get-ProfileConfig`, `Get-ActiveProfile`, `Set-WslProfile`, `Test-ProfileDefinition`, `Resolve-ProfilePaths`, `Get-AvailableRamGB` (dans `ProfileManager.ps1`), ou l'equivalent dans `Logger.ps1`/`Monitor.ps1`, ne couvrent pas deja le besoin. Duplique uniquement si la duplication reduit reellement un risque (pas pour economiser un appel de fonction).

### Compatibilite avec l'existant

Avant de modifier le schema de `data/profiles.json`, le format de `data/history.json`, ou le comportement d'une fonction publique d'un module, identifie les consommateurs (le menu interactif de `wisely.ps1`, les tests Pester, un profil existant deja ecrit sur le disque d'un utilisateur). La retro-compatibilite des profils est un principe historique du projet (section "Principes directeurs") -- une rupture de schema doit etre explicite, motivee, et accompagnee d'une migration si necessaire.

### Tests

Toute nouvelle logique metier significative (nouvelle regle de validation, nouveau calcul de seuil, nouvelle transition d'etat de profil) doit etre accompagnee d'un test Pester dans le fichier `tests/*.Tests.ps1` correspondant au module touche. Les tests doivent verifier des comportements et invariants reels (ex. "un profil dont le nom contient un retour a la ligne est rejete", precedent reel de ce projet -- voir le commit de securite sur les cles de profil), pas simplement augmenter un chiffre de couverture.

## Liste exhaustive des anti-patterns

- Catch silencieux ou generique qui masque la cause reelle d'une erreur.
- Degradation silencieuse vers `$null`/valeur par defaut plutot que signalement explicite de l'echec.
- Recommandation, seuil ou alerte sans la mesure qui la source.
- Reecriture destructive d'un fichier partage (`.wslconfig`) plutot qu'une fusion des cles gerees.
- `exit` dans un module dot-source (`ProfileManager.ps1`, `Logger.ps1`, `Monitor.ps1`).
- Valeur magique/seuil invente dans le code plutot que source depuis `data/profiles.json`/`docs/RESOURCE-MODEL.md`.
- Nouvelle fonction dupliquant une fonction deja presente dans un module existant.
- Extension de perimetre de lecture non documentee dans `docs/DOCTRINE-LECTURE.md`.
- Action destructive (ecriture, arret de session) sans le garde-fou reversibilite/backup deja etabli.
- Logique metier nouvelle sans test Pester correspondant.
- Contournement d'un test qui a revele un bug (skip, note de "limitation connue") plutot que correction de la cause reelle -- voir "Rigueur de diagnostic" dans `SKILL.md`.
- Hypothese non verifiee acceptee comme conclusion ("probablement un probleme d'environnement") sans verification active.
- Couplage direct entre deux modules sans passer par l'orchestrateur `wisely.ps1`.
- Ambiguite d'identification d'etat (deux profils indiscernables par une seule valeur, comme l'ancien comportement de `Get-ActiveProfile` avant le marqueur `[wisely]`).
- Commande externe construite par concatenation de chaines a partir d'une entree non validee.
- Modification de schema ou de contrat public sans identifier ni adapter les consommateurs.

## Checklist de revue interne, en detail

Avant de considerer une modification terminee, verifie explicitement chacun des points suivants et corrige avant de t'arreter si l'un souleve un probleme reel :

1. Ai-je correctement compris le besoin reel (`docs/PROBLEM.md`/`docs/USE-CASES.md`), pas seulement l'enonce litteral de la demande ?
2. Ai-je inspecte l'existant (`docs/PRINCIPLES.md`, `docs/RESOURCE-MODEL.md`, `modules/*.ps1`, `tests/*.Tests.ps1`) avant de creer quelque chose de nouveau ?
3. Ma solution est-elle la plus simple parmi celles qui restent robustes ?
4. Ai-je introduit une complexite, une dependance ou une abstraction non justifiee par un besoin reel ?
5. Les erreurs et cas limites importants sont-ils geres explicitement (pas de `catch` muet, pas de `$null` silencieux, `throw` correct dans un module dot-source) ?
6. Ai-je cree un risque de securite (commande construite par concatenation, droit admin non verifie, donnee sensible loguee) ?
7. Ai-je touche un fichier partage (`.wslconfig`) d'une facon qui pourrait detruire une donnee non geree par Wisely ?
8. Ai-je introduit une regression sur un profil, un comportement ou un contrat existant ?
9. Le changement est-il lisible sans reconstruction mentale de mon intention ?
10. Les responsabilites entre modules restent-elles separees (aucun couplage nouveau non justifie) ?
11. Le comportement important est-il verifiable par un test Pester, et ai-je fait tourner `Invoke-Pester`/`Invoke-ScriptAnalyzer` sur ce que j'ai modifie ?
12. Ai-je modifie uniquement ce qui etait necessaire a la tache, sans changement hors perimetre non signale ?
