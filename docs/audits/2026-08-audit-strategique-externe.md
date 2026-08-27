> ---
>
> **Document archivé — pièce d'analyse, ne fait pas foi.**
>
> **Origine :** audit stratégique produit par une IA externe en août 2026, à la
> demande du mainteneur, à partir du dépôt `Thurxm09/Wisely`.
> **Statut :** archivé intégralement, **jamais réécrit** — y compris ses
> redondances (§9 et §23 sont identiques, §12 et §25 aussi) et ses marqueurs de
> citation internes, qui font partie de la pièce.
> **Ce qui en a été retenu, écarté, et pourquoi :**
> [`decisions/0013-adoption-audit-strategique-externe.md`](../decisions/0013-adoption-audit-strategique-externe.md).
> **Vérification indépendante :** ses trois constats de code (détection `vmmem`,
> identité du profil actif par égalité de valeur, réécriture destructive de
> `.wslconfig`) ont été vérifiés dans le code et sont exacts.
>
> Les documents qui font foi restent `PROBLEM.md`, `VISION.md`, `PRINCIPLES.md`,
> `ROADMAP.md`, `ASSUMPTIONS.md` et `decisions/`.
>
> ---

# Audit stratégique de Wisely — août 2026

J’ai pris le dépôt `Thurxm09/Wisely` comme source documentaire principale et croisé sa documentation de référence, sa roadmap, ses décisions d’architecture, ses tâches et le code actuel avec l’état de l’écosystème WSL2 en août 2026.

Il y a un point important avant de commencer : **le dépôt contient déjà une première “refondation stratégique” datée du 26 août 2026**. Autrement dit, ta question actuelle n’arrive pas avant toute réflexion : elle arrive **après une première tentative de remise à plat**. Mon travail consiste donc à aller un cran plus loin et à challenger cette refondation elle-même. Le document `refondation-wisely.html` confirme d’ailleurs que les documents `VISION.md`, `ROADMAP.md` et les ADR récentes en sont les conséquences formelles. fileciteturn17file0L2-L2

Et ma conclusion principale est la suivante :

> **La refondation actuelle est nettement meilleure que l’ancien Wisely, mais je ne conserverais pas “l’écart entre consommation et autorisation” comme ontologie centrale de tout le produit.**
>
> Je garderais cette notion comme **modèle interne puissant pour les ressources configurables**, mais je ferais de la capacité produit supérieure quelque chose de légèrement différent :
>
> **Wisely doit rendre compréhensible la réalité des ressources WSL2 à la frontière Windows/Linux, expliquer pourquoi cette réalité existe, puis permettre une action sûre, justifiée et vérifiée.**

Autrement dit : **moins “profile switcher intelligent”, moins “monitoring”, et même un peu moins “gap engine” ; davantage “resource intelligence + safe control layer”.**

---

# 1. Ce que Wisely est réellement aujourd’hui

## 1.1 Le produit actuellement livré

Le README présente encore Wisely comme un **“WSL2 profile switcher”** : profils mémoire, monitoring RAM en arrière-plan, rapports hebdomadaires, menu interactif, backup, rollback, etc. fileciteturn14file0L2-L2

L’architecture est très lisible :

- `wisely.ps1` comme point d’entrée ;
- `ProfileManager.ps1` pour les profils et l’écriture de `.wslconfig` ;
- `Logger.ps1` pour l’historique ;
- `Monitor.ps1` et `MonitorTask.ps1` pour la surveillance ;
- `WeeklyReport.ps1` pour les rapports ;
- `profiles.json` comme source de configuration. fileciteturn14file0L2-L2

Les trois profils actuels sont :

- `web` → 4 Go / 3 CPU ;
- `data` → 6 Go / 5 CPU ;
- `base` → 2 Go / 2 CPU.

Ils sont stockés comme des valeurs absolues dans `profiles.json`. fileciteturn20file0L2-L2

### En termes fonctionnels, Wisely sait donc actuellement :

**Observer partiellement**

- RAM Windows ;
- processus `vmmem` ;
- profil actif ;
- historique des changements ;
- état du monitoring.

**Décider**

- choisir un profil.

**Agir**

- sauvegarder `.wslconfig` ;
- l'écrire ;
- redémarrer WSL2 ;
- rollback ;
- faire du dry-run.

**Mais il ne sait pas encore réellement :**

- attribuer la consommation à une distribution ;
- attribuer correctement la consommation à des processus Linux ;
- reconstruire l'historique réel de consommation ;
- dériver une recommandation fondée sur des mesures fiables ;
- expliquer causalement pourquoi WSL consomme X Go ;
- vérifier de façon complète que l'effet observé correspond à la promesse.

Le plus important : **la capacité “action” est plus mature que la capacité “compréhension”.**

C'est exactement ce que reconnaît la nouvelle vision du projet : le maillon actuel est essentiellement « agir », alors que la boucle complète devrait être observer → comprendre → décider → agir → vérifier. fileciteturn5file0L2-L2

---

# 2. Le paradoxe actuel : le code raconte encore l'ancien produit

C’est probablement l’une des choses les plus importantes que j’ai trouvées.

La documentation stratégique dit maintenant :

> Wisely relie ce que WSL2 consomme à ce qu'on l'autorise à consommer.

Mais le code réel est encore profondément construit autour de l'ancien paradigme.

Par exemple :

### `Get-VmmemStats`

Le code utilise toujours :

`Get-Process -Name "vmmem"`

et renvoie `null` en cas d'échec. fileciteturn19file0L2-L2

Cela confirme que le problème identifié dans la roadmap v2.5 n'est pas encore corrigé dans le code actuel : la surveillance repose encore sur un proxy Windows incomplet.

### `Get-ActiveProfile`

La reconnaissance du profil actif se fait encore essentiellement par **égalité sur la valeur mémoire**. Deux profils à 4 Go peuvent donc être confondus. fileciteturn21file0L2-L2

### `.wslconfig`

`ConvertTo-WslConfigContent` reconstruit le contenu à partir des champs connus de Wisely. C'est précisément le comportement que la nouvelle politique “ne jamais détruire ce qu'on ne gère pas” cherche à éliminer. fileciteturn21file0L2-L2

Donc :

> **La refondation stratégique est aujourd'hui plus avancée que l'implémentation.**

