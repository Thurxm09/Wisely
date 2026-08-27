## Description

<!-- Que fait cette PR ? Pourquoi ce changement ? -->

## Type de changement

- [ ] Correction de bug
- [ ] Nouvelle fonctionnalité
- [ ] Documentation
- [ ] Refactoring (pas de changement de comportement)
- [ ] Autre :

## Checklist

- [ ] Les tests Pester passent en local ou via CI
- [ ] PSScriptAnalyzer ne remonte aucun avertissement
- [ ] Toute nouvelle fonction dans `modules/` a des tests associés
- [ ] `data/profiles.json` reste valide contre `schemas/profiles.schema.json` si modifié
- [ ] Si ce changement modifie un comportement déjà documenté (fonction renommée/supprimée, bug corrigé, mesure retirée) : `grep` `docs/*.md`, `docs/decisions/*.md` et `README.md` pour l'ancienne description, le nom de fonction ou le comportement obsolète, et corrige-les dans **cette** PR — ne pas laisser une future PR "vérifier plus tard" (voir `docs/decisions/` pour l'exception : les ADR ne se corrigent pas, elles se révisent par une nouvelle décision)

## Comment tester

<!-- Étapes pour valider le changement manuellement, si applicable -->
