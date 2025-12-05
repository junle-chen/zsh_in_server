#!/usr/bin/env bash
# p10k_full_setup.sh
# 功能：安装字体 + 修复 P10k + 迁移旧配置
set -euo pipefail

# --- 0. 辅助函数 ---
log()  { printf "\033[1;32m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[WARN] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[ERR ] %s\033[0m\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || { err "缺少依赖：$1"; exit 1; }; }
fetch() { if have curl; then curl -fsSL "$1" -o "$2"; else wget -qO "$2" "$1"; fi; }

# --- 1. 基础环境检测 ---
need git
ZSH_BIN="$(command -v zsh || true)"
[[ -n "$ZSH_BIN" ]] || { err "请先安装 zsh"; exit 1; }

# --- 2. 字体自动安装 (新增功能) ---
install_font() {
  log "正在检测/安装 MesloLGS NF 字体..."
  local font_url="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  local font_name="MesloLGS NF Regular.ttf"
  local font_dir=""
  local os_type="$(uname)"

  if [[ "$os_type" == "Darwin" ]]; then
    font_dir="$HOME/Library/Fonts"
  elif [[ "$os_type" == "Linux" ]]; then
    font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
  else
    warn "未知系统，跳过字体下载。请手动下载 MesloLGS NF 字体。"
    return
  fi

  if [[ -f "$font_dir/$font_name" ]]; then
    log "字体已存在，跳过下载。"
  else
    log "正在下载字体到 $font_dir ..."
    fetch "$font_url" "$font_dir/$font_name"
    
    if [[ "$os_type" == "Linux" ]]; then
      if have fc-cache; then
        log "刷新字体缓存..."
        fc-cache -fv "$font_dir" >/dev/null
      else
        warn "未找到 fc-cache 命令，可能需要重启终端才能识别新字体。"
      fi
    fi
    log "字体安装成功！"
  fi
}

# 执行字体安装
install_font

# --- 3. 安装/检测 Oh My Zsh ---
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
  log "安装 Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# --- 4. 更新插件与主题 ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"
mkdir -p "$ZSH_CUSTOM"/{themes,plugins}

clone_or_pull() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    (cd "$dest" && git pull --ff-only >/dev/null || true)
  elif [[ ! -d "$dest" ]]; then
    git clone --depth=1 "$url" "$dest"
  fi
}

log "更新 Powerlevel10k 与插件..."
clone_or_pull https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_pull https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"

# --- 5. 智能重写 .zshrc ---
ZRC="$HOME/.zshrc"
BACKUP_NAME=""

if [[ -f "$ZRC" ]]; then
  BACKUP_NAME="${ZRC}.bak_$(date +%Y%m%d_%H%M%S)"
  cp -f "$ZRC" "$BACKUP_NAME"
  log "原配置已备份至: $BACKUP_NAME"
fi

log "正在生成新配置并迁移旧设置..."

cat > "$ZRC" <<'EOF'
# --- Powerlevel10k & OMZ 核心配置 ---
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git zsh-autosuggestions zsh-completions zsh-syntax-highlighting)

ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
fpath=($ZSH_CUSTOM/plugins/zsh-completions/src $fpath)

source "$ZSH/oh-my-zsh.sh"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# --- 核心配置结束 ---

EOF

if [[ -n "$BACKUP_NAME" ]]; then
  echo "" >> "$ZRC"
  echo "# ==================================================" >> "$ZRC"
  echo "# [User Config] 迁移的旧配置" >> "$ZRC"
  echo "# ==================================================" >> "$ZRC"
  echo "" >> "$ZRC"

  cat "$BACKUP_NAME" \
    | sed -E 's/^(export ZSH=)/# (屏蔽) \1/' \
    | sed -E 's/^(source .*oh-my-zsh.sh)/# (屏蔽) \1/' \
    | sed -E 's/^(ZSH_THEME=)/# (屏蔽) \1/' \
    | sed -E 's/^(plugins=\()/ # (屏蔽) \1/' \
    | sed -E 's/^(# >>> OMZ_P10K)/# (屏蔽) \1/' \
    >> "$ZRC"
fi

# --- 6. 确保 p10k 临时配置存在 ---
P10K="$HOME/.p10k.zsh"
if [[ ! -f "$P10K" ]]; then
  cat > "$P10K" <<'EOF'
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status time)
EOF
fi

# --- 7. 最终指引与执行 ---
echo
echo "==========================================================="
echo "  🔴 重要提示：字体设置"
echo "==========================================================="
echo "  字体 'MesloLGS NF Regular' 已下载并安装到系统。"
echo ""
echo "  >>> 即使安装成功，你也必须手动更改终端设置！ <<<"
echo ""
echo "  1. 打开终端设置 (Preferences/Settings)"
echo "  2. 找到 'Font' 或 'Text' 选项"
echo "  3. 将字体修改为: MesloLGS NF"
echo "  (如果不修改，Powerlevel10k 的图标将显示为乱码)"
echo "==========================================================="
echo
echo "即将进入配置向导..."
sleep 3
exec "$ZSH_BIN" -i -c 'source ~/.zshrc; p10k configure'