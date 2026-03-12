#!/bin/bash

###############################################################
#  YGGCHAT - Одна команда для всего
#
#  Запуск:
#    curl -L https://github.com/Thomekk/yggchat/raw/main/yggchat.sh | bash
#
###############################################################

YGG_DIR="$HOME/.yggchat"
YGG_CONF="$YGG_DIR/yggdrasil.conf"
ADDR_FILE="$YGG_DIR/my_ip"
CONTACTS="$HOME/.yggchat_contacts"
PORT=4891

setup() {
    clear
    echo "════════════════════════════════════════"
    echo "      🌳 YGGCHAT - Установка"
    echo "════════════════════════════════════════"
    
    mkdir -p "$YGG_DIR"
    
    # Пакеты
    echo "[1/5] Пакеты..."
    pkg update -y
    pkg install netcat-openbsd curl wget -y

    # Архитектура
    echo "[2/5] Определение архитектуры..."
    ARCH=$(uname -m)
    case $ARCH in
        aarch64|arm64) YGG_ARCH="arm64" ;;
        armv7*|armv8*) YGG_ARCH="arm" ;;
        x86_64) YGG_ARCH="amd64" ;;
        *) 
            echo "✗ Архитектура не поддерживается: $ARCH"
            return 1
            ;;
    esac
    echo "   Обнаружена: $ARCH -> $YGG_ARCH"

    # Yggdrasil
    echo "[3/5] Yggdrasil..."
    YGG_BIN="$PREFIX/bin/yggdrasil"
    
    # Пробуем разные способы
    DOWNLOADED=0
    
    # URL вариантов
    URL1="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.8/yggdrasil-linux-$YGG_ARCH"
    URL2="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.7/yggdrasil-linux-$YGG_ARCH"
    URL3="https://github.com/yggdrasil-network/yggdrasil-go/releases/latest/download/yggdrasil-linux-$YGG_ARCH"
    
    for URL in "$URL1" "$URL2" "$URL3"; do
        echo "   Пробую: ${URL##*/}"
        
        # Curl
        curl -L -o "$YGG_BIN" --connect-timeout 15 --max-time 60 "$URL" 2>&1
        
        # Проверка файла
        if [ -f "$YGG_BIN" ]; then
            SIZE=$(stat -c%s "$YGG_BIN" 2>/dev/null || echo "0")
            TYPE=$(file "$YGG_BIN" 2>/dev/null)
            
            echo "   Размер: $SIZE байт"
            echo "   Тип: $TYPE"
            
            if echo "$TYPE" | grep -qi "ELF\|executable"; then
                chmod +x "$YGG_BIN"
                DOWNLOADED=1
                echo "   ✓ Успешно!"
                break
            elif [ "$SIZE" -gt 1000000 ]; then
                # Большой файл - скорее всего бинарник
                chmod +x "$YGG_BIN"
                if "$YGG_BIN" -version 2>/dev/null; then
                    DOWNLOADED=1
                    echo "   ✓ Успешно!"
                    break
                fi
            fi
        fi
        
        rm -f "$YGG_BIN"
    done
    
    if [ "$DOWNLOADED" = "0" ]; then
        echo ""
        echo "✗ Автоскачивание не удалось"
        echo ""
        echo "════════════════════════════════════════"
        echo " СКАЧАЙТЕ ВРУЧНУЮ:"
        echo "════════════════════════════════════════"
        echo ""
        echo "1. В браузере откройте:"
        echo "   https://github.com/yggdrasil-network/yggdrasil-go/releases"
        echo ""
        echo "2. Скачайте файл: yggdrasil-linux-$YGG_ARCH"
        echo ""
        echo "3. В Termux выполните:"
        echo "   cp ~/downloads/yggdrasil-linux-$YGG_ARCH $PREFIX/bin/yggdrasil"
        echo "   chmod +x $PREFIX/bin/yggdrasil"
        echo ""
        echo "4. Затем снова:"
        echo "   curl -L https://github.com/Thomekk/yggchat/raw/main/yggchat.sh | bash"
        echo ""
        return 1
    fi

    # Конфиг
    echo "[4/5] Конфигурация..."
    yggdrasil -genconf > "$YGG_CONF" 2>/dev/null
    if [ ! -s "$YGG_CONF" ]; then
        echo "✗ Ошибка создания конфига"
        return 1
    fi

    # Алиасы
    echo "[5/5] Команды..."
    sed -i '/alias ygg/d' ~/.bashrc 2>/dev/null
    echo "alias yggchat='bash $YGG_DIR/yggchat.sh'" >> ~/.bashrc
    echo "alias yggstart='yggdrasil -useconff $YGG_CONF &>/dev/null & sleep 5; ip -6 a | grep -om1 \"inet6 [23].*\" | cut -d\" \" -f2 | tee $ADDR_FILE'" >> ~/.bashrc
    echo "alias yggip='cat $ADDR_FILE 2>/dev/null'" >> ~/.bashrc
    echo "alias yggstop='pkill yggdrasil'" >> ~/.bashrc
    
    # Сохраняем скрипт
    cp "$0" "$YGG_DIR/yggchat.sh" 2>/dev/null
    chmod +x "$YGG_DIR/yggchat.sh"

    echo ""
    echo "════════════════════════════════════════"
    echo "      ✓ УСТАНОВКА ЗАВЕРШЕНА"
    echo "════════════════════════════════════════"
    echo ""
    echo "Выполните по очереди:"
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
        echo "Нет Yggdrasil IP!"
        echo ""
        echo "Выполните: yggstart"
        echo "Или: yggdrasil -useconff $YGG_CONF &"
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
        echo " Отправьте другу: $IP"
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
elif [ -f "$YGG_CONF" ] && command -v yggdrasil &>/dev/null; then
    chat
else
    setup
fi
