# Repository notes for agents

A [chezmoi](https://chezmoi.io) dotfiles repo. Secrets are **age-encrypted**; machine
differences are driven by a **role + profiles** model. Read this before editing.

## Machine model (`.chezmoi.toml.tmpl`)

- One `role` per machine, **prompted** at `chezmoi init`: `desktop | work | k8s | nas | server | vm`.
- Gate templates on the derived **capability**, never on the role name:
  - `gui`     — desktop, work
  - `trust`   — `work` on work, `none` on vm, else `personal`
  - `homelab` — desktop, k8s, nas
  - plus `ephemeral`, `headless`, and `pkgmgr` (`brew` | `dnf` | `apt`)
- `profiles` — opt-in package bundles, **prompted** at init (currently `dev`, `media`, `ctf`).
- Nothing is keyed off hostnames. **No machine names or personal identifiers belong in the repo.**

## ⚠️ Keep the profile menu in sync

The `chezmoi init` profile prompt shows a menu built from a **hardcoded** `$profileDescs`
map in `.chezmoi.toml.tmpl`. The config template **cannot read `.chezmoidata`**, so this map
is a manual duplicate of `packages.yaml`. **Whenever you add / remove / rename a profile in
`.chezmoidata/packages.yaml` (`profiles:`), update `$profileDescs` in `.chezmoi.toml.tmpl` to
match.**

## Packages (`.chezmoidata/packages.yaml`)

- Install order: `baseline.all` (every machine) → `baseline.gui` (if `.gui`) → each enabled `profiles.<p>`.
- Per-manager lists: `dnf` / `apt` / `brew` (+ `casks`, `flatpak`).
- Third-party repos (gh, docker, vscode, tailscale, mise, charm) are configured in
  `.chezmoiscripts/run_once_before_install-package-managers.sh.tmpl`, keyed to `.gui` / profiles.
  If you add a package that needs a repo, add the repo there too (dnf and apt branches).

## Scripts (`.chezmoiscripts/`, 2 + bootstrap)

- `run_once_before_setup-age-key` — writes `~/.config/chezmoi/key.txt` from
  `op://chezmoi/Chezmoi age key/credential` (or manual on machines without 1Password).
- `run_once_before_install-package-managers` — package managers + repos, dispatch by `pkgmgr`.
- `run_onchange_after_install-packages` — installs packages by `pkgmgr`, then `mise install`.

## Secrets — age encryption

- chezmoi-native age, one key. Private key at `~/.config/chezmoi/key.txt` (never committed);
  recipient (public key) is in `.chezmoi.toml.tmpl`.
- Add a new secret with **`chezmoi add --encrypt <file>`** → stored as `encrypted_*.age`.
  Never commit a plaintext secret or a `onepasswordRead` of identity data.
- Encrypted files are gated in `.chezmoiignore` on `not .personal` (a `vm` has no key).
- Git identity: default is **prompted** (`gitname`/`gitemail`); per-remote overrides live in the
  age-encrypted `~/.config/git/overrides` + `id-*` files (patterns and identities stay private).

## Privacy rule

This repo is public. Do **not** commit real names, emails, machine names, or private
hostnames. Before committing, sanity-check:
`git grep -iE 'realname|your@email|private-hostnames' -- . ':(exclude)*.age'`
