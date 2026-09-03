# Wisely — WSL2 Resource Intelligence & Control

> **Understand WSL. Act with confidence.**
>
> Wisely turns the real state of your WSL2 resources into explainable decisions and safe
> actions. Every number it prints carries its scope, its measurement class and its confidence
> level — because a figure whose meaning you don't know is worse than no figure at all.

![Version](https://img.shields.io/badge/version-3.0.0-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D4?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/License-GPL--v3-blue)

🌐 [wisely-site-beta.vercel.app](https://wisely-site-beta.vercel.app) · 🇫🇷 [Documentation complète en français](README.md)

> **This is a short quickstart, not a translation.** The full documentation — architecture,
> product rationale, decision records, resource model — lives in French in [`README.md`](README.md)
> and [`docs/`](docs/). Keeping two complete READMEs in sync is a promise this project would
> break within a month, so it isn't made.

---

## Wisely is looking for testers

Nobody except its maintainer has used this tool yet. That is the single most important gap in
the project right now, and it is the one we are trying to close — not by writing more
documentation, but by putting the tool in front of people who can tell us where it is wrong.

**"I didn't understand the output" is more useful to us than "looks great".** If you run WSL2
on Windows, five minutes of your time is worth more than any internal audit we could run.

---

## Try it without installing anything

`wisely -Diagnose` — and its `-Explain` / `-History` variants — is **entirely read-only**. It
never touches your `.wslconfig`, writes nothing to disk, registers no scheduled task, and
requires no permanent installation. You can delete the folder afterwards and nothing remains.

```powershell
git clone https://github.com/Thurxm09/Wisely.git
cd Wisely
pwsh ./wisely.ps1 -Diagnose
```

**Requirements:** Windows 10 (build 19041+) or Windows 11 · WSL2 installed · PowerShell 5.1 or
later. Nothing else.

### What it answers, in this order

1. **What is happening?** — `.wslconfig` validity, `autoMemoryReclaim` state, `sparseVhd`,
   running distributions, VHDX size.
2. **Why?** — the RAM ceiling from `.wslconfig`, expressed as a share of host RAM.
3. **Is it dangerous?** — memory attribution per process, with its **explicit unattributed
   remainder**.
4. **What can I do?** — and, just as often, why nothing you could change would help.

Every line is tagged `[scope / measurement class / confidence]`. That is deliberate: summing
RSS inside a distro double-counts shared pages, so it is never presented as "the RAM WSL2 uses".
The reasoning behind each figure is in [`docs/RESOURCE-MODEL.md`](docs/RESOURCE-MODEL.md).

### Going a little further

```powershell
pwsh ./wisely.ps1 -Diagnose -Explain autoMemoryReclaim   # explain any .wslconfig key
pwsh ./wisely.ps1 -Diagnose -History                     # switch history, attributable or discarded
pwsh ./wisely.ps1 -Consent status                        # in-distro reading is OFF by default
```

Reading **inside** your Linux distributions is disabled until you explicitly allow it
(`-Consent grant`, revocable at any time). The closed list of commands Wisely is ever allowed
to run in a guest is documented in [`docs/DOCTRINE-LECTURE.md`](docs/DOCTRINE-LECTURE.md) and
enforced by a test. There is **no telemetry**, opt-in or otherwise, and none is planned.

---

## Telling us what happened

| You want to… | Where | Time |
| --- | --- | --- |
| Flag something in two clicks | [Quick feedback](https://github.com/Thurxm09/Wisely/issues/new?template=field-test.yml) — one required field | 30 s |
| Describe what happened in detail | [Detailed feedback](https://github.com/Thurxm09/Wisely/issues/new?template=field-test-detailed.yml) | 5 min |
| Report a security problem | [Private report](https://github.com/Thurxm09/Wisely/security/advisories/new) — **never a public issue** | — |

Feedback in English or French is equally welcome.

### Redact before you paste

The diagnostic output contains your distribution names and guest process names. Those often
carry a client, project or employer name. **Never paste raw output into a public issue.**

```powershell
pwsh ./wisely.ps1 -Diagnose -Redact          # pseudonymises names, keeps every number
pwsh ./wisely.ps1 -Diagnose -Redact -Json    # same, structured output
```

`-Redact` replaces distribution and process names with stable pseudonyms (`distro-1`, `proc-1`,
…) and preserves all figures, units, scopes, measurement classes and confidence levels — that
is, everything that makes a report useful. Read it over before pasting: `-Redact` covers the
fields Wisely knows about, not what you type into a free-text box yourself.

Full list of what must never be published: [`SECURITY.md`](SECURITY.md).

---

## What Wisely does not do yet

Being straight about this is cheaper than disappointing you later.

- **No consumption history.** Wisely reads the current state; it does not yet know what your
  machine did last week. Planned (P4).
- **No sized recommendation.** It will not tell you "set 6 GB" until it can prove the number
  from a measurement. That is a deliberate constraint, not a missing feature.
- **No disk reclamation.** It explains the gap between logical usage and VHDX size; it does not
  compact anything. `Optimize-VHD` is factually broken on sparse VHDs
  ([ADR 0010](docs/decisions/0010-retrait-reclaim-optimize-vhd.md)).
- **Not distributed via PowerShell Gallery or Winget.** Packaging comes after the product is
  proven useful, not before ([ADR 0009](docs/decisions/0009-distribution-apres-le-produit.md)).

The full roadmap, and the reasoning behind its ordering, is in [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Full installation

Only needed if you want profile switching, background monitoring and the global `wisely` alias.
See [`README.md`](README.md#installation) — the diagnostic above needs none of it.

## License

GPL-3.0. See [`LICENSE`](LICENSE).
