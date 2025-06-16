#!/usr/bin/env bash
## Instalador mejorado para Ubuntu 24.04 / Debian con soporte Pacstall

# ─── Configuración Inicial ────────────────────────────────
set -euo pipefail
set -o errtrace
trap 'echo -e "${RED}[ERROR]${NC} en línea $LINENO. Comando: $BASH_COMMAND" | tee -a "$LOG_FILE"' ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

USER_NAME=$(whoami)
LOG_FILE="/tmp/ubuntu_install_$(date +%Y%m%d_%H%M%S).log"
DISTRO_NAME=$(lsb_release -is)
DISTRO_VERSION=$(lsb_release -rs)
touch "$LOG_FILE"

# ─── Paquetes ──────────────────────────────────────────────
declare -A PACKAGE_MAP=(
  ["system"]="synaptic cups nextcloud-desktop nala gdebi"
  ["video"]="kodi kodi-inputstream-adaptive gimp gmic ffmpeg vlc"
  ["internet"]="brave-browser"
  ["dev"]="code lazygit default-jdk flutter npm nodejs python3-pip python3-pipx python3-virtualenv python3-pandas python3-numpy"
  ["virtualization"]="virtualbox virtualbox-ext-pack"
  ["misc"]="wmctrl fonts-inconsolata fonts-droid-fallback xfonts-terminus fonts-cantarell fonts-liberation ttf-mscorefonts-installer"
  ["pacstall-dev"]="android-studio neovim zed-editor-stable-bin"
  ["pacstall-internet"]="teams-for-linux-deb"
  ["pacstall-misc"]="appimagelauncher-deb adw-gtk-theme"
)

# ─── Utilidades ─────────────────────────────────────────────
log() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
error() {
  echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
  exit 1
}

is_interactive() {
  [[ -t 1 && -t 0 ]]
}

confirm() {
  if is_interactive; then
    read -rp "$1 [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]] || return 1
  fi
  return 0
}

check_distro() {
  if [[ "$DISTRO_NAME" != "Ubuntu" && "$DISTRO_NAME" != "Debian" ]]; then
    error "Este script solo es compatible con Ubuntu o Debian."
  fi
}

check_internet() {
  ping -q -c 1 google.com &>/dev/null || error "No hay conexión a Internet."
}

check_root() {
  if [[ $EUID -eq 0 ]]; then
    error "No ejecutes este script como root. Usa tu usuario con sudo."
  fi
  command -v sudo &>/dev/null || error "Se requiere sudo y no está instalado."
}

# ─── Instalación ────────────────────────────────────────────
update_system() {
  log "Actualizando sistema..."
  sudo apt update && sudo apt full-upgrade -y || error "Falló la actualización"
  command -v pacstall &>/dev/null && pacstall -Up

  log "Instalando dependencias básicas..."
  sudo apt install -y --no-install-recommends \
    wget curl gnupg2 lsb-release apt-transport-https \
    dirmngr gnupg ca-certificates build-essential cmake git kitty \
    software-properties-common || error "Falló la instalación base"

  success "Sistema actualizado y dependencias instaladas"
}

install_pacstall() {
  if ! command -v pacstall &>/dev/null; then
    log "Instalando Pacstall..."
    sudo bash -c "$(curl -fsSL https://pacstall.dev/q/install)" || error "Falló Pacstall"
    success "Pacstall instalado"

    if [[ ! ":$PATH:" == *":/usr/share/pacstall:"* ]]; then
      echo 'export PATH="$PATH:/usr/share/pacstall"' >>~/.bashrc
      source ~/.bashrc
    fi
  else
    log "Pacstall ya está instalado. Actualizando..."
    pacstall -Up
  fi
}

setup_repositories() {
  log "Añadiendo repositorios..."

  # Visual Studio Code
  if [[ ! -f /etc/apt/trusted.gpg.d/packages.microsoft.gpg ]]; then
    sudo install -D -o root -g root -m 644 \
      <(wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor) \
      /etc/apt/trusted.gpg.d/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
  fi

  # Brave
  if [[ ! -f /etc/apt/trusted.gpg.d/brave-browser-release.gpg ]]; then
    sudo curl -fsSLo /etc/apt/trusted.gpg.d/brave-browser-release.gpg https://brave-browser-apt-release.s3.brave.com/brave-core.asc
    echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  fi

  # VirtualBox
  if [[ ! -f /etc/apt/trusted.gpg.d/virtualbox.gpg ]]; then
    wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --output /etc/apt/trusted.gpg.d/virtualbox.gpg
    echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list
  fi

  # LazyGit (solo en Ubuntu)
  if [[ "$DISTRO_NAME" == "Ubuntu" ]]; then
    sudo add-apt-repository -y ppa:lazygit-team/release || warning "No se pudo añadir el PPA de LazyGit"
  fi

  sudo apt update
  success "Repositorios añadidos"
}

