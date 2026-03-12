#!/bin/bash

###############################################################
#  YGGCHAT - Простой P2P чат через Yggdrasil (ОДИН ФАЙЛ)
#
#  Установка:
#    curl -LO https://github.com/Thomekk/yggchat/raw/main/yggchat.sh && bash yggchat.sh setup
#
#  Запуск:
#    yggchat
#
###############################################################

YGG_DIR="$HOME/.yggchat"
YGG_CONF="$YGG_DIR/yggdrasil.conf"
ADDR_FILE="$YGG_DIR/my_ip"
CONTACTS="$HOME/.yggchat_contacts"
PORT=4891

setup() {
    mkdir -p "$YGG_DIR"
    
    echo "[*] Установка пакетов..."
    pkg update && pkg install netcat-openbsd curl -y

    echo "[*] Установка Yggdrasil..."
    ARCH=$(uname -m)
    case $ARCH in aarch64|arm64) A="arm64" ;; arm*) A="arm" ;; x86_64) A="amd64" ;; *) echo "Архитектура не поддерживается"; exit 1 ;; esac
    
    curl -Lo $PREFIX/bin/yggdrasil "https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.8/yggdrasil-linux-$A"
    chmod +x $PREFIX/bin/yggdrasil
    
    # Проверка
    if ! file $PREFIX/bin/yggdrasil | grep -q ELF; then
        echo "Ошибка скачивания. Скачайте вручную: https://github.com/yggdrasil-network/yggdrasil-go/releases"
        exit 1
    fi

    echo "[*] Генерация конфига..."
    yggdrasil -genconf > "$YGG_CONF"

    echo "[*] Создание команд..."
    sed -i '/alias yggchat/d; /alias yggstart/d; /alias yggip/d' ~/.bashrc
    echo "alias yggchat='bash $YGG_DIR/yggchat.sh'" >> ~/.bashrc
    echo "alias yggstart='yggdrasil -useconff $YGG_CONF &>/dev/null & sleep 5; ip -6 a | grep -om1 \"inet6 [23][0-9a-f:]*\" | cut -d\" \" -f2 | tee $ADDR_FILE'" >> ~/.bashrc
    echo "alias yggip='cat $ADDR_FILE'" >> ~/.bashrc
    
    # Копируем этот скрипт
    cp "$0" "$YGG_DIR/yggchat.sh"
    chmod +x "$YGG_DIR/yggchat.sh"

    echo "[!] Готово! Выполните: source ~/.bashrc"
    echo "[!] Затем: yggstart && yggchat"
}

get_ip() { ip -6 a 2>/dev/null | grep -om1 "inet6 [23][0-9a-f:]*" | cut -d" " -f2; }

chat() {
    clear
    IP=$(get_ip)
    [ -z "$IP" ] && echo "Ошибка: нет IP. Запустите yggstart" && exit 1
    
    echo "════════════════════════════════════════"
    echo "  🌳 YGGCHAT | IP: $IP"
    echo "════════════════════════════════════════"
    echo "  1) Ждать друга (сервер)"
    echo "  2) Подключиться (клиент)"
    echo "────────────────────────────────────────"
    read -p "Выбор: " m
    
    if [ "$m" = "1" ]; then
        echo "Отправьте IP другу: $IP"
        echo "Ожидание... (Ctrl+C выход)"
        nc -lkp $PORT | while read l; do echo -e "\n[Друг]: $l"; echo -n "> "; done &
        trap "kill $! 2>/dev/null; echo; exit" INT
        while read -p "> " m; do [ -n "$m" ] && echo "$m" | nc -q0 localhost $PORT 2>/dev/null; done
    elif [ "$m" = "2" ]; then
        [ -f "$CONTACTS" ] && echo "Последний: $(cat $CONTACTS)" && read -p "Использовать? (y/n): " u
        [ "$u" = "y" ] && T=$(cat $CONTACTS) || read -p "IP друга: " T
        [ -z "$T" ] && exit 1
        echo "$T" > "$CONTACTS"
        echo "Подключение к $T..."
        nc -lkp $PORT | while read l; do echo -e "\n[Друг]: $l"; echo -n "> "; done &
        trap "kill $! 2>/dev/null; echo; exit" INT
        while read -p "> " m; do [ -n "$m" ] && echo "$m" | nc -q0 $T $PORT 2>/dev/null; done
    fi
}

[ "$1" = "setup" ] && setup || chat
