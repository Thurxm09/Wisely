# Le problème — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> quel problème existe, pour qui, et avec quelles preuves ?
>
> Ce document décrit un espace de problème, pas un produit. Il ne nomme
> délibérément aucune fonctionnalité de Wisely : si une phrase ci-dessous ne
> reste pas vraie le jour où Wisely disparaît, elle n'a rien à faire ici.
>
> Statut : vivant. Dernière révision : 2026-08-27.

---

## 1. Le problème, en une phrase

**L'utilisateur ne peut pas relier la pression de ressources qu'il observe sur
Windows à ce qui se passe réellement dans WSL2, ni savoir quelle action serait
sûre et pertinente.**

C'est le problème tel qu'il est **vécu**. Il a deux causes structurelles, dans cet
ordre :

1. **La consommation de ressources de WSL2 est opaque.** Personne ne peut voir ce
   que WSL2 consomme réellement, ni pourquoi.
2. **Son plafond est global.** Une fois qu'on sait qu'il y a un problème, on
   découvre que le seul levier disponible s'applique à toute la machine, s'édite
   dans un fichier texte, et exige de tuer l'ensemble de l'environnement Linux
   pour prendre effet.

L'ordre compte, deux fois. Longtemps, ce projet a considéré la rigidité comme le
problème premier et l'opacité comme un détail — c'est l'inverse. Et jusqu'au
2026-08-27, ce paragraphe énonçait encore les deux causes **à la place** du
problème vécu : personne n'écrit « la consommation de WSL2 est opaque ». Les gens
écrivent « pourquoi mon PC rame ». Les situations correspondantes sont décrites
dans `USE-CASES.md`.

---

## 2. Pourquoi c'est difficile : la frontière

WSL2 fait tourner Linux dans une machine virtuelle légère. Cette frontière est
exactement l'endroit où tous les outils d'observation échouent, des deux côtés à
la fois :

| Depuis | Ce qu'on voit | Ce qu'on ne voit pas |
|---|---|---|
| **Windows** | Un seul processus opaque (`VmmemWSL`, anciennement `vmmem`) agrégeant le noyau Linux, le page cache et tous les processus invités | Quelle distribution, quel processus, depuis quand |
| **Linux** | Les processus invités, via `htop`, `free`, `/proc` | Le coût réel côté hôte, et l'existence même du plafond imposé |

**Personne ne fait la jointure.** C'est le fait structurant de tout cet espace de
problème.

Second désalignement, moins visible : le plafond de `.wslconfig` est **global à la
machine**, alors que les charges de travail sont **par distribution et par
projet**. Un même utilisateur peut avoir une distribution de développement, une
distribution Docker et un environnement de test, tous soumis au même plafond
unique.

---

## 3. Cartographie de l'espace

Deux axes : la ressource concernée, et la question que se pose l'utilisateur.

| | Que se passe-t-il **maintenant** ? | Que s'est-il passé **pendant mon absence** ? | **Pourquoi** ? (attribution) | **Que faire** ? | **Le faire** | **Le maintenir** |
|---|---|---|---|---|---|---|
| **RAM** | Partiellement couvert | Non couvert | Non couvert | Non couvert | Couvert | Non couvert |
| **CPU** | Partiellement couvert | Non couvert | Non couvert | Non couvert | Couvert | Non couvert |
| **Swap** | Non couvert | Non couvert | Non couvert | Non couvert | Couvert | Non couvert |
| **Disque (VHDX)** | Non couvert | Non couvert | Non couvert | Non couvert | Partiellement | Non couvert |
| **I/O, GPU, réseau, temps de démarrage** | Non couvert | Non couvert | Non couvert | Non couvert | Non couvert | Non couvert |

Les colonnes **« pourquoi ? »** et **« que s'est-il passé ? »** sont les plus
douloureuses et les moins servies. C'est cohérent avec la plainte réelle observée
dans l'écosystème : personne n'écrit « mon plafond WSL2 est mal réglé ». Les gens
écrivent « VmmemWSL consomme 9 Go », ce qui est une question d'attribution.

---

## 4. Qui a ce problème

**Avertissement méthodologique, à ne pas contourner.** Wisely n'a aucun
utilisateur réel à ce jour, aucun retour, aucune télémétrie. Tout ce qui suit est
**hypothèse**, classée par confiance décroissante. Ces segments ne doivent jamais
être cités comme des faits dans une décision produit ; ils sont là pour être
falsifiés. Voir `ASSUMPTIONS.md`.

### Le segment primaire est une situation, pas un métier

> **Un utilisateur confronté à un problème de ressources WSL2 qu'il ne comprend pas.**

