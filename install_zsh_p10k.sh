#!/usr/bin/env bash
# p10k_install.sh
# 修复版：正确重写 .zshrc 顺序，确保 p10k configure 可用
set -euo pipefail

# --- 0. 辅助函数 ---
log()  { printf "\033[1;32m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[WARN] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[ERR ] %s\033[0m\n" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || { err "缺少依赖：$1（请先安装或加入 PATH）"; exit 1; }; }

# --- 1. 依赖检测 ---
need git
if ! have curl && ! have wget; then err "需要 curl 或 wget"; exit 1; fi
# 简单的下载包装器
fetch() { if have curl; then curl -fsSL "$1" -o "$2"; else wget -qO "$2" "$1"; fi; }

ZSH_BIN="$(command -v zsh || true)"
[[ -n "$ZSH_BIN" ]] || { err "未检测到 zsh，请先安装 zsh"; exit 1; }
log "检测到 zsh: $ZSH_BIN"

# --- 2. 安装 Oh My Zsh ---
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
  log "安装 Oh My Zsh..."
  # RUNZSH=no: 不立即进入 zsh
  # CHSH=no: 不自动 chsh (避免脚本中断，用户可手动更改)
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "已存在 Oh My Zsh，跳过安装。"
fi

# --- 3. 下载/更新主题与插件 ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"
mkdir -p "$ZSH_CUSTOM"/{themes,plugins}

clone_or_pull () {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    log "更新: $(basename "$dest")"
    (cd "$dest" && git pull --ff-only >/dev/null || true)
  elif [[ ! -d "$dest" ]]; then
    log "安装: $(basename "$dest")"
    git clone --depth=1 "$url" "$dest"
  fi
}

clone_or_pull https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_pull https://github.com/zsh-users/zsh-completions \
  "$ZSH_CUSTOM/plugins/zsh-completions"

# --- 4. 生成标准化的 .zshrc ---
ZRC="$HOME/.zshrc"

# 备份旧配置
if [[ -f "$ZRC" ]]; then
  BACKUP_NAME="${ZRC}.bak_$(date +%Y%m%d_%H%M%S)"
  cp -f "$ZRC" "$BACKUP_NAME"
  log "旧配置已备份至: $BACKUP_NAME"
fi

log "正在生成新的 .zshrc (确保加载顺序正确)..."

# 写入新配置 (使用覆盖模式 > )
cat > "$ZRC" <<'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Define plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)

# Custom folder settings
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

# Add zsh-completions to fpath before OMZ sources it
fpath=($ZSH_CUSTOM/plugins/zsh-completions/src $fpath)

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# --- 5. 确保 .p10k.zsh 存在 (防报错) ---
P10K="$HOME/.p10k.zsh"
if [[ ! -f "$P10K" ]]; then
  log "创建临时 p10k 配置文件..."
  cat > "$P10K" <<'EOF'
# Temporary p10k config
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status time)
EOF
fi

# --- 6. 启动并进入配置 ---
echo
echo "==============================================="
echo "  安装完成！"
echo "  即将进入 Zsh 并自动运行 p10k configure..."
echo "==============================================="
echo

# 使用 exec 替换当前 shell，加载新配置并运行向导
exec "$ZSH_BIN" -i -c 'source ~/.zshrc; p10k configure'