# Cas d'usage — les situations que Wisely doit servir

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> dans quelles situations concrètes quelqu'un aurait-il besoin de Wisely ?
>
> **Ce ne sont pas des personas.** Le métier est le mauvais axe : un étudiant et
> un ingénieur ML vivent exactement le même incident quand WSL2 mange toute la
> RAM ; un développeur web et un SRE vivent le même incident quand un service
> Linux tourne toute la nuit. Ce qui distingue les besoins, c'est la **situation**,
> pas la fiche de poste.
>
> **Avertissement, à ne pas contourner.** Aucune de ces situations n'a été
> observée chez un utilisateur réel. Elles sont dérivées de la plainte publique
> recensée dans `PROBLEM.md` §5 et du raisonnement, pas de la mesure. Elles sont
> là pour être falsifiées — voir `ASSUMPTIONS.md`.
>
> Statut : vivant. Dernière révision : 2026-08-27.

---

## Le segment primaire

> **Un utilisateur confronté à un problème de ressources WSL2 qu'il ne comprend pas.**

Tout le reste — Docker, workload Linux, multi-distribution, machine contrainte,
poste d'entreprise — est un **contexte** qui module la situation, pas un segment
distinct. C'est ce qui permet d'élargir l'audience sans fabriquer un produit
générique.

La bonne métrique de marché n'est donc pas « à quelle fréquence les gens
changent-ils de profil ? » mais **« à quelle fréquence rencontrent-ils un
problème de ressources WSL qu'ils ne savent pas expliquer ou résoudre
facilement ? »**.

---

## Comment lire une fiche

Chaque situation nomme ce que l'utilisateur dit, ce qu'il voit aujourd'hui, ce
qui lui manque, et ce que Wisely doit répondre en termes des quatre objets de
`VISION.md` — **État, Cause, Politique, Action**. Puis le rattachement : la case
de la carte de `PROBLEM.md` §3, le palier de `ROADMAP.md`, l'hypothèse en jeu.

---

## S1 — « WSL prend 9 Go et je ne sais pas pourquoi »

La situation la plus fréquente, et le point d'entrée de tout le produit. La
requête « VmmemWSL high memory » a un volume qui se mesure à la quantité
d'articles écrits pour y répondre.

**Ce qu'il voit.** Un processus opaque dans le Gestionnaire des tâches. Aucune
indication de ce qu'il contient, ni de s'il y a un plafond.
**Ce qui manque.** Tout, sauf le chiffre.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | 8,4 Go côté hôte ; plafond configuré à 10 Go |
| Cause | 5,1 Go rattachables aux processus des distributions actives, 2,6 Go de cache Linux, un reste non attribué explicite |
| Politique | `autoMemoryReclaim` désactivé |
| Action | Activer `autoMemoryReclaim=gradual` — configuration seule, risque faible — **avant** de toucher au plafond |

**Carte `PROBLEM.md` §3 :** RAM × « pourquoi ? ». **Palier :** Diagnostic.
**Hypothèses :** A2, A9, A10.

---

## S2 — « Docker a laissé la mémoire haute après un build »

Le contexte Docker Desktop est probablement la population WSL2 la plus nombreuse.
Docker recommande lui-même `autoMemoryReclaim` pour ce cas précis.

**Ce qu'il voit.** La RAM ne redescend pas après une opération lourde terminée.
**Ce qui manque.** Savoir que ce qui reste est majoritairement du cache, et que
c'est corrigeable par configuration plutôt qu'en tuant l'environnement.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | Consommation stable et haute, sans charge active correspondante |
| Cause | Rétention de cache, distinguée de la demande soutenue des processus |
| Politique | État de `autoMemoryReclaim`, plafond, swap |
| Action | Le réglage adapté — sans effacer `networkingMode`, `dnsTunneling` ni le reste du `.wslconfig` de Docker |

**Carte :** RAM × « pourquoi ? » et × « que faire ? ». **Palier :** Diagnostic.
**Principe engagé :** 8 — c'était la situation où le code était **activement
nuisible**, puisqu'un simple changement de profil effaçait les clés de Docker.
**Corrigé en P0/v2.5** : l'écriture de `.wslconfig` fusionne désormais les clés
gérées au lieu de régénérer le fichier (voir S5 ci-dessous).

---

## S3 — « Mon portable rame quand je lance mon environnement »

Machine contrainte, 8 à 16 Go, compétence système faible. La douleur est réelle
et permanente, pas ponctuelle.

**Ce qu'il voit.** Windows devient lent. Il ne sait pas nécessairement que WSL2
est en cause, ni ce qu'est `.wslconfig`.
**Ce qui manque.** Le lien entre la lenteur ressentie et la pression mémoire, et
un plafond dimensionné pour **sa** machine.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | Pression mémoire hôte, part prise par WSL2, marge restante pour Windows |
| Cause | Ce qui dans WSL2 explique cette part |
| Politique | Un plafond calibré sur 16 Go n'a aucun sens sur 8 Go |
| Action | Une politique dérivée de la machine réelle, pas trois valeurs absolues en gigaoctets |

