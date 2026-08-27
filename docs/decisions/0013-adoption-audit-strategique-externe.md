# 0013 — Adoption de l'audit stratégique externe d'août 2026

**Statut :** acceptée
**Date :** 2026-08-27
**Révise :** [0005](0005-direction-boucle-fermee.md)

## Contexte

Un audit stratégique externe a été commandé par le mainteneur en août 2026, avec
pour consigne de challenger non pas l'ancien Wisely, mais **la refondation du
2026-08-26 elle-même** — celle qui a produit `../VISION.md`, `../ROADMAP.md` et
les décisions 0005 à 0012. Le document complet est archivé, sans retouche, dans
[`../audits/2026-08-audit-strategique-externe.md`](../audits/2026-08-audit-strategique-externe.md).

Sa thèse : la refondation a raison d'abandonner le « profile switcher », mais
elle s'arrête un cran trop tôt en conservant **l'écart** — la distance entre ce
que WSL2 consomme et ce qu'on l'autorise à consommer — comme ontologie de tout le
produit.

Trois éléments ont été vérifiés avant d'accorder du crédit à l'audit.

**Ses constats de code sont exacts.** `Get-Process -Name "vmmem"` dans
`modules/Monitor.ps1` et `modules/MonitorTask.ps1` ; `Get-ActiveProfile` qui
identifie le profil actif par égalité de valeur mémoire dans
`modules/ProfileManager.ps1` ; `ConvertTo-WslConfigContent` qui régénère
`.wslconfig` à partir de cinq champs. Les trois sont réels, et déjà inscrits en
v2.5 — ce qui confirme au passage sa lecture la plus juste : **la stratégie du
dépôt est en avance sur son implémentation.**

**L'écart ne s'étend pas uniformément.** Il modélise correctement les ressources
à plafond configurable — mémoire, CPU exposé, swap. Il ne dit rien du cache
Linux, de l'I/O, du disque, du GPU, du temps de démarrage. Et il masque une
distinction décisive : **8 Go consommés ne sont pas 8 Go nécessaires.** Une
partie de ce que `VmmemWSL` affiche est du cache que Linux rendra sous pression.
Un produit dont l'unité de pensée est l'écart est structurellement tenté
d'afficher un écart CPU, un écart cache, un écart disque — tous faux, tous
convaincants.

**« Expliquer » manquait comme maillon nommé.** La boucle
`observer → comprendre → décider → agir → vérifier` range le travail le plus dur
dans « comprendre », où il n'est ni construit, ni testé, ni ratable.

## Alternatives considérées

| Option | Écartée parce que |
|---|---|
| Archiver l'audit sans rien changer | Deux stratégies concurrentes dans `docs/`, sans arbitrage écrit — le contraire de ce que la refondation cherchait à obtenir |
| Ne retenir que les corrections techniques (sémantique des mesures) | Revient à prendre les conséquences en refusant la prémisse qui les produit |
| Adopter aussi le *Resource Evidence Graph* (§28) | Superstructure sur des données qui n'existent pas et un produit sans utilisateur — voir « différé » ci-dessous |
| Réécrire le produit autour du diagnostic seul | Déjà écarté par 0005, et pour la même raison : un diagnostic sans action est un rapport, et cela jette le seul maillon que le projet détienne |

## Décision

**La capacité fondamentale devient : transformer l'état réel des ressources WSL2
en décisions explicables et en actions sûres.**

- **Catégorie :** WSL2 Resource Intelligence & Control.
- **Promesse :** *Comprendre WSL. Agir en confiance.* (« Understand WSL. Act safely. »)
- **Les quatre objets :** État, Cause, Politique, Action.
- **La boucle :** observer → **expliquer** → recommander → agir → vérifier.
- **L'écart est requalifié**, pas supprimé : il devient la **relation entre l'État
  observé et la Politique de ressources**, modèle interne des ressources
  configurables. Il cesse d'être l'ontologie du produit et le test de périmètre.

Trois conséquences structurantes sont actées avec cette décision.

**Un nouveau filtre de périmètre.** L'ancienne `VISION.md` tirait son pouvoir de
refus d'un test unique — « si ça ne s'exprime pas comme une opération sur
l'écart, ça n'appartient pas à Wisely ». Ce test a réellement servi : il a tué le
spike Terminal.Gui, les hooks et `-Snapshot`. En requalifiant l'écart, il faut le
remplacer, sans quoi l'adoption échange un modèle étroit contre un modèle qui ne
filtre plus rien. Le remplacement, assemblé à partir des §12, §25 et §27 de
l'audit :

> Une proposition doit (1) servir un des quatre objets pour un maillon nommé de
> la boucle, (2) désigner la case de la carte de `../PROBLEM.md` §3 et la
> situation de `../USE-CASES.md` qu'elle sert, et (3) ne tomber dans aucun des
> non-buts déclarés dans `../VISION.md`. Une réponse absente est un signal
> d'arrêt, pas un détail à préciser plus tard.

