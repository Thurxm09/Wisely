# Recrutement — où trouver des testeurs, et comment mesurer

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> où trouve-t-on des gens susceptibles d'essayer Wisely, à quelles conditions les
> aborder, et comment mesure-t-on ce qui se passe ensuite ?
>
> Ce document ne contient **ni hypothèses** (`ASSUMPTIONS.md`), **ni priorités**
> (`ROADMAP.md`), **ni protocoles de session pour les hypothèses du site**
> (dossier de validation du dépôt `wisely-site`) — les protocoles propres aux
> expériences CLI, comme E4 et E5, vivent dans `docs/validation/protocoles/` de
> ce dépôt —, **ni critères de périmètre produit** (`VISION.md`). Il les cite,
> il ne les redit pas.
>
> Il existe parce que `ASSUMPTIONS.md` sait dire *quoi* mesurer et *à quel seuil*,
> mais rien dans le dépôt ne disait *auprès de qui*, ni *comment obtenir un
> dénominateur*. L'expérience E3a a échoué sur exactement ce manque.
>
> Statut : vivant. Première rédaction : 2026-09-03.

---

## Le constat qui a produit ce document

E3a a été publiée le 2026-09-01 sur X et Bluesky. Deux jours plus tard : **1
étoile, 0 fork, 0 issue, 6 vues cumulées (X : 6, Bluesky : 0).**

La tentation était de lire ce zéro comme un signal contre A1 — « personne n'a ce
problème ». C'est faux, et c'est le genre d'erreur qui coûte un projet. Un zéro
sur un dénominateur inconnu ne dit rien. Il dit « personne n'a vu ».

**Deux règles en découlent, et elles gouvernent tout ce document :**

> **1. On ne publie pas sans savoir combien de personnes ont vu.**
> Sans dénominateur, l'expérience n'est pas une expérience.
>
> **2. On ne dépense pas un canal deux fois.**
> Un canal se brûle en une publication maladroite. La liste ci-dessous est
> courte, et c'est délibéré.

---

## 1. Trois personas, priorisés

Pas « tous les développeurs ». La question n'est pas qui *pourrait* utiliser
Wisely, mais qui a **aujourd'hui, activement, un problème** que l'outil adresse.

Ces personas sont des **profils de recrutement**, pas des personas produit — le
produit raisonne en situations (`USE-CASES.md`), et cette distinction est
volontaire : elle empêche ce document de redevenir un document de positionnement.

### P1 — Le développeur Docker/WSL2 étranglé · **priorité maximale**

| | |
|---|---|
| **Profil** | 16 Go de RAM, Docker Desktop sur backend WSL2, un ou deux projets lourds. Windows par contrainte, Linux par nécessité. |
| **Niveau technique** | Élevé sur son domaine, moyen sur WSL2 — il sait que `VmmemWSL` mange sa RAM, pas pourquoi. |
| **Douleur** | **Aiguë et active.** Sa machine rame maintenant. Il a déjà cherché, trouvé des articles contradictoires, essayé un `.wslconfig` copié-collé. |
| **Motivation à tester** | Immédiate et égoïste : il veut récupérer sa RAM. C'est la meilleure motivation qui existe — elle ne demande aucune bienveillance. |
| **Problèmes qu'il rencontrera** | Peut ne pas avoir PowerShell 7. Peut être rebuté par `git clone` pour « juste voir ». Risque de lire le reste non attribué négatif comme un bug. |
| **Où le trouver** | `microsoft/WSL#4166`, r/bashonubuntuonwindows, r/docker, Discords Docker et DevOps. |
| **Message qui l'intéresse** | « Voilà pourquoi les chiffres que tu compares ne mesurent pas la même chose. » Jamais « j'ai fait un outil ». |
| **Feedback attendu** | Le plus riche du lot : il **compare** Wisely à ce qu'il a déjà essayé. Teste A1, A9, A10. |

### P3 — Le data scientist sous WSL · **seconde priorité**

