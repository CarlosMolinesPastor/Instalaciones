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
USER_HOME="/home/$USER_NAME"
LOG_FILE="/tmp/ubuntu_install_$(date +%Y%m%d_%H%M%S).log"
DISTRO_NAME=$(lsb_release -is)
DISTRO_VERSION=$(lsb_release -rs)
touch "$LOG_FILE"

# ─── Paquetes ──────────────────────────────────────────────
declare -A PACKAGE_MAP=(
  ["system"]="synaptic cups nextcloud-desktop nala gdebi"
  ["video"]="kodi kodi-inputstream-adaptive gimp gmic ffmpeg vlc"
  ["internet"]="brave-browser"
  ["dev"]="code default-jdk npm nodejs python3-pip python3-pipx python3-virtualenv python3-pandas python3-numpy"
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

# ─── Funciones de Instalación ──────────────────────────────
install_java() {
  confirm "¿Instalar Java (JDK y JRE)?" || return
  
  log "Instalando Java..."
  sudo apt install -y default-jre default-jdk
  
  # Configurar JAVA_HOME
  JAVA_PATH=$(sudo update-alternatives --list java | sed 's|/bin/java||')
  if [[ -n "$JAVA_PATH" ]]; then
    echo "JAVA_HOME=\"$JAVA_PATH\"" | sudo tee -a /etc/environment
    source /etc/environment
    log "JAVA_HOME configurado en $JAVA_PATH"
  else
    warning "No se pudo determinar JAVA_HOME automáticamente"
  fi
  
  success "Java instalado correctamente"
}

install_homebrew() {
  confirm "¿Instalar Homebrew?" || return
  
  log "Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Configurar Homebrew para el usuario actual
  BREW_PREFIX="/home/linuxbrew/.linuxbrew"
  (echo; echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"") >> "$USER_HOME/.bashrc"
  (echo; echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"") >> "$USER_HOME/.zshrc"
  eval "$($BREW_PREFIX/bin/brew shellenv)"
  
  # Instalar dependencias necesarias
  sudo apt-get install -y build-essential
  
  success "Homebrew instalado correctamente"
}

install_rust() {
  confirm "¿Instalar Rust y Silicon?" || return
  
  log "Instalando dependencias de Rust..."
  sudo apt-get install -y libxcb-render0-dev libxcb-shape0-dev libxcb-xfixes0-dev
  
  log "Instalando Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$USER_HOME/.cargo/env"
  
  log "Instalando Silicon..."
  cargo install silicon
  
  success "Rust y Silicon instalados correctamente"
}

install_nvm_node() {
  confirm "¿Instalar NVM y Node.js?" || return
  
  log "Instalando NVM..."
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  
  # Cargar NVM en la sesión actual
  export NVM_DIR="$USER_HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  
  log "Instalando la última versión LTS de Node.js..."
  LTS_VERSION=$(nvm ls-remote | grep -i latest | grep -Po 'v\d+\.\d+\.\d+' | tail -n 1)
  nvm install "$LTS_VERSION"
  nvm use "$LTS_VERSION"
  
  log "Instalando TypeScript globalmente..."
  npm install -g typescript-language-server typescript
  
  success "NVM y Node.js instalados correctamente (Versión $LTS_VERSION)"
}

install_intellij() {
  confirm "¿Instalar IntelliJ IDEA?" || return
  
  log "Configurando repositorio de JetBrains..."
  curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | gpg --dearmor | sudo tee /usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg] http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com any main" | sudo tee /etc/apt/sources.list.d/jetbrains-ppa.list > /dev/null
  
  log "Instalando IntelliJ IDEA..."
  sudo apt update
  sudo apt install -y intellij-idea-community
  
  success "IntelliJ IDEA instalado correctamente"
}

install_liquorix_kernel() {
  confirm "¿Instalar kernel Liquorix?" || return
  
  log "Añadiendo repositorio de Liquorix..."
  sudo add-apt-repository -y ppa:damentz/liquorix
  sudo apt update
  
  log "Instalando kernel Liquorix..."
  sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64
  
  success "Kernel Liquorix instalado. Reinicia para activarlo."
}

install_pacstall() {
  confirm "¿Instalar/Actualizar Pacstall?" || return
  
  log "Instalando Pacstall..."
  sudo bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"
  
  success "Pacstall instalado correctamente"
}

