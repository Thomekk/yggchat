#!/bin/bash

#######################################################################
#  YGGCHAT - P2P Чат через сеть Yggdrasil для Termux
#  Версия: 2.0
#  Автор: Thomekk
#######################################################################

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Конфигурация
YGGCHAT_DIR="$HOME/.yggchat"
YGGDRASIL_DIR="$HOME/.yggdrasil"
MY_ADDRESS_FILE="$YGGCHAT_DIR/my_address.txt"
CONTACTS_FILE="$YGGCHAT_DIR/contacts.txt"
HISTORY_DIR="$YGGCHAT_DIR/history"
PORT=9999
SCRIPT_PATH="/data/data/com.termux/files/usr/bin/yggchat"

#######################################################################
#  ЛОГОТИП
#######################################################################
show_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
██╗   ██╗ ██████╗ ██╗  ██╗██╗    ██╗     
╚██╗ ██╔╝██╔═══██╗╚██╗██╔╝██║    ██║     
 ╚████╔╝ ██║   ██║ ╚███╔╝ ██║ █╗ ██║     
  ╚██╔╝  ██║   ██║ ██╔██╗ ██║███╗██║     
   ██║   ╚██████╔╝██╔╝ ██╗╚███╔███╔╝     
   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚══╝╚══╝      
                                         
    P2P Chat · Yggdrasil Network
EOF
    echo -e "${NC}"
}

#######################################################################
#  ИНИЦИАЛИЗАЦИЯ
#######################################################################
init_yggchat() {
    mkdir -p "$YGGCHAT_DIR"
    mkdir -p "$HISTORY_DIR"
    mkdir -p "$YGGDRASIL_DIR"
    
    # Создаём файл контактов если нет
    [ ! -f "$CONTACTS_FILE" ] && touch "$CONTACTS_FILE"
}

#######################################################################
#  ПОЛУЧЕНИЕ YGGDRASIL АДРЕСА
#######################################################################
get_ygg_address() {
    local ygg_addr=""
    
    # Способ 1: через ip command (tun0 интерфейс)
    if [ -z "$ygg_addr" ]; then
        ygg_addr=$(ip -6 addr show tun0 2>/dev/null | grep -oP 'inet6 \K[23][0-9a-f:]+' | grep -v '^fe80' | head -1)
    fi
    
    # Способ 2: через все интерфейсы
    if [ -z "$ygg_addr" ]; then
        ygg_addr=$(ip -6 addr show 2>/dev/null | grep -oP 'inet6 \K[23][0-9a-f:]+' | grep -v '^fe80' | head -1)
    fi
    
    # Способ 3: через yggdrasilctl
    if [ -z "$ygg_addr" ] && [ -x "/data/data/com.termux/files/usr/bin/yggdrasilctl" ]; then
        ygg_addr=$(/data/data/com.termux/files/usr/bin/yggdrasilctl getSelf 2>/dev/null | grep -oP 'address[:\s]+\K[0-9a-f:]+' | head -1)
    fi
    
    echo "$ygg_addr"
}

#######################################################################
#  СОХРАНЕНИЕ АДРЕСА В ФАЙЛ
#######################################################################
save_my_address() {
    local addr=$(get_ygg_address)
    if [ -n "$addr" ]; then
        echo "$addr" > "$MY_ADDRESS_FILE"
        echo "$addr"
    fi
}

#######################################################################
#  ЧТЕНИЕ СОХРАНЁННОГО АДРЕСА
#######################################################################
load_my_address() {
    if [ -f "$MY_ADDRESS_FILE" ]; then
        cat "$MY_ADDRESS_FILE"
    fi
}

#######################################################################
#  УСТАНОВКА ЗАВИСИМОСТЕЙ
#######################################################################
install_deps() {
    local need_install=0
    
    if ! command -v python3 &> /dev/null; then
        need_install=1
    fi
    
    if [ $need_install -eq 1 ]; then
        echo -e "${CYAN}Установка зависимостей...${NC}"
        pkg install python -y 2>/dev/null
    fi
}

