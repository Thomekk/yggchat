#!/bin/bash

#######################################################################
#  YGGCHAT - Простой чат через сеть Yggdrasil для Termux
#  Версия: 1.0
#  Автор: Thomekk
#######################################################################

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Конфигурация
YGGCHAT_DIR="$HOME/.yggchat"
YGGDRASIL_DIR="$HOME/.yggdrasil"
YGGDRASIL_BIN="/data/data/com.termux/files/usr/bin/yggdrasil"
YGGDRASILCTL_BIN="/data/data/com.termux/files/usr/bin/yggdrasilctl"
PORT=9999
SCRIPT_PATH="/data/data/com.termux/files/usr/bin/yggchat"

# Очистка экрана и показ логотипа
show_logo() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
   ██╗   ██╗ ██████╗ ██╗██████╗  █████╗ 
   ╚██╗ ██╔╝██╔═══██╗██║██╔══██╗██╔══██╗
    ╚████╔╝ ██║   ██║██║██║  ██║███████║
     ╚██╔╝  ██║   ██║██║██║  ██║██╔══██║
      ██║   ╚██████╔╝██║██████╔╝██║  ██║
      ╚═╝    ╚═════╝ ╚═╝╚═════╝ ╚═╝  ╚═╝
                    
         🌐 Чат через сеть Yggdrasil
EOF
    echo -e "${NC}"
}

