# -*- coding: utf-8 -*-
import socket, threading, select, signal, sys, time, getopt, argparse
try:
    import _thread as thread
except ImportError:
    import thread

# Parse arguments cleanly for BOTH positional args (e.g. 'python PDirect.py 80 22') AND flag args ('-p 80 -l 22')
parser = argparse.ArgumentParser()
parser.add_argument("pos_port", nargs="?", default=None, help="Puerto de escucha de socks")
parser.add_argument("pos_local", nargs="?", default=None, help="Puerto local a redirigir")
parser.add_argument("-l", "--local", default=None, help="Puerto local")
parser.add_argument("-p", "--port", default=None, help="Puerto de escucha")
parser.add_argument("-c", "--contr", default="", help="Contraseña X-Pass")
parser.add_argument("-r", "--response", default="200", help="Código de respuesta HTTP")
parser.add_argument("-t", "--texto", default=None, help="Texto de respuesta HTTP")

args, unknown = parser.parse_known_args()

# Determinar Puerto de Escucha
if args.port:
    LISTENING_PORT = int(args.port)
elif args.pos_port:
    LISTENING_PORT = int(args.pos_port)
else:
    LISTENING_PORT = 80

# Determinar Puerto Local (Destino)
if args.local:
    target_port = args.local
elif args.pos_local:
    target_port = args.pos_local
else:
    target_port = "22"

DEFAULT_HOST = '127.0.0.1:' + str(target_port)
LISTENING_ADDR = '0.0.0.0'
PASS = str(args.contr) if args.contr else ""

BUFLEN = 4096 * 4
TIMEOUT = 60

STATUS_RESP = args.response if args.response else '200'

if args.texto:
    STATUS_TXT = args.texto
elif STATUS_RESP == '101':
    STATUS_TXT = '<font color="red">Switching Protocols</font>'
else:
    STATUS_TXT = '<font color="red">Connection established</font>'

RESPONSE = str('HTTP/1.1 ' + STATUS_RESP + ' ' + STATUS_TXT + '\r\nContent-length: 0\r\n\r\nHTTP/1.1 200 Connection established\r\n\r\n').encode('latin1')

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except AttributeError:
            pass
        self.soc.settimeout(2)
        try:
            self.soc.bind((self.host, self.port))
        except Exception as e:
            print(f"Error al enlazar puerto {self.port}: {e}")
            sys.exit(1)
            
        self.soc.listen(128)
        self.running = True

        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue

                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def printLog(self, log):
        self.logLock.acquire()
        print(log)
        self.logLock.release()

    def addConn(self, conn):
        try:
            self.threadsLock.acquire()
            if self.running:
                self.threads.append(conn)
        finally:
            self.threadsLock.release()

    def removeConn(self, conn):
        try:
            self.threadsLock.acquire()
            if conn in self.threads:
                self.threads.remove(conn)
        finally:
            self.threadsLock.release()

    def close(self):
        try:
            self.running = False
            self.threadsLock.acquire()

            threads = list(self.threads)
            for c in threads:
                c.close()
        finally:
            self.threadsLock.release()


class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = ''
        self.server = server
        self.log = 'Connection: ' + str(addr)

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except:
            pass
        finally:
            self.clientClosed = True

        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except:
            pass
        finally:
            self.targetClosed = True

    def run(self):
        try:
            raw_data = self.client.recv(BUFLEN)
            if not raw_data:
                return
            self.client_buffer = raw_data.decode('latin1', errors='ignore')

            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')

            if hostPort == '':
                hostPort = DEFAULT_HOST

            split = self.findHeader(self.client_buffer, 'X-Split')

            if split != '':
                self.client.recv(BUFLEN)

            if hostPort != '':
                passwd = self.findHeader(self.client_buffer, 'X-Pass')
                
                if len(PASS) != 0 and passwd == PASS:
                    self.method_CONNECT(hostPort)
                elif len(PASS) != 0 and passwd != PASS:
                    self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif hostPort.startswith('127.0.0.1') or hostPort.startswith('localhost'):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')

        except Exception as e:
            self.log += ' - error: ' + str(e)
            self.server.printLog(self.log)
            pass
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(header + ': ')

        if aux == -1:
            return ''

        aux = head.find(':', aux)
        head = head[aux+2:]
        aux = head.find('\r\n')

        if aux == -1:
            return ''

        return head[:aux]

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i+1:])
            host = host[:i]
        else:
            port = 443

        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host, port)[0]

        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.log += ' - CONNECT ' + path

        self.connect_target(path)
        self.client.sendall(RESPONSE)
        self.client_buffer = ''

        self.server.printLog(self.log)
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]

                            count = 0
                        else:
                            break
                    except:
                        error = True
                        break
            if count == TIMEOUT:
                error = True

            if error:
                break

def main():
    print(f"\n:-------PythonProxy (Python 3)-------:\n")
    print(f"Listening addr: {LISTENING_ADDR}")
    print(f"Listening port: {LISTENING_PORT}\n")
    print(f"Target host: {DEFAULT_HOST}\n")
    print(f":-----------------------------------:\n")

    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()

    while True:
        try:
            time.sleep(2)
        except KeyboardInterrupt:
            print('Stopping...')
            server.close()
            break

if __name__ == '__main__':
    main()