#######################################################################
#  УСТАНОВКА YGGDRASIL
#######################################################################
install_yggdrasil() {
    # Проверяем, установлен ли уже
    if [ -x "/data/data/com.termux/files/usr/bin/yggdrasil" ]; then
        echo -e "${GREEN}✓ Yggdrasil уже установлен${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Установка Yggdrasil...${NC}"
    
    # Устанавливаем зависимости для сборки
    pkg install golang git make -y 2>/dev/null
    
    cd $HOME
    
    # Клонируем репозиторий
    if [ ! -d "$HOME/yggdrasil-go" ]; then
        echo -e "${CYAN}Скачивание исходного кода...${NC}"
        git clone https://github.com/yggdrasil-network/yggdrasil-go
    fi
    
    cd yggdrasil-go
    
    # Компилируем
    echo -e "${CYAN}Компиляция (подождите)...${NC}"
    ./build 2>/dev/null
    
    if [ -f "./yggdrasil" ]; then
        cp yggdrasil /data/data/com.termux/files/usr/bin/
        cp yggdrasilctl /data/data/com.termux/files/usr/bin/
        chmod +x /data/data/com.termux/files/usr/bin/yggdrasil
        chmod +x /data/data/com.termux/files/usr/bin/yggdrasilctl
        echo -e "${GREEN}✓ Yggdrasil установлен успешно!${NC}"
        return 0
    else
        echo -e "${RED}✗ Ошибка компиляции${NC}"
        return 1
    fi
}

#######################################################################
#  ГЕНЕРАЦИЯ КОНФИГА YGGDRASIL
#######################################################################
generate_ygg_config() {
    if [ ! -f "$YGGDRASIL_DIR/config.conf" ]; then
        echo -e "${CYAN}Генерация конфигурации...${NC}"
        yggdrasil -genconf > "$YGGDRASIL_DIR/config.conf" 2>/dev/null
        
        # Добавляем публичные пиры для подключения к сети
        local peers='Peers: [\n      "tls://yggpeer.za.gy:443"\n      "tls://yggdrasil.su:8443"\n      "tls://bombadil.zxxia.com:8443"\n    ]'
        sed -i "s/Peers: \[.*\]/$peers/" "$YGGDRASIL_DIR/config.conf" 2>/dev/null
        
        echo -e "${GREEN}✓ Конфигурация создана${NC}"
    fi
}

#######################################################################
#  ЗАПУСК YGGDRASIL
#######################################################################
start_yggdrasil() {
    if pgrep -f "yggdrasil" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Yggdrasil уже запущен${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Запуск Yggdrasil...${NC}"
    
    # Генерируем конфиг если нет
    [ ! -f "$YGGDRASIL_DIR/config.conf" ] && generate_ygg_config
    
    # Запускаем в фоне
    yggdrasil -useconffile "$YGGDRASIL_DIR/config.conf" > /dev/null 2>&1 &
    
    sleep 3
    
    if pgrep -f "yggdrasil" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Yggdrasil запущен!${NC}"
        
        # Сохраняем адрес
        local addr=$(save_my_address)
        if [ -n "$addr" ]; then
            echo -e "${GREEN}✓ Ваш адрес: ${YELLOW}$addr${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Не удалось запустить Yggdrasil${NC}"
        return 1
    fi
}

#######################################################################
#  ОСТАНОВКА YGGDRASIL
#######################################################################
stop_yggdrasil() {
    if pgrep -f "yggdrasil" > /dev/null 2>&1; then
        pkill -f "yggdrasil"
        echo -e "${GREEN}✓ Yggdrasil остановлен${NC}"
    else
        echo -e "${YELLOW}Yggdrasil не запущен${NC}"
    fi
}

#######################################################################
#  ДОБАВИТЬ КОНТАКТ
#######################################################################
add_contact() {
    local name="$1"
    local addr="$2"
    
    # Убираем квадратные скобки если есть
    addr=$(echo "$addr" | tr -d '[]')
    
    # Проверяем, нет ли уже такого
    if grep -q "^$addr" "$CONTACTS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Контакт уже существует${NC}"
        return
    fi
    
    echo "$addr|$name" >> "$CONTACTS_FILE"
    echo -e "${GREEN}✓ Контакт '$name' добавлен${NC}"
}

#######################################################################
#  ПОКАЗАТЬ СПИСОК КОНТАКТОВ
#######################################################################
show_contacts() {
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  КОНТАКТЫ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ ! -s "$CONTACTS_FILE" ]; then
        echo -e "${YELLOW}Список контактов пуст${NC}"
        echo -e "${CYAN}Используйте 'yggchat add' чтобы добавить контакт${NC}"
        return
    fi
    
    local i=1
    while IFS='|' read -r addr name; do
        echo -e "  ${GREEN}$i${NC}) ${CYAN}$name${NC}"
        echo -e "     ${YELLOW}$addr${NC}"
        ((i++))
    done < "$CONTACTS_FILE"
    
    echo ""
}

