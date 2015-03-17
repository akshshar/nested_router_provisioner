import paramiko
import os, signal
import shlex
import argparse
import subprocess
from subprocess import Popen, PIPE
import sys
import logging
import pdb
import time
import re
import os.path

logging.basicConfig(level=logging.DEBUG)

ABS_PATH = os.path.dirname(os.path.abspath(__file__))
HOST_IP = ''

def get_host_port(hostname):
    cmd = ABS_PATH+"/get_host_port.sh "+ str(hostname)
    host_port = subprocess.check_output(shlex.split(cmd))
    return host_port


def get_host_ip(host_port):
    cmd = ABS_PATH+"/get_host_ip.tcl "+ str(host_port)
    host_ip = subprocess.check_output(shlex.split(cmd))
    return host_ip


def disable_paging(remote_conn):
    '''Disable paging on a Cisco router'''

    remote_conn.send("terminal length 0\n")
    time.sleep(1)

    # Clear the buffer on the screen
    output = remote_conn.recv(1000)

    return output


def execute_xr_intr_shell_cmd(inv_shell_cmd_list, port_ssh_fwd):
    remote_hostname = '127.0.0.1' 
    remote_username = 'root'
    remote_password = 'lab'
    remote_port = int(port_ssh_fwd) 

    remote_client = paramiko.SSHClient()
    remote_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    remote_client.connect(remote_hostname, port=remote_port, username=remote_username, password=remote_password, timeout=5)

    remote_console = remote_client.invoke_shell()
    print "Interactive SSH session established"
    print "Cmd list is \n\n"

    # Turn off paging
    disable_paging(remote_console)

    for inv_shell_cmd in inv_shell_cmd_list:
        remote_console.send(str(inv_shell_cmd)+"\r")
        remote_console.send("\r\r")
        time.sleep(2)


    output = remote_console.recv(10000)
    print output

    remote_client.close()
 
def execute_xr_console_cmd(cmd_list, port_ssh_fwd):
    remote_client = paramiko.SSHClient()
    remote_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    remote_client.connect('127.0.0.1', port=int(port_ssh_fwd), username='root', password='lab')

    remote_console = remote_client.invoke_shell()
    print "Interactive SSH session established"
    print "Cmd list is \n\n"
    print cmd_list
    output = remote_console.recv(1000)
    print output

    # Turn off paging
    disable_paging(remote_console)
    remote_console.send("exec\n")
    time.sleep(5)
    remote_console.send("root\n")
    remote_console.send("root\n\n\n")
    remote_console.send("\n\n\n")

    time.sleep(5)
    for cmd in cmd_list:
        remote_console.send(str(cmd)+"\n\n")
        time.sleep(2)

    remote_console.send(str(cmd)+"\n\n")
    output = remote_console.recv(10000)
    remote_client.close() 
    return output
 
    
def execute_xr_shell_cmd(cmd, port_ssh_fwd):
    print "XR command to be executed is\n\n"
    ssh_cmd = "ssh -p "+str(port_ssh_fwd)+" root@127.0.0.1 \""+cmd+"\""
    print str(ssh_cmd)
    output = subprocess.check_output(shlex.split(ssh_cmd))
    return output

    
def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('-x', '--xr_hostname', help="hostname of XR lxc", nargs='+', type=str)

    args = parser.parse_args()

    host_xr= args.xr_hostname[0]
    hostname = host_xr.split('-')[2]
    print "Hostname is "+str(hostname) 
    #determine host_linux_port
    HOST_PORT = get_host_port(hostname).rstrip('\n')
    #Determine host Ip

    HOST_IP = get_host_ip(HOST_PORT).rstrip('\n')
   
    cmd1 = "ps -ef "
    cmd2 = "grep ssh"
    cmd3 = "grep "+str(HOST_IP)
    cmd4 = "awk \'{print $12}\' "

    p1 = subprocess.Popen(shlex.split(cmd1), stdout=subprocess.PIPE)
    p2 = subprocess.Popen(shlex.split(cmd2), stdin=p1.stdout, stdout=subprocess.PIPE)
    p1.stdout.close()
    p3 = subprocess.Popen(shlex.split(cmd3), stdin=p2.stdout, stdout=subprocess.PIPE)
    p2.stdout.close()
    p4 = subprocess.Popen(shlex.split(cmd4), stdin=p3.stdout, stdout=subprocess.PIPE)
    p3.stdout.close()

    out = p4.communicate()

#    proc = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, shell=True)
#    (out, err) = proc.communicate()

    print "output is "+str(out)
#    pdb.set_trace()

    port_ssh_fwd = int(out[0].rsplit('\n')[0].split(':')[0]) 
    output = execute_xr_console_cmd(['process shutdown flume', '\n\n' ,'process start flume', 'show proc | i flume'], port_ssh_fwd)
    print output
 
if __name__ == "__main__":
    main(sys.argv[1:])

