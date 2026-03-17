#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== Yggdrasil + Чат: установка в Termux ==="

# 1. Проверка, что мы в Termux
if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
    echo "Ошибка: этот скрипт предназначен для Termux."
    exit 1
fi

# 2. Установка зависимостей
echo "Установка необходимых пакетов (wget, binutils, tar)..."
pkg update -y
pkg install -y wget binutils tar

# 3. Завершаем старые процессы Yggdrasil (если есть)
if pgrep -x "yggdrasil" > /dev/null; then
    echo "Обнаружен запущенный процесс Yggdrasil. Останавливаем..."
    pkill -x "yggdrasil"
    sleep 2
fi

# 4. Определение архитектуры
ARCH=$(uname -m)
case "$ARCH" in
    aarch64) YGG_ARCH="arm64" ;;
    armv7l|armhf) YGG_ARCH="armhf" ;;
    x86_64) YGG_ARCH="amd64" ;;
    i686) YGG_ARCH="386" ;;
    *) echo "Архитектура $ARCH не поддерживается."; exit 1 ;;
esac
echo "Определена архитектура: $YGG_ARCH"

# 5. Загрузка Yggdrasil
VER="0.5.13"
BASE_URL="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v${VER}"
FILE="yggdrasil-${VER}-${YGG_ARCH}.deb"
URL="${BASE_URL}/${FILE}"

echo "Загрузка $FILE ..."
wget "$URL" -O "$FILE" --show-progress

if [ ! -s "$FILE" ]; then
    echo "Ошибка: файл $FILE не загружен или пуст."
    exit 1
fi

# 6. Распаковка deb-пакета
echo "Распаковка пакета..."
ar x "$FILE"
if [ -f data.tar.gz ]; then
    tar -xzf data.tar.gz
elif [ -f data.tar.xz ]; then
    tar -xJf data.tar.xz
else
    echo "Не найден data.tar внутри deb-пакета."
    exit 1
fi

# 7. Копирование бинарников
echo "Копирование исполняемых файлов в $PREFIX/bin ..."
cp -f usr/bin/yggdrasil "$PREFIX/bin/"
cp -f usr/bin/yggdrasilctl "$PREFIX/bin/"
chmod +x "$PREFIX/bin/yggdrasil" "$PREFIX/bin/yggdrasilctl"

# 8. Очистка временных файлов
rm -rf usr etc data.tar.* control.tar.gz debian-binary "$FILE"

# 9. Генерация конфигурационного файла (если его нет)
CONFIG_FILE="$HOME/yggdrasil.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Генерируем базовый конфигурационный файл..."
    yggdrasil -genconf > "$CONFIG_FILE"

    # Добавляем публичные пиры для лучшей связности
    PEERS=(
        "tcp://ygg.no:10000"
        "tcp://yggdrasil.katzen.host:10000"
        "tcp://94.130.46.55:10000"
    )
    PEERS_STRING=$(printf '"%s", ' "${PEERS[@]}")
    PEERS_STRING="[${PEERS_STRING%, }]"
    sed -i "s|Peers: \[\]|Peers: $PEERS_STRING|" "$CONFIG_FILE"
else
    echo "Конфигурационный файл уже существует: $CONFIG_FILE (используем как есть)"
fi

# 10. Создание команды chat
echo "Создаём скрипт chat в $PREFIX/bin/chat ..."
cat > "$PREFIX/bin/chat" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Yggdrasil Chat Plugin for Termux (исправленная версия)
# Usage: chat

YGG_CONF="$HOME/yggdrasil.conf"
YGG_LOG="$HOME/yggdrasil.log"
CONTACTS_FILE="$HOME/.ygg_contacts"
PID_FILE="$HOME/.yggdrasil.pid"
PYTHON_CMD="python3"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ensure_python() {
    if ! command -v $PYTHON_CMD &> /dev/null; then
        echo -e "${YELLOW}Python не найден. Устанавливаем...${NC}"
        pkg update -y && pkg install -y python
    fi
}

