# Décisions — Wisely

> **Question à laquelle ce répertoire répond :** pourquoi a-t-on tranché ainsi,
> et quand ?

Chaque décision structurante vit dans son propre fichier, daté et révisable.
Cette organisation remplace le §10 monolithique de l'ancien `ROADMAP.md`, qui
mélangeait des décisions prises à des moments différents sans permettre d'en
réviser une seule sans toucher au reste.

## Conventions

- Un fichier par décision, numéroté séquentiellement, jamais renuméroté.
- **Statut** : `acceptée`, `révisée` (une décision ultérieure la modifie),
  `remplacée` (une décision ultérieure l'annule), `en attente` (dépend d'une
  hypothèse à valider — voir `../ASSUMPTIONS.md`).
- Une décision n'est **jamais supprimée ni réécrite**. On en ajoute une nouvelle
  qui la révise ou la remplace, et on met à jour son statut. L'historique du
  raisonnement a autant de valeur que sa conclusion.
- Une décision qui repose sur une hypothèse non validée doit le dire, et nommer
  l'hypothèse.

## Index

| # | Décision | Statut | Date |
|---|---|---|---|
| [0001](0001-audience-non-exclusivement-solo.md) | Audience non exclusivement solo | révisée | 2026-08-25 |
| [0002](0002-tests-sans-wsl2.md) | Stratégie de test entièrement sans WSL2 | acceptée | 2026-08-25 |
| [0003](0003-powershell-5-et-7.md) | PowerShell 5.1 et 7+ en parallèle | acceptée | 2026-08-25 |
| [0004](0004-gouvernance-organisation-github.md) | Organisation GitHub pour la gouvernance | en attente | 2026-08-25 |
| [0005](0005-direction-boucle-fermee.md) | Direction produit : la boucle fermée | acceptée | 2026-08-26 |
| [0006](0006-profils-derives.md) | Profils dérivés plutôt qu'absolus | acceptée | 2026-08-26 |
| [0007](0007-annulation-spike-terminal-gui.md) | Annulation du spike Terminal.Gui | acceptée | 2026-08-26 |
| [0008](0008-lecture-in-distro.md) | Lecture dans la distribution, sous contrat | acceptée | 2026-08-26 |
| [0009](0009-distribution-apres-le-produit.md) | Distribution large après le produit | acceptée | 2026-08-26 |
| [0010](0010-retrait-reclaim-optimize-vhd.md) | Retrait de `-Reclaim` sous sa forme `Optimize-VHD` | acceptée | 2026-08-26 |
| [0011](0011-auto-switch-reporte.md) | Changement de profil automatique reporté | acceptée | 2026-08-26 |
| [0012](0012-hooks-echec-par-regle.md) | Hooks : comportement d'échec choisi par règle | en attente | 2026-08-25 |