| | |
|---|---|
| **Profil** | Notebooks, pandas, parfois un modèle local. WSL2 parce que l'outillage Python y est meilleur. |
| **Niveau technique** | Fort en Python, **faible en PowerShell et en administration Windows**. |
| **Douleur** | Aiguë mais **mal formulée** : « mon kernel meurt », pas « mon plafond WSL2 est mal réglé ». Il ne sait pas que le problème a un nom. |
| **Motivation à tester** | Plus faible : il n'a pas identifié WSL2 comme la cause. Il faut lui montrer le lien avant de lui proposer l'outil. |
| **Problèmes qu'il rencontrera** | Tous ceux de P1, plus la barrière PowerShell. **C'est le profil qui abandonne**, et c'est exactement pour cela qu'il est précieux. |
| **Où le trouver** | Discords data FR et EN, communautés Python, forums Jupyter. |
| **Message qui l'intéresse** | « Ton kernel meurt-il sans raison apparente ? Il y a peut-être un plafond que tu ne connais pas. » |
| **Feedback attendu** | **Le plus précieux sur la compréhension.** C'est lui qui révèle ce que la sortie n'explique pas. Teste A9, A11, A12. |

### P2 — Le powershelliste outillé · **troisième priorité**

| | |
|---|---|
| **Profil** | Écrit des modules PowerShell, a un avis sur les verbes approuvés, lit le code avant de l'exécuter. |
| **Niveau technique** | Très élevé — souvent supérieur à celui du mainteneur sur PowerShell. |
| **Douleur** | **Faible sur les ressources, forte sur la qualité.** Il ne cherche pas à récupérer de la RAM ; il veut voir si le code tient. |
| **Motivation à tester** | La curiosité technique et le plaisir de trouver un défaut. Motivation réelle, mais qui ne teste pas la valeur produit. |
| **Problèmes qu'il rencontrera** | Aucun d'installation. Il trouvera en revanche les cas limites, et il aura raison. |
| **Où le trouver** | r/PowerShell, Discord PowerShell, communautés d'administration Windows. |
| **Message qui l'intéresse** | « Lecture seule, liste fermée de commandes invitées, consentement révocable. Dis-moi où ça casse. » |
| **Feedback attendu** | Sécurité, robustesse, cas limites, qualité de l'écriture `.wslconfig`. Teste A4. Excellent feedback technique, **faible pouvoir de réfutation produit**. |

> **Pourquoi P2 arrive en dernier alors qu'il donne le meilleur feedback.** Parce
> que le risque du projet n'est plus technique. `AUDIT.md` recense deux campagnes
> closes, la CI porte cinq contrôles, la suite Pester couvre six modules. Ce qui
> n'est pas su, c'est si quelqu'un en a besoin — et P2 ne répond pas à cette
> question. Le recruter en premier reviendrait à chercher ses clés sous le
> lampadaire.

---

## 2. Cartographie des canaux

Chaque canal est jugé sur ce qu'il apporte **à l'expérience E3b**, pas sur sa
popularité.

### Priorité 1

#### `microsoft/WSL#4166` — « WSL 2 consumes massive amounts of RAM and doesn't return it »

