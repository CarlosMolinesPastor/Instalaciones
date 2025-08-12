#!/bin/bash

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables globales
INSTALLED_COMPONENTS=()

# Función para mostrar mensajes de éxito
success() {
    echo -e "${GREEN}[✓] $1${NC}"
    INSTALLED_COMPONENTS+=("$1")
}

# Función para mostrar mensajes de información
info() {
    echo -e "${BLUE}[i] $1${NC}"
}

# Función para mostrar mensajes de advertencia
warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Función para mostrar mensajes de error
error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        warning "No se recomienda ejecutar este script como root. Se solicitarán privilegios cuando sea necesario."
        read -p "¿Deseas continuar de todos modos? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Función para verificar que estamos en Debian
check_debian() {
    if ! grep -q "Debian" /etc/os-release; then
        error "Este script está diseñado para Debian. No se recomienda su uso en otras distribuciones."
        exit 1
    fi
}

# Función para actualizar el sistema
update_system() {
    info "Actualizando el sistema..."
    sudo apt update && sudo apt upgrade -y
    if [ $? -eq 0 ]; then
        success "Sistema actualizado correctamente"
    else
        error "Error al actualizar el sistema"
        return 1
    fi
}

# Función para instalar paquetes esenciales
install_essentials() {
    info "Instalando paquetes esenciales..."
    sudo apt install -y build-essential git curl wget
    if [ $? -eq 0 ]; then
        success "Paquetes esenciales instalados correctamente"
    else
        error "Error al instalar paquetes esenciales"
        return 1
    fi
}

# Función para instalar herramientas C/C++
install_c_tools() {
    info "Instalando herramientas y librerías para C/C++..."
    sudo apt install -y libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
        libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev \
        autoconf automake libtool cmake libcunit1-dev libgtest-dev
    if [ $? -eq 0 ]; then
        success "Herramientas para C/C++ instaladas correctamente"
    else
        error "Error al instalar herramientas para C/C++"
        return 1
    fi
}

# Función para instalar Python
install_python() {
    info "Instalando Python y herramientas relacionadas..."
    sudo apt install -y python3 python3-dev python3-pip python3-venv
    if [ $? -eq 0 ]; then
        success "Python instalado correctamente"
    else
        error "Error al instalar Python"
        return 1
    fi
}

# Función para instalar Java
install_java() {
    info "Configurando Java (Temurin 17)..."
    
    sudo apt install -y wget apt-transport-https gpg
    
    if [ ! -f /etc/apt/trusted.gpg.d/adoptium.gpg ]; then
        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg || return 1
        echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list || return 1
    fi
    
    sudo apt update || return 1
    sudo apt install -y temurin-17-jdk junit || return 1
    
    info "Configurando Java alternativo..."
    sudo update-alternatives --config java
    
    JAVA_HOME_PATH=$(update-alternatives --list java | grep temurin-17 | sed 's|/bin/java||')
    echo "export JAVA_HOME=$JAVA_HOME_PATH" >> ~/.bashrc
    echo "export JAVA_HOME=$JAVA_HOME_PATH" >> ~/.zshrc
    source ~/.bashrc
    
    success "Java instalado y configurado correctamente"
}

# Función para instalar Node.js
install_nodejs() {
    info "Instalando Node.js y npm..."
    
    echo -e "Opciones de instalación:"
    echo "1) Instalar desde repositorios (más simple)"
    echo "2) Instalar usando nvm (recomendado, permite múltiples versiones)"
    read -p "Selecciona una opción [1-2]: " option
    
    case $option in
        1)
            sudo apt install -y npm nodejs
            ;;
        2)
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash || return 1
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            
            LTS_VERSION=$(nvm ls-remote | grep -i latest | grep -Po 'v\d+\.\d+\.\d+' | tail -n 1)
            nvm install "$LTS_VERSION" || return 1
            nvm use "$LTS_VERSION" || return 1
            ;;
        *)
            error "Opción no válida"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        success "Node.js instalado correctamente"
    else
        error "Error al instalar Node.js"
        return 1
    fi
}

