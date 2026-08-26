# 0012 — Hooks : comportement d'échec choisi par règle

**Statut :** en attente — la fonctionnalité elle-même n'est pas planifiée
**Date :** 2026-08-25

## Contexte

Un système de hooks `pre-switch` / `post-switch` définis dans `profiles.json`
avait été envisagé. La question posée : si un hook échoue (délai dépassé,
exception, code de sortie non nul), le changement de profil doit-il être
abandonné, poursuivi, ou l'utilisateur doit-il choisir ?

## Décision

Le choix revient à l'utilisateur, **au niveau de chaque règle** — par exemple une
clé `on-failure: abort | continue` par hook — plutôt qu'un comportement global
imposé par l'outil.

## Statut au 2026-08-26

La décision reste valide **si** les hooks sont implémentés un jour. Mais la
fonctionnalité elle-même ne figure plus dans la roadmap : elle ne s'exprime pas
comme une opération sur l'écart (`../VISION.md`), et aucun besoin utilisateur ne
l'appuie.

Cette décision est conservée pour deux raisons : elle documente un arbitrage déjà
réfléchi, et elle évite de le rejouer si la question se repose. Elle n'est pas un
engagement à livrer la fonctionnalité.

## Conséquences

- Aucune, tant que les hooks ne sont pas planifiés.
- Si la question revient, elle devra d'abord passer le filtre de
  `../PRINCIPLES.md` avant que ce détail d'implémentation ne redevienne
  pertinent.
