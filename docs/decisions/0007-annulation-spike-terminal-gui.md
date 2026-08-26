# 0007 — Annulation du spike Terminal.Gui

**Statut :** acceptée
**Date :** 2026-08-26

## Contexte

Le cycle v2.4 comportait deux items : le garde-fou WSL2 avant shutdown (livré) et
un spike expérimental Terminal.Gui — script d'installation du DLL NuGet,
prototype de menu derrière un drapeau de fonctionnalité, évaluation UX puis ADR
Go/No-go.

Le spike était la dernière tâche « Active » de `../TASKS.md`.

## Décision

**Annulé.** Pas reporté : retiré.

## Motifs

**Aucun problème utilisateur adossé.** Le menu interactif actuel fonctionne et
n'a fait l'objet d'aucune plainte — d'autant qu'il n'y a aucun utilisateur pour
se plaindre. Le spike répond à une curiosité technique, pas à un besoin
documenté. Il échoue au principe 6 (`../PRINCIPLES.md`).

**Justifié par un document périmé.** Sa source normative,
`Wisely — État des lieux & Guide d'intégration TUIStudio.md`, portait en tête un
avertissement « document historique — périmé » tout en restant la référence de la
tâche. Un document qu'on garde uniquement pour la section qui alimente une tâche
qu'on ne fait pas est une dette documentaire.

**Ne s'exprime pas comme une opération sur l'écart** (`../VISION.md`). Le test est
sans ambiguïté ici.

**Coût réel non nul.** L'évaluation portait sur 2 à 4 semaines, et le risque
principal identifié à l'époque — la fragmentation de la maintenance entre deux
moteurs de rendu — reste entier.

## Conséquences

- Le document TUIStudio est supprimé du dépôt (son historique Git le conserve).
- Le cycle v2.4 se clôt sur son seul item livré, plus la refondation
  documentaire.
- Si la question du rendu terminal se repose un jour, elle devra venir d'un
  besoin utilisateur constaté, pas d'un document de 2026.
