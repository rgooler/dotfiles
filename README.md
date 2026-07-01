# dotfiles & config management

My collection of my dotfiles used across multiple systems and managed by [chezmoi](https://www.github.com/twpayne/chezmoi).

## Quick Start

```bash
  sh -c "$(curl -fsSL get.chezmoi.io)" -- init --apply rgooler
```

`init` prompts for this machine's **role**, **profiles**, and **git identity**
(see [Roles & profiles](#roles--profiles)).

Secrets are **age-encrypted** in this repo and decrypted at apply time with a single
age key. Nothing calls 1Password on every apply — it's only used once to fetch the key:

- **Machines with 1Password** — the `setup-age-key` script reads the key from
  `op://chezmoi/Chezmoi age key`. Have the
  [1Password CLI](https://developer.1password.com/docs/cli/) installed and unlocked
  (`eval $(op signin)`, or the desktop-app CLI integration).
- **Machines without 1Password** (e.g. Steam Deck) — drop the key in first, then init:

  ```bash
    mkdir -p ~/.config/chezmoi
    install -m600 /path/to/key.txt ~/.config/chezmoi/key.txt
  ```

The private key lives only at `~/.config/chezmoi/key.txt` (never committed); the
recipient (public key) is in `.chezmoi.toml.tmpl`.

## Roles & profiles

Each machine picks a **role** and a set of **profiles** at `chezmoi init` (both prompted):

- **role** — `desktop | work | k8s | nas | server | vm`. Drives derived capabilities
  (GUI apps, personal secrets, homelab/kube access, package manager).
- **profiles** — opt-in package bundles layered on the baseline:
  - `dev` — docker, gh, ripgrep, dev tooling
  - `media` — VLC, Plex, mpv, HandBrake
  - `ctf` — nmap, john, arp-scan, ghidra, CTF stack

### Enable/change a profile on a running machine

Re-run init — the profiles prompt is pre-filled with your current selection; edit it,
then apply:

```bash
  chezmoi init      # e.g. change "dev,media" -> "dev,media,ctf"
  chezmoi apply     # the package script re-runs and installs the new profile
```

Role and git identity are "sticky" (set once). To change them, edit the values in
`~/.config/chezmoi/chezmoi.toml` and re-run `chezmoi apply`.

### Define a NEW profile

1. Add it under `profiles:` in `.chezmoidata/packages.yaml` with `dnf` / `apt` / `brew`
   (+ `casks` / `flatpak`) lists.
2. Add a matching entry to the `$profileDescs` map in `.chezmoi.toml.tmpl` (the init menu
   is hardcoded there — the config template can't read `.chezmoidata`).
3. If any package needs a third-party repo, add the repo to
   `.chezmoiscripts/run_once_before_install-package-managers.sh.tmpl` (dnf **and** apt
   branches). That script is `run_once`; on a machine that already ran it, re-run with
   `chezmoi state delete-bucket --bucket=scriptState` then `chezmoi apply`.

## Tools Used

| Name | Description | Required |
| ---- | ----------- | -------- |
| Package manager | [homebrew](https://brew.sh/) | Yes |
| Shell | [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH) | Yes |
| Zsh theme         | [powerlevel10k](https://github.com/romkatv/powerlevel10k) | Yes |
| Dotfiles manager  | [chezmoi](https://chezmoi.io/) | Yes |
| Password Manager  | [1password](https://www.1password.com/) | Yes |

## Command Reference

To add new files to chezmoi control:
> `chezmoi add <file>`

To edit a file under chezmoi control:
> `chezmoi edit <file>`

To preview changes before applying:
> `chezmoi diff`

To apply changes from `.local/share/chezmoi/` to ~/ use:
> `chezmoi apply`

To both `git pull` and `chezmoi apply` use `update`
> `chezmoi update`

To force a refresh the downloaded archives (from .`chezmoiexternal.toml`), use the --refresh-externals (-R) flag to chezmoi apply:
> `chezmoi -R apply`

To test chezmoi template files (.tmpl):
> `chezmoi execute-template < dot_gitconfig.tmpl`

## Chezmoi and Git

To execute git commands within the chezmoi source director you can append them to the *chezmoi* command

Git pull:
> `chezmoi git pull`

Git push:
> `chezmoi git push`

Git status:
> `chezmoi git status`

## Resources

* [Install](https://www.chezmoi.io/install/)
* [Quick Start](https://www.chezmoi.io/quick-start/#using-chezmoi-across-multiple-machines)
* [Setup](https://www.chezmoi.io/user-guide/setup/)
* [Chezmoi Github](https://github.com/twpayne/chezmoi)
* [Chezmoi Web](https://chezmoi.io)
