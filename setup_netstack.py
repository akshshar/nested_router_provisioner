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
CHEF_SERVER_IP = ""
host_prefix = "xr-lxc-"
XR_LXC_HOST = ""

def split_by_n( seq, n ):
    """A generator to divide a sequence into chunks of n units."""
    while seq:
        yield seq[:n]
        seq = seq[n:]


def disable_paging(remote_conn):
    '''Disable paging on a Cisco router'''

    remote_conn.send("terminal length 0\n")
    time.sleep(1)

    # Clear the buffer on the screen
    output = remote_conn.recv(1000)

    return output

def rexists(sftp, path):
    """os.path.exists for paramiko's SCP object
    """
    try:
        sftp.stat(path)
    except IOError, e:
        if e[0] == 2:
            return False
    else:
        return True

def get_host_ip(host_port):
    cmd = ABS_PATH+"/get_host_ip.tcl "+ str(host_port)
    host_ip = subprocess.check_output(shlex.split(cmd))
    return host_ip

def setup_xr_console(xr_port):
    cmd = ABS_PATH+"/setup_xr_console.tcl "+ str(xr_port)
    print "\n\n\n CMD is \n\n\n"
    print str(cmd) + "\n\n\n"
    output = subprocess.check_output(shlex.split(cmd))
    return

def setup_host_auth(host_port):
    proxy_hostname = HOST_IP 
    proxy_username = 'root'
    proxy_password = 'lab'
    proxy_port = 22

    proxy_client = paramiko.SSHClient()
    proxy_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    proxy_client.connect(proxy_hostname, username=proxy_username, password=proxy_password, timeout=5)

    sftp = proxy_client.open_sftp()
    remote_file="/root/base_rsa.pub"
    local_file="/home/cisco/.ssh/id_rsa.pub"
    sftp.put(local_file, remote_file)
    sftp.close()
    
    cmd="cat /root/base_rsa.pub >> ~/.ssh/authorized_keys"
    stdin, stdout, stderr = proxy_client.exec_command(cmd)

    proxy_client.close()
    return

def setup_xr_auth(port_ssh_fwd):
    remote_client = paramiko.SSHClient()
    remote_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    remote_client.connect('127.0.0.1', port=int(port_ssh_fwd), username='root', password='lab')

    sftp = remote_client.open_sftp()
    remote_file="/root/base_rsa.pub"
    local_file="/home/cisco/.ssh/id_rsa.pub"
    sftp.put(local_file, remote_file)
    sftp.close()

    cmd="cat /root/base_rsa.pub >> ~/.ssh/authorized_keys"
    stdin, stdout, stderr = remote_client.exec_command(cmd)
    remote_client.close()    
    return
   
def setup_port_forwarding(port_ssh_fwd):
    #Kill any existing port_forwarding processes
    cmd = "/bin/bash "+ABS_PATH+"/kill_ssh_port_fwds "+str(port_ssh_fwd)
    p = subprocess.call(shlex.split(cmd))

    cmd= "ssh -f -N -L "+str(port_ssh_fwd)+":10.11.12.14:22 -l root "+HOST_IP
    p = subprocess.call(shlex.split(cmd))
    return


def execute_host_cmd(cmd):
    print "Host command to be executed is\n\n"
    ssh_cmd = "ssh root@"+HOST_IP+" \""+cmd+"\"" 
    print str(ssh_cmd)
    output = subprocess.check_output(shlex.split(ssh_cmd))
    return output

