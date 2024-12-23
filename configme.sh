#!/bin/bash

[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"
$SUDO apt update && $SUDO apt install -y zsh neovim tmux autojump || {
  echo "Installation of packages failed or not applicable in this environment."
}

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Oh My Zsh is not installed. Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  echo "Oh My Zsh installation is complete."
else
  echo "Oh My Zsh is already installed."
fi

plugins=("zsh-syntax-highlighting" "zsh-autosuggestions")

for plugin in "${plugins[@]}"; do
  if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]; then
    echo "Installing $plugin plugin..."
    case "$plugin" in
      zsh-syntax-highlighting)
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
        ;;
      zsh-autosuggestions)
        git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
        ;;
      *)
        echo "Unknown plugin: $plugin"
        ;;
    esac

    echo "$plugin plugin installed."
  else
    echo "$plugin plugin is already installed."
  fi
done

current_shell=$(basename "$SHELL")

if [ "$current_shell" != "zsh" ]; then
    echo "Current shell is $current_shell. Changing default shell to zsh."

    if command -v zsh >/dev/null 2>&1; then
        chsh -s $(which zsh)
        echo "zsh is now the default shell."
    else
        echo "zsh is not installed or not available in the PATH."
    fi
else
    echo "zsh is already the default shell."
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
  echo "Powerlevel10k is not installed. Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  echo "Powerlevel10k installation is complete."
else
  echo "Powerlevel10k is already installed."
fi

LUNARVIM_DIR="$HOME/.local/share/lunarvim"

if [ -d "$LUNARVIM_DIR" ]; then
  echo "LunarVim is already installed at $LUNARVIM_DIR."
else
  echo "LunarVim is not installed. Proceeding with installation..."

  if ! command -v node &>/dev/null; then
    echo "Node.js is not installed. Installing Node.js..."
    sudo apt update
    sudo apt install -y nodejs npm
  fi

  if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    echo "Python3 or pip3 is not installed. Installing Python3 and pip..."
    sudo apt update
    sudo apt install -y python3 python3-pip
  fi

  echo "Installing LunarVim..."
  LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)
  if [ -d "$LUNARVIM_DIR" ]; then
    echo "LunarVim installation completed successfully."
  else
    echo "LunarVim installation failed. Please check the logs for details."
  fi
fi

conf_dir="$PWD/.conf"
timestamp=$(date +"%Y%m%d%H%M%S")
for file in "$conf_dir"/.*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        home_file="$HOME/$filename"

        if [ -f "$home_file" ]; then
            mv "$home_file" "$home_file.$timestamp"
            echo "Renamed existing file $home_file to $home_file.$timestamp"
        fi

        cp "$file" "$home_file"
        echo "Copied $file to $home_file"
    fi
done

git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

echo "Please restart your terminal or run 'source ~/.zshrc' to apply the changes."
