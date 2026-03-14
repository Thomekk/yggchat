#!/usr/bin/env bash

set -e

YGGCHAT_DIR="$HOME/.yggchat"
YGGDRASIL_DIR="$HOME/.yggdrasil"
PID_FILE="$YGGDRASIL_DIR/yggdrasil.pid"
CONF_FILE="$YGGDRASIL_DIR/yggdrasil.conf"
ADDRESS_FILE="$YGGCHAT_DIR/address.txt"
PEERS_FILE="$YGGCHAT_DIR/peers.txt"
TMP_DIR="$YGGCHAT_DIR/tmp"

install() {
    echo "Установка YggChat..."

    mkdir -p "$YGGCHAT_DIR"
    mkdir -p "$YGGDRASIL_DIR/bin"
    mkdir -p "$TMP_DIR"

    echo "Установка пакетов..."
    pkg update -y
    pkg install -y python curl tar

    ARCH=$(uname -m)
    case $ARCH in
        aarch64) YGG_ARCH="arm64" ;;
        armv7l|armv8l) YGG_ARCH="armv7" ;;
        i686) YGG_ARCH="386" ;;
        x86_64) YGG_ARCH="amd64" ;;
        *) echo "Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
    esac

    YGG_VERSION="v0.5.6"
    YGG_URL="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/${YGG_VERSION}/yggdrasil-${YGG_VERSION}-linux-${YGG_ARCH}.tar.gz"
    echo "Скачивание Yggdrasil ${YGG_VERSION} для ${YGG_ARCH}..."
    curl -L "$YGG_URL" -o "$TMP_DIR/yggdrasil.tar.gz"

    tar -xzf "$TMP_DIR/yggdrasil.tar.gz" -C "$YGGDRASIL_DIR/bin" --strip-components=1
    rm -f "$TMP_DIR/yggdrasil.tar.gz"

    "$YGGDRASIL_DIR/bin/yggdrasil" -genconf > "$CONF_FILE"
    sed -i 's|"Peers": \[\]|"Peers": ["tcp://bootstrap.yggdrasil.net:80"]|' "$CONF_FILE"

    echo "Запуск Yggdrasil..."
    "$YGGDRASIL_DIR/bin/yggdrasil" -useconffile "$CONF_FILE" &> "$YGGDRASIL_DIR/yggdrasil.log" &
    YGG_PID=$!
    echo $YGG_PID > "$PID_FILE"
    sleep 5

    ADDR=$("$YGGDRASIL_DIR/bin/yggdrasilctl" getSelf | grep -i "IPv6" | awk '{print $2}' || true)
    if [ -z "$ADDR" ]; then
        echo "Не удалось получить адрес Yggdrasil. Проверьте логи: $YGGDRASIL_DIR/yggdrasil.log"
        exit 1
    fi
    echo "$ADDR" > "$ADDRESS_FILE"
    echo "Ваш адрес в сети Yggdrasil: $ADDR"
    echo "Сохранен в $ADDRESS_FILE"

    touch "$PEERS_FILE"

    # Создаём символическую ссылку, если возможно
    if [ -d "$PREFIX/bin" ]; then
        ln -sf "$YGGCHAT_DIR/yggchat.sh" "$PREFIX/bin/yggchat"
        echo "Создана ссылка: $PREFIX/bin/yggchat"
    else
        echo "Предупреждение: не удалось создать ссылку. Добавьте $YGGCHAT_DIR в PATH или запускайте скрипт напрямую."
    fi

    echo "Установка завершена. Запуск чата..."
    exec "$0"
}

start_yggdrasil() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            return 0
        fi
    fi
    echo "Запуск Yggdrasil..."
    "$YGGDRASIL_DIR/bin/yggdrasil" -useconffile "$CONF_FILE" &> "$YGGDRASIL_DIR/yggdrasil.log" &
    YGG_PID=$!
    echo $YGG_PID > "$PID_FILE"
    sleep 3
}

