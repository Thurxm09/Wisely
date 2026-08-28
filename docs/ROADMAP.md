# Roadmap — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> qu'est-ce qu'on fait ensuite, et pourquoi dans cet ordre ?
>
> Ce document ne contient ni positionnement, ni principes, ni décisions. Ils
> vivent respectivement dans `PROBLEM.md`, `PRINCIPLES.md` et `decisions/`, où
> chacun peut être révisé sans toucher aux autres.
>
> **Ce n'est pas un calendrier.** Le projet n'a aucune contrainte de délai, et
> c'est un avantage à préserver : il permet le bon ordre plutôt que l'ordre du
> plus facile. Aucune date n'est donnée, volontairement.
>
> Statut : vivant. Dernière révision : 2026-08-27
> (voir `decisions/0013-adoption-audit-strategique-externe.md`).

---

## Le principe d'ordonnancement

L'ordre est imposé par les **dépendances**, pas par la facilité ni par la valeur
perçue. Deux règles, et la seconde est neuve.

> **1. On ne construit ni diagnostic ni recommandation sur une mesure qui ment.**
>
> **2. On ne construit pas au-delà d'une capacité qu'on n'a pas confrontée à un
> utilisateur.**

La première explique pourquoi la version des correctifs vient en premier, alors
même qu'elle n'ajoute rien de visible. La seconde explique pourquoi il y a un
palier bloquant au milieu de cette séquence : le principal risque du projet n'est
plus technique, c'est celui de construire avec beaucoup de soin un produit dont
personne n'a démontré que quelqu'un en a besoin.

Chaque palier franchit une marche de `VISION.md`. Les étiquettes de version sont
conservées — le `CHANGELOG.md` et les tags s'en servent — mais **c'est la capacité
qui commande, pas le numéro**.

---

## La séquence

| Palier | Version | Capacité franchie |
|---|---|---|
| P0 | v2.5 | Les mesures sont honnêtes |
| P1 | v2.6 | Wisely voit des deux côtés de la frontière, sous contrat |
| P2 | v3.0 | L'état est expliqué |
| **P3** | — | **Quelqu'un d'autre que le mainteneur s'en sert** — bloquant |
| P4 | v3.2 | La consommation a une histoire |
| P5 | v3.1 | La recommandation porte sa preuve |
| P6 | v3.1 | L'action est vérifiée |
| P7 | v3.1 | Le plafond est dérivé de la réalité |
| P8 | v3.3 | Le disque est expliqué avant d'être touché |
| P9 | v4.0 | Distribution |

---

### v2.4 — Clôture · livrée

Le garde-fou WSL2 avant shutdown (`Get-WslActiveSessions`, `Confirm-WslShutdown`,
`Test-WiselyNonInteractive`, flag `-Force`) est livré et couvert par la suite
Pester. Le spike Terminal.Gui est annulé — voir
[0007](decisions/0007-annulation-spike-terminal-gui.md). S'y ajoute la
refondation documentaire de 2026-08-26, révisée le 2026-08-27 par
[0013](decisions/0013-adoption-audit-strategique-externe.md).

---

### P0 · v2.5 — Vérité · livrée

**La version qui rend les mesures honnêtes.** Elle n'a ajouté aucune
fonctionnalité visible, et c'était la plus importante de la séquence. Les cinq
correctifs sont livrés (`decisions/`, `CHANGELOG.md`).

1. **Détection du processus WSL2.** `Get-Process -Name "vmmem"` ne trouve rien sur
   Windows 11 récent, où le processus s'appelle `VmmemWSL`. Toute la couche
   d'observation est silencieusement inopérante sur ces machines.
2. **Seuil d'alerte au bon dénominateur.** L'alerte compare aujourd'hui la part de
   WSL2 dans la RAM **totale** à un seuil de 80 %, alors que le plafond le plus
   large livré est de 6 Go : l'alerte ne peut mathématiquement pas se déclencher.
   Le seuil doit porter sur le plafond WSL2, pas sur la RAM physique. C'est un
   mélange de portées au sens de `RESOURCE-MODEL.md` §3.
