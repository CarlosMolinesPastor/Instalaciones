#!/usr/bin/env bash

# Configuración
set -euo pipefail
trap 'echo "Error en línea $LINENO. Comando: $BASH_COMMAND"' ERR

# Colores para mejor legibilidad
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables configurables
USER_NAME=$(whoami)
LOG_FILE="/tmp/arch_install_$(date +%Y%m%d_%H%M%S).log"
PACKAGE_GROUPS=(
  "system:octopi cups nextcloud-client"
  "video:kodi kodi-addon-inputstream-adaptive gimp gimp-plugin-gmic"
  "internet:brave-bin"
  "dev:visual-studio-code-bin unityhub android-studio neovim neovim-remote jdk17-openjdk jdk-openjdk flutter-bin npm nodejs python-pip python-pipx python-virtualenv python-pandas python-numpy"
  "virtualization:virtualbox-host-dkms virtualbox virtualbox-guest-iso virtualbox-guest-utils"
  "misc:adw-gtk-theme lazygit silicon wmctrl"
)

# Funciones de utilidad
log() {
  echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
  exit 1
}

confirm() {
  read -rp "$1 [y/N] " response
  [[ "$response" =~ ^[Yy]$ ]] || return 1
  return 0
}

check_internet() {
  if ! ping -c 1 archlinux.org &>/dev/null; then
    error "No hay conexión a Internet. Por favor, verifica tu conexión."
  fi
}

update_system() {
  log "Actualizando el sistema..."
  sudo pacman -Syyu --noconfirm || error "Falló la actualización del sistema"
  success "Sistema actualizado correctamente"
}

install_yay() {
  log "Instalando paquetes base y YAY..."
  sudo pacman -Sy --noconfirm --needed base-devel git curl wget zsh || error "Falló la instalación de paquetes base"

  if ! command -v yay &>/dev/null; then
    log "Clonando y compilando YAY..."
    temp_dir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$temp_dir" || error "Falló al clonar YAY"
    cd "$temp_dir" || error "No se pudo acceder al directorio temporal"
    makepkg -si --noconfirm || error "Falló al compilar YAY"
    cd || return
    rm -rf "$temp_dir"
  else
    warning "YAY ya está instalado. Saltando instalación..."
  fi

  success "YAY instalado correctamente"
}

install_chaotic() {
  if ! grep -q "chaotic-aur" /etc/pacman.conf; then
    log "Instalando repositorio Chaotic AUR..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || error "Falló al recibir clave"
    sudo pacman-key --lsign-key 3056513887B78AEB || error "Falló al firmar clave"
    sudo pacman -U --noconfirm \
      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || error "Falló al instalar paquetes chaotic"

    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
    yay -Syyu --noconfirm || error "Falló al actualizar después de agregar chaotic"
    success "Repositorio Chaotic AUR instalado correctamente"
  else
    warning "Chaotic AUR ya está configurado. Saltando instalación..."
  fi
}

