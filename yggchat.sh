#!/bin/bash

###############################################################
#  YGGCHAT - Простой P2P чат через сеть Yggdrasil
#
#  Установка:
#    curl -LO https://github.com/Thomekk/yggchat/raw/main/yggchat.sh
#    bash yggchat.sh setup
#
#  Или одной командой:
#    curl -L https://github.com/Thomekk/yggchat/raw/main/yggchat.sh > yggchat.sh && bash yggchat.sh setup
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
    clear
    echo "========================================="
    echo "    YGGCHAT - Установка"
    echo "========================================="
    
    # Создаём директорию
    mkdir -p "$YGG_DIR"
    
    # Сохраняем скрипт
    SCRIPT_PATH="$YGG_DIR/yggchat.sh"
    if [ -f "$0" ] && [ "$0" != "bash" ]; then
        cp "$0" "$SCRIPT_PATH"
    fi
    
    echo "[1/4] Установка пакетов..."
    pkg update -y
    pkg install netcat-openbsd curl wget -y

    echo "[2/4] Установка Yggdrasil..."
    
    # Определяем архитектуру
    ARCH=$(uname -m)
    case $ARCH in
        aarch64|arm64) YGG_ARCH="arm64" ;;
        armv7*|armv8*) YGG_ARCH="arm" ;;
        x86_64) YGG_ARCH="amd64" ;;
        *) echo "Неизвестная архитектура: $ARCH"; exit 1 ;;
    esac
    
    echo "Архитектура: $ARCH -> $YGG_ARCH"
    
    # URL для скачивания
    YGG_URL="https://github.com/yggdrasil-network/yggdrasil-go/releases/latest/download/yggdrasil-linux-${YGG_ARCH}"
    YGG_BIN="$PREFIX/bin/yggdrasil"
    
    # Скачиваем бинарник
    echo "Скачивание Yggdrasil..."
    curl -L --output "$YGG_BIN" "$YGG_URL" 2>/dev/null || wget -O "$YGG_BIN" "$YGG_URL" 2>/dev/null
    
    # Проверяем что скачался бинарник, а не HTML
    FILE_TYPE=$(file "$YGG_BIN" 2>/dev/null || echo "unknown")
    if echo "$FILE_TYPE" | grep -q "ELF\|executable"; then
        chmod +x "$YGG_BIN"
        echo "✓ Yggdrasil установлен"
    else
        echo "✗ Ошибка скачивания. Пробую альтернативный метод..."
        
        # Пробуем конкретную версию
        YGG_URL="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v0.5.8/yggdrasil-linux-${YGG_ARCH}"
        curl -L --output "$YGG_BIN" "$YGG_URL" 2>/dev/null || wget -O "$YGG_BIN" "$YGG_URL" 2>/dev/null
        
        FILE_TYPE=$(file "$YGG_BIN" 2>/dev/null || echo "unknown")
        if echo "$FILE_TYPE" | grep -q "ELF\|executable"; then
            chmod +x "$YGG_BIN"
            echo "✓ Yggdrasil установлен"
        else
            echo "✗ Не удалось скачать Yggdrasil автоматически"
            echo "Скачайте вручную с:"
            echo "https://github.com/yggdrasil-network/yggdrasil-go/releases"
            echo "и положите в: $YGG_BIN"
            exit 1
        fi
    fi

    echo "[3/4] Генерация конфигурации..."
    yggdrasil -genconf > "$YGG_CONF" 2>/dev/null
    
    if [ ! -s "$YGG_CONF" ]; then
        echo "✗ Ошибка генерации конфигурации"
        exit 1
    fi
    echo "✓ Конфигурация создана"

    echo "[4/4] Создание команд..."
    
    # Удаляем старые алиасы
    sed -i '/alias yggchat/d' "$BASHRC" 2>/dev/null
    sed -i '/alias yggip/d' "$BASHRC" 2>/dev/null
    sed -i '/alias yggstart/d' "$BASHRC" 2>/dev/null
    sed -i '/alias yggsstop/d' "$BASHRC" 2>/dev/null
    
    # Создаём алиасы
    echo "alias yggchat='bash $SCRIPT_PATH'" >> "$BASHRC"
    echo "alias yggip='cat $ADDR_FILE 2>/dev/null || echo Запустите yggstart'" >> "$BASHRC"
    echo "alias yggstart='nohup yggdrasil -useconff $YGG_CONF >/dev/null 2>&1 & echo \$! > $YGG_DIR/ygg.pid; sleep 5; ip -6 addr show 2>/dev/null | grep -o \"inet6 [23][0-9a-f:]*\" | head -1 | cut -d\" \" -f2 | tee $ADDR_FILE; echo \"\"" >> "$BASHRC"
    echo "alias yggstop='kill \$(cat $YGG_DIR/ygg.pid 2>/dev/null) 2>/dev/null; rm -f $YGG_DIR/ygg.pid; echo Остановлено'" >> "$BASHRC"
    
    # Создаём скрипты запуска (как backup)
    cat > "$YGG_DIR/start.sh" << 'EOF'
