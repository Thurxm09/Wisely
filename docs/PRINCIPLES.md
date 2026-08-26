# Principes produit — Wisely

> **Question à laquelle ce document répond, et à laquelle il est seul à répondre :**
> comment trancher un arbitrage sans rouvrir le débat à chaque fois ?
>
> Ces principes sont des **critères de conception**, pas des règles de style. Une
> proposition qui en viole plusieurs simultanément ne doit pas être implémentée,
> quel que soit son attrait technique. Les conventions de code vivent dans
> `CONTRIBUTING.md`, pas ici.
>
> Statut : vivant. Dernière révision : 2026-08-26.

---

## Les principes historiques

Repris de l'ancien `ROADMAP.md` §9, où ils étaient noyés dans un document qui
faisait cinq métiers à la fois. Ils ont tenu et restent valides.

### 1. Zéro configuration requise pour commencer

Un utilisateur qui installe l'outil doit pouvoir l'exécuter immédiatement, sans
modifier aucun fichier. La personnalisation est possible, jamais obligatoire.

> **Révision 2026-08-26.** Ce principe était en contradiction ouverte avec les
> profils livrés : trois valeurs absolues en gigaoctets calibrées sur une machine
> 16 Go ne peuvent pas être un défaut raisonnable sur une machine 8 Go ou 64 Go.
> Un défaut qui n'est valable que sur une seule configuration matérielle n'est pas
> un défaut, c'est une préférence personnelle. La conséquence est actée dans
> `decisions/0006-profils-derives.md`.

### 2. Réversibilité systématique

Toute action modifiant l'état du système doit être réversible. Aucune opération
destructive irréversible sans confirmation explicite. Le backup existe pour les
fichiers, les logs pour les actions.

### 3. Échouer vite et bruyamment

Une erreur vaut mieux qu'un comportement silencieux incorrect. Fichier manquant,
JSON invalide, droits insuffisants : le dire clairement, immédiatement, avec ce
qu'il faut faire.

> **Révision 2026-08-26.** Ce principe avait une exception non écrite qui l'a vidé
> de son sens : les métriques « optionnelles » retournaient `$null` en silence en
> cas d'échec, pour ne jamais faire échouer l'appelant. Résultat, trois
> défaillances totales de la couche d'observation sont restées invisibles pendant
> toute la vie du projet. Voir le principe 9.

### 4. Scriptabilité de première classe

Toute action réalisable via le menu interactif doit l'être en commande directe,
avec des codes de sortie standard. Les scripts d'automatisation sont des citoyens
de première classe.

### 5. Source de vérité unique

`data/profiles.json` reste la seule source de vérité des profils et réglages.
Aucun comportement métier variable ne doit être codé en dur. Les constantes
techniques (noms de tâches planifiées, clés requises) sont des exceptions
acceptables.

### 6. Minimalisme fonctionnel

Chaque fonctionnalité doit justifier sa présence par une valeur utilisateur
documentée. « C'est faisable » et « c'est intéressant » ne sont pas des
justifications. La question à poser : combien d'utilisateurs réels en ont besoin,
et à quelle fréquence ?

> **Complément 2026-08-26.** Ce principe s'applique aussi à la suppression. Une
> fonctionnalité déjà écrite qui ne survit pas à cette question doit être retirée,
> pas conservée par respect pour le travail investi.

### 7. Compatibilité descendante des profils

Une mise à jour ne doit jamais casser un `profiles.json` existant. Les nouvelles
clés sont optionnelles avec des défauts documentés. Une migration automatique est
proposée si le schéma évolue de façon incompatible.

---

## Les principes ajoutés

Chacun est né d'une défaillance constatée dans le code, pas d'une intuition. Ils
sont formulés pour que la même erreur ne puisse pas se reproduire sous une autre
forme.

### 8. Ne jamais détruire ce qu'on ne gère pas

Wisely écrit dans un fichier partagé. `.wslconfig` peut contenir des réglages
posés par l'utilisateur, par Docker Desktop, par WSL Settings ou par une
politique d'entreprise : `networkingMode`, `dnsTunneling`, `autoMemoryReclaim`,
`sparseVhd`, `nestedVirtualization`, `vmIdleTimeout`, une section
`[experimental]`.

