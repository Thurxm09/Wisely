# Hypothèses — ce que nous croyons sans l'avoir vérifié

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> sur quoi repose la stratégie, et qu'est-ce qui n'est pas prouvé ?
>
> Une bonne stratégie sait nommer ses inconnues. Ce registre existe pour que les
> hypothèses ne se transforment pas silencieusement en faits à force d'être
> répétées dans les documents.
>
> **Règle d'usage :** aucune hypothèse de ce document ne doit être citée comme un
> fait dans une décision produit tant que sa colonne « statut » indique
> `non testée`.
>
> Statut : vivant, à réviser à chaque cycle. Dernière révision : 2026-09-03.

---

## Contexte : ce que nous ne savons vraiment pas

Wisely a **zéro utilisateur réel**, zéro retour, zéro télémétrie — et la
télémétrie n'est pas envisagée (voir `DOCTRINE-LECTURE.md` §2.4). Le projet a été
annoncé publiquement une fois, le 2026-09-01 sur X et Bluesky, et **cette annonce
n'a atteint personne** : 6 vues cumulées (X : 6, Bluesky : 0), aucun retour, aucun fork (voir
E3a). Elle ne change donc rien à ce constat, et c'est précisément ce qu'elle
établit.

Cela a une conséquence directe et inconfortable : **tout ce qui, dans
`PROBLEM.md`, concerne les utilisateurs est une hypothèse**, y compris les
segments présentés avec une « confiance haute ». La confiance y désigne la
solidité du raisonnement, pas l'existence d'une preuve.

Ce qui est en revanche **factuel et vérifié** : les constats portant sur le code
(`AUDIT.md`), et l'état de l'écosystème WSL2 vérifié en août 2026 (`PROBLEM.md`
§5).

---

## Registre

Classement par **Impact × Incertitude**. L'impact mesure ce qui s'effondre si
l'hypothèse est fausse ; l'incertitude, notre ignorance actuelle.

| # | Hypothèse | Impact | Incertitude | Statut |
|---|---|---|---|---|
| **A1** | Quelqu'un d'autre que le mainteneur a ce problème assez fort pour installer un outil | Maximal | Maximale | non testée |
| **A9** | Le diagnostic a plus de valeur que le switch | Maximal | Maximale | non testée |
| **A12** | La valeur perçue du diagnostic survit à sa première utilisation | Maximal | Maximale | non testée |
| **A13** | Il existe un contexte où quelqu'un paierait pour cette capacité | Fort | Maximale | non testée |
| **A2** | `autoMemoryReclaim` n'a pas déjà résolu la moitié « RAM » du problème fondateur | Fort | Forte | non testée |
| **A5** | Le coût du `wsl --shutdown` est acceptable, et les gens rencontrent des problèmes de ressources assez souvent | Fort | Forte | **testable immédiatement** |
| **A10** | L'attribution Windows → distribution → processus change réellement la décision de l'utilisateur | Fort | Forte | non testée |
| **A11** | Une recommandation sourcée par la mesure suffit à déclencher une action | Fort | Forte | non testée |
| **A3** | L'état des ressources est mesurable assez précisément pour fonder une recommandation | Fort | Modérée | non testée |
| **A4** | Les utilisateurs acceptent qu'un outil Windows lise dans leur distribution Linux | Fort | Modérée | non testée |
| **A6** | La douleur disque dépasse la douleur RAM | Modéré | Forte | non testée |
| **A7** | Le public non-développeur est atteignable par un outil en ligne de commande | Modéré | Forte | non testée |
| **A8** | Les utilisateurs multi-distributions ont besoin d'une attribution par distribution, plutôt qu'un plafond unique WSL2 toutes distros confondues | Modéré | Forte | non testée |

> **A9, A10 et A11 sont nées de l'adoption de l'audit d'août 2026**
> ([0013](decisions/0013-adoption-audit-strategique-externe.md)). Ce sont
> exactement les paris que cette adoption engage : elles doivent donc figurer ici,
> et non être citées comme des acquis parce qu'une décision les suppose.

> **A12 et A13 sont nées le 2026-09-03**, quand la finalité du projet a été
> énoncée comme « produit, à terme monétisable ». Elles sont ici pour la même
> raison que les précédentes : une finalité qui suppose une valeur récurrente et
> un consentement à payer engage deux paris, et un pari non écrit devient un fait
> à force d'être répété. Aucune décision de monétisation n'est prise ni préparée
> par leur présence — elles sont testables **au coût marginal nul** dans les
> mêmes sessions qu'A9 et A11, ce qui est la seule raison de les ouvrir
> maintenant plutôt qu'après la barrière P3.

