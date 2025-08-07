#!/bin/bash

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes de éxito
success() {
  echo -e "${GREEN}[✓] $1${NC}"
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
  exit 1
}

# Verificar si el script se ejecuta como root
if [ "$EUID" -eq 0 ]; then
  warning "No se recomienda ejecutar este script como root. Se solicitarán privilegios cuando sea necesario."
  read -p "¿Deseas continuar de todos modos? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Verificar que estamos en Debian
if ! grep -q "Debian" /etc/os-release; then
  error "Este script está diseñado para Debian. No se recomienda su uso en otras distribuciones."
fi

# Menú principal
echo -e "${GREEN}\nConfiguración de Debian para Desarrolladores${NC}"
echo "========================================"
echo "Este script instalará y configurará:"
echo "1. Paquetes esenciales y herramientas de desarrollo"
echo "2. Entornos de programación (C/C++, Python, Java, Node.js)"
echo "3. Docker y Docker Compose"
echo "4. IDEs (VS Code, Neovim, IntelliJ)"
echo "5. Zsh con configuración personalizada"
echo "6. Herramientas adicionales"
echo "========================================"

read -p "¿Deseas continuar con la instalación? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  exit 0
fi

# 1. Actualización del sistema e instalación de paquetes esenciales
info "Actualizando el sistema e instalando paquetes esenciales..."
sudo apt update && sudo apt upgrade -y || error "Error al actualizar el sistema"
sudo apt install -y build-essential git curl wget || error "Error al instalar paquetes esenciales"
success "Sistema actualizado y paquetes esenciales instalados"

# 2. Librerías para C/C++
info "Instalando herramientas y librerías para C/C++..."
sudo apt install -y libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
  libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev \
  autoconf automake libtool cmake || error "Error al instalar herramientas para C/C++"

# Frameworks de testing para C/C++
sudo apt install -y libcunit1-dev libgtest-dev || error "Error al instalar frameworks de testing"
success "Herramientas y librerías para C/C++ instaladas"

# 3. Python
info "Instalando Python y herramientas relacionadas..."
sudo apt install -y python3 python3-dev python3-pip python3-venv || error "Error al instalar Python"
success "Python instalado correctamente"

# 4. Java
info "Configurando Java (Temurin 17)..."
if ! sudo apt install -y wget apt-transport-https gpg; then
  error "Error al instalar dependencias para Java"
fi

# Añadir repositorio de Temurin
if [ ! -f /etc/apt/trusted.gpg.d/adoptium.gpg ]; then
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg || error "Error al añadir clave GPG"
  echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list || error "Error al añadir repositorio"
fi

sudo apt update || error "Error al actualizar repositorios"
sudo apt install -y temurin-17-jdk junit || error "Error al instalar Java"

# Configurar Java alternativo
info "Configurando Java alternativo..."
sudo update-alternatives --config java

# Configurar JAVA_HOME
JAVA_HOME_PATH=$(update-alternatives --list java | grep temurin-17 | sed 's|/bin/java||')
echo "export JAVA_HOME=$JAVA_HOME_PATH" >>~/.bashrc
echo "export JAVA_HOME=$JAVA_HOME_PATH" >>~/.zshrc
source ~/.bashrc
success "Java instalado y configurado correctamente"

# 5. Node.js & npm
info "Instalando Node.js y npm..."
read -p "¿Deseas instalar Node.js mediante nvm (recomendado)? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  sudo apt install -y npm nodejs || error "Error al instalar Node.js desde repositorios"
else
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash || error "Error al instalar nvm"
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  LTS_VERSION=$(nvm ls-remote | grep -i latest | grep -Po 'v\d+\.\d+\.\d+' | tail -n 1)
  nvm install "$LTS_VERSION" || error "Error al instalar Node.js LTS"
  nvm use "$LTS_VERSION" || error "Error al cambiar versión de Node.js"
fi
success "Node.js instalado correctamente"

# 6. Docker
info "Instalando Docker y Docker Compose..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release || error "Error al instalar dependencias de Docker"

# Añadir clave GPG de Docker
if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error "Error al añadir clave GPG de Docker"
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null || error "Error al añadir repositorio de Docker"
fi

sudo apt update || error "Error al actualizar repositorios"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || error "Error al instalar Docker"

# Añadir usuario al grupo docker
sudo usermod -aG docker $USER || error "Error al añadir usuario al grupo docker"
sudo systemctl enable docker || error "Error al habilitar Docker"
success "Docker instalado y configurado correctamente"

# 7. IDEs
info "Instalando IDEs de desarrollo..."

# Visual Studio Code
read -p "¿Instalar Visual Studio Code? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  sudo apt install -y software-properties-common apt-transport-https || error "Error al instalar dependencias para VS Code"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg || error "Error al descargar clave GPG de Microsoft"
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/ || error "Error al instalar clave GPG"
  sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list' || error "Error al añadir repositorio de VS Code"
  sudo apt update || error "Error al actualizar repositorios"
  sudo apt install -y code || error "Error al instalar VS Code"
  success "Visual Studio Code instalado correctamente"
fi