**Wisely ne touche qu'aux clés qu'il gère, et laisse le reste intact.** Cela vaut
pour tout fichier, tout réglage système et toute tâche planifiée que l'outil n'a
pas créés lui-même.

> *Origine :* `ConvertTo-WslConfigContent` régénère aujourd'hui le fichier entier
> à partir de cinq champs, effaçant silencieusement tout le reste au premier
> switch. Et `Test-WslConfigIntegrity` ne vérifie que les trois clés que Wisely
> vient d'écrire — le filet de sécurité ne pouvait donc pas détecter la perte.

### 9. Ne jamais mesurer ce qu'on ne peut pas attribuer

Une mesure doit pouvoir désigner ce qu'elle mesure. Si une grandeur ne peut pas
être rattachée à sa cause, elle ne doit pas être affichée comme si elle l'était.

Corollaire opérationnel : **une mesure qui échoue doit le dire**. Une métrique
dégradée en `$null` silencieux est pire que pas de métrique du tout, parce
qu'elle est indiscernable d'une valeur nulle légitime.

> *Origine :* `ramDeltaGB` mesure la RAM libérée par l'arrêt de WSL2, puis
> l'attribue au profil cible dans le rapport hebdomadaire. Le seuil d'alerte
> compare la part de WSL2 dans la RAM **totale** à un seuil pensé pour la part de
> son **plafond**. Et `Get-Process -Name "vmmem"` ne trouve rien sur Windows 11
> récent, où le processus s'appelle `VmmemWSL` — trois échecs silencieux.

### 10. Aucune recommandation sans la mesure qui la source

Wisely ne dit jamais « mets 6 Go ». Il dit « 6 Go, parce que ton pic mesuré sur
14 jours est 5,4 Go, atteint trois fois ». La recommandation porte sa preuve.

Ce n'est pas de la politesse : c'est ce qui rend une recommandation
**réfutable**, donc digne de confiance. Un outil qui touche à la configuration
système de quelqu'un ne peut pas demander une adhésion aveugle.

Corollaire : si la mesure n'est pas disponible ou pas fiable, **il n'y a pas de
recommandation** — pas de recommandation par défaut, pas de valeur « raisonnable »
sortie de nulle part.

### 11. Annoncer le coût avant de le faire payer

L'action centrale de Wisely interrompt tout l'environnement Linux en cours.
C'est la propriété la plus dangereuse du produit. Avant toute opération
destructive, l'outil dit **ce qui va être perdu**, précisément.

> *Origine :* `Confirm-WslShutdown` (v2.4) fait la moitié du chemin — il signale
> que des distributions tournent, sans dire ce qui s'y exécute. Ce principe pose
> la direction : plus l'outil voit clair, plus l'avertissement doit être précis.

### 12. La confiance se déclare avant de s'exercer

Toute capacité qui étend la portée de Wisely — lire dans une distribution Linux,
écrire ailleurs que dans `.wslconfig`, envoyer quoi que ce soit sur le réseau —
doit être documentée **avant** d'être implémentée, avec ce qu'elle fait et ce
qu'elle ne fera jamais.

Voir `DOCTRINE-LECTURE.md`, écrit avant la ligne de code correspondante.

---

## Comment utiliser ces principes

Devant une proposition, les questions dans l'ordre :

1. S'exprime-t-elle comme une opération sur l'écart (`VISION.md`) ?
2. Quelle case de la carte du problème remplit-elle, pour quel segment
   (`PROBLEM.md`) ?
3. Viole-t-elle un principe ci-dessus ? Lequel, et est-ce assumé et écrit ?
4. Repose-t-elle sur une hypothèse non validée (`ASSUMPTIONS.md`) ? Si oui, la
   valider coûte-t-il moins cher que de construire ?

Une réponse absente à la question 1 ou 2 est un signal d'arrêt, pas un détail à
préciser plus tard.