3. **`ramDeltaGB` : corriger ou retirer.** La mesure est prise autour de
   `wsl --shutdown` sans redémarrage, puis attribuée au profil **cible** — elle
   mesure donc l'arrêt de la session précédente. Tant qu'elle n'est pas
   attribuable, elle sort du rapport hebdomadaire (principe 9).
4. **Écriture non destructive de `.wslconfig`.** Fusionner au lieu de réécrire, et
   marquer la provenance des clés gérées. Chaque changement de profil efface
   aujourd'hui `networkingMode`, `dnsTunneling`, `autoMemoryReclaim`,
   `sparseVhd` et tout le reste — et `Test-WslConfigIntegrity` ne vérifie que les
   clés que Wisely vient d'écrire, donc ne peut pas détecter la perte.
5. **Identité du profil actif.** `Get-ActiveProfile` reconnaît le profil actif par
   égalité de valeur mémoire : deux profils à 4 Go sont indiscernables. L'identité
   doit être marquée, pas devinée.

> **Palier atteint :** les mesures sont honnêtes.
> **Effet de bord majeur :** l'item 4 débloque la situation S5 et deux contextes
> entiers — Docker Desktop et poste d'entreprise — pour qui l'outil est
> aujourd'hui activement nuisible.
> **Principes engagés :** 8, 9, 14. **Décisions :** [0005](decisions/0005-direction-boucle-fermee.md),
> [0013](decisions/0013-adoption-audit-strategique-externe.md).

---

### P1 · v2.6 — Contrat · livrée

**La doctrine avant le code.** `DOCTRINE-LECTURE.md` était déjà écrit ; ce cycle
le met en œuvre. `RESOURCE-MODEL.md` en est le pendant sémantique, également
écrit d'avance : les deux listes de commandes restent identiques (vérifié par
un test de dérive doc/code). Les quatre livrables sont couverts ; prochaine
priorité d'implémentation : **P2 · v3.0 — Diagnostic**, ci-dessous.

1. Implémentation de la liste fermée de commandes, comme constante unique, avec
   le test Pester qui interdit toute invocation hors liste.
2. Consentement explicite au premier usage, révocable, désactivé par défaut.
   Relève du contrôle utilisateur, pas de la configuration — principe 1 révisé.
3. Dégradation propre en cas de refus : les fonctions concernées disent pourquoi
   elles sont indisponibles et comment les activer.
4. Première lecture utile : `/proc/meminfo` sur les distributions **déjà en cours
   d'exécution**, avec la distinction `MemAvailable` / `Cached` qui fonde tout le
   reste (`RESOURCE-MODEL.md` §4.3).

> **Palier atteint :** Wisely voit des deux côtés de la frontière, sous contrat.
> **Principes engagés :** 1, 12. **Décision :** [0008](decisions/0008-lecture-in-distro.md).
> **Hypothèse en jeu :** A4.

---

### P2 · v3.0 — Diagnostic

**Le produit devient lui-même.** C'est ici qu'« expliquer » cesse d'être un mot
et devient une commande.

**Prérequis :** `RESOURCE-MODEL.md` fait foi. Aucune grandeur ne s'affiche sans y
avoir son entrée — portée, source, classe, confiance.

1. **`wisely diagnose`** — une commande, un état complet et expliqué. Elle répond
   dans l'ordre : que se passe-t-il ? pourquoi ? est-ce dangereux ? que puis-je
   faire ? est-ce que ça vaut la peine de changer quelque chose ?
   Couvre la validité de `.wslconfig`, `autoMemoryReclaim` actif ou non et ce que
   cela changerait, `sparseVhd`, la taille du VHDX, les distributions, le plafond
   rapporté à la RAM hôte, l'état du consentement de lecture.
   - **`--explain <clé>`** — pour toute clé de `.wslconfig` non gérée par Wisely,
     explique ce qu'elle fait et si WSL Settings la couvre déjà. Contrepartie en
     lecture seule de l'écriture non destructive (P0 item 4, dont elle dépend).
     Sert la situation S5. Principes engagés : 8, 14.
   - **`--history`** — indique si les entrées d'historique ont été attribuables ou
     écartées, au lieu d'un rapport silencieusement clairsemé. Principe 9.