# Función para instalar Docker
install_docker() {
    info "Instalando Docker y Docker Compose..."
    
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release || return 1
    
    if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || return 1
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || return 1
    fi
    
    sudo apt update || return 1
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || return 1
    
    sudo usermod -aG docker $USER || return 1
    sudo systemctl enable docker || return 1
    
    success "Docker instalado y configurado correctamente"
}

# Función para instalar VS Code
install_vscode() {
    info "Instalando Visual Studio Code..."
    
    sudo apt install -y software-properties-common apt-transport-https || return 1
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg || return 1
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/ || return 1
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list' || return 1
    sudo apt update || return 1
    sudo apt install -y code || return 1
    
    success "Visual Studio Code instalado correctamente"
}

# Función para instalar Neovim
install_neovim() {
    info "Instalando Neovim con configuración personalizada..."
    
    sudo apt install -y neovim || return 1
    
    info "Haciendo backup de configuraciones existentes de Neovim..."
    [ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak
    [ -d ~/.local/share/nvim ] && mv ~/.local/share/nvim ~/.local/share/nvim.bak
    [ -d ~/.local/state/nvim ] && mv ~/.local/state/nvim ~/.local/state/nvim.bak
    [ -d ~/.cache/nvim ] && mv ~/.cache/nvim ~/.cache/nvim.bak
    
    git clone https://github.com/CarlosMolinesPastor/nvim.git ~/.config/nvim || return 1
    
    success "Neovim instalado y configurado correctamente"
}

# Función para instalar IntelliJ
install_intellij() {
    info "Instalando IntelliJ IDEA..."
    
    echo -e "Opciones de instalación:"
    echo "1) Community Edition (gratis)"
    echo "2) Ultimate Edition (pago, requiere licencia)"
    read -p "Selecciona una opción [1-2]: " option
    
    case $option in
        1)
            curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | sudo gpg --dearmor -o /usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg || return 1
            echo "deb [signed-by=/usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg] http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com any main" | sudo tee /etc/apt/sources.list.d/jetbrains-ppa.list > /dev/null || return 1
            sudo apt update || return 1
            sudo apt install -y intellij-idea-community || return 1
            ;;
        2)
            curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | sudo gpg --dearmor -o /usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg || return 1
            echo "deb [signed-by=/usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg] http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com any main" | sudo tee /etc/apt/sources.list.d/jetbrains-ppa.list > /dev/null || return 1
            sudo apt update || return 1
            sudo apt install -y intellij-idea-ultimate || return 1
            ;;
        *)
            error "Opción no válida"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        success "IntelliJ IDEA instalado correctamente"
    else
        error "Error al instalar IntelliJ IDEA"
        return 1
    fi
}

# Función para instalar Ollama
install_ollama() {
    info "Instalando Ollama con modelo de IA local..."
    
    curl -fsSL https://ollama.com/install.sh | sh || return 1
    info "Descargando modelo qwen2.5-coder:1.5b (esto puede tomar tiempo)..."
    ollama run qwen2.5-coder:1.5b || warning "Error al descargar el modelo, pero Ollama se instaló correctamente"
    
    success "Ollama instalado correctamente"
}

# Función para configurar Zsh
configure_zsh() {
    info "Configurando Zsh y herramientas de terminal..."
    
    sudo apt install -y zsh fzf ripgrep lsd bat || return 1
    
    if [ "$SHELL" != "/usr/bin/zsh" ]; then
        info "Cambiando shell a Zsh..."
        sudo chsh -s /usr/bin/zsh $USER || return 1
    fi
    
    curl -sS https://starship.rs/install.sh | sh || return 1
    starship preset pastel-powerline -o ~/.config/starship.toml || warning "Error al configurar Starship, pero se instaló correctamente"
    
    sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended || return 1
    
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || return 1
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || return 1
    git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab || return 1
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf || return 1
    ~/.fzf/install --key-bindings --completion --no-update-rc || return 1
    
    git clone https://github.com/CarlosMolinesPastor/zsh.git ~/zsh-config-temp || return 1
    cp ~/zsh-config-temp/.zshrc ~/.zshrc || return 1
    rm -rf ~/zsh-config-temp || warning "Error al limpiar archivos temporales"
    
    success "Zsh y herramientas de terminal configuradas correctamente"
}