Ce n'est pas un problème en soi. Au contraire, c'est préférable à l'inverse.

Mais cela signifie que **la roadmap ne doit surtout pas être accélérée simplement parce qu'elle est bien écrite.**

---

# 3. Le problème fondamental est-il correctement formulé ?

Votre `PROBLEM.md` pose :

> **“La consommation de ressources de WSL2 est opaque, et son plafond est global.”** fileciteturn4file0L2-L2

Je pense que c'est **presque juste**, mais qu'il manque une distinction.

## 3.1 “Plafond global” est un vrai problème

Microsoft confirme que `.wslconfig` s'applique globalement à la VM WSL2, alors que `wsl.conf` est spécifique à une distribution. `memory`, `processors` et `swap` font partie des paramètres globaux de `.wslconfig`. citeturn775392search5turn775392search10

Donc votre observation :

> ressources ≠ workloads

est fondamentalement correcte.

C'est un axe stratégique très intéressant.

---

# 4. Mais “consommé vs autorisé” ne marche pas uniformément pour toutes les ressources

C'est là que je commencerais réellement à challenger `VISION.md`.

Votre modèle de l'écart est excellent pour :

- mémoire autorisée ;
- CPU exposé ;
- certains paramètres de swap ;
- politiques de ressources.

Mais il devient beaucoup moins naturel pour :

- disque ;
- I/O ;
- réseau ;
- GPU ;
- temps de démarrage ;
- comportement de cache ;
- pression mémoire ;
- anomalies.

Prenons la RAM.

WSL2 alloue dynamiquement des ressources, et Microsoft documente désormais `autoMemoryReclaim`. La documentation actuelle indique notamment les modes `disabled`, `gradual` et `dropCache`. citeturn775392search0

Docker recommande lui-même `autoMemoryReclaim` pour rendre de la mémoire à Windows après des opérations lourdes, précisément parce que le cache Linux peut retenir de la RAM. citeturn775392search1

Donc :

**8 Go consommés ≠ 8 Go réellement nécessaires.**

Et c'est une distinction capitale.

Une partie du problème n'est pas :

> “WSL prend plus que ce qu'on lui autorise.”

Elle est parfois :

> “WSL paraît prendre beaucoup, mais cette mémoire n'a pas la même signification selon qu'elle correspond à de l'anonyme, du cache, du swap, etc.”

Votre doctrine de lecture l'a déjà compris, puisqu'elle veut lire `/proc/meminfo`. fileciteturn10file0L2-L2

Par conséquent :

> **Le véritable objet de valeur n'est pas “l'écart”.**
>
> **C'est la compréhension correcte de l'état des ressources et de sa relation avec une politique.**

L'écart est alors **une vue dérivée**, pas nécessairement la racine de tout le produit.

---

# 5. La grande opportunité est ailleurs : la jointure

La meilleure idée actuellement présente dans Wisely est en réalité celle-ci :

> **Windows voit le conteneur. Linux voit le contenu. Wisely peut relier les deux.**

`PROBLEM.md` appelle cela “la jointure”. fileciteturn4file0L2-L2

Je conserverais cette idée à tout prix.

Mais je la formulerais autrement.

### Aujourd'hui

Windows :

> `VmmemWSL = 8,4 Go`

Linux :

> Python 2,1 Go  
> cache 3,2 Go  
> Node 1,4 Go  
> swap 0,7 Go

Le problème est que l'utilisateur doit mentalement faire le rapprochement.

### Wisely pourrait produire :

> **WSL2 utilise 8,4 Go sur l'hôte.**
>
> 5,1 Go sont associés à l'activité mémoire des distributions actuellement actives.
>
> 2,6 Go correspondent principalement au cache Linux.
>
> Python est actuellement le principal consommateur identifiable.
>
> Le plafond `.wslconfig` est de 10 Go.
>
> L'usage observé sur les 30 dernières minutes indique…
>
> **Recommandation : ne changez pas encore le plafond. Activez plutôt `autoMemoryReclaim`, puis observez.**

Là, on commence à avoir un produit.

---

# 6. C'est beaucoup plus intéressant qu'un dashboard

Le paysage actuel rend certaines conclusions assez nettes.

Microsoft propose désormais son propre WSL Settings, qui couvre graphiquement les réglages principaux de `.wslconfig`. La documentation Microsoft recommande même WSL Settings plutôt que l'édition manuelle. citeturn775392search5

Parallèlement, des outils tiers ont considérablement mûri.

`wsl2-distro-manager` propose une vraie gestion graphique des distributions, avec installation, sauvegarde, restauration, configuration et autres opérations ; le dépôt affiche aujourd'hui environ **4 000 étoiles et 178 forks**. citeturn775392search2

`wsl-dashboard` est également un gestionnaire WSL complet avec monitoring temps réel, gestion des distributions, réseau, USB, migration, etc., et affiche environ **3 300 étoiles et 166 forks**. citeturn771901search0

Même une extension VS Code “WSL Manager” couvre déjà mémoire, CPU, swap, networking, sparse VHD, `autoMemoryReclaim`, groupes et autres réglages. citeturn771901search4

Donc :

## Vision à abandonner

**“Construisons le meilleur dashboard WSL2.”**

Non.

La catégorie est déjà suffisamment occupée.

---

# 7. Le problème reste pourtant très réel

Il ne faut surtout pas tomber dans l'excès inverse et conclure :

> “Tout existe déjà.”

Ce serait faux.

Un cas récent particulièrement révélateur : un problème WSL publié le **8 juillet 2026** décrit `VmmemWSL` pouvant consommer toute la mémoire physique jusqu'à rendre le système non réactif. Le rapport indique même que `wsl --shutdown` peut rester bloqué. citeturn775392search7

Un autre problème ouvert le **7 août 2026** décrit une croissance de `vmmem` pouvant provoquer des erreurs mémoire côté GPU/NPU Windows. citeturn775392search4

Autrement dit :

> **Le problème “je ne comprends pas pourquoi WSL utilise autant de ressources et ce que cela provoque réellement sur Windows” est toujours vivant.**

Et il est même plus intéressant qu'avant.

---

# 8. Docker rend votre problème encore plus intéressant

Docker Desktop est probablement un test stratégique particulièrement révélateur.

