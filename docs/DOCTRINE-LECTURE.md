# Doctrine de lecture — ce que Wisely lit dans votre Linux

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> qu'est-ce que Wisely lit à l'intérieur d'une distribution WSL2, et que ne
> lira-t-il jamais ?
>
> **Ce document est écrit avant l'implémentation, volontairement.** La capacité
> qu'il décrit est planifiée pour la v2.6 et n'existe pas encore dans le code. La
> raison de cet ordre est au cœur du sujet : un outil Windows qui entre dans le
> Linux de quelqu'un doit dire d'avance ce qu'il n'y fera jamais. Écrire le
> contrat après coup, c'est décrire ce qu'on a fait plutôt que s'engager sur ce
> qu'on fera.
>
> Statut : contrat. Toute modification élargissant la portée exige une entrée
> dans `decisions/` et une mention au CHANGELOG.
> Dernière révision : 2026-08-26.

---

## 1. Pourquoi Wisely a besoin de regarder à l'intérieur

Depuis Windows, WSL2 est une boîte opaque : un seul processus (`VmmemWSL`)
agrégeant le noyau Linux, le page cache et tous les processus invités. Aucune
mesure prise depuis l'extérieur ne peut répondre à « quelle distribution
consomme ça ? », ni distinguer « WSL2 a *besoin* de 5 Go » de « WSL2 a *pris*
5 Go et en garde 3 en cache ».

Or c'est exactement ce que Wisely doit savoir pour tenir sa promesse (voir
`VISION.md`). Sans cette information, l'outil ne peut ni diagnostiquer, ni
recommander un plafond, ni vérifier qu'un changement a produit l'effet annoncé.

**Ce n'est pas un problème technique.** `wsl -d <distro> -- cat /proc/meminfo`
s'exécute depuis PowerShell, sans rien installer, en une ligne. La difficulté est
entièrement une question de confiance, et c'est pour cela qu'elle mérite un
document et une version à elle seule.

---

## 2. Les cinq engagements

### 2.1 Lecture seule, sans exception

Wisely **n'écrit rien** à l'intérieur d'une distribution. Ni fichier, ni
configuration, ni paquet, ni service, ni tâche planifiée, ni entrée de
`crontab`.

La seule surface d'écriture de Wisely reste `%USERPROFILE%\.wslconfig` côté
Windows, plus ses propres fichiers dans son répertoire d'installation.

Une opération de maintenance qui exigerait une écriture invitée — `fstrim` pour
la récupération d'espace disque, par exemple — n'est **jamais** exécutée
automatiquement. Wisely affiche la commande, explique ce qu'elle fait, et
l'utilisateur la lance lui-même. Cette règle n'a pas d'exception « pratique ».

### 2.2 Aucun agent, aucune installation

Wisely n'installe rien dans la distribution : ni binaire, ni script, ni service,
ni démon, ni dépendance. Aucun paquet n'est ajouté, aucun gestionnaire de paquets
n'est invoqué.

Toute lecture passe par une invocation ponctuelle `wsl -d <distro> -- <commande>`
qui se termine immédiatement. Il ne reste rien après.

Conséquence assumée : Wisely n'utilise que des commandes présentes sur une
distribution nue. Si une mesure exige `psutil` ou un outil non standard, la
mesure est abandonnée, pas la règle.

### 2.3 Liste fermée de commandes

Wisely n'exécute **que** les commandes de la liste ci-dessous. Elle est
exhaustive, versionnée dans ce document, et toute addition exige une entrée dans
`decisions/` et une mention au CHANGELOG.

| Commande | Ce qu'elle donne | Pourquoi Wisely en a besoin |
|---|---|---|
| `cat /proc/meminfo` | Mémoire totale, libre, disponible, cache, swap de l'invité | Distinguer la mémoire réellement utilisée de la mémoire en cache — le cœur de la mesure de l'écart |
| `cat /proc/loadavg` | Charge moyenne 1/5/15 min | Contexte de charge CPU côté invité |
| `cat /proc/uptime` | Temps depuis le démarrage de l'invité | Savoir si une mesure est représentative ou prise juste après un démarrage |
| `df -P /` | Occupation du système de fichiers racine | Relier la taille du VHDX à l'occupation réelle vue de l'intérieur |
| `nproc` | Nombre de processeurs vus par l'invité | Vérifier que le plafond CPU est bien appliqué |
| `ps -eo rss,comm --sort=-rss` | Processus par empreinte mémoire, **nom de commande seul** | Attribuer la consommation — répondre à « qu'est-ce qui prend ces gigaoctets ? » |

Les commandes de découverte côté Windows — `wsl --list --verbose`,
`wsl --list --running --quiet`, `wsl --version` — ne sont pas des lectures
invitées et ne relèvent pas de ce contrat, mais sont listées ici pour que le
tableau des accès soit complet.

### 2.4 Ce que Wisely ne lira jamais

Cette liste est aussi contraignante que la précédente. Elle n'est pas indicative.

