#!/usr/bin/env bash
set -euo pipefail

# =========================
# Oh My Zsh + P10k 一键安装
# 支持: Ubuntu/Debian, CentOS/RHEL/Fedora, Arch, macOS
# =========================

echo "==> Detecting OS and package manager..."
OS="unknown"; PM=""; SUDO="sudo"
if [[ "$EUID" -eq 0 ]]; then SUDO=""; fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  OS="macos"; PM="brew"
elif [[ -f /etc/os-release ]]; then
  . /etc/os-release
  case "${ID_LIKE:-$ID}" in
    *debian*|*ubuntu*) OS="debian"; PM="apt";;
    *rhel*|*centos*|*fedora*) OS="rhel"; PM="$(command -v dnf >/dev/null 2>&1 && echo dnf || echo yum)";;
    *arch*) OS="arch"; PM="pacman";;
  esac
fi

if [[ "$OS" == "unknown" ]]; then
  echo "Unsupported OS. Exiting."; exit 1
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }
install_pkgs() {
  case "$PM" in
    apt)
      $SUDO apt-get update -y
      $SUDO apt-get install -y zsh curl git fontconfig locales
      ;;
    dnf|yum)
      $SUDO $PM -y install zsh curl git fontconfig
      ;;
    pacman)
      $SUDO pacman -Sy --noconfirm zsh curl git fontconfig
      ;;
    brew)
      brew update || true
      brew install zsh git
      ;;
  esac
}

echo "==> Installing base packages (zsh, git, curl, fontconfig)..."
install_pkgs

# Ensure locale (avoid weird glyph issues)
if [[ "$OS" != "macos" ]] && ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
  echo "==> Generating en_US.UTF-8 locale (if needed)..."
  if [[ -f /etc/locale.gen ]]; then
    $SUDO sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen || true
    $SUDO locale-gen || true
  fi
fi

# Install Oh My Zsh (unattended)
if [[ ! -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
  echo "==> Installing Oh My Zsh (unattended)..."
  export RUNZSH=no
  export CHSH=no
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "==> Oh My Zsh already installed. Skipping."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install Powerlevel10k
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  echo "==> Installing Powerlevel10k theme..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Install plugins
echo "==> Installing plugins (autosuggestions, syntax-highlighting, completions)..."
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ -d "$ZSH_CUSTOM/plugins/zsh-completions" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"

# Install MesloLGS Nerd Font (server-safe; will just place in ~/.local/share/fonts)
FONT_DIR="$HOME/.local/share/fonts"
MESLO_TAG="MesloLGS NF"
if ! fc-list | grep -qi "MesloLGS NF"; then
  echo "==> Installing MesloLGS Nerd Fonts locally..."
  mkdir -p "$FONT_DIR"
  for f in Regular Bold Italic "Bold Italic"; do
    url_name=$(echo "MesloLGS NF ${f}.ttf" | sed 's/ /%20/g')
    curl -fsSL -o "$FONT_DIR/MesloLGS NF ${f}.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/${url_name}"
  done
  fc-cache -f "$FONT_DIR" || true
else
  echo "==> MesloLGS Nerd Fonts already present. Skipping."
fi

ZSHRC="$HOME/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
  echo "==> Creating ~/.zshrc ..."
  touch "$ZSHRC"
fi

# Backup once
if [[ ! -f "$ZSHRC.bak_omz_p10k" ]]; then
  cp "$ZSHRC" "$ZSHRC.bak_omz_p10k"
fi

# Ensure theme = powerlevel10k
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i.bak 's#^ZSH_THEME=.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' "$ZSHRC"
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
fi

# Ensure plugins list contains ours
ensure_plugin() {
  local name="$1"
  if grep -q '^plugins=' "$ZSHRC"; then
    if ! grep -q "$name" "$ZSHRC"; then
      sed -i.bak "s/^plugins=(\(.*\))/plugins=(\1 $name)/" "$ZSHRC"
    fi
  else
    echo "plugins=($name)" >> "$ZSHRC"
  fi
}
ensure_plugin git
ensure_plugin zsh-autosuggestions
ensure_plugin zsh-syntax-highlighting
ensure_plugin zsh-completions

# zsh-completions needs fpath & compinit; syntax-highlighting should be sourced last
if ! grep -q "zsh-completions/src" "$ZSHRC"; then
  cat >>"$ZSHRC" <<'EOF'

# === extra settings for completions & highlighting ===
fpath=($ZSH_CUSTOM/plugins/zsh-completions/src $fpath)
autoload -U compinit && compinit

# place syntax-highlighting at the end
source $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# autosuggestions config (optional tweak)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
EOF
fi

# Optional: speed up compinit by caching
if ! grep -q "compinit -C" "$ZSHRC"; then
  sed -i.bak 's/compinit$/compinit -C/' "$ZSHRC" || true
fi

# Change default shell to zsh
ZSH_PATH="$(command -v zsh)"
if [[ -n "$ZSH_PATH" ]] && [[ "$SHELL" != "$ZSH_PATH" ]]; then
  echo "==> Changing default shell to: $ZSH_PATH"
  if chsh -s "$ZSH_PATH" >/dev/null 2>&1; then
    echo "Default shell changed to zsh."
  else
    echo "WARNING: Failed to change shell automatically. You can run: chsh -s $(which zsh)"
  fi
fi

# Prepare a minimal p10k config if none exists (optional)
P10K="$HOME/.p10k.zsh"
if [[ ! -f "$P10K" ]]; then
  cat >"$P10K" <<'EOF'
# Minimal Powerlevel10k for first run; you can re-run `p10k configure` anytime.
# This keeps prompt fast and clean on servers.
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
[[ -r "$HOME/.p10k.local.zsh" ]] && source "$HOME/.p10k.local.zsh"
EOF
  # ensure it gets sourced
  if ! grep -q '\.p10k\.zsh' "$ZSHRC"; then
    echo '[[ -r "~/.p10k.zsh" ]] && source ~/.p10k.zsh' >> "$ZSHRC"
  fi
fi

echo "==> All set. Reloading zsh and launching p10k configure..."
# Launch new interactive zsh with p10k configure (user can exit if headless)
exec zsh -i -c 'source ~/.zshrc; echo "Starting p10k configure..."; p10k configure || true; exec zsh'
echo "=============================="
echo "Installation complete! Entering p10k configuration."
echo "=============================="
