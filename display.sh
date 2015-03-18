function is_port_free {

check=`lsof -i:$1`
result=$?
if [[ $result == 1 ]]
then
    printf "Port $1 is free...returning"
    return 1
else
    printf "Port $1 is not free...returning"
    return 0
fi
}
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

printf "\n\n\n Starting the provisioner script....\n\nSetting up net devices on the host as XR LXC boots up. Please wait........\n\n\n"

port=7000
while true
do
   is_port_free $port
   check_port=$?
   printf "\n\n\n Check_port value is $check_port\n\n"
   if [[ $check_port -eq 1 ]]
   then
       break
   fi

   if [[ $port -eq 7060 ]]
   then
       printf "Unable to find a free port in the range of 7000-7060, aborting...."
       exit 0
   fi
   port=$((port+1))
done

su cisco -c  "python $HOME/sunstone/setup_netstack.py -p ${split_host_final[0]} -x ${split_boot_final[0]} -n $2 -f $port -c"
#printf "python /home/cisco/sunstone/setup_netstack.py -p ${split_host_final[0]} -x ${split_boot_final[0]} -n $2 -f $port"

host_ip=`/home/cisco/sunstone/get_host_ip.tcl ${split_host_final[0]}`

echo -e "${blue}\n\n\n\n##########################################################################\n\n\n${NC}"

echo -e "${red}        Done!! To ssh into the host machine, run-->\n\n                        ${NC}"

echo -e "${green}       ssh -l root $host_ip \n\n\n${NC}"

echo -e "${red}        To ssh into the XR shell, run -->\n\n                                    ${NC}"

echo -e "${green}       ssh -p $port -l root 127.0.0.1                                          ${NC}"
echo -e "${blue}\n\n\n##########################################################################\n${NC}"