# Показать статус сети Yggdrasil
show_status() {
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  СТАТУС СЕТИ YGGDRASIL${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Проверяем, запущен ли Yggdrasil
    if pgrep -f "yggdrasil" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Yggdrasil запущен${NC}"
        
        # Получаем адрес через yggdrasilctl или ip
        local ygg_addr=""
        
        # Пытаемся через yggdrasilctl
        if [ -x "$YGGDRASILCTL_BIN" ]; then
            ygg_addr=$($YGGDRASILCTL_BIN getSelf 2>/dev/null | grep -oP 'address[:\s]+\K[0-9a-f:]+' | head -1)
        fi
        
        # Если не получилось, пробуем через ip
        if [ -z "$ygg_addr" ]; then
            ygg_addr=$(ip -6 addr show 2>/dev/null | grep -oP 'inet6 \K[23][0-9a-f:]+' | grep -v '^fe80' | head -1)
        fi
        
        # Если всё ещё пусто, ищем tun интерфейс
        if [ -z "$ygg_addr" ]; then
            ygg_addr=$(ip -6 addr show tun0 2>/dev/null | grep -oP 'inet6 \K[0-9a-f:]+' | grep -v '^fe80' | head -1)
        fi
        
        if [ -n "$ygg_addr" ]; then
            echo -e ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}  ВАШ YGGDRASIL АДРЕС:${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BOLD}${YELLOW}  $ygg_addr${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e ""
            echo -e "${CYAN}Отправьте этот адрес собеседнику!${NC}"
            echo -e ""
        else
            echo -e "${YELLOW}! Не удалось определить адрес${NC}"
            echo -e "${CYAN}Попробуйте: ip -6 addr${NC}"
        fi
    else
        echo -e "${RED}✗ Yggdrasil не запущен${NC}"
        echo -e "${CYAN}Нужно установить и запустить Yggdrasil${NC}"
    fi
}

# Установка Yggdrasil
install_yggdrasil() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  УСТАНОВКА YGGDRASIL${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Проверяем наличие Go
    if ! command -v go &> /dev/null; then
        echo -e "${CYAN}Установка Go...${NC}"
        pkg install golang -y
    fi
    
    # Проверяем наличие git
    if ! command -v git &> /dev/null; then
        echo -e "${CYAN}Установка Git...${NC}"
        pkg install git -y
    fi
    
    echo -e "${CYAN}Скачивание Yggdrasil...${NC}"
    cd $HOME
    
    if [ -d "$HOME/yggdrasil-go" ]; then
        echo -e "${CYAN}Обновление существующего репозитория...${NC}"
        cd yggdrasil-go && git pull
    else
        git clone https://github.com/yggdrasil-network/yggdrasil-go
        cd yggdrasil-go
    fi
    
    echo -e "${CYAN}Компиляция Yggdrasil (это может занять несколько минут)...${NC}"
    ./build
    
    if [ -f "./yggdrasil" ]; then
        cp yggdrasil /data/data/com.termux/files/usr/bin/
        cp yggdrasilctl /data/data/com.termux/files/usr/bin/
        chmod +x /data/data/com.termux/files/usr/bin/yggdrasil
        chmod +x /data/data/com.termux/files/usr/bin/yggdrasilctl
        echo -e "${GREEN}✓ Yggdrasil установлен!${NC}"
    else
        echo -e "${RED}✗ Ошибка компиляции${NC}"
        return 1
    fi
}

# Генерация конфига Yggdrasil
generate_config() {
    echo -e "${CYAN}Генерация конфигурации Yggdrasil...${NC}"
    
    mkdir -p "$YGGDRASIL_DIR"
    
    if [ ! -f "$YGGDRASIL_DIR/config.conf" ]; then
        yggdrasil -genconf > "$YGGDRASIL_DIR/config.conf"
        
        # Добавляем публичные пиры
        echo -e "${CYAN}Добавление публичных пиров...${NC}"
        sed -i 's/Peers:\s*\[/Peers: [\n      "tls:\/\/yggpeer.za.gy:443"\n      "tls:\/\/yggdrasil.su:8443"/' "$YGGDRASIL_DIR/config.conf"
        
        echo -e "${GREEN}✓ Конфигурация создана${NC}"
    else
        echo -e "${GREEN}✓ Конфигурация уже существует${NC}"
    fi
}

# Запуск Yggdrasil
start_yggdrasil() {
    if ! pgrep -f "yggdrasil" > /dev/null 2>&1; then
        echo -e "${CYAN}Запуск Yggdrasil...${NC}"
        
        if [ ! -f "$YGGDRASIL_DIR/config.conf" ]; then
            generate_config
        fi
        
        yggdrasil -useconffile "$YGGDRASIL_DIR/config.conf" &
        sleep 2
        
        if pgrep -f "yggdrasil" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Yggdrasil запущен!${NC}"
        else
            echo -e "${RED}✗ Ошибка запуска Yggdrasil${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Yggdrasil уже запущен${NC}"
    fi
}

# Остановка Yggdrasil
stop_yggdrasil() {
    echo -e "${CYAN}Остановка Yggdrasil...${NC}"
    pkill -f "yggdrasil"
    echo -e "${GREEN}✓ Yggdrasil остановлен${NC}"
}

# Установка зависимостей
install_deps() {
    echo -e "${CYAN}Проверка зависимостей...${NC}"
    
    # Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${CYAN}Установка Python...${NC}"
        pkg install python -y
    fi
    
    # Netcat (опционально)
    if ! command -v nc &> /dev/null; then
        echo -e "${CYAN}Установка netcat-openbsd...${NC}"
        pkg install netcat-openbsd -y
    fi
    
    # lsof
    if ! command -v lsof &> /dev/null; then
        pkg install lsof -y
    fi
    
    echo -e "${GREEN}✓ Все зависимости установлены${NC}"
}

# Запуск сервера чата
run_server() {
    show_logo
    show_status
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  РЕЖИМ СЕРВЕРА (Ожидание подключения)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Отправьте ваш адрес собеседнику!${NC}"
    echo -e "${YELLOW}Он должен подключиться командой: yggchat connect${NC}"
    echo ""
    echo -e "${GREEN}Ожидание подключения на порту $PORT...${NC}"
    echo ""
    
    python3 << 'PYTHON_SERVER'
import socket
import sys
import os

HOST = "::"
PORT = 9999

try:
    server = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)
    
    print("\033[92m" + "✓ Сервер запущен, ожидание подключения..." + "\033[0m")
    print("")
    
    conn, addr = server.accept()
    
    print("\033[92m" + "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" + "\033[0m")
    print("\033[92m" + "✓ ПОДКЛЮЧИЛСЯ: " + str(addr[0]) + "\033[0m")
    print("\033[92m" + "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" + "\033[0m")
    print("")
    print("\033[96m" + "Чат активен! Пишите сообщения." + "\033[0m")
    print("\033[93m" + "Для выхода нажмите Ctrl+C" + "\033[0m")
    print("")
    
    import threading
    
    def receive_messages(sock):
        while True:
            try:
                data = sock.recv(1024).decode()
                if not data:
                    print("\n\033[91m" + "Собеседник отключился" + "\033[0m")
                    break
                print("\r\033[95m" + "Собеседник: " + "\033[0m" + data)
                print("\033[94m" + "Вы: " + "\033[0m", end="", flush=True)
            except:
                break
    
    receiver = threading.Thread(target=receive_messages, args=(conn,), daemon=True)
    receiver.start()
    
    while True:
        try:
            msg = input("\033[94mВы: \033[0m")
            if msg:
                conn.send(msg.encode())
        except KeyboardInterrupt:
            print("\n\033[93m" + "Завершение чата..." + "\033[0m")
            break
        except:
            break
    
    conn.close()
    server.close()

except OSError as e:
    if e.errno == 98:
        print("\033[91m" + "✗ Порт уже занят! Попробуйте:" + "\033[0m")
        print("  lsof -i :9999")
        print("  kill -9 <PID>")
    else:
        print(f"\033[91m✗ Ошибка: {e}\033[0m")
except Exception as e:
    print(f"\033[91m✗ Ошибка: {e}\033[0m")
PYTHON_SERVER
}