Docker reconnaît lui-même que WSL2 utilise une VM Linux partagée entre distributions et que le Resource Saver ne peut pas simplement arrêter cette VM sous Windows. Docker recommande plutôt `autoMemoryReclaim` pour le problème mémoire. citeturn775392search6turn775392search1

Cela crée une zone où :

**Windows**

voit un `VmmemWSL`.

**Docker**

voit ses propres workloads.

**WSL**

voit plusieurs distributions.

**Linux**

voit les processus.

**L'utilisateur**

voit simplement :

> “Mon PC vient de manger 11 Go de RAM.”

Ça, c'est exactement le genre de situation où Wisely peut avoir une vraie légitimité.

Et cette légitimité est **transversale** :

- développeur ;
- Docker ;
- ML ;
- étudiant ;
- administrateur ;
- utilisateur multi-distributions.

Ce ne sont pas réellement six marchés.

C'est **un seul job** :

> **“Aidez-moi à comprendre et à reprendre le contrôle quand WSL utilise des ressources d'une manière que je ne comprends pas.”**

---

# 9. Je changerais votre segmentation

Le projet actuel raisonne encore partiellement en personas :

- web ;
- data/ML ;
- Docker ;
- étudiant ;
- DevOps ;
- multi-distro.

Je pense qu'il faut aller plus loin.

### Le métier n'est pas le bon axe.

Un ingénieur ML et un étudiant peuvent vivre exactement le même incident :

> WSL consomme toute la RAM disponible.

Un développeur web et un SRE peuvent avoir exactement le même incident :

> un service Linux reste actif toute la nuit.

Donc le segment primaire devrait être :

### **Utilisateur confronté à un problème de ressources WSL2 incompris**

Puis seulement ensuite :

- environnement Docker ;
- workload Linux ;
- multi-distro ;
- machine contrainte ;
- utilisateur avancé.

Cela permet d'élargir l'audience **sans fabriquer un produit générique**.

---

# 10. Ce que je conserverais de la vision actuelle

La refondation du 26 août contient plusieurs très bonnes décisions.

## À conserver absolument

### 1. La lecture Windows + Linux

C'est probablement votre avantage technique majeur. fileciteturn22file0L2-L2

### 2. Le contrat de confiance

La doctrine “lecture seule, sans agent, liste fermée de commandes, pas de secrets, pas de réseau” est excellente. fileciteturn10file0L2-L2

Ce n'est pas juste de la sécurité.

C'est une **feature produit**.

### 3. La non-destruction de `.wslconfig`

Le principe 8 est essentiel. fileciteturn7file0L2-L2

### 4. Backup / rollback / dry-run

C'est l'un des meilleurs actifs existants du projet. `ROADMAP.md` a raison de le considérer comme tel. fileciteturn8file0L2-L2

### 5. Mesures honnêtes

Le principe 9 est excellent :

> ne jamais afficher une métrique dont on ne connaît pas réellement la signification. fileciteturn7file0L2-L2

### 6. Recommandation portant sa preuve

Le principe 10 pourrait devenir **un pilier de marque** :

> “Wisely ne vous donne pas un chiffre magique ; il vous montre pourquoi il vous donne ce chiffre.” fileciteturn7file0L2-L2

---

# 11. Ce que je remettrais en question

## A. “Le profil” comme objet principal

Le profil est probablement encore trop central.

L'utilisateur ne se réveille pas le matin en se disant :

> “Aujourd'hui, j'aimerais charger le profil DATA.”

Il se dit plutôt :

> “Je dois entraîner ce modèle.”

> “Je lance Docker.”

> “J'ai besoin que mon PC reste réactif.”

> “Pourquoi WSL prend encore 9 Go ?”

Le profil est **une politique d'exécution**.

Il devrait donc devenir une mécanique interne ou secondaire.

---

# 12. La nouvelle abstraction que je recommande

Je structurerais Wisely autour de quatre objets conceptuels :

### 1. **State**

Quel est l'état réel de WSL ?

### 2. **Cause**

Pourquoi cet état existe-t-il ?

### 3. **Policy**

Qu'est-ce que la machine est censée permettre ?

### 4. **Action**

Que peut-on faire sans mettre l'environnement en danger ?

Cela donne :

> **Observe → Explain → Recommend → Act → Verify**

Cette boucle est légèrement différente de votre modèle actuel :

> Observer → Comprendre → Décider → Agir → Vérifier.

La différence paraît subtile.

Elle ne l'est pas.

**Explain** devient une capacité produit explicite.

Parce que c'est précisément là que se trouve la douleur.

---

# 13. Je remplacerais “gap” par un modèle de “resource state”

Je ne supprimerais surtout pas `gap`.

Je le repositionnerais.

Par exemple :

```text
Resource State
 ├── Host
 │    ├── RAM
 │    ├── CPU
 │    └── GPU
 │
 └── WSL
      ├── VM
      │    ├── allocated
      │    ├── active
      │    ├── cache
      │    └── swap
      │
      ├── Distros
      │    ├── Ubuntu
      │    └── docker-desktop
      │
      └── Processes
           ├── python
           ├── node
           └── dockerd
```

Puis :

```text
Policy
 ├── memory ceiling
 ├── processors
 ├── swap
 └── other managed settings
```

Et enfin :

```text
Assessment
 ├── healthy
 ├── constrained
 ├── unexplained
 ├── overprovisioned
 └── risky
```

Le “gap” devient alors une **relation entre State et Policy**, et non le produit entier.

C'est beaucoup plus extensible.

---

# 14. Attention à un piège technique majeur

Votre doctrine prévoit :

`ps -eo rss,comm --sort=-rss`

C'est une bonne première brique pour attribution. fileciteturn10file0L2-L2

Mais il faudra absolument éviter une erreur conceptuelle :

**la somme des RSS de tous les processus ne doit pas être présentée comme exactement égale à la RAM réellement consommée.**

Les pages partagées peuvent être comptabilisées plusieurs fois.

Donc Wisely devra distinguer :

- mesure directe ;
- mesure attribuée ;
- estimation ;
- corrélation.

C'est précisément le genre de nuance qui peut faire ou détruire la confiance.

Votre principe 9 doit évoluer vers quelque chose comme :

> **Every metric has a scope, source, freshness and confidence.**

