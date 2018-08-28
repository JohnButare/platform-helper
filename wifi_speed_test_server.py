import socket
import sys
from optparse import OptionParser, OptionGroup
import signal
import select
import time
from threading import Thread
import os
import re
import SocketServer
import threading
import datetime


def_port = 1212

GOOGLE_DNS = "8.8.8.8"

STOP_ALL_THREADS = False

if os.name == 'nt':
    # Windows
    DEFAULT_SOCKET_BUFFER_SIZE=262144
else:
    DEFAULT_SOCKET_BUFFER_SIZE=65536

def is_protocol_msg(msg):
    msg = msg.split(' ')
    if len(msg) != 3 and len(msg) != 4:        
        return False
    if msg[0]!= 'push':
        log_msg("Wrong protocol message, no push")
        return False
    try:
        block = int(msg[1])
        size = int(msg[2])
        if len(msg) == 4:
            udp_rate = int(msg[3])
    except Exception, e:
        return False
    return True
	
def get_block_size(msg):
    return int(msg.split(' ')[1])

def get_full_size(msg):
    return int(msg.split(' ')[2])
    
def get_udp_rate(msg):
    msg = msg.split(' ')
    if len(msg) == 4:
        return int(msg[3])
    return 0
    
usage = "usage: %prog [options] [tcp_port]"
version = "1.6"
parser = OptionParser(usage, version=version)
parser.add_option("-v", "--verbose", help = "Verbose mode", action="store_true", dest="verbose", default=False)
parser.add_option("-b", "--broadcast", dest="broadcast", help="The broadcast IP address", default = None)
parser.add_option("-e", "--socket-rcv-buf", dest="socket_rcv_buf", help="The minimum size of the socket receive buffer. If the system default is higher that will be used. Usage: -e 131072 or -e 128K", default = DEFAULT_SOCKET_BUFFER_SIZE)
parser.add_option("-s", "--socket-snd-buf", dest="socket_snd_buf", help="The minimum size of the socket send buffer. If the system default is higher that will be used. Usage: -s 131072 or -e 128K", default = DEFAULT_SOCKET_BUFFER_SIZE)
parser.add_option("-u", "--udp-port", dest="udp_port", help="set udp port", default="1213")

(opts, args) = parser.parse_args()
    
if len(args) < 1:
    port = def_port

try:
    port = int(args[0])
except:
    port = def_port
    
def log_msg(msg):
    if opts.verbose:
        print msg
        
def get_interpreted_buffer_sizes(buffer_size):
    result = re.match("(.*)[kK]", str(buffer_size))
    if result:
        return int(result.groups()[0])*1024
    return int(buffer_size)
    
def set_socket_buffer_sizes(client_socket):
    current_rcv_buf = client_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
    current_snd_buf = client_socket.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
    opts_rcv_buf = get_interpreted_buffer_sizes(opts.socket_rcv_buf)
    opts_snd_buf = get_interpreted_buffer_sizes(opts.socket_snd_buf)
    if (current_rcv_buf < opts_rcv_buf):
        log_msg("Changing socket receive buffer size from %s to %s" % (current_rcv_buf, opts_rcv_buf))
        client_socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, opts_rcv_buf)
    if (current_snd_buf < opts_snd_buf):
        log_msg("Changing socket send buffer size from %s to %s" % (current_snd_buf, opts_snd_buf))
        client_socket.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, opts_snd_buf)
    
    # Test if the buffer size was accepted by the system
    current_rcv_buf = client_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
    current_snd_buf = client_socket.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
    
    if (current_rcv_buf < opts_rcv_buf):        
        log_msg("Socket receive buffer size %s was not accepted by the system, current value: %s" % (opts_rcv_buf, current_rcv_buf))
    if (current_snd_buf < opts_snd_buf):        
        log_msg("Socket send buffer size %s was not accepted by the system, current value: %s" % (opts_snd_buf, current_snd_buf))
        
def __get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((GOOGLE_DNS, 80))
        ip = s.getsockname()[0]
        s.close()
    except socket.error:
        ip = None
    return ip
    
def get_broadcast_ip():
    ''' This is a dirty workaround and works only the netmask is /24 
    but there is no better cross-platform option
    without running external commands like ipconfig, or using special libs '''
    
    if opts.broadcast:
        return opts.broadcast

    local_ip = __get_local_ip()
    broadcast = "255.255.255.255"
    if local_ip == None:
        return broadcast
        
    ip_fields = local_ip.split(".")
    broadcast = "%s.%s.%s.255" %(ip_fields[0], ip_fields[1], ip_fields[2])
    return broadcast
    
def get_hostname():
    hostname = socket.gethostname().replace(' ', '_')
    return hostname
     
def start_broadcast(broadcast_ip, port):
    hostname = get_hostname()
    version = "1.0"
    type="C"
    brsocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    brsocket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    brsocket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    log_msg("Start sending broadcast message to %s:%s" % (broadcast_ip, port))
    while (True):        
        brsocket.sendto('%s %s %s' % (version, type, hostname), (broadcast_ip, port))
        time.sleep(1)
    brsocket.close()
    
