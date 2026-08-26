# 0002 — Stratégie de test entièrement sans WSL2

**Statut :** acceptée
**Date :** 2026-08-25

## Contexte

Une machine de développement avec WSL2 est disponible, mais la CI tourne sur des
runners qui n'ont ni Windows configuré pour WSL2, ni WSL2 installé. La question
était de savoir si la stratégie de test devait dépendre d'un environnement réel.

## Décision

La suite de tests fonctionne **entièrement sans WSL2**, avec des mocks complets
des appels système (`wsl --shutdown`, `Register-ScheduledTask`,
`Get-CimInstance`, lecture de `.wslconfig`).

## Conséquences

- La CI et de futurs contributeurs externes peuvent exécuter la suite sans
  environnement Windows + WSL2 dédié.
- Toute nouvelle fonction qui touche au système doit être conçue pour être
  mockable : la collecte de données est séparée de l'affichage et des effets de
  bord. Le duo `Get-WatchSnapshot` / `Show-WslWatch` et la fonction
  `Test-WiselyNonInteractive` illustrent le motif attendu.
- Corollaire pour la v2.6 : la lecture dans la distribution devra suivre la même
  règle — invocations isolées dans des fonctions nommées et mockables.