# Neovim
read -p "¿Instalar Neovim con configuración personalizada? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  sudo apt install -y neovim || error "Error al instalar Neovim"

  # Hacer backup de configuraciones existentes
  info "Haciendo backup de configuraciones existentes de Neovim..."
  [ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak
  [ -d ~/.local/share/nvim ] && mv ~/.local/share/nvim ~/.local/share/nvim.bak
  [ -d ~/.local/state/nvim ] && mv ~/.local/state/nvim ~/.local/state/nvim.bak
  [ -d ~/.cache/nvim ] && mv ~/.cache/nvim ~/.cache/nvim.bak

  # Clonar configuración personalizada
  git clone https://github.com/CarlosMolinesPastor/nvim.git ~/.config/nvim || error "Error al clonar configuración de Neovim"
  success "Neovim instalado y configurado correctamente"
fi

# IntelliJ IDEA
read -p "¿Instalar IntelliJ IDEA? [Community/Ultimate/N] " -r
case $REPLY in
[Cc]*)
  curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | sudo gpg --dearmor -o /usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg || error "Error al añadir clave GPG de JetBrains"
  echo "deb [signed-by=/usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg] http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com any main" | sudo tee /etc/apt/sources.list.d/jetbrains-ppa.list >/dev/null || error "Error al añadir repositorio de JetBrains"
  sudo apt update || error "Error al actualizar repositorios"
  sudo apt install -y intellij-idea-community || error "Error al instalar IntelliJ IDEA Community"
  success "IntelliJ IDEA Community instalado correctamente"
  ;;
[Uu]*)
  curl -s https://s3.eu-central-1.amazonaws.com/jetbrains-ppa/0xA6E8698A.pub.asc | sudo gpg --dearmor -o /usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg || error "Error al añadir clave GPG de JetBrains"
  echo "deb [signed-by=/usr/share/keyrings/jetbrains-ppa-archive-keyring.gpg] http://jetbrains-ppa.s3-website.eu-central-1.amazonaws.com any main" | sudo tee /etc/apt/sources.list.d/jetbrains-ppa.list >/dev/null || error "Error al añadir repositorio de JetBrains"
  sudo apt update || error "Error al actualizar repositorios"
  sudo apt install -y intellij-idea-ultimate || error "Error al instalar IntelliJ IDEA Ultimate"
  success "IntelliJ IDEA Ultimate instalado correctamente"
  ;;
*)
  info "Omitiendo instalación de IntelliJ IDEA"
  ;;
esac

# Ollama (IA local)
read -p "¿Instalar Ollama con modelo de IA local? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  curl -fsSL https://ollama.com/install.sh | sh || error "Error al instalar Ollama"
  info "Descargando modelo qwen2.5-coder:1.5b (esto puede tomar tiempo)..."
  ollama run qwen2.5-coder:1.5b || warning "Error al descargar el modelo, pero Ollama se instaló correctamente"
  success "Ollama instalado correctamente"
fi

# 8. Zsh y herramientas de terminal
info "Configurando Zsh y herramientas de terminal..."

# Instalar dependencias
sudo apt install -y zsh fzf ripgrep lsd bat || error "Error al instalar herramientas de terminal"

# Cambiar shell a Zsh
if [ "$SHELL" != "/usr/bin/zsh" ]; then
  info "Cambiando shell a Zsh..."
  sudo chsh -s /usr/bin/zsh $USER || error "Error al cambiar shell a Zsh"
fi

# Instalar Starship prompt
curl -sS https://starship.rs/install.sh | sh || error "Error al instalar Starship"
starship preset pastel-powerline -o ~/.config/starship.toml || warning "Error al configurar Starship, pero se instaló correctamente"

# Instalar Oh My Zsh y plugins
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" "" --unattended || error "Error al instalar Oh My Zsh"

# Plugins de Zsh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || error "Error al instalar zsh-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || error "Error al instalar zsh-autosuggestions"
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab || error "Error al instalar fzf-tab"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf || error "Error al clonar fzf"
~/.fzf/install --key-bindings --completion --no-update-rc || error "Error al instalar fzf"

# Configuración personalizada de Zsh
git clone https://github.com/CarlosMolinesPastor/zsh.git ~/zsh-config-temp || error "Error al clonar configuración de Zsh"
cp ~/zsh-config-temp/.zshrc ~/.zshrc || error "Error al copiar configuración de Zsh"
rm -rf ~/zsh-config-temp || warning "Error al limpiar archivos temporales"
success "Zsh y herramientas de terminal configuradas correctamente"

# 9. Comprobación final
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
code --version || warning "VS Code no está instalado"
nvim --version | head -n 1 || warning "Neovim no está instalado"

# Mensaje final
echo -e "${GREEN}\n¡Instalación completada con éxito!${NC}"
echo "========================================"
echo "Recomendaciones:"
echo "1. Cierra la sesión y vuelve a iniciar para aplicar todos los cambios"
echo "2. Ejecuta 'source ~/.zshrc' o reinicia tu terminal para cargar la configuración de Zsh"
echo "3. Para usar Docker sin sudo, necesitarás reiniciar tu sesión"
echo "========================================"
echo "Gracias por usar este script. ¡Feliz desarrollo!"
