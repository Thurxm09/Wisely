# Audits stratégiques — Wisely

> **Question à laquelle ce répertoire répond :** qu'ont dit les regards extérieurs
> portés sur la stratégie du projet, et qu'en a-t-on retenu ?

Ce répertoire conserve les **audits stratégiques externes** dans leur intégralité,
tels qu'ils ont été reçus.

## À ne pas confondre

| Fichier | Métier |
|---|---|
| `docs/audits/` (ce répertoire) | Regards extérieurs sur la **stratégie** : positionnement, vision, priorités |
| `docs/AUDIT.md` | Audit de **qualité du code** — findings numérotés, corrigés au fil des versions |

La collision de noms est réelle et volontairement levée ici : un document qui dit
« l'audit a montré que… » doit préciser lequel.

## Conventions

- **Un audit n'est jamais réécrit, ni corrigé, ni élagué.** Ses redondances, ses
  erreurs et ses angles morts font partie de la pièce. On le cite, on ne le
  retouche pas — même règle que pour les ADR (`../decisions/README.md`).
- **Un audit ne fait jamais foi.** Ce sont les documents de fond (`PROBLEM.md`,
  `VISION.md`, `PRINCIPLES.md`, `ROADMAP.md`) et les ADR qui font foi. Un audit
  est une entrée, pas une conclusion.
- **Tout audit archivé doit avoir son ADR de réponse**, qui dit ce qui en a été
  retenu, ce qui a été écarté, et pourquoi. Sans quoi le dépôt se retrouve avec
  deux stratégies concurrentes et aucun arbitrage.

## Index

| Audit | Date | Origine | ADR de réponse |
|---|---|---|---|
| [Audit stratégique d'août 2026](2026-08-audit-strategique-externe.md) | 2026-08 | IA externe, à la demande du mainteneur | [0013](../decisions/0013-adoption-audit-strategique-externe.md) |