Le métier est le mauvais axe de découpage. Un ingénieur ML et un étudiant vivent
exactement le même incident quand WSL2 consomme toute la RAM disponible ; un
développeur web et un SRE vivent le même incident quand un service Linux reste
actif toute la nuit. Ce qui distingue réellement les besoins, c'est la
**situation** — décrite dans `USE-CASES.md`.

Les segments A à F ci-dessous restent valides et utiles : ils décrivent les
**contextes** qui modulent ces situations — environnement Docker, machine
contrainte, poste d'entreprise, multi-distribution. Ils ne sont plus lus comme
des marchés distincts, mais comme des variantes d'un même problème. C'est ce qui
permet d'élargir l'audience sans fabriquer un produit générique.

### A — « Pourquoi mon PC rame ? » · confiance haute, volume le plus élevé

WSL2 tourne chez lui parce qu'*autre chose* l'a installé : Docker Desktop, un
outil imposé par son employeur, un cours. Il ne sait pas ce qu'est `.wslconfig`.
Il a cherché « VmmemWSL high memory », une requête dont le volume se mesure à la
quantité d'articles écrits pour y répondre. Compétence PowerShell : nulle à
faible. **Toute solution qui exige un clone Git, une modification de politique
d'exécution et des droits administrateur lui est inaccessible avant même qu'il ne
rencontre le produit.**

### B — Utilisateur Docker Desktop · confiance haute

Probablement la population WSL2 la plus nombreuse. Possède une distribution
`docker-desktop`, souvent un `networkingMode` particulier, parfois du DNS
tunneling. Son `.wslconfig` contient des réglages qu'il n'a pas forcément écrits
lui-même et qu'il ne peut pas se permettre de perdre.

### C — Étudiant, portable 8-16 Go · confiance moyenne-haute

Usage non-développeur de WSL2 : un cours, un TP, un outil imposé. Contrainte
matérielle réelle et permanente, compétence système faible.

### D — Data / ML · confiance moyenne

Sa douleur réelle porte sur le **GPU** et le **disque** (environnements conda,
jeux de données, points de contrôle de modèles), plus que sur le plafond RAM.
Attention : c'est le segment dont le nom apparaît dans les profils livrés par
Wisely, ce qui a longtemps masqué le fait que ses vraies contraintes ne sont pas
celles que l'outil adresse.

### E — DevOps / SRE sur poste d'entreprise · confiance moyenne

Réseau miroir, VPN, pare-feu d'entreprise, politique d'exécution `AllSigned`.
Double barrière : sa configuration WSL2 est complexe et fragile, et il ne peut
pas installer de script non signé.

### F — Utilisateur multi-distributions · confiance moyenne

Son problème est *par distribution* ; le seul levier disponible est *global*.

### Un constat inconfortable mais utile

Le segment le mieux servi par l'approche historique du projet — développeur solo
qui connaît déjà `.wslconfig`, jongle délibérément entre contextes de travail, et
n'a **rien d'autre** dans sa configuration WSL2 — est vraisemblablement **le plus
petit de tous**. C'est aussi le profil exact du mainteneur. Ce n'est pas
disqualifiant : beaucoup de bons outils commencent là. Mais cela doit être assumé
comme un choix, jamais subi comme un angle mort.

---

## 5. Ce que l'écosystème résout déjà

Rien de ce qui suit ne doit être présenté comme un manque. Ces capacités
existent, et les reconstruire serait du gaspillage.

| Capacité | État, vérifié en août 2026 |
|---|---|
| **Édition graphique de `.wslconfig`** | Microsoft livre **WSL Settings** (`wslsettings.exe`, WinUI 3) : mémoire, cœurs CPU, taille et emplacement du swap, compatible avec le fichier texte existant |
| **Restitution automatique de la mémoire** | `autoMemoryReclaim` (`gradual` / `dropcache`), depuis WSL 1.3.10 / 2.0. Pas actif par défaut, et interactions connues avec zswap |
| **Récupération automatique de l'espace disque** | `sparseVhd` : désallocation à la suppression de fichiers. **Rend `Optimize-VHD` inopérant** — la méthode correcte devient `fstrim` depuis Linux, et les deux approches sont mutuellement exclusives |
| **Édition de `.wslconfig` / `wsl.conf` par des tiers** | WSL UI, wsl2-distro-manager, WSLMan |
| **Profils de ressources commutables** | WSL-Memory-Monitor (profils, curseur, icône de zone de notification). Existe, sans traction : 3 étoiles, 4 commits |
| **Compaction VHDX manuelle** | Plusieurs scripts publics, dont WSL-VHDX-Compact — désormais partiellement obsolètes face à `sparseVhd` |
| **Limites de ressources du backend WSL** | Docker Desktop expose sa propre interface |
| **Gestion graphique généraliste des distributions** | `wsl2-distro-manager` et `wsl-dashboard` couvrent installation, sauvegarde, restauration, configuration, monitoring temps réel, réseau, USB, migration. Une extension VS Code « WSL Manager » couvre déjà mémoire, CPU, swap, `sparseVhd` et `autoMemoryReclaim`. **Traction rapportée par l'audit d'août 2026, non revérifiée ici :** de l'ordre de quelques milliers d'étoiles chacun |

