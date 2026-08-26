# Wisely - Changelog

## v2.4.0 - 2026-08-26

### v2.4 - Garde-fou shutdown & refondation documentaire

- Garde-fou WSL2 actif avant `wsl --shutdown` : `Get-WslActiveSessions` et `Confirm-WslShutdown` dans `ProfileManager.ps1`, avec flag `-Force` pour l'usage script/automatise et `Test-WiselyNonInteractive` pour les sessions sans entree utilisateur
- Refondation de l'architecture documentaire : un document par question - `docs/PROBLEM.md` (le probleme, independamment de toute solution), `docs/VISION.md` (la capacite fondamentale), `docs/PRINCIPLES.md` (les criteres d'arbitrage), `docs/DOCTRINE-LECTURE.md` (contrat de lecture dans la distribution Linux, ecrit avant l'implementation), `docs/ASSUMPTIONS.md` (registre des hypotheses non validees)
- `docs/decisions/` : 12 ADR dates et revisables, remplacant le paragraphe monolithique de decisions strategiques de l'ancien ROADMAP
- `docs/ROADMAP.md` reduit a son seul metier (les versions et leur ordre) ; positionnement, principes et decisions deplaces dans les documents dedies
- **Spike Terminal.Gui annule** (et non reporte) : aucun probleme utilisateur adosse, justifie par un document lui-meme perime - voir `docs/decisions/0007-annulation-spike-terminal-gui.md`
- Suppression de `docs/wisely.md` (instantane fige redondant) et du guide TUIStudio (perime) ; l'expose technologique est archive dans `docs/archive/` avec un avertissement
- `docs/refondation-wisely.html` : document de travail de l'analyse strategique (six directions comparees, cartographie du probleme, etat de l'art verifie, roadmap reclassee, hypotheses a valider), conserve comme trace du raisonnement
- `docs/glossary.md`, `docs/CLAUDE.md` et le skill `wisely-conventions` resynchronises sur la nouvelle structure

> Aucun changement de code de production dans la partie documentaire de cette version.

## v2.3.0 - 2026-08-25

### v2.3 - Observabilite

- Suite de tests Pester pour Monitor.ps1, MonitorTask.ps1, WeeklyReport.ps1 (dette technique prealable)
- Metriques reelles post-switch : RAM liberee/consommee (Get-AvailableRamGB) et temps de redemarrage WSL2
- Rapports hebdomadaires enrichis avec la RAM moyenne liberee/consommee par profil au switch
- wisely -Watch : dashboard temps reel (RAM/CPU vmmem, profil actif, derniere alerte)
- Audit general (whole-repo) : 15 constats corriges, 5 reportes au backlog
- Semgrep integre a la CI (scan --config=auto + p/secrets + p/github-actions, sur push/PR et hebdomadaire) en complement de CodeQL
- Actions GitHub epinglees par SHA, injections shell corrigees dans les workflows


## v2.2.0 - 2026-08-21

### v2.2 - DX & Documentation

- Chemins swapFile resolus via variables d'environnement (%TEMP%, %USERPROFILE%, %LOCALAPPDATA%)
- Integrite des reglages : historyMaxEntries, backupEnabled, fix du fallback monitorIntervalSeconds
- Validation JSON Schema de profiles.json en CI (schemas/profiles.schema.json)
- Commande wisely -Status -Short pour l'integration prompt (Oh My Posh, Windows Terminal)
- Commande wisely -Snapshot pour capturer l'etat courant en nouveau profil
- CONTRIBUTING.md et templates d'issue/PR
- README : galerie de profils par usage + snippet Oh My Posh
- Housekeeping : badge de version, doc a jour


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
