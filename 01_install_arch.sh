#!/bin/bash

install_yay() {
  read -p "Instalando paquetes base necesarios y YAY...pulsa una tecla para continuar"
  sudo pacman -Sy --noconfirm --needed base-devel git curl wget zsh
  cd /opt
  sudo git clone https://aur.archlinux.org/yay.git
  sudo chown -R "$USER":"$USER" yay
  cd yay
  makepkg -si --noconfirm
  echo "Paquetes base y YAY instalado"
  echo ""
}

install_chaotic() {
  read -p "Instalando repositorio Chaotic AUR... pulsa una tecla para continuar"
  sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 3056513887B78AEB
  sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  echo -e "[chaotic-aur] \nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
  yay -Syyu --noconfirm
  echo "Repositorio Chaotic AUR instalado"
  echo ""
}

install_various() {
  read -p "Instalando paquetes varios... pulsa una tecla para continuar"
  yay -Syyu --noconfirm --needed octopi tailscale kodi kodi-addon-inputstream-adaptive adw-gtk-theme lazygit silicon virtualbox-host-dkms virtualbox virtualbox-guest-iso virtualbox-guest-utils brave-bin cups nextcloud-client libreoffice-fresh libreoffice-fresh-es onlyoffice-bin gimp gimp-plugin-gmic visual-studio-code-bin unityhub android-studio neovim neovim-remote chromium jdk17-openjdk jdk-openjdk flutter-bin npm nodejs python-pip python-pipx python-virtualenv python-pandas python-numpy wmctrl
  sudo usermod -a -G vboxusers $(whoami)
  echo "Paquetes varios instalados"
  echo ""
}

install_rust() {
  read -p "Instalando Rust y sus componentes... pulsa una tecla para continuar"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  rustup toolchain install nightly --allow-downgrade --profile minimal --component clippy
  rustup component add rust-analyzer
  echo "Rust y sus componentes instalados"
  echo ""
}

install_acernitro5() {
  read -p "Instalando configuracion para Acer Nitro 5... pulsa una tecla para continuar"
  yay -Syyu --noconfirm --needed auto-cpufreq nbfc-linux acer-wmi-battery-dkms
  sudo systemctl enable auto-cpufreq
  sudo systemctl start auto-cpufreq
  nbfc config -r
  sudo nbfc config -s "Acer Nitro AN515-57"
  sudo nbfc config -a "Acer Nitro AN515-57"
  sudo cp '/usr/share/nbfc/configs/Acer Nitro AN515-57.json' '/usr/share/nbfc/configs/Acer Nitro AN515-57.json.bak'
  sudo sed -i 's/17/81/g' '/usr/share/nbfc/configs/Acer Nitro AN515-57.json'
}

chris_linutil() {
  read -p "Ejecucion de script de Chris Titus... pulsa una tecla para continuar, se saldra de la instalacion"
  curl -fsSL https://christitus.com/linux | sh
  echo "Script de Chris Titus ejecutado"
  echo ""
}

set -e # Exit on error
echo "Instalacion de los paquetes de ArchLinux"
echo "Requiere conexion a internet y un usuario con permisos sudo"
echo ""
read -p "Pulsa una tecla para continuar"
echo ""
echo "Primero vamos a actualizar el sistema..."
sleep 2s
sudo pacman -Syyu --noconfirm
echo "Sistema actualizado"
echo ""
## Shell y Oh My Zsh
current_shell=$(basename "$SHELL")
ohmyzsh_dir="$HOME/.oh-my-zsh"
while true; do
  clear
  echo "MENU DE INSTALACION DE ARCHLINUX"
  echo "1. Instalar YAY (AUR Helper)"
  echo "2. Instalacion de chaotic AUR"
  echo "3. Instalacion de paquetes varios"
  echo "4. Instalar Rust y sus componentes"
  echo "5. Instalar configuracion para Acer Nitro 5"
  echo "6. Ejecutar script de Chris Titus"
  echo "0. Salir"
  echo "Escoge una opcion:"
  read opcion
  case $opcion in
  1)
    install_yay
    ;;
  2)
    install_chaotic
    ;;
  3)
    install_various
    ;;
  4)
    install_rust
    ;;
  5)
    install_acernitro5
    ;;
  6)
    chris_linutil
    ;;
  0)
    echo "Saliendo del instalador..."
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
    break
    exit 0
    ;;
  *)
    echo "Opcion no valida. Por favor, elige una opcion del menu."
    continue
    ;;
  esac
  read -p "Pulsa una tecla para continuar..."
done
