# 0001 — Audience non exclusivement solo

**Statut :** révisée par [0009](0009-distribution-apres-le-produit.md) et encadrée par `../ASSUMPTIONS.md` (A1)
**Date :** 2026-08-25

## Contexte

La question posée était : l'outil vise-t-il exclusivement les développeurs solo,
ou y a-t-il une ambition de support des configurations d'équipe ?

## Décision

Non, pas exclusivement solo. Ambition de support des configurations d'équipe, et
plus largement de « tous ceux qui utilisent WSL2, quel que soit leur usage, et
veulent en monitorer la consommation ».

## Révision du 2026-08-26

La décision reste valide comme **intention**, mais l'analyse stratégique en a
révélé deux problèmes que la formulation initiale masquait.

Premièrement, elle était en contradiction avec le principe « zéro configuration
requise » : trois profils exprimés en gigaoctets absolus, calibrés sur une machine
16 Go, ne peuvent pas servir de défaut à un public hétérogène. La contradiction
est levée par [0006](0006-profils-derives.md).

Deuxièmement, l'élargissement de cible n'est pas une décision qu'on peut prendre
seul : il repose entièrement sur l'hypothèse A1 (`../ASSUMPTIONS.md`), qui n'est
pas testée. L'ambition est donc conservée comme **direction**, pas comme fait
acquis, et les fonctionnalités qui n'ont de sens qu'en présence d'un public réel
(profils d'équipe, cascade organisation/utilisateur, bibliothèque communautaire)
sont explicitement mises en attente.

## Conséquences

- Aucune fonctionnalité ne doit supposer un utilisateur unique.
- Aucune fonctionnalité destinée aux équipes ne doit être construite avant que A1
  soit validée.
