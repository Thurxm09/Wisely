# Modèle de ressources — ce que chaque chiffre veut dire

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> que signifie exactement chaque grandeur que Wisely affiche, et laquelle
> refuse-t-il d'afficher ?
>
> **Ce document est écrit avant l'implémentation, volontairement**, comme
> `DOCTRINE-LECTURE.md` l'a été. La raison est la même : une mesure dont on ne
> sait pas dire la signification est plus dangereuse qu'une mesure absente, parce
> qu'elle est indiscernable d'une mesure juste.
>
> Rapport avec `DOCTRINE-LECTURE.md` : celui-ci dit **ce que Wisely a le droit de
> lire** ; celui-ci dit **ce que ça signifie**. Les deux listes de commandes
> doivent rester identiques à la ligne près.
>
> Statut : doctrine. Dernière révision : 2026-08-27.

---

## 1. Pourquoi ce document existe

L'audit stratégique d'août 2026 a mis le doigt sur un piège que la doctrine de
lecture n'adressait pas : elle autorise `ps -eo rss,comm` et `nproc` sans dire ce
qu'on a le droit d'en déduire. Or :

- **la somme des RSS de tous les processus n'est pas la RAM consommée** — les
  pages partagées sont comptées dans chaque processus qui les mappe ;
- **`loadavg` n'est pas un pourcentage CPU** ;
- **`nproc` ne mesure aucun usage** — il dit ce que l'invité *voit* ;
- **8 Go consommés ne sont pas 8 Go nécessaires** — une part est du cache que
  Linux rendra sous pression.

Chacune de ces quatre erreurs produit un chiffre plausible, affichable, et faux.
Chacune détruit la confiance une seule fois, définitivement. Ce document existe
pour qu'aucune ne puisse entrer dans le produit par inadvertance.

---

## 2. La taxonomie de mesure

Toute grandeur manipulée par Wisely appartient à **une** de ces quatre classes.
La classe est une propriété de la mesure, pas une opinion sur elle, et elle est
**visible côté utilisateur**.

| Classe | Définition | Exemple | Ce qu'on a le droit d'en dire |
|---|---|---|---|
| **Directe** | Lue telle quelle à sa source, sans transformation | `MemTotal` de `/proc/meminfo` | « C'est la valeur. » |
| **Attribuée** | Rattachée à une entité par une règle explicite, avec un reste non attribuable | RSS de `python3` | « C'est ce qui est rattachable à X », **jamais** « c'est ce que X consomme » |
| **Estimée** | Calculée à partir d'autres mesures, avec des hypothèses nommées | Mémoire « réellement nécessaire » = active hors cache | « Estimation, sous telle hypothèse » |
| **Corrélée** | Deux grandeurs varient ensemble, sans lien causal établi | Pic de `VmmemWSL` et démarrage d'un conteneur | « Observé en même temps », **jamais** « causé par » |

**Règle d'affichage.** Une mesure attribuée s'affiche toujours avec sa ligne
« non attribué ». Une estimation s'affiche toujours avec l'hypothèse qui la
produit. Une corrélation ne s'affiche jamais sous une formulation causale.

---

## 3. Le contrat de métrique

Toute mesure porte quatre qualités : **portée, source, fraîcheur, confiance**
(principe 9). C'est la forme cible, exprimée ici en JSON pour la lisibilité —
aucune obligation de la sérialiser telle quelle en PowerShell, mais aucune mesure
ne doit manquer un de ces champs conceptuellement.

```json
{
  "timestamp":   "2026-08-27T14:03:11Z",
  "scope":       "distro",
  "entity":      "Ubuntu",
  "metric":      "memory.available",
  "value":       3120,
  "unit":        "MB",
  "source":      "/proc/meminfo",
  "confidence":  "high",
  "freshnessMs": 340,
  "attribution": "direct"
}
```

### Portées (`scope`)

| Portée | Ce qu'elle désigne |
|---|---|
| `host` | La machine Windows entière |
| `vm` | La machine virtuelle WSL2, toutes distributions confondues (`VmmemWSL`) |
| `distro` | Une distribution nommée |
| `process` | Un processus à l'intérieur d'une distribution |
| `policy` | Une valeur de configuration, non une mesure |

