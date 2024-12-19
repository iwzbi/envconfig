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

echo "Please restart your terminal or run 'source ~/.zshrc' to apply the changes."