install_package_group() {
  local group_name=$1
  local packages=${PACKAGE_MAP[$group_name]:-}

  [[ -z "$packages" ]] && warning "Grupo vacío: $group_name" && return

  log "Instalando grupo: $group_name..."

  if [[ "$group_name" == pacstall-* ]]; then
    if ! command -v pacstall &>/dev/null; then
      warning "Pacstall no está instalado"
      return
    fi
    for pkg in $packages; do
      confirm "¿Instalar $pkg (Pacstall)?" && pacstall -I -B "$pkg" || warning "Fallo en $pkg"
    done
  else
    sudo apt install -y --no-install-recommends $packages || warning "Algunos paquetes fallaron"
  fi
}

install_all_packages() {
  for group in "${!PACKAGE_MAP[@]}"; do
    install_package_group "$group"
  done
}

configure_brave() {
  if dpkg -l | grep -q brave-browser; then
    log "Configurando Brave..."
    mkdir -p "$HOME/.local/share/applications"
    cp /usr/share/applications/brave-browser.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
    sed -i 's|Exec=/usr/bin/brave-browser-stable|Exec=/usr/bin/brave-browser-stable --no-sandbox|g' "$HOME/.local/share/applications/brave-browser.desktop" || warning "No se pudo ajustar Brave"
    success "Brave configurado"
  fi
}

setup_zsh() {
  confirm "¿Configurar ZSH como shell predeterminado?" || return

  if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    sudo apt install -y zsh
    chsh -s "$(which zsh)"
  fi

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  success "ZSH listo. Se aplicará al próximo inicio de sesión."
}

cleanup() {
  log "Eliminando paquetes innecesarios..."
  sudo apt autoremove -y && sudo apt clean
  success "Limpieza completada"
}

# ─── Menú ───────────────────────────────────────────────────
show_menu() {
  while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════╗"
    echo -e "║   ${YELLOW}INSTALADOR PARA UBUNTU/DEBIAN CON PACSTALL${BLUE}  ║"
    echo -e "╠══════════════════════════════════════════════╣"
    echo -e "║ 1. Actualizar sistema y dependencias         ║"
    echo -e "║ 2. Instalar/Actualizar Pacstall              ║"
    echo -e "║ 3. Configurar repositorios adicionales       ║"
    echo -e "║ 4. Instalar paquetes del sistema (apt)       ║"
    echo -e "║ 5. Instalar paquetes especiales (Pacstall)   ║"
    echo -e "║ 6. Instalar todos los paquetes (apt + pac)   ║"
    echo -e "║ 7. Configurar Brave Browser                  ║"
    echo -e "║ 8. Configurar ZSH y Oh My ZSH                ║"
    echo -e "║ 9. Limpiar sistema                           ║"
    echo -e "║ 0. Salir                                     ║"
    echo -e "╚══════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Distribución: ${DISTRO_NAME} ${DISTRO_VERSION}"
    echo -e "Log: $LOG_FILE${NC}"

    read -rp "Selecciona una opción: " option
    case $option in
    1) update_system ;;
    2) install_pacstall ;;
    3) setup_repositories ;;
    4)
      echo -e "\n${BLUE}Grupos APT:${NC}"
      for group in "${!PACKAGE_MAP[@]}"; do [[ "$group" != pacstall-* ]] && echo " - $group: ${PACKAGE_MAP[$group]}"; done
      read -rp "Nombre del grupo: " group
      install_package_group "$group"
      ;;
    5)
      echo -e "\n${BLUE}Grupos Pacstall:${NC}"
      for group in "${!PACKAGE_MAP[@]}"; do [[ "$group" == pacstall-* ]] && echo " - $group: ${PACKAGE_MAP[$group]}"; done
      read -rp "Nombre del grupo: " group
      install_package_group "$group"
      ;;
    6) install_all_packages ;;
    7) configure_brave ;;
    8) setup_zsh ;;
    9) cleanup ;;
    0)
      log "¡Instalación finalizada!"
      exit 0
      ;;
    *) warning "Opción no válida." ;;
    esac
    read -rp "Presiona Enter para continuar..."
  done
}

# ─── Punto de entrada ──────────────────────────────────────
main() {
  echo "Usuario: $USER_NAME" >>"$LOG_FILE"
  echo "Fecha: $(date)" >>"$LOG_FILE"
  check_root
  check_distro
  check_internet
  update_system
  show_menu
}

main "$@"