#######################################################################
#  ПОЛУЧИТЬ АДРЕС КОНТАКТА ПО НОМЕРУ
#######################################################################
get_contact_addr() {
    local num=$1
    local i=1
    while IFS='|' read -r addr name; do
        if [ $i -eq $num ]; then
            echo "$addr"
            return
        fi
        ((i++))
    done < "$CONTACTS_FILE"
}

#######################################################################
#  P2P ЧАТ - ОБА ПОЛЬЗОВАТЕЛЯ СЕРВЕРЫ
#######################################################################
run_chat() {
    local peer_addr="$1"
    local my_addr=$(load_my_address)
    
    # Убираем квадратные скобки
    peer_addr=$(echo "$peer_addr" | tr -d '[]')
    
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  P2P ЧАТ АКТИВЕН${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Ваш адрес:${NC}    ${YELLOW}$my_addr${NC}"
    echo -e "${CYAN}Собеседник:${NC}  ${YELLOW}$peer_addr${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Оба подключены к сети Yggdrasil${NC}"
    echo -e "${YELLOW}Для выхода нажмите Ctrl+C${NC}"
    echo ""
    
    # Запускаем Python P2P чат
    python3 << PYTHON_P2P
import socket
import threading
import sys
import os
import time

MY_ADDR = "$my_addr"
PEER_ADDR = "$peer_addr"
PORT = 9999
HISTORY_FILE = "$HISTORY_DIR/" + PEER_ADDR.replace(":", "_") + ".txt"

def save_message(direction, msg):
    try:
        with open(HISTORY_FILE, "a") as f:
            timestamp = time.strftime("%H:%M")
            f.write(f"[{timestamp}] {direction}: {msg}\n")
    except:
        pass

def server_thread():
    """Слушаем входящие соединения"""
    try:
        server = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("::", PORT))
        server.listen(1)
        server.settimeout(1)
        
        while running:
            try:
                conn, addr = server.accept()
                data = conn.recv(4096).decode()
                if data:
                    print(f"\r\033[95mСобеседник:\033[0m {data}")
                    print("\033[94mВы:\033[0m ", end="", flush=True)
                    save_message("Собеседник", data)
                conn.close()
            except socket.timeout:
                continue
            except:
                continue
        server.close()
    except Exception as e:
        pass

def send_message(peer, msg):
    """Отправить сообщение собеседнику"""
    try:
        client = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        client.settimeout(5)
        client.connect((peer, PORT))
        client.send(msg.encode())
        client.close()
        return True
    except:
        return False

# Глобальный флаг для остановки
running = True

# Запускаем сервер в отдельном потоке
server = threading.Thread(target=server_thread, daemon=True)
server.start()

print("\033[92m✓ Сервер запущен, ожидание сообщений...\033[0m")
print("\033[92m✓ Можете отправлять сообщения\033[0m")
print("")

# Главный цикл отправки
try:
    while True:
        try:
            msg = input("\033[94mВы:\033[0m ")
            if msg.strip():
                if send_message(PEER_ADDR, msg):
                    save_message("Вы", msg)
                else:
                    print("\033[91m✗ Не удалось доставить сообщение\033[0m")
        except KeyboardInterrupt:
            running = False
            print("\n\033[93mЗавершение чата...\033[0m")
            break
        except EOFError:
            break
except:
    pass

running = False
PYTHON_P2P
}