# Запуск клиента чата
run_client() {
    show_logo
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  РЕЖИМ КЛИЕНТА (Подключение к серверу)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Запрашиваем адрес
    echo -ne "${YELLOW}Введите адрес собеседника: ${NC}"
    read HOST
    
    # Убираем квадратные скобки если есть
    HOST=$(echo "$HOST" | tr -d '[]')
    
    if [ -z "$HOST" ]; then
        echo -e "${RED}✗ Адрес не введён${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}Подключение к $HOST:$PORT...${NC}"
    
    python3 << PYTHON_CLIENT
import socket
import threading
import sys

HOST = "$HOST"
PORT = 9999

try:
    client = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    client.settimeout(10)
    client.connect((HOST, PORT))
    client.settimeout(None)
    
    print("\033[92m" + "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" + "\033[0m")
    print("\033[92m" + "✓ ПОДКЛЮЧЕНО К: " + HOST + "\033[0m")
    print("\033[92m" + "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" + "\033[0m")
    print("")
    print("\033[96m" + "Чат активен! Пишите сообщения." + "\033[0m")
    print("\033[93m" + "Для выхода нажмите Ctrl+C" + "\033[0m")
    print("")
    
    def receive_messages(sock):
        while True:
            try:
                data = sock.recv(1024).decode()
                if not data:
                    print("\n\033[91m" + "Собеседник отключился" + "\033[0m")
                    break
                print("\r\033[95m" + "Собеседник: " + "\033[0m" + data)
                print("\033[94m" + "Вы: " + "\033[0m", end="", flush=True)
            except:
                break
    
    receiver = threading.Thread(target=receive_messages, args=(client,), daemon=True)
    receiver.start()
    
    while True:
        try:
            msg = input("\033[94mВы: \033[0m")
            if msg:
                client.send(msg.encode())
        except KeyboardInterrupt:
            print("\n\033[93m" + "Завершение чата..." + "\033[0m")
            break
        except:
            break
    
    client.close()

except socket.timeout:
    print("\033[91m" + "✗ Таймаут подключения. Проверьте адрес." + "\033[0m")
except ConnectionRefusedError:
    print("\033[91m" + "✗ Отказ в подключении. Сервер не запущен?" + "\033[0m")
except Exception as e:
    print(f"\033[91m✗ Ошибка подключения: {e}\033[0m")
    print("\033[93m" + "Проверьте:" + "\033[0m")
    print("  1. Правильность адреса")
    print("  2. Запущен ли Yggdrasil")
    print("  3. Запущен ли сервер у собеседника")
PYTHON_CLIENT
}

