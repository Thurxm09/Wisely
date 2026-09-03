# E4 — Temps pour identifier la cause

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> comment conduit-on la session qui mesure l'expérience E4 d'`ASSUMPTIONS.md`, sans
> biaiser la comparaison entre les trois outillages ?
>
> Ce document ne contient ni l'hypothèse testée, ni son seuil de succès
> (`ASSUMPTIONS.md`, section E4 et tableau `Journal de validation`), ni les
> personas à recruter (`RECRUITMENT.md` §1), ni le vocabulaire de confiance
> utilisé pour consigner un résultat (`RECRUITMENT.md` §7). Il les cite, il ne
> les redit pas.
>
> Statut : contrat. Dernière révision : 2026-09-03.

---

## 1. Recrutement

Persona et priorité : `RECRUITMENT.md` §1, ordre **P1 > P3 > P2**. Aucun critère
de recrutement supplémentaire — E4 ne dépend pas d'un profil particulier de
connaissance de WSL2, contrairement au Niveau B du site (voir la note
d'`ASSUMPTIONS.md` entre E6 et E4 sur pourquoi les deux programmes restent
séparés).

Recrutement via la case « accepteriez-vous 20 minutes d'échange ? » du
formulaire de retour éclair (`.github/ISSUE_TEMPLATE/field-test.yml`). Ce
chiffre reste correct tel quel : E4 se fait par écrit, à son rythme (§4), pas
lors d'un rendez-vous calé à heure fixe — le temps réel passé par le testeur
tourne autour de 15 à 20 minutes, chronométrage inclus.

## 2. Message d'annonce

Envoyé par écrit (issue, message direct, réponse au formulaire) au volontaire,
**verbatim** :

> « Merci de vouloir donner un coup de main. Voici comment ça se passe : je te
> décris une machine dont WSL2 consomme anormalement de la mémoire, et je te
> demande de trouver la cause probable avec trois outils différents, chacun
> chronométré séparément. Tu chronomètres toi-même, avec ce que tu veux
> (téléphone, minuteur). Il n'y a rien à installer de plus que Wisely, et rien
> à réussir : ce qui m'intéresse, c'est combien de temps chaque outil te prend,
> pas si tu trouves vite. Tu m'envoies juste tes trois temps et, pour chacun,
> une phrase disant ce que tu as conclu. Ça prend entre 15 et 20 minutes. »

## 3. Règles de conduite

| Règle | Raison |
|---|---|
| **Le scénario est standardisé, identique pour les 5 participants.** Une anomalie WSL2 provoquée de façon identique — un fixture de test jetable, jamais un outil livré dans le produit. | Une anomalie propre à chaque machine rendrait le seuil « réduction ≥ 50 % » (`ASSUMPTIONS.md`) sans grande signification sur un échantillon de 5. |
| **L'ordre des trois outillages (Gestionnaire des tâches, `htop`, Wisely) est tiré au sort et communiqué avec le protocole**, différent pour chaque participant. | Sans randomisation, un effet d'apprentissage biaise systématiquement le dernier outil testé : qui a déjà vu la machine avec `htop` ira plus vite avec Wisely ensuite. |
| **Chaque outillage est chronométré jusqu'à l'énoncé écrit de la cause probable, jamais jusqu'à une action corrective.** | E4 mesure le diagnostic, pas la réparation — c'est ce que dit `ASSUMPTIONS.md` : « mesurer le temps nécessaire pour identifier la cause probable ». |
| **Aucun indice pendant le chronométrage.** | Une aide informelle invaliderait la comparaison entre outillages. |
| **Un abandon au-delà du délai plafond (8 minutes par outillage) se consigne comme temps plafond (8 min), jamais comme donnée manquante.** | Une donnée manquante disparaît silencieusement du résultat ; un temps plafond dit honnêtement que l'outil a échoué à ce délai. |

## 4. Déroulé

Deux paliers. Le premier est le défaut ; le second est une option, jamais un
préalable — proposer le second avant que le testeur ait exprimé une aisance
avec le partage d'écran est une erreur de recrutement, pas une variante
acceptable du protocole.

### Palier asynchrone (défaut) — écrit, ≈ 15-20 minutes du côté du testeur

1. Le testeur reçoit par écrit : le message d'annonce (§2), la description du
   scénario standardisé, l'ordre tiré au sort des trois outillages, et les
   règles de conduite du §3 reformulées simplement (pas d'indice, chronométrer
   jusqu'à l'énoncé de la cause, plafond à 8 minutes par outil).
2. Le testeur exécute les trois tâches à son rythme, chronomètre lui-même, et
   note pour chacune : le temps écoulé et une phrase disant la cause qu'il a
   identifiée.
3. Le testeur renvoie ses trois lignes de résultat par le canal de son choix
   (issue, DM, réponse au formulaire).
4. Confiance consignée dans `ASSUMPTIONS.md` : **rapporté seul** (grille de
   `RECRUITMENT.md` §7).

### Palier renforcé (option, jamais un préalable) — partage d'écran, ≈ 35-40 minutes

Réservé aux volontaires explicitement à l'aise avec un partage d'écran, jamais
présenté comme la voie normale. Même scénario et mêmes règles que le palier
asynchrone, mais observées en direct par le mainteneur :

- Accueil et rappel du principe (2 min).
- Trois tâches : présentation de l'outillage (1 min) + travail chronométré
  plafonné à 8 min + battement (1 min) — répété trois fois dans l'ordre tiré
  au sort.
- Clôture, questions ouvertes du testeur (2-3 min).

Confiance consignée : **reproduit localement** (`RECRUITMENT.md` §7) — la
mesure la plus fiable de la grille, parce qu'observée directement.

## 5. Codage et consignation

Chaque session (asynchrone ou renforcée) produit trois temps et trois causes
identifiées, un par outillage. Le résultat global d'E4 — comparaison des
temps moyens entre les trois outillages, et calcul de la réduction obtenue par
Wisely face au meilleur des deux autres — se consigne dans la ligne **E4** du
tableau `## Journal de validation` d'`ASSUMPTIONS.md` (colonnes `Résultat`,
`Décision`, `Date`), en notant pour chaque participant si sa mesure est
« rapporté seul » ou « reproduit localement ». Un mélange des deux paliers
dans le même échantillon est acceptable et attendu : élargir le funnel via le
palier asynchrone est précisément ce que cette révision du protocole vise.