2. **État et Cause, avec leurs classes.** Chaque chiffre porte sa portée et sa
   confiance ; toute vue d'attribution affiche sa ligne « non attribué ».
3. **Annonce du coût avant le geste** — étendre `Confirm-WslShutdown` pour dire
   *ce qui* va être interrompu, pas seulement qu'il y a quelque chose.

> **Palier atteint :** l'état est expliqué.
> **Situations servies :** S1, S2, S4, S5. **Principes engagés :** 9, 11, 13, 14.
> **Note de nommage :** `wisely doctor` a été renommé `wisely diagnose` avant
> écriture — le nom annonce la valeur plutôt qu'une catégorie d'outil
> ([0013](decisions/0013-adoption-audit-strategique-externe.md)).

---

### P3 — Barrière de validation · **bloquant**

**Aucun palier au-delà de celui-ci ne démarre avant que cette barrière soit
franchie.** Ce n'est pas une étape de communication, et ce n'est pas la
distribution large — délibérément repoussée en P9
([0009](decisions/0009-distribution-apres-le-produit.md)).

1. **Publier `wisely diagnose` seul** et observer si quelqu'un l'utilise. C'est
   l'expérience E3 de `ASSUMPTIONS.md`. Elle ne demande aucun engagement : pas
   d'installation permanente, pas de modification système, pas de confiance
   préalable. Elle mesure donc un intérêt réel plutôt qu'une politesse.
2. **Mesurer le temps pour identifier la cause probable** — Gestionnaire des
   tâches seul, `htop` seul, Wisely. C'est une métrique produit forte, et elle
   teste A10 directement.
3. **Comparer la sortie brute et la sortie sourcée** — « ta consommation est de
   7,3 Go » contre « 7,3 Go dont 3,2 de cache, pic de 5,9 sur 14 jours, voici
   pourquoi nous ne recommandons pas d'augmenter le plafond ». Teste A11.

> **Palier atteint :** quelqu'un d'autre que le mainteneur s'en sert.
> **Hypothèses en jeu :** A1, A9, A10, A11. **Résultats consignés :** journal de
> validation de `ASSUMPTIONS.md`.
> **Ce qui se passe si la barrière n'est pas franchie :** c'est une information,
> pas un échec. Un `diagnose` que personne n'utilise dit quelque chose de vrai et
> d'utile sur la suite à donner au projet.

---

### P4 · v3.2 — La durée

**Remonté avant la recommandation.** L'ordre précédent plaçait la recommandation
sourcée (v3.1) avant l'historique (v3.2) — or une recommandation du type « ton
pic mesuré sur 14 jours est 5,4 Go » exige que l'historique existe déjà. La
dépendance était inversée.

1. Historique de la **consommation réelle** — et non de l'usage de l'outil.
2. Remplacement du rapport hebdomadaire, qui compte aujourd'hui les changements de
   profil, c'est-à-dire l'activité de l'outil et non celle de la machine.
3. Attribution par distribution et par processus, avec son reste explicite
   (`RESOURCE-MODEL.md` §4.4).
4. Alerte refondée sur l'état et sa tendance, au bon dénominateur.

> **Palier atteint :** la consommation a une histoire.
> **Situations servies :** S1, S4. **Hypothèses :** A8, A10.

---

### P5 · v3.1 — La recommandation porte sa preuve

Recommandation de dimensionnement **sourcée** par la mesure — jamais un chiffre
sans sa preuve. « 6 Go, parce que ton pic mesuré sur 14 jours est 5,4 Go, atteint
trois fois. » Et si la mesure n'est pas disponible ou pas fiable, **il n'y a pas
de recommandation**.

Aucune recommandation portant sur le plafond mémoire n'est formulée sans
indiquer l'état de `autoMemoryReclaim` : recommander d'augmenter un plafond alors
que ce réglage est désactivé revient à traiter un symptôme dont la cause est
connue et corrigeable à coût nul (`RESOURCE-MODEL.md` §4.5).

> **Palier atteint :** la recommandation porte sa preuve.
> **Principe engagé :** 10. **Hypothèse :** A11.