Ce serait très puissant.

---

# 15. Même problème pour le CPU

`loadavg` n'est pas un “CPU percentage”.

`nproc` ne mesure pas l'utilisation CPU ; il indique seulement ce que l'invité voit.

Et le CPU de `VmmemWSL` côté Windows et le load côté Linux n'ont pas exactement la même sémantique.

Donc :

> **ne construisez surtout pas un “CPU gap” simpliste.**

Le modèle de ressources doit préciser les sémantiques de chaque métrique avant d'afficher quoi que ce soit.

C'est une raison forte pour créer un document `RESOURCE-MODEL.md`.

---

# 16. Le disque : très bonne intuition, mais pas “reclaim”

Votre décision 0010 est bonne. `Optimize-VHD` n'est plus une réponse universelle face à `sparseVhd`, et le projet a correctement décidé de détecter le régime puis de router vers la bonne méthode. fileciteturn25file0L2-L2

Mais je pousserais plus loin le raisonnement :

> **Le produit ne doit pas “nettoyer le disque”.**
>
> Il doit **expliquer l'écart entre stockage logique, occupation réelle, taille VHDX et espace effectivement récupérable.**

Encore une fois, comprendre avant d'agir.

---

# 17. Les visions stratégiques possibles

## Vision 1 — WSL Profile Switcher

**Valeur :** faible à moyenne  
**Différenciation :** faible  
**Complexité :** faible  
**Risque :** élevé de devenir une commodité

Pourquoi ?

Microsoft couvre déjà la configuration graphique et plusieurs outils tiers couvrent les profils/configurations. citeturn775392search5turn775392search2

### Verdict

**REMOVE comme vision stratégique.**

Le switch peut rester une capacité.

---

## Vision 2 — Dashboard WSL

**Valeur :** moyenne  
**Différenciation :** faible à moyenne  
**Complexité :** élevée

Marché déjà occupé par `wsl-dashboard`, `wsl2-distro-manager` et autres outils. citeturn771901search0turn775392search2

### Verdict

**REMOVE comme vision.**

Le dashboard peut exister comme interface, pas comme proposition de valeur.

---

## Vision 3 — Observability layer for WSL2

**Valeur :** élevée  
**Différenciation :** élevée  
**Complexité :** élevée

C'est techniquement très intéressant.

Mais “observability” seule devient vite une catégorie horizontale :

metrics + logs + history + dashboards + alerts…

et vous risquez de construire Grafana pour une VM WSL.

### Verdict

**KEEP comme capacité technique, pas comme positionnement final.**

---

## Vision 4 — WSL2 Resource Diagnostic

**Valeur :** très élevée  
**Différenciation :** élevée  
**Complexité :** moyenne

Question centrale :

> **Pourquoi WSL consomme-t-il autant et que puis-je faire ?**

C'est immédiatement compréhensible.

Et surtout, on peut créer un premier produit sans construire toute la plateforme.

### Verdict

**TRÈS FORTE.**

---

## Vision 5 — Resource Optimization Assistant

**Valeur :** très élevée  
**Différenciation :** très élevée  
**Complexité :** élevée

Wisely observe :

> “Vous consommez X, votre historique montre Y, `autoMemoryReclaim` est désactivé…”

Puis recommande :

> “Voici l'action la plus sûre.”

C'est beaucoup plus puissant.

### Verdict

**Vision cible long terme.**

---

## Vision 6 — WSL2 Resource Control Plane

C'est probablement la meilleure formulation stratégique long terme.

Pas un gestionnaire WSL générique.

Pas un dashboard.

Pas un simple tuner.

Mais :

> **une couche de contrôle des ressources WSL2 qui connaît à la fois l'état réel et la politique souhaitée.**

### Verdict

**Meilleure architecture stratégique.**

Mais il faut commencer beaucoup plus petit.

---

# 18. La vision que je recommande

Je proposerais :

## **Wisely — WSL2 Resource Intelligence & Control**

Et la promesse utilisateur :

> **Wisely explique où vont les ressources de WSL2, pourquoi elles sont utilisées et quelle action sûre permet de reprendre le contrôle.**

Cela donne trois niveaux :

### Aujourd'hui

**Control**

> “Je change les ressources.”

### Demain

**Intelligence**

> “Je comprends les ressources.”

### Long terme

**Closed-loop control**

> “Je comprends → recommande → agit → vérifie.”

C'est beaucoup plus robuste que :

> “Wisely relie ce que WSL2 consomme à ce qu'on l'autorise à consommer.”

Cette phrase reste excellente **comme modèle architectural**, mais elle est un peu trop étroite comme promesse produit universelle.

---

# 19. Le véritable cœur de Wisely

J'ai testé plusieurs formulations.

### A

> “Gérer les ressources WSL2.”

Trop générique.

### B

> “Monitorer WSL2.”

Trop faible.

### C

> “Optimiser WSL2.”

Trop vague.

### D

> “Relier consommation et autorisation.”

Excellente abstraction interne.

### E

> **“Transformer l'état de ressources WSL2 en décisions explicables et sûres.”**

C'est celle que je recommande.

Elle contient :

- observation ;
- interprétation ;
- recommandation ;
- action ;
- sécurité.

Et elle survit mieux à l'évolution du produit.

---

# 20. La feature phare devrait être `wisely diagnose`

Je changerais légèrement `wisely doctor`.

`doctor` sonne comme un outil générique de vérification.

`diagnose` annonce directement la valeur.

Exemple :

```text
wisely diagnose
```

et non :

```text
wisely -Status
```

La commande devrait répondre :

### “Que se passe-t-il ?”

### “Pourquoi ?”

### “Est-ce dangereux ?”

### “Que puis-je faire ?”

### “Est-ce que cela vaut réellement la peine de changer quelque chose ?”

C'est là que Wisely devient un produit.

---

# 21. Exemple de sortie cible

Quelque chose de ce genre :

