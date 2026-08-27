# Principes produit — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> comment trancher un arbitrage sans rouvrir le débat à chaque fois ?
>
> Ces principes sont des **critères de conception**, pas des règles de style. Une
> proposition qui en viole plusieurs simultanément ne doit pas être implémentée,
> quel que soit son attrait technique. Les conventions de code vivent dans
> `CONTRIBUTING.md`, pas ici.
>
> Statut : vivant. Dernière révision : 2026-08-27.

---

## Les principes historiques

Repris de l'ancien `ROADMAP.md` §9, où ils étaient noyés dans un document qui
faisait cinq métiers à la fois. Ils ont tenu et restent valides.

### 1. Zéro configuration technique obligatoire pour obtenir la première valeur

Un utilisateur qui installe l'outil doit pouvoir l'exécuter immédiatement, sans
modifier aucun fichier. La personnalisation est possible, jamais obligatoire.

> **Révision 2026-08-27.** La formulation d'origine — « zéro configuration requise
> pour commencer » — entrait en collision frontale avec le consentement explicite
> de la lecture invitée (`DOCTRINE-LECTURE.md` §2.5), qui est un geste demandé à
> l'utilisateur avant toute valeur. Il faut distinguer deux choses que le mot
> « configuration » confondait :
>
> | | Statut |
> |---|---|
> | **Configuration technique** — éditer un fichier, poser des valeurs, calibrer | À éviter. C'est le principe |
> | **Consentement et contrôle** — autoriser une lecture, choisir une profondeur de diagnostic, révoquer | **Légitime, et souhaitable.** Un outil qui entre dans le Linux de quelqu'un doit demander |
>
> Ce ne sont pas des préférences à minimiser : ce sont des décisions que
> l'utilisateur a le droit de prendre. Ce qui doit rester à zéro, c'est le travail
> technique exigé **avant** la première réponse utile.

> **Révision 2026-08-26.** Ce principe était en contradiction ouverte avec les
> profils livrés : trois valeurs absolues en gigaoctets calibrées sur une machine
> 16 Go ne peuvent pas être un défaut raisonnable sur une machine 8 Go ou 64 Go.
> Un défaut qui n'est valable que sur une seule configuration matérielle n'est pas
> un défaut, c'est une préférence personnelle. La conséquence est actée dans
> `decisions/0006-profils-derives.md`.

### 2. Réversibilité systématique

Toute action modifiant l'état du système doit être réversible. Aucune opération
destructive irréversible sans confirmation explicite. Le backup existe pour les
fichiers, les logs pour les actions.

### 3. Échouer vite et bruyamment

Une erreur vaut mieux qu'un comportement silencieux incorrect. Fichier manquant,
JSON invalide, droits insuffisants : le dire clairement, immédiatement, avec ce
qu'il faut faire.

> **Révision 2026-08-26.** Ce principe avait une exception non écrite qui l'a vidé
> de son sens : les métriques « optionnelles » retournaient `$null` en silence en
> cas d'échec, pour ne jamais faire échouer l'appelant. Résultat, trois
> défaillances totales de la couche d'observation sont restées invisibles pendant
> toute la vie du projet. Voir le principe 9.

### 4. Scriptabilité de première classe

Toute action réalisable via le menu interactif doit l'être en commande directe,
avec des codes de sortie standard. Les scripts d'automatisation sont des citoyens
de première classe.

### 5. Source de vérité unique

`data/profiles.json` reste la seule source de vérité des profils et réglages.
Aucun comportement métier variable ne doit être codé en dur. Les constantes
techniques (noms de tâches planifiées, clés requises) sont des exceptions
acceptables.

### 6. Minimalisme fonctionnel

Chaque fonctionnalité doit justifier sa présence par une valeur utilisateur
documentée. « C'est faisable » et « c'est intéressant » ne sont pas des
justifications. La question à poser : combien d'utilisateurs réels en ont besoin,
et à quelle fréquence ?

> **Complément 2026-08-26.** Ce principe s'applique aussi à la suppression. Une
> fonctionnalité déjà écrite qui ne survit pas à cette question doit être retirée,
> pas conservée par respect pour le travail investi.

### 7. Compatibilité descendante des profils

Une mise à jour ne doit jamais casser un `profiles.json` existant. Les nouvelles
clés sont optionnelles avec des défauts documentés. Une migration automatique est
proposée si le schéma évolue de façon incompatible.

---

## Les principes ajoutés

