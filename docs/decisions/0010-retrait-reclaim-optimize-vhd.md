# 0010 — Retrait de `-Reclaim` sous sa forme `Optimize-VHD`

**Statut :** acceptée — l'axe disque est repris autrement en v3.3
**Date :** 2026-08-26

## Contexte

L'ancienne roadmap planifiait en v3.1 une commande `wisely -Reclaim` orchestrant
« la séquence sûre déjà connue » : arrêt de la distribution puis
`Optimize-VHD -Mode Full`, ou séquence `diskpart` équivalente.

Vérification faite en août 2026 : depuis l'introduction du **sparse VHD**
(septembre 2023), `Optimize-VHD` **échoue** sur ces disques, avec un message
indiquant que le fichier ne doit pas être sparse. La méthode correcte devient
`fstrim` **depuis l'intérieur de Linux**, et les deux approches sont mutuellement
exclusives. Un garde-fou `--allow-unsafe` a par ailleurs été ajouté en WSL 2.5.6
pour risque de corruption.

La feature était donc **obsolète avant d'être écrite**.

## Décision

`-Reclaim` sous sa forme planifiée est retirée de la roadmap.

L'axe disque n'est pas abandonné : il est repris en v3.3 sous une forme différente
— **détecter le régime** (sparse ou non), **mesurer** le récupérable, **router**
vers la bonne méthode, et **chiffrer** l'effet. Jamais exécuter une compaction à
l'aveugle.

Conformément à `../DOCTRINE-LECTURE.md` §2.1, si la bonne méthode est `fstrim`,
Wisely affiche la commande et l'explique : il ne l'exécute pas à la place de
l'utilisateur.

## Conséquences

- La valeur de l'axe disque se déplace de l'exécution vers le **routage** — ce
  qui est aussi ce qui le rend différenciant, puisque aucun outil recensé ne
  détecte le régime avant d'agir.
- Le risque « manipulation directe du VHDX » identifié dans l'ancienne roadmap
  diminue fortement, puisque Wisely cesse d'être l'acteur de l'opération
  destructive.
- Les scripts publics de compaction VHDX existants sont partiellement obsolètes
  pour la même raison : ne pas s'en inspirer sans vérifier leur date.
