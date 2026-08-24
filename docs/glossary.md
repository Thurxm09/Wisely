# Glossaire — Wisely

| Terme | Signification |
|-------|---------------|
| Wisely | Nom du projet — outil CLI PowerShell de gestion de profils de ressources WSL2 |
| `.wslconfig` | Fichier de configuration WSL2 (chemin utilisateur : `C:\Users\othur\.wslconfig`) |
| `profiles.json` | Source de vérité externe listant les profils de ressources (web, data science, minimal) |
| `vmmem` | Processus Windows utilisé comme heuristique de mesure de la RAM consommée par WSL2 |
| `Get-ProfileConfig` | Fonction de lecture/parsing de `profiles.json` — cible prioritaire des tests Pester et de la mémoïsation |
| `Import-Profiles` | Fonction d'import de profils — deuxième cible prioritaire des tests Pester |
| `Clear-ProfileConfigCache` | Fonction d'invalidation du cache mémoïsé, appelée après `Set-WslProfile`, `Import-Profiles`, `New-CustomProfile` |
| PS5.1 / PS7 | Deux versions de PowerShell avec des chemins `$PROFILE` distincts (`Documents\WindowsPowerShell\` vs `Documents\PowerShell\`) — alias `wisely` résolu par symlink |
| AUDIT.md | Document de suivi des constats d'audit qualité du projet |
| ROADMAP.md | Document de vision stratégique long terme du projet |
| `ramDeltaGB` | Champ de `history.json` (v2.3) — delta de RAM Windows disponible mesuré au moment du switch (positif = libérée, négatif = consommée), journalisé par `Write-SwitchLog` |
| `restartSeconds` | Champ de `history.json` (v2.3) — temps mesuré de l'arrêt WSL2 (`wsl --shutdown` + stabilisation) lors d'un switch |
| `wisely -Watch` | Dashboard temps réel (v2.3) : RAM/CPU `vmmem`, profil actif, dernière alerte, rafraîchi toutes les `-Interval` secondes |
| `Get-WatchSnapshot` / `Get-VmmemStats` | Fonctions de `Monitor.ps1` alimentant `wisely -Watch` — collecte de données pure et testable, séparée de la boucle d'affichage |
| `Test-IsAdminUser` | Fonction de `Monitor.ps1` factorisant le check de droits administrateur entre `Start-WslMonitor` et `Stop-WslMonitor` |
