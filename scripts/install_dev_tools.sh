#!/usr/bin/env bash
set -euo pipefail

# --- Install git (OS-specific) ---
if ! command -v git >/dev/null; then
  echo "Installing git..."
  case "$(uname -s)" in
    Linux)
      if command -v apt-get >/dev/null; then
        sudo apt-get update && sudo apt-get install -y git  # Ubuntu/Debian
      elif command -v dnf >/dev/null; then
        sudo dnf install -y git  # Fedora
      elif command -v pacman >/dev/null; then
        sudo pacman -Sy git  # Arch
      fi
      ;;
    Darwin)
      xcode-select --install
      ;;
  esac
fi


# --- Install asdf (latest Git version) ---
if ! command -v asdf >/dev/null; then
  echo "Installing asdf..."
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch "$(git ls-remote --tags https://github.com/asdf-vm/asdf.git | grep -o 'refs/tags/v[0-9]*\.[0-9]*\.[0-9]*' | sort -rV | head -n 1 | grep -o '[^/]*$')"
  
  # Add to zshrc (cross-shell compatible)
  grep -qxF '. "$HOME/.asdf/asdf.sh"' ~/.zshrc || echo -e '\n. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
  grep -qxF 'fpath=(${ASDF_DIR}/completions $fpath)' ~/.zshrc || echo -e '\nfpath=(${ASDF_DIR}/completions $fpath)' >> ~/.zshrc
fi

# --- Install direnv (OS-specific) ---
if ! command -v direnv >/dev/null; then
  echo "Installing direnv..."
  case "$(uname -s)" in
    Linux)
      if command -v apt-get >/dev/null; then
        sudo apt-get update && sudo apt-get install -y direnv  # Ubuntu/Debian
      elif command -v dnf >/dev/null; then
        sudo dnf install -y direnv  # Fedora
      elif command -v pacman >/dev/null; then
        sudo pacman -Sy direnv  # Arch
      fi
      ;;
    Darwin)
      brew install direnv  # macOS
      ;;
  esac

  # Add hook to zshrc
  grep -qxF 'eval "$(direnv hook zsh)"' ~/.zshrc || echo -e '\neval "$(direnv hook zsh)"' >> ~/.zshrc
fi

# --- Initialize asdf plugins (optional) ---
if command -v asdf >/dev/null && [ ! -d ~/.asdf/plugins/nodejs ]; then
  asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  # Add other plugins as needed (e.g., python, ruby)
fi