**Une barrière de validation dans la roadmap.** L'expérience E3 (« publier le
diagnostic seul ») existait dans `../ASSUMPTIONS.md`, mais rien n'empêchait
d'enchaîner les paliers jusqu'au disque sans jamais confronter le produit à un
utilisateur. Elle devient un palier bloquant. Le principe d'ordonnancement gagne
une seconde règle, à côté de « on ne construit ni diagnostic ni recommandation
sur une mesure qui ment » : **on ne construit pas au-delà d'une capacité qu'on
n'a pas confrontée à un utilisateur.**

**La sémantique des mesures devient un prérequis.** `../DOCTRINE-LECTURE.md` dit
ce que Wisely a le droit de lire ; il ne dit nulle part ce que les chiffres
signifient. Or la somme des RSS n'est pas la RAM consommée (les pages partagées
sont comptées plusieurs fois), `loadavg` n'est pas un pourcentage CPU, et `nproc`
ne mesure aucun usage. `../RESOURCE-MODEL.md` comble ce trou et devient un
prérequis du palier Diagnostic.

Enfin, `wisely doctor` est renommé **`wisely diagnose`** : la commande n'est pas
écrite, le changement est donc gratuit, et le nom annonce la valeur plutôt qu'une
catégorie d'outil.

## Ce que cette décision ne dit pas

**Elle n'annule pas 0005.** La boucle fermée, le switch qui « reçoit ses deux
extrémités », l'invariant de non-destruction de `.wslconfig` et le contrat de
lecture invitée sont conservés intacts. 0005 avait raison sur la direction ; 0013
corrige l'**altitude** à laquelle elle est formulée. Le switch, le monitoring,
l'historique, la lecture in-distro et l'écart restent tous — ils cessent
seulement d'être *le produit* pour devenir les briques d'une question plus
profonde : *pourquoi WSL fait-il cela, est-ce un problème, et que dois-je faire ?*

**Elle ne relance pas la course au tableau de bord.** L'audit confirme ce que
`../PROBLEM.md` §5 constatait déjà : la catégorie « gestionnaire WSL graphique »
est occupée. L'exclusion posée par `../VISION.md` reste entière.

**Elle n'introduit aucune intelligence artificielle dans le produit.** L'audit
est explicite et le dépôt le suit : le raisonnement primaire doit rester
déterministe, explicable et local.

## Retenu mais différé

Le **Resource Evidence Graph** (audit §28) — chaque recommandation adossée à un
graphe de preuves horodatées et pondérées en confiance. L'idée est juste et
différenciante, mais c'est une superstructure sur des données qui n'existent pas
encore, pour un produit qui n'a aucun utilisateur. Sa brique réellement utile est
le **contrat de métrique** (audit §34), qui part dans `../RESOURCE-MODEL.md`
immédiatement. Le graphe est à rouvrir **après** la barrière de validation.

L'**architecture cible en couches** (audit §33) est retenue comme vue logique,
mais ne devient pas un document maintenant : sans code correspondant, ce serait un
dessin. Elle deviendra `ARCHITECTURE.md` quand le palier Diagnostic la rendra
réelle.

## Conséquences

- `../VISION.md` est réécrit : capacité, quatre objets, boucle à cinq maillons,
  écart requalifié, nouveau filtre de périmètre, non-buts déclarés.
- `../PRINCIPLES.md` : principe 1 reformulé (configuration vs consentement),
  principe 9 renforcé (portée, source, fraîcheur, confiance), principes 13
  (expliquer avant de recommander) et 14 (la provenance est visible) ajoutés.
- `../PROBLEM.md` : le problème énoncé côté utilisateur d'abord ; segment
  primaire par **situation** et non par métier.
- `../RESOURCE-MODEL.md` et `../USE-CASES.md` créés.
- `../ROADMAP.md` réordonné en paliers de capacités validables, avec la barrière
  de validation, et l'historique remonté **avant** la recommandation — une
  recommandation sourcée par un pic sur 14 jours exige que l'historique existe.
- `../ASSUMPTIONS.md` : hypothèses A9, A10, A11 ajoutées, registre reclassé,
  journal de validation ouvert.
- 0005 passe en statut `révisée`.
- **Aucun changement de code de production.** v2.5 « Vérité » reste la prochaine
  priorité d'implémentation — conformément à ce que l'audit défend lui-même.

Cette décision repose sur A9 (`../ASSUMPTIONS.md`), non validée : que le
diagnostic ait plus de valeur que le switch. Elle est prise parce qu'elle est
meilleure que les alternatives **quelle que soit** la réponse — même si le switch
reste le geste le plus utilisé, un outil qui explique ce qu'il mesure vaut mieux
qu'un outil qui affiche des chiffres dont il ignore le sens.