# Función para instalar Flatpak y Snap
install_flatpak_snap() {
    info "Instalando Flatpak y Snap..."
    
    sudo apt install -y flatpak || return 1
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || return 1
    
    sudo apt install -y snapd || return 1
    sudo systemctl enable --now snapd.socket || return 1
    
    sudo ln -s /var/lib/snapd/snap /snap || warning "Error al crear enlace simbólico para snap (puede que ya exista)"
    
    success "Flatpak y Snap instalados y configurados correctamente"
}

# Función para instalar herramientas multimedia
install_multimedia() {
    info "Instalando herramientas multimedia..."
    
    sudo apt install -y audacity kdenlive kodi shotcut ffmpeg \
        libavcodec-extra vlc || return 1
    
    success "Herramientas multimedia instaladas correctamente"
}

# Función para instalar herramientas gráficas
install_graphics() {
    info "Instalando herramientas gráficas..."
    
    sudo apt install -y inkscape gimp gimp-gmic gpick krita \
        blender scribus darktable || return 1
    
    success "Herramientas gráficas instaladas correctamente"
}

# Función para instalar herramientas de ofimática
install_office() {
    info "Instalando herramientas de ofimática..."
    
    echo -e "Opciones de instalación:"
    echo "1) LibreOffice (recomendado)"
    echo "2) OnlyOffice"
    echo "3) Ambos"
    read -p "Selecciona una opción [1-3]: " option
    
    case $option in
        1)
            sudo apt install -y libreoffice libreoffice-l10n-es libreoffice-gtk3 || return 1
            ;;
        2)
            # Descargar e instalar OnlyOffice
            wget https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb || return 1
            sudo dpkg -i onlyoffice-desktopeditors_amd64.deb || sudo apt-get install -f -y
            rm onlyoffice-desktopeditors_amd64.deb
            ;;
        3)
            sudo apt install -y libreoffice libreoffice-l10n-es libreoffice-gtk3 || return 1
            wget https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb || return 1
            sudo dpkg -i onlyoffice-desktopeditors_amd64.deb || sudo apt-get install -f -y
            rm onlyoffice-desktopeditors_amd64.deb
            ;;
        *)
            error "Opción no válida"
            return 1
            ;;
    esac
    
    success "Herramientas de ofimática instaladas correctamente"
}

# Función para instalar VirtualBox
install_virtualbox() {
    info "Instalando VirtualBox para Debian Trixie..."
    
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list || return 1
    
    wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg || return 1
    
    sudo apt update || return 1
    sudo apt install -y virtualbox-7.0 || return 1
    
    sudo usermod -aG vboxusers $USER || warning "Error al añadir usuario al grupo vboxusers"
    
    success "VirtualBox instalado correctamente"
}

# Función para instalar Geany con temas
install_geany() {
    info "Instalando Geany con temas..."
    
    sudo apt install -y geany || return 1
    
    git clone https://github.com/codebrainz/geany-themes.git || return 1
    cd geany-themes || return 1
    ./install || warning "Error al instalar temas, pero Geany se instaló correctamente"
    cd ..
    rm -Rf geany-themes || warning "Error al eliminar archivos temporales"
    
    success "Geany con temas instalado correctamente"
}

# Función para mostrar el submenú de IDEs
show_ides_menu() {
    clear
    echo -e "${GREEN}Instalación de IDEs${NC}"
    echo "========================================"
    echo "1. Instalar Visual Studio Code"
    echo "2. Instalar Neovim con configuración"
    echo "3. Instalar IntelliJ IDEA"
    echo "4. Instalar Geany con temas"
    echo "5. Volver al menú principal"
    echo "========================================"
}