Chacun est né d'une défaillance constatée dans le code, pas d'une intuition. Ils
sont formulés pour que la même erreur ne puisse pas se reproduire sous une autre
forme.

### 8. Ne jamais détruire ce qu'on ne gère pas

Wisely écrit dans un fichier partagé. `.wslconfig` peut contenir des réglages
posés par l'utilisateur, par Docker Desktop, par WSL Settings ou par une
politique d'entreprise : `networkingMode`, `dnsTunneling`, `autoMemoryReclaim`,
`sparseVhd`, `nestedVirtualization`, `vmIdleTimeout`, une section
`[experimental]`.

**Wisely ne touche qu'aux clés qu'il gère, et laisse le reste intact.** Cela vaut
pour tout fichier, tout réglage système et toute tâche planifiée que l'outil n'a
pas créés lui-même.

> *Origine :* `ConvertTo-WslConfigContent` régénérait le fichier entier à partir
> de cinq champs, effaçant silencieusement tout le reste au premier switch —
> **corrigé en P0/v2.5** (fusion via `Set-IniSectionKeys`, plus jamais de
> réécriture complète). `Test-WslConfigIntegrity` continue de ne vérifier que
> les trois clés que Wisely gère lui-même ; ce n'est plus un filet de sécurité
> manquant puisque l'écriture ne détruit plus le reste, mais elle ne peut pas
> non plus détecter une perte causée par autre chose que Wisely.

### 9. Toute mesure porte sa portée, sa source, sa fraîcheur et sa confiance

Une mesure doit pouvoir désigner ce qu'elle mesure. Si une grandeur ne peut pas
être rattachée à sa cause, elle ne doit pas être affichée comme si elle l'était.

Corollaire opérationnel : **une mesure qui échoue doit le dire**. Une métrique
dégradée en `$null` silencieux est pire que pas de métrique du tout, parce
qu'elle est indiscernable d'une valeur nulle légitime.

> **Renforcement 2026-08-27.** « Attribuable ou non » est une distinction trop
> grossière. Toute grandeur affichée appartient à **une** de quatre classes, et sa
> classe est visible côté utilisateur :
>
> | Classe | Ce qu'on a le droit d'en dire |
> |---|---|
> | **Directe** | « C'est la valeur » |
> | **Attribuée** | « C'est ce qui est rattachable à X », jamais « c'est ce que X consomme » |
> | **Estimée** | « Estimation, sous telle hypothèse » — l'hypothèse est nommée |
> | **Corrélée** | « Observé en même temps », jamais « causé par » |
>
> Deux règles dures en découlent, toutes deux issues de pièges réels :
>
> 1. **La somme des RSS n'est jamais présentée comme égale à la RAM consommée.**
>    Les pages partagées sont comptées dans chaque processus qui les mappe. Toute
>    vue d'attribution affiche sa ligne « non attribué ».
> 2. **Il n'y a pas d'écart CPU.** `loadavg` n'est pas un pourcentage, `nproc` ne
>    mesure aucun usage, et le CPU de la machine virtuelle côté Windows n'a pas la
>    même sémantique que la charge invitée.
>
> Le détail par ressource vit dans `RESOURCE-MODEL.md`, qui est à ce principe ce
> que `DOCTRINE-LECTURE.md` est au principe 12.

> *Origine :* `ramDeltaGB` mesurait la RAM libérée par l'arrêt de WSL2, mais
> l'attribuait au profil cible dans le rapport hebdomadaire ; le seuil d'alerte
> comparait la part de WSL2 dans la RAM **totale** à un seuil pensé pour la part
> de son **plafond** ; et `Get-Process -Name "vmmem"` ne trouvait rien sur
> Windows 11 récent, où le processus s'appelle aussi `VmmemWSL` — trois échecs
> silencieux, tous **corrigés en P0/v2.5** (`ramDeltaGB` retiré, seuil rapporté
> au plafond `.wslconfig`, les deux noms de processus désormais recherchés).

### 10. Aucune recommandation sans la mesure qui la source

Wisely ne dit jamais « mets 6 Go ». Il dit « 6 Go, parce que ton pic mesuré sur
14 jours est 5,4 Go, atteint trois fois ». La recommandation porte sa preuve.

Ce n'est pas de la politesse : c'est ce qui rend une recommandation
**réfutable**, donc digne de confiance. Un outil qui touche à la configuration
système de quelqu'un ne peut pas demander une adhésion aveugle.

