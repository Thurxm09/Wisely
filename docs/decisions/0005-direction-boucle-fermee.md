# 0005 — Direction produit : la boucle fermée

**Statut :** acceptée
**Date :** 2026-08-26

## Contexte

Analyse stratégique complète menée sur l'état v2.3.0, à la demande du mainteneur,
avec pour question : construisons-nous le bon produit ?

Trois faits ont orienté la réponse.

**La proposition de valeur affichée est en train d'être absorbée par la
plateforme.** Microsoft livre WSL Settings (`wslsettings.exe`, WinUI 3), qui
édite `.wslconfig` graphiquement — mémoire, cœurs, swap. L'affirmation « Windows
ne propose aucun mécanisme natif », qui ouvrait l'ancienne roadmap, n'est plus
vraie.

**Trois défaillances silencieuses et indépendantes affectaient la couche
d'observation** : seuil d'alerte comparé à un dénominateur qui le rend
inatteignable, `ramDeltaGB` mesurant l'arrêt de WSL2 mais attribué au profil
cible, et `Get-Process -Name "vmmem"` ne trouvant rien sur Windows 11 récent où
le processus s'appelle `VmmemWSL`. Trois échecs totaux, invisibles — le signe que
cette couche n'a jamais eu de lecteur.

**Personne ne fait la jointure Windows/Linux.** Depuis Windows, `VmmemWSL` est une
boîte opaque ; depuis Linux, `htop` ignore le plafond. C'est le seul territoire
non occupé de l'espace de problème.

## Alternatives considérées

| Direction | Écartée parce que |
|---|---|
| Commutateur fiable (statu quo amélioré) | Proposition de valeur absorbée par WSL Settings ; déjà cloné par des outils tiers |
| Diagnostic seul | Un diagnostic sans action est un rapport ; jette le meilleur actif du projet |
| Observabilité continue | Bonne, mais c'est un composant, pas un produit |
| Gestionnaire WSL2 général | Produit générique sans proposition de valeur claire ; coût de maintenance prohibitif en solo |
| Gardien de `.wslconfig` | Pas une direction concurrente : c'est le socle des autres, traité comme invariant (principe 8) |

## Décision

Wisely est **la boucle de rétroaction que WSL2 n'a pas** : observer → comprendre
→ décider → agir → vérifier.

La capacité fondamentale est de **relier ce que WSL2 consomme à ce qu'on
l'autorise à consommer**, et l'unité de pensée est **l'écart** entre ces deux
grandeurs. Voir `../VISION.md`.

Le diagnostic sert de porte d'entrée ; la préservation de la configuration
d'autrui est un invariant non négociable.

## Ce que cette décision ne dit pas

**Elle n'abandonne pas le changement de profil.** Le maillon « agir » est le plus
difficile de la chaîne et le seul que le projet détienne : backup versionné,
validation post-écriture, rollback automatique, mode simulation, garde-fou sur
les sessions actives. Aucun concurrent identifié ne fait cela.

Le problème n'a jamais été que ce maillon soit mauvais, mais qu'il soit
**orphelin**. La décision lui rend ses deux extrémités : un plafond dérivé de la
mesure en amont, une vérification en aval. Ce qui est concurrencé, c'est le
switch *seul* ; le switch *informé et vérifié* n'a pas d'équivalent.

## Conséquences

- `ROADMAP.md` est réordonné autour des paliers de `../VISION.md`.
- Les mesures fausses deviennent bloquantes et passent en tête (v2.5).
- La lecture invitée devient nécessaire — voir [0008](0008-lecture-in-distro.md).
- Plusieurs fonctionnalités existantes ne survivent pas au filtre de l'écart :
  voir [0007](0007-annulation-spike-terminal-gui.md),
  [0010](0010-retrait-reclaim-optimize-vhd.md), et le tableau de `ROADMAP.md`.
- Cette décision repose sur A1 (`../ASSUMPTIONS.md`), non validée. Elle est prise
  parce qu'elle est meilleure que les alternatives **quelle que soit** la réponse
  à A1 : même sans public, un outil dont les mesures sont honnêtes vaut mieux
  qu'un outil dont elles mentent.