**Carte :** RAM × « maintenant » et × « que faire ? ». **Paliers :** Diagnostic,
puis Politiques dérivées. **Décision :** `0006-profils-derives.md`.
**Hypothèse :** A7 — ce public est-il seulement atteignable en ligne de commande ?

---

## S4 — « Je ne sais pas quelle distribution consomme »

Le plafond de `.wslconfig` est **global à la machine** ; les charges de travail
sont **par distribution**. C'est le second désalignement structurel de
`PROBLEM.md` §2.

**Ce qu'il voit.** Un seul chiffre agrégé pour Ubuntu, `docker-desktop` et son
environnement de test réunis.
**Ce qui manque.** La ventilation — et l'aveu honnête que le levier disponible ne
l'est pas.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | La consommation par distribution en cours d'exécution |
| Cause | Les principaux consommateurs rattachables dans chacune |
| Politique | Le plafond est global — le dire, plutôt que laisser croire à un réglage par distribution |
| Action | Ce qui est réellement actionnable, distribution par distribution |

**Carte :** RAM × « pourquoi ? ». **Palier :** Attribution & historique.
**Hypothèses :** A8, A10.

---

## S5 — « Je veux changer `.wslconfig` sans casser Docker »

Situation typique du poste d'entreprise et de tout `.wslconfig` non trivial :
réseau miroir, DNS tunneling, réglages posés par une politique d'entreprise.

**Ce qu'il voit.** Un fichier partagé qu'il n'a pas entièrement écrit lui-même et
qu'il ne peut pas se permettre de perdre.
**Ce qui manque.** La garantie qu'un outil qui écrit dans ce fichier préserve ce
qu'il ne gère pas — **aucun des outils recensés ne l'offre**.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | Le contenu réel du fichier, clé par clé |
| Cause | La **provenance** : « Wisely gère cette clé » / « cette clé existe et n'est pas gérée par Wisely » |
| Politique | Ce que fait chaque clé non gérée, et si WSL Settings la couvre déjà |
| Action | Une écriture par fusion, jamais par régénération |

**Carte :** RAM/CPU/Swap × « le faire ». **Paliers :** Vérité & sûreté (l'écriture
non destructive), puis Diagnostic (`diagnose --explain`). **Principes :** 8, 14.

---

## S6 — « Mon disque se remplit et le VHDX ne rétrécit pas »

**Ce qu'il voit.** `ext4.vhdx` occupe 80 Go alors que `df` en annonce 30 utilisés
à l'intérieur.
**Ce qui manque.** La compréhension que quatre grandeurs différentes sont en jeu,
et que la bonne méthode dépend d'un régime qu'il ignore.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | Occupation logique, taille du VHDX, écart, récupérable réel |
| Cause | Le régime — `sparseVhd` actif ou non — et ce qu'il implique |
| Politique | Ce que la configuration actuelle permet |
| Action | La commande adaptée, **affichée et expliquée, jamais exécutée** pour ce qui exige une écriture invitée |

**Carte :** Disque × « pourquoi ? » et × « que faire ? ». **Palier :** Disque.
**Décision :** `0010-retrait-reclaim-optimize-vhd.md`. **Hypothèse :** A6.

---

## S7 — « J'ai changé mon plafond, est-ce que ça a servi à quelque chose ? »

La situation que personne ne formule spontanément, et qui est pourtant le maillon
qui ferme la boucle.

**Ce qu'il voit.** « Profil appliqué avec succès. » Et rien d'autre.
**Ce qui manque.** La preuve que le geste — qui a coûté l'interruption de tout
l'environnement Linux — a produit l'effet annoncé.

| Objet | Ce que Wisely doit dire |
|---|---|
| État | Avant / après, sur les mêmes grandeurs et avec les mêmes portées |
| Cause | Ce qui a réellement changé, et ce qui n'a pas bougé |
| Politique | La configuration effectivement en vigueur après écriture |
| Action | Effet conforme à l'annonce ? Rollback nécessaire ? |

**Carte :** RAM × « le maintenir ». **Palier :** Action sûre & vérification.
**Principes :** 10, 11. **Hypothèse :** A11.

---

## Ce que ce document n'est pas

- **Ni une liste de fonctionnalités** — une situation décrit un besoin, jamais une
  implémentation.
- **Ni une segmentation marketing** — les contextes (Docker, entreprise, machine
  contrainte) modulent les situations, ils ne les remplacent pas.
- **Ni une preuve** — voir l'avertissement en tête. Une situation qui ne serait
  jamais rencontrée par personne doit pouvoir être retirée d'ici sans nostalgie.

---

## Documents liés

- `PROBLEM.md` — l'espace de problème, dont ces situations sont la face vécue
- `VISION.md` — les quatre objets, et le filtre qui exige de désigner une situation
- `RESOURCE-MODEL.md` — ce que valent réellement les chiffres cités ici
- `ROADMAP.md` — les paliers qui servent ces situations, et dans quel ordre
- `ASSUMPTIONS.md` — les hypothèses que chaque situation engage
