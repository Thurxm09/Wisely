# Vision — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> quelle est la capacité fondamentale de Wisely ?
>
> Ce document est court volontairement. Il se lit en cinq minutes et se révise
> rarement — une révision ici est un changement de projet, pas un ajustement.
> Le problème auquel il répond est décrit dans `PROBLEM.md`.
>
> Statut : vivant, révision rare. Dernière révision : 2026-08-26.

---

## La capacité fondamentale

> **Wisely relie ce que WSL2 consomme à ce qu'on l'autorise à consommer.**

Rien de plus, et surtout rien d'autre. Une capacité fondamentale se reconnaît à
ce qu'elle sait dire non.

Cette formulation a été retenue parmi cinq. Les quatre autres échouent pour des
raisons instructives : « bascule les ressources en sécurité » décrit le mécanisme
et non la capacité ; « rend visible ce que WSL2 coûte » ampute l'action et jette
le meilleur actif du projet ; « la boucle de rétroaction que WSL2 n'a pas » est
juste mais trop abstraite pour trancher une question de périmètre ; « dimensionne
d'après la réalité plutôt que d'après une supposition » est la meilleure promesse
tournée utilisateur, mais elle décrit le bénéfice, pas la capacité.

Celle-ci nomme la **jointure** — le seul territoire que personne n'occupe (voir
`PROBLEM.md` §2) — et contient les deux moitiés du produit : *consomme*
(mesurer) et *autorise* (agir).

---

## L'unité de pensée : l'écart

Tout le produit se dérive d'une seule grandeur : **la distance entre ce que WSL2
prend et ce qu'il a le droit de prendre.**

```
   consommé maintenant          autorisé              pic mesuré
          3,1 Go                  4 Go                  5,2 Go
   |========================|......|.....................|
   |------- mesuré ---------|      |                     |
                            |<-------- l'écart --------->|
```

Chaque fonction du produit est une opération sur cette grandeur :

| Fonction | Ce qu'elle est, exprimée en écart |
|---|---|
| Diagnostic | Mesurer l'écart, et dire d'où il vient |
| Recommandation | L'écart historique indique le plafond correct |
| Alerte | L'écart se referme — le plafond va être atteint |
| Switch de profil | Déplacer volontairement la borne « autorisé » |
| Vérification | L'écart a-t-il bougé comme annoncé ? |
| Historique | La trajectoire de l'écart dans le temps |

C'est le test à appliquer à toute proposition de fonctionnalité : **si elle ne
s'exprime pas comme une opération sur l'écart, elle n'appartient probablement pas
à Wisely.**

---

## Le modèle : une boucle, pas un geste

```
  observer  ->  comprendre  ->  décider  ->  agir  ->  vérifier
                                              ^          |
                                              |__________|
```

Wisely détient aujourd'hui **un seul maillon : « agir »**. Et c'est le plus
difficile de la chaîne. Backup versionné, validation post-écriture, rollback
automatique, mode simulation, garde-fou sur les sessions actives : aucun outil
concurrent identifié ne fait cela, et WSL Settings non plus.

Le problème n'a jamais été que ce maillon soit mauvais. Le problème est qu'il est
**orphelin** — une réponse sans question. C'est ce qui explique que trois
mécanismes du produit aient pu rester cassés sans que personne s'en aperçoive :
sans mesure autour du geste, rien ne pouvait les contredire.

**Le switch ne rétrécit pas. Il reçoit ses deux extrémités.**

| | Aujourd'hui | Avec la boucle |
|---|---|---|
| Choix du profil | Une constante devinée | Une valeur dérivée de la consommation mesurée |
| Retour après action | « OK, WEB actif en 4.2s » | « Plafond 4 Go — pic mesuré sur 7 jours : 5,2 Go. Tu vas taper le plafond. » |
| Coût du geste | Invisible jusqu'à ce qu'il soit payé | Annoncé avant : voici ce qui va être interrompu |

Ce qui est concurrencé, c'est le switch *seul*. Le switch *informé et vérifié*
n'a aucun équivalent.

---

## Ce que la vision exclut

Une capacité fondamentale trace une frontière. Ne relèvent pas de Wisely, sauf à
s'exprimer comme une opération sur l'écart :

- La gestion du cycle de vie des distributions.
- Le remplacement de WSL Settings comme éditeur de configuration. Microsoft
  fournit les interrupteurs ; Wisely dit lesquels actionner et pourquoi.
- Le GPU, le réseau, le pare-feu — sauf s'ils deviennent une ressource dont on
  mesure l'écart entre consommation et autorisation.
- Toute forme de tableau de bord généraliste. « Afficher des métriques » n'est pas
  une capacité, c'est un moyen.

---

## Horizon

La vision ne s'exprime pas en dates — il n'y a pas de contrainte de délai sur ce
projet, et c'est un avantage à préserver : il autorise le bon ordre plutôt que
l'ordre du plus facile.

Elle s'exprime en paliers de capacité :

1. **Les mesures sont honnêtes.** Rien ne ment. Prérequis absolu : on ne construit
   ni diagnostic ni recommandation sur une mesure fausse.
2. **Wisely voit des deux côtés de la frontière**, sous un contrat de confiance
   explicite (voir `DOCTRINE-LECTURE.md`).
3. **L'écart est mesuré, expliqué, et vérifié après action.** Le produit devient
   lui-même.
4. **Le plafond est dérivé de la réalité** plutôt que saisi à la main.
5. **L'écart a une histoire**, donc des tendances et des alertes fondées.

La distribution large vient après, délibérément. On ne dispose que d'un seul
lancement, et il ne doit pas être dépensé sur la version dont la plateforme
absorbe la proposition de valeur. Voir `decisions/0009-distribution-apres-le-produit.md`.

---

## Documents liés

- `PROBLEM.md` — l'espace de problème dont cette vision extrait une part
- `PRINCIPLES.md` — comment trancher sans rouvrir cette question
- `ASSUMPTIONS.md` — ce que cette vision suppose et qui n'est pas vérifié
- `ROADMAP.md` — l'ordre dans lequel les paliers sont atteints
- `decisions/` — pourquoi cette vision plutôt qu'une autre
