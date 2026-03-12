#!/bin/bash

###############################################################
#  YGGCHAT - Простой P2P чат через сеть Yggdrasil
#
#  Установка:
#    curl -L https://github.com/USER/yggchat/raw/main/yggchat.sh | bash -s setup
#
#  Или скачать и запустить:
#    curl -LO https://github.com/USER/yggchat/raw/main/yggchat.sh
#    bash yggchat.sh setup
#
#  Запуск:
#    yggchat
#
###############################################################

# Пути и константы
YGG_DIR="$HOME/.yggchat"
YGG_CONF="$YGG_DIR/yggdrasil.conf"
ADDR_FILE="$YGG_DIR/my_ip"
CONTACTS="$HOME/.yggchat_contacts"
BASHRC="$HOME/.bashrc"
PORT=4891

# Функция установки
setup_chat() {
    echo "[*] Установка зависимостей..."
    pkg update && pkg install netcat-openbsd curl -y

    echo "[*] Установка Yggdrasil..."
    mkdir -p "$YGG_DIR"
    
    ARCH=$(uname -m)
    case $ARCH in
        aarch64|arm64) YGG_ARCH="arm64" ;;
        armv7*|armv8*) YGG_ARCH="arm" ;;
        x86_64) YGG_ARCH="amd64" ;;
        *) echo "Неизвестная архитектура: $ARCH"; exit 1 ;;
    esac
    
    curl -L -o "$PREFIX/bin/yggdrasil" \
        "https://github.com/yggdrasil-network/yggdrasil-go/releases/latest/download/yggdrasil-linux-${YGG_ARCH}"
    chmod +x "$PREFIX/bin/yggdrasil"

    echo "[*] Генерация конфигурации..."
    yggdrasil -genconf > "$YGG_CONF"

    # Создаем алиасы
    sed -i '/alias yggchat/d' "$BASHRC"
    sed -i '/alias yggip/d' "$BASHRC"
    sed -i '/alias yggstart/d' "$BASHRC"
    echo "alias yggchat='bash $YGG_DIR/yggchat.sh'" >> "$BASHRC"
    echo "alias yggip='cat $ADDR_FILE 2>/dev/null || echo Запустите yggstart'" >> "$BASHRC"
    echo "alias yggstart='yggdrasil -useconff $YGG_CONF &>/dev/null & sleep 3; ip -6 addr | grep -o \"inet6 [23][0-9a-f:]*\" | cut -d\" \" -f2 | tee $ADDR_FILE'" >> "$BASHRC"
    
    # Копируем скрипт
    cp "$0" "$YGG_DIR/yggchat.sh" 2>/dev/null
    chmod +x "$YGG_DIR/yggchat.sh"

    echo "[!] Установка завершена. Перезапустите терминал."
    echo "[!] После перезапуска:"
    echo "    1. Запустите 'yggstart' чтобы стартануть сеть"
    echo "    2. Команда 'yggip' покажет ваш адрес"
    echo "    3. Команда 'yggchat' откроет чат"
    exit 0
}

# Получение Yggdrasil IP
get_ip() {
    ip -6 addr 2>/dev/null | grep -oP 'inet6 \K[23][0-9a-f:]+' | head -1
}

# Основная логика чата
run_chat() {
    clear
    
    MY_IP=$(get_ip)
    if [ -z "$MY_IP" ]; then
        echo "Ошибка: Yggdrasil IP не найден."
        echo "Сначала запустите 'yggstart' и подождите 10 секунд."
        exit 1
    fi

    echo "╔════════════════════════════════════════╗"
    echo "║       🌳 YGGDRASIL P2P CHAT            ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ Ваш IP: $MY_IP"
    echo "╚════════════════════════════════════════╝"

    # Выбор режима
    echo ""
    echo "Режим работы:"
    echo "  1) Ожидать подключения (сервер)"
    echo "  2) Подключиться к другу (клиент)"
    echo ""
    read -p "Выбор [1/2]: " mode

    if [ "$mode" == "1" ]; then
        # Сервер
        echo ""
        echo "Ваш IP: $MY_IP"
        echo "Отправьте этот адрес другу"
        echo "Друг должен выбрать режим 2 и ввести этот IP"
        echo ""
        echo "[*] Ожидание подключения... (Ctrl+C для выхода)"
        
        # Ждём подключения друга
        nc -l -p $PORT | while read line; do
            echo -e "\n\a[ДРУГ]: $line"
            echo -n "> "
        done &
        REC_PID=$!
        
        trap "kill $REC_PID 2>/dev/null; echo -e '\nЧат завершен.'; exit" INT
        
        # Отправка сообщений
        while true; do
            read -p "> " msg
            if [ ! -z "$msg" ]; then
                # Пытаемся отправить (друг уже подключился)
                echo "$msg" | nc -q 0 127.0.0.1 $PORT 2>/dev/null || \
                echo "Ожидание подключения друга..."
            fi
        done
        
    elif [ "$mode" == "2" ]; then
        # Клиент
        if [ -f "$CONTACTS" ]; then
            LAST=$(cat "$CONTACTS")
            echo ""
            echo "Последний собеседник: $LAST"
            read -p "Использовать его? (y/n): " use_old
        fi

        if [[ "$use_old" != "y" ]]; then
            read -p "Введите IP друга: " target
            if [ -z "$target" ]; then
                echo "Ошибка: IP не указан"
                exit 1
            fi
            echo "$target" > "$CONTACTS"
        else
            target=$(cat "$CONTACTS")
        fi

        echo ""
        echo "[*] Подключение к $target..."
        
        # Проверка соединения
        if ! timeout 5 bash -c "echo '' | nc -w 2 $target $PORT" 2>/dev/null; then
            echo "Друг ещё не запустил сервер. Ожидание..."
        fi
        
        echo "[*] Ожидание сообщений... (Ctrl+C для выхода)"
        
        # Приём сообщений
        nc -l -p $PORT | while read line; do
            echo -e "\n\a[ДРУГ]: $line"
            echo -n "> "
        done &
        REC_PID=$!
        
        trap "kill $REC_PID 2>/dev/null; echo -e '\nЧат завершен.'; exit" INT
        
        # Отправка
        while true; do
            read -p "> " msg
            if [ ! -z "$msg" ]; then
                echo "$msg" | nc -q 0 $target $PORT 2>/dev/null || \
                echo "Не удалось отправить. Друг подключен?"
            fi
        done
    else
        echo "Неверный выбор"
        exit 1
    fi
}

# Проверка аргументов
if [ "$1" == "setup" ]; then
    setup_chat
else
    run_chat
fi
