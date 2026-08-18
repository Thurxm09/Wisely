# Politique de sécurité

## Versions supportées

Seule la version majeure actuelle bénéficie de correctifs de sécurité.

| Version | Supportée          |
| ------- | ------------------ |
| 2.x     | :white_check_mark: |
| 1.x     | :x:                |

> Les versions 1.x ne reçoivent plus aucune mise à jour, y compris les correctifs de sécurité. Il est fortement recommandé de migrer vers la version 2.x.

---

## Signalement d'une vulnérabilité

Si vous découvrez une vulnérabilité de sécurité dans ce projet, **merci de ne pas ouvrir d'issue publique**.

### Procédure

1. **Ouvrez un rapport privé** via l'onglet **Security > Advisories** de ce dépôt GitHub :
   `https://github.com/Thurxm09/Wisely/security/advisories/new`
2. Décrivez la vulnérabilité avec le plus de détails possible :
   - Composant concerné (ex. : `wisely.ps1`, `modules/ProfileManager.ps1`)
   - Étapes de reproduction
   - Impact potentiel (élévation de privilèges, exécution de code arbitraire, fuite de données, etc.)
   - Version affectée
3. Si possible, proposez un correctif ou une piste de résolution.

### Délais de réponse

| Étape                                  | Délai estimé |
| -------------------------------------- | ------------ |
| Accusé de réception                    | 48 heures    |
| Évaluation initiale (accepté / rejeté) | 7 jours      |
| Publication d'un correctif             | 30 jours     |

> Ces délais sont indicatifs et peuvent varier selon la complexité de la vulnérabilité.

---

## Périmètre

### Dans le périmètre

- Exécution de code arbitraire via la manipulation des fichiers `data/profiles.json` ou `.wslconfig`
- Élévation de privilèges liée aux tâches planifiées Windows créées par `-Monitor start`
- Contournement des validations d'entrée (ex. : `-NewProfile`, `-Import`)
- Fuite de données sensibles dans les logs ou les rapports générés

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
