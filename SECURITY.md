# Politique de sécurité

## Versions supportées

Seule la version majeure actuelle bénéficie de correctifs de sécurité.

| Version | Supportée          |
| ------- | ------------------ |
| 3.x     | :white_check_mark: |
| 2.x     | :x:                |
| 1.x     | :x:                |

> Les versions 1.x et 2.x ne reçoivent plus aucune mise à jour, y compris les correctifs de sécurité. Il est fortement recommandé de migrer vers la version 3.x.

---

## Ne publiez jamais ceci dans une issue publique

Wisely lit l'état de votre machine. Sa sortie peut donc contenir des informations qui vous identifient ou qui décrivent votre environnement de travail. **Avant de coller quoi que ce soit dans une issue, une discussion ou un message public**, retirez :

- les **noms de vos distributions WSL** (ils portent souvent un nom de client, de projet ou d'employeur) ;
- les **noms de processus** remontés par l'attribution mémoire (même remarque) ;
- les **chemins absolus**, qui contiennent votre nom d'utilisateur Windows ;
- les **noms d'hôte** et identifiants de machine ;
- le contenu intégral d'un `.wslconfig` géré par une politique d'entreprise ;
- toute clé, jeton ou identifiant, quel qu'en soit le support.

**Utilisez `-Redact`, c'est fait pour ça :**

```powershell
pwsh ./wisely.ps1 -Diagnose -Redact
```

Cette option remplace les noms de distributions et de processus par des pseudonymes stables (`distro-1`, `proc-1`, …) et **conserve intégralement** les chiffres, les unités, les portées, les classes de mesure et les niveaux de confiance — c'est-à-dire tout ce qui rend un rapport exploitable. Ajoutez `-Json` si vous préférez une sortie structurée.

Relisez toujours la sortie avant de la coller. `-Redact` couvre les champs connus de Wisely ; il ne peut rien contre une information sensible qui apparaîtrait dans un champ libre que vous remplissez vous-même.

---

## Signalement d'une vulnérabilité

Si vous découvrez une vulnérabilité de sécurité dans ce projet, **merci de ne pas ouvrir d'issue publique**.

### Procédure

1. **Ouvrez un rapport privé** via l'onglet **Security > Advisories** de ce dépôt GitHub :
   `https://github.com/Thurxm09/Wisely/security/advisories/new`
2. Décrivez la vulnérabilité avec le plus de détails possible :
   - Composant concerné (ex. : `wisely.ps1`, `modules/ProfileManager.ps1`, `modules/GuestReader.ps1`)
   - Étapes de reproduction
   - Impact potentiel (élévation de privilèges, exécution de code arbitraire, fuite de données, etc.)
   - Version affectée (`wisely -Version`)
3. Si possible, proposez un correctif ou une piste de résolution.

Un rapport privé n'a pas besoin d'être expurgé : le canal est confidentiel. C'est justement pour cela qu'il existe.

### Délais de réponse

| Étape                                  | Délai estimé |
| -------------------------------------- | ------------ |
| Accusé de réception                    | 48 heures    |
| Évaluation initiale (accepté / rejeté) | 7 jours      |
| Publication d'un correctif             | 30 jours     |

> Ces délais sont indicatifs et peuvent varier selon la complexité de la vulnérabilité. Wisely est maintenu par une seule personne : ils sont tenus de bonne foi, pas contractuels.

---

## Périmètre

### Dans le périmètre

- Exécution de code arbitraire via la manipulation des fichiers `data/profiles.json` ou `.wslconfig`
- Élévation de privilèges liée aux tâches planifiées Windows créées par `-Monitor start`
- Contournement des validations d'entrée (ex. : `-NewProfile`, `-Import`)
- Fuite de données sensibles dans les logs ou les rapports générés
- **Contournement du consentement de lecture invitée** (`settings.guestReadConsent`) : toute voie par laquelle `modules/GuestReader.ps1` exécuterait une commande dans une distribution sans consentement accordé
- **Sortie de la liste fermée de commandes invitées** documentée dans `docs/DOCTRINE-LECTURE.md` : toute injection permettant d'exécuter autre chose que les commandes recensées
- **Défaillance de `-Redact`** : toute donnée identifiante (nom de distribution, nom de processus, chemin, nom d'hôte) qui survivrait à l'expurgation
- **Écriture inattendue en mode diagnostic** : `-Diagnose`, `-Explain` et `-History` sont garantis en lecture seule ; toute écriture disque déclenchée par ces chemins est une vulnérabilité, pas un bug

### Hors périmètre

- Vulnérabilités dans Windows, PowerShell ou WSL2 eux-mêmes
- Problèmes liés à une configuration système non standard ou intentionnellement non sécurisée
- Problèmes de style de code ou de lisibilité

---

## Divulgation responsable

Nous nous engageons à :

- Traiter chaque signalement avec sérieux et confidentialité
- Notifier le rapporteur une fois le correctif déployé
- Mentionner le rapporteur dans le changelog (sauf demande contraire)

Merci de nous accorder le temps nécessaire pour corriger la vulnérabilité avant toute divulgation publique.
