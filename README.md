# Wisely — WSL2 Resource Intelligence & Control

> **Comprendre WSL. Agir en confiance.**
>
> Wisely transforme l'état réel des ressources WSL2 en décisions explicables et en
> actions sûres. Aujourd'hui, il livre le maillon « agir » : profils mémoire,
> sauvegarde et rollback à chaque écriture, surveillance RAM en arrière-plan et
> rapports, depuis un menu interactif ou une seule commande.

![Version](https://img.shields.io/badge/version-2.4.0-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D4?logo=windows&logoColor=white)
![WSL](https://img.shields.io/badge/WSL-2-orange?logo=linux&logoColor=white)
![License](https://img.shields.io/badge/License-GPL--v3-blue)

## Table des matières

- [Wisely — WSL2 Resource Intelligence \& Control](#wisely--wsl2-resource-intelligence--control)
  - [Table des matières](#table-des-matières)
  - [Pourquoi ce projet ?](#pourquoi-ce-projet-)
  - [Fonctionnalités](#fonctionnalités)
  - [Prérequis](#prérequis)
  - [Installation](#installation)
  - [Démarrage rapide](#démarrage-rapide)
  - [Référence des commandes](#référence-des-commandes)
  - [Profils par défaut](#profils-par-défaut)
  - [Intégration Oh My Posh / Windows Terminal](#intégration-oh-my-posh--windows-terminal)
  - [Profils personnalisés](#profils-personnalisés)
  - [Surveillance RAM](#surveillance-ram)
  - [Rapports hebdomadaires](#rapports-hebdomadaires)
  - [Import / Export](#import--export)
  - [Architecture](#architecture)
  - [Configuration avancée](#configuration-avancée)
  - [Licence](#licence)

---

## Pourquoi ce projet ?

Depuis Windows, WSL2 est une boîte opaque : un seul processus agrège le noyau Linux, le cache et tous les processus invités. Depuis Linux, `htop` ignore jusqu'à l'existence du plafond imposé. **Personne ne fait la jointure** — et c'est pour cela qu'on ne sait ni pourquoi WSL2 consomme ce qu'il consomme, ni quelle action serait sûre.

Wisely s'attaque à cette jointure. Il en livre aujourd'hui la moitié la plus difficile — **agir sans rien casser** :

- ✅ Changement de profil en une commande ou via un menu interactif
- ✅ Sauvegarde automatique et rollback instantané à chaque opération
- ✅ Validation post-écriture, mode simulation, garde-fou avant d'interrompre WSL2
- ✅ Surveillance RAM WSL2 en arrière-plan avec alertes natives Windows
- ✅ Rapports d'utilisation hebdomadaires générés automatiquement
- ✅ Entièrement extensible via un fichier JSON — aucune modification du code requise

### Ce qui n'est pas encore livré

Le projet est **transparent sur son état réel** : comprendre et expliquer viennent après agir. La commande de diagnostic `wisely diagnose`, la lecture à l'intérieur des distributions et l'attribution de la consommation sont planifiées, pas disponibles. Plusieurs mesures actuelles sont par ailleurs connues comme fausses et corrigées en priorité — voir [`docs/ROADMAP.md`](docs/ROADMAP.md).

La direction du produit, ce qu'il ne deviendra jamais et pourquoi : [`docs/VISION.md`](docs/VISION.md).

---

## Fonctionnalités

| Fonctionnalité               | Description                                                         |
| ---------------------------- | ------------------------------------------------------------------- |
| **Menu interactif**          | Navigation au clavier (flèches + Entrée) — aucun flag à mémoriser   |
| **Profils JSON**             | Définis dans `data/profiles.json`, modifiables sans toucher au code |
| **Backup automatique**       | `.wslconfig` sauvegardé avant chaque switch                         |
| **Rollback instantané**      | Restauration en une commande si quelque chose tourne mal            |
| **Validation post-écriture** | Rollback automatique si `.wslconfig` est invalide après écriture    |
| **Mode dry-run**             | Simule un switch sans aucune écriture système                       |
| **Surveillance RAM**         | Tâche planifiée Windows — fonctionne sans terminal ouvert           |
| **Alertes Toast**            | Notifications Windows natives quand WSL2 dépasse le seuil configuré |
| **Rapports hebdomadaires**   | Générés automatiquement chaque lundi à 09h00                        |
| **Historique complet**       | Toutes les opérations tracées dans `data/history.json`              |
| **Profils personnalisés**    | Création de nouveaux profils depuis la CLI                          |
| **Import / Export**          | Partage et sauvegarde des profils en JSON                           |
| **Alias global**             | `wisely` disponible partout dans le terminal PowerShell         |
| **Nettoyage intégré**        | Purge des fichiers temporaires et anciens rapports                  |

---

## Prérequis

- **Windows 10** (build 19041+) ou **Windows 11**
- **WSL2** installé et configuré (`wsl --install`)
- **PowerShell 5.1** ou supérieur (inclus dans Windows)
- Droits d'exécution de scripts PowerShell pour l'utilisateur courant
- **Droits administrateur** requis pour la commande `Set-ExecutionPolicy` (étape 2 de l'installation) ; dans un environnement d'entreprise, cette politique peut déjà être définie par votre DSI

---

## Installation

```powershell
# 1. Cloner le dépôt
git clone https://github.com/Thurxm09/Wisely.git C:\Scripts\Wisely

# 2. Autoriser l'exécution des scripts locaux (si ce n'est pas déjà fait)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Débloquer les fichiers téléchargés
Get-ChildItem C:\Scripts\Wisely -Recurse -Filter *.ps1 | Unblock-File

# 4. (Recommandé) Ajouter un alias global dans votre profil PowerShell
Add-Content -Path $PROFILE `
  -Value "`nfunction wisely { & 'C:\Scripts\Wisely\wisely.ps1' @args }" `
  -Encoding ASCII
. $PROFILE
```

> **Note :** L'étape 4 vous permet d'appeler `wisely` depuis n'importe quel répertoire sans naviguer jusqu'au dossier d'installation.

---

## Démarrage rapide

```powershell
# Ouvrir le menu interactif (recommandé pour débuter)
wisely

# Basculer directement vers un profil
wisely web

# Simuler un switch sans rien écrire
wisely data -DryRun
```

---

## Référence des commandes

```powershell
# ── Navigation ─────────────────────────────────────────────────────────
wisely                          # Menu interactif (flèches + Entrée)
wisely <profil>                 # Switch direct vers un profil
wisely <profil> -DryRun         # Simulation sans écriture
wisely <profil> -Verbose        # Switch avec diff .wslconfig avant/après

# ── Récupération ───────────────────────────────────────────────────────
wisely -Rollback                # Restaurer le backup précédent
wisely -History                 # Afficher l'historique des opérations

# ── Observation ────────────────────────────────────────────────────────
wisely -Status                  # Dashboard complet (RAM, profil actif, historique)
wisely -Status -Short           # Ligne compacte pour prompt (voir intégration Oh My Posh)
wisely -Snapshot                # Capturer le profil actif courant comme nouveau profil
wisely -Version                 # Afficher la version installée

# ── Surveillance RAM ────────────────────────────────────────────────────
wisely -Monitor start           # Démarrer la surveillance en arrière-plan
wisely -Monitor stop            # Arrêter la surveillance
wisely -Monitor status          # Vérifier l'état du monitoring
wisely -Watch                   # Dashboard temps réel (RAM/CPU vmmem, profil actif, dernière alerte)
wisely -Watch -Interval 5       # Rafraîchi toutes les 5s au lieu de 3s par défaut (Ctrl+C pour quitter)

# ── Lecture in-distro (sous consentement) ───────────────────────────────
wisely -Consent grant           # Autoriser la lecture dans la distribution WSL2 (désactivé par défaut)
wisely -Consent status          # Afficher l'état du consentement
wisely -GuestInfo               # Mémoire de la distribution active : MemAvailable vs Cached

# ── Reporting ───────────────────────────────────────────────────────────
wisely -Report                  # Générer un rapport d'utilisation maintenant

# ── Gestion des profils ─────────────────────────────────────────────────
wisely -NewProfile "clé RAMgo NbCPU [description]"
                                    # Créer un profil personnalisé
wisely -Export                  # Exporter les profils vers un fichier JSON
wisely -Import chemin.json      # Importer des profils depuis un fichier JSON

# ── Maintenance ─────────────────────────────────────────────────────────
wisely -Clean                   # Purger les fichiers temporaires et anciens rapports

# ── Sortie ─────────────────────────────────────────────────────────────
wisely <profil> -Quiet          # Aucune sortie sauf erreurs (scripts/automatisation)
```

---

## Profils par défaut

Les trois profils livrés couvrent les usages les plus courants. Ils sont définis dans [`data/profiles.json`](data/profiles.json) et peuvent être modifiés ou étendus librement.

### Développement web — `web`

```powershell
wisely web
```

Brave + VS Code + WSL léger. Un compromis RAM/réactivité pensé pour du développement web courant sans conteneurs lourds.

| RAM  | CPU | Swap | Couleur |
| ---- | --- | ---- | ------- |
| 4 GB | 3   | 3 GB | Vert    |

### Data Science / ML — `data`

```powershell
wisely data
```

Jupyter + Pandas + ML. Le profil le plus généreux en RAM et en CPU, pour les charges de calcul et les notebooks.

| RAM  | CPU | Swap | Couleur |
| ---- | --- | ---- | ------- |
| 6 GB | 5   | 2 GB | Jaune   |

### Mode minimal — `base`

```powershell
wisely base
```

Empreinte réduite pour conserver un maximum de RAM à l'hôte Windows — utile en visioconférence, sur batterie, ou simplement au repos.

| RAM  | CPU | Swap | Couleur |
| ---- | --- | ---- | ------- |
| 2 GB | 2   | 2 GB | Cyan    |

### Exemple de profil personnalisé

Au-delà des trois profils livrés, `profiles.json` accepte n'importe quelle clé supplémentaire suivant le même schéma :

```json
"gaming": {
  "displayName": "GAMING",
  "description": "Mode gaming haute performance",
  "color": "Magenta",
  "memory": "12GB",
  "processors": 6,
  "swap": "4GB",
  "swapFile": "%TEMP%/wisely-swap.vhdx",
  "swappiness": 10
}
```

Voir [Profils personnalisés](#profils-personnalisés) pour le créer directement en ligne de commande, sans éditer le JSON à la main.

---

## Intégration Oh My Posh / Windows Terminal

Le switch `wisely -Status -Short` retourne une ligne compacte (`[WSL:WEB 4GB]`) sur la sortie standard, pensée pour être injectée dans un prompt sans jamais bloquer sur `-Quiet`. Ajoutez un segment personnalisé à votre configuration [Oh My Posh](https://ohmyposh.dev/) :

```json
{
  "type": "command",
  "style": "plain",
  "foreground": "p:cyan",
  "properties": {
    "shell": "pwsh",
    "command": "pwsh -NoProfile -File C:\\Scripts\\Wisely\\wisely.ps1 -Status -Short"
  }
}
```

Adaptez le chemin `C:\Scripts\Wisely\wisely.ps1` à votre installation. Le segment reste vide (aucune erreur affichée) si aucun profil Wisely n'est actif.

---

## Profils personnalisés

Créez un nouveau profil directement depuis la CLI :

```powershell
# Syntaxe : wisely -NewProfile "clé RAMgo NbCPU [description]"
wisely -NewProfile "gaming 12GB 6 Mode gaming haute performance"
```

- La clé doit être un mot unique (minuscules recommandées) et doit être un identifiant alphanumérique (lettres, chiffres, `_`, `-`)
- La RAM doit suivre le format `<nombre>GB` (ex : `4GB`, `8GB`)
- Le nombre de CPU doit être compris entre 1 et le nombre de processeurs logiques de la machine hôte
- La description est optionnelle

Le profil est immédiatement disponible dans le menu interactif et dans la liste des commandes directes.

---

## Surveillance RAM

Wisely inclut un système de monitoring RAM qui s'exécute en arrière-plan via le Planificateur de tâches Windows, sans nécessiter de terminal ouvert.

> **Note :** Le démarrage et l'arrêt du monitoring requièrent des **droits administrateur** — lancez PowerShell en tant qu'Administrateur pour ces commandes.

```powershell
# Démarrer le monitoring
wisely -Monitor start

# Vérifier l'état
wisely -Monitor status

# Arrêter le monitoring
wisely -Monitor stop
```

**Comportement :**

- Vérifie l'utilisation RAM de WSL2 (via le processus `vmmem`) toutes les 30 secondes
- Envoie une alerte Toast Windows native si la consommation dépasse le seuil configuré (80 % par défaut)
- Système de cooldown intégré : 30 minutes minimum entre deux alertes successives

Le seuil et l'intervalle de vérification sont configurables dans `data/profiles.json` (clé `settings`).

---

## Rapports hebdomadaires

Un rapport d'utilisation est généré automatiquement chaque lundi à 09h00 **heure locale du système** (via le Planificateur de tâches Windows, activé au démarrage du monitoring).

```powershell
# Générer un rapport manuellement
wisely -Report
```

**Contenu du rapport :**

- Répartition des switchs par profil
- Profil dominant de la semaine
- Total de switchs, jour le plus actif, heure de pointe
- Liste des 5 derniers switchs effectués

Les rapports sont sauvegardés dans `data/reports/report_YYYY-MM-DD.txt`. Un maximum de 12 rapports est conservé (rotation automatique). Pour nettoyer manuellement :

```powershell
wisely -Clean
```

---

## Import / Export

Partagez ou sauvegardez vos profils en dehors du dépôt :

```powershell
# Exporter vers un fichier (par défaut : wsl-profiles-export.json)
wisely -Export

# Importer depuis un fichier
wisely -Import C:\Backup\mes-profils.json
```

L'importation crée automatiquement un backup du `.wslconfig` courant avant d'appliquer les nouveaux profils.

> **Attention :** L'importation **remplace entièrement** le fichier `data/profiles.json` existant, y compris les profils personnalisés créés localement. Exportez vos profils actuels avant d'importer un nouveau fichier si vous souhaitez les conserver.

---

## Architecture

```
Wisely/
├── wisely.ps1              ← Point d'entrée unique
├── modules/
│   ├── ProfileManager.ps1      ← Logique profils (apply, backup, rollback, import/export)
│   ├── Logger.ps1              ← Historique JSON
│   ├── Monitor.ps1             ← Contrôle de la tâche planifiée Windows
│   ├── MonitorTask.ps1         ← Script exécuté par le Planificateur de tâches
│   └── WeeklyReport.ps1        ← Génération des rapports hebdomadaires
└── data/
    ├── profiles.json           ← Définition des profils (source de vérité)
    ├── history.json            ← Généré automatiquement (non versionné)
    └── reports/                ← Rapports hebdomadaires (non versionnés)
```

**Principe clé :** `wisely.ps1` est le seul point d'entrée. Les modules ne se connaissent pas entre eux — toute orchestration passe par le script principal.

---

## Configuration avancée

Le fichier `data/profiles.json` centralise l'ensemble de la configuration :

```json
{
  "version": "2.0.0",
  "profiles": {
    "web": {
      "displayName": "WEB",
      "description": "Brave + VS Code + WSL léger",
      "color": "Green",
      "memory": "4GB",
      "processors": 3,
      "swap": "3GB",
      "swapFile": "%TEMP%/wisely-swap.vhdx",
      "swappiness": 10
    }
  },
  "settings": {
    "monitorThreshold": 80,
    "monitorIntervalSeconds": 30,
    "historyMaxEntries": 100,
    "backupEnabled": true,
    "backupHistoryMax": 5
  }
}
```

`swapFile` accepte des placeholders de variables d'environnement Windows, étendus automatiquement à chaque application du profil :

| Placeholder       | Résolu vers                                    |
| ------------------ | ----------------------------------------------- |
| `%TEMP%`           | Dossier temporaire de l'utilisateur courant     |
| `%USERPROFILE%`    | Dossier personnel de l'utilisateur (`C:\Users\...`) |
| `%LOCALAPPDATA%`   | Dossier `AppData\Local` de l'utilisateur        |

Un chemin littéral (ex. `C:/Temp/wsl-swap.vhdx`) reste bien entendu accepté et n'est pas modifié.

| Paramètre `settings`     | Description                                      | Défaut |
| ------------------------ | ------------------------------------------------ | ------ |
| `monitorThreshold`       | Seuil RAM (%) déclenchant une alerte Toast       | `80`   |
| `monitorIntervalSeconds` | Intervalle de vérification RAM (secondes)        | `30`   |
| `historyMaxEntries`      | Nombre maximum d'entrées dans l'historique       | `100`  |
| `backupEnabled`          | Active la sauvegarde automatique de `.wslconfig` | `true` |
| `backupHistoryMax`       | Nombre maximum de backups `.wslconfig` conservés | `5`    |

---

## Licence

Distribué sous licence GNU GENERAL PUBLIC v3.0. Voir [LICENSE](LICENSE) pour le texte complet.
