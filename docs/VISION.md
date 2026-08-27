# Vision — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> quelle est la capacité fondamentale de Wisely ?
>
> Ce document est court volontairement. Il se lit en cinq minutes et se révise
> rarement — une révision ici est un changement de projet, pas un ajustement.
> Le problème auquel il répond est décrit dans `PROBLEM.md`.
>
> Statut : vivant, révision rare. Dernière révision : 2026-08-27
> (voir `decisions/0013-adoption-audit-strategique-externe.md`).

---

## La capacité fondamentale

> **Wisely transforme l'état réel des ressources WSL2 en décisions explicables et
> en actions sûres.**

**Catégorie :** WSL2 Resource Intelligence & Control.
**Promesse :** *Comprendre WSL. Agir en confiance.*

Cette formulation a été retenue parmi cinq, et les quatre autres échouent pour
des raisons instructives :

| Formulation | Pourquoi elle ne tient pas |
|---|---|
| « Gérer les ressources WSL2 » | Générique — décrit une catégorie d'outils, pas une capacité |
| « Monitorer WSL2 » | Ampute l'action, qui est le seul maillon que le projet détienne réellement |
| « Optimiser WSL2 » | Vague, et promet un résultat qu'aucune mesure ne peut garantir |
| « Relier ce que WSL2 consomme à ce qu'on l'autorise à consommer » | **Excellente abstraction interne**, trop étroite comme capacité : elle ne couvre ni le cache, ni le disque, ni l'I/O, ni le temps de démarrage |

La formulation retenue contient les cinq mouvements du produit : observer,
interpréter, recommander, agir, garantir la sûreté. Et elle survit à l'extension
du produit à de nouvelles ressources, ce que la précédente ne faisait pas.

---

## Les quatre objets

Tout ce que Wisely manipule se ramène à quatre objets. C'est le vocabulaire du
produit, et il doit se retrouver dans le code comme dans l'interface.

| Objet | Question | Exemple |
|---|---|---|
| **État** | Quel est l'état réel de WSL2, des deux côtés de la frontière ? | `VmmemWSL` occupe 7,8 Go ; `/proc/meminfo` de Ubuntu montre 2,0 Go de cache |
| **Cause** | Pourquoi cet état existe-t-il ? | `python3` retient 2,4 Go ; le reste non attribué est majoritairement du cache |
| **Politique** | Qu'est-ce que la machine est censée permettre ? | Plafond `.wslconfig` à 8 Go, `autoMemoryReclaim` désactivé |
| **Action** | Que peut-on faire sans mettre l'environnement en danger ? | Activer `autoMemoryReclaim=gradual` — configuration seule, aucun redémarrage |

---

## Le modèle : une boucle, pas un geste

```
  observer  ->  expliquer  ->  recommander  ->  agir  ->  vérifier
                                                  ^         |
                                                  |_________|
```

**« Expliquer » est un maillon nommé, et c'est délibéré.** L'ancienne formulation
de cette boucle disait « comprendre » — un mot qui range le travail le plus
difficile dans la tête de l'utilisateur, où il n'est ni construit, ni testé, ni
ratable. Expliquer est un livrable : l'utilisateur doit pouvoir comprendre son
état **même quand aucune action n'est recommandée**. C'est précisément là que se
trouve la douleur, et c'est ce que « Task Manager + WSL Settings + htop » ne
font pas bien *ensemble*.

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
| Choix du plafond | Une constante devinée | Une valeur dérivée de la consommation mesurée |
| Retour après action | « OK, WEB actif en 4.2s » | « Plafond 4 Go — pic mesuré sur 7 jours : 5,2 Go. Tu vas taper le plafond. » |
| Coût du geste | Invisible jusqu'à ce qu'il soit payé | Annoncé avant : voici ce qui va être interrompu |

Ce qui est concurrencé, c'est le switch *seul*. Le switch *informé et vérifié*
n'a aucun équivalent.

---

## L'écart, requalifié

L'écart — la distance entre ce que WSL2 prend et ce qu'il a le droit de prendre —
reste **la relation centrale entre l'État et la Politique**.

```
   consommé maintenant          autorisé              pic mesuré
          3,1 Go                  4 Go                  5,2 Go
   |========================|......|.....................|
   |------- mesuré ---------|      |                     |
                            |<-------- l'écart --------->|
```

Il a cessé d'être l'ontologie du produit, pour une raison précise.

**Ce qu'il modélise bien.** Les ressources à plafond configurable : mémoire
autorisée, CPU exposé, swap, et plus généralement toute politique de ressources
inscrite dans `.wslconfig`.

**Ce qu'il modélise mal.** Le cache Linux, l'I/O, le disque, le GPU, le temps de
démarrage, la pression mémoire, les anomalies. Aucune de ces grandeurs n'a de
« borne autorisée » à laquelle la comparer.

