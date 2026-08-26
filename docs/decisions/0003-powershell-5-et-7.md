# 0003 — PowerShell 5.1 et 7+ en parallèle

**Statut :** acceptée
**Date :** 2026-08-25

## Contexte

PowerShell 5.1 est inclus dans Windows et constitue le plus petit dénominateur
commun. PowerShell 7+ apporte des facilités réelles mais exige une installation.

## Décision

Support de PowerShell 7+ **en parallèle** de 5.1. Aucune dépréciation de 5.1.

## Conséquences

- Pas de syntaxe exclusive à PS7 dans le code de production (`??=`,
  `ForEach-Object -Parallel`, opérateurs de chaînage ternaires).
- `Test-Json`, utilisé par `tests/Schema.Tests.ps1`, n'existe qu'en PS7 : c'est
  une dépendance de **développement**, pas d'exécution, et cette asymétrie est
  assumée.
- Toute fonctionnalité exigeant PS7 à l'exécution devrait faire l'objet d'une
  nouvelle décision, pas d'un glissement silencieux.