```text
WISELY DIAGNOSE

SYSTEM
Windows RAM          12.6 / 16 GB
WSL memory            7.8 GB
WSL limit             8 GB
Pressure              HIGH

WHY
├─ Ubuntu
│  ├─ python3          2.4 GB
│  ├─ node              1.1 GB
│  └─ Linux cache       2.0 GB
│
└─ docker-desktop      1.6 GB

CONFIGURATION
autoMemoryReclaim     disabled
swap                  4 GB

ASSESSMENT
⚠ WSL is close to its configured ceiling.
⚠ Most non-process-attributed memory is Linux cache.
✓ No evidence that the ceiling should be increased.

RECOMMENDATION
Enable autoMemoryReclaim=gradual.

WHY
Your recent observations show recurring cache retention
without equivalent sustained process demand.

RISK
Low — configuration only.

ACTION
[ Preview ] [ Apply ] [ Ignore ]
```

Vous avez alors un produit qui fait quelque chose que “Task Manager + WSL Settings + htop” ne font pas bien **ensemble**.

---

# 22. C'est là que votre contrat de confiance devient un avantage compétitif

La doctrine actuelle est excellente. fileciteturn10file0L2-L2

Je la transformerais cependant en composant UX visible.

Chaque donnée pourrait afficher :

```text
SOURCE
Windows / VmmemWSL
Confidence: High
Freshness: 2s
```

ou :

```text
SOURCE
Ubuntu /proc/meminfo
Confidence: High
Scope: distro
```

ou :

```text
ATTRIBUTION
Estimated
Shared memory may cause double counting
```

Et chaque recommandation :

```text
RECOMMENDATION EVIDENCE

Observed peak:       5.7 GB
Configured ceiling:  8 GB
Samples:              3,482
Window:               14 days
Confidence:            Medium
```

Voilà une innovation beaucoup plus intéressante qu'une intelligence artificielle collée au produit avec du scotch.

---

# 23. Je changerais votre segmentation

Le projet actuel raisonne encore partiellement en personas :

- web ;
- data/ML ;
- Docker ;
- étudiant ;
- DevOps ;
- multi-distro.

Je pense qu'il faut aller plus loin.

### Le métier n'est pas le bon axe.

Un ingénieur ML et un étudiant peuvent vivre exactement le même incident :

> WSL consomme toute la RAM disponible.

Un développeur web et un SRE peuvent avoir exactement le même incident :

> un service Linux reste actif toute la nuit.

Donc le segment primaire devrait être :

### **Utilisateur confronté à un problème de ressources WSL2 incompris**

Puis seulement ensuite :

- environnement Docker ;
- workload Linux ;
- multi-distro ;
- machine contrainte ;
- utilisateur avancé.

Cela permet d'élargir l'audience **sans fabriquer un produit générique**.

---

# 24. Ce que je ferais de l'IA

Pas maintenant.

Surtout pas un :

> “Ask Wisely AI…”

au-dessus d'un mauvais moteur de métriques.

La première intelligence de Wisely doit être :

**déterministe + explicable + locale.**

Plus tard, un moteur linguistique pourra transformer :

> 5 métriques + 4 règles + historique

en :

> “Ton problème vient probablement de…”

Mais le raisonnement primaire doit rester reproductible.

---

# 25. La nouvelle abstraction produit

Je structurerais Wisely autour de quatre objets conceptuels :

### 1. **State**

Quel est l'état réel de WSL ?

### 2. **Cause**

Pourquoi cet état existe-t-il ?

### 3. **Policy**

Qu'est-ce que la machine est censée permettre ?

### 4. **Action**

Que peut-on faire sans mettre l'environnement en danger ?

Cela donne :

> **Observe → Explain → Recommend → Act → Verify**

Cette boucle est légèrement différente de votre modèle actuel :

> Observer → Comprendre → Décider → Agir → Vérifier.

La différence paraît subtile.

Elle ne l'est pas.

**Explain** devient une capacité produit explicite.

Parce que c'est précisément là que se trouve la douleur.

---

# 26. Les fonctionnalités qui pourraient disparaître complètement

Je serais assez agressif ici.

## Probablement supprimer

### `Snapshot`

Pourquoi ?

Il corrige un problème créé par le modèle de profils au lieu de répondre à un vrai job.

### Rapports hebdomadaires

Ils ressemblent à une fonctionnalité “produit” parce qu'ils génèrent un artefact.

Mais générer un fichier n'est pas une valeur.

### Profils métier

`WEB`, `DATA SCIENCE`, `BASE`.

Ces noms sont effectivement trop prescriptifs.

### Hooks

Votre décision 0012 est logique. fileciteturn27file0L2-L2

### auto-switch

À long terme, potentiellement utile.

Mais certainement pas cœur.

---

# 27. Ce que Wisely ne devrait jamais devenir

Je poserais explicitement ces interdictions dans la future vision.

Wisely ne doit pas devenir :

- un gestionnaire complet de distributions ;
- un terminal ;
- un Docker manager ;
- un outil d'administration Linux général ;
- un remplaçant de WSL Settings ;
- un observability platform généraliste ;
- un système d'agents permanents ;
- un “optimizer” qui applique aveuglément des tweaks ;
- une usine à profils ;
- une IA qui prétend comprendre ce que les métriques ne permettent pas de savoir.

Le problème historique de beaucoup d'outils système est :

> “Puisqu'on peut lire un truc, ajoutons-le.”

Votre principe de minimalisme doit protéger Wisely de cela. fileciteturn7file0L2-L2

---

# 28. Une innovation beaucoup plus forte que “AI-powered”

Je vois une piste extrêmement intéressante :

# **Resource Evidence Graph**

Chaque recommandation serait construite à partir d'un graphe :

```text
Host pressure
      ↓
VmmemWSL
      ↓
Distro
      ↓
Memory state
      ↓
Process
      ↓
Observed trend
      ↓
Configuration
      ↓
Recommended action
      ↓
Observed effect
```

Chaque relation aurait :

- source ;
- timestamp ;
- confiance ;
- portée ;
- transformation.

Wisely pourrait alors dire :

> “Cette recommandation est fondée sur 1 827 observations.”

Ce serait très différenciant.

Et surtout :

**auditable.**

---

# 29. Deuxième innovation : le “before / after contract”

Quand Wisely applique une action :

### Avant

```text
RAM WSL       7.4 GB
Host free     2.1 GB
Ceiling       8 GB
Pressure      HIGH
```

### Action

```text
Enable autoMemoryReclaim
```

### Après

```text
RAM WSL       4.9 GB
Host free     4.7 GB
Pressure      NORMAL
```