#!/bin/bash
nohup yggdrasil -useconff ~/.yggchat/yggdrasil.conf >/dev/null 2>&1 &
echo $! > ~/.yggchat/ygg.pid
sleep 5
IP=$(ip -6 addr show 2>/dev/null | grep -o "inet6 [23][0-9a-f:]*" | head -1 | cut -d" " -f2)
echo "$IP" > ~/.yggchat/my_ip
echo "Yggdrasil запущен"
echo "Ваш IP: $IP"
EOF
    chmod +x "$YGG_DIR/start.sh"
    
    echo "✓ Команды созданы"

    echo ""
    echo "========================================="
    echo "    ✓ УСТАНОВКА ЗАВЕРШЕНА"
    echo "========================================="
    echo ""
    echo "Выполните:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Затем:"
    echo "  yggstart  - Запустить сеть"
    echo "  yggip     - Показать ваш IP"
    echo "  yggchat   - Начать чат"
    echo ""
    exit 0
}

# Получение Yggdrasil IP
get_ip() {
    ip -6 addr show 2>/dev/null | grep -oP 'inet6 \K[23][0-9a-f:]+' | head -1
}

# Основная логика чата
run_chat() {
    clear
    
    MY_IP=$(get_ip)
    if [ -z "$MY_IP" ]; then
        echo "Ошибка: Yggdrasil IP не найден."
        echo ""
        echo "Сначала запустите сеть:"
        echo "  bash ~/.yggchat/start.sh"
        echo ""
        echo "Или добавьте алиасы:"
        echo "  source ~/.bashrc"
        exit 1
    fi

    echo "╔════════════════════════════════════════════════════"
    echo "║         🌳 YGGDRASIL P2P CHAT                    ║"
    echo "╠════════════════════════════════════════════════════"
    echo "║  Ваш IP: $MY_IP"
    echo "║  Порт:   $PORT"
    echo "╚════════════════════════════════════════════════════"
    echo ""

    # Выбор режима
    echo "Режим работы:"
    echo "  1) Ожидать подключения (сервер)"
    echo "  2) Подключиться к другу (клиент)"
    echo ""
    read -p "Выбор [1/2]: " mode

    if [ "$mode" == "1" ]; then
        run_server
    elif [ "$mode" == "2" ]; then
        run_client
    else
        echo "Неверный выбор"
        exit 1
    fi
}

# Режим сервера
run_server() {
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  Отправьте другу ваш IP: $MY_IP"
    echo "  Друг должен выбрать режим 2 и ввести этот IP"
    echo "════════════════════════════════════════════════════"
    echo ""
    echo "[*] Ожидание подключения друга... (Ctrl+C выход)"
    echo ""
    
    # Создаём FIFO для двусторонней связи
    FIFO="$YGG_DIR/chat_fifo"
    rm -f "$FIFO"
    mkfifo "$FIFO"
    
    # Запускаем слушателя
    nc -l -p $PORT > "$FIFO" 2>/dev/null &
    NC_PID=$!
    
    # Читаем входящие в фоне
    (while read line; do
        echo -e "\r\033[K\033[32m[Друг]\033[0m: $line"
        echo -ne "\033[33m>\033[0m "
    done < "$FIFO") &
    READ_PID=$!
    
    cleanup() {
        kill $NC_PID $READ_PID 2>/dev/null
        rm -f "$FIFO"
        echo -e "\nЧат завершён."
        exit 0
    }
    trap cleanup INT
    
    sleep 1
    echo -ne "\033[33m>\033[0m "
    
    # После первого подключения друга - переподключаемся к нему
    while true; do
        read msg
        if [ -n "$msg" ]; then
            # Пытаемся отправить на порт друга
            echo "$msg" | nc -q 0 ${FRIEND_IP:-127.0.0.1} $PORT 2>/dev/null || true
        fi
    done
}

# Режим клиента
run_client() {
    # Ввод адреса
    if [ -f "$CONTACTS" ]; then
        LAST=$(cat "$CONTACTS")
        echo ""
        echo "Последний собеседник: $LAST"
        read -p "Использовать его? (y/n): " use_old
    fi

    if [[ "$use_old" != "y" ]]; then
        echo ""
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
    echo "[*] Подключение к $target:$PORT ..."
    echo ""
    
    # Создаём FIFO
    FIFO="$YGG_DIR/chat_fifo"
    rm -f "$FIFO"
    mkfifo "$FIFO"
    
    # Подключаемся к серверу и слушаем
    (echo "CONNECTED" | nc -q 0 $target $PORT 2>/dev/null) &
    
    sleep 1
    
    # Запускаем слушателя
    nc -l -p $PORT > "$FIFO" 2>/dev/null &
    NC_PID=$!
    
    (while read line; do
        echo -e "\r\033[K\033[32m[Друг]\033[0m: $line"
        echo -ne "\033[33m>\033[0m "
    done < "$FIFO") &
    READ_PID=$!
    
    cleanup() {
        kill $NC_PID $READ_PID 2>/dev/null
        rm -f "$FIFO"
        echo -e "\nЧат завершён."
        exit 0
    }
    trap cleanup INT
    
    echo "[*] Чат активен. Пишите сообщения! (Ctrl+C выход)"
    echo -ne "\033[33m>\033[0m "
    
    while true; do
        read msg
        if [ -n "$msg" ]; then
            echo "$msg" | nc -q 0 $target $PORT 2>/dev/null || \
            echo -e "\r\033[KНе удалось отправить"
            echo -ne "\033[33m>\033[0m "
        fi
    done
}

# Проверка аргументов
if [ "$1" == "setup" ]; then
    setup_chat
else
    run_chat
fi
