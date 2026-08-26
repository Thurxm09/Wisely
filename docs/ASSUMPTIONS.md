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
> Statut : vivant, à réviser à chaque cycle. Dernière révision : 2026-08-26.

---

## Contexte : ce que nous ne savons vraiment pas

Wisely a **zéro utilisateur réel**, zéro retour, zéro télémétrie — et la
télémétrie n'est pas envisagée (voir `DOCTRINE-LECTURE.md` §2.4). Le projet n'a
jamais été annoncé publiquement.

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
| **A2** | `autoMemoryReclaim` n'a pas déjà résolu la moitié « RAM » du problème fondateur | Fort | Forte | non testée |
| **A5** | Le coût du `wsl --shutdown` est acceptable, et les gens changent de profil plus d'une fois | Fort | Forte | **testable immédiatement** |
| **A3** | L'écart est mesurable assez précisément pour fonder une recommandation | Fort | Modérée | non testée |
| **A4** | Les utilisateurs acceptent qu'un outil Windows lise dans leur distribution Linux | Fort | Modérée | non testée |
| **A6** | La douleur disque dépasse la douleur RAM | Modéré | Forte | non testée |
| **A7** | Le public non-développeur est atteignable par un outil en ligne de commande | Modéré | Forte | non testée |
| **A8** | Les utilisateurs multi-distributions (segment F) ont besoin d'une attribution par distribution, plutôt qu'un plafond unique WSL2 toutes distros confondues | Modéré | Forte | non testée |

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

---

## Trois expériences à coût quasi nul

### E1 — Lire `data/history.json` · dix minutes · teste A5

Compter les entrées `SWITCH` réellement enregistrées depuis la mise en service,
leur répartition dans le temps, et la proportion de profils réellement utilisés.

**Comment lire le résultat :**

- Des changements réguliers (plusieurs par semaine) confirment A5 : le geste vaut
  son prix, le commutateur a un sens.
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

### E3 — Publier le diagnostic seul · une version · teste A1

Publier la commande de diagnostic sans le reste, et observer si quelqu'un
l'utilise.

**Pourquoi ce test est le bon.** Il ne demande aucun engagement : pas
d'installation permanente, pas de modification système, pas de confiance
préalable. Il mesure donc un intérêt réel plutôt qu'une politesse. Un outil
qu'on lance une fois et qu'on ne réutilise jamais est un signal aussi
informatif qu'un outil adopté.

**À ne pas confondre avec un lancement.** Ce n'est pas la distribution large,
délibérément repoussée (voir `decisions/0009-distribution-apres-le-produit.md`).

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
