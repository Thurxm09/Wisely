# 0006 — Profils dérivés plutôt qu'absolus

**Statut :** acceptée — implémentation planifiée v3.1
**Date :** 2026-08-26

## Contexte

Les trois profils livrés (`web` 4 Go / 3 CPU, `data` 6 Go / 5 CPU, `base` 2 Go /
2 CPU) sont des constantes absolues calibrées sur une machine 16 Go précise :
celle du mainteneur.

Cela produit trois problèmes distincts.

Le principe « les profils par défaut doivent couvrir 80 % des cas d'usage » est
**structurellement infalsifiable** : il ne peut être vrai que sur une seule
configuration matérielle. Sur 8 Go, `data` est dangereux ; sur 64 Go, il est
absurde.

Un plafond absolu **n'est pas partageable**. Cela invalide en cascade tout ce qui
repose sur le partage de profils : import/export, bibliothèque communautaire,
configurations d'équipe, cascade organisation/utilisateur.

Enfin, l'outil **se casse sur la prochaine machine de son propre auteur** : un
passage à 32 Go rend les trois profils livrés dénués de sens.

## Décision

Un profil cesse d'être un nombre et devient une **politique résolue à
l'application**, sur la machine réelle.

Exemples de formes envisagées, à figer lors de l'implémentation : « laisser N Go
à Windows », « prendre X % de la RAM hôte », « la moitié des cœurs logiques ». La
valeur absolue reste acceptée comme cas particulier, pour ne pas casser les
`profiles.json` existants (principe 7).

## Conséquences

- Résout la contradiction entre l'ambition d'audience ([0001](0001-audience-non-exclusivement-solo.md))
  et le principe « zéro configuration » (`../PRINCIPLES.md` §1).
- Rend le partage de profils possible, donc rouvre la question de l'import/export
  sur une base saine.
- Impose une migration de schéma `profiles.json` compatible descendante.
- Les libellés par métier (« WEB », « DATA SCIENCE ») sont à reconsidérer : ils
  décrivent un métier alors que la valeur décrit un plafond. Un profil devrait
  être nommé par ce qu'il fait à la machine, pas par ce que l'utilisateur est
  censé faire ce jour-là.