#######################################################################
#  МЕНЮ ДОБАВЛЕНИЯ КОНТАКТА
#######################################################################
menu_add_contact() {
    echo ""
    echo -ne "${CYAN}Имя контакта: ${NC}"
    read name
    
    if [ -z "$name" ]; then
        echo -e "${RED}Имя не введено${NC}"
        return
    fi
    
    echo -ne "${CYAN}Yggdrasil адрес: ${NC}"
    read addr
    
    if [ -z "$addr" ]; then
        echo -e "${RED}Адрес не введён${NC}"
        return
    fi
    
    add_contact "$name" "$addr"
}

#######################################################################
#  МЕНЮ ЧАТА
#######################################################################
menu_chat() {
    show_contacts
    
    if [ ! -s "$CONTACTS_FILE" ]; then
        echo -ne "${CYAN}Введите адрес собеседника: ${NC}"
        read peer_addr
    else
        echo -ne "${CYAN}Выберите номер контакта или введите адрес: ${NC}"
        read choice
        
        # Проверяем, это число или адрес
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            peer_addr=$(get_contact_addr "$choice")
            if [ -z "$peer_addr" ]; then
                echo -e "${RED}Контакт не найден${NC}"
                return
            fi
        else
            peer_addr="$choice"
        fi
    fi
    
    # Убираем квадратные скобки
    peer_addr=$(echo "$peer_addr" | tr -d '[]')
    
    if [ -z "$peer_addr" ]; then
        echo -e "${RED}Адрес не указан${NC}"
        return
    fi
    
    run_chat "$peer_addr"
}

#######################################################################
#  ГЛАВНОЕ МЕНЮ
#######################################################################
show_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  МЕНЮ${NC}"
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Показываем статус Yggdrasil
        if pgrep -f "yggdrasil" > /dev/null 2>&1; then
            local addr=$(load_my_address)
            echo -e "${GREEN}✓ Yggdrasil: активен${NC}"
            echo -e "${GREEN}✓ Ваш адрес: ${YELLOW}${addr}${NC}"
        else
            echo -e "${RED}✗ Yggdrasil: не запущен${NC}"
        fi
        
        echo ""
        echo -e "  ${GREEN}1${NC}) Начать чат"
        echo -e "  ${GREEN}2${NC}) Контакты"
        echo -e "  ${GREEN}3${NC}) Добавить контакт"
        echo -e "  ${GREEN}4${NC}) Мой адрес"
        echo -e "  ${GREEN}5${NC}) Запустить Yggdrasil"
        echo -e "  ${GREEN}6${NC}) Остановить Yggdrasil"
        echo -e "  ${GREEN}7${NC}) Установить Yggdrasil"
        echo -e "  ${GREEN}8${NC}) Справка"
        echo -e "  ${GREEN}0${NC}) Выход"
        echo ""
        echo -ne "${YELLOW}Выберите: ${NC}"
        read choice
        
        case $choice in
            1)
                menu_chat
                ;;
            2)
                show_contacts
                ;;
            3)
                menu_add_contact
                ;;
            4)
                local addr=$(load_my_address)
                echo ""
                echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${GREEN}  ВАШ АДРЕС YGGDRASIL:${NC}"
                echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}  $addr${NC}"
                echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${CYAN}Отправьте этот адрес собеседнику!${NC}"
                ;;
            5)
                start_yggdrasil
                ;;
            6)
                stop_yggdrasil
                ;;
            7)
                install_yggdrasil
                generate_ygg_config
                start_yggdrasil
                ;;
            8)
                show_help
                ;;
            0|q|exit)
                echo -e "${GREEN}До свидания!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор${NC}"
                ;;
        esac
    done
}

