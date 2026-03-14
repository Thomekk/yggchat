cat > ~/.yggchat/yggchat.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/.yggchat
echo "Ваш адрес: $(cat address.txt)"
echo "1) Запустить сервер (ждать подключения)"
echo "2) Подключиться к собеседнику"
read -p "Выберите (1/2): " mode
if [ "$mode" = "1" ]; then
    python3 -c '
import socket
HOST = "::"
PORT = 9999
server = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((HOST, PORT))
server.listen(1)
print("Ожидание подключения...")
conn, addr = server.accept()
print("Подключился:", addr[0])
while True:
    try:
        data = conn.recv(1024).decode()
        if not data: break
        print("\rСобеседник:", data)
        print("Вы: ", end="", flush=True)
        msg = input()
        conn.send(msg.encode())
    except: break
'
elif [ "$mode" = "2" ]; then
    read -p "Введите IPv6 адрес собеседника: " peer
    python3 -c "
import socket, threading, sys
peer = sys.argv[1]
def receive(sock):
    while True:
        try:
            data = sock.recv(1024).decode()
            if not data: break
            print('\rСобеседник:', data)
            print('Вы: ', end='', flush=True)
        except: break
client = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
client.connect((peer, 9999))
print('Подключено!')
threading.Thread(target=receive, args=(client,), daemon=True).start()
while True:
    msg = input('Вы: ')
    client.send(msg.encode())
" "$peer"
fi
EOF

chmod +x ~/.yggchat/yggchat.sh
ln -sf ~/.yggchat/yggchat.sh $PREFIX/bin/yggchat
echo "Теперь можно запускать чат командой: yggchat"