---

## Détail des hypothèses critiques

### A1 — Il existe un public

**Ce qu'elle affirme.** Le problème décrit dans `PROBLEM.md` est ressenti par
d'autres personnes, assez fortement pour qu'elles installent et gardent un outil.

**Ce qui s'effondre si elle est fausse.** Tout. La roadmap, la refondation, la
distribution. Wisely resterait un excellent outil personnel — conclusion
parfaitement honorable, mais qui change complètement l'investissement à y
consacrer.

**Ce qui la rend plausible.** Le volume d'articles écrits pour répondre à
« VmmemWSL high memory » ; l'existence de plusieurs outils tiers attaquant le
même problème.

**Ce qui la fragilise.** Aucun de ces outils tiers n'a de traction, y compris
ceux plus accessibles qu'un script PowerShell à cloner. Cela peut signifier que
la catégorie est mal exécutée — ou que la douleur est réelle mais trop faible
pour motiver l'installation d'un outil, les gens s'en accommodant.

**Comment la tester.** Expérience E3 ci-dessous.

### A9 — Le diagnostic a plus de valeur que le switch

**Ce qu'elle affirme.** Comprendre pourquoi WSL2 consomme ce qu'il consomme est
plus utile, plus souvent, que changer facilement de plafond.

**Ce qui s'effondre si elle est fausse.** Le pivot stratégique du 2026-08-27. Si
le switch reste le geste dominant, Wisely redevient un commutateur — meilleur que
les autres, mais dans une catégorie que WSL Settings et plusieurs outils tiers
occupent déjà.

**Ce qui la rend plausible.** Personne n'écrit « mon plafond WSL2 est mal
réglé » ; les gens écrivent « VmmemWSL consomme 9 Go », ce qui est une question
d'attribution. Le volume d'articles écrits pour répondre à cette question est le
seul signal de demande dont le projet dispose.

**Ce qui la fragilise.** Un diagnostic se consomme une fois. Un outil qu'on lance
une seule fois n'est pas un produit — mais c'est un signal, et c'est précisément
ce que l'expérience E3 mesure.

**Comment la tester.** Expérience E3, plus la mesure comparative E4.

**Note importante :** cette hypothèse est prise **sans** être validée, et
assumée comme telle. La décision 0013 est meilleure que ses alternatives quelle
que soit la réponse — même si le switch domine, un outil qui explique ce qu'il
mesure vaut mieux qu'un outil qui affiche des chiffres dont il ignore le sens.

### A12 — La valeur survit à la première utilisation

**Ce qu'elle affirme.** Un utilisateur qui a lancé `wisely diagnose` une fois a une
raison de le relancer — parce que la question « pourquoi WSL2 consomme ce qu'il
consomme » se repose, ou parce que le diagnostic a révélé quelque chose qui
demande un suivi.

**Ce qui s'effondre si elle est fausse.** La finalité « produit ». Un outil qu'on
lance une fois, qui donne sa réponse et qu'on oublie est un **service rendu**, pas
un produit : il ne soutient ni rétention, ni relation, ni modèle économique. Ce
serait une conclusion honorable et parfaitement défendable — mais elle change
l'investissement à consacrer au projet, exactement comme A1.

**Ce qui la fragilise.** `ASSUMPTIONS.md` le disait déjà en défendant A9 : *« un
diagnostic se consomme une fois »*. Cette phrase était une objection à A9 ; elle
devient ici l'hypothèse centrale, parce que la finalité a changé.

