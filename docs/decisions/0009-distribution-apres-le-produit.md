# 0009 — Distribution large après le produit

**Statut :** acceptée — révise la décision de distribution du 2026-08-25
**Date :** 2026-08-26

## Contexte

La décision du 2026-08-25 actait la publication sur PowerShell Gallery, planifiée
en v3.0, comme « le changement d'adoption le plus impactant possible ». Winget
suivait, et l'ancienne roadmap en faisait la version majeure suivante.

## Décision

La distribution large — PowerShell Gallery, Winget, organisation GitHub,
packaging en module — est **déplacée après** les cycles produit, en v4.0.

## Motifs

**On ne dispose que d'un seul lancement.** L'attention d'un public est une
ressource non renouvelable : un outil découvert, essayé et jugé décevant n'est pas
réessayé six mois plus tard.

**La version actuelle serait lancée sur la mauvaise proposition de valeur.**
« L'outil qui évite d'éditer `.wslconfig` à la main » est ce que Microsoft vient
de livrer gratuitement avec WSL Settings.

**Les mesures mentent encore.** Publier un outil dont l'alerte ne peut pas se
déclencher et dont le rapport hebdomadaire attribue mal ses chiffres, c'est
distribuer les défauts avant les qualités.

**Le site publie un autre outil.** Il annonce la v2.0.0, un changelog arrêté là,
et documente partout une commande `wsl-switch` qui n'existe plus — un utilisateur
qui suit les instructions d'installation obtient un alias qui ne fonctionne pas.

**Et surtout : rien ne presse.** Le projet n'a aucune contrainte de délai. C'est
précisément ce qui permet d'attendre d'avoir quelque chose à montrer. Traiter
cette absence de contrainte comme un avantage stratégique plutôt que comme un
confort est le cœur de cette décision.

## Ce que cette décision ne dit pas

Elle ne repousse pas toute exposition publique. L'expérience E3
(`../ASSUMPTIONS.md`) — publier le diagnostic seul pour tester A1 — reste
souhaitable et *précède* la distribution. C'est un test d'audience, pas un
lancement : il ne demande aucun engagement et ne consomme pas le capital
d'attention.

## Conséquences

- v3.0 devient un cycle produit (« L'écart ») et non un cycle de distribution.
- [0004](0004-gouvernance-organisation-github.md) passe en attente et sera
  rouverte avec ce cycle.
- La resynchronisation du dépôt `wisely-site` devient un prérequis de v4.0, à
  traiter dans une passe dédiée.
- Le packaging en module PowerShell reste techniquement pertinent ; seul son
  calendrier change.