### Conclusion

```text
Action effective: YES
Expected benefit: CONFIRMED
Rollback needed: NO
```

C'est bien plus intéressant qu'un simple “Action executed successfully”.

---

# 30. Troisième innovation : configuration provenance

Votre principe 8 peut devenir encore plus fort.

Wisely pourrait afficher :

```text
.wslconfig

memory              8GB       Wisely
processors          8         Wisely
networkingMode      mirrored  External
dnsTunneling        true      External
autoMemoryReclaim   gradual   External
```

Pas :

> “Qui a écrit cette ligne ?”

si cette information n'est pas connue.

Mais :

> **“Wisely possède cette clé”**
>
> **“Cette clé existe mais n'est pas gérée par Wisely.”**

Cela règle un vrai problème de coexistence.

---

# 31. La confiance doit devenir un axe du produit

Votre doctrine actuelle est déjà excellente, mais elle peut devenir un véritable positionnement.

Le produit pourrait afficher :

### Local

> Nothing leaves your machine.

### Least privilege

> No sudo.

### No agent

> Nothing installed in your distro.

### Explicit scope

> These are the exact commands we may run.

### Explainable

> Every recommendation has evidence.

C'est une proposition particulièrement intéressante pour :

- développeurs prudents ;
- utilisateurs avancés ;
- environnements professionnels ;
- entreprises.

La doctrine actuelle contient déjà presque tout cela. fileciteturn10file0L2-L2

---

# 32. Une autre correction conceptuelle : “zéro configuration”

Votre principe 1 est excellent mais sa formulation actuelle va rencontrer une petite tension avec le consentement. fileciteturn7file0L2-L2

Je le reformulerais :

> **Zéro configuration technique obligatoire pour obtenir la première valeur.**

Parce que :

- consentement ;
- autorisation ;
- choix de profondeur du diagnostic

sont techniquement des préférences.

Ce n'est pas un problème.

Il faut simplement distinguer :

**configuration**

et

**consentement / contrôle utilisateur.**

---

# 33. Architecture technique cible

Je **ne réécrirais pas Wisely en Rust, Go ou C# maintenant.**

Le projet est PowerShell-first, Windows-first, et PowerShell 5.1 reste une contrainte de compatibilité explicitement choisie. fileciteturn31file0L2-L2

Ce n'est pas encore votre problème.

Je découperais plutôt le système logiquement :

```text
                 ┌──────────────────────┐
                 │      CLI / TUI       │
                 └──────────┬───────────┘
                            │
                 ┌──────────▼───────────┐
                 │    Orchestrator      │
                 └──────────┬───────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
   Host Collector      Distro Collector    Config Collector
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
                   Resource Model
                            │
                            ▼
                    Diagnosis Engine
                            │
                            ▼
                  Recommendation Engine
                            │
                            ▼
                    Action Executor
                            │
                            ▼
                  Verification Engine
                            │
                            ▼
                    Evidence Store
```

Pas besoin de microservices.

Pas besoin de Rust.

Pas besoin de serveur local.

Pas besoin d'agent.

Juste des responsabilités clairement séparées.

---

# 34. Le modèle de données mérite beaucoup plus d'attention

Une mesure devrait idéalement ressembler conceptuellement à :

```json
{
  "timestamp": "...",
  "scope": "distro",
  "entity": "Ubuntu",
  "metric": "memory.available",
  "value": 3120,
  "unit": "MB",
  "source": "/proc/meminfo",
  "confidence": "high",
  "freshnessMs": 340,
  "attribution": "direct"
}
```

Ce modèle sera bien plus important à long terme que le choix de l'UI.

Parce qu'il détermine si Wisely peut réellement construire un moteur de diagnostic fiable.

---

# 35. Le vrai produit pourrait être étonnamment petit

Et c'est important.

Vous pourriez avoir une V1 stratégique avec seulement :

```text
wisely diagnose
wisely explain
wisely recommend
wisely apply
wisely verify
```

Et derrière :

- 5–10 métriques ;
- 10–20 règles ;
- une politique `.wslconfig` ;
- quelques actions sûres.

Pas besoin de 50 écrans.

Pas besoin de dashboard permanent.

Pas besoin d'IA.

Pas besoin de marketplace.

Vous pourriez avoir **un produit plus petit et beaucoup plus fort.**

---

# 36. Documentation : votre projet en a déjà beaucoup

Et paradoxalement, je pense que votre risque documentaire est maintenant réel.

Vous avez :

- problème ;
- vision ;
- principes ;
- hypothèses ;
- doctrine ;
- roadmap ;
- tâches ;
- audit ;
- ADR ;
- glossaire ;
- document de refondation.

L'architecture documentaire est déjà très mature pour un projet qui, selon `ASSUMPTIONS.md`, a **zéro utilisateur réel, zéro télémétrie et zéro feedback utilisateur**. fileciteturn6file0L2-L2

Donc je ne créerais surtout pas quinze documents de plus.

---

# 37. Les documents que je recommande désormais

## 1. `PROBLEM.md`

**KEEP**

Très bon.

Il doit simplement être légèrement réorienté autour du problème utilisateur avant les ressources.

---

## 2. `VISION.md`

**CHANGE**

Il doit définir :

- capacité centrale ;
- frontière produit ;
- utilisateur/job ;
- ce que Wisely ne fait pas.

Et faire de `gap` un modèle important mais non exclusif.

---

## 3. `PRINCIPLES.md`

**KEEP + enrichir**

Ajouter :

- chaque métrique a un scope ;
- chaque métrique a une confiance ;
- aucune inférence non justifiée ;
- l'incertitude doit être visible.

---

## 4. `ASSUMPTIONS.md`

**KEEP**

Mais ajouter des hypothèses directement liées à :

- diagnostic vs switch ;
- valeur de l'attribution ;
- valeur de la recommandation ;
- acceptation de la lecture invitée.

---

## 5. `RESOURCE-MODEL.md`

### **NEW — très important**

Ce document doit expliquer :

- RAM host ;
- RAM WSL ;
- cache ;
- mémoire active ;
- swap ;
- CPU ;
- disque ;
- VHDX ;
- attribution ;
- limitations ;
- confiance ;
- unités ;
- sémantiques.

C'est probablement le document technique le plus important à créer.

