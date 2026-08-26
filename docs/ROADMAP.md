# Roadmap — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> qu'est-ce qu'on fait ensuite, et pourquoi dans cet ordre ?
>
> Ce document ne contient plus ni positionnement, ni principes, ni décisions.
> Ils vivent respectivement dans `PROBLEM.md`, `PRINCIPLES.md` et `decisions/`,
> où chacun peut être révisé sans toucher aux autres.
>
> **Ce n'est pas un calendrier.** Le projet n'a aucune contrainte de délai, et
> c'est un avantage à préserver : il permet le bon ordre plutôt que l'ordre du
> plus facile. Aucune date n'est donnée, volontairement.
>
> Statut : vivant. Dernière révision : 2026-08-26.

---

## Le principe d'ordonnancement

L'ordre est imposé par les **dépendances**, pas par la facilité ni par la valeur
perçue.

> **On ne construit ni diagnostic ni recommandation sur une mesure qui ment.**

C'est pourquoi la version des correctifs vient en premier, avant toute
fonctionnalité nouvelle, alors même qu'elle n'ajoute rien de visible.

Chaque version atteint un palier de `VISION.md`.

---

## La séquence

### v2.4 — Clôture · livrée

Le garde-fou WSL2 avant shutdown (`Get-WslActiveSessions`, `Confirm-WslShutdown`,
`Test-WiselyNonInteractive`, flag `-Force`) est livré et couvert par la suite
Pester. Le spike Terminal.Gui est annulé — voir
[0007](decisions/0007-annulation-spike-terminal-gui.md). S'y ajoute la
refondation documentaire dont ce fichier fait partie.

---

### v2.5 — Vérité

**La version qui rend les mesures honnêtes.** Elle n'ajoute aucune
fonctionnalité visible, et c'est la plus importante de la séquence.

1. **Détection du processus WSL2.** `Get-Process -Name "vmmem"` ne trouve rien sur
   Windows 11 récent, où le processus s'appelle `VmmemWSL`. Toute la couche
   d'observation est silencieusement inopérante sur ces machines.
2. **Seuil d'alerte au bon dénominateur.** L'alerte compare aujourd'hui la part de
   WSL2 dans la RAM **totale** à un seuil de 80 %, alors que le plafond le plus
   large livré est de 6 Go : l'alerte ne peut mathématiquement pas se déclencher.
   Le seuil doit porter sur le plafond WSL2, pas sur la RAM physique.
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
> **Effet de bord majeur :** l'item 4 débloque deux segments entiers — utilisateurs
> Docker Desktop et postes d'entreprise (`PROBLEM.md` §4, segments B et E) — pour
> qui l'outil est aujourd'hui activement nuisible.
> **Principes engagés :** 8, 9. **Décision :** [0005](decisions/0005-direction-boucle-fermee.md).

---

### v2.6 — Contrat

**La doctrine avant le code.** `DOCTRINE-LECTURE.md` est déjà écrit ; ce cycle le
met en œuvre.

1. Implémentation de la liste fermée de commandes, comme constante unique, avec
   le test Pester qui interdit toute invocation hors liste.
2. Consentement explicite au premier usage, révocable, désactivé par défaut.
3. Dégradation propre en cas de refus : les fonctions concernées disent pourquoi
   elles sont indisponibles et comment les activer.
4. Première lecture utile : `/proc/meminfo` sur les distributions **déjà en cours
   d'exécution**.

> **Palier atteint :** Wisely voit des deux côtés de la frontière, sous contrat.
> **Principes engagés :** 12. **Décision :** [0008](decisions/0008-lecture-in-distro.md).
> **Hypothèse en jeu :** A4.

---

### v3.0 — L'écart

**Le produit devient lui-même.**

1. **`wisely doctor`** — une commande, un état complet et expliqué : validité de
   `.wslconfig`, `autoMemoryReclaim` actif ou non et ce que cela changerait,
   `sparseVhd`, taille du VHDX, distributions, plafond rapporté à la RAM hôte,
   état du consentement de lecture.
   - **`--explain <clé>`** — pour toute clé de `.wslconfig` non gérée par
     Wisely, explique ce qu'elle fait et si WSL Settings la couvre déjà.
     Contrepartie en lecture seule de l'écriture non destructive (v2.5 item 4,
     dont elle dépend). Sert les segments B et E (`PROBLEM.md` §4). Principe
     engagé : 8.
   - **`--history`** — indique si les entrées d'historique ont été
     attribuables ou écartées, au lieu d'un rapport silencieusement
     clairsemé. Sert tous les segments. Principe engagé : 9.
2. **Mesure réelle de l'écart** — consommé, autorisé, pic — en remplacement du
   proxy `VmmemWSL` seul.
3. **Vérification post-switch** — l'écart a-t-il bougé comme annoncé ? Ferme la
   boucle et remplace `ramDeltaGB`.
4. **Annonce du coût avant le geste** — étendre `Confirm-WslShutdown` pour dire
   *ce qui* va être interrompu, pas seulement qu'il y a quelque chose.

> **Palier atteint :** l'écart est mesuré, expliqué, vérifié.
> **Principes engagés :** 10, 11. **Hypothèse en jeu :** A3.
> C'est aussi la version qui porte l'expérience E3 (`ASSUMPTIONS.md`).

---

### v3.1 — Le bon plafond

1. Profils dérivés : une politique résolue sur la machine réelle, la valeur
   absolue restant acceptée en cas particulier. La documentation livrée doit
   inclure un exemple calibré pour une machine 8 Go, à côté des défauts 16 Go
   du mainteneur — sans quoi cette version reproduit en caché le biais
   qu'elle corrige.
2. Recommandation de dimensionnement **sourcée** par la mesure — jamais un chiffre
   sans sa preuve.