---

### P6 · v3.1 — L'action est vérifiée

Le **contrat avant / après** : les mêmes grandeurs, avec les mêmes portées, avant
et après l'action, puis une conclusion explicite — effet conforme à l'annonce ?
rollback nécessaire ? C'est ce qui ferme la boucle et remplace `ramDeltaGB`.

Bien plus utile qu'un « action exécutée avec succès », qui ne dit rien de
l'effet.

> **Palier atteint :** l'action est vérifiée. **Situation servie :** S7.
> **Principes engagés :** 10, 11. **Hypothèse :** A3.

---

### P7 · v3.1 — Le bon plafond

1. Profils dérivés : une politique résolue sur la machine réelle, la valeur
   absolue restant acceptée en cas particulier. La documentation livrée doit
   inclure un exemple calibré pour une machine 8 Go, à côté des défauts 16 Go
   du mainteneur — sans quoi ce palier reproduit en caché le biais qu'il corrige.
2. Migration de schéma `profiles.json`, compatible descendante.

> **Palier atteint :** le plafond est dérivé de la réalité. **Situation :** S3.
> **Décision :** [0006](decisions/0006-profils-derives.md). **Principes :** 1, 10.

---

### P8 · v3.3 — Le disque

Détecter le régime (`sparseVhd` ou non), mesurer le récupérable, **router** vers
la bonne méthode — `fstrim` depuis Linux, ou compaction — et chiffrer l'effet.
Jamais de compaction à l'aveugle.

Le produit ne « nettoie » pas le disque : il **explique l'écart** entre occupation
logique, taille du VHDX et espace effectivement récupérable
(`RESOURCE-MODEL.md` §6). Conformément à `DOCTRINE-LECTURE.md` §2.1, Wisely
affiche et explique la commande invitée ; il ne l'exécute pas.

> **Situation servie :** S6. **Décision :** [0010](decisions/0010-retrait-reclaim-optimize-vhd.md).
> **Hypothèse en jeu :** A6.

---

### P9 · v4.0 — Distribution

PowerShell Gallery, Winget, organisation GitHub, packaging en module, et
resynchronisation du dépôt `wisely-site`.

> **Décision :** [0009](decisions/0009-distribution-apres-le-produit.md) — placée
> ici délibérément. On ne dispose que d'un seul lancement ; il ne doit pas être
> dépensé sur la version dont la plateforme absorbe la proposition de valeur.

---

## Classement de l'existant

Le résultat de la revue du 2026-08-26, révisé le 2026-08-27, conservé pour que
les décisions de retrait ne se rejouent pas.