install_packages() {
  log "Instalando paquetes agrupados..."

  for group in "${PACKAGE_GROUPS[@]}"; do
    category=${group%%:*}
    packages=${group#*:}

    if confirm "¿Instalar paquetes de la categoría ${category}? (${packages})"; then
      log "Instalando paquetes de ${category}..."
      yay -S --needed --noconfirm ${packages} || warning "Algunos paquetes de ${category} no se instalaron correctamente"
    fi
  done

  # Configuración adicional para virtualización
  if pacman -Qi virtualbox &>/dev/null; then
    sudo usermod -a -G vboxusers "$USER_NAME"
  fi

  success "Paquetes instalados correctamente"
}

install_rust() {
  if ! command -v rustup &>/dev/null; then
    log "Instalando Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || error "Falló la instalación de Rust"
    source "$HOME/.cargo/env"
    rustup toolchain install nightly --allow-downgrade --profile minimal --component clippy || warning "Falló al instalar toolchain nightly"
    rustup component add rust-analyzer || warning "Falló al instalar rust-analyzer"
    success "Rust instalado correctamente"
  else
    warning "Rust ya está instalado. Saltando instalación..."
  fi
}

install_acernitro5() {
  if confirm "¿Instalar configuración específica para Acer Nitro 5?"; then
    log "Instalando paquetes para Acer Nitro 5..."
    yay -S --noconfirm --needed auto-cpufreq nbfc-linux acer-wmi-battery-dkms || error "Falló al instalar paquetes para Acer Nitro 5"

    log "Configurando auto-cpufreq..."
    sudo systemctl enable --now auto-cpufreq || warning "Falló al habilitar auto-cpufreq"

    log "Configurando NBFC..."
    nbfc config -r || warning "Falló al reiniciar configuración NBFC"
    sudo nbfc config -a "Acer Nitro AN515-57" || warning "Falló al aplicar configuración NBFC"

    if [ -f '/usr/share/nbfc/configs/Acer Nitro AN515-57.json' ]; then
      sudo cp '/usr/share/nbfc/configs/Acer Nitro AN515-57.json' '/usr/share/nbfc/configs/Acer Nitro AN515-57.json.bak'
      sudo sed -i 's/17/81/g' '/usr/share/nbfc/configs/Acer Nitro AN515-57.json' || warning "Falló al modificar configuración NBFC"
    fi

    success "Configuración para Acer Nitro 5 completada"
  fi
}

setup_zsh() {
  if [ "$(basename "$SHELL")" != "zsh" ]; then
    if confirm "¿Cambiar shell a ZSH?"; then
      log "Cambiando shell a ZSH..."
      chsh -s "$(which zsh)" || warning "Falló al cambiar shell a ZSH"
    fi
  else
    log "ZSH ya es el shell actual"
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    if confirm "¿Instalar Oh My ZSH?"; then
      log "Instalando Oh My ZSH..."
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || warning "Falló al instalar Oh My ZSH"
    fi
  else
    log "Oh My ZSH ya está instalado"
  fi
}

run_christitus() {
  if confirm "¿Ejecutar script de Chris Titus? Esto saldrá del instalador actual."; then
    log "Ejecutando script de Chris Titus..."
    curl -fsSL https://christitus.com/linux | sh || warning "Falló al ejecutar script de Chris Titus"
    success "Script de Chris Titus ejecutado"
    return 0
  fi
  return 1
}

show_menu() {
  while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════╗"
    echo -e "║   ${YELLOW}INSTALADOR DE ARCH LINUX MEJORADO${BLUE}  ║"
    echo -e "╠══════════════════════════════════════╣"
    echo -e "║ 1. Instalar YAY (AUR Helper)         ║"
    echo -e "║ 2. Instalar repositorio Chaotic AUR  ║"
    echo -e "║ 3. Instalar paquetes agrupados       ║"
    echo -e "║ 4. Instalar Rust y componentes       ║"
    echo -e "║ 5. Configuración para Acer Nitro 5   ║"
    echo -e "║ 6. Configurar ZSH y Oh My ZSH        ║"
    echo -e "║ 7. Ejecutar script de Chris Titus    ║"
    echo -e "║ 0. Salir                             ║"
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Registro de instalación: $LOG_FILE${NC}"
    read -rp "Selecciona una opción: " option

    case $option in
    1) install_yay ;;
    2) install_chaotic ;;
    3) install_packages ;;
    4) install_rust ;;
    5) install_acernitro5 ;;
    6) setup_zsh ;;
    7) if run_christitus; then break; fi ;;
    0)
      setup_zsh
      log "Instalación completada. ¡Disfruta de Arch Linux!"
      exit 0
      ;;
    *) warning "Opción no válida. Inténtalo de nuevo." ;;
    esac

    if [[ "$option" != "0" ]]; then
      read -rp "Presiona Enter para continuar..."
    fi
  done
}

# Ejecución principal
main() {
  check_internet
  update_system
  show_menu
}

main "$@"
