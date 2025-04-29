#!/bin/bash -x
set -euo pipefail

# --- Install asdf (latest binary) ---
install_asdf() {
  if ! command -v asdf >/dev/null || ! asdf --version | grep -q "0.16"; then
    echo "Installing asdf (v0.16.x)..."
    case "$(uname -s)" in
      Darwin)
        # macOS: Use Homebrew (recommended)
        if ! command -v brew >/dev/null; then
          echo "Homebrew not found. Installing..."
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install asdf
        ;;
      Linux)
        # Linux: Download precompiled binary
        LATEST_ASDF=$(curl -s https://api.github.com/repos/asdf-vm/asdf/releases/latest | grep 'browser_download_url.*linux' | fgrep 'amd64.tar.gz' |fgrep -v '.tar.gz.' | cut -d '"' -f 4)
        curl -L "$LATEST_ASDF" | tar -xzv -C ~/bin/
        chmod +x ~/bin/asdf
        ;;
    esac
  fi
}

# --- Configure asdf for Zsh ---
configure_asdf() {
  local zshrc=~/.zshrc
  local asdf_data_dir="${ASDF_DATA_DIR:-$HOME/.asdf}"

  # Add asdf to PATH and set ASDF_DATA_DIR
  if ! grep -q "asdf.sh" "$zshrc"; then
    echo -e "\n# asdf 0.16.x config" >> "$zshrc"
    echo "export ASDF_DATA_DIR=\"$asdf_data_dir\"" >> "$zshrc"
    echo "export PATH=\"\$ASDF_DATA_DIR/shims:\$PATH\"" >> "$zshrc"
    echo ". \"\$ASDF_DATA_DIR/asdf.sh\"" >> "$zshrc"
  fi

  # Initialize completions
  mkdir -p "$asdf_data_dir/completions"
  asdf completion zsh > "$asdf_data_dir/completions/_asdf"
}

# --- Install direnv (OS-specific) ---
install_direnv() {
  if ! command -v direnv >/dev/null; then
    case "$(uname -s)" in
      Darwin) brew install direnv ;;
      Linux)
        if command -v apt-get >/dev/null; then
          sudo apt-get install -y direnv  # Ubuntu/Debian
        elif command -v dnf >/dev/null; then
          sudo dnf install -y direnv      # Fedora
        fi
        ;;
    esac
    # Add direnv hook to Zsh
    grep -qxF 'eval "$(direnv hook zsh)"' ~/.zshrc || echo -e '\neval "$(direnv hook zsh)"' >> ~/.zshrc
  fi
}

# --- Main ---
install_asdf
configure_asdf
install_direnv

echo "Done! Restart your shell or run: exec zsh"
