# 0008 — Lecture dans la distribution, sous contrat

**Statut :** acceptée — contrat écrit, implémentation planifiée v2.6
**Date :** 2026-08-26

## Contexte

Une hypothèse technique implicite structurait tout le projet : **rien ne doit
tourner à l'intérieur de la distribution Linux.** Toute mesure était donc prise
depuis Windows, d'où le recours au processus `vmmem` comme approximation.

Cette contrainte est ce qui condamne Wisely à ne voir qu'une boîte noire. Elle
rend impossibles l'attribution (« quel processus consomme ces gigaoctets ? »), la
distinction entre mémoire utilisée et mémoire en cache, et la vérification qu'un
changement a produit l'effet annoncé.

Constat déterminant : **la contrainte n'était pas technique, mais doctrinale.**
`wsl -d <distro> -- cat /proc/meminfo` s'exécute depuis PowerShell, sans rien
installer. D'autres outils le font déjà.

## Décision

La contrainte est levée, **sous contrat explicite**.

Le contrat est écrit **avant** l'implémentation, dans
`../DOCTRINE-LECTURE.md`. Ses engagements : lecture seule sans exception, aucun
agent ni installation, liste fermée de commandes versionnée, aucun contenu de
fichier ni variable d'environnement ni argument de processus, consentement
explicite et révocable, dégradation propre en cas de refus.

## Alternatives écartées

| Alternative | Écartée parce que |
|---|---|
| Conserver la contrainte | Condamne le produit à la boîte noire, donc à ne jamais tenir sa promesse |
| Agent installé dans la distribution | Empreinte permanente, surface de maintenance, et demande de confiance disproportionnée |
| Lecture sans contrat écrit | Un outil qui entre dans le Linux de quelqu'un sans dire d'avance ce qu'il n'y fera jamais ne mérite pas cette confiance |

## Pourquoi un cycle entier

Le mainteneur a estimé que la question méritait une version à elle seule. C'est
juste : la difficulté n'est pas d'écrire la commande, elle est de mériter le
droit de l'exécuter. Un contrat borné, vérifiable et opt-in est aussi ce qui rend
la capacité acceptable en environnement d'entreprise — donc un différenciateur,
pas seulement une précaution.

## Conséquences

- `../DOCTRINE-LECTURE.md` devient un document contractuel : toute extension de
  portée exige une nouvelle décision et une mention au CHANGELOG.
- La liste de commandes autorisées est une constante unique dans le code, et un
  test Pester vérifie qu'aucune invocation n'existe en dehors.
- Repose sur A4 (`../ASSUMPTIONS.md`), non validée : les utilisateurs acceptent
  cette lecture. Le refus est donc un chemin de première classe, pas un cas
  dégradé.