**Une portée ne se mélange jamais à une autre sans le dire.** Comparer une valeur
de portée `vm` à un seuil pensé pour une portée `host` est exactement le bug qui
a rendu l'alerte RAM mathématiquement indéclenchable pendant toute la vie du
projet (`AUDIT.md`, corrigé en v2.5).

### Niveaux de confiance

| Niveau | Critère |
|---|---|
| **Haute** | Mesure directe, source unique, sémantique documentée par l'amont (noyau Linux, API Windows) |
| **Moyenne** | Mesure attribuée avec reste explicite, ou directe mais à sémantique ambiguë selon la version de la plateforme |
| **Basse** | Estimation ou corrélation. **Ne fonde jamais une recommandation à elle seule** (principe 10) |

### Fraîcheur

Une mesure prise il y a trente secondes sur un système qui vient de démarrer un
conteneur n'est pas une mesure de l'état courant. Toute vue affiche l'âge de ses
données ; `/proc/uptime` sert à savoir si une mesure est représentative ou prise
juste après un démarrage.

---

## 4. La mémoire

C'est la ressource centrale, et celle où les pièges sont les plus coûteux.

### 4.1 RAM hôte — portée `host`

**Source :** `Win32_OperatingSystem` (`FreePhysicalMemory`, `TotalVisibleMemorySize`),
déjà utilisé par `Get-RamInfo` dans `wisely.ps1`.
**Classe :** directe. **Confiance :** haute.

**Ce que c'est :** la mémoire physique que Windows considère comme libre.
**Ce que ce n'est pas :** la mémoire *disponible*. Windows garde en cache une
part importante de mémoire qui serait rendue sous pression. Un « 2 Go libres »
n'est donc pas un état d'urgence en soi.

### 4.2 RAM WSL2 vue de Windows — portée `vm`

**Source :** `Get-Process` sur le processus de la machine virtuelle
(`WorkingSet64`).
**Classe :** directe. **Confiance :** haute sur la valeur, **basse sur son
interprétation**.

**Ce que c'est :** un agrégat unique contenant le noyau Linux, le page cache et
tous les processus invités de **toutes** les distributions.
**Ce que ce n'est pas :** ce dont WSL2 a besoin. C'est ce qu'il a pris.

> **Piège de nommage, à traiter partout.** Le processus s'appelle `vmmem` sur les
> versions plus anciennes de Windows et `VmmemWSL` sur Windows 11 récent. Le code
> ne cherchait auparavant que `vmmem` (`modules/Monitor.ps1`, `modules/MonitorTask.ps1`),
> ce qui rendait toute la couche d'observation silencieusement inopérante sur une
> partie du parc. **Corrigé en P0/v2.5** : les deux fichiers utilisent désormais
> `Get-Process -Name "VmmemWSL", "vmmem"`. **Toute lecture de ce processus doit accepter
> les deux noms, et dire explicitement quand elle ne trouve ni l'un ni l'autre.**

### 4.3 RAM vue de Linux — portée `distro`

**Source :** `cat /proc/meminfo`. **Classe :** directe. **Confiance :** haute.

C'est ici que se joue la distinction la plus importante du domaine.

| Champ | Ce qu'il veut dire | Piège |
|---|---|---|
| `MemTotal` | Ce que l'invité croit avoir | Reflète le plafond `.wslconfig`, pas la RAM physique |
| `MemFree` | Mémoire strictement inutilisée | **Presque toujours bas, et ce n'est pas un problème** — Linux utilise la RAM libre comme cache |
| `MemAvailable` | Mémoire mobilisable sans swapper | **C'est le bon chiffre pour « reste-t-il de la marge ? »**, pas `MemFree` |
| `Cached` + `Buffers` | Page cache — données de fichiers gardées en mémoire | Récupérable sous pression. C'est ce que `autoMemoryReclaim` rend à Windows |
| `SwapTotal` / `SwapFree` | Swap configuré et libre | Du swap *utilisé* n'est pas en soi une pathologie |
| `Dirty` / `Writeback` | Pages en attente d'écriture disque | Contexte d'un pic d'I/O, jamais une mesure de consommation |

**La règle qui en découle :** la « mémoire réellement nécessaire » d'une
distribution est une grandeur **estimée**, dérivée de l'anonyme (hors cache), et
elle s'affiche toujours comme telle.

### 4.4 Attribution par processus — portée `process`

