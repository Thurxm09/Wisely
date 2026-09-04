# 0014 — Vie privée : les docs d'exécution du recrutement sortent du dépôt public

**Statut :** acceptée
**Date :** 2026-09-04

## Contexte

Ce dépôt est public, sous GPL, et c'est l'endroit exact où va quiconque
s'intéresse à Wisely — y compris les personnes visées par la campagne de
recrutement de testeurs (`RECRUITMENT.md` §2 et §3). Trois incidents survenus
le 2026-09-04, le jour même du lancement du canal 2/4 (`r/bashonubuntuonwindows`),
ont révélé que la documentation de fond hébergeait, sans que ce soit
nécessaire, deux catégories de contenu à risque :

1. **Un playbook de campagne lisible par ses cibles.** `docs/RECRUITMENT.md`
   contenait les personas, les canaux jugés un par un, les angles qui
   fonctionnent ou se retournent, et les brouillons de messages — y compris
   pour des canaux pas encore publiés. Un commentaire sceptique sur
   `microsoft/WSL#4166` (catégorie `incomprehension`, `observation unique`,
   consignée dans `ASSUMPTIONS.md`) a montré concrètement le mécanisme : un
   renvoi public automatique créé par GitHub à partir de la référence courte
   d'un canal externe citée dans un message de commit (`8804892`) exposait le
   vocabulaire interne de la campagne directement sous le commentaire posté.
   La règle 9 ajoutée à `RECRUITMENT.md` §5 corrige le mécanisme technique,
   mais pas le fait que le playbook complet restait lisible par quiconque
   ouvre `docs/` — la vraie porte d'entrée, pas seulement le renvoi GitHub.
2. **Des informations personnelles/opérationnelles sans rapport avec le
   produit.** `docs/CLAUDE.md` (fichier de mémoire pour les sessions Claude
   Code) exposait la configuration machine du mainteneur et un fragment de
   son nom d'utilisateur Windows réel — rien de tout cela n'aide quiconque à
   évaluer ou utiliser Wisely.

`docs/TASKS.md` relève de la même famille que (1) : suivi jour par jour de
quel canal a été publié quand, avec quel texte, et le détail des retours
individuels reçus (y compris le nom d'utilisateur d'un commentateur externe).

## Décision

**`CLAUDE.md`, `RECRUITMENT.md` et `TASKS.md` sont retirés du dépôt public et
déplacés dans le dépôt privé `Thurxm09/dotfiles` (`wisely/`).** Le contenu est
inchangé, seul l'emplacement change.

**Ce qui reste public, délibérément :** `VISION.md`, `PROBLEM.md`,
`PRINCIPLES.md`, `USE-CASES.md`, `DOCTRINE-LECTURE.md`, `RESOURCE-MODEL.md`,
`ROADMAP.md`, `decisions/`, `AUDIT.md`, `ASSUMPTIONS.md` (le tableau
d'hypothèses et le journal de validation, qui documentent l'incertitude
réelle du produit — c'est la même transparence que les ADR, pas un playbook).
Ce n'est pas une fermeture générale de la documentation : c'est la
distinction entre transparence *sur le produit* (sert celui qui l'évalue,
reste) et détail d'exécution *de la campagne* (sert le mainteneur, n'a rien à
faire sous les yeux de ses cibles).

**Aucune réécriture d'historique.** Les commits déjà mergés qui citent ou
contiennent ces fichiers restent dans l'historique public — `git rm` retire
le fichier de l'arborescence actuelle, pas de l'historique. Ce n'est pas
réparable rétroactivement sans réécrire l'historique d'une branche protégée,
ce que ce dépôt s'interdit.

## Motifs

- Un playbook de recrutement lisible par ses cibles contredit son propre
  objectif : chaque angle de `RECRUITMENT.md` §3 dépend de paraître
  spontané, et un lecteur qui tombe sur le document entier n'y croit plus —
  ni pour le message qu'il vient de lire, ni pour aucun des suivants.
- Le contrat de lecture du produit (`DOCTRINE-LECTURE.md`) engage Wisely à
  ne lire que ce qui est nécessaire, sous consentement. Le même principe
  vaut pour ce que le mainteneur expose de lui-même : rien qui ne serve pas
  celui qui lit.
- `docs/CLAUDE.md` n'a jamais eu vocation à être lu par un humain autre que
  le mainteneur — c'est un fichier de mémoire d'outil, pas de la
  documentation projet.

## Conséquences

- Les liens vivants vers `RECRUITMENT.md` et `TASKS.md` dans `ROADMAP.md`,
  `glossary.md`, `ASSUMPTIONS.md`, les protocoles `E4`/`E5` et le skill
  `wisely-conventions` sont annotés `(privé)` plutôt que supprimés, pour ne
  pas donner l'impression d'une référence cassée par erreur.
- Les mentions historiques dans `CHANGELOG.md`, `AUDIT.md`,
  `decisions/0007-*.md` et `docs/audits/` ne sont **pas** corrigées : elles
  décrivent un état passé, et ce dépôt s'interdit de réécrire rétroactivement
  les ADR et les audits archivés.
- Toute future décision de recrutement ou de suivi d'exécution se documente
  désormais dans `Thurxm09/dotfiles/wisely/`, pas ici.