3. Migration de schéma `profiles.json`, compatible descendante.

> **Palier atteint :** le plafond est dérivé de la réalité.
> **Décision :** [0006](decisions/0006-profils-derives.md). **Principe :** 10.

---

### v3.2 — La durée

1. Historique de la **consommation réelle** — et non de l'usage de l'outil.
2. Remplacement du rapport hebdomadaire, qui compte aujourd'hui les changements de
   profil, c'est-à-dire l'activité de l'outil et non celle de la machine.
3. Alerte refondée sur l'écart et sa tendance.

> **Palier atteint :** l'écart a une histoire.
> Alimente la recommandation de v3.1 en données réelles.

---

### v3.3 — Le disque

Détecter le régime (`sparseVhd` ou non), mesurer le récupérable, **router** vers
la bonne méthode — `fstrim` depuis Linux, ou compaction — et chiffrer l'effet.
Jamais de compaction à l'aveugle. Conformément à `DOCTRINE-LECTURE.md` §2.1,
Wisely affiche et explique la commande invitée ; il ne l'exécute pas.

> **Décision :** [0010](decisions/0010-retrait-reclaim-optimize-vhd.md).
> **Hypothèse en jeu :** A6.

---

### v4.0 — Distribution

PowerShell Gallery, Winget, organisation GitHub, packaging en module, et
resynchronisation du dépôt `wisely-site`.

> **Décision :** [0009](decisions/0009-distribution-apres-le-produit.md) — placée
> ici délibérément. On ne dispose que d'un seul lancement ; il ne doit pas être
> dépensé sur la version dont la plateforme absorbe la proposition de valeur.

---

## Classement de l'existant

Le résultat de la revue du 2026-08-26, conservé pour que les décisions de retrait
ne se rejouent pas.

| Élément | Verdict | Motif |
|---|---|---|
| Backup, rollback, validation post-écriture, dry-run | **KEEP** | Le meilleur actif du projet. Aucun concurrent identifié ne fait cela. |
| Garde-fou sessions actives | **KEEP** | À étendre en v3.0 (dire *quoi*, pas seulement *qu'il y a quelque chose*). |
| Menu interactif, source de vérité JSON, Pester, CI | **KEEP** | Socle sain. |
| Profils (le concept) | **CHANGE** | Plafond absolu → politique dérivée. [0006](decisions/0006-profils-derives.md) |
| Monitoring et alerte RAM | **CHANGE** | À refonder sur l'écart. Inopérante aujourd'hui, pour deux raisons indépendantes. |
| `wisely -Watch` | **CHANGE** | Bonne idée, mauvaise donnée. |
| Rapport hebdomadaire | **CHANGE** | Compte l'usage de l'outil, pas la consommation de la machine. |
| `-Reclaim` via `Optimize-VHD` | **REMOVE** | Factuellement cassé sur VHD sparse. [0010](decisions/0010-retrait-reclaim-optimize-vhd.md) |
| Spike Terminal.Gui | **REMOVE** | Aucun problème utilisateur adossé. [0007](decisions/0007-annulation-spike-terminal-gui.md) |
| Import / Export de profils | **REMOVE** | Partage un plafond non portable, et remplace intégralement `profiles.json`. À rouvrir après v3.1. |
| `-Snapshot` | **REMOVE** | Aggrave le défaut d'identité du profil actif. |
| Cascade organisation / équipe | **DEFER** | Problème de distribution sans utilisateurs. Dépend de A1. |
| Auto-switch contextuel | **DEFER** | [0011](decisions/0011-auto-switch-reporte.md). Dépend de A5. |
| Hooks `pre` / `post-switch` | **DEFER** | Ne s'exprime pas comme une opération sur l'écart. [0012](decisions/0012-hooks-echec-par-regle.md) |
| PowerShell Gallery, Winget | **DEFER** | Déplacé en v4.0. [0009](decisions/0009-distribution-apres-le-produit.md) |
| GPU, état d'alimentation | **VALIDATE** | Signaux plausibles, aucune preuve de besoin. |
| Profil de projet `.wisely-profile` | **VALIDATE** | Geste familier, mais dépend de A5 : sans changements fréquents, il ne sert à rien. |
| Signature des scripts | **VALIDATE** | Débloque le segment E, mais dépend de A1 pour justifier le coût. |
| Écriture non destructive de `.wslconfig` | **NEW** | Prérequis, pas fonctionnalité. v2.5. |
| `wisely doctor` | **NEW** | Porte d'entrée, meilleur rapport valeur/effort. v3.0. |
| Lecture in-distro sous contrat | **NEW** | Le verrou qui ouvre tout le reste. v2.6. |
| Vérification post-switch | **NEW** | Ferme la boucle. v3.0. |

---

## Ce que la roadmap ne doit jamais devenir

Une liste de fonctionnalités. Chaque entrée ci-dessus doit pouvoir désigner :

1. l'opération sur l'écart qu'elle représente (`VISION.md`) ;
2. la case de la carte du problème qu'elle remplit et le segment qu'elle sert
   (`PROBLEM.md`) ;
3. le palier qu'elle fait franchir.

Une entrée qui n'y arrive pas sort de la roadmap — c'est ce qui est arrivé au
spike Terminal.Gui.

---

## Documents liés

`PROBLEM.md` · `VISION.md` · `PRINCIPLES.md` · `ASSUMPTIONS.md` ·
`DOCTRINE-LECTURE.md` · `decisions/` · `AUDIT.md` · `TASKS.md`

Le raisonnement qui a produit cette séquence est conservé dans
`refondation-wisely.html` (document de travail daté du 2026-08-26, à ouvrir dans
un navigateur). Il explique les arbitrages ; les documents ci-dessus font foi.
