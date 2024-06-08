# dotfiles & config management

My collection of my dotfiles used across multiple systems and managed by [chezmoi](https://www.github.com/twpayne/chezmoi).

## Quick Start

```bash
  sh -c "$(curl -fsSL get.chezmoi.io)" -- init --apply rgooler
```

Personal secrets are stored in [1Password](https://1password.com) and you'll
need the [1Password CLI](https://developer.1password.com/docs/cli/) installed.

After installation or major changes you may need to relogin to 1Password with:

```bash
  eval $(op signin)
```

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
