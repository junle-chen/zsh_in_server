#!/usr/bin/env bash
set -e

# ==============================
# 无 sudo 版本（安装到 $HOME）
# ==============================

mkdir -p $HOME/bin $HOME/src

echo "==> 检查是否已有 zsh..."
if ! command -v zsh >/dev/null 2>&1; then
    echo "==> 未检测到 zsh，开始在 HOME 编译安装 (大约 2~3 分钟)..."
    cd $HOME/src
    curl -LO https://sourceforge.net/projects/zsh/files/latest/download -o zsh.tar.xz
    tar -xf zsh.tar.xz
    cd zsh-*
    ./configure --prefix=$HOME
    make -j4
    make install

    echo "export PATH=$HOME/bin:\$PATH" >> ~/.bashrc
    echo "export PATH=$HOME/bin:\$PATH" >> ~/.zshrc
else
    echo "==> 已有 zsh，跳过编译安装。"
fi

ZSH_PATH="$HOME/bin/zsh"
if [ ! -f "$ZSH_PATH" ]; then
    ZSH_PATH=$(command -v zsh)
fi

echo "==> 使用 zsh: $ZSH_PATH"

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "==> 安装 Oh My Zsh（无 sudo）..."
    RUNZSH=no CHSH=no sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install Powerlevel10k
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    echo "==> 安装 Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      $ZSH_CUSTOM/themes/powerlevel10k
fi

# Plugins
echo "==> 安装插件（autosuggest / syntax-highlighting / completions）..."
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  $ZSH_CUSTOM/plugins/zsh-autosuggestions 2>/dev/null || true

git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  $ZSH_CUSTOM/plugins/zsh-syntax-highlighting 2>/dev/null || true

git clone --depth=1 https://github.com/zsh-users/zsh-completions \
  $ZSH_CUSTOM/plugins/zsh-completions 2>/dev/null || true

# Modify .zshrc
echo "==> 配置 .zshrc..."

sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc || \
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc

sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' ~/.zshrc || \
  echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)' >> ~/.zshrc

# Extra plugin config
if ! grep -q "zsh-syntax-highlighting" ~/.zshrc; then
cat << 'EOF' >> ~/.zshrc

# Extra plugin settings
fpath=($ZSH_CUSTOM/plugins/zsh-completions/src $fpath)
autoload -U compinit && compinit

# Syntax highlighting should be last
source $ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF
fi

echo ""
echo "====================================="
echo "  安装完成！现在将进入 p10k configure"
echo "====================================="
echo ""

# Use our own zsh to run p10k configure
exec $ZSH_PATH -i -c 'p10k configure'