#######################################################################
#  СПРАВКА
#######################################################################
show_help() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  КОМАНДЫ YGGCHAT${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}yggchat${NC}           - Открыть меню"
    echo -e "  ${GREEN}yggchat chat${NC}      - Начать чат"
    echo -e "  ${GREEN}yggchat add${NC}       - Добавить контакт"
    echo -e "  ${GREEN}yggchat contacts${NC}  - Список контактов"
    echo -e "  ${GREEN}yggchat address${NC}   - Показать мой адрес"
    echo -e "  ${GREEN}yggchat start${NC}     - Запустить Yggdrasil"
    echo -e "  ${GREEN}yggchat stop${NC}      - Остановить Yggdrasil"
    echo -e "  ${GREEN}yggchat install${NC}   - Установить Yggdrasil"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  КАК ИСПОЛЬЗОВАТЬ${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}1. Оба пользователя запускают:${NC}"
    echo -e "   ${YELLOW}yggchat${NC}"
    echo ""
    echo -e "${CYAN}2. При первом запуске Yggdrasil установится автоматически${NC}"
    echo ""
    echo -e "${CYAN}3. Обменяйтесь адресами друг с другом${NC}"
    echo ""
    echo -e "${CYAN}4. Добавьте адрес собеседника в контакты${NC}"
    echo ""
    echo -e "${CYAN}5. Начните чат - выберите контакт${NC}"
    echo ""
    echo -e "${CYAN}P2P: Оба пользователя являются серверами.${NC}"
    echo -e "${CYAN}Сообщения отправляются напрямую на сервер собеседника.${NC}"
    echo ""
}

#######################################################################
#  ПОКАЗАТЬ АДРЕС
#######################################################################
show_address() {
    local addr=$(load_my_address)
    if [ -z "$addr" ]; then
        addr=$(save_my_address)
    fi
    
    if [ -n "$addr" ]; then
        echo -e "${GREEN}Ваш Yggdrasil адрес:${NC}"
        echo -e "${YELLOW}$addr${NC}"
    else
        echo -e "${RED}Не удалось получить адрес. Yggdrasil запущен?${NC}"
    fi
}

#######################################################################
#  ПЕРВАЯ УСТАНОВКА
#######################################################################
first_run_setup() {
    # Проверяем, установлен ли Yggdrasil
    if [ ! -x "/data/data/com.termux/files/usr/bin/yggdrasil" ]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  ПЕРВЫЙ ЗАПУСК - УСТАНОВКА${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        install_deps
        install_yggdrasil
        generate_ygg_config
        start_yggdrasil
        
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  УСТАНОВКА ЗАВЕРШЕНА!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        sleep 2
    fi
    
    # Проверяем, запущен ли Yggdrasil
    if ! pgrep -f "yggdrasil" > /dev/null 2>&1; then
        echo -e "${CYAN}Запуск Yggdrasil...${NC}"
        start_yggdrasil
        sleep 2
    fi
    
    # Сохраняем адрес
    save_my_address > /dev/null 2>&1
}

#######################################################################
#  УСТАНОВКА СКРИПТА В СИСТЕМУ
#######################################################################
install_script() {
    # Копируем скрипт в систему если запускаем через curl
    if [ "$0" != "$SCRIPT_PATH" ] && [ "$0" != "bash" ]; then
        cp "$0" "$SCRIPT_PATH" 2>/dev/null
        chmod +x "$SCRIPT_PATH" 2>/dev/null
    fi
}

#######################################################################
#  ГЛАВНАЯ ФУНКЦИЯ
#######################################################################
main() {
    # Инициализация
    init_yggchat
    install_script
    
    # Обработка аргументов
    case "$1" in
        chat|c)
            install_deps
            first_run_setup
            menu_chat
            ;;
        add|a)
            menu_add_contact
            ;;
        contacts|list|l)
            show_contacts
            ;;
        address|addr|me)
            show_address
            ;;
        start|s)
            start_yggdrasil
            ;;
        stop)
            stop_yggdrasil
            ;;
        install|i)
            install_deps
            install_yggdrasil
            generate_ygg_config
            start_yggdrasil
            show_address
            ;;
        help|h|--help|-h)
            show_logo
            show_help
            ;;
        "")
            show_logo
            install_deps
            first_run_setup
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