def execute_host_intr_shell_cmd(inv_shell_cmd_list):
    proxy_hostname = HOST_IP
    proxy_username = 'root'
    proxy_password = 'lab'
    proxy_port = 22

    proxy_client = paramiko.SSHClient()
    proxy_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    proxy_client.connect(proxy_hostname, username=proxy_username, password=proxy_password, timeout=5)

    proxy_console = proxy_client.invoke_shell()
    print "Interactive SSH session established"
    print "Cmd list is \n\n"

    # Turn off paging
    disable_paging(proxy_console)
    for inv_shell_cmd in inv_shell_cmd_list:
        proxy_console.send(str(inv_shell_cmd)+"\n")
        time.sleep(2)

    proxy_console.send("\n\n")

    output = proxy_console.recv(10000)
    print output
    proxy_client.close()

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

    
def is_xr_lxc_up():
    output = execute_host_cmd("virsh -c lxc:/// list | awk '{print $2}'")
    for lxc in output.split():
        if lxc == "default-sdr--1":
            result = True
            break
        else:
            result = False
    return result

def check_remote_path(remote_host, user, pswd, port, path_name):

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(remote_host, port=int(port), username=user, password=pswd, timeout=5)

    sftp = client.open_sftp()
    if rexists(sftp, path_name):
        result = True
    else:
        result = False
    sftp.close()
    client.close()
    return result