get_my_address() {
    if [ ! -f "$ADDRESS_FILE" ]; then
        ADDR=$("$YGGDRASIL_DIR/bin/yggdrasilctl" getSelf | grep -i "IPv6" | awk '{print $2}')
        if [ -n "$ADDR" ]; then
            echo "$ADDR" > "$ADDRESS_FILE"
        else
            echo "Не удалось получить адрес. Убедитесь, что Yggdrasil запущен."
            exit 1
        fi
    fi
    cat "$ADDRESS_FILE"
}

run_server() {
    echo "Запуск сервера чата. Ожидание подключения..."
    python3 -c '
import socket
import sys

HOST = "::"
PORT = 9999

server = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    server.bind((HOST, PORT))
except Exception as e:
    print("Ошибка привязки порта:", e)
    sys.exit(1)

server.listen(1)
print("Сервер запущен. Ожидание подключения на порту 9999...")
conn, addr = server.accept()
print("Подключился:", addr[0])

while True:
    try:
        data = conn.recv(1024).decode()
        if not data:
            break
        print("\rСобеседник:", data)
        print("Вы: ", end="", flush=True)
        msg = input()
        conn.send(msg.encode())
    except (KeyboardInterrupt, EOFError):
        break
    except:
        break

conn.close()
server.close()
'
}

run_client() {
    local PEER_ADDR="$1"
    echo "Подключение к $PEER_ADDR:9999 ..."
    python3 -c '
import socket
import threading
import sys

HOST = sys.argv[1]
PORT = 9999

def receive(sock):
    while True:
        try:
            data = sock.recv(1024).decode()
            if not data:
                break
            print("\rСобеседник:", data)
            print("Вы: ", end="", flush=True)
        except:
            break

client = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
try:
    client.connect((HOST, PORT))
except Exception as e:
    print("Ошибка подключения:", e)
    sys.exit(1)

print("Подключено к серверу!")

threading.Thread(target=receive, args=(client,), daemon=True).start()

while True:
    try:
        msg = input("Вы: ")
        client.send(msg.encode())
    except (KeyboardInterrupt, EOFError):
        break
' "$PEER_ADDR"
}

# ----------------------------------------------------------------------
# Основная логика
# ----------------------------------------------------------------------

# Если скрипт запущен из пайпа (первый запуск) — скачиваем себя и устанавливаем
if [ ! -f "$0" ] || [[ "$0" == *"bash"* ]] || [[ "$0" == "/dev/stdin" ]]; then
    echo "Первый запуск: установка YggChat..."
    mkdir -p "$YGGCHAT_DIR"
    curl -L https://github.com/Thomekk/yggchat/raw/main/yggchat.sh -o "$YGGCHAT_DIR/yggchat.sh"
    chmod +x "$YGGCHAT_DIR/yggchat.sh"
    if [ -d "$PREFIX/bin" ]; then
        ln -sf "$YGGCHAT_DIR/yggchat.sh" "$PREFIX/bin/yggchat"
    fi
    exec "$YGGCHAT_DIR/yggchat.sh" --install
fi

# Если передан ключ --install – выполняем установку
if [ "$1" == "--install" ]; then
    install
    exit 0
fi

# Иначе – обычный запуск чата
if [ ! -f "$YGGDRASIL_DIR/bin/yggdrasil" ]; then
    echo "Yggdrasil не установлен. Запустите установку: yggchat --install"
    exit 1
fi

start_yggdrasil
MY_ADDR=$(get_my_address)
echo "Ваш адрес в сети Yggdrasil: $MY_ADDR"
echo
echo "Введите адрес собеседника (IPv6) для подключения,"
echo "или нажмите Enter, чтобы ожидать входящее подключение:"
read -p "Адрес: " PEER_ADDR

if [ -z "$PEER_ADDR" ]; then
    run_server
else
    if ! grep -qxF "$PEER_ADDR" "$PEERS_FILE" 2>/dev/null; then
        echo "$PEER_ADDR" >> "$PEERS_FILE"
        echo "Адрес сохранен в $PEERS_FILE"
    fi
    run_client "$PEER_ADDR"
fi