**Le piège qu'il crée.** Il masque la distinction la plus importante du domaine :
**8 Go consommés ne sont pas 8 Go nécessaires.** Une partie de ce que `VmmemWSL`
affiche est du cache que Linux rendra sous pression — ce que `autoMemoryReclaim`
exploite précisément. Un produit dont l'unité de pensée est l'écart est
structurellement tenté d'afficher un écart CPU, un écart cache, un écart disque :
tous faux, tous convaincants, tous destructeurs de confiance.

L'écart est donc une **vue dérivée** — puissante, conservée, mais dérivée. Ce qui
la précède, c'est la compréhension correcte de l'état des ressources et de sa
relation à une politique. Voir `RESOURCE-MODEL.md`.

---

## Le filtre de périmètre

Une capacité fondamentale se reconnaît à ce qu'elle sait dire non. Devant toute
proposition, dans cet ordre :

1. **Sert-elle un des quatre objets** — État, Cause, Politique, Action — pour un
   **maillon nommé** de la boucle ? Lequel ?
2. **Quelle case** de la carte du problème (`PROBLEM.md` §3) remplit-elle, et
   **quelle situation** de `USE-CASES.md` sert-elle ?
3. **Tombe-t-elle dans un non-but** déclaré ci-dessous ?

Une réponse absente à la question 1 ou 2 est un **signal d'arrêt**, pas un détail
à préciser plus tard. C'est ce test qui a écarté le spike Terminal.Gui, les hooks
et `-Snapshot` ; il doit continuer à pouvoir le faire.

---

## Ce que Wisely ne devient jamais

La liste est aussi contraignante que la capacité. Le défaut historique des outils
système est *« puisqu'on peut lire ce truc, ajoutons-le »* ; ces interdictions
existent pour que le minimalisme (principe 6) ait des dents.

Wisely ne devient pas :

- un gestionnaire complet de distributions (créer, cloner, exporter, supprimer) ;
- un terminal, ni un gestionnaire Docker ;
- un outil d'administration Linux généraliste ;
- un remplaçant de WSL Settings — Microsoft fournit les interrupteurs, Wisely dit
  lesquels actionner et pourquoi ;
- une plateforme d'observabilité généraliste, ni un tableau de bord permanent :
  « afficher des métriques » n'est pas une capacité, c'est un moyen ;
- un système d'agents permanents installés dans la distribution ;
- un « optimiseur » qui applique des réglages à l'aveugle ;
- une usine à profils ;
- une IA qui prétend comprendre ce que les métriques ne permettent pas de savoir.

Le GPU, le réseau et le pare-feu n'en relèvent pas non plus — sauf à devenir des
ressources dont l'État et la Politique sont réellement mesurables.

---

## Horizon

La vision ne s'exprime pas en dates — il n'y a pas de contrainte de délai sur ce
projet, et c'est un avantage à préserver : il autorise le bon ordre plutôt que
l'ordre du plus facile.

Elle s'exprime en trois niveaux, eux-mêmes découpés en paliers dans `ROADMAP.md` :

| Niveau | Ce que Wisely sait dire |
|---|---|
| **Contrôle** — aujourd'hui | « Je change les ressources, sans rien casser. » |
| **Intelligence** — demain | « Je comprends les ressources, et je peux l'expliquer. » |
| **Boucle fermée** — long terme | « Je comprends, je recommande avec ma preuve, j'agis, je vérifie. » |

Les paliers de capacité, dans l'ordre imposé par leurs dépendances :

1. **Les mesures sont honnêtes.** Prérequis absolu : on ne construit ni
   diagnostic ni recommandation sur une mesure fausse.
2. **Wisely voit des deux côtés de la frontière**, sous un contrat de confiance
   explicite (`DOCTRINE-LECTURE.md`).
3. **L'état est expliqué** — chaque chiffre porte sa portée, sa source, sa
   fraîcheur et sa confiance (`RESOURCE-MODEL.md`).
4. **Quelqu'un d'autre que le mainteneur s'en sert.** Palier bloquant, et non
   une étape de communication.
5. **La consommation a une histoire**, donc des tendances.
6. **La recommandation porte sa preuve**, et l'action est vérifiée après coup.

La distribution large vient après, délibérément. On ne dispose que d'un seul
lancement, et il ne doit pas être dépensé sur la version dont la plateforme
absorbe la proposition de valeur. Voir `decisions/0009-distribution-apres-le-produit.md`.

---

## Documents liés

- `PROBLEM.md` — l'espace de problème dont cette vision extrait une part
- `USE-CASES.md` — les situations réelles que la vision doit servir
- `RESOURCE-MODEL.md` — ce que signifie chaque chiffre affiché
- `PRINCIPLES.md` — comment trancher sans rouvrir cette question
- `ASSUMPTIONS.md` — ce que cette vision suppose et qui n'est pas vérifié
- `ROADMAP.md` — l'ordre dans lequel les paliers sont atteints
- `decisions/0013-adoption-audit-strategique-externe.md` — pourquoi cette vision
  plutôt que la précédente
