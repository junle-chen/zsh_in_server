#!/usr/bin/env bash
# p10k_configure.sh
# 安装/修复 Oh My Zsh + Powerlevel10k + 常用插件，并触发 `p10k configure`
set -euo pipefail

log()  { printf "\033[1;32m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[WARN] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[ERR ] %s\033[0m\n" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || { err "缺少依赖：$1（请先安装或加入 PATH）"; exit 1; }; }

need git
if ! have curl && ! have wget; then err "需要 curl 或 wget"; exit 1; fi
fetch() { if have curl; then curl -fsSL "$1" -o "$2"; else wget -qO "$2" "$1"; fi; }

# 1) zsh 检测
ZSH_BIN="$(command -v zsh || true)"
[[ -n "$ZSH_BIN" ]] || { err "未检测到 zsh，请先安装 zsh"; exit 1; }
log "检测到 zsh: $ZSH_BIN"

# 2) Oh My Zsh（用户目录，无 sudo）
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
  log "安装 Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "已存在 Oh My Zsh，跳过安装。"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"
mkdir -p "$ZSH_CUSTOM"/{themes,plugins}

# 3) 安装/更新主题与插件
clone_or_pull () {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    (cd "$dest" && git pull --ff-only >/dev/null || true)
  elif [[ ! -d "$dest" ]]; then
    git clone --depth=1 "$url" "$dest"
  fi
}

log "安装/更新 Powerlevel10k 与常用插件…"
clone_or_pull https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_pull https://github.com/zsh-users/zsh-completions \
  "$ZSH_CUSTOM/plugins/zsh-completions"

# 4) 规范化并修复 ~/.zshrc（采用标记块，幂等）
ZRC="$HOME/.zshrc"
[[ -f "$ZRC" ]] || touch "$ZRC"
cp -f "$ZRC" "${ZRC}.bak_p10k_$(date +%s)" || true

# 删除旧标记块
perl -0777 -pe 's/# >>> OMZ_P10K START[\s\S]*?# >>> OMZ_P10K END\n?//g' -i "$ZRC"

# 追加新的标记块（保证顺序正确：变量→fpath→plugins→主题→最后 source omz）
cat >> "$ZRC" <<'EOF'
# >>> OMZ_P10K START
# Oh My Zsh 主目录与自定义目录
export ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

# zsh-completions 的补全脚本路径（必须在 OMZ 初始化前加入）
fpath=($ZSH_CUSTOM/plugins/zsh-completions/src $fpath)

# 插件（syntax-highlighting 放在最后，交由 OMZ 自动加载）
plugins=(git zsh-autosuggestions zsh-completions zsh-syntax-highlighting)

# 主题：Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# 加载 Oh My Zsh（会按 plugins 与 ZSH_THEME 初始化补全与主题）
[ -s "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# 若存在本地 p10k 配置则加载；无则稍后运行 `p10k configure`
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
# >>> OMZ_P10K END
EOF

# 5) 选配：首次提供极简 p10k 以防主题空白（配置向导后可覆盖）
P10K="$HOME/.p10k.zsh"
if [[ ! -f "$P10K" ]]; then
  cat > "$P10K" <<'EOF'
# Minimal p10k preset (可被 `p10k configure` 覆盖)
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)
EOF
fi

# 6) 触发配置向导（不做终端尺寸检测——按你的要求）
echo
echo "==============================================="
echo "  一切就绪！即将进入 p10k configure"
echo "==============================================="
echo
exec "$ZSH_BIN" -i -c 'source ~/.zshrc; p10k configure'