def main(argv):
    global HOST_IP

    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--host_telnet_port', help="telnet port to connect to host linux", nargs='+', type=str)
    parser.add_argument('-x', '--XR_telnet_port', help="telnet port to connect to XR console", nargs='+', type=str)
    parser.add_argument('-n', '--net_name', help="user defined net name", nargs='+', type=str)
    parser.add_argument('-f', '--port_ssh_fowarding', help="Port to forward the ssh connections to", nargs='+', type=str)

    args = parser.parse_args()

    host_telnet=args.host_telnet_port[0]
    xr_telnet=args.XR_telnet_port[0]
    net_name=args.net_name[0]
    port_ssh_fwd= args.port_ssh_fowarding[0]

    print "Trying to determine the ip address of the host"

    HOST_IP = get_host_ip(host_telnet).rstrip('\n')

    #Remove known hosts
    if os.path.exists('/home/cisco/.ssh/known_hosts'):
        cmd = "rm /home/cisco/.ssh/known_hosts"
        print "cmd is "+str(cmd)
        output = subprocess.check_output(shlex.split(cmd))


    setup_host_auth(host_telnet) 

    print "\n\n\nChecking if XR lxc is up.....\n\n\n"
    while True: 
        lxc_output = is_xr_lxc_up()
        if lxc_output == True:
            print "XR LXC is up"
            break
        time.sleep(2)
    #Now that XR lxc is up, wait for about 30 seconds
    print "Sleep for about 30 seconds"
 
    time.sleep(30)
    
    #Now try to set up XR console
    setup_xr_console(xr_telnet)

    setup_port_forwarding(port_ssh_fwd)
        
    setup_xr_auth(port_ssh_fwd)

    #Now start executing commands
    #Determine the ip address of <net>Br1
    cmd = "ifconfig "+net_name+"Br1"
    output = subprocess.check_output(shlex.split(cmd))

    gip = re.search(r'inet addr:(\S+)', output)
    mac = re.search(r'HWaddr\s+(\S+)', output)
 
    #Create a list of xr console commands
 
    xr_int_ip = '.'.join([gip.group(1).split('.')[0], gip.group(1).split('.')[1], gip.group(1).split('.')[2], str(int(gip.group(1).split('.')[3])+9)])

    xr_con_cmd_list = ['conf t', 'int GigabitEthernet0/RP0/CPU0/0', 'ip addr '+xr_int_ip+' 255.255.255.0', 'no shut', 'commit'] 
    execute_xr_console_cmd(xr_con_cmd_list, port_ssh_fwd)

    xr_con_cmd_list = ['conf t', 'router static address-family ipv4 unicast 0.0.0.0/0 GigabitEthernet0/RP0/CPU0/0 '+ str(gip.group(1)), 'commit']     

    execute_xr_console_cmd(xr_con_cmd_list, port_ssh_fwd)

    create_tap = 0

    try:
        output = execute_xr_shell_cmd('ifconfig tap123', port_ssh_fwd)
    except Exception,e:
        print(e)
        create_tap = 1

    if create_tap:
        while True:
            try:
                execute_host_cmd('modprobe lcndklm')
                time.sleep(2)
                execute_host_cmd('echo 1 1 1 1 > /proc/sys/kernel/printk')
                time.sleep(2)

                if not check_remote_path('127.0.0.1', 'root', 'lab',  port_ssh_fwd, "/dev/net"):
                    execute_xr_shell_cmd('mkdir /dev/net/', port_ssh_fwd)
                    time.sleep(2)
                if not check_remote_path('127.0.0.1', 'root', 'lab', port_ssh_fwd, '/dev/net/tuncisco'):
                    execute_xr_shell_cmd('mknod /dev/net/tuncisco c 10 201', port_ssh_fwd)
                    time.sleep(2)

                execute_xr_console_cmd(['proc restart netio'], port_ssh_fwd)
                time.sleep(5)
                execute_xr_shell_cmd('ifconfig tap123 up', port_ssh_fwd)
                time.sleep(2)

                break
            except Exception,e:
                print(e)
                execute_xr_shell_cmd('rm -r /dev/net', port_ssh_fwd)

    while True:
        show_int_out = execute_xr_console_cmd(['sh interfaces GigabitEthernet 0/RP0/CPU0/0'], port_ssh_fwd)
        print show_int_out
        try:
            mac_addr = re.search(r'address is\s+(\S+)\s+\(bia', show_int_out)
            xr_intf_mac = ':'.join((split_by_n(''.join(mac_addr.group(1).split('.')),2)))
            print xr_intf_mac
            break 
        except Exception,e:
            print str(e)
        time.sleep(2)

    while True:
        show_im_db =  execute_xr_console_cmd(['sh im database interface GigabitEthernet 0/RP0/CPU0/0'], port_ssh_fwd)
        print show_im_db
        try:
            ifh_value =  re.search(r'ifh\s+(\S+)\s+\(', show_im_db)
            xr_ifh_value= int(ifh_value.group(1), 0)
            print xr_ifh_value
            break 
        except Exception,e: 
            print str(e)
        time.sleep(2)

 
   #Give the XR instance some rest. Sleep for 15 seconds
    time.sleep(15)
   #Copy kimctrl to host
    cmd = "scp /home/cisco/sunstone/kimctrl root@"+HOST_IP+":/root/kimctrl"
    print "cmd is "+str(cmd)
    output = subprocess.check_output(shlex.split(cmd))



   #Copy netbroker start script to XR
    cmd = "scp -P "+str(port_ssh_fwd)+" "+ABS_PATH+"/start_netbroker.sh root@127.0.0.1:/root/start_netbroker.sh"
    print "cmd is "+str(cmd)
    output = subprocess.check_output(shlex.split(cmd))
    execute_xr_shell_cmd('chmod 777 /root/start_netbroker.sh', port_ssh_fwd)



   #Now create the netdevice
    execute_host_intr_shell_cmd(['/root/kimctrl -a ge0000 -m '+str(xr_intf_mac)+' -i '+str(xr_ifh_value), '\r\r', 'ps -ef | grep kimctrl'])
    execute_xr_shell_cmd('ifconfig ge0000 '+str(xr_int_ip)+'  up', port_ssh_fwd) 
    execute_host_cmd('modprobe cisco_nb')
    execute_xr_intr_shell_cmd(['/root/start_netbroker.sh'], port_ssh_fwd)
    execute_xr_shell_cmd('/sbin/arp -s '+str(gip.group(1))+' '+str(mac.group(1)), port_ssh_fwd)


   #Copy XR shell public key to local authorized keys 


    cmd = "scp -P "+str(port_ssh_fwd)+"  root@127.0.0.1:/root/.ssh/id_rsa.pub /home/cisco/sunstone/xr_shell.pub"
    output = subprocess.check_output(shlex.split(cmd))

