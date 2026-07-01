# CLAUDE.md

See **[AGENTS.md](AGENTS.md)** for how this repo works: the machine role/profiles model,
age-encrypted secrets, the install scripts, and the privacy rule.

Most-forgotten item: the `chezmoi init` profile menu is a **hardcoded map** in
`.chezmoi.toml.tmpl` (`$profileDescs`) that must be kept in sync with the `profiles:` in
`.chezmoidata/packages.yaml`. Update both together.