Corollaire : si la mesure n'est pas disponible ou pas fiable, **il n'y a pas de
recommandation** — pas de recommandation par défaut, pas de valeur « raisonnable »
sortie de nulle part.

### 11. Annoncer le coût avant de le faire payer

L'action centrale de Wisely interrompt tout l'environnement Linux en cours.
C'est la propriété la plus dangereuse du produit. Avant toute opération
destructive, l'outil dit **ce qui va être perdu**, précisément.

> *Origine :* `Confirm-WslShutdown` (v2.4) fait la moitié du chemin — il signale
> que des distributions tournent, sans dire ce qui s'y exécute. Ce principe pose
> la direction : plus l'outil voit clair, plus l'avertissement doit être précis.

### 12. La confiance se déclare avant de s'exercer

Toute capacité qui étend la portée de Wisely — lire dans une distribution Linux,
écrire ailleurs que dans `.wslconfig`, envoyer quoi que ce soit sur le réseau —
doit être documentée **avant** d'être implémentée, avec ce qu'elle fait et ce
qu'elle ne fera jamais.

Voir `DOCTRINE-LECTURE.md`, écrit avant la ligne de code correspondante.

### 13. Expliquer avant de recommander

L'explication est un livrable en soi, pas la note de bas de page d'une
recommandation. L'utilisateur doit pouvoir comprendre son état **même quand
aucune action n'est recommandée** — et « tout va bien, voici pourquoi » est une
réponse de plein droit.

Ce principe complète le 10 sans le doubler : le 10 exige qu'une recommandation
porte sa preuve ; le 13 exige que l'explication vaille sans recommandation.

> *Origine :* l'ancienne boucle disait « observer → **comprendre** → décider ».
> Ce mot rangeait le travail le plus difficile dans la tête de l'utilisateur, où
> il n'était ni construit, ni testé, ni ratable. C'est exactement là que se trouve
> la douleur : « Task Manager + WSL Settings + htop » donnent tous les chiffres,
> et personne ne fait la jointure.

### 14. La provenance est visible

Toute clé de `.wslconfig` affichée indique si Wisely la gère ou non. Pas « qui a
écrit cette ligne » — cette information n'est pas connue et ne doit pas être
inventée — mais :

```text
memory              8GB       gérée par Wisely
processors          8         gérée par Wisely
networkingMode      mirrored  externe
autoMemoryReclaim   gradual   externe
```

C'est la face lisible du principe 8. Le 8 garantit qu'on ne détruit pas ce qu'on
ne gère pas ; le 14 le rend **vérifiable par l'utilisateur** au lieu d'exiger
qu'il le croie. C'est ce qui rend la coexistence avec Docker Desktop, WSL
Settings et une politique d'entreprise réellement crédible.

---

## Comment utiliser ces principes

Devant une proposition, les questions dans l'ordre :

1. Sert-elle un des **quatre objets** — État, Cause, Politique, Action — pour un
   **maillon nommé** de la boucle (`VISION.md`) ? Lequel ? Un mécanisme
   générique qui pourrait servir n'importe quel objet selon ce qu'on y
   brancherait ne compte pas comme réponse valide.
2. Quelle case de la carte du problème remplit-elle (`PROBLEM.md` §3), et quelle
   **situation** sert-elle (`USE-CASES.md`) ?
3. Tombe-t-elle dans un des **non-buts** déclarés (`VISION.md`) ?
4. Viole-t-elle un principe ci-dessus ? Lequel, et est-ce assumé et écrit ?
5. Repose-t-elle sur une hypothèse non validée (`ASSUMPTIONS.md`) ? Si oui, la
   valider coûte-t-il moins cher que de construire ?

Une réponse absente à la question 1 ou 2 est un signal d'arrêt, pas un détail à
préciser plus tard.

> **Note 2026-08-27, corrigée le même jour.** La question 1 disait auparavant
> « s'exprime-t-elle comme une opération sur l'écart ? ». En requalifiant
> l'écart, il fallait le remplacer par un filtre au moins aussi tranchant, et non
> le diluer — voir `decisions/0013-adoption-audit-strategique-externe.md`. Un
> rejeu rigoureux (voir la note sous « Le filtre de périmètre » dans
> `VISION.md`) a montré que l'affirmation initiale — « ce test a écarté le spike
> Terminal.Gui, les hooks et `-Snapshot` » — était fausse : ces trois passent en
> réalité les questions 1 à 3 sans effort, et ont été écartés par les questions 4
> et 5 ci-dessous, pas par le filtre de `VISION.md`.
