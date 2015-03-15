boot_port=`ps -ef | grep $1 | grep $2 | grep kvm | awk '{print $53}'`
host_port=`ps -ef | grep $1 | grep $2 | grep kvm | awk '{print $59}'`

split_var=(${boot_port//:/ })
split_var_port=${split_var[2]}
split_boot_final=(${split_var_port//,/ })

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
white='\033[1;37m'

NC='\033[0m'

#printf "${blue}\n\n\n\n##########################################################################\n${NC}"
#echo -e "${red}\n\nTo view the boot process, run \"telnet localhost ${split_boot_final[0]}\"\n${NC}"

split_var=(${host_port//:/ })
split_var_port=${split_var[2]}
split_host_final=(${split_var_port//,/ })

#echo -e "${red}\nTo telnet into host_linux, run \"telnet localhost ${split_host_final[0]}\"\n${NC}"
#printf "${blue}\n\n##########################################################################\n\n\n${NC}"

#Call the python script
#printf "Now run \n\n"
#printf "python /home/cisco/sunstone/try_nested_ssh.py -p ${split_host_final[0]} -x ${split_boot_final[0]} -n $2\n\n\n"

printf "Setting up net devices on the host as XR LXC boots up. Please wait........\n\n\n"
su cisco -c  "python /home/cisco/sunstone/setup_netstack.py -p ${split_host_final[0]} -x ${split_boot_final[0]} -n $2"

host_ip=`/home/cisco/sunstone/get_host_ip.tcl ${split_host_final[0]}`

echo -e "${blue}\n\n\n\n##########################################################################\n${NC}"

echo -e "${red}          Done!! To ssh into the host machine, run-->\n\n\n                        \n${NC}"

echo -e "${green}        ssh -l root $host_ip${NC}"

echo -e "${red}          To ssh into the XR shell, run -->\n\n                                    \n${NC}"

echo -e "${green}        ssh -p 1234 -l root 127.0.0.1                                            \n${NC}"
echo -e "${blue}\n\n\n\n##########################################################################\n${NC}"