| | |
|---|---|
| **Pourquoi** | Ouverte depuis 2019, jamais close, alimentée en continu. **Le seul endroit connu où le persona P1 se trouve à l'état pur, en douleur active.** Personne n'y arrive par hasard. |
| **Qui on y trouve** | P1 massivement, un peu de P2. |
| **Difficulté d'entrée** | Nulle techniquement. **Maximale culturellement.** |
| **Règles** | Aucune règle écrite, mais une norme forte : un fil de sept ans a déjà vu passer des dizaines d'autopromotions et les traite en conséquence. |
| **Approche** | **Répondre réellement, d'abord.** Le commentaire doit être utile même si on retire la dernière ligne. Voir le message en §4. |
| **Contenu** | L'explication cache vs somme des RSS, `MemAvailable` ≠ `MemTotal - used`, `autoMemoryReclaim` éteint par défaut. L'outil en dernière phrase. |
| **Fréquence** | **Un commentaire. Une seule fois. Jamais de relance.** |
| **Appel à l'action** | Un lien, aucune injonction. « si c'est utile ». |
| **Risque spam** | **Élevé** si mal exécuté, nul si le commentaire apporte de la valeur. C'est le canal où l'écart entre les deux est le plus grand. |
| **Effort** | 1 h de rédaction, parce que chaque affirmation technique doit être exacte. |
| **Potentiel qualitatif** | **Le plus élevé de la liste.** |
| **Potentiel quantitatif** | Élevé et durable : le fil est indexé et lu en continu. |

