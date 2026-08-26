# 0011 — Changement de profil automatique reporté

**Statut :** acceptée — dépend de A5 (`../ASSUMPTIONS.md`)
**Date :** 2026-08-26 (révise le report non motivé du 2026-08-25)

## Contexte

L'ancienne roadmap présentait le changement de profil automatique comme « la
feature produit la plus impactante envisageable » et « potentiellement la plus
différenciante » : un moteur de règles déclenchant un changement selon le
processus actif, l'heure, l'état de la batterie.

La décision du 2026-08-25 le reportait, mais sans écrire de motif : « non
tranchée pour l'instant, volontairement reportée ». Un report sans raison écrite
se rouvre à chaque cycle.

## Décision

Reporté, **avec motif**, jusqu'à validation de A5.

## Motif

**L'action déclenchée est destructive.** Un changement de profil exécute
`wsl --shutdown`, ce qui interrompt tout ce qui tourne : serveurs de
développement, notebooks, compilations, conteneurs. Un moteur de règles qui tue
automatiquement la session Linux de quelqu'un parce qu'il est 22 h, ou parce que
la machine est passée sur batterie, est un moyen efficace de faire perdre du
travail.

**Automatiser un geste dont on ignore s'il vaut son prix amplifie le danger, pas
la valeur.** Tant que A5 n'est pas testée, on ne sait pas si les utilisateurs
changent de profil souvent — ni s'ils considèrent le coût acceptable quand ils le
font délibérément. L'automatiser reviendrait à leur imposer ce coût sans qu'ils
le choisissent.

L'intuition initiale de reporter était donc bonne ; seule la raison manquait.

## Conditions de réouverture

1. A5 validée : le geste vaut son prix et se répète.
2. Le coût du geste a baissé, ou est au moins **annoncé avant** d'être payé
   (principe 11, `../PRINCIPLES.md`).
3. Un besoin réel exprimé par un utilisateur, pas une déduction.

## Conséquences

- Les signaux d'entrée envisagés (GPU, alimentation) passent également en
  attente : exposer un signal en lecture seule pour préparer un moteur de règles
  reporté, c'est construire une dépendance vers une fonctionnalité qui n'existera
  peut-être jamais.
