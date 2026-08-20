# Wisely - Changelog

## v2.1.0 - 2026-08-20

### v2.1 - Polish & Fiabilite

- Suite de tests Pester (tests/), integree a la CI - dette technique prioritaire du ROADMAP resolue
- Validation du chemin du swap file avant ecriture dans .wslconfig
- Backup versionne avec historique glissant (data/backups/, settings.backupHistoryMax, defaut 5)
- Cache memoise pour Get-ProfileConfig (Clear-ProfileConfigCache)
- Flags -Verbose (diff .wslconfig avant/apres switch) et -Quiet
- Fix du bug de troncature de la barre RAM dans wisely -Status


## v2.0.0 - 2026-03-18

### Architecture
- Refactoring complet : script monolithique -> structure modulaire 5 fichiers
- Profils externalises dans data/profiles.json (plus de code a modifier)
- Separation claire : logique metier / interface / monitoring / reporting

### Phase 1 - Foundation
- Menu interactif a navigation clavier (fleches + Entree)
- Backup automatique de .wslconfig avant chaque switch
- Rollback instantane via wisely -Rollback
- Validation post-ecriture avec rollback automatique si .wslconfig invalide
- Historique complet des operations dans data/history.json
- Mode simulation -DryRun sans ecriture systeme
- Creation de profils personnalises via CLI
- Import / export des profils en JSON

### Phase 2 - Monitoring RAM
- Surveillance RAM WSL2 via tache planifiee Windows (sans terminal ouvert)
- Detection du process vmmem comme proxy de la consommation WSL2
- Alertes Toast Windows natives via API Windows Runtime
- Systeme de cooldown (30 min entre deux alertes)
- Commandes : -Monitor start|stop|status

### Phase 3 - Reporting
- Rapport hebdomadaire automatique chaque lundi a 09h00
- Generation manuelle via wisely -Report
- Contenu : repartition par profil, profil dominant, heure de pointe, derniers switchs
- Sauvegarde dans data/reports/report_YYYY-MM-DD.txt
- Rotation automatique : 12 rapports maximum conserves

### Ameliorations transversales
- Alias global PowerShell wisely (disponible partout sans cd)
- Validation du JSON profiles.json au demarrage avec messages d'erreur actionnables
- Commande wisely -Clean pour purger les fichiers temporaires

---

## v1.0 - Initial

- Switch entre profils WEB (2GB) et DATA SCIENCE (6GB)
- Affichage du profil actif et de la RAM Windows
- Aide utilisateur basique