---

## 6. `USE-CASES.md`

### **NEW**

Pas des personas marketing.

Des situations réelles :

- “WSL consomme trop de RAM.”
- “Docker a laissé la mémoire élevée.”
- “Mon laptop ralentit.”
- “Je ne sais pas quelle distro consomme.”
- “Je veux modifier `.wslconfig` sans casser Docker.”

---

## 7. `VALIDATION.md`

### **NEW — extrêmement important**

Il doit contenir :

- hypothèse ;
- expérience ;
- population ;
- métrique ;
- seuil de succès ;
- résultat ;
- décision.

Ce document doit empêcher le projet de remplacer les utilisateurs par les documents.

---

## 8. `ARCHITECTURE.md`

### **NEW**

Architecture cible logique.

Pas de diagramme de microservices Kafka-Vault-Redis pour admirer le soleil.

Juste les responsabilités.

---

## 9. `ROADMAP.md`

**CHANGE**

Elle doit devenir une suite de **capacités validables**, pas uniquement de versions.

---

# 38. Les documents que je ne créerais pas

Je ne vois pas aujourd'hui de raison forte d'ajouter séparément :

- `STRATEGY.md` ;
- `MARKET.md` ;
- `PRODUCT.md` ;
- `FEATURES.md` ;
- `COMPETITORS.md`.

Le risque serait de produire une bibliothèque de documents qui racontent le produit au lieu de construire le produit.

Votre refondation documentaire avait justement pour objectif d'éviter cela. fileciteturn8file0L2-L2

---

# 39. Impact × Incertitude : le nouveau classement

Je le ferais ainsi.

| Hypothèse | Impact | Incertitude | Priorité |
|---|---:|---:|---|
| Il existe une douleur suffisamment forte pour utiliser Wisely | 5 | 5 | **P0** |
| Le diagnostic est plus utile que le switch | 5 | 5 | **P0** |
| L'attribution Windows → distro → processus apporte une vraie valeur | 5 | 4 | **P0** |
| Les utilisateurs acceptent la lecture invitée | 5 | 4 | **P0** |
| Les recommandations basées sur historique sont utiles | 4 | 4 | **P1** |
| Les utilisateurs veulent des profils persistants | 3 | 4 | P2 |
| L'auto-switch vaut son risque | 4 | 5 | P3 |
| GPU/power est un axe important | 3 | 5 | P3 |
| Les rapports hebdomadaires ont une valeur | 2 | 5 | **REMOVE jusqu'à preuve contraire** |

---

# 40. Les expériences que je lancerais immédiatement

Contrairement à la roadmap actuelle, je mettrais l'expérimentation utilisateur au centre.

### Expérience A — Diagnostic manuel

Une version minimaliste de `wisely diagnose`.

Objectif :

> quelqu'un comprend-il réellement son problème plus rapidement ?

---

### Expérience B — Attribution

Comparer :

**Task Manager seul**

vs

**htop seul**

vs

**Wisely**

Mesure :

> **temps pour identifier la cause probable.**

C'est une métrique produit extrêmement forte.

---

### Expérience C — Recommandation

Donner :

> “Votre consommation est de 7,3 Go.”

puis :

> “Votre consommation est de 7,3 Go, dont 3,2 Go de cache, avec un pic de 5,9 Go sur 14 jours ; voici pourquoi nous recommandons de ne pas augmenter le plafond.”

Mesurer laquelle des deux sorties inspire davantage confiance.

---

### Expérience D — Action

Comparer :

> “Voulez-vous appliquer cette modification ?”

avec :

> “Cette modification interrompra Ubuntu, Docker et les processus suivants…”

Votre propre principe 11 va déjà dans cette direction. fileciteturn7file0L2-L2

---

# 41. Mon avis sur A5

La décision 0011 a raison d'attendre avant l'auto-switch. fileciteturn26file0L2-L2

Mais je pense que **A5 est en réalité une hypothèse encore plus structurante que le dépôt ne le dit**.

Car si les utilisateurs changent de profil :

> trois fois par an

alors un moteur de switch sophistiqué est secondaire.

Si les utilisateurs rencontrent :

> quinze incidents de ressources par mois

alors le diagnostic devient central.

Donc la vraie question n'est pas :

> “À quelle fréquence changent-ils de profil ?”

mais :

> **“À quelle fréquence rencontrent-ils un problème de ressources WSL qu'ils ne savent pas expliquer ou résoudre facilement ?”**

C'est une meilleure métrique du marché.

---

# 42. Ce que je pense de la décision 0005

La décision de la boucle fermée est très bonne.

Mais je la modifierais légèrement.

Votre texte dit :

> Wisely est la boucle de rétroaction que WSL2 n'a pas. fileciteturn15file0L2-L2

Je préférerais :

> **Wisely est la couche qui transforme l'état réel des ressources WSL2 en décisions explicables et en actions sûres.**

Puis :

```text
Observe
   ↓
Explain
   ↓
Decide
   ↓
Act
   ↓
Verify
```

Et votre “gap” devient :

```text
Observed State ↔ Resource Policy
```

C'est plus large sans devenir générique.

---

# 43. Le nouveau positionnement que je recommande

### Nom

**Wisely**

### Catégorie

**WSL2 Resource Intelligence & Control**

### Problème

> WSL2 expose mal la relation entre consommation réelle, workloads Linux et configuration de ressources ; l'utilisateur doit aujourd'hui assembler lui-même plusieurs outils pour comprendre ce qui se passe.

### Promesse

> **Understand WSL. Act safely.**

En français :

> **Comprendre WSL. Agir en confiance.**

### Proposition de valeur

> **Wisely explique où vont les ressources de WSL2, identifie les causes probables et propose des actions sûres, fondées sur des mesures réelles.**

---

# 44. Réponse directe aux 12 questions finales

## 1. Que devrait réellement être Wisely ?

**Une couche de compréhension et de contrôle des ressources WSL2**, centrée sur le diagnostic, l'explication et l'action sûre.

Pas un simple switcher.

Pas un dashboard.

Pas un gestionnaire WSL généraliste.

---

## 2. Quel problème fondamental ?

> **L'utilisateur ne peut pas facilement relier la pression de ressources observée sur Windows à ce qui se passe réellement dans WSL2, ni savoir quelle action serait sûre et pertinente.**

