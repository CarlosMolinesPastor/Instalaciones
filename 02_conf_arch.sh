#!/bin/bash

install_nerdfonts() {
  read -p "Instalando NerdFonts... pulsa una tecla para continuar"
  cd ~
  mkdir build
  cd build
  git clone https://github.com/CarlosMolinesPastor/nerdfonts.git
  cd nerdfonts
  chmod +x nerdinstall.sh
  ./nerdinstall.sh
  cd ~
  rm -Rf build
  echo "NerdFonts instalado"
  echo ""
}

install_zsh() {
  current_shell=$(basename "$SHELL")
  ohmyzsh_dir="$HOME/.oh-my-zsh"
  read -p "Instalando ZSH y configurando Oh My ZSH... pulsa una tecla para continuar"
  if [ "$current_shell" = "zsh" ]; then
    echo "Ya estás usando zsh."
  else
    echo "Cambiando shell a zsh..."
    chsh -s "$(which zsh)"
  fi

  if [ -d "$ohmyzsh_dir" ]; then
    echo "Oh My Zsh ya está instalado en $ohmyzsh_dir."
  else
    echo "Instalando Oh My Zsh..."
    sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
  fi
  starship preset pastel-powerline -o ~/.config/starship.toml
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
  cd ~
  git clone https://github.com/CarlosMolinesPastor/zsh.git
  cp zsh/.zshrc ~/.zshrc
  rm -rf zsh
  echo "ZSH y Oh My ZSH instalados y configurados"
  read -p "Para aplicar los cambios, cierra y vuelve a abrir la terminal o ejecuta 'source ~/.zshrc'. Pulsa una tecla para continuar"
}

install_lazyvim() {
  read -p "Instalando LazyVim... pulsa una tecla para continuar"
  mv ~/.config/nvim{,.bak}
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git
  echo "LazyVim instalado"
  echo ""
}

install_kitty() {
  read -p "Instalando configuracion de Kitty... pulsa una tecla para continuar"
  git clone https://github.com/CarlosMolinesPastor/kitty.git
  cp -R kitty ~/.config/
  echo "Kitty configurado"
  echo ""
}

conf_ssh() {
  read -p "Configurando SSH... pulsa una tecla para continuar"
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/*
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ecdsa
  ssh-add ~/.ssh/id_rsa
  ssh-add ~/.ssh/orangepi
  echo "SSH configurado"
  echo ""
}

conf_java() {
  read -p "Configurando Java en Wayland... pulsa una tecla para continuar"
  echo -e "_JAVA_AWT_WM_NONREPARENTING=1" | sudo tee -a /etc/environment >/dev/null
  archlinux-java status
  echo "Si no tienes instalado Java, puedes instalarlo con el comando: sudo pacman -S jdk-openjdk"
  echo "Java configurado para Wayland"
  echo ""
}

conf_zed() {
  read -p "Configurando Zed... pulsa una tecla para continuar"
  mkdir -p ~/.config/zed
  git clone https://github.com/CarlosMolinesPastor/zed-editor.git
  cp ~/zed-editor/settings.json ~/.config/zed/settings.json
  echo "Zed configurado"
  echo "Puedes instalar Zed desde su pagina oficial: https://zed.dev/"
  echo ""
}

while true; do
  clear
  echo "MENU DE CONFIGURACION ARCHLINUX"
  echo "1. Instalar NerdFonts"
  echo "2. Instalar ZSH y Oh My ZSH"
  echo "3. Instalar LazyVim"
  echo "4. Instalar configuracion de Kitty"
  echo "5. Configurar SSH (solo para usuario karlinux)"
  echo "6. Configurar Java en Wayland"
  echo "7. Configurar Zed (opcional)"
  echo "0. Salir"
  read opcion
  case $opcion in
  1)
    install_nerdfonts
    ;;
  2)
    install_zsh
    ;;
  3)
    install_lazyvim
    ;;
  4)
    conf_kitty
    ;;
  5)
    conf_ssh
    ;;
  6)
    conf_java
    ;;
  7)
    conf_zed
    ;;
  0)
    echo "Saliendo del instalador..."
    echo "Instalacion completada. Reinicia la sesion para completar la configuracion."
    break
    exit 0
    ;;
  *)
    echo "Opcion no valida. Por favor, elige una opcion del menu."
    continue
    ;;
  esac
done