**Source :** `ps -eo rss,comm --sort=-rss`. **Classe : attribuée.**
**Confiance :** moyenne, jamais haute.

**Le piège central de tout le produit :**

> **La somme des RSS de tous les processus n'est jamais présentée comme égale à
> la mémoire consommée.**

Le RSS d'un processus inclut toutes les pages physiques qu'il mappe, **y compris
celles qu'il partage** avec d'autres (bibliothèques, mémoire partagée, pages
copy-on-write d'un `fork`). La même page est donc comptée dans chaque processus
qui la mappe. Additionner les RSS peut dépasser la mémoire réellement occupée,
parfois largement.

**Conséquences contraignantes :**

1. Une vue d'attribution affiche toujours une ligne **« non attribué »**, et
   celle-ci peut être négative si les doubles comptages dominent — auquel cas
   c'est ce fait qui s'affiche, pas un zéro cosmétique.
2. Le total d'une vue d'attribution n'est **jamais** présenté comme le total de
   la consommation. Les deux chiffres coexistent, avec leurs classes.
3. La formulation est « ce qui est rattachable à `python3` », jamais « ce que
   `python3` consomme ».
4. `comm` donne le nom de la commande, pas ses arguments — choix de la doctrine
   de lecture §2.4, pour ne pas voir passer de jetons ni de chemins privés. Wisely
   sait donc qu'un processus s'appelle `python3` ; il ne sait pas ce qu'il exécute,
   et ne doit jamais faire mine de le savoir.

### 4.5 `autoMemoryReclaim` — portée `policy`

**Ce que ce réglage change n'est pas la valeur de la mesure : c'est sa
signification dans le temps.** En mode `gradual`, la mémoire cache inactive est
progressivement rendue à Windows ; en `dropCache`, elle l'est brutalement. Une
même charge de travail produit donc des courbes de `VmmemWSL` radicalement
différentes selon ce réglage.

**Règle :** aucune recommandation portant sur le plafond mémoire ne peut être
formulée sans indiquer l'état de `autoMemoryReclaim`. Recommander d'augmenter un
plafond alors que ce réglage est désactivé, c'est traiter un symptôme dont la
cause est connue et corrigeable à coût nul.

---

## 5. Le CPU

**Sources :** `nproc` (portée `distro`), `cat /proc/loadavg` (portée `distro`),
CPU du processus de la VM côté Windows (portée `vm`).

| Grandeur | Ce que c'est | Ce que ce n'est **pas** |
|---|---|---|
| `nproc` | Le nombre de processeurs que l'invité voit | Un usage. Sert **uniquement** à vérifier que le plafond `processors` est appliqué |
| `loadavg` 1/5/15 | Moyenne du nombre de tâches exécutables **ou en attente d'I/O ininterruptible** | Un pourcentage. Une charge de 4,0 sur 8 cœurs n'est pas « 50 % » — et une charge élevée peut venir d'une attente disque, pas du CPU |
| CPU de la VM côté Windows | Part du temps processeur consommée par la machine virtuelle | Comparable au `loadavg` invité : les deux grandeurs n'ont pas la même sémantique |

> **Il n'y a pas d'« écart CPU ».** Comparer `loadavg` à `processors` produit un
> chiffre qui a l'air d'un taux d'utilisation et n'en est pas un. Tant qu'aucune
> mesure d'utilisation CPU réelle et attribuable n'est disponible, Wisely affiche
> le contexte de charge et **s'abstient de tout diagnostic CPU chiffré**.

C'est un cas d'application directe du principe 9 : une grandeur qu'on ne peut pas
attribuer ne s'affiche pas comme si on le pouvait.

---

## 6. Le disque

Quatre grandeurs distinctes, régulièrement confondues — y compris dans les
articles de blog qui traitent du sujet.

| Grandeur | Source | Ce que c'est |
|---|---|---|
| **Occupation logique** | `df -P /` dans la distribution | Ce que le système de fichiers Linux considère comme occupé |
| **Taille du VHDX** | Taille du fichier `ext4.vhdx` côté Windows | Ce que le disque virtuel occupe réellement sur le disque hôte |
| **Écart de compaction** | Différence entre les deux | Espace alloué au VHDX mais libéré à l'intérieur de Linux |
| **Récupérable** | Dépend du régime | Ce qu'une opération donnée rendrait effectivement |

**Le régime change tout.** Avec `sparseVhd` actif, la désallocation se fait à la
suppression des fichiers et `Optimize-VHD` est inopérant — la méthode correcte
devient `fstrim` depuis Linux. Sans `sparseVhd`, le VHDX ne rétrécit pas seul.
Les deux approches sont mutuellement exclusives, et c'est la raison du retrait de
`-Reclaim` (`decisions/0010-retrait-reclaim-optimize-vhd.md`).

**Règle :** Wisely **explique** cet écart, il ne « nettoie » pas. Détecter le
régime, mesurer le récupérable, montrer la commande adaptée. Conformément à
`DOCTRINE-LECTURE.md` §2.1, une opération exigeant une écriture invitée — `fstrim`
en particulier — est affichée et expliquée, jamais exécutée.

---

## 7. Les grandeurs que Wisely refuse d'afficher

Application directe du principe 9. Cette liste est aussi contraignante que les
précédentes.

| Grandeur | Pourquoi elle est refusée |
|---|---|
| Un « % d'utilisation CPU » de WSL2 | Aucune source ne le fournit avec une sémantique unique (§5) |
| Une somme de RSS présentée comme la consommation totale | Double comptage des pages partagées (§4.4) |
| Un « écart » sur une ressource sans plafond configurable | Il n'y a pas de borne « autorisée » à laquelle comparer |
| La RAM libérée par un `wsl --shutdown` attribuée au profil **cible** | Mesure l'arrêt de la session **précédente** — c'était le défaut de `ramDeltaGB`, retiré en v2.5 (P0) |
| Toute métrique dégradée en `$null` silencieux | Indiscernable d'une valeur nulle légitime. Une mesure qui échoue **le dit** |
| Une cause présentée comme établie à partir d'une corrélation | « Observé en même temps » n'est pas « causé par » (§2) |

---

## 8. Ce que Wisely lit, et où

Cette liste doit rester **identique** à celle de `DOCTRINE-LECTURE.md` §2.3.
Toute divergence entre les deux documents est un défaut à corriger immédiatement,
dans les deux sens.

| Commande | Portée | Classe | Ce qu'elle fonde ici |
|---|---|---|---|
| `cat /proc/meminfo` | `distro` | directe | §4.3 — le cœur de la mesure mémoire |
| `cat /proc/loadavg` | `distro` | directe | §5 — contexte de charge, jamais un taux |
| `cat /proc/uptime` | `distro` | directe | §3 — représentativité d'une mesure |
| `df -P /` | `distro` | directe | §6 — occupation logique |
| `nproc` | `distro` | directe | §5 — vérification du plafond, jamais un usage |
| `ps -eo rss,comm --sort=-rss` | `process` | **attribuée** | §4.4 — attribution, avec reste explicite |

Côté Windows, hors contrat de lecture invitée : énumération WSL
(`wsl --list --verbose`, `wsl --list --running --quiet`, `wsl --version`),
processus de la machine virtuelle (§4.2), `Win32_OperatingSystem` (§4.1),
et localisation + taille du VHDX de la distribution active (registre
`HKCU:\...\Lxss\{GUID}\BasePath`, puis taille du fichier `ext4.vhdx` à cet
emplacement — jamais son contenu, jamais son ouverture).

---

## 9. Comment ce document est utilisé

Aucune grandeur ne doit apparaître dans le produit sans une entrée ici décrivant
sa portée, sa source, sa classe et sa confiance. Ajouter un affichage sans
compléter ce document est un défaut au même titre qu'ajouter une commande invitée
sans compléter `DOCTRINE-LECTURE.md`.

Si une mesure ne peut pas être décrite dans ces termes, ce n'est pas ce document
qui est incomplet : **c'est la mesure qui n'est pas prête à être affichée.**

---

## Documents liés

- `DOCTRINE-LECTURE.md` — ce que Wisely a le droit de lire (§8 doit y correspondre)
- `PRINCIPLES.md` — principe 9 (portée, source, fraîcheur, confiance), principe 10
  (aucune recommandation sans sa mesure), principe 13 (expliquer avant de recommander)
- `VISION.md` — pourquoi l'écart est une vue dérivée et non l'ontologie du produit
- `ROADMAP.md` — ce document est un prérequis du palier Diagnostic
- `decisions/0013-adoption-audit-strategique-externe.md` — la décision qui l'a créé