- **Aucun contenu de fichier utilisateur.** Ni code source, ni documents, ni
  fichiers de configuration applicatifs, ni historique de shell, ni
  `~/.ssh`, ni `~/.aws`, ni `.env`, ni trousseau. Les seuls fichiers lus sont
  ceux de `/proc` et le résultat de `df`, listés en 2.3.
- **Aucune variable d'environnement.** Elles contiennent régulièrement des jetons
  et des chaînes de connexion.
- **Aucun argument de ligne de commande des processus.** C'est la raison précise
  du choix de `comm` (nom de la commande) plutôt que `args` dans `ps` : les
  arguments contiennent fréquemment des mots de passe, des jetons d'API et des
  chemins privés. Wisely voit qu'un processus s'appelle `python3` et combien il
  consomme ; il ne voit pas ce qu'il exécute.
- **Aucun nom d'utilisateur, chemin personnel ou nom de machine invité.**
- **Aucun trafic réseau, aucune connexion ouverte, aucun port.**
- **Aucune sortie de commande n'est envoyée où que ce soit.** Wisely n'a aucune
  télémétrie, aucun appel réseau sortant, aucun rapport d'erreur distant. Toute
  donnée lue reste sur la machine.

### 2.5 Consentement explicite et révocable

La lecture invitée est **désactivée par défaut**. Elle s'active par un geste
délibéré de l'utilisateur, jamais par une mise à jour, jamais implicitement à la
première utilisation d'une fonctionnalité qui en aurait besoin.

À la première demande, Wisely affiche un résumé de ce document — les commandes
exactes, et ce qui ne sera jamais lu — et demande une confirmation. Le choix est
enregistré dans les réglages et peut être révoqué à tout moment, sans
désinstallation et sans perte des autres fonctionnalités.

**Dégradation propre en cas de refus.** Sans lecture invitée, Wisely continue de
fonctionner : le switch de profil, la sécurité, l'historique et les mesures
côté Windows restent identiques. Les fonctions qui exigent la vue invitée
disent explicitement *pourquoi* elles sont indisponibles et *comment* les
activer — elles ne sont ni masquées, ni dégradées en silence, ni remplacées par
une estimation présentée comme une mesure (principe 9, `PRINCIPLES.md`).

---

## 3. Les garanties d'exécution

Au-delà de ce qui est lu, la façon dont c'est lu engage aussi.

- **Aucune élévation de privilèges.** Les lectures s'exécutent avec l'utilisateur
  par défaut de la distribution. Wisely n'invoque jamais `sudo`, et une commande
  qui l'exigerait est retirée de la liste plutôt qu'élevée.
- **Aucun démarrage à l'insu de l'utilisateur.** Wisely ne lit que dans les
  distributions **déjà en cours d'exécution** (`wsl --list --running`). Démarrer
  une distribution arrêtée pour la mesurer consommerait précisément les
  ressources que l'outil prétend économiser, et modifierait l'état qu'il observe.
- **Délai maximal et échec explicite.** Chaque invocation a un délai d'expiration
  court. Un dépassement ou une erreur est signalé, jamais avalé — une mesure
  absente est dite absente.
- **Aucune interpolation.** Le nom de distribution provient de l'énumération WSL,
  jamais d'une saisie libre concaténée dans une commande. Les commandes de la
  liste 2.3 sont des constantes, pas des chaînes construites.
- **Fréquence bornée.** Les lectures ont lieu sur demande explicite ou à
  l'intervalle d'échantillonnage configuré. Wisely ne sonde pas en continu.

---

## 4. Comment vérifier que ce contrat est tenu

Un contrat non vérifiable n'est qu'une déclaration d'intention.

- La liste de commandes du §2.3 est **la** source de vérité, et une constante
  unique dans le code. Toute commande invitée passe par elle.
- Un test Pester vérifie qu'aucune invocation invitée n'existe hors de cette
  liste. Ajouter une commande sans mettre à jour ce document fait échouer la CI.
- Le code est public sous GPL v3 : n'importe qui peut vérifier ces affirmations
  plutôt que les croire.
- La commande de diagnostic affiche l'état du consentement et la liste exacte de
  ce qui serait lu.

---

## 5. Pourquoi c'est un différenciateur, et pas seulement une précaution

Les outils qui touchent à la configuration système demandent en général une
confiance aveugle : ils décrivent ce qu'ils font, rarement ce qu'ils ne font pas.

Un contrat explicite, borné et vérifiable est ce qui rend acceptable, pour un
utilisateur en entreprise ou simplement prudent, qu'un outil Windows regarde à
l'intérieur de son environnement Linux. C'est la condition pour que la capacité
existe — et la raison pour laquelle ce document précède le code plutôt que de le
suivre.

---

## Documents liés

- `PRINCIPLES.md` — principe 12 : la confiance se déclare avant de s'exercer
- `VISION.md` — pourquoi la vue invitée est nécessaire à la capacité fondamentale
- `decisions/0008-lecture-in-distro.md` — la décision et ses alternatives écartées
- `ROADMAP.md` — v2.6, le cycle qui livre ce contrat et son implémentation