### Ce qui reste vraiment absent

- **Aucune mesure de la consommation WSL2 en ligne de commande.** Ni `wsl --status`
  ni `wsl --version` ne l'exposent.
- **Aucune attribution.** Rien ne relie les gigaoctets de `VmmemWSL` à une
  distribution ou à un processus.
- **Aucun historique.** Rien ne conserve de série temporelle de la consommation.
- **Aucun diagnostic agrégé.** L'information est éparpillée sur des dizaines
  d'articles de blog dont certains sont désormais faux.
- **Aucune coexistence garantie.** Aucun des outils qui écrivent `.wslconfig` ne
  garantit de préserver les clés qu'il ne gère pas.

### Lecture du paysage concurrentiel

Deux catégories doivent être distinguées, et l'audit d'août 2026 a raison
d'insister. Celle des **gestionnaires WSL graphiques généralistes** est occupée
par des projets matures et adoptés : la reconstruire serait du gaspillage, et
c'est la raison pour laquelle `VISION.md` exclut explicitement le tableau de bord
comme proposition de valeur.

Celle des « profils de ressources WSL2 », en revanche, **existe déjà et personne
ne l'a gagnée**. Information à double tranchant, à ne sur-interpréter dans aucun sens :
ce n'est pas la preuve d'une demande refoulée (aucun de ces outils n'a de
traction, y compris ceux plus accessibles qu'un script PowerShell à cloner), ni
la preuve d'un marché mort (aucun ne fait la jointure, et aucun n'a un niveau
d'ingénierie élevé).

---

## 6. Ce que nous n'adressons pas

Délimiter est aussi important que décrire. Ne relèvent pas de ce problème :

- **La gestion du cycle de vie des distributions** (créer, cloner, exporter,
  supprimer) — plusieurs outils le font, et ce n'est pas une question de
  ressources.
- **Les performances de WSL2 en tant que telles** (vitesse d'I/O sur `/mnt/c`,
  temps de démarrage) — problèmes réels, mais qui relèvent de Microsoft.
- **L'optimisation des charges Linux elles-mêmes** — si un processus fuit, c'est
  un problème applicatif, pas un problème WSL2.
- **La configuration réseau, GPU, ou pare-feu** — sauf lorsqu'elle affecte
  directement la relation entre consommation et autorisation.
- **Le remplacement de WSL Settings** — Microsoft fournit les interrupteurs.

---

## 7. Comment ce document est utilisé

`VISION.md` choisit **une** partie de cet espace et explique pourquoi.
`USE-CASES.md` en décrit la face vécue, situation par situation.
`RESOURCE-MODEL.md` dit ce que valent réellement les chiffres qu'on y manipule.

Aucune fonctionnalité ne devrait entrer dans `ROADMAP.md` sans pouvoir désigner
la case du tableau §3 qu'elle remplit et la situation de `USE-CASES.md` qu'elle
sert.

Si une décision produit contredit ce document, c'est ce document qu'il faut
réviser d'abord — pas le contourner.

---

## Sources

État de l'écosystème vérifié en août 2026 :
[Microsoft Learn — Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) ·
[WSL Settings GUI Application](https://deepwiki.com/microsoft/WSL/4.3-wsl-settings-gui-application) ·
[Phoronix — WSL 1.3.10 memory reclaim](https://www.phoronix.com/news/Microsoft-WSL-1.3.10) ·
[Microsoft Q&A — sparse VHD cannot be compacted](https://learn.microsoft.com/en-us/answers/questions/1526083/in-wsl2-with-sparse-vhd-the-storage-usage-does-not) ·
[Sparse VHD support in WSL](https://danielcosenza.com/posts/wsl-sparse-vhd/) ·
[Microsoft Q&A — VmmemWSL](https://learn.microsoft.com/en-us/answers/a/1310278) ·
[WSL-Memory-Monitor](https://github.com/oratual/WSL-Memory-Monitor) ·
[wsl-cpu-monitor](https://github.com/tab4moji/wsl-cpu-monitor)
