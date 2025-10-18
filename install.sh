#!/bin/bash

printf "You're on Syntax-Recorder installer\n"
printf "Sit and chill while we carry out all the nerd part :)\n"

printf "\nBefore continuing:\nIf a dependency isn't found, the installer will install it.\n"
read -p "Accept? [Y/n]: " choice

if [[ -z "$choice" || "$choice" =~ ^[Yy]$ ]]; then
    accept=true
    printf "\nWonderful! ^_^\n"
else
    accept=false
    printf "\nOkay! Just keep in mind that you'll need to install all dependencies manually to avoid errors! ;)\n"
fi

# Função para checar se o comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para instalar pacotes
install() {
    PACKAGE="$1"

    if [ -z "$PACKAGE" ]; then
        echo -e "[\e[31mERROR\e[0m]: No package specified. Aborting..."
        return 1
    fi

    # Detecta distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=$ID
    else
        echo -e "[\e[31mERROR\e[0m]: Could not detect Linux distro. Aborting..."
        return 1
    fi

    if command_exists "$PACKAGE"; then
        echo -e "[\e[32mINFO\e[0m]: '$PACKAGE' is already installed."
        return 0
    fi

    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint)
            echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' with apt..."
            sudo apt update
            sudo apt install -y "$PACKAGE"
            ;;
        fedora)
            echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' with dnf..."
            sudo dnf install -y "$PACKAGE"
            ;;
        centos|rhel)
            echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' with yum..."
            sudo yum install -y "$PACKAGE"
            ;;
        arch|manjaro)
            echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' with pacman..."
            sudo pacman -S --noconfirm "$PACKAGE" || true

            if ! command_exists "$PACKAGE"; then
                if command_exists yay; then
                    echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' from AUR with yay..."
                    yay -S --noconfirm "$PACKAGE"
                else
                    echo -e "[\e[33mWARN\e[0m]: '$PACKAGE' may be in the AUR, but 'yay' is not installed."
                fi
            fi
            ;;
        opensuse*|suse)
            echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' with zypper..."
            sudo zypper install -y "$PACKAGE"
            ;;
        alpine)
            echo -e "[\e[34mINFO\e[0m]: Installing '$PACKAGE' with apk..."
            sudo apk add "$PACKAGE"
            ;;
        *)
            echo -e "[\e[31mERROR\e[0m]: Distro not supported: '$DISTRO_ID'. Aborting..."
            return 1
            ;;
    esac
}

# Criação de pasta e clonagem do repositório
printf "\nStarting installation...\n"
sleep 1

echo -e "[\e[34mINFO\e[0m]: Creating config folder..."
mkdir -p ~/syntax-recorder
sleep 1
cd ~/syntax-recorder || exit 1

if [ "$accept" = true ]; then
    if ! command_exists git; then
        echo -e "[\e[33mWARN\e[0m]: Git not found! Installing..."
        install git
        sleep 1
    fi

    echo -e "[\e[34mINFO\e[0m]: Cloning repository..."
    git clone https://github.com/synt-xerror/syntax-recorder || echo -e "[\e[33mWARN\e[0m]: Repository may already exist."
else
    if ! command_exists git; then
        echo -e "[\e[33mWARN\e[0m]: Git not found! Aborting..."
        exit 1
    fi
fi

cd syntax-recorder || exit 1

echo -e "[\e[34mINFO\e[0m]: Copying script to binary folder... (you may need to enter your password)"
sudo cp -i record.sh /usr/bin/record

if [ "$accept" = true ]; then
    echo -e "[\e[34mINFO\e[0m]: Installing dependencies..."
    install gpu-screen-recorder
    install arecord
    install ffmpeg
else
    echo -e "[\e[33mWARN\e[0m]: Skipped installing dependencies."
fi

echo -e "[\e[32mSUCCESS\e[0m]: Installation completed successfully! Use the command 'record' to start recording."
