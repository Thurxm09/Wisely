#!/usr/bin/env python3
"""Controle de derive doc/code pour Wisely.

Deux controles cibles, pas un scan brut de tout v\\d+\\.\\d+ :

1. Version codee en dur (badge shields.io, banniere "version actuelle/
   courante") comparee au fichier VERSION a la racine du depot. Toute ligne
   qui matche aussi le motif d'etiquette de palier (P0 / v2.5, P2 / v3.0)
   est traitee comme legitime : c'est le garde-fou anti-faux-positif
   principal, sans lui ce controle produirait des dizaines de faux
   positifs sur ROADMAP.md/TASKS.md.
2. Termes retires (liste tenue a la main) recherches par mot entier. Un
   hit avec un mot du champ lexical "retire/renomme/anciennement" a
   proximite est une mention historique legitime.

Perimetre : docs/**/*.md, README.md, README.en.md. Exclusions : docs/
decisions/*.md (les ADR ne se corrigent jamais retroactivement), docs/
audits/*.md et docs/archive/*.md (ne font pas foi).

Volontairement non branche en CI dans cette passe - decision separee a
prendre plus tard. Sortie ASCII pure ligne par ligne, code de sortie 0/1.

Limite connue, non corrigee : la proximite de mot-cle ne detecte que les
formulations qui reutilisent le champ lexical retire/renomme/remplace/
anciennement. Une mention historique tournee autrement (temps a l'imparfait,
"introduits par", entree de changelog au passe) reste un faux [FAIL].
Constate sur ce depot au 2026-09-03 sur trois lignes verifiees manuellement
comme legitimes : docs/AUDIT.md (finding deja marque "Corrige"),
docs/PRINCIPLES.md (paragraphe "Origine :"), docs/TASKS.md (entree "## Done"
au passe). Accepte pour rester un outil a deux controles cibles plutot qu'un
correcteur syntaxique - a affiner seulement si le bruit devient genant.
"""

import argparse
import re
import sys
from pathlib import Path

EXCLUDED_DIRS = ("decisions", "audits", "archive")

# Termes retires du produit. Ajouter ici au fur et a mesure des retraits
# constates - cette liste n'a pas vocation a etre exhaustive d'emblee.
RETIRED_TERMS = ("ramDeltaGB", "wisely doctor")

# Mots dont la proximite d'un terme retire signale une mention historique
# legitime plutot qu'une description perimee du comportement actuel.
LEGITIMATE_CONTEXT_WORDS = (
    "retire",
    "retiree",
    "retirees",
    "retires",
    "renomme",
    "renommee",
    "renommees",
    "renommes",
    "remplace",
    "remplacee",
    "remplacees",
    "remplaces",
    "anciennement",
    "ancien",
    "ancienne",
    "corrige",
    "corrigee",
    "corrigees",
    "corriges",
)

BADGE_RE = re.compile(r"shields\.io/badge/version-([0-9]+\.[0-9]+\.[0-9]+)")
BANNER_RE = re.compile(
    r"(?i)version\s+(?:actuelle|courante)\s*:?\s*v?([0-9]+\.[0-9]+\.[0-9]+)"
)
PALIER_GUARD_RE = re.compile(r"P[0-9]+\s*/\s*v[0-9]+\.[0-9]+")


def strip_accents(text):
    """ASCII-fold for word-context comparisons, not for output.

    Accented characters below are Unicode escapes, not literals, to keep
    this source file itself ASCII-pure (same convention as [char]0xXXXX in
    the project's .ps1 files).
    """
    accented = (
        "\u00e9\u00e8\u00ea\u00eb\u00e0\u00e2\u00ee\u00ef\u00f4\u00f9\u00fb\u00e7"
        "\u00c9\u00c8\u00ca\u00cb\u00c0\u00c2\u00ce\u00cf\u00d4\u00d9\u00db\u00c7"
    )
    folded = "eeeeaaiiouuc" "EEEEAAIIOUUC"
    accent_map = str.maketrans(accented, folded)
    return text.translate(accent_map)


def iter_target_files(root):
    for path in sorted(root.glob("docs/**/*.md")):
        if any(part in EXCLUDED_DIRS for part in path.relative_to(root).parts):
            continue
        yield path
    for name in ("README.md", "README.en.md"):
        candidate = root / name
        if candidate.is_file():
            yield candidate


def check_version_lines(path, lines, expected_version, results):
    for lineno, raw_line in enumerate(lines, start=1):
        if PALIER_GUARD_RE.search(raw_line):
            continue

        badge_match = BADGE_RE.search(raw_line)
        if badge_match:
            found = badge_match.group(1)
            if found == expected_version:
                results.append(("OK", path, lineno, "badge de version " + found + " a jour"))
            else:
                results.append(
                    (
                        "FAIL",
                        path,
                        lineno,
                        "badge de version affiche " + found + " mais VERSION vaut " + expected_version,
                    )
                )

        banner_match = BANNER_RE.search(raw_line)
        if banner_match:
            found = banner_match.group(1)
            if found == expected_version:
                results.append(("OK", path, lineno, "banniere de version " + found + " a jour"))
            else:
                results.append(
                    (
                        "FAIL",
                        path,
                        lineno,
                        "banniere de version affiche " + found + " mais VERSION vaut " + expected_version,
                    )
                )


def check_retired_terms(path, lines, results):
    for lineno, raw_line in enumerate(lines, start=1):
        for term in RETIRED_TERMS:
            if not re.search(r"\b" + re.escape(term) + r"\b", raw_line):
                continue

            folded = strip_accents(raw_line).lower()
            has_legitimate_context = any(word in folded for word in LEGITIMATE_CONTEXT_WORDS)

            if has_legitimate_context:
                results.append(
                    (
                        "SKIP",
                        path,
                        lineno,
                        'terme retire "' + term + '" trouve avec contexte legitime a proximite',
                    )
                )
            else:
                results.append(
                    (
                        "FAIL",
                        path,
                        lineno,
                        'terme retire "' + term + '" trouve sans contexte legitime a proximite',
                    )
                )


def run(root):
    expected_version_path = root / "VERSION"
    if not expected_version_path.is_file():
        print("[FAIL] VERSION introuvable a la racine de " + str(root))
        return 1

    expected_version = expected_version_path.read_text(encoding="utf-8").strip()

    results = []
    for path in iter_target_files(root):
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        rel_path = path.relative_to(root)
        check_version_lines(rel_path, lines, expected_version, results)
        check_retired_terms(rel_path, lines, results)

    for status, path, lineno, detail in results:
        print("[" + status + "] " + str(path) + ":" + str(lineno) + " " + detail)

    ok_count = sum(1 for r in results if r[0] == "OK")
    skip_count = sum(1 for r in results if r[0] == "SKIP")
    fail_count = sum(1 for r in results if r[0] == "FAIL")

    print(
        "Resume : "
        + str(ok_count)
        + " OK, "
        + str(skip_count)
        + " SKIP, "
        + str(fail_count)
        + " FAIL sur "
        + str(len(results))
        + " signal(aux) detecte(s)"
    )

    return 1 if fail_count > 0 else 0


def main():
    parser = argparse.ArgumentParser(description="Controle de derive doc/code pour Wisely")
    parser.add_argument(
        "--root",
        default=".",
        help="Racine du depot a analyser (defaut : repertoire courant)",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    sys.exit(run(root))


if __name__ == "__main__":
    main()
