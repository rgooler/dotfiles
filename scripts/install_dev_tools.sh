#!/bin/bash -x
set -euo pipefail

# --- Install asdf (v0.18) ---
install_asdf() {
  if ! command -v asdf >/dev/null || ! asdf --version | grep -q "0.18"; then
    echo "Installing asdf (v0.18.x)..."
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
        # Linux: Download precompiled binary from GitHub releases
        mkdir -p ~/bin
        ASDF_VERSION="v0.18.0"
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
          ARCH="amd64"
        fi
        DOWNLOAD_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-${ARCH}.tar.gz"
        echo "Downloading asdf from: $DOWNLOAD_URL"
        curl -L "$DOWNLOAD_URL" | tar -xzv -C ~/bin/
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
  if ! grep -q "asdf shims" "$zshrc"; then
    echo -e "\n# asdf 0.18.x config" >> "$zshrc"
    echo "export ASDF_DATA_DIR=\"$asdf_data_dir\"" >> "$zshrc"
    echo "export PATH=\"\$ASDF_DATA_DIR/shims:\$PATH\"" >> "$zshrc"
  fi

  # Initialize completions for zsh
  mkdir -p "$asdf_data_dir/completions"
  if command -v asdf >/dev/null; then
    asdf completion zsh > "$asdf_data_dir/completions/_asdf" 2>/dev/null || true
    # Add completion path to zsh
    if ! grep -q "asdf completions" "$zshrc"; then
      echo "fpath=(\$ASDF_DATA_DIR/completions \$fpath)" >> "$zshrc"
      echo "autoload -Uz compinit && compinit" >> "$zshrc"
    fi
  fi
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
