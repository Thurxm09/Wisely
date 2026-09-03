# E5 — Sortie brute contre sortie sourcée

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> comment conduit-on la session qui mesure l'expérience E5 d'`ASSUMPTIONS.md`, sans
> ancrer la réponse du testeur sur la première formulation qu'il voit ?
>
> Ce document ne contient ni l'hypothèse testée, ni son seuil de succès
> (`ASSUMPTIONS.md`, section E5 et tableau `Journal de validation`), ni les
> personas à recruter (`RECRUITMENT.md` §1). Il les cite, il ne les redit pas.
>
> Statut : contrat. Dernière révision : 2026-09-03.

---

## 1. Recrutement

Persona et priorité : `RECRUITMENT.md` §1, ordre **P1 > P3 > P2**. Même
population que E4 (`ASSUMPTIONS.md`, tableau `Journal de validation`, ligne
E5 : « ≥ 5 personnes » — une seule population, pas deux groupes de 5), donc un
volontaire peut faire E4 et E5 dans le même échange sans que ça double
l'échantillon requis pour l'une ou l'autre.

Recrutement via la même case « accepteriez-vous 20 minutes d'échange ? » du
formulaire de retour éclair. E5 à elle seule ne prend que 1 à 2 minutes du
temps du testeur — voir §4.

## 2. Message d'annonce

Envoyé par écrit, **verbatim** :

> « Je vais te montrer une phrase qui décrit ta consommation de mémoire, et te
> demander ce que tu ferais en la lisant. Il n'y a pas de bonne réponse — je
> veux juste savoir si elle te pousse à agir ou non. Ensuite je t'en montre une
> seconde, un peu différente, et je te pose la même question. Ça prend une
> minute ou deux. »

**Entièrement asynchrone : aucun palier renforcé n'est nécessaire.** Mesurer
quelle formulation déclenche une action n'a jamais requis d'observation en
direct, contrairement à E4 qui mesure un temps.

## 3. Règles de conduite

| Règle | Raison |
|---|---|
| **Conception intra-sujet : le même participant voit les deux formulations.** | C'est ce qu'implique déjà le chiffre « ≥ 5 personnes » du tableau `Journal de validation` — une seule population. Passer à un design inter-groupes doublerait silencieusement l'échantillon requis par rapport à ce qui est déjà écrit dans `ASSUMPTIONS.md`. |
| **L'ordre des deux formulations est tiré au sort, différent pour chaque participant.** | Neutralise l'effet d'ancrage : la première formulation vue influence toujours la lecture de la seconde. |
| **Les deux formulations sont reprises verbatim depuis `ASSUMPTIONS.md`, jamais reformulées.** | Une reformulation, même mineure, change ce qui est mesuré et invaliderait la comparaison. |
| **Ne jamais suggérer qu'une réponse est attendue.** | Répondre « d'accord », neutre, ou ne rien dire, entre les deux formulations — jamais de validation. |

## 4. Déroulé — asynchrone, ≈ 1-2 minutes

1. Le testeur reçoit une des deux formulations (ordre tiré au sort) :
   - « Ta consommation est de 7,3 Go. »
   - « Ta consommation est de 7,3 Go, dont 3,2 Go de cache, avec un pic de
     5,9 Go sur 14 jours ; voici pourquoi nous recommandons de ne pas
     augmenter le plafond. »
2. Question ouverte : « Qu'est-ce que tu ferais maintenant ? »
3. Le testeur répond par texte.
4. Le mainteneur envoie la seconde formulation, pose la même question.
5. Le testeur répond une seconde fois.

## 5. Codage et consignation

Chaque réponse est codée en binaire : **action déclenchée** (le testeur dit
qu'il changerait un réglage, chercherait plus loin, ou agirait concrètement)
ou **action non déclenchée** (le testeur dit qu'il ne changerait rien, ou reste
incertain sans dire qu'il agirait). Le résultat global d'E5 — la formulation
sourcée déclenche-t-elle strictement plus d'actions que la formulation brute,
sur l'échantillon complet — se consigne dans la ligne **E5** du tableau
`## Journal de validation` d'`ASSUMPTIONS.md` (colonnes `Résultat`,
`Décision`, `Date`). Confiance consignée : **rapporté seul**
(`RECRUITMENT.md` §7) — E5 n'a pas de palier renforcé, donc pas de tier
« reproduit localement » possible pour cette expérience.