**Ce qui la rend plausible.** L'état de WSL2 n'est pas stable : un projet qui
grossit, un conteneur ajouté, une mise à jour de WSL déplacent le problème. Et
P4 (l'historique) transformerait un instantané en série — c'est-à-dire
précisément une raison de revenir. Mais **P4 est derrière la barrière P3** : on ne
peut pas construire la réponse avant d'avoir mesuré la question.

**Comment la tester.** Le champ « le relanceriez-vous ? » du formulaire de retour
éclair, croisé avec les réutilisations réellement rapportées d'E3b. Une intention
déclarée n'est pas une réutilisation : les deux se comparent, et l'écart est le
résultat.

### A13 — Il existe un contexte où quelqu'un paierait

**Ce qu'elle affirme.** Au moins un contexte d'usage — poste d'entreprise, parc de
machines, support interne, prestation — attribue à cette capacité une valeur
supérieure à son coût d'acquisition.

**Ce qui s'effondre si elle est fausse.** Rien de technique. Uniquement la finalité
commerciale, qui redeviendrait « excellent outil open source ».

**Ce qui la fragilise, et il faut le dire franchement.** Deux choses, aujourd'hui
non résolues :

1. **La licence GPL-3.0** et la distribution par `git clone` contraignent
   fortement les modèles possibles. Ce n'est pas rédhibitoire — l'open core,
   l'hébergement, le support et la double licence existent — mais aucune de ces
   voies n'est ouverte par défaut, et certaines exigeraient une décision de
   licence prise **avant** toute contribution externe significative.
2. **Le segment individuel est le moins solvable** de ceux que `PROBLEM.md`
   décrit. Un développeur qui règle son `.wslconfig` deux fois par an ne paie pas
   pour un diagnostic ; une DSI qui gère 400 postes WSL2 pourrait payer pour une
   flotte — mais ce contexte n'a jamais été observé, et il dépend d'A1 avant tout
   le reste.

**Ce qui ne doit pas se produire.** Que cette hypothèse déforme le produit avant
d'être testée. Aucune fonctionnalité, aucun découpage, aucune restriction ne se
justifie par A13 tant qu'elle reste `non testée` — c'est la règle d'usage en tête
de ce document, et elle s'applique ici avec une force particulière.

**Comment la tester.** Sans jamais demander « combien paieriez-vous ? », question
qui ne mesure que la politesse. Deux questions ouvertes dans les sessions
qualitatives : *dans quel contexte professionnel ce problème coûte-t-il de
l'argent aujourd'hui ?* et *qui, chez vous, décide de ce genre d'outil ?* Un
contexte solvable se raconte ; il ne se coche pas.

**Décision à ne pas prendre maintenant.** Tout choix de licence ou de modèle
économique. Il appartiendra à un ADR, argumenté, quand A1 et A12 auront un statut.

### A2 — La plateforme n'a pas déjà résolu le problème

**Ce qu'elle affirme.** `autoMemoryReclaim` ne suffit pas à rendre inutile la
gestion du plafond mémoire.

**Ce qui s'effondre si elle est fausse.** La moitié « RAM » de la proposition de
valeur. La boucle devrait se recentrer sur l'attribution et sur le disque, qui
ne bénéficient pas d'une atténuation équivalente.

**Ce qui la fragilise.** Le réglage existe depuis WSL 2.0 et rend la mémoire
cache inactive à Windows automatiquement. C'est une réponse directe au grief
fondateur du projet — « laisser WSL2 consommer 6 Go en permanence est inutile ».

**Ce qui la soutient.** Le réglage n'est pas actif par défaut, la plupart des
utilisateurs en ignorent l'existence, et des interactions négatives avec zswap
sont documentées. Même si l'hypothèse tombe, une opportunité subsiste : dire à
l'utilisateur que ce réglage existe, qu'il est éteint, et ce qu'il changerait
chez lui.

**Comment la tester.** Expérience E2 ci-dessous.

### A5 — Le geste central est acceptable

**Ce qu'elle affirme.** Payer un arrêt complet de l'environnement Linux — perdre
serveurs de développement, notebooks, compilations, conteneurs en cours — est un
prix que les utilisateurs acceptent de payer, assez souvent pour qu'un outil de
changement de profil ait un sens.

**Ce qui s'effondre si elle est fausse.** Le maillon « agir », c'est-à-dire le
seul que le projet détient aujourd'hui. Si les gens ne changent de profil que
deux ou trois fois par an, le produit n'est pas un commutateur : c'est au mieux
un outil de réglage initial, et toute la valeur bascule vers le diagnostic.

**Pourquoi elle est prioritaire.** C'est la seule hypothèse à fort impact
**testable en dix minutes, avec des données déjà présentes sur la machine du
mainteneur.**

> **Reformulation 2026-08-27.** La question posée à l'origine — « à quelle
> fréquence les gens changent-ils de profil ? » — mesure l'usage d'une
> fonctionnalité, pas l'existence d'un marché. La bonne question est :
> **« à quelle fréquence rencontrent-ils un problème de ressources WSL qu'ils ne
> savent pas expliquer ou résoudre facilement ? »** Trois changements de profil
> par an et quinze incidents non expliqués par mois racontent deux produits
> complètement différents — et c'est le second chiffre qui décide.

---

## Les expériences

### E1 — Lire `data/history.json` · dix minutes · teste A5

Compter les entrées `SWITCH` réellement enregistrées depuis la mise en service,
leur répartition dans le temps, et la proportion de profils réellement utilisés.

**Comment lire le résultat :**

- Des changements réguliers (plusieurs par semaine) confirment A5 : le geste vaut
  son prix, le commutateur a un sens — et A9 s'en trouve affaiblie.
- Trois changements en un an infirment A5 de la manière la plus économique
  possible. Ce serait le résultat le plus important de toute l'analyse
  stratégique — et il est déjà sur le disque.
- Un seul profil réellement utilisé sur les trois livrés invalide au passage la
  pertinence du découpage par métier.

**Biais à garder en tête :** un échantillon d'une personne, qui est aussi
l'auteur de l'outil, donc l'utilisateur le plus motivé possible. Un résultat
faible est concluant ; un résultat élevé ne prouve rien pour les autres.

### E2 — Activer `autoMemoryReclaim=gradual` pendant une semaine · teste A2

Poser le réglage, ne rien changer d'autre, et observer si le besoin de descendre
le plafond mémoire diminue.

**Comment lire le résultat :** si le besoin disparaît, la plateforme a résolu la
moitié RAM du problème, et la boucle doit se recentrer sur l'attribution et le
disque. Si le besoin subsiste, A2 tient et la direction est confirmée.

**Note :** cette expérience est aussi un test grandeur nature du principe 8
(`PRINCIPLES.md`) — dans l'état actuel du code, le premier changement de profil
effacera ce réglage.

### E3 — Publier le diagnostic seul · teste A1 et A9

Publier la commande de diagnostic sans le reste, et observer si quelqu'un
l'utilise.

**Pourquoi ce test est le bon.** Il ne demande aucun engagement : pas
d'installation permanente, pas de modification système, pas de confiance
préalable. Il mesure donc un intérêt réel plutôt qu'une politesse. Un outil
qu'on lance une fois et qu'on ne réutilise jamais est un signal aussi
informatif qu'un outil adopté.

**À ne pas confondre avec un lancement.** Ce n'est pas la distribution large,
délibérément repoussée (voir `decisions/0009-distribution-apres-le-produit.md`).

Cette expérience a été menée une première fois puis **arrêtée sans conclure**.
Elle se lit désormais en deux temps.

#### E3a — première tentative · arrêtée le 2026-09-03, non concluante

Publiée sur X et Bluesky le 2026-09-01, fenêtre prévue jusqu'au 2026-09-29.
**Arrêtée avant son terme, sans résultat**, pour une raison qui n'a rien à voir
avec l'outil : l'exposition mesurée des deux publications est **inférieure à 50
vues cumulées**.

**Pourquoi c'est un arrêt et non un échec.** Un zéro obtenu sur un dénominateur
inconnu ne réfute rien. Il aurait dit « personne n'a vu », pas « personne n'en a
besoin » — et il aurait été consigné comme un signal contre A1, ce qui aurait été
faux. Attendre le 2026-09-29 pour obtenir cette non-information était un coût pur.

**Ce que l'arrêt établit malgré tout, et qui est utile :** le projet ne disposait
d'aucune chaîne de mesure de l'exposition, ni d'aucun chemin de retour utilisable.
Publier sans les avoir, c'était mesurer avec un instrument absent. C'est le vrai
enseignement d'E3a, et il est entièrement attribuable.

**A1 et A9 restent `non testées`.** Aucun statut n'est déduit d'E3a.

**Bonne nouvelle, à ne pas perdre de vue :** avec seulement 6 vues cumulées, le lancement
unique que protège [0009](decisions/0009-distribution-apres-le-produit.md) **n'a
pas été dépensé.**

#### E3b — seconde tentative · conditions de validité fixées d'avance

Identique dans son principe, corrigée sur les deux points qui ont fait échouer la
mesure : un dénominateur, et des chemins de retour.

**Conditions de validité — nouveauté, et le point important.** E3b comporte deux
seuils, et l'ordre compte :

1. **Un seuil de validité de la mesure**, sans lequel le résultat n'est pas
   interprétable : ≥ 300 impressions cumulées et ≥ 40 visites uniques sur la page
   testeurs. S'il n'est pas atteint, l'expérience est **de nouveau non
   concluante** — on ajoute des canaux, on ne conclut pas.
2. **Un seuil de succès** sur l'hypothèse elle-même : ≥ 5 essais distincts
   rapportés et ≥ 1 réutilisation, sous 4 semaines.

Cette distinction est ce qui manquait à E3a. Un seuil de succès sans seuil de
validité laisse un résultat nul se faire passer pour une réfutation.

**Chaîne de mesure**, sans télémétrie (`DOCTRINE-LECTURE.md` §2.4) : impressions
relevées à la main sur chaque canal → visites de la page testeurs par lien taggé
(PostHog, côté site) → clones et vues uniques (API GitHub Traffic) → retours
déclarés (formulaires, discussions). Détail dans `RECRUITMENT.md` §6 *(privé — `Thurxm09/dotfiles`)*.

**Limite connue et assumée.** L'analytique du site est configurée sans cookie ni
`localStorage` : elle mesure l'exposition et le premier clic, **jamais le retour
d'un visiteur**. La réutilisation ne sera donc connue que par déclaration. Ce
renoncement est cohérent avec l'absence de bannière de consentement ; il n'est pas
un défaut à corriger, mais une limite à énoncer plutôt qu'à contourner.

### E6 — Recruter directement des testeurs · teste A9, A10, A11, A12, A13

E4 et E5 exigent au moins cinq personnes déjà recrutées. E3b ne les fournit pas :
elle mesure des essais, pas des volontaires.

Recruter 8 à 15 testeurs par le canal explicite du formulaire de retour éclair
(« accepteriez-vous 20 minutes d'échange ? »), en priorisant les personas de
`RECRUITMENT.md` §1 *(privé)* dans l'ordre P1 > P3 > P2.

**Comment lire le résultat.** Le taux de volontariat parmi ceux qui ont donné un
retour est lui-même un signal sur A1 : quelqu'un qui accepte de donner vingt
minutes a un problème réel, pas une curiosité. Un taux nul avec des retours
positifs est une contradiction utile — et signalerait de la politesse plutôt que
du besoin.

**Pourquoi E6 ne recycle pas le protocole Niveau B du site.** Un volontaire E6 a par
construction déjà utilisé `wisely diagnose` — c'est ce que la case du formulaire
présuppose. Le protocole Niveau B de `wisely-site`
(`docs/validation/protocoles/niveau-b-test-qualitatif.md`) élimine explicitement ce
profil : sa cinquième question de screener est « As-tu déjà entendu parler d'un outil
appelé Wisely ? *(une réponse positive écarte le participant)* » (§1), et sa règle de
conduite centrale précise « Ne jamais expliquer Wisely avant l'exposition initiale. —
C'est la seule chose que la session mesure. Elle ne se rejoue pas. » (§3). Un testeur
E6 a déjà eu son exposition initiale ; la rejouer ne mesurerait rien. Écart secondaire,
qui aurait de toute façon rendu la fusion intenable : le formulaire de recrutement E6
annonce « accepteriez-vous 20 minutes d'échange ? », alors que le déroulé Niveau B seul
est titré « Déroulé — 25 minutes » (§4) — sans compter le screener et le consentement
qui le précèdent. Les deux programmes de validation restent donc délibérément séparés.

### E4 — Temps pour identifier la cause · teste A9 et A10

Donner à quelqu'un une machine dont WSL2 consomme anormalement, et mesurer le
**temps nécessaire pour identifier la cause probable** avec trois outillages :
Gestionnaire des tâches seul, `htop` seul, Wisely.

**Comment lire le résultat :** si Wisely ne réduit pas ce temps, la « jointure »
Windows/Linux est techniquement élégante et commercialement faible. C'est une
métrique produit forte parce qu'elle est comparative et qu'elle ne demande à
personne son opinion.

### E5 — Sortie brute contre sortie sourcée · teste A11

Présenter deux formulations du même état :

> « Ta consommation est de 7,3 Go. »

puis

> « Ta consommation est de 7,3 Go, dont 3,2 Go de cache, avec un pic de 5,9 Go
> sur 14 jours ; voici pourquoi nous recommandons de ne pas augmenter le
> plafond. »

**Comment lire le résultat :** mesurer laquelle inspire assez confiance pour
déclencher une action. Si la seconde n'apporte rien, le principe 10 est un coût
sans bénéfice — ce qui serait une découverte majeure et contre-intuitive.

---

## Journal de validation

> **Ce tableau existe pour empêcher le projet de remplacer les utilisateurs par
> les documents.** Une hypothèse reste `non testée` tant qu'une ligne ci-dessous
> ne porte pas un résultat. Le seuil de succès se fixe **avant** l'expérience,
> jamais après : un seuil écrit après coup ne réfute rien.

| Exp. | Hypothèse | Population | Métrique | Seuil de succès | Résultat | Décision | Date |
|---|---|---|---|---|---|---|---|
| **E1** | A5 | 1 (le mainteneur) — biais assumé | Nombre et répartition des entrées `SWITCH` de `data/history.json` | ≥ 1 changement/semaine en moyenne, et ≥ 2 profils réellement utilisés | *non menée* | — | — |
| **E2** | A2 | 1 (le mainteneur), 1 semaine | Besoin ressenti de baisser le plafond, avec `autoMemoryReclaim=gradual` actif | Le besoin subsiste → A2 tient | *non menée* | — | — |
| **E3a** | A1, A9 | Utilisateurs externes, après P2 | Utilisations réelles de `wisely diagnose`, et réutilisations | ≥ 5 essais distincts rapportés (étoile, fork, ou retour explicite) et ≥ 1 réutilisation rapportée, sous 4 semaines après publication | **arrêtée — non concluante.** Publiée sur X et Bluesky le 2026-09-01. Exposition mesurée : 6 vues cumulées (X : 6, Bluesky : 0) ; état du dépôt à J+2 : 1 étoile, 0 fork, 0 issue. Dénominateur insuffisant pour interpréter un résultat nul | **Arrêt avant terme.** A1 et A9 restent `non testées` : aucun statut n'est déduit d'E3a. Cause identifiée : ni chaîne de mesure de l'exposition, ni chemin de retour utilisable au moment de la publication. Les deux sont construits, puis E3b est lancée | 2026-09-03 |
| **E3b** | A1, A9 | Utilisateurs externes, canaux de `RECRUITMENT.md` §2 *(privé)* | Idem E3a, plus le dénominateur d'exposition | **Validité** (sans quoi le résultat n'est pas interprétable) : ≥ 300 impressions cumulées et ≥ 40 visites uniques de la page testeurs. **Succès** : ≥ 5 essais distincts rapportés et ≥ 1 réutilisation, sous 4 semaines | **en cours** — canal 1 (`microsoft/WSL#4166`, 2026-09-03) toujours actif. Canal 2 (`r/bashonubuntuonwindows`, 2026-09-04) retiré par Reddit sous 19h — traité comme canal brûlé. `r/PowerShell` en attente (vérification de compte). LinuxFr.org publié le 2026-09-05 en substitution hors séquence priorité 1. Premier retour qualitatif reçu sur le canal 1 : un commentaire sceptique (réactions 👍1/👎1), catégorie `incomprehension` — `observation unique`, aucun correctif engagé sur le fond. Chiffres bruts datés : voir « Relevé hebdomadaire de l'entonnoir d'exposition » ci-dessous | — | 2026-09-05 |
| **E4** | A9, A10 | ≥ 5 personnes, 3 outillages comparés | Temps pour identifier la cause probable | Réduction ≥ 50 % face au meilleur des deux autres outillages | *non menée* | — | — |
| **E5** | A11 | ≥ 5 personnes | Part qui déclenche l'action proposée | La sortie sourcée déclenche strictement plus que la brute | *non menée* | — | — |
| **E6** | A9, A10, A11, A12, A13 | Répondants aux formulaires de retour | Nombre de volontaires pour 20 min d'échange, et leur part parmi les répondants | ≥ 5 volontaires effectivement disponibles, dont ≥ 2 du persona P1 | *non menée* | — | — |

**Règle de tenue.** Chaque expérience menée remplit ses colonnes `Résultat`,
`Décision` et `Date`, **y compris quand le résultat infirme l'hypothèse** — c'est
même le cas le plus précieux. La colonne `Statut` du registre est mise à jour
dans le même mouvement. Une expérience abandonnée est marquée comme telle avec
son motif ; elle n'est pas effacée.

### Relevé hebdomadaire de l'entonnoir d'exposition (E3b)

`RECRUITMENT.md` §6 *(privé — `Thurxm09/dotfiles`)* exige un relevé chaque lundi des quatre étages de la chaîne
de mesure ; le tableau ci-dessus est structuré par expérience, pas par semaine,
et n'a pas de colonne pour une série datée. Les chiffres bruts vivent ici,
un seul endroit :

| Date | Impressions cumulées (tous canaux) | Visites cumulées `/beta` | Clones + vues uniques GitHub (14 j glissants) | Retours déclarés cumulés | Notes |
|---|---|---|---|---|---|
| 2026-09-03 | 6 | — | — | 0 | Relevé de lancement, avant activation du canal 1/4 (`microsoft/WSL#4166`) |
| 2026-09-04 | non relevé | non relevé | non relevé | 1 | Canal 2/4 lancé (`r/bashonubuntuonwindows`). Premier retour reçu sur le canal 1 (`microsoft/WSL#4166`) : réactions 👍1/👎1, commentaire sceptique — catégorie `incomprehension`, `observation unique`. Impressions et visites toujours non relevées (voir TASKS.md). **Second signal, sur le même retour** : le mainteneur a répondu lui-même sur le fil, en confirmant publiquement l'usage d'une IA pour rédiger le message initial, en re-justifiant le fond, et en renouvelant l'appel à tester — trois choses que la règle 8 ci-dessus (ne jamais discuter un retour négatif publiquement) déconseille. Rien d'irréversible à corriger (pas d'édition du commentaire) ; leçon consignée, pas de relance à faire quel que soit le résultat |
| 2026-09-05 | non relevé | non relevé | non relevé | 1 | `r/bashonubuntuonwindows` retiré par Reddit lui-même sous 19h (1 vue) — traité comme canal brûlé, pas comme exposition réelle ; `r/PowerShell` mis en attente le temps de vérifier l'état du compte. Canal de substitution publié hors séquence priorité 1 : LinuxFr.org *(privé — détail dans `Thurxm09/dotfiles`)*, message réécrit intégralement par le mainteneur dans ses propres mots, substance technique revérifiée avant publication |

---

## Décisions à ne pas prendre maintenant

Chacune dépend d'une hypothèse non validée. Les prendre aujourd'hui, ce serait
construire sur du sable.

| Décision en attente | Dépend de |
|---|---|
| Changement de profil automatique (moteur de règles) | A5 — automatiser un geste destructif exige d'abord de savoir que le geste vaut son prix |
| Profils d'équipe, cascade organisation/utilisateur | A1 — résoudre un problème de distribution sans utilisateurs |
| GPU, état d'alimentation | Aucune preuve de besoin ; à rouvrir sur demande réelle |
| Distribution large (PowerShell Gallery, Winget) | Dépend de tout le reste |
| Réécriture dans un autre langage, interface graphique | Moyens en quête d'une fin |
| **Modèle économique, changement ou clarification de licence** | **A13, et A1 avant elle.** Une décision de licence prise avant les premières contributions externes est facile ; prise après, elle exige l'accord de chaque contributeur. C'est donc la seule décision de ce tableau dont le **coût augmente avec le temps** — à surveiller, sans la précipiter pour autant |
| **Toute fonctionnalité justifiée par la rétention** | **A12.** Construire une raison de revenir avant d'avoir vérifié que quelqu'un revient, c'est répondre à une question qu'on ne s'est pas posée |

---

## Ce qui, à l'inverse, est établi

Pour éviter que ce document ne fasse douter de tout :

- Les défaillances de mesure décrites dans `AUDIT.md` et traitées en v2.5 sont
  **vérifiées dans le code**, pas hypothétiques.
- L'existence de WSL Settings, d'`autoMemoryReclaim` et de `sparseVhd`, ainsi que
  l'incompatibilité entre `sparseVhd` et `Optimize-VHD`, sont **vérifiées** en
  août 2026 (sources dans `PROBLEM.md`).
- L'absence de toute commande WSL native exposant la consommation mémoire est
  **vérifiée**.
- Le fait que personne ne fasse la jointure Windows/Linux est **vérifié** dans la
  limite des outils recensés.