#    pdb.set_trace()
    input_file = ['/home/cisco/sunstone/xr_shell.pub']
    cmd = ['cat'] + input_file
    with open('/home/cisco/.ssh/authorized_keys', "a") as outfile:
        subprocess.call(cmd, stdout=outfile)
   #Set up networking and hosts in XR
    xr_int_net = '.'.join([xr_int_ip.split('.')[0], xr_int_ip.split('.')[1], xr_int_ip.split('.')[2], '0'])

    cmd = "sudo iptables -t nat -A POSTROUTING -s "+str(xr_int_net)+"/24 -j MASQUERADE"
    output = subprocess.check_output(shlex.split(cmd))

    cmd = "ifconfig eth0"
    output = subprocess.check_output(shlex.split(cmd))
    ip = re.search(r'inet addr:(\S+)', output)

    CHEF_SERVER_IP = ip.group(1)

    XR_LXC_HOST = str(host_prefix)+net_name

#    net_setup_cmd_list = ['ip route del default', 'ip route add default via '+xr_int_ip+' dev ge0000', 'echo \"'+CHEF_SERVER_IP+' sunstone\" >> /etc/hosts', 'mkdir /root/rpms', 'hostname '+XR_LXC_HOST, 'echo \"'+XR_LXC_HOST+'\" > /etc/hostname' ]
    net_setup_cmd_list = ['ip route del default', 'ip route add default via '+gip.group(1)+' dev ge0000', 'echo \"'+CHEF_SERVER_IP+' sunstone\" >> /etc/hosts', 'hostname '+XR_LXC_HOST, 'echo \"'+XR_LXC_HOST+'\" > /etc/hostname']

    if not check_remote_path('127.0.0.1', 'root', 'lab', port_ssh_fwd, "/root/rpms"):
        execute_xr_shell_cmd('mkdir /root/rpms', port_ssh_fwd)
        time.sleep(2)

    for cmd in net_setup_cmd_list:
        execute_xr_shell_cmd(cmd, port_ssh_fwd)

   #Copy chef rpm iand starter tar into XR shell and set up chef-client
    cmd = " scp -P "+str(port_ssh_fwd)+"  /tftpboot/chef-12.0.3-1.x86_64.rpm root@127.0.0.1:/root/rpms/" 
    output = subprocess.check_output(shlex.split(cmd))

    cmd = " scp -P "+str(port_ssh_fwd)+" /tftpboot/chef-starter.tar root@127.0.0.1:/root/rpms/"
    output = subprocess.check_output(shlex.split(cmd)) 

    cmd = " scp -P "+str(port_ssh_fwd)+" /tftpboot/client.rb root@127.0.0.1:/root/"
    output = subprocess.check_output(shlex.split(cmd))
  
   #Now set up the chef-client within XR

    execute_xr_shell_cmd('rpm -ivh --nodeps /root/rpms/chef-12.0.3-1.x86_64.rpm', port_ssh_fwd)  

    if check_remote_path('127.0.0.1', 'root', 'lab', port_ssh_fwd, "/root/chef-repo"):
        execute_xr_shell_cmd('rm -r /root/chef-repo', port_ssh_fwd)
        time.sleep(2)

    chef_client_cmd_list = ['tar -xvf /root/rpms/chef-starter.tar -C /root/', 'cd chef-repo', 'knife configure client .', 'cp /root/client.rb ./client.rb', 'knife ssl fetch', 'ps -ef | grep chef']
    execute_xr_intr_shell_cmd(chef_client_cmd_list, port_ssh_fwd)

    env_var='export SSL_CERT_FILE=/root/chef-repo/.chef/trusted_certs/sunstone.crt'
    cmd = str(env_var)+'&& chef-client -d -c /root/chef-repo/client.rb -i 60 -s 20 -L /root/chef-repo/logs &'
    execute_xr_shell_cmd(cmd, port_ssh_fwd)

 
if __name__ == "__main__":
    main(sys.argv[1:])