# Показать справку
show_help() {
    show_logo
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  КОМАНДЫ YGGCHAT${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}yggchat${NC}           - Показать меню"
    echo -e "${GREEN}yggchat server${NC}   - Создать чат (сервер)"
    echo -e "${GREEN}yggchat connect${NC}  - Подключиться к чату"
    echo -e "${GREEN}yggchat status${NC}   - Показать статус и адрес"
    echo -e "${GREEN}yggchat start${NC}    - Запустить Yggdrasil"
    echo -e "${GREEN}yggchat stop${NC}     - Остановить Yggdrasil"
    echo -e "${GREEN}yggchat install${NC}  - Установить Yggdrasil"
    echo -e "${GREEN}yggchat help${NC}     - Показать справку"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  КАК ИСПОЛЬЗОВАТЬ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}1. Первый пользователь:${NC}"
    echo -e "   ${YELLOW}yggchat server${NC}"
    echo -e "   (отправьте адрес собеседнику)"
    echo ""
    echo -e "${CYAN}2. Второй пользователь:${NC}"
    echo -e "   ${YELLOW}yggchat connect${NC}"
    echo -e "   (введите адрес собеседника)"
    echo ""
    echo -e "${CYAN}3. Общайтесь!${NC}"
    echo ""
}

# Показать меню
show_menu() {
    show_logo
    show_status
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  МЕНЮ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) Создать чат (сервер)"
    echo -e "  ${GREEN}2${NC}) Подключиться к чату"
    echo -e "  ${GREEN}3${NC}) Запустить Yggdrasil"
    echo -e "  ${GREEN}4${NC}) Остановить Yggdrasil"
    echo -e "  ${GREEN}5${NC}) Установить Yggdrasil"
    echo -e "  ${GREEN}6${NC}) Справка"
    echo -e "  ${GREEN}0${NC}) Выход"
    echo ""
    echo -ne "${YELLOW}Выберите действие: ${NC}"
    read choice
    
    case $choice in
        1) run_server ;;
        2) run_client ;;
        3) start_yggdrasil; sleep 2; show_menu ;;
        4) stop_yggdrasil; sleep 1; show_menu ;;
        5) install_yggdrasil; generate_config; start_yggdrasil; sleep 2; show_menu ;;
        6) show_help; echo -ne "${YELLOW}Нажмите Enter для возврата...${NC}"; read; show_menu ;;
        0) echo -e "${GREEN}До свидания!${NC}"; exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}"; sleep 1; show_menu ;;
    esac
}

# Установка скрипта в систему
install_script() {
    # Создаём директорию для yggchat
    mkdir -p "$YGGCHAT_DIR"
    
    # Копируем скрипт в систему
    if [ "$0" != "$SCRIPT_PATH" ]; then
        cp "$0" "$SCRIPT_PATH" 2>/dev/null
        chmod +x "$SCRIPT_PATH" 2>/dev/null
    fi
    
    # Проверяем, добавлена ли команда в PATH
    if ! command -v yggchat &> /dev/null; then
        # Добавляем алиас в bashrc
        echo "alias yggchat='$SCRIPT_PATH'" >> "$HOME/.bashrc"
        echo "alias yggchat='$SCRIPT_PATH'" >> "$HOME/.bash_profile" 2>/dev/null
    fi
}

# Главная функция
main() {
    # Устанавливаем скрипт при первом запуске
    install_script
    
    # Устанавливаем зависимости
    install_deps
    
    # Обработка аргументов
    case "$1" in
        server|s|1)
            run_server
            ;;
        connect|c|2)
            run_client
            ;;
        status)
            show_logo
            show_status
            ;;
        start)
            start_yggdrasil
            show_status
            ;;
        stop)
            stop_yggdrasil
            ;;
        install|i)
            install_yggdrasil
            generate_config
            start_yggdrasil
            show_status
            ;;
        help|h|?|-h|--help)
            show_help
            ;;
        "")
            show_menu
            ;;
        *)
            echo -e "${RED}Неизвестная команда: $1${NC}"
            echo -e "${CYAN}Используйте: yggchat help${NC}"
            ;;
    esac
}

# Запуск
main "$@"