class ThreadedTCPRequestHandler(SocketServer.BaseRequestHandler):

    def handle(self):
        set_socket_buffer_sizes(self.request)
        received_data = 0
        data = None
        print("New incoming TCP connection from %s:%s" % (self.client_address[0], self.client_address[1]))
        while (True and not STOP_ALL_THREADS):            
            readable, writable, errored = select.select([self.request], [], [], 1)
            if (readable):
                try:
                    data = self.request.recv(4096)
                    received_data += len(data)
                except socket.error:
                    pass
                if not data:
                    log_msg("Closing connection\n")
                    log_msg("Received data: %s bytes" % received_data)
                    self.request.close()
                    return                
                if (is_protocol_msg(data)):                    
                    if not push_data (self.request, data, client_address=None):                            
                        return
                    
class MyUDPHandler(SocketServer.BaseRequestHandler):

    def handle(self):
        received_data = 0
        client_socket = self.request[1]
        data = self.request[0]
        received_data += len(data)
        set_socket_buffer_sizes(client_socket)        
        repeated = 0
        prev_received_data = received_data
        push_mode = False
        print("New incoming UDP connection from %s:%s" % (self.client_address[0], self.client_address[1]))
        while (True and not STOP_ALL_THREADS):            
            readable, writable, errored = select.select([client_socket], [], [], 0.1)
            if (readable):
                try:
                    data = client_socket.recv(4096)
                    received_data += len(data)
                except socket.error:
                    pass            
            if (data and is_protocol_msg(data)):
                push_mode = True
                if not push_data (client_socket, data, self.client_address, True):
                    # this will never run here
                    return
                data = ""
            #log_msg("date: %s, Received data: %s bytes" % (datetime.datetime.now().time(), received_data))
            if repeated == 10:                
                log_msg("Received data: %s bytes" % received_data)
                if not push_mode:
                    for x in range(0, 3):
                        log_msg("Sending received data back to udp, client addres: %s" % str(self.client_address))
                        socket_send(client_socket, str(received_data), self.client_address, True)
                        time.sleep(1)
                return
            if received_data > 0:
                if received_data == prev_received_data:
                    repeated += 1
                else:
                    repeated = 0
            prev_received_data = received_data
        
def push_data (client_socket, data, client_address=None, use_udp=False):
    msg_block_size = get_block_size(data)
    full_size = get_full_size(data)    
    udp_rate = get_udp_rate(data)    
    log_msg("Push mode, starting sending, total data size to send: %s bytes, block size: %s bytes, udp rate (if udp): %s" % (full_size,msg_block_size, udp_rate))
    sent_data = 0
    msg = "\n".zfill(msg_block_size)
    current_rate = 0
    start_time = get_time_in_ms()
    prev_time = start_time
    sent_packages = 0
    while (sent_data < full_size and not STOP_ALL_THREADS):
        if (udp_rate == 0 or current_rate < udp_rate):
            try:
                socket_send(client_socket, msg, client_address, use_udp)
            except Exception, e:
                return False
            sent_packages += 1
            sent_data += len(msg)
        current_time = get_time_in_ms()
        time_diff = current_time - prev_time
        if udp_rate > 0 and (time_diff > 1 or sent_packages > 10):
            sent_packages = 0
            prev_time = current_time
            elapsed_time = current_time - start_time
            if elapsed_time > 0:
                current_rate = ((sent_data * 8) / elapsed_time)*1000
            #log_msg("Current rate: %s Kbps, sent data: %s Kbyte" % ((current_rate / 1024), (sent_data/1024)))
    log_msg ("Sending finished, sent data: %s bytes" % sent_data)
    return True
    
def get_time_in_ms():
    return int(round(time.time() * 1000))

def socket_send(client_socket, msg, client_address, use_udp):
    if use_udp:
        client_socket.sendto(msg, client_address)
    else:
        client_socket.sendall(msg)

class ThreadedTCPServer(SocketServer.ThreadingMixIn, SocketServer.TCPServer):
    pass
    
def signal_handler(signal, frame):
    global STOP_ALL_THREADS
    print('You pressed Ctrl+C, exiting')
    STOP_ALL_THREADS = True    
    sys.exit(0)
    
def get_udp_port():
    return int(opts.udp_port)
    
if __name__ == "__main__":
    global server
    log_msg("Starting in debug mode")
    signal.signal(signal.SIGINT, signal_handler)
    
    thread = Thread(target = start_broadcast, args = (get_broadcast_ip(), port, ))
    thread.daemon = True
    thread.start()
    print("Server started (v%s), listening on %s:%s (TCP) and on %s:%s (UDP)" % (version, __get_local_ip(), port, __get_local_ip(), get_udp_port()))
    print("Don't forget to enable port %s and %s (in case of udp) in firewall settings or disable firewall temporarily until the tests finished" % (port, get_udp_port()))
    if (get_broadcast_ip() is not None):
        print("Server (%s) is automatically discoverable by clients\n" % get_hostname())
    print("Press CTRL+C to exit")

    server_udp = SocketServer.UDPServer(('', get_udp_port()), MyUDPHandler)
    server_thread_udp = threading.Thread(target=server_udp.serve_forever)
    server_thread_udp.daemon = True
    server_thread_udp.start()
    
    server_tcp = ThreadedTCPServer(('', port), ThreadedTCPRequestHandler)
    server_thread_tcp = threading.Thread(target=server_tcp.serve_forever)
    server_thread_tcp.daemon = True
    server_thread_tcp.start()
    while (True):
        time.sleep(1)