setup_repositories() {
  confirm "¿Configurar repositorios adicionales?" || return
  
  log "Añadiendo repositorios..."
  
  # Brave Browser
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  
  # VS Code
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/vscode.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/vscode.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
  
  # Node.js
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  
  sudo apt update
  success "Repositorios configurados correctamente"
}

install_package_group() {
  local group=$1
  [[ -z "${PACKAGE_MAP[$group]:-}" ]] && error "Grupo de paquetes no válido: $group"
  
  if [[ $group == pacstall-* ]]; then
    log "Instalando grupo $group con Pacstall..."
    for pkg in ${PACKAGE_MAP[$group]}; do
      confirm "¿Instalar $pkg?" && pacstall -I "$pkg"
    done
  else
    log "Instalando grupo $group con apt..."
    sudo apt install -y ${PACKAGE_MAP[$group]}
  fi
  
  success "Paquetes del grupo $group instalados"
}

install_all_packages() {
  confirm "¿Instalar TODOS los paquetes? Esto puede llevar tiempo." || return
  
  for group in "${!PACKAGE_MAP[@]}"; do
    if [[ $group == pacstall-* ]]; then
      for pkg in ${PACKAGE_MAP[$group]}; do
        pacstall -I "$pkg"
      done
    else
      sudo apt install -y ${PACKAGE_MAP[$group]}
    fi
  done
  
  success "Todos los paquetes instalados"
}

configure_brave() {
  confirm "¿Configurar Brave Browser?" || return
  
  log "Configurando Brave..."
  sudo apt install -y brave-browser
  
  # Configuración recomendada
  if [[ -f "$USER_HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences" ]]; then
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$USER_HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
    sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$USER_HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
  fi
  
  success "Brave configurado. Ejecuta 'brave-browser' para iniciarlo."
}

setup_zsh() {
  confirm "¿Configurar ZSH y Oh My ZSH?" || return
  
  log "Instalando ZSH..."
  sudo apt install -y zsh
  
  log "Instalando Oh My ZSH..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  
  # Plugins recomendados
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  
  # Configuración básica
  sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' ~/.zshrc
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
  
  # Cambiar shell por defecto
  chsh -s $(which zsh)
  
  success "ZSH y Oh My ZSH configurados. Reinicia la terminal."
}

install_flutter() {
  confirm "¿Instalar Flutter SDK?" || return
  
  log "Instalando dependencias..."
  sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev
  
  log "Descargando Flutter..."
  cd "$USER_HOME" || error "No se pudo cambiar a $USER_HOME"
  git clone https://github.com/flutter/flutter.git -b stable
  flutter precache
  flutter doctor
  
  # Agregar a PATH
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$USER_HOME/.bashrc"
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$USER_HOME/.zshrc"
  
  success "Flutter instalado. Ejecuta 'flutter doctor' para verificar."
}

install_lazygit() {
  confirm "¿Instalar LazyGit?" || return
  
  log "Instalando LazyGit..."
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit /usr/local/bin
  rm lazygit lazygit.tar.gz
  
  success "LazyGit instalado. Ejecuta 'lazygit' para usarlo."
}

cleanup() {
  confirm "¿Limpiar paquetes innecesarios y caché?" || return
  
  log "Limpiando sistema..."
  sudo apt autoremove -y
  sudo apt clean
  sudo rm -rf /var/cache/apt/archives/*
  sudo rm -rf /tmp/*
  
  if command -v pacstall &>/dev/null; then
    pacstall -Rc
  fi
  
  success "Limpieza completada"
}

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
    echo -e "║ 8. Configurar ZSH y Oh My ZSH               ║"
    echo -e "║ 9. Instalar Flutter SDK                     ║"
    echo -e "║ 10. Instalar LazyGit                        ║"
    echo -e "║ 11. Instalar Java                           ║"
    echo -e "║ 12. Instalar Homebrew                       ║"
    echo -e "║ 13. Instalar Rust y Silicon                 ║"
    echo -e "║ 14. Instalar NVM y Node.js                  ║"
    echo -e "║ 15. Instalar IntelliJ IDEA                  ║"
    echo -e "║ 16. Instalar kernel Liquorix                ║"
    echo -e "║ 17. Limpiar sistema                         ║"
    echo -e "║ 0. Salir                                    ║"
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
    9) install_flutter ;;
    10) install_lazygit ;;
    11) install_java ;;
    12) install_homebrew ;;
    13) install_rust ;;
    14) install_nvm_node ;;
    15) install_intellij ;;
    16) install_liquorix_kernel ;;
    17) cleanup ;;
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