> À traiter de la même manière, et **seulement si le disque est concerné** :
> `microsoft/WSL#4699` (récupération d'espace disque). Ne pas y aller avant P8 —
> Wisely explique l'écart disque mais ne le corrige pas, et le dire vaut mieux
> que de le laisser espérer.

#### r/bashonubuntuonwindows

| | |
|---|---|
| **Pourquoi** | Le subreddit WSL de fait. r/WSL2 a été vérifié restreint le 2026-08-31 : publication réservée aux membres approuvés. |
| **Qui on y trouve** | P1 et P3. |
| **Difficulté d'entrée** | Moyenne. **Vérifier les règles de self-promotion avant de publier** — elles changent, et le constat de 2026-08-31 ne vaut que pour r/WSL2. |
| **Approche** | Post de partage d'expérience, pas d'annonce produit. Le titre porte l'enseignement, pas le nom de l'outil. |
| **Contenu** | « Ce que j'ai appris en essayant de mesurer la mémoire WSL2 », l'outil en fin de post. |
| **Fréquence** | Une publication. Rien avant 14 jours si elle échoue. |
| **Risque spam** | Moyen — atténué en répondant à d'autres fils avant de publier le sien. |
| **Effort** | 1 h 30. |
| **Potentiel qualitatif** | Élevé. **Potentiel quantitatif** : moyen. |

#### r/PowerShell

| | |
|---|---|
| **Pourquoi** | Public et sans restriction connue (vérifié le 2026-08-31). Le seul canal où P2 se trouve en nombre. |
| **Approche** | **Angle code, jamais angle produit.** « Voilà comment j'ai résolu l'écriture non destructive d'un fichier INI partagé » intéresse ce public ; « j'ai fait un outil WSL2 » ne l'intéresse pas. |
| **Appel à l'action** | Une revue de code, pas un essai. C'est ce que ce public a envie de donner. |
| **Risque spam** | Faible avec l'angle code, élevé avec l'angle produit. |
| **Potentiel qualitatif** | Élevé sur la robustesse, **faible sur la valeur produit**. |
| **Potentiel quantitatif** | Moyen. |

### Priorité 2

| Canal | Pourquoi | Effort | Qualitatif | Quantitatif |
|---|---|---|---|---|
| **Article technique** (dev.to, Hashnode) — *« Summing RSS is not your WSL2 memory usage »* | Le contenu **existe déjà** dans `RESOURCE-MODEL.md` §4.4. **C'est le seul canal qui travaille encore dans six mois** : les autres s'éteignent en 48 h. Il alimente aussi le référencement sur les requêtes que P1 tape réellement. | 2 h | Moyen | Élevé et **durable** |
| **LinuxFr.org** (journal, FR) | Public technique francophone exigeant, tolérant aux projets personnels quand ils sont présentés honnêtement. | 1 h | Élevé | Faible |
| **Human Coders News** (FR) | Curation francophone, soumission simple. | 15 min | Moyen | Faible |
| **X + Bluesky** | Déjà utilisés, audience quasi inexistante. À **construire** en publiant sur le sujet, pas à exploiter en publiant sur le produit. | Continu | Faible | Faible aujourd'hui |
| **LinkedIn (FR)** | Premier cercle. Utile pour E6 (recrutement direct nominatif), inutile pour E3b. | 30 min | Moyen | Faible |

### À tester

**Discords** WSL, PowerShell, data (FR et EN). Règle sans exception : **participer
avant de publier**. Répondre à trois questions d'autrui avant de mentionner
quoi que ce soit de soi. Sans cela, c'est du spam, quelle que soit la formulation.

**Lobste.rs** : si une invitation se présente. Pas de démarche pour en obtenir une.

### En réserve

**Show HN.** Le meilleur canal disponible, et **on ne peut le jouer qu'une fois**.
Conditions préalables, toutes nécessaires :

1. `README.en.md` en place *(fait)* ;
2. page testeurs en ligne, bilingue, avec liens taggés ;
3. `-Redact` livré *(fait)*, formulaires en place *(fait)* ;
4. Discussions et signalement privé activés ;
5. **au moins un retour externe déjà reçu** — un fil Show HN sans aucun signe de
   vie est plus coûteux que pas de fil du tout.

Date la plus tôt raisonnable : **J30**. Pas avant.

### À éviter

| Canal | Motif |
|---|---|
| **Product Hunt** | Mauvais ajustement, et pas seulement « pas encore ». Audience produit grand public, format vitrine, pour un CLI GPL installé par `git clone` sur une machine Windows avec WSL2. Fort volume, aucun testeur qualifié attendu. |
| **PowerShell Gallery, Winget** | Bloqué jusqu'à P9 par [0009](decisions/0009-distribution-apres-le-produit.md). Ne pas rouvrir sans nouvelle décision. |
| **Publication croisée multi-subreddits** | Détecté et sanctionné par les modérateurs comme par les lecteurs. Brûle plusieurs canaux d'un coup. |
| **Messages directs à froid** | Taux de réponse dérisoire, coût de réputation réel. Les DM ne valent qu'en **réponse** à quelqu'un qui s'est manifesté. |
| **Communautés Slack sans historique** | Même raison que les Discords, en pire : les Slack de communauté tolèrent encore moins l'arrivant qui annonce. |

---

## 3. Angles de communication

Cinq angles. Chacun a un contexte où il fonctionne **et un contexte où il se
retourne** — la seconde colonne est la plus utile des deux.

| Angle | Fonctionne | Se retourne |
|---|---|---|
| **« Voilà pourquoi votre mesure est fausse »** | `microsoft/WSL#4166`, article technique, r/bashonubuntuonwindows. Apporte de la valeur avant de demander quoi que ce soit. **C'est l'angle par défaut.** | Sur un format court : trop long à établir, devient une affirmation sans preuve. |
| **« Lecture seule, aucun engagement »** | Partout. La confiance est le premier frein d'un outil qui lit la machine, et c'est le meilleur argument réel du produit. | Nulle part. **À conserver dans tous les messages, sans exception.** |
| **« Aidez-nous à casser l'outil »** | Communautés hostiles au marketing : Show HN, r/PowerShell. Renverse la relation — on ne demande pas un service, on offre une cible. | Auprès de P3, qui n'a aucune envie de casser quoi que ce soit et lira une corvée. |
| **« Je cherche des testeurs »** | Discords après participation, premier cercle, LinkedIn FR. Direct et honnête là où une relation existe déjà. | Reddit et HN : lu comme du recrutement d'utilisateurs gratuits, et c'est une lecture légitime. |
| **Sécurité / vie privée** | P2, contextes d'entreprise. Consentement révocable, liste fermée de commandes, aucune télémétrie. | P1, qui veut récupérer sa RAM et lira une complication. |

**Ce qui doit figurer dans tout message, quel que soit l'angle :**

1. l'outil est en validation terrain et **cherche ce qui ne marche pas** ;
2. le diagnostic est **lecture seule**, aucune installation permanente ;
3. **ce que l'outil ne fait pas encore** — c'est le meilleur signal de confiance
   disponible, et il ne coûte rien.

**Ce qui ne doit jamais y figurer :** un chiffre de gain non reproductible. La
formulation « jusqu'à 4 Go libérés » est déjà signalée comme un risque de
crédibilité dans le dossier de validation du site (hypothèse CR1) — pour la
raison exacte que `VISION.md` écarte « Optimiser WSL2 » : elle promet un résultat
qu'aucune mesure ne garantit, à un public qui décode ce genre de phrase plus vite
que tout autre.

---

## 4. Messages

Quatre messages, un par canal de priorité 1, plus un français. Pas de variantes :
un message adapté vaut mieux que six déclinaisons.

### `microsoft/WSL#4166` — anglais

> The reason this thread never converges is that most of the numbers being
> compared here don't measure the same thing.
>
> `VmmemWSL` in Task Manager is the whole VM: kernel, page cache, and every guest
> process. Summing RSS inside the distro double-counts shared pages — the same
> page is counted once per process that maps it — so the sum can legitimately
> exceed what the host reports, and a negative "unaccounted" remainder is
> arithmetic rather than a bug.
>
> `MemAvailable` is also not `MemTotal - used`. `MemFree` is nearly always low
> and that is normal: Linux uses free RAM as page cache, which is reclaimable
> under pressure. So "used" and "needed" are two different quantities, and only
> the first one is directly measurable.
>
> Two things worth checking, both free: `autoMemoryReclaim` is not enabled by
> default, and in `gradual` mode it returns inactive cache to Windows. And
> `memory=` in `.wslconfig` is a ceiling on what the VM may take, not an amount
> it reserves — `MemTotal` inside the distro reflects that ceiling, not your
> physical RAM.
>
> I wrote a read-only PowerShell command that prints these side by side, each
> figure tagged with its scope, how it was obtained and how much to trust it:
> <lien>. It writes nothing, installs nothing, and you can delete the folder
> afterwards. I'm looking for people to tell me where it's wrong — that's
> genuinely the point.

> **Note d'exécution.** Chaque affirmation technique de ce message doit être
> revérifiée contre `RESOURCE-MODEL.md` avant publication. Une erreur factuelle
> sur ce fil coûte plus cher que le silence.

### r/bashonubuntuonwindows — anglais

**Titre :** `What I got wrong for months about WSL2 memory (and what finally made it make sense)`

> I spent a while trying to figure out why `VmmemWSL` sat at 8 GB while `htop`
> inside Ubuntu showed 2 GB used. Turns out I was comparing three different
> things and calling them all "memory".
>
> - Task Manager shows the **whole VM**: kernel, page cache, every guest process.
> - Summing RSS inside the distro **double-counts shared pages** — it can exceed
>   the host figure, and that's arithmetic, not a leak.
> - `MemAvailable` is **not** `MemTotal - used`. `MemFree` being low is normal —
>   Linux uses free RAM as page cache, and cache is reclaimable under pressure.
>   "Used" and "needed" are simply not the same quantity.
>
> The two things that changed how I read all this: `autoMemoryReclaim` is not on
> by default, and in `gradual` mode it hands inactive cache back to Windows. And
> `memory=` is a **ceiling**, not a reservation — `MemTotal` inside the distro
> reflects that ceiling rather than your physical RAM, which is why the two
> numbers never lined up for me.
>
> I ended up writing a read-only command that prints all of this together, each
> number tagged with what it actually measures: <lien>. It's early and I'm
> deliberately looking for the cases where it's wrong or unclear — "I didn't
> understand the output" is the most useful thing you could tell me.

### r/PowerShell — anglais, angle code

**Titre :** `Non-destructive INI merge: how I stopped my script from eating other tools' config`

> `.wslconfig` is a shared file — the user edits it, Docker Desktop writes to it,
> WSL Settings writes to it, corporate policy may push it. My script used to
> rewrite it wholesale on every profile switch, which silently destroyed
> `autoMemoryReclaim`, `sparseVhd`, `networkingMode` and anything under
> `[experimental]`. Worse, my own integrity check only verified the keys I had
> just written, so it could never detect the loss.
>
> The fix was a merge that only touches the keys the tool declares it manages,
> preserving unknown keys, unknown sections, comments and ordering — plus an
> explicit `[wisely]` marker so active state is **read**, not guessed by matching
> a memory value (two 4 GB profiles used to be indistinguishable).
>
> Code, tests and the reasoning: <lien>. GPL-3.0, Pester + PSScriptAnalyzer +
> CodeQL + Semgrep in CI. I'd genuinely value a review — particularly on the
> guest-read consent model, which is the part I'm least sure about.

### LinuxFr.org — français, journal

**Titre :** `Wisely : pourquoi je ne sais pas si mon outil sert à quelqu'un`

> J'ai passé plusieurs mois sur un outil en ligne de commande qui explique
> pourquoi WSL2 consomme ce qu'il consomme sous Windows. Il est en GPL v3, il
> a des tests, une CI, et une documentation que je crois honnête.
>
> Il a aussi **zéro utilisateur**, et c'est le sujet de ce journal.
>
> Ce qui m'a le plus appris en écrivant cet outil, ce ne sont pas les
> fonctionnalités : ce sont les mesures fausses que j'ai dû retirer. Une
> métrique qui attribuait la mémoire au mauvais profil. Un seuil d'alerte
> rapporté à la mauvaise référence, donc mathématiquement indéclenchable. Une
> réécriture de `.wslconfig` qui effaçait les réglages des autres outils, et une
> vérification d'intégrité incapable de le détecter, puisqu'elle ne relisait que
> ce qu'elle venait d'écrire.
>
> J'en ai tiré une règle : ne jamais mesurer ce qu'on ne peut pas attribuer. Une
> mesure qui échoue doit le dire ; une métrique dégradée en `null` silencieux est
> pire que pas de métrique du tout.
>
> Aujourd'hui la commande de diagnostic est en lecture seule, chaque chiffre
> porte sa portée et son niveau de confiance, et la lecture à l'intérieur des
> distributions est désactivée tant qu'on ne l'autorise pas explicitement.
>
> Ce que je cherche n'est pas des étoiles : c'est de savoir si quelqu'un d'autre
> que moi a ce problème. Le code, et surtout la documentation qui explique
> pourquoi il est comme ça : <lien>.

### Discord — après participation réelle, jamais à l'arrivée

> Salut — je traîne ici depuis un moment. J'ai écrit un truc pour comprendre
> pourquoi WSL2 mange de la RAM sous Windows, et j'en suis au stade inconfortable
> où j'ai besoin que des gens me disent que ça ne marche pas.
>
> C'est une commande en lecture seule, rien à installer, rien d'écrit sur le
> disque : `pwsh ./wisely.ps1 -Diagnose` après un clone. Cinq minutes.
>
> Ce qui m'intéresse le plus, ce n'est pas « ça marche », c'est « je n'ai rien
> compris à ce que ça affiche ». <lien>

---

## 5. Cadence et règles anti-spam

Non négociables. Chacune vient d'un mode d'échec observable.

1. **Un canal par jour maximum.** Publier partout le même jour est le signal de
   spam le plus reconnaissable qui soit.
2. **Jamais deux messages sur le même canal en moins de 14 jours.**
3. **Aucune relance non sollicitée**, nulle part, jamais.
4. **Aucun message identique sur deux canaux.** Un copier-coller repéré coûte les
   deux canaux, pas un.
5. **Participer avant de publier** sur tout espace communautaire (Discord, Slack,
   forums) : répondre à trois personnes avant de parler de soi.
6. **Un seul commentaire sur une issue GitHub tierce.** Et uniquement sur une
   issue qu'on aide réellement.
7. **Répondre à tout retour sous 48 h**, y compris négatif, y compris injuste.
8. **Ne jamais discuter un retour négatif publiquement.** On remercie, on
   consigne, on corrige ou on explique pourquoi non.
9. **Ne jamais citer la référence courte (`owner/repo#numéro`) ni l'URL
   complète d'un canal externe dans un message de commit ou de PR.** GitHub
   crée un renvoi public automatique ("mentioned this issue") visible
   directement sur l'issue ciblée, quel que soit le dépôt d'où part le
   commit — exposant le vocabulaire interne de la campagne (canal,
   expérience, dénominateur) à des lecteurs habitués à repérer l'autopromo.
   Décrire le canal en prose suffit et ne déclenche aucun renvoi. Constat :
   2026-09-04, sur `microsoft/WSL#4166` via le commit `8804892`.

---

## 6. La chaîne de mesure de l'exposition

C'est la pièce dont l'absence a fait échouer E3a. Quatre étages, **aucun sans
consentement, aucune télémétrie dans le CLI** (`DOCTRINE-LECTURE.md` §2.4).

```
  [1] impressions par canal
      relevé manuel : analytics X/Bluesky, votes et vues Reddit,
      vues de l'article, position HN
              |
              v
  [2] visites de la page testeurs
      PostHog côté site, lien taggé ?src=<canal> distinct par canal
              |
              v
  [3] clones et vues uniques du dépôt
      API GitHub Traffic - fenêtre glissante de 14 jours,
      donc à relever CHAQUE SEMAINE sous peine de perdre la donnée
              |
              v
  [4] retours déclarés
      formulaires field-test, discussions, réponses directes
```

**Taux à calculer, et ce que chacun dit :**

| Taux | Ce qu'un effondrement signifie |
|---|---|
| [1] → [2] | Le **message** ne convainc pas. Réécrire le message, pas le produit. |
| [2] → [3] | La **page** ou la promesse ne convainc pas. Le produit n'est pas encore en cause. |
| [3] → [4] | Le **produit** ou le chemin de retour est en cause. C'est ici que le signal devient exploitable. |

Cet ordre est la valeur du dispositif : il dit **à quel étage** ça casse. E3a n'en
avait aucun, et ne pouvait donc rien attribuer.

> **Limite à énoncer, jamais à contourner.** L'analytique du site est configurée
> sans cookie ni `localStorage` (`src/lib/analytics/config.ts`). Elle mesure
> l'exposition et le premier clic, **jamais le retour d'un visiteur**. La
> réutilisation — donc A12 — ne sera connue que par déclaration. Ce renoncement
> est cohérent avec l'absence de bannière de consentement : c'est une limite du
> dispositif, pas un défaut à corriger. Elle se dit ainsi, et ne s'estime jamais.

**Relevé hebdomadaire**, chaque lundi, dans le journal de validation
d'`ASSUMPTIONS.md`. Le point 3 impose la cadence : la fenêtre GitHub Traffic est
glissante sur 14 jours, une donnée non relevée est une donnée perdue.

---

## 7. Transformer les retours en décisions

Cette section **réutilise** le vocabulaire de preuve et l'échelle de gravité du
dossier de validation du dépôt `wisely-site` (`docs/VALIDATION.md` §2 et §3). Elle
ne les redéfinit pas : un second vocabulaire rendrait les deux inutilisables.

### Catégories

Appliquées en labels par les formulaires : `bug` · `mesure-fausse` ·
`incomprehension` · `ux` · `installation` · `compatibilite` · `performance` ·
`securite` · `manque` · `hors-perimetre`.

### Score

```
Priorité = (Gravité x Fréquence x Confiance) / Effort
```

| Facteur | Barème |
|---|---|
| **Gravité** | Critique 8 · Majeur 4 · Moyen 2 · Mineur 1 — définitions de `VALIDATION.md` §3 |
| **Fréquence** | 1 testeur 1 · 2 testeurs 2 · ≥ 3 testeurs 4 |
| **Confiance** | reproduit localement 3 · rapporté avec sortie `-Redact` 2 · rapporté seul 1 |
| **Effort** | ≤ 1 h 1 · ≤ 1 jour 2 · > 1 jour 4 |

### Deux règles qui priment sur le score

Un score fait toujours mentir un cas rare. Ces deux-là ne passent pas par le
calcul :

1. **Un signalement de sécurité ne se score pas.** Canal privé, `SECURITY.md`,
   traitement immédiat.
2. **Une mesure fausse passe avant tout le reste**, quel que soit son score.
   C'est la première règle d'ordonnancement de `ROADMAP.md` : *on ne construit ni
   diagnostic ni recommandation sur une mesure qui ment*. Le projet a déjà payé
   pour l'apprendre — cinq correctifs en P0/v2.5.

### Lecture des signaux

| Signal | Ce qu'il autorise |
|---|---|
| `observation unique` — 1 testeur | Formuler une question pour la session suivante. **Aucun correctif.** |
| `tendance récurrente` — ≥ 3 sur 6, ou stable sur 2 périodes | Prioriser un travail de correction. |
| `problème confirmé` — tendance **et** cohérence qualitatif/comportemental | Décider, corriger, retester. |
| `hypothèse infirmée` | **Le statut le plus utile du tableau.** Réviser la conception. |
| *contradictoire* | **Ne pas moyenner.** Segmenter par persona : l'écart entre P1 et P3 *est* le résultat. |
| `signal insuffisant` | Relancer une expérience mieux dimensionnée. Ne rien conclure. |

### Un retour n'est pas une décision produit

Chaque retour est confronté au **filtre de périmètre** de `VISION.md` — quel objet
(État, Cause, Politique, Action), quel maillon de la boucle, quelle situation de
`USE-CASES.md` — avant d'entrer dans la roadmap.

Un retour qui ne passe pas le filtre est **remercié, consigné, et clos avec son
motif**. Jamais ignoré, jamais accepté par politesse. C'est ce qui empêche la
roadmap de redevenir une liste de fonctionnalités — précisément le sort qu'a
connu le spike Terminal.Gui ([0007](decisions/0007-annulation-spike-terminal-gui.md)).

Symétriquement : **un retour utilisateur ne vaut pas non plus vérité**. Cinq
personnes qui demandent la même fonctionnalité peuvent toutes décrire le même
contournement d'un problème que la fonctionnalité ne résout pas. On cherche le
problème derrière la demande — c'est le premier champ, obligatoire, du formulaire
de demande de fonctionnalité.

---

## 8. Rendre la boucle visible

C'est là que meurent la plupart des programmes de bêta : le testeur ne voit jamais
ce que son retour a produit, et ne revient pas.

1. **`CHANGELOG.md` cite l'issue et remercie nommément.** `SECURITY.md` prend déjà
   cet engagement pour les vulnérabilités ; il s'étend ici à tout retour, sauf
   demande contraire — le formulaire détaillé propose la case.
2. **Le rapporteur est notifié à la publication**, pas seulement à la correction.
   La case existe dans les deux formulaires.
3. **Le journal de validation est mis à jour y compris quand le résultat infirme
   l'hypothèse.** La règle existe déjà dans `ASSUMPTIONS.md`, et c'est le cas le
   plus précieux.

---

## Documents liés

`ASSUMPTIONS.md` (les hypothèses, les expériences, le journal) ·
`ROADMAP.md` (l'ordre et la barrière P3) · `VISION.md` (le filtre de périmètre) ·
`USE-CASES.md` (les situations) · `SECURITY.md` (la divulgation responsable) ·
`TASKS.md` (l'état d'avancement) · `docs/validation/protocoles/` de ce dépôt
(protocoles des expériences CLI E4 et E5) · dossier de validation du dépôt
`wisely-site` (vocabulaire de preuve, gravité, protocoles des hypothèses du site).
