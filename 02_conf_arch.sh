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
LOG_FILE="/tmp/arch_config_$(date +%Y%m%d_%H%M%S).log"
CONFIG_REPOS=(
  "https://github.com/CarlosMolinesPastor/nerdfonts.git"
  "https://github.com/CarlosMolinesPastor/zsh.git"
  "https://github.com/CarlosMolinesPastor/kitty.git"
  "https://github.com/CarlosMolinesPastor/zed-editor.git"
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

install_nerdfonts() {
  if confirm "¿Instalar NerdFonts?"; then
    log "Instalando NerdFonts..."
    temp_dir=$(mktemp -d)

    git clone "${CONFIG_REPOS[0]}" "$temp_dir/nerdfonts" || error "Falló al clonar repositorio de NerdFonts"

    cd "$temp_dir/nerdfonts" || error "No se pudo acceder al directorio de NerdFonts"
    chmod +x nerdinstall.sh
    ./nerdinstall.sh || warning "Hubo problemas durante la instalación de NerdFonts"

    cd || return
    rm -rf "$temp_dir"
    success "NerdFonts instalados correctamente"
  fi
}

setup_zsh() {
  if confirm "¿Configurar ZSH y Oh My ZSH?"; then
    log "Configurando ZSH..."

    # Cambiar shell a ZSH si no está configurado
    if [ "$(basename "$SHELL")" != "zsh" ]; then
      log "Cambiando shell a ZSH..."
      chsh -s "$(which zsh)" || warning "Falló al cambiar shell a ZSH"
    else
      log "ZSH ya es el shell actual"
    fi

    # Instalar Oh My ZSH si no existe
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
      log "Instalando Oh My ZSH..."
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || error "Falló al instalar Oh My ZSH"
    fi

    # Configurar Starship
    if command -v starship &>/dev/null; then
      log "Configurando Starship..."
      starship preset pastel-powerline -o ~/.config/starship.toml || warning "Falló al configurar Starship"
    fi

    # Instalar plugins y temas
    log "Instalando plugins para ZSH..."
    declare -A plugins=(
      ["powerlevel10k"]="https://github.com/romkatv/powerlevel10k.git"
      ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
      ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
      ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab.git"
    )

    for plugin in "${!plugins[@]}"; do
      repo="${plugins[$plugin]}"
      target_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"

      if [ ! -d "$target_dir" ]; then
        git clone --depth=1 "$repo" "$target_dir" || warning "Falló al instalar plugin $plugin"
      fi
    done

    # Configurar .zshrc personalizado
    temp_dir=$(mktemp -d)
    git clone "${CONFIG_REPOS[1]}" "$temp_dir/zsh-config" || error "Falló al clonar repositorio de configuración ZSH"

    if [ -f "$temp_dir/zsh-config/.zshrc" ]; then
      log "Configurando .zshrc personalizado..."
      cp "$temp_dir/zsh-config/.zshrc" ~/.zshrc || warning "Falló al copiar .zshrc"
    fi

    rm -rf "$temp_dir"
    success "ZSH configurado correctamente"
    log "Para aplicar los cambios, cierra y vuelve a abrir la terminal o ejecuta 'source ~/.zshrc'"
  fi
}

setup_lazyvim() {
  if confirm "¿Instalar LazyVim?"; then
    log "Configurando LazyVim..."

    if [ -d ~/.config/nvim ]; then
      log "Haciendo backup de configuración existente de Neovim..."
      mv ~/.config/nvim ~/.config/nvim.bak || warning "Falló al hacer backup de la configuración existente"
    fi

    git clone --depth=1 https://github.com/LazyVim/starter ~/.config/nvim || error "Falló al clonar LazyVim"
    rm -rf ~/.config/nvim/.git
    success "LazyVim configurado correctamente"
  fi
}

setup_kitty() {
  if confirm "¿Configurar Kitty Terminal?"; then
    log "Configurando Kitty..."

    temp_dir=$(mktemp -d)
    git clone "${CONFIG_REPOS[2]}" "$temp_dir/kitty-config" || error "Falló al clonar repositorio de Kitty"

    if [ -d "$temp_dir/kitty-config" ]; then
      mkdir -p ~/.config/kitty
      cp -R "$temp_dir/kitty-config"/* ~/.config/kitty/ || warning "Falló al copiar configuración de Kitty"
    fi

    rm -rf "$temp_dir"
    success "Kitty configurado correctamente"
  fi
}

setup_ssh() {
  if [ "$USER_NAME" != "karlinux" ]; then
    warning "La configuración SSH solo está diseñada para el usuario karlinux"
    return
  fi

  if confirm "¿Configurar SSH?"; then
    log "Configurando SSH..."

    if [ -d ~/.ssh ]; then
      chmod 700 ~/.ssh || warning "Falló al cambiar permisos del directorio .ssh"

      for key in ~/.ssh/id_ecdsa ~/.ssh/id_rsa ~/.ssh/orangepi; do
        if [ -f "$key" ]; then
          chmod 600 "$key" || warning "Falló al cambiar permisos para $key"
        fi
      done

      eval "$(ssh-agent -s)" || warning "Falló al iniciar ssh-agent"

      for key in ~/.ssh/id_ecdsa ~/.ssh/id_rsa ~/.ssh/orangepi; do
        if [ -f "$key" ]; then
          ssh-add "$key" || warning "Falló al agregar llave $key"
        fi
      done
    else
      warning "No se encontró directorio .ssh"
    fi

    success "SSH configurado correctamente"
  fi
}

setup_java() {
  if confirm "¿Configurar Java para Wayland?"; then
    log "Configurando Java..."

    if ! grep -q "_JAVA_AWT_WM_NONREPARENTING" /etc/environment; then
      echo "_JAVA_AWT_WM_NONREPARENTING=1" | sudo tee -a /etc/environment >/dev/null || warning "Falló al configurar variable para Java"
    fi

    log "Estado de Java en el sistema:"
    archlinux-java status || warning "No se pudo verificar el estado de Java"

    if ! command -v java &>/dev/null; then
      warning "Java no está instalado. Puedes instalarlo con: sudo pacman -S jdk-openjdk"
    fi

    success "Java configurado para Wayland"
  fi
}

setup_zed() {
  if confirm "¿Configurar Zed Editor?"; then
    log "Configurando Zed..."

    if ! command -v zed &>/dev/null; then
      warning "Zed no está instalado. Puedes instalarlo desde: https://zed.dev/"
    fi

    temp_dir=$(mktemp -d)
    git clone "${CONFIG_REPOS[3]}" "$temp_dir/zed-config" || error "Falló al clonar repositorio de Zed"

    if [ -f "$temp_dir/zed-config/settings.json" ]; then
      mkdir -p ~/.config/zed
      cp "$temp_dir/zed-config/settings.json" ~/.config/zed/ || warning "Falló al copiar configuración de Zed"
    fi

    rm -rf "$temp_dir"
    success "Zed configurado correctamente"
  fi
}

show_menu() {
  while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════╗"
    echo -e "║    ${YELLOW}CONFIGURADOR DE ARCH LINUX${BLUE}        ║"
    echo -e "╠══════════════════════════════════════╣"
    echo -e "║ 1. Instalar NerdFonts                ║"
    echo -e "║ 2. Configurar ZSH y Oh My ZSH        ║"
    echo -e "║ 3. Configurar LazyVim                ║"
    echo -e "║ 4. Configurar Kitty Terminal         ║"
    echo -e "║ 5. Configurar SSH (solo karlinux)    ║"
    echo -e "║ 6. Configurar Java para Wayland      ║"
    echo -e "║ 7. Configurar Zed Editor             ║"
    echo -e "║ 0. Salir                             ║"
    echo -e "╚══════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Registro de configuración: $LOG_FILE${NC}"
    read -rp "Selecciona una opción: " option

    case $option in
    1) install_nerdfonts ;;
    2) setup_zsh ;;
    3) setup_lazyvim ;;
    4) setup_kitty ;;
    5) setup_ssh ;;
    6) setup_java ;;
    7) setup_zed ;;
    0)
      log "Configuración completada. Reinicia tu sesión para aplicar todos los cambios."
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
  show_menu
}

main "$@"
