# 0004 — Organisation GitHub pour la gouvernance

**Statut :** en attente — dépend de A1 (`../ASSUMPTIONS.md`)
**Date :** 2026-08-25

## Contexte

Le projet a un bus factor de 1. Une organisation GitHub faciliterait l'ajout de
co-mainteneurs et mutualiserait la publication sur PowerShell Gallery.

## Décision

Créer une organisation GitHub **Wisely** pour héberger le projet.

## Report du 2026-08-26

La décision reste bonne dans son principe, mais elle était couplée à la
publication sur PowerShell Gallery, elle-même repoussée par
[0009](0009-distribution-apres-le-produit.md). Créer une organisation pour
accueillir des co-mainteneurs qui n'existent pas, autour d'un projet sans
utilisateurs, résout un problème qu'on n'a pas encore.

La migration reste un prérequis administratif à traiter **avant** le cycle de
distribution, pas avant les cycles de produit qui le précèdent.

## Conséquences

- Aucun blocage sur les cycles v2.4 à v3.3.
- À rouvrir en même temps que [0009](0009-distribution-apres-le-produit.md).
