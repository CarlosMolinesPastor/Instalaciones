# Instalaciones

Repositorio con los pasos de instalaciones propias

Los archivos de instalacion de archlinux son scripts de bash con la instalacion por un lado y por la otra con la configuracion de varias partes del sistema.

Se puede descargar con el comando:

```bash
git clone https://github.com/CarlosMolinesPastor/Instalaciones.git
cd Instalaciones
chmod +x *.sh
# Primero se realiza la instalacion de archlinux, que es un script con los programas y aplicaciones necesarias.
./01_install_arch.sh
# Por ultimo se procede a al configuracion de los programas y aplicaciones.
./02_conf_arch.sh
```

Conforme se actualicen las instalaciones se iran poniendo en el repositorio

La instalacion de paquetes es totalmente personalizada y es en base a la programacion y desarrollo que realizo, python, java, bash... Y los editores que utilizo, como pueden ser neovim, vscode, zed, android studio..., así como determinados servicios como nextcloud desktop, etc...

Espero que a alguien le sirva de ayuda.
