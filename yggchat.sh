#!/data/data/com.termux/files/usr/bin/bash
set -e

YGGCHAT_DIR="$HOME/.yggchat"
YGGDRASIL_DIR="$HOME/.yggdrasil"
PID_FILE="$YGGDRASIL_DIR/yggdrasil.pid"
CONF_FILE="$YGGDRASIL_DIR/yggdrasil.conf"
ADDRESS_FILE="$YGGCHAT_DIR/address.txt"
PEERS_FILE="$YGGCHAT_DIR/peers.txt"
TMP_DIR="$YGGCHAT_DIR/tmp"
VERSION="0.5.13"

# Цвета для вывода
GREEN='\033[0;32m'
NC='\033[0m'

# Функция установки всего необходимого
install_all() {
    echo -e "${GREEN}>>> Установка YggChat...${NC}"

    mkdir -p "$YGGCHAT_DIR" "$YGGDRASIL_DIR/bin" "$TMP_DIR"

    # Установка пакетов Termux
    echo -e "${GREEN}>>> Обновление списка пакетов...${NC}"
    pkg update -y
    echo -e "${GREEN}>>> Установка python, curl, wget, tar...${NC}"
    pkg install -y python curl wget tar

    # Определение архитектуры
    ARCH=$(uname -m)
    case $ARCH in
        aarch64)  YGG_ARCH="arm64" ;;
        armv7l|armv8l) YGG_ARCH="armv7" ;;
        i686)     YGG_ARCH="386" ;;
        x86_64)   YGG_ARCH="amd64" ;;
        *) echo "Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
    esac

    # Скачивание Yggdrasil
    YGG_URL="https://github.com/yggdrasil-network/yggdrasil-go/releases/download/v${VERSION}/yggdrasil-${VERSION}-linux-${YGG_ARCH}.tar.gz"
    echo -e "${GREEN}>>> Скачивание Yggdrasil v${VERSION} для ${YGG_ARCH}...${NC}"
    wget -O "$TMP_DIR/yggdrasil.tar.gz" "$YGG_URL"

    # Распаковка
    echo -e "${GREEN}>>> Распаковка...${NC}"
    tar -xzf "$TMP_DIR/yggdrasil.tar.gz" -C "$YGGDRASIL_DIR/bin" --strip-components=1
    rm -f "$TMP_DIR/yggdrasil.tar.gz"

    # Генерация конфига
    echo -e "${GREEN}>>> Генерация конфигурации Yggdrasil...${NC}"
    "$YGGDRASIL_DIR/bin/yggdrasil" -genconf > "$CONF_FILE"
    sed -i 's|"Peers": \[\]|"Peers": ["tcp://bootstrap.yggdrasil.net:80"]|' "$CONF_FILE"

    # Запуск Yggdrasil
    start_yggdrasil

    # Получение IPv6-адреса
    echo -e "${GREEN}>>> Получение вашего адреса в сети Yggdrasil...${NC}"
    sleep 5
    MY_ADDR=$("$YGGDRASIL_DIR/bin/yggdrasilctl" getSelf 2>/dev/null | grep -i "IPv6" | awk '{print $2}')
    if [ -z "$MY_ADDR" ]; then
        echo "Не удалось получить адрес. Проверьте логи: $YGGDRASIL_DIR/yggdrasil.log"
        exit 1
    fi
    echo "$MY_ADDR" > "$ADDRESS_FILE"
    echo -e "${GREEN}✅ Ваш адрес: $MY_ADDR${NC}"
    echo -e "(сохранён в $ADDRESS_FILE)"

    # Создание файла для хранения адресов собеседников
    touch "$PEERS_FILE"

    # Создаём симлинк для команды yggchat
    if [ -d "$PREFIX/bin" ]; then
        ln -sf "$YGGCHAT_DIR/yggchat.sh" "$PREFIX/bin/yggchat"
        echo -e "${GREEN}✅ Создана команда 'yggchat'${NC}"
    else
        echo "Предупреждение: не удалось создать симлинк. Добавьте $YGGCHAT_DIR в PATH"
    fi

    echo -e "${GREEN}>>> Установка завершена!${NC}"
}

