#!/bin/bash

###############################################################
#  YGGCHAT - Простой P2P чат через Yggdrasil
#
#  Установка одной командой:
#    curl -L https://github.com/Thomekk/yggchat/raw/main/yggchat.sh | bash
#
#  Запуск чата:
#    yggchat
#
###############################################################

YGG_DIR="$HOME/.yggchat"
YGG_CONF="$YGG_DIR/yggdrasil.conf"
ADDR_FILE="$YGG_DIR/my_ip"
CONTACTS="$HOME/.yggchat_contacts"
PORT=4891
SCRIPT_FILE="$YGG_DIR/yggchat.sh"

setup() {
    clear
    echo "════════════════════════════════════════"
    echo "      🌳 YGGCHAT - Установка"
    echo "════════════════════════════════════════"
    
    mkdir -p "$YGG_DIR"
    
    # Сначала сохраняем этот скрипт
    echo "[1/5] Сохранение скрипта..."
    cat "$0" > "$SCRIPT_FILE" 2>/dev/null || curl -L -o "$SCRIPT_FILE" https://github.com/Thomekk/yggchat/raw/main/yggchat.sh 2>/dev/null
    chmod +x "$SCRIPT_FILE"
    
    # Пакеты
    echo "[2/5] Пакеты..."
    pkg update -y
    pkg install netcat-openbsd curl wget binutils iproute2 -y

    # Архитектура
    echo "[3/5] Yggdrasil..."
    ARCH=$(uname -m)
    case $ARCH in
        aarch64|arm64) DEB="yggdrasil-0.5.13-arm64.deb" ;;
        armv7*|armv8*) DEB="yggdrasil-0.5.13-armhf.deb" ;;
        x86_64) DEB="yggdrasil-0.5.13-amd64.deb" ;;
        *)
            echo "✗ Архитектура не поддерживается: $ARCH"
            return 1
            ;;
    esac
    echo "   Архитектура: $ARCH"

    # Скачиваем .deb
    if ! command -v yggdrasil &>/dev/null; then
        echo "   Скачивание $DEB ..."
        cd "$YGG_DIR"
        curl -L -o ygg.deb "https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.13/$DEB"
        echo "   Распаковка..."
        ar x ygg.deb
        tar xf data.tar.*
        cp usr/bin/yggdrasil $PREFIX/bin/
        chmod +x $PREFIX/bin/yggdrasil
        rm -rf ygg.deb control.tar.* data.tar.* usr
        cd ~
    fi
    
    if command -v yggdrasil &>/dev/null; then
        echo "   ✓ Yggdrasil установлен"
    else
        echo "   ✗ Ошибка установки Yggdrasil"
        return 1
    fi

    # Конфиг
    echo "[4/5] Конфигурация..."
    yggdrasil -genconf > "$YGG_CONF" 2>/dev/null
    [ ! -s "$YGG_CONF" ] && echo "✗ Ошибка конфига" && return 1
    echo "   ✓ Конфиг создан"

    # Алиасы (исправленный флаг -useconffile)
    echo "[5/5] Команды..."
    sed -i '/alias ygg/d' ~/.bashrc 2>/dev/null
    echo "alias yggchat='bash $SCRIPT_FILE'" >> ~/.bashrc
    echo "alias yggstart='yggdrasil -useconffile $YGG_CONF &>/dev/null & sleep 5; ip -6 a | grep -om1 \"inet6 [23].*\" | cut -d\" \" -f2 | tee $ADDR_FILE'" >> ~/.bashrc
    echo "alias yggip='cat $ADDR_FILE 2>/dev/null'" >> ~/.bashrc
    echo "alias yggstop='pkill yggdrasil'" >> ~/.bashrc
    echo "   ✓ Команды созданы"

    echo ""
    echo "════════════════════════════════════════"
    echo "      ✓ УСТАНОВКА ЗАВЕРШЕНА"
    echo "════════════════════════════════════════"
    echo ""
    echo "Теперь выполните:"
    echo ""
    echo "  source ~/.bashrc"
    echo "  yggstart"
    echo "  yggchat"
    echo ""
}

get_ip() { 
    ip -6 a 2>/dev/null | grep -om1 "inet6 [23][0-9a-f:]*" | cut -d" " -f2
}

chat() {
    clear
    IP=$(get_ip)
    if [ -z "$IP" ]; then
        echo "════════════════════════════════════════"
        echo " Нет Yggdrasil IP!"
        echo "════════════════════════════════════════"
        echo ""
        echo "Выполните:"
        echo "  yggstart"
        echo ""
        echo "Или вручную:"
        echo "  yggdrasil -useconffile $YGG_CONF &"
        echo "  sleep 10"
        echo ""
        exit 1
    fi
    
    echo "════════════════════════════════════════"
    echo "  🌳 YGGCHAT"
    echo "  Ваш IP: $IP"
    echo "════════════════════════════════════════"
    echo "  1) Ждать друга (сервер)"
    echo "  2) Подключиться (клиент)"
    echo "────────────────────────────────────────"
    read -p "Выбор: " m
    
    if [ "$m" = "1" ]; then
        echo ""
        echo "────────────────────────────────────────"
        echo " Отправьте другу IP: $IP"
        echo " Друг выбирает: 2 и вводит этот IP"
        echo "────────────────────────────────────────"
        echo " Ожидание... (Ctrl+C выход)"
        echo ""
        nc -lkp $PORT | while read l; do 
            echo -e "\n[Друг]: $l"
            echo -n "> "
        done &
        trap "kill $! 2>/dev/null; echo; exit" INT
        while read -p "> " m; do 
            [ -n "$m" ] && echo "$m" | nc -q0 localhost $PORT 2>/dev/null
        done
        
    elif [ "$m" = "2" ]; then
        if [ -f "$CONTACTS" ]; then
            LAST=$(cat "$CONTACTS")
            echo "Последний: $LAST"
            read -p "Использовать? (y/n): " u
        fi
        [ "$u" = "y" ] && T="$LAST" || read -p "IP друга: " T
        [ -z "$T" ] && exit 1
        echo "$T" > "$CONTACTS"
        echo "Подключение к $T..."
        nc -lkp $PORT | while read l; do 
            echo -e "\n[Друг]: $l"
            echo -n "> "
        done &
        trap "kill $! 2>/dev/null; echo; exit" INT
        while read -p "> " m; do 
            [ -n "$m" ] && echo "$m" | nc -q0 $T $PORT 2>/dev/null
        done
    fi
}

# Запуск
if [ "$1" = "setup" ]; then
    setup
elif [ "$1" = "chat" ]; then
    chat
elif [ -f "$YGG_CONF" ] && command -v yggdrasil &>/dev/null && [ -f "$SCRIPT_FILE" ]; then
    chat
else
    setup
fi