| Élément | Verdict | Motif |
|---|---|---|
| Backup, rollback, validation post-écriture, dry-run | **KEEP** | Le meilleur actif du projet. Aucun concurrent identifié ne fait cela. |
| Garde-fou sessions actives | **KEEP** | À étendre en P2 (dire *quoi*, pas seulement *qu'il y a quelque chose*). |
| Menu interactif, source de vérité JSON, Pester, CI | **KEEP** | Socle sain. |
| Lecture cross-frontière Windows/Linux | **KEEP** | L'avantage technique majeur. Personne d'autre ne fait la jointure. |
| Profils (le concept) | **CHANGE** | Plafond absolu → politique dérivée. [0006](decisions/0006-profils-derives.md) |
| Monitoring et alerte RAM | **CHANGE** | À refonder sur l'état et sa tendance. Inopérante aujourd'hui, pour deux raisons indépendantes. |
| `wisely -Watch` | **CHANGE** | Bonne idée, mauvaise donnée. |
| Rapport hebdomadaire | **REMOVE** | Compte l'usage de l'outil, pas la consommation de la machine. Générer un artefact n'est pas une valeur — principe 6. Requalifié CHANGE → REMOVE le 2026-08-27. |
| `-Reclaim` via `Optimize-VHD` | **REMOVE** | Factuellement cassé sur VHD sparse. [0010](decisions/0010-retrait-reclaim-optimize-vhd.md) |
| Spike Terminal.Gui | **REMOVE** | Aucun problème utilisateur adossé. [0007](decisions/0007-annulation-spike-terminal-gui.md) |
| Import / Export de profils | **REMOVE** | Partage un plafond non portable, et remplace intégralement `profiles.json`. À rouvrir après P7. |
| `-Snapshot` | **REMOVE** | Aggrave le défaut d'identité du profil actif, et corrige un problème créé par le modèle de profils plutôt qu'un besoin réel. |
| Profils métier `web` / `data` / `base` | **REMOVE** | Noms trop prescriptifs, valeurs calibrées sur une seule machine. Remplacés en P7. |
| Cascade organisation / équipe | **DEFER** | Problème de distribution sans utilisateurs. Dépend de A1. |
| Auto-switch contextuel | **DEFER** | [0011](decisions/0011-auto-switch-reporte.md). Dépend de A5. |
| Hooks `pre` / `post-switch` | **DEFER** | Point d'extension générique : ne compte pas comme réponse valide à la question 1 du filtre (`VISION.md`), et aucun besoin utilisateur ne l'appuie — principe 6. [0012](decisions/0012-hooks-echec-par-regle.md) |
| PowerShell Gallery, Winget | **DEFER** | Déplacé en P9. [0009](decisions/0009-distribution-apres-le-produit.md) |
| Resource Evidence Graph | **DEFER** | Superstructure sur des données qui n'existent pas et un produit sans utilisateur. À rouvrir après P3. [0013](decisions/0013-adoption-audit-strategique-externe.md) |
| `ARCHITECTURE.md` | **DEFER** | Sans code correspondant, ce serait un dessin. À écrire quand P2 rend l'architecture réelle. |
| GPU, état d'alimentation | **VALIDATE** | Signaux plausibles, aucune preuve de besoin. |
| Profil de projet `.wisely-profile` | **VALIDATE** | Geste familier, mais dépend de A5 : sans changements fréquents, il ne sert à rien. |
| Signature des scripts | **VALIDATE** | Débloque le contexte entreprise, mais dépend de A1 pour justifier le coût. |
| Écriture non destructive de `.wslconfig` | **NEW** | Prérequis, pas fonctionnalité. P0. |
| `RESOURCE-MODEL.md` | **NEW** | Prérequis sémantique du diagnostic. Livré le 2026-08-27. |
| Affichage de la provenance des clés | **NEW** | Face lisible du principe 8. P0 puis P2. Principe 14. |
| `wisely diagnose` | **NEW** | Porte d'entrée, meilleur rapport valeur/effort. P2. |
| Lecture in-distro sous contrat | **NEW** | Le verrou qui ouvre tout le reste. P1. |
| Contrat avant / après | **NEW** | Ferme la boucle. P6. |
| Barrière de validation | **NEW** | Palier bloquant. P3. [0013](decisions/0013-adoption-audit-strategique-externe.md) |

---

## Ce que la roadmap ne doit jamais devenir

Une liste de fonctionnalités. Chaque entrée ci-dessus doit pouvoir désigner :

1. l'objet — État, Cause, Politique, Action — et le maillon de la boucle qu'elle
   sert (`VISION.md`) ;
2. la case de la carte du problème (`PROBLEM.md` §3) et la situation
   (`USE-CASES.md`) qu'elle sert ;
3. le palier qu'elle fait franchir.

Une entrée qui n'y arrive pas sort de la roadmap — c'est ce qui est arrivé au
spike Terminal.Gui.

---

## Documents liés

`PROBLEM.md` · `VISION.md` · `USE-CASES.md` · `PRINCIPLES.md` ·
`RESOURCE-MODEL.md` · `ASSUMPTIONS.md` · `DOCTRINE-LECTURE.md` · `decisions/` ·
`AUDIT.md` · `TASKS.md`

Le raisonnement qui a produit cette séquence est conservé dans deux pièces
d'analyse, qui ne font pas foi : `refondation-wisely.html` (2026-08-26, à ouvrir
dans un navigateur) et `audits/2026-08-audit-strategique-externe.md`
(l'audit externe qui a challengé la précédente). Les documents ci-dessus font foi.