---

## 3. Pour qui ?

Pas “les développeurs”.

Pour :

> **les utilisateurs de WSL2 confrontés à une consommation de ressources surprenante, excessive ou difficile à interpréter.**

Cela inclut naturellement :

- Docker ;
- dev ;
- data/ML ;
- étudiants ;
- utilisateurs Linux avancés ;
- multi-distro ;
- entreprise.

---

## 4. Proposition de valeur centrale

> **Comprendre rapidement ce que WSL consomme, pourquoi, et quoi faire ensuite.**

---

## 5. Capacité cœur

> **Transformer l'état brut des ressources WSL2 en information explicable et actionnable.**

---

## 6. Vision actuelle à abandonner

À abandonner :

> **“profile switcher” comme identité produit.**

À remettre en question :

> **“gap” comme modèle universel de tout le produit.**

À conserver :

> **gap comme relation clé entre état observé et politique de ressources.**

---

## 7. À conserver absolument

- lecture cross-boundary Windows/Linux ;
- contrat de lecture invitée ;
- instrumentation fiable ;
- attribution ;
- backup ;
- rollback ;
- dry-run ;
- validation ;
- sécurité ;
- scriptabilité ;
- principe de preuve des recommandations. fileciteturn7file0L2-L2

---

## 8. À supprimer / arrêter

Je mettrais sur voie de sortie :

- profils métier `web/data/base` ;
- `Snapshot` ;
- rapports hebdomadaires sans preuve de valeur ;
- hooks ;
- sophistication UI prématurée ;
- logique de “switcher” comme cœur marketing.

---

## 9. Nouvelles opportunités

Priorité :

1. diagnostic cross-boundary ;
2. attribution distro/processus ;
3. explication de `VmmemWSL` ;
4. recommandations basées sur preuves ;
5. configuration provenance / drift ;
6. before-after verification ;
7. diagnostic disque intelligent ;
8. historique causal plutôt que simple historique ;
9. éventuellement automatisation à long terme.

---

## 10. Nouvelle roadmap

```text
P0  Truth & Safety
    ↓
P1  Diagnose
    ↓
P2  Validate with users
    ↓
P3  Attribution + History
    ↓
P4  Evidence-based Recommendation
    ↓
P5  Safe Action + Verification
    ↓
P6  Derived Policies
    ↓
P7  Automation
    ↓
P8  Distribution
```

C'est cette roadmap que je recommande.

---

## 11. Documents

### Conserver

- `PROBLEM.md`
- `VISION.md`
- `PRINCIPLES.md`
- `ASSUMPTIONS.md`
- `ROADMAP.md`
- `decisions/`
- `DOCTRINE-LECTURE.md`

### Ajouter

- `RESOURCE-MODEL.md`
- `USE-CASES.md`
- `VALIDATION.md`
- `ARCHITECTURE.md`

### Modifier fortement

- `README.md`
- `VISION.md`
- `ROADMAP.md`
- `TASKS.md`

Le README en particulier doit être réaligné avec la vision actuelle : il continue aujourd'hui à vendre essentiellement le “profile switcher”, alors que les documents stratégiques ont largement dépassé cette proposition. fileciteturn14file0L2-L2

---

## 12. Les 5 hypothèses à valider avant d'investir massivement

### H1 — Il existe une douleur suffisamment forte

**Impact 5 / Incertitude 5**

Quelqu'un doit vouloir utiliser Wisely, pas simplement trouver l'idée intéressante.

---

### H2 — Le diagnostic a davantage de valeur que le switch

**Impact 5 / Incertitude 5**

C'est potentiellement le pivot stratégique le plus important.

---

### H3 — L'attribution Windows → distro → processus change réellement la décision de l'utilisateur

**Impact 5 / Incertitude 4**

Sinon la fameuse “jointure” est techniquement jolie mais commercialement faible.

---

### H4 — Les utilisateurs acceptent la lecture invitée

**Impact 5 / Incertitude 4**

La doctrine actuelle rend cette hypothèse testable proprement. fileciteturn10file0L2-L2

---

### H5 — Les recommandations basées sur les preuves sont suffisamment utiles pour justifier une action

**Impact 5 / Incertitude 4**

C'est ce qui permettra de transformer un outil de diagnostic en produit différenciant.

---

# Conclusion

Je vais être volontairement direct :

**Wisely n'a probablement pas besoin de devenir plus gros. Il a besoin de devenir plus juste.**

Le projet a déjà fait quelque chose de très difficile : il a reconnu que le produit historique — “je change facilement mon `.wslconfig`” — était en train de perdre sa justification face à WSL Settings et à l'écosystème. Microsoft couvre déjà une partie importante de la configuration, tandis que plusieurs gestionnaires WSL sérieux couvrent le management général. citeturn775392search5turn775392search2turn771901search0

La bonne nouvelle, c'est que cela laisse justement une place plus intéressante.

### Je positionnerais Wisely ainsi :

> **Wisely est la couche de resource intelligence de WSL2 : il relie l'état réel observé sur Windows et Linux à la configuration de la machine, explique ce qui se passe, recommande une action justifiée et vérifie son résultat.**

Le **switch** reste.

Le **monitoring** reste.

L'**historique** reste.

La **lecture in-distro** reste.

Le **gap** reste.

Mais ils cessent d'être le produit.

Ils deviennent les briques d'un produit plus profond :

> **“Pourquoi WSL fait-il cela, est-ce un problème, et que dois-je faire maintenant ?”**

À mon sens, c'est là que se trouve la véritable opportunité de Wisely.

Et surtout, je ne développerais **pas encore toute cette architecture**.

Le prochain investissement rationnel n'est pas v3.0 → v3.3.

C'est :

> **un petit `wisely diagnose`, extrêmement fiable, puis une vraie confrontation à des utilisateurs externes.**

Parce qu'à cet instant, le principal risque de Wisely n'est plus technique.

**C'est le risque de construire avec beaucoup d'intelligence un produit dont nous n'avons pas encore démontré que quelqu'un a besoin.**

Le registre `ASSUMPTIONS.md` l'admet déjà ; la prochaine étape consiste maintenant à transformer cette honnêteté documentaire en **preuves utilisateur**. fileciteturn6file0L2-L2