ensure_yggdrasil_installed() {
    if ! command -v yggdrasil &> /dev/null; then
        echo -e "${RED}Yggdrasil не установлен. Сначала выполните установку.${NC}"
        exit 1
    fi
}

ensure_yggdrasil_running() {
    if pgrep -x "yggdrasil" > /dev/null; then
        echo -e "${GREEN}Yggdrasil уже запущен.${NC}"
        return 0
    fi

    echo -e "${YELLOW}Yggdrasil не запущен. Запускаем...${NC}"

    if [ ! -f "$YGG_CONF" ]; then
        echo "Генерируем новый конфигурационный файл..."
        yggdrasil -genconf > "$YGG_CONF"
        PEERS=(
            "tcp://ygg.no:10000"
            "tcp://yggdrasil.katzen.host:10000"
            "tcp://94.130.46.55:10000"
        )
        PEERS_STRING=$(printf '"%s", ' "${PEERS[@]}")
        PEERS_STRING="[${PEERS_STRING%, }]"
        sed -i "s|Peers: \[\]|Peers: $PEERS_STRING|" "$YGG_CONF"
    fi

    sed -i '/AdminListen:/d' "$YGG_CONF"
    echo 'AdminListen: "none"' >> "$YGG_CONF"

    yggdrasil -useconf "$YGG_CONF" > "$YGG_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"

    echo "Ожидаем инициализации сети..."
    local timeout=30
    local ip=""
    while [ $timeout -gt 0 ]; do
        if grep -q "Your IPv6 address is" "$YGG_LOG" 2>/dev/null; then
            ip=$(grep "Your IPv6 address is" "$YGG_LOG" | tail -1 | awk '{print $5}')
            echo -e "${GREEN}✓ Сеть Yggdrasil запущена. Ваш IPv6 адрес: $ip${NC}"
            break
        fi
        sleep 1
        ((timeout--))
    done

    if [ -z "$ip" ]; then
        echo -e "${RED}Не удалось получить IPv6 адрес за 30 секунд. Проверьте лог: $YGG_LOG${NC}"
        return 1
    fi
    return 0
}

get_my_ip() {
    if [ ! -f "$YGG_LOG" ]; then
        echo ""
        return
    fi
    grep "Your IPv6 address is" "$YGG_LOG" | tail -1 | awk '{print $5}'
}

