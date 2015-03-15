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

def disable_paging(remote_conn):
    '''Disable paging on a Cisco router'''

    remote_conn.send("terminal length 0\n")
    time.sleep(1)

    # Clear the buffer on the screen
    output = remote_conn.recv(1000)

    return output


def execute_xr_intr_shell_cmd(inv_shell_cmd_list):
    remote_hostname = '127.0.0.1' 
    remote_username = 'root'
    remote_password = 'lab'
    remote_port = 1234 

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
 
def execute_xr_console_cmd(cmd_list):
    remote_client = paramiko.SSHClient()
    remote_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    remote_client.connect('127.0.0.1', port=1234, username='root', password='lab')

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
 
    
def execute_xr_shell_cmd(cmd):
    print "XR command to be executed is\n\n"
    ssh_cmd = "ssh -p 1234 root@127.0.0.1 \""+cmd+"\""
    print str(ssh_cmd)
    output = subprocess.check_output(shlex.split(ssh_cmd))
    return output

    
def main(argv):
    output = execute_xr_console_cmd(['process shutdown flume', '\n\n' ,'process start flume', 'show proc | i flume'])
    print output
 
if __name__ == "__main__":
    main(sys.argv[1:])