# Función para verificar las instalaciones
check_installations() {
    info "Comprobando las instalaciones..."
    echo -e "\nVersiones instaladas:"
    echo "----------------------"
    gcc --version | head -n 1 || warning "GCC no está instalado"
    python3 --version || warning "Python no está instalado"
    java --version || warning "Java no está instalado"
    node --version || warning "Node.js no está instalado"
    docker --version || warning "Docker no está instalado"
    git --version || warning "Git no está instalado"
    zsh --version || warning "Zsh no está instalado"
    code --version 2>/dev/null || warning "VS Code no está instalado"
    nvim --version 2>/dev/null | head -n 1 || warning "Neovim no está instalado"
    virtualbox --version 2>/dev/null || warning "VirtualBox no está instalado"
    geany --version 2>/dev/null || warning "Geany no está instalado"
    flatpak --version 2>/dev/null || warning "Flatpak no está instalado"
    snap --version 2>/dev/null || warning "Snap no está instalado"
    
    read -p "Presiona Enter para continuar..."
}

# Función para mostrar componentes instalados
show_installed_components() {
    clear
    echo -e "${GREEN}Componentes instalados:${NC}"
    echo "============================"
    if [ ${#INSTALLED_COMPONENTS[@]} -eq 0 ]; then
        echo "No se han instalado componentes aún."
    else
        for component in "${INSTALLED_COMPONENTS[@]}"; do
            echo "- $component"
        done
    fi
    echo "============================"
    read -p "Presiona Enter para continuar..."
}

# Función para mostrar el menú principal
show_menu() {
    clear
    echo -e "${GREEN}Configuración de Debian para Desarrolladores${NC}"
    echo "========================================"
    echo "1. Actualizar sistema"
    echo "2. Instalar paquetes esenciales"
    echo "3. Instalar herramientas C/C++"
    echo "4. Instalar Python"
    echo "5. Instalar Java"
    echo "6. Instalar Node.js"
    echo "7. Instalar Docker"
    echo "8. Instalar IDEs y editores"
    echo "9. Configurar Zsh"
    echo "10. Instalar Ollama (IA local)"
    echo "11. Instalar Flatpak y Snap"
    echo "12. Herramientas Multimedia"
    echo "13. Herramientas Gráficas"
    echo "14. Herramientas de Oficina"
    echo "15. Instalar VirtualBox"
    echo "16. Verificar instalaciones"
    echo "17. Mostrar componentes instalados"
    echo "0. Salir"
    echo "========================================"
}

# Función principal
main() {
    check_root
    check_debian
    
    while true; do
        show_menu
        read -p "Selecciona una opción [0-16]: " option
        
        case $option in
            1) update_system ;;
            2) install_essentials ;;
            3) install_c_tools ;;
            4) install_python ;;
            5) install_java ;;
            6) install_nodejs ;;
            7) install_docker ;;
            8) 
                while true; do
                    show_ides_menu
                    read -p "Selecciona una opción [1-5]: " ide_option
                    
                    case $ide_option in
                        1) install_vscode ;;
                        2) install_neovim ;;
                        3) install_intellij ;;
                        4) install_geany ;;
                        5) break ;;
                        *) error "Opción no válida" ;;
                    esac
                    
                    read -p "Presiona Enter para continuar..."
                done
                ;;
            9) configure_zsh ;;
            10) install_ollama ;;
            11) install_flatpak_snap ;;
            12) install_multimedia ;;
            13) install_graphics ;;
            14) install_office ;;
            15) install_virtualbox ;;
            16) check_installations ;;
            17) show_installed_components ;;
            0) 
                echo -e "${GREEN}¡Hasta luego!${NC}"
                echo "Recomendaciones:"
                echo "1. Cierra la sesión y vuelve a iniciar para aplicar todos los cambios"
                echo "2. Ejecuta 'source ~/.zshrc' o reinicia tu terminal para cargar la configuración de Zsh"
                echo "3. Para usar Docker sin sudo, necesitarás reiniciar tu sesión"
                echo "4. Para VirtualBox, es posible que necesites reiniciar para cargar los módulos del kernel"
                exit 0
                ;;
            *) error "Opción no válida" ;;
        esac
        
        read -p "Presiona Enter para continuar..."
    done
}

# Ejecutar función principal
main