add_contact() {
    echo "Добавление нового контакта"
    read -p "Введите имя контакта: " name
    read -p "Введите IPv6 адрес контакта: " addr
    if [[ ! "$addr" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo -e "${RED}Некорректный IPv6 адрес${NC}"
        return
    fi
    echo "$name $addr" >> "$CONTACTS_FILE"
    echo -e "${GREEN}Контакт добавлен.${NC}"
}

list_contacts() {
    if [ ! -f "$CONTACTS_FILE" ]; then
        echo "Нет сохраненных контактов."
        return
    fi
    echo "Список контактов:"
    nl "$CONTACTS_FILE" | awk '{print $1 ". " $2 " - " $3}'
}

choose_contact() {
    if [ ! -f "$CONTACTS_FILE" ]; then
        return 1
    fi
    local choice
    read -p "Выберите номер контакта (или 0 для ручного ввода): " choice </dev/tty >/dev/tty
    if [ "$choice" = "0" ]; then
        local addr
        read -p "Введите IPv6 адрес: " addr </dev/tty >/dev/tty
        echo "$addr"
    else
        local addr
        addr=$(sed -n "${choice}p" "$CONTACTS_FILE" | awk '{print $2}')
        if [ -z "$addr" ]; then
            echo -e "${RED}Неверный номер${NC}" >/dev/tty
            return 1
        fi
        echo "$addr"
    fi
}

start_chat_client() {
    local addr=$1
    if [ -z "$addr" ]; then
        list_contacts
        addr=$(choose_contact)
        local ret=$?
        if [ $ret -ne 0 ] || [ -z "$addr" ]; then
            return
        fi
    fi

    echo -e "${YELLOW}Подключаемся к $addr:9999...${NC}"
    $PYTHON_CMD -c "
import socket
import threading
import sys

HOST = '$addr'
PORT = 9999

def receive(sock):
    try:
        while True:
            data = sock.recv(1024).decode()
            if not data:
                break
            print('\r\033[0;32mСобеседник:\033[0m', data)
            print('\033[1;33mВы:\033[0m ', end='', flush=True)
    except:
        pass

try:
    client = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    client.connect((HOST, PORT))
    print('\033[0;32mПодключено к серверу!\033[0m')
except Exception as e:
    print('\033[0;31mОшибка подключения:\033[0m', e)
    sys.exit(1)

threading.Thread(target=receive, args=(client,), daemon=True).start()

try:
    while True:
        msg = input('\033[1;33mВы:\033[0m ')
        client.send(msg.encode())
except KeyboardInterrupt:
    print('\n\033[0;33mЧат завершен.\033[0m')
finally:
    client.close()
"
}

start_chat_server() {
    echo -e "${YELLOW}Запуск сервера на порту 9999...${NC}"
    $PYTHON_CMD -c "
import socket
import sys

HOST = '::'
PORT = 9999

try:
    server = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)
    print('\033[0;32mСервер запущен. Ожидание подключения...\033[0m')
    conn, addr = server.accept()
    print('\033[0;32mПодключился:\033[0m', addr[0])
except Exception as e:
    print('\033[0;31mОшибка сервера:\033[0m', e)
    sys.exit(1)

try:
    while True:
        data = conn.recv(1024).decode()
        if not data:
            break
        print('\r\033[0;32mСобеседник:\033[0m', data)
        msg = input('\033[1;33mВы:\033[0m ')
        conn.send(msg.encode())
except KeyboardInterrupt:
    print('\n\033[0;33mСервер остановлен.\033[0m')
finally:
    conn.close()
    server.close()
"
}

show_menu() {
    clear
    my_ip=$(get_my_ip)
    echo "====================================="
    echo "   Yggdrasil Чат"
    echo "====================================="
    echo -e "Ваш IPv6 адрес: ${GREEN}${my_ip:-не определен}${NC}"
    echo "-------------------------------------"
    echo "1. Показать мой IPv6 адрес"
    echo "2. Добавить контакт"
    echo "3. Список контактов"
    echo "4. Начать чат с контактом (клиент)"
    echo "5. Режим сервера (ожидать подключение)"
    echo "6. Выйти"
    echo "-------------------------------------"
    read -p "Выберите действие [1-6]: " choice
    case $choice in
        1)
            echo -e "Ваш IPv6 адрес: ${GREEN}$(get_my_ip)${NC}"
            read -p "Нажмите Enter для продолжения..."
            ;;
        2)
            add_contact
            read -p "Нажмите Enter для продолжения..."
            ;;
        3)
            list_contacts
            read -p "Нажмите Enter для продолжения..."
            ;;
        4)
            start_chat_client
            read -p "Нажмите Enter для продолжения..."
            ;;
        5)
            start_chat_server
            read -p "Нажмите Enter для продолжения..."
            ;;
        6)
            echo "Выход."
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            read -p "Нажмите Enter для продолжения..."
            ;;
    esac
}

main() {
    ensure_python
    ensure_yggdrasil_installed
    ensure_yggdrasil_running || exit 1

    while true; do
        show_menu
    done
}

main
EOF

chmod +x "$PREFIX/bin/chat"

# 11. Завершение
echo
echo "=== Установка завершена ==="
echo "Теперь вы можете запустить чат командой: chat"
echo "При первом запуске чат автоматически запустит сеть Yggdrasil и покажет ваш IPv6‑адрес."
echo "Контакты сохраняются в файле ~/.ygg_contacts"