# Функция запуска Yggdrasil, если он ещё не запущен
start_yggdrasil() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            return 0
        fi
    fi
    echo -e "${GREEN}>>> Запуск Yggdrasil...${NC}"
    "$YGGDRASIL_DIR/bin/yggdrasil" -useconffile "$CONF_FILE" &> "$YGGDRASIL_DIR/yggdrasil.log" &
    YGG_PID=$!
    echo $YGG_PID > "$PID_FILE"
    sleep 3
}

# Функция получения своего адреса
get_my_address() {
    if [ ! -f "$ADDRESS_FILE" ]; then
        echo "Файл с адресом не найден. Возможно, Yggdrasil не настроен."
        exit 1
    fi
    cat "$ADDRESS_FILE"
}

# Функция сервера (ожидание подключения)
run_server() {
    echo -e "${GREEN}>>> Режим сервера. Ожидание подключения на порту 9999...${NC}"
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
print("Сервер запущен. Ожидание подключения...")
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

# Функция клиента (подключение к собеседнику)
run_client() {
    local PEER_ADDR="$1"
    echo -e "${GREEN}>>> Подключение к $PEER_ADDR:9999...${NC}"
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

    # Сохраняем адрес собеседника, если его ещё нет в списке
    if ! grep -qxF "$PEER_ADDR" "$PEERS_FILE" 2>/dev/null; then
        echo "$PEER_ADDR" >> "$PEERS_FILE"
        echo -e "${GREEN}✅ Адрес собеседника сохранён в $PEERS_FILE${NC}"
    fi
}

# ----------------------------------------------------------------------
# Основная логика
# ----------------------------------------------------------------------

# Если скрипт запущен из пайпа (первый запуск) — копируем себя в постоянное место
if [[ "$0" == *"bash"* ]] || [[ "$0" == "/dev/stdin" ]] || [ ! -f "$YGGCHAT_DIR/yggchat.sh" ]; then
    echo -e "${GREEN}Первый запуск: установка YggChat...${NC}"
    mkdir -p "$YGGCHAT_DIR"
    # Копируем текущий скрипт в ~/.yggchat/yggchat.sh
    cat > "$YGGCHAT_DIR/yggchat.sh" <<'INNEREOF'
#!/data/data/com.termux/files/usr/bin/bash
# Содержимое этого файла будет точно таким же, как и исходный скрипт.
# Для избежания рекурсии мы просто вызовем установку и затем передадим управление.
# Однако проще перезапустить этот же скрипт с флагом --install.
# Но мы уже находимся внутри выполнения, поэтому просто вызовем функцию install_all.
INNEREOF
    # Но проще: мы уже выполняем скрипт, поэтому можем прямо сейчас вызвать install_all.
    # Для этого нужно, чтобы скрипт содержал функции и далее шёл вызов.
    # Мы перезапустим скрипт с флагом --install.
    exec bash "$YGGCHAT_DIR/yggchat.sh" --install
fi

# Если передан ключ --install – выполняем установку
if [ "$1" == "--install" ]; then
    install_all
    echo -e "${GREEN}Установка завершена. Теперь можно запускать чат командой yggchat${NC}"
    exit 0
fi

# Обычный запуск чата
# Проверяем, установлен ли Yggdrasil
if [ ! -f "$YGGDRASIL_DIR/bin/yggdrasil" ]; then
    echo "Yggdrasil не найден. Запустите сначала установку: yggchat --install"
    exit 1
fi

# Запускаем Yggdrasil, если он не запущен
start_yggdrasil

# Получаем свой адрес
MY_ADDR=$(get_my_address)
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Ваш адрес в сети Yggdrasil: $MY_ADDR${NC}"
echo -e "${GREEN}================================${NC}"
echo

# Меню
echo "Выберите действие:"
echo "1) Запустить сервер (ждать входящее подключение)"
echo "2) Подключиться к собеседнику"
echo "0) Выход"
read -p "Ваш выбор (1/2/0): " choice

case $choice in
    1)
        run_server
        ;;
    2)
        # Показываем ранее сохранённые адреса
        if [ -s "$PEERS_FILE" ]; then
            echo "Сохранённые адреса собеседников:"
            cat -n "$PEERS_FILE"
        fi
        read -p "Введите IPv6-адрес собеседника: " peer
        if [ -n "$peer" ]; then
            run_client "$peer"
        else
            echo "Адрес не введён."
        fi
        ;;
    0)
        exit 0
        ;;
    *)
        echo "Неверный выбор."
        ;;
esac