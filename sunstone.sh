#!/bin/bash
#
# HELP
#
# This tool creates and launches a QEMU/KVM virtual machine instance for the
# cisco sunstone platform. At a minimum an ISO is needed to allow the system
# to boot. Additionally for the system to successfully install, a blank hard
# disk is needed. The tool will create any needed disks if not found.
#
# On subsequent runs you will be prompted if you wish to repeat the install
# phase or boot from the existing installed disks.
#
# Simple boot
#
#    sunstone.sh -iso sunstone-mini-x.iso
#
# Or if you have a pre-booted VMDK or OVA
#
#    sunstone.sh -disk sunstone-mini-x.vmdk
#
#    sunstone.sh -disk sunstone-mini-x.ova
#
#
# Terminal output
# ---------------
#
# The sunstone platform supports serial port access only. As such we need a
# way to connect to the telnet ports that we randomly allocate at startup for
# sunstone to use. For ease of use, this tool can launch a variety of terminals
# and then within those terminals will telnet to the sunstone serial ports.
#
# A variety of terminal types is supported e.g.:
#
#    sunstone.sh -iso sunstone-mini-x.iso --gnome
#    sunstone.sh -iso sunstone-mini-x.iso --mrxvt
#    sunstone.sh -iso sunstone-mini-x.iso --konsole
#    sunstone.sh -iso sunstone-mini-x.iso --xterm
#    sunstone.sh -iso sunstone-mini-x.iso --screen
#
# The tool by default will try to find one of the above if no option is
# specified.
#
#   --gnome can sometimes cause issues if you are not running a gnome desktop
#
#   --screen is a text only interface. Generally you need a .screenrc and should
#   be familiar with how to use screen before attempting to use this one!
#
# Output to these terminals is logged into the work dir that is created when
# you launch the VM. In this way you have a record of every session.
#
#
# Networking
# -----------
#
# The tool also creates a number of network interfaces to connect the VM to.
# These interfaces are named 'h' or 'p' tap.
#
#    'h' here indicates an interface that is connected to the host machine
#    network (virbr0) and can hence be used for ssh access to the VM.
#
#    'p' indicates a private interface attached to its own bridge which may
#    then be used to connect to other VMs that also connect to the same named
#    bridge.
#
# If you wish to run multiple instances at the same time, you must use the
# -net option to provide some other name other than your login name. e.g.
#
#    sunstone.sh -iso sunstone-mini-x.iso --gnome -net mynet2
#
#
# Disks
# -----
#
# By default the tool will create raw disks. These can be very large. To save
# space you can use the qcow2 option to enable copy on write functionality.
# This may have a performance hit but will drastically reduce disk space needed.
#
#
# Background running
# ------------------
#
# This tool can run qemu in the background. The telnet ports are logged into
# the work dir created. You may then manually telnet to the router.
#
#
# Development mode
# ----------------
#
# Development mode will cause the ISO to be expanded and the __development=true
# option to be added to the command line. This will cause the system to not
# allow IOS XR to launch on the console port. Instead login to the host will
# be provided.
#
# One caveat, as you will now be double telnetted, it is necessary to be able
# to telnet from the host into the guest and then exit back to the host
# without killing both telnet connections. For this purpose, you can do:
#
#   For XR:
#        telnet -e ^Q localhost 9001
#
#   For calvados:
#        telnet -e ^Q localhost 50000
#
# And to escape out to the host telnet session, hit "ctrl ]" and then "q enter"
#
#
# VM access
# ---------
#
# Once in the host VM you can ssh to the containers manually via:
#
#   For XR:
#     ssh -l root 10.11.12.14
#
#   For calvados:
#     ssh -l root 10.11.12.15
#
#   For UVF:
#     ssh -l root 10.11.12.115
#
# And then back to the host via
#
#     ssh -l root 10.0.2.16
#
#
# sshfs access
# ------------
#
# To mount a directory remotely you may follow this approach (which will need
# tweaking for your own nameservers):
#
#     1. on host VM, get the address QEMU allocated for us on virbr0:
#
#         [host:~]$ ifconfig eth0
#         eth0      Link encap:Ethernet  HWaddr 52:46:01:5B:D1:78
#                 inet addr:192.168.122.122  Bcast:192.168.122.255  Mask:255.255.255.0
#
#     2. on host, ssh into sunstone VM
#
#         ssh -l root 192.168.122.122
#
#     3. on sunstone VM, set up nameservers
#
#         cat >/etc/resolv.conf <<%%
#     nameserver 64.102.6.247
#     nameserver 171.70.168.183
#     nameserver 172.36.131.10
#     nameserver 192.168.122.1
#     search cisco.com
#     %%
#
#     4. on sunstone VM, create any mount points you need e.g. I am mounting
#        /ws/nmcgill-sjc
#
#         mkdir -p /ws/nmcgill-sjc
#         sshfs -o idmap=user -o allow_other nmcgill@sjc-ads-2617:/ws/nmcgill-sjc /ws/nmcgill-sjc
#
#     5. To do the same in the calvados VM
#
#         ssh 10.11.12.15
#         mkdir -p /ws/nmcgill-sjc
#         sshfs 10.0.2.16:/ws/nmcgill-sjc /ws/nmcgill-sjc
#
#     6. To do the same in the XR VM
#
#         ssh 10.11.12.14
#         mkdir -p /ws/nmcgill-sjc
#         sshfs 10.0.2.16:/ws/nmcgill-sjc /ws/nmcgill-sjc
#
#
# Creating a VMDK or OVA
# ----------------------
#
# To create a VMDK, first we must boot the ISO and allow the system to install
# onto the disk. When the system then reboots we are able to create an OVA
# from that disk image. The OVA contains the VMDK which can be extracted
# then be used as an deployable virtual machine object within vSphere, OpenStack,
# VirtualBox etc.... e.g.:
#
#    sunstone.sh -iso sunstone-mini-x.iso --export-images
#
# Which you can then boot via:
#
#    sunstone.sh -disk sunstone-mini-x.vmdk
#
#
# Usage
# -----
#
# Usage: ./sunstone.sh -image <sunstone iso>
#
#   -i
#   -iso
#   --iso <imagename>   : Name of ISO to boot from.
#
#   -disk
#   --disk <name>       : Name of a preinstalled disk to boot from.
#
#   -n
#   -net
#   -name
#   --name <netname>    : Name of the network. Defaults to $LOGNAME
#
#   -w
#   -workdir
#   --workdir <dir>     : Place to store log and temporary files.
#                         Default is to use the current working directory.
#
#   -clean
#   --clean             : Clean only. Attempt to clean up taps from previous run
#                         Will attempt to kill the old QEMU instance also.
#   -term-bg
#   --term-bg <color>   : Terminal background color (xterm, mrxvt)
#
#   -term-fg
#   --term-fg <color>   : Terminal foreground color (xterm, mrxvt)
#
#   -term-font
#   --term-font <font>  : Terminal font (xterm, mrxvt)
#
#           e.g. -term-font '-*-lucidatypewriter-*-*-*-*-10-*-*-*-*-*-*-*'
#
#   -term-profile
#   --term-profile <p>  : Terminal foreground color (gnome, konsole)
#
#                         e.g.  -term-profile my-profile
#   -term-opt
#   --term-opt <opts>   : Options to passthrough to the terminal windoe.
#
#                         e.g.  -term-opt '-title \"hello there\"'
#
#   -gnome
#   --gnome             : Use tabbed gnome terminal
#
#   -xterm
#   --xterm             : Use multiple xterms
#
#   -konsole
#   --konsole           : Open tabbed konsole sessions.
#
#   -mrxvt
#   --mrxvt             : Open tabbed mrxvt sessions. If you want to tweak the
#                         appearance, you should edit your  ~/.mrxvtrc e.g.
#
#                           Mrxvt.xft:              1
#                           Mrxvt.xftAntialias:     1
#                           Mrxvt.xftFont:          DejaVu Sans Mono
#                           Mrxvt.xftSize:          17
#
#   -screen
#   --screen            : Open screen sessions for telnet.
#
#   -noterm
#   --noterm            : Launch no terminals. Anticipation is that you will
#                         manually telnet to the ports.
#   -log
#   --log               : Spawn telnet sessions to serial ports. Assumes no xterms
#                         are needed.
#   -f
#   -force
#   --force             : Just do it, take defaults.
#
#   -r
#   -recreate
#   --recreate          : Recreate disks.
#
#   -dev
#   --dev               : Run in sunstone development mode (default).
#
#   -cloud
#   --cloud             : Enable tweaks useful for operating in the cloud
#                         e.g. VGA console instead of serial port
#
#   -hw-profile=<profile>
#   --hw-profile=<profile>    
#
#                       : Configure a hw profile type to modify the internal 
#                         memory and CPU requirements of the virtual router.
#
#                         Supported profiles: 
#
#                              "vrr" (virtual route reflector)
#
#                         If a file <profile> also exists, it will be sourced
#                         into the script to allow overriding of defaults. e.g.
#
#                         vrr.profile:
#
#                         OPT_PLATFORM_MEMORY_MB=32768
#                         OPT_PLATFORM_SMP="-smp cores=4,threads=1,sockets=1"
#
#
#   -vga
#   --vga               : Enable VGA mode terminal.
#
#                         NOTE Cisco IOS XR will only boot into this VGA term with the
#                         -cloud option.
#
#   -vnc
#   --vnc <host>        : Start a VNC server. This is the default for cloud
#                         mode.
#
#                         e.g. -vnc 127.0.0.1:0
#                              -vnc :0
#   -sim
#   --sim               : Run in sunstone simulation mode (deprecated).
#
#   -prod
#   --prod              : Run in sunstone production mode.
#
#   -32
#   --32
#   -iosxrv32
#   --iosxrv32          : Tweak behaviour for booting legacy IOS XRv 32 bit
#
#   -enable-extra-tty
#   --enable-extra-tty  : Extra 3rd and 4th TTY (default)
#
#   -disable-extra-tty
#   --disable-extra-tty : Disable 3rd and 4th TTY.
#
#   -disable-kvm
#   --disable-kvm       : Disable KVM acceleration support
#
#   -disable-smp
#   --disable-smp       : Disable SMP
#
#   -disable-numa
#   --disable-numa      : Disable NUMA Balancing (useful for compilation on ADS)
#
#   -smp
#   --smp               : Orverride base SMP options e.g.
#                           -smp cores=4,threads=1,sockets=1
#   -m
#   -memory
#   --memory            : Memory in MB, 16384 default
#
#   -10g
#   --10g               : Scan all 10G NICs on the host and add them to the
#                         QEMU command line.
#   -disable-network
#   --disable-network   : Do not create any network interfaces
#
#   -disable-disk-virtio
#   --disable-disk-virtio : Use slower IDE based access for disks
#
#   -disable-runas
#   --disable-runas     : Disable KVM -runas option (if initgroup causes issues)
#
#   -disable-boot
#   --disable-boot      : Exit after baking ISOs. Do NOT boot QEMU.
#
#   -disable-taps
#   --disable-taps      : Do not create TAP interfaces. Instead disconnected
#                         interfaces will be created. Useful for booting for
#                         a basic test if networking tools (tunctl) are not
#                         installed.
#   -data-nics
#   --data-nics <x>     : Number of data taps to initialize (i.e. used by XR)
#
#   -host-nics
#   --host-nics <x>     : Number of host taps to initialize (i.e. used by guest VM for host access)
#   -p
#   -pci
#   --pci ...           : Assign a specific PCI passthrough device to QEMU
#                            -pci 05:00.0
#                         or
#                            -pci 0000:05:00.0
#
#                         See this link for more info:
#
#                           http://www.linux-kvm.org/page/How_to_assign_devices_with_VT-d_in_KVM
#
#   -host-nic-type	: 
#   --host-nic-type	: Pass host interface type (default is virtio)
#			: permissible value is e1000
#
#   -passthrough
#   --passthrough ...   : Extra arguments to pass to QEMU unmodified.
#
#   -huge
#   --huge              : Check huge pages are enabled appropriately
#
#   -cpu-pin
#   --cpu-pin a,b,c     : Comma seperated list of CPUs to pin to e.g. 1,2,3,4
#
#   -numa-pin
#   --numa-pin <x>      : Automatically choose only CPUs from the given numa node x
#
#   -cmdline-append
#   --cmdline-append .. : Extra arguments to pass to the Linux cmdline
#                         e.g. -cmdline-append "__development=true"
#   -cmdline-remove
#   --cmdline-remove .. : Extra arguments to pass to the Linux cmdline
#                         e.g. -cmdline-remove "quiet"
#   -qcow2
#   --qcow2             : Create QCOW2 disks during ISO install.
#
#   -export-raw
#   --export-raw        : Once installed, create a raw image from the disk
#                         image. Warning, this will be as large as the disk.
#   -export-qcow2
#   --export-qcow2      : Once installed, create a QCOW2 from the disk image.
#
#   -export-images
#   --export-images     : Once installed, create an OVA and VMDK from the disk image using default OVF tempalte.
#
#   -ovf
#   --ovf <name>        : OVF template to use for OVA generation.
#
#   -topology
#   --topology
#   -topo
#   --topo <name>       : Source a topology file. sunstone.topo will be 
#                         looked for as a default.
#
#                         This topology file then allows you to override 
#                         the bridge names that are used by default.
#
#                         Examples:
#
#                   b2b.topo:
#                  
#                          ####################################################
#                          #
#                          # Creates the following topology
#                          #
#                          #   +---------+    +---------+
#                          #   |  node1  |    |  node2  |
#                          #   +---------+    +---------+
#                          #     1  2  3        1  2  3
#                          #     |  |  |        |  |  |
#                          #     +-----|-[br1]--+  |  |
#                          #        |  |           |  |
#                          #        +--|-[br2]-----+  |
#                          #           |              |
#                          #           +-[br3]--------+
#                          #
#                          ####################################################
#                          case $OPT_NET_AND_NODE_NAME in
#                          *node1*)
#                              BRIDGE_DATA_ETH[1]=${OPT_NET_NAME}br1
#                              BRIDGE_DATA_ETH[2]=${OPT_NET_NAME}br2
#                              BRIDGE_DATA_ETH[3]=${OPT_NET_NAME}br3
#                              ;;
#                          *node2*)
#                              BRIDGE_DATA_ETH[1]=${OPT_NET_NAME}br1
#                              BRIDGE_DATA_ETH[2]=${OPT_NET_NAME}br2
#                              BRIDGE_DATA_ETH[3]=${OPT_NET_NAME}br3
#                              ;;
#                           *)
#                              die "Unhandled node name $OPT_NET_AND_NODE_NAME"
#                              ;;
#                          esac
#                  
#                          ####################################################
#
#                   chain.topo:
#                  
#                          ####################################################
#                          #
#                          # Creates the following topology
#                          #
#                          #   +---------+    +---------+   +---------+
#                          #   |  node1  |    |  node2  |   |  node3  |
#                          #   +---------+    +---------+   +---------+
#                          #     1  2  3        1  2  3       1  2  3
#                          #     |              |  |          |
#                          #     +------[br1]---+  +---[br2]--+
#                          #
#                          case $OPT_NET_AND_NODE_NAME in
#                          *node1*)
#                              BRIDGE_DATA_ETH[1]=${OPT_NET_NAME}br1
#                              ;;
#                          *node2*)
#                              BRIDGE_DATA_ETH[1]=${OPT_NET_NAME}br1
#                              BRIDGE_DATA_ETH[2]=${OPT_NET_NAME}br2
#                              ;;
#                          *node3*)
#                              BRIDGE_DATA_ETH[1]=${OPT_NET_NAME}br2
#                              ;;
#                           *)
#                              die "Unhandled node name $OPT_NET_AND_NODE_NAME"
#                              ;;
#                          esac
#                  
#                          ####################################################
#
#                         And to use this you would then boot 3 instances like:
#
#                           sunstone.sh -node node1 -topo b2b.topo
#                           sunstone.sh -node node2 -topo b2b.topo
#                           sunstone.sh -node node3 -topo b2b.topo
#
#                         To clean (if running in the background) do this:
#
#                           sunstone.sh -node node1 -topo b2b.topo -clean
#                           sunstone.sh -node node2 -topo b2b.topo -clean
#                           sunstone.sh -node node3 -topo b2b.topo -clean
#
#   -host <ip/host>
#   --host <ip/host>    : Use this host address for telnet connectivity. Defaults
#                         to localhost.
#
#   -port <number>
#   --port <number>     : Use this port for serial access. The default is to
#                         randomly allocate port numbers. With this option you
#                         can give fixed port numnbers. If you specify this
#                         option multiple times (up to 4) the port number will
#                         be used for successive serial ports.
#   -bg
#   --bg                : Run in the background. Do not open any consoles.
#
#   -no-reboot
#   --no-reboot         : Exit the script on qemu shutdown
#
#   -debug
#   --debug             : Debug logs
#
#   -verbose
#   --verbose           : Verbose logging, include program name in each line.
#                         Useful when being called from another script.
#
#   -tech-support
#   --tech-support      : Gather tech support info and then exit
#
#   -h
#   -help
#   --help              : This help
#
# October 2014, Neil McGill
#
# Copyright (c) 2014 by Cisco Systems, Inc.
# All rights reserved.
#
# END_OF_HELP

help()
{
    cat $0 | sed '/^# HELP/,/^# END_OF_HELP/!d' | grep -v HELP | sed -e 's/^..//g' | sed 's/^#/ /g'
}

PROGRAM="sunstone.sh"
LAST_OPTION=$0
VERSION="0.9.7"
ORIGINAL_ARGS="$0 $@"
MYPID=$$

init_tool_defaults()
{
    #
    # Choose console automatically if not set
    #
    OPT_UI_LOG=0
    OPT_UI_NO_TERM=0
    OPT_UI_SCREEN=0
    OPT_UI_XTERM=0
    OPT_UI_GNOME_TERMINAL=0
    OPT_UI_KONSOLE=0
    OPT_UI_MRXVT=0

    #
    # -net
    #
    OPT_NET_NAME=$LOGNAME
    OPT_NODE_NAME=

    #
    # --runas
    #
    OPT_ENABLE_RUNAS=1

    #
    # Enable network
    #
    OPT_ENABLE_NETWORK=1

    #
    # Create TAP interfsaces
    #
    OPT_ENABLE_TAPS=1

    #
    # Default configuration file
    #
    OPT_TOPO=sunstone.topo

    #
    # Linux limits the tap length annoyingly and we have to work around this
    #
    MAX_TAP_LEN=15
}

init_platform_defaults_iosxrv_32()
{
    PLATFORM_NAME_WITH_SPACES="Cisco IOS XRv 32 Bit"
    PLATFORM_NAME="IOS-XRv32"
    PLATFORM_name="ios-xrv32"

    OPT_PLATFORM_MEMORY_MB=8192
    OPT_PLATFORM_SMP="-smp cores=4,threads=1,sockets=1"

    #
    # virtio is much faster for XRv32
    #
    NIC_DATA_INTERFACE=virtio-net-pci
    NIC_HOST_INTERFACE=virtio-net-pci

    #
    # No disk virtio support
    #
    OPT_ENABLE_DISK_VIRTIO=0

    #
    # No calvados support
    #
    OPT_ENABLE_SER_3_4=0

    #
    # --enable-kvm
    #
    OPT_ENABLE_KVM=1

    #
    # --smp
    #
    OPT_ENABLE_SMP=1

    OPT_DATA_NICS=3
    OPT_HOST_NICS=3

    #
    # Put the mgmt eth on virbr0 for dhcp
    #
    OPT_HOST_VIRBR0_NIC="1"

    #
    # --enable-numa
    #
    OPT_ENABLE_NUMA=1
}

init_platform_defaults_iosxrv_64()
{
    PLATFORM_NAME_WITH_SPACES="Cisco IOS XRv 64 Bit"
    PLATFORM_NAME="IOS-XRv64"
    PLATFORM_name="ios-xrv64"

    OPT_PLATFORM_MEMORY_MB=16384
    OPT_PLATFORM_VRR_MEMORY_MB=24576
    OPT_PLATFORM_SMP="-smp cores=4,threads=1,sockets=1"

    NIC_DATA_INTERFACE=e1000
    NIC_HOST_INTERFACE=virtio-net-pci

    #
    # On by default for now
    #
    OPT_ENABLE_DEV_MODE=1

    #
    # Sim mode for booting on VXR 
    #
    OPT_ENABLE_SIM_MODE=0

    #
    # Off by default for now
    #
    OPT_ENABLE_CLOUD_MODE=0

    #
    # Enable virtio disks
    #
    OPT_ENABLE_DISK_VIRTIO=1

    #
    # 3rd/4th tty
    #
    OPT_ENABLE_SER_3_4=1

    #
    # --enable-kvm
    #
    OPT_ENABLE_KVM=1

    #
    # --smp
    #
    OPT_ENABLE_SMP=1

    OPT_DATA_NICS=3
    OPT_HOST_NICS=3

    #
    # Connect eth2 (index 3) to virbr0. 
    #
    # Connect eth0 (index 1) for mgmt eth for dhcp.
    #
    OPT_HOST_VIRBR0_NIC="1 3"

    #
    # --enable-numa
    #
    OPT_ENABLE_NUMA=1
}

init_platform_hw_profile_vrr_iosxrv_64()
{
    log "Configuring defaults for VRR (Virtual Route Reflector mode)"

    if [ $OPT_PLATFORM_MEMORY_MB -lt $OPT_PLATFORM_VRR_MEMORY_MB ]; then
        OPT_PLATFORM_MEMORY_MB=$OPT_PLATFORM_VRR_MEMORY_MB

        log "Platform memory set to $OPT_PLATFORM_MEMORY_MB MB"
    fi
}

init_platform_hw_profile_vrr()
{
    case "$PLATFORM_NAME" in
    *XRv64*)
        init_platform_hw_profile_vrr_iosxrv_64
        ;;
    *)
        die "Platform $PLATFORM_NAME does not support profile $OPT_ENABLE_HW_PROFILE"
        ;;
    esac
}

record_usage()
{
    printf "%s: %-10s (---) %-11s %-30s %-80s %s\n" \
        "`date`" \
        "$LOGNAME" \
        "$VERSION" \
        "`hostname`" \
        "$HOST_PLATFORM" \
        "$ORIGINAL_ARGS" >> /ws/nmcgill-sjc/sunstone/usage
}

record_error()
{
    printf "%s: %-10s (ERR) %-11s %-30s %-80s %s\n" \
        "`date`" \
        "$LOGNAME" \
        "$VERSION" \
        "`hostname`" \
        "$HOST_PLATFORM" \
        "$ORIGINAL_ARGS, error is '$*'" >> /ws/nmcgill-sjc/sunstone/usage
}

install_ubuntu()
{
    local PACKAGE=$1

    if [ "$is_ubuntu" = "" ]; then
        return
    fi

    banner "Attempting to install $PACKAGE"

    trace sudo apt-get install $PACKAGE
    if [ $? -ne 0 ]; then
        die "Package install failed for $PACKAGE"
    fi
}

install_centos()
{
    if [ "$is_centos" = "" ]; then
        return
    fi

    banner "Try running the following as root:"
    echo "yum -y install $*"

    #
    # If on cisco workspace?
    #
    for i in \
        /auto/nsstg-tools-hard/bin/sunstone/prepare_qemu_env.sh \
        /auto/rp_dt_panini/jiemiwan/sunstone/prepare_qemu_env.sh
    do
        if [ -x $i ]; then
            banner "Or try running the following as root:"
            echo "$i"
        fi
    done

    exit 1
}

install_package_help()
{
    local PACKAGE=$1

    err "A cricical package, $PACKAGE, is missing"

    case $PACKAGE in
    *qemu*|*kvm*)
        install_ubuntu qemu-system
        install_centos "@virt*"
        ;;

    *brctl*|*tunctl*|*ifconfig*)
        install_ubuntu bridge-utils
        install_ubuntu uml-utilities
        install_centos bridge-utils
        ;;

#    gnome-terminal)
#        install_ubuntu gnome-terminal
#        install_centos gnome-terminal
#        ;;

#    konsole)
#        install_ubuntu konsole
#        install_centos konsole
#        ;;

#    mrxvt)
#        install_ubuntu mrxvt
#        install_centos mrxvt
#        ;;

#    xterm)
#        install_ubuntu xterm
#        install_centos xorg-x11-xauth xterm
#        ;;

#    screen)
#        install_ubuntu screen
#        install_centos screen
#        ;;

    mkisofs)
        install_ubuntu genisoimage
        install_centos genisoimage
        ;;

    isoread)
        install_ubuntu isoread
        install_centos isoread
        ;;

    libvirt-bin)
        install_ubuntu libvirt-bin
        install_centos libvirt-bin
        ;;

    cot)
        banner "Please install COT from https://github.com/glennmatthews/cot"
        exit 1
        ;;

    vmdktool)
        banner "Please install vmdktool from http://www.awfulhak.org/vmdktool/"
        exit 1
        ;;
    esac

    which $PACKAGE
    if [ $? -ne 0 ]; then
        die "Package $PACKAGE is not installed"
    fi
}

sudo_check()
{
    local PROG=$1

    if [ ! -e $PROG ]; then
        local PATH_PROG=`which $PROG`
        if [ ! -e $PATH_PROG ]; then
            err "$PROG does not exist"
            false
            return
        fi

        PROG=$PATH_PROG
    fi

    if [ -u $PROG ]; then
        $*
    else
        chmod +s $PROG &>/dev/null

        if [ -u $PROG ]; then
            $*
        else
            if [ "$is_centos" != "" ]; then
                $*
            else
                sudo $*
                return
            fi
        fi
    fi

    RET=$?
    if [ $? -eq 0 ]; then
        return $RET
    fi

    if [ "$is_centos" != "" ]; then
        return $RET
    fi

    sudo $*
}

sudo_check_trace()
{
    local PROG=$1

    if [ ! -e $PROG ]; then
        local PATH_PROG=`which $PROG`
        if [ ! -e $PATH_PROG ]; then
            err "$PROG does not exist"
            false
            return
        fi

        PROG=$PATH_PROG
    fi

    if [ -u $PROG ]; then
        trace $*
    else
        chmod +s $PROG &>/dev/null

        if [ -u $PROG ]; then
            trace $*
        else
            if [ "$is_centos" != "" ]; then
                trace $*
            else
                trace sudo $*
                return
            fi
        fi
    fi

    RET=$?
    if [ $? -eq 0 ]; then
        return $RET
    fi

    if [ "$is_centos" != "" ]; then
        return $RET
    fi

    trace sudo $*
}

sudo_check_trace_to() {
    local CMD="$1"
    local FILE="$2"

    sudo_check $CMD 2>&1 >$FILE
    RET=$?

    if [ $RET -ne 0 ]; then
        cat $FILE
    fi

    cat $FILE >> $LOG_DIR/$PROGRAM.log
    return $RET
}

assert_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "INFO: For more detailed results, you should run this as root"
        echo "HINT:   sudo $0"
    fi
}

verdict() {
        # Print verdict
        if [ "$1" = "0" ]; then
            echo "KVM acceleration can be used"
        else
            echo "KVM acceleration can NOT be used"
        fi
}

kvm_ok()
{
    # check cpu flags for capability
    virt=$(egrep -m1 -w '^flags[[:blank:]]*:' /proc/cpuinfo | egrep -wo '(vmx|svm)') || true
    [ "$virt" = "vmx" ] && brand="intel"
    [ "$virt" = "svm" ] && brand="amd"

    if [ -z "$virt" ]; then
        echo "INFO: Your CPU does not support KVM extensions"
        assert_root
        verdict 1
        return 1
    fi

    # Now, check that the device exists
    if [ -e /dev/kvm ]; then
        echo "INFO: /dev/kvm exists"
        verdict 0
        return 0
    else
        echo "INFO: /dev/kvm does not exist"
        echo "HINT:   sudo modprobe kvm_$brand"
    fi

    assert_root

    # Prepare MSR access
    msr="/dev/cpu/0/msr"
    if [ ! -r "$msr" ]; then
            modprobe msr
    fi

    if [ ! -r "$msr" ]; then
        echo "You must be root to run this check." >&2
        return 1
    fi

    echo "INFO: Your CPU supports KVM extensions"

    disabled=0
    # check brand-specific registers
    if [ "$virt" = "vmx" ]; then
            BIT=$(rdmsr --bitfield 0:0 0x3a 2>/dev/null || true)
            if [ "$BIT" = "1" ]; then
                    # and FEATURE_CONTROL_VMXON_ENABLED_OUTSIDE_SMX clear (no tboot)
                    BIT=$(rdmsr --bitfield 2:2 0x3a 2>/dev/null || true)
                    if [ "$BIT" = "0" ]; then
                            disabled=1
                    fi
            fi

    elif [ "$virt" = "svm" ]; then
            BIT=$(rdmsr --bitfield 4:4 0xc0010114 2>/dev/null || true)
            if [ "$BIT" = "1" ]; then
                    disabled=1
            fi
    else
            echo "FAIL: Unknown virtualization extension: $virt"
            verdict 1
            return 1
    fi

    if [ "$disabled" -eq 1 ]; then
            echo "INFO: KVM ($virt) is disabled by your BIOS"
            echo "HINT: Enter your BIOS setup and enable Virtualization Technology (VT),"
            echo "      and then hard poweroff/poweron your system"
            verdict 1
            return 0
    fi

    verdict 0
    return 0
}

post_read_options_init_disk_vars()
{
    DISK1_NAME=disk1
    DISK1_SIZE=50G

    if [ "$OPT_INSTALL_CREATE_QCOW2" != "" ]; then
        DISK_TYPE=qcow2
    else
        DISK_TYPE=raw
    fi

    DISK1=${WORK_DIR}${DISK1_NAME}.$DISK_TYPE
}

post_read_options_init_net_vars()
{
    #
    # Keep the name lengths here less than SPACE_NEEDED_FOR_SUFFIX
    #
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        TAP_DATA_ETH[$i]=${OPT_NODE_NAME}Xr$i
        BRIDGE_DATA_ETH[$i]=${OPT_NET_NAME}Br$i
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        TAP_HOST_ETH[$i]=${OPT_NODE_NAME}Lx$i
        BRIDGE_HOST_ETH[$i]=${OPT_NET_NAME}LxBr$i
    done

    #
    # Override the NIC if we are connecting to the virtual bridge
    #
    if [ "$OPT_HOST_VIRBR0_NIC" != "" ]
    then
        for i in $OPT_HOST_VIRBR0_NIC
        do
            BRIDGE_HOST_ETH[$i]="virbr0"
        done
    fi

    if [ -f $OPT_TOPO ]
    then
        log "Sourcing template: $OPT_TOPO"
        . $OPT_TOPO
    fi
}

post_read_options_init_tty_vars()
{
    TTY0_NAME="QEMU"
    TTY1_NAME="Xr"
    TTY2_NAME="XrAux"
    TTY3_NAME="Admin"
    TTY4_NAME="AdAux"

    QEMU_NAME_LONG="QEMU monitor        "
    TTY1_NAME_LONG="Host/IOS XR Console "
    TTY2_NAME_LONG="IOS XR Aux console  "
    TTY3_NAME_LONG="Calvados Console    "
    TTY4_NAME_LONG="Calvados Aux console"

    if [ "$OPT_ENABLE_CLOUD_MODE" = "1" ]; then
        add_linux_cmd "__cloud=true"

        TTY1_NAME="XrAux"
        TTY1_NAME_LONG="IOS XR Aux console  "

        TTY2_NAME="Admin"
        TTY2_NAME_LONG="Calvados Console    "

        TTY3_NAME="AdAux"
        TTY3_NAME_LONG="Calvados Aux console"

        TTY4_NAME="NA"
        TTY4_NAME_LONG="(Host shell NA)     "
    fi

    if [ "$OPT_ENABLE_HW_PROFILE" != "" ]; then
        add_linux_cmd "__hw_profile=$OPT_ENABLE_HW_PROFILE"
    fi

    if [ "$OPT_ENABLE_SIM_MODE" = "1" ]; then
        add_linux_cmd "simulator=true"

        TTY4_NAME="Sim"
        TTY4_NAME_LONG="Linux host shell sim"
    fi

    if [ "$OPT_ENABLE_DEV_MODE" = "1" ]; then
        add_linux_cmd "__development=true"

        TTY4_NAME="Host"
        TTY4_NAME_LONG="Linux host shell dev"
    fi

    if [ "$OPT_ENABLE_VGA" = "1" ]; then
        add_linux_cmd "vga=0x317 "
    fi

    TTY0_CMD_VIRSH_XML=${LOG_DIR}${TTY0_NAME}.virsh.xml
    TTY0_CMD_QEMU=${LOG_DIR}${TTY0_NAME}.cmd.sh

    TTY0_PRE_CMD=${LOG_DIR}${TTY0_NAME}.pre.telnet.sh

    TTY0_CMD=${LOG_DIR}${TTY0_NAME}.telnet.sh
    TTY1_CMD=${LOG_DIR}${TTY1_NAME}.telnet.sh
    TTY2_CMD=${LOG_DIR}${TTY2_NAME}.telnet.sh
    TTY3_CMD=${LOG_DIR}${TTY3_NAME}.telnet.sh
    TTY4_CMD=${LOG_DIR}${TTY4_NAME}.telnet.sh

    TTY0_TELNET_CMD=telnet
    TTY1_TELNET_CMD=telnet
    TTY2_TELNET_CMD=telnet
    TTY3_TELNET_CMD=telnet
    TTY4_TELNET_CMD=telnet

    if [ "$OPT_UI_LOG" = "1" ]; then
        TTY0_TELNET_CMD=expect.sh
        TTY1_TELNET_CMD=expect.sh
        TTY2_TELNET_CMD=expect.sh
        TTY3_TELNET_CMD=expect.sh
        TTY4_TELNET_CMD=expect.sh

        cat >${LOG_DIR}/$TTY0_TELNET_CMD <<%%
#!/usr/bin/expect -f
set timeout 20
set name [lindex \$argv 0]
set port [lindex \$argv 1]
spawn telnet \$name \$port
send "\r"
expect "\r"
interact
%%
        chmod +x ${LOG_DIR}/$TTY0_TELNET_CMD
    fi
}

post_read_options_init()
{
    #
    # MY_QEMU_PID_FILE is made by us
    #
    MY_QEMU_PID_FILE=${WORK_DIR}qemu.pid

    #
    # QEMU_PID_FILE is made by QEMU and may not be readable by a user
    #
    QEMU_PID_FILE=${WORK_DIR}qemu.main.pid

    #
    # For spawned terminal sessions
    #
    MY_TERMINALS_PID_FILE=${WORK_DIR}terminals.pid

    #
    # This process
    #
    MY_PID_FILE=${WORK_DIR}sunstone.pid

    post_read_options_init_disk_vars
    post_read_options_init_net_vars
    post_read_options_init_tty_vars

    trap "errexit" 1 2 15 ERR SIGINT SIGTERM EXIT

    local HOST=`hostname`

    log "Work dir: $WORK_DIR"
    log "Logs    : $LOG_DIR"
    log "Version : $VERSION"
    log "User    : $LOGNAME@${HOST}"
    log "Host    : $HOST_PLATFORM"

    if [ "$is_centos" != "" ]; then
        log "OS      : Centos"
    fi

    if [ "$is_ubuntu" != "" ]; then
        log "OS      : Ubuntu"
    fi

    if [ "$is_fedora" != "" ]; then
        log "OS      : Fedora"
    fi
}

#
# Clean up any user options, checking for possible errors
#
post_read_options_fini_check_tap_names()
{
    if [ "$OPT_CLEAN" != "" ]; then
        #
        # Force a clean
        #
        OPT_FORCE=1

        log "Clean only"
        cleanup_at_start_forced

        exit 0
    fi

    #
    # Clean up previous instance if there is one running
    #
    cleanup_at_start
}

post_read_options_fini_check_terminal()
{
    #
    # Logging only, no terminals launched
    #
    if [ "$OPT_UI_LOG" -eq 1 ]; then
        return
    fi

    #
    # Not needed to check this for running in the background
    #
    if [ "$OPT_RUN_IN_BG" != "" ]; then
        if [ "$OPT_UI_SCREEN" = 0           -a \
             "$OPT_UI_GNOME_TERMINAL" = 0   -a \
             "$OPT_UI_KONSOLE" = 0          -a \
             "$OPT_UI_MRXVT" = 0            -a \
             "$OPT_UI_XTERM" = 0            ]
        then
            return
        fi
    fi

    if [ "$OPT_UI_NO_TERM" -eq 1 ]; then
        return
    fi

    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    log "Checking terminal type is installed"

    MRXVT=`which mrxvt 2>/dev/null`
    for i in \
        /auto/edatools/oicad/tools/vxr_user/vxr_latest/mrxvt-05b/bin/mrxvt \
        $MRXVT
    do
        if [ -x $i ]; then
            log_debug " Found $i"
            MRXVT=$i
            break
        fi
    done

    if [ "$OPT_UI_GNOME_TERMINAL" != 0 ]; then
        which gnome-terminal &>/dev/null
        if [ $? -ne 0 ]; then
            err "Could not use gnome-terminal as terminal, not found"
            install_package_help gnome-terminal
            OPT_UI_GNOME_TERMINAL=1
            which gnome-terminal &>/dev/null
            if [ $? -ne 0 ]; then
                OPT_UI_GNOME_TERMINAL=0
            fi
        else
            log_debug " Found gnome-terminal"
        fi
    fi

    if [ "$OPT_UI_KONSOLE" != 0 ]; then
        which konsole &>/dev/null
        if [ $? -ne 0 ]; then
            err "Could not use konsole as terminal, not found"
            install_package_help konsole

            which konsole &>/dev/null
            if [ $? -ne 0 ]; then
                OPT_UI_KONSOLE=0
            fi
        else
            log_debug " Found konsole"
        fi
    fi

    if [ "$OPT_UI_MRXVT" != 0 ]; then
        which $MRXVT &>/dev/null
        if [ $? -ne 0 ]; then
            err "Could not use mrxvt as terminal, not found"
            install_package_help mrxvt

            which $MRXVT &>/dev/null
            if [ $? -ne 0 ]; then
                OPT_UI_MRXVT=0
            fi
        else
            log_debug " Found mrxvt"
        fi
    fi

    if [ "$OPT_UI_XTERM" != 0 ]; then
        which xterm &>/dev/null
        if [ $? -ne 0 ]; then
            err "Could not use xterm as terminal, not found"
            install_package_help xterm

            which xterm &>/dev/null
            if [ $? -ne 0 ]; then
                OPT_UI_XTERM=0
            fi
        else
            log_debug " Found xterm"
        fi
    fi

    if [ "$OPT_UI_SCREEN" != 0 ]; then
        which screen &>/dev/null
        if [ $? -ne 0 ]; then
            err "Could not use screen as terminal, not found"
            install_package_help screen

            which screen &>/dev/null
            if [ $? -ne 0 ]; then
                OPT_UI_SCREEN=0
            fi
        else
            log_debug " Found screen"
        fi

        if [ ! -f ~/.screenrc ]; then
            cat >~/.screenrc <<%%
escape ^Gg
shell -${SHELL}
#
# Quiet
#
startup_message off
#
# Auto launch
#
altscreen on
#
# Undo screen split (S)
#
bind o only
#
# Copy mode - editor in your shell!
#
bind c copy
#
# New window
#
bind n screen
#
# Prev/next screen
#
bind h prev
bind l next
#
# Up down in split screen
#
bind j focus down
bind k focus up
bind q quit
#
# Bold as GREEN
#
attrcolor b "G"
#
# Allow xterm renaming to work
#
termcapinfo xterm*|rxvt*|kterm*|Eterm* 'hs:ts=\E]0;:fs=\007:ds=\E]0;\007'
hardstatus alwayslastline "%{= g} %{= w}%-w%{=r}%n* %t%{-}%+W"

defhstatus "screen ^E (^Et) | $USER@^EH"
hardstatus off
#
# To allow scrolling on gnome-terinal
#
termcapinfo xterm ti@:te@
screen -t shell       0       bash -ls
screen -t shell       1       bash -ls
%%

            cat <<%%
###############################################################################
#
# You had no ~/.screenrc and want to use screen. I have created a sample
# file for you. To run this script however with screen, please run 'screen' and
# then re-run this script. This will allow screen to open new tabs within your
# screen session.
#
# To use screen:
#
#     To move to tab number N:           press "ctrl-g <N>"
#     To move to the tab on the right:   press "ctrl-g l"
#     To move to the tab on the left:    press "ctrl-g h"
#     To close a tab                     press "ctrl-g K"
#
###############################################################################
%%
            die "Please run screen and then retry."
        else
            log_low " Found .screenrc"
        fi

        if [ "$STY" = "" ]; then
            die "Please run screen first and then retry."
        fi
    fi

    #
    # Make sure at least one terminal is enabled
    #
    if [ "$OPT_UI_SCREEN" = 0           -a \
         "$OPT_UI_GNOME_TERMINAL" = 0   -a \
         "$OPT_UI_KONSOLE" = 0          -a \
         "$OPT_UI_MRXVT" = 0            -a \
         "$OPT_UI_XTERM" = 0            ]
    then
        #
        # Highest priority, most likely to work.
        #
        which $MRXVT &>/dev/null
        if [ $? -eq 0 ]; then
            log_debug " Chose mrxvt as default terminal"
            OPT_UI_MRXVT=1
            return
        fi

        which gnome-terminal &>/dev/null
        if [ $? -eq 0 ]; then
            log_debug " Chose gnome-terminal as default terminal"
            OPT_UI_GNOME_TERMINAL=1
            return
        fi

        which konsole &>/dev/null
        if [ $? -eq 0 ]; then
            log_debug " Chose konsole as default terminal"
            OPT_UI_KONSOLE=1
            return
        fi

        which xterm &>/dev/null
        if [ $? -eq 0 ]; then
            log_debug " Chose xterm as default terminal"
            OPT_UI_XTERM=1
            return
        fi

        which screen &>/dev/null
        if [ $? -eq 0 ]; then
            log_debug " Chose screen as default terminal"
            OPT_UI_SCREEN=1
            return
        fi

        err "Cannot find any graphical terminal to use."
        install_package_help gnome-terminal
        post_read_options_fini_check_terminal
    fi
}

post_read_options_apply_qemu_network_options()
{
    if [ "$OPT_ENABLE_NETWORK" = "0" ]; then
        return
    fi

    #
    # Add all 10Gig interfaces
    #
    add_qemu_cmd_10g

    get_next_mac_addresses

    if [ "$OPT_ENABLE_TAPS" = "1" ]; then
        for i in $(seq 1 $OPT_HOST_NICS)
        do
            add_qemu_cmd "-netdev tap,id=host$i,ifname=${TAP_HOST_ETH[$i]},script=no,downscript=no "
        done

        for i in $(seq 1 $OPT_HOST_NICS)
        do
            add_qemu_cmd "-device ${NIC_HOST_INTERFACE},romfile=,netdev=host$i,id=host$i,mac=${MAC_HOST_ETH[$i]} "
        done

        for i in $(seq 1 $OPT_DATA_NICS)
        do
            add_qemu_cmd "-netdev tap,id=data$i,ifname=${TAP_DATA_ETH[$i]},script=no,downscript=no "
        done

        for i in $(seq 1 $OPT_DATA_NICS)
        do
            add_qemu_cmd "-device ${NIC_DATA_INTERFACE},romfile=,netdev=data$i,id=data$i,mac=${MAC_DATA_ETH[$i]} "
        done
    else
        for i in $(seq 1 $OPT_HOST_NICS)
        do
            add_qemu_cmd "-device ${NIC_HOST_INTERFACE},romfile=,id=host$i,mac=${MAC_HOST_ETH[$i]} "
        done

        for i in $(seq 1 $OPT_DATA_NICS)
        do
            add_qemu_cmd "-device ${NIC_DATA_INTERFACE},romfile=,id=data$i,mac=${MAC_DATA_ETH[$i]} "
        done
    fi
}

post_read_options_apply_qemu_options()
{
    add_qemu_cmd "-m $OPT_PLATFORM_MEMORY_MB"

    if [ $OPT_ENABLE_SMP -eq 1 ]; then
        add_qemu_cmd "$OPT_PLATFORM_SMP"
    fi

    if [ $OPT_ENABLE_KVM -eq 1 ]; then
        add_qemu_cmd "-enable-kvm"
    fi

    add_qemu_cmd "-daemonize"

    case "$QEMU_VERSION" in
        *version\ 0.)
            log "QEMU version < 1.4 tweaks"

            OPT_DISABLE_VGA="-nographic"
            ;;

        *version\ 1.[0123]*)
            log "QEMU version < 1.4 tweaks"
            OPT_DISABLE_VGA="-nographic"
            ;;

        *version\ 1.[456789]*)
            log "QEMU version >= 1.4 tweaks"
            OPT_DISABLE_VGA="-display none"
            ;;

        *version\ 2.*)
            log "QEMU version >= 2.0 tweaks"
            OPT_DISABLE_VGA="-display none"
            sudo echo 0 > /proc/sys/kernel/numa_balancing
            ;;
    esac

    if [ "$OPT_ENABLE_VGA" = "1" ]; then
        #
        # Would like to use SDL but it is buggy in QEMU 1.0
        #
        if [ "$OPT_VNC_SERVER" != "" ]; then
            add_qemu_cmd "-vnc $OPT_VNC_SERVER"
        else
            add_qemu_cmd "-vnc :0"
        fi

        add_qemu_cmd "-vga std"
    else
        add_qemu_cmd "$OPT_DISABLE_VGA"
    fi

    add_qemu_cmd "-rtc base=utc"

    add_qemu_cmd "-name $PLATFORM_NAME:$OPT_NET_NAME"

    if [ "$OPT_ENABLE_EXIT_ON_QEMU_REBOOT" = "1" ]; then
        add_qemu_cmd "-no-reboot"
    fi

    if [ $OPT_ENABLE_RUNAS -eq 1 ]; then
        if [ "$LOGNAME" != "root" ]; then
            add_qemu_cmd "-runas $LOGNAME"
        fi
    fi

    post_read_options_apply_qemu_network_options
}

post_read_options_fini_check_should_qemu_start()
{
    #
    # Default to a need to launch QEMU
    #
    QEMU_SHOULD_START=1

    #
    # Check if we want to launch QEMU
    #
    if [ "$OPT_EXPORT_QCOW2"  != "" -o \
         "$OPT_EXPORT_RAW"    != "" -o \
         "$OPT_EXPORT_IMAGES" != "" ]
    then
        #
        # We have an existing disk image and can export without needing to boot
        #
        if [ -f "$DISK1" ]; then
            if [ "$OPT_ENABLE_RECREATE_DISKS" = "" ]; then
                log "QEMU launch not needed for export"
                log_low " Use -r to force recreate of disks"
                QEMU_SHOULD_START=
                return
            else
                log "Will recreate disk image for VMDK creation"
            fi
        fi
    fi
}

#
# Last check of any user options, checking for possible errors
#
post_read_options_fini()
{
    post_read_options_fini_check_should_qemu_start

    post_read_options_fini_check_tap_names

    post_read_options_fini_check_terminal

    if [ "$OPT_TECH_SUPPORT" != "" ]; then
        exit 0
    fi
}

check_centos_install_is_ok()
{
    if [ "$is_centos" = "" ]; then
        return
    fi

    log "Checking centos tools are installed"

    local EXIT=

    for f in `which brctl 2>/dev/null`                  \
             `which tunctl 2>/dev/null`                 \
             `which ifconfig 2>/dev/null`
    do
        if [ ! -f "$f" ]; then
            err "$f not found."
            EXIT=1
            continue
        fi

        if [ ! -u $f ]; then
            trace chmod +s $f
            if [ $? -eq 0 ]; then
                if [ "$EXIT" = "" ]; then
                    err "Failed to  $f. Please run the following as root:"
                    echo chmod +s $f
                fi
                EXIT=1
            fi

            if [ ! -u $f ]; then
                if [ "$EXIT" = "" ]; then
                    err "Failed to suid $f. Please run the following as root:"
                    echo chmod +s $f
                fi
                EXIT=1
            fi
        else
            log_debug " Found $f, setuid set"
        fi
    done

    if [ "$EXIT" != "" ]; then
        exit 1
    fi

    #
    # If KVM runs under a different ID, we need to allow access
    #
    log "Changing exec perm of local dir for qemu access"
    trace chmod +x `pwd`

    true
}

check_sudo_access()
{
    if [ "$is_ubuntu" = "" ]; then
        return
    fi

    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    log "Checking for sudo access"

    sudo -n grep "$LOGNAME.*NOPASSWD" /etc/sudoers &>/dev/null
    if [ $? -ne 0 ]; then
        banner "I need to add you to /etc/sudoers"
        log "Enter the root password so I can modify /etc/sudoers"

        su -c "cat <<EOF >> /etc/sudoers
$LOGNAME ALL=(ALL:ALL) ALL
$LOGNAME ALL=(ALL) NOPASSWD:ALL
EOF"

        echo $LOGNAME ALL=NOPASSWD: ALL | sudo tee -a /etc/sudoers
        if [ $? -ne 0 ]; then
            err "Failed to add $LOGNAME to sudoers to avoid password entry"
        fi

        sudo grep "$LOGNAME.*NOPASSWD" /etc/sudoers
        if [ $? -ne 0 ]; then
            err "Failed to find $LOGNAME in /etc/sudoers. Struggling on."
        fi
    else
        log_debug " Found"
    fi
}

check_kvm_accel()
{
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    if [ $OPT_ENABLE_KVM -eq 0 ]; then
        return
    fi

    log "Checking for KVM acceleration"

    which kvm-ok &>/dev/null
    if [ $? -eq 0 ]; then
        kvm-ok &>/dev/null
    else
        kvm_ok &>/dev/null
    fi

    if [ $? != 0 ]; then
        banner "You need KVM acceleration support on this host"

        which kvm-ok &>/dev/null
        if [ $? -eq 0 ]; then
            kvm-ok
        else
            kvm_ok
        fi

        exit 1
    fi

    log_debug " Found"
}

check_ubuntu_install_is_ok()
{
    check_sudo_access
}

check_host_bridge_is_ok()
{
    if [ "$OPT_ENABLE_TAPS" = "0" ]; then
        return
    fi

    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    local EXIT=

    log "Checking for host bridge (virbr0) support"

    ifconfig virbr0 &>/dev/null
    if [ $? -eq 0 ]; then
        log_debug " Found"

        return
    fi

    err "Not found. virbr0 is neded for host connectivity from VM"
    install_package_help libvirt-bin

    ifconfig virbr0 &>/dev/null
    if [ $? -eq 0 ]; then
        return
    fi

    err "Lack of virbr0 will prevent the device from learning an IP address via DHCP; i.e. host connectivity will be impacted. Will continue anyway."

    if [ "$OPT_FORCE" = "" ]; then
        sleep 5
    fi
}

check_qemu_install_is_ok()
{
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    log "Checking QEMU is installed"

    local EXIT=

    for i in \
             /usr/libexec/qemu-kvm                          \
             /usr/libexec/kvm                               \
             /usr/bin/kvm                                   \
             /usr/bin/qemu-system-x86_64                    \
             /auto/xrut/sw/cel-5/bin/qemu-system-x86_64     \
             `which qemu-kvm &>/dev/null`                   \
             `which kvm &>/dev/null`                        \
             `which qemu-system-x86_64 &>/dev/null`
    do
        if [ -x $i ]; then
            if [ -u $i ]; then
                log_low " Found $i, setuid set"
                KVM_EXEC="$i"
                EXIT=
                break
            else
                #
                # Enable run-as-root on qemu for centos where sudo is not used
                # often
                #
                chmod +s $i &>/dev/null

                if [ -u $i ]; then
                    KVM_EXEC="$i"
                    log_low " Found $KVM_EXEC, setuid set"
                    EXIT=
                    break
                else
                    if [ "$is_ubuntu" != "" ]; then
                        log_low " Found $i, need sudo"
                        KVM_EXEC="sudo $i"
                        EXIT=
                        break
                    elif [ "${is_centos}" != "" ]; then
                        if [ "$EXIT" = "" ]; then
                            err "Failed to suid $i. Please run the following as root:"
                            echo chmod +s $i
                        fi
                        EXIT=1
                    else
                        KVM_EXEC="$i"
                        EXIT=
                        break
                    fi
                fi
            fi
        fi
    done

    if [ "$EXIT" != "" ]; then
        exit 1
    fi

    if [ "$KVM_EXEC" = "" ]; then
        banner "Could not find KVM or QEMU to run"
        install_package_help qemu-system
        check_qemu_install_is_ok
    fi

    log "QEMU version:installed"
    QEMU_VERSION=`$KVM_EXEC --version`
    log_low " $QEMU_VERSION"

    check_qemu_img_install_is_ok
}

check_qemu_img_install_is_ok()
{
    log "Checking qemu-img is installed"

    for i in /auto/xrut/sw/cel-5/bin/qemu-img               \
             `which qemu-img 2>/dev/null`
    do
        if [ -x $i ]; then
            QEMU_IMG_EXEC="$i"
            log_debug " Found $QEMU_IMG_EXEC"
            break
        fi
    done

    if [ "$QEMU_IMG_EXEC" = "" ]; then
        banner "Could not find qemu-img to run"
        install_package_help qemu-img
        check_qemu_img_install_is_ok
    fi
}

check_net_tools_installed()
{
    if [ "$OPT_ENABLE_TAPS" = "0" ]; then
        return
    fi

    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    log "Checking networking tools are installed"

    which brctl &> /dev/null
    if [ $? != 0 ]; then
        install_package_help brctl
    else
        log_debug " Found brctl"
    fi

    which tunctl &> /dev/null
    if [ $? != 0 ]; then
        install_package_help tunctl
    else
        log_debug " Found tunctl"
    fi

    which ifconfig &> /dev/null
    if [ $? != 0 ]; then
        install_package_help ifconfig
    else
        log_debug " Found ifconfig"
    fi
}

#function to enable device passthrough
function allow_unsafe_assigned_int_fordevicepassthru ()
{
   if [ -f /sys/module/kvm/parameters/allow_unsafe_assigned_interrupts ]; then

	sudo echo 1 > /sys/module/kvm/parameters/allow_unsafe_assigned_interrupts
   fi

}

create_log_dir()
{
    init_colors

    #
    # -workdir
    #
    if [ "$OPT_WORK_DIR_HOME" != "" ]; then
        WORK_DIR=$OPT_WORK_DIR_HOME/workdir-${OPT_NODE_NAME}/
    else
        WORK_DIR=workdir-${OPT_NODE_NAME}/
    fi

    #
    # Store logs locally and use the date to avoid losing old logs
    #
    LOG_DATE=`date "+%a_%b_%d_at_%H_%M"`
    LOG_DIR=${WORK_DIR}logs/$LOG_DATE/

    WORK_DIR=`echo $WORK_DIR | sed 's;//;/;g'`
    LOG_DIR=`echo $LOG_DIR | sed 's;//;/;g'`

    mkdir -p $WORK_DIR
    if [ ! -d $WORK_DIR ]; then
        die "Failed to make working dir, $WORK_DIR"
    fi

    mkdir -p $LOG_DIR
    if [ ! -d $LOG_DIR ]; then
        die "Failed to make log dir, $LOG_DIR in " `pwd` " " `mkdir -p $LOG_DIR`
    fi

    if [ $? -ne 0 ]; then
        LOG_DIR=/tmp/$LOGNAME/logs/$LOG_DATE
        mkdir -p $LOG_DIR
        if [ $? -ne 0 ]; then
            LOG_DIR=.
        fi
    fi

    #
    # Redirect stdout into a named pipe.
    #
    exec > >(tee -a $LOG_DIR/$PROGRAM.console.log)

    #
    # Same for stderr
    #
    exec 2>&1
}

brctl_delbr()
{
    local BRIDGE=$1

    if [ "$BRIDGE" = "" ]; then
        err "No bridge specified in $FUNCNAME"
        backtrace
        return
    fi

    if [ ! -d /sys/devices/virtual/net/$BRIDGE ]; then
        return
    fi

    if [ `brctl_count_if $BRIDGE` -ne 0 ]
    then
        log "Not deleting bridge $BRIDGE, still in use:"
        brctl show $BRIDGE
        return
    fi

    log "Deleting bridge $BRIDGE"

    sudo_check_trace ifconfig_down $BRIDGE
    sudo_check_trace brctl delbr $BRIDGE

    if [ -d /sys/devices/virtual/net/$BRIDGE ]; then
        err "Could not delete bridge $BRIDGE"
    fi
}

brctl_delif()
{
    local BRIDGE=$1
    local TAP=$2

    if [ "$BRIDGE" = "" ]; then
        err "No bridge specified in $FUNCNAME"
        backtrace
        return
    fi

    if [ "$TAP" = "" ]; then
        err "No tap specified in $FUNCNAME"
        backtrace
        return
    fi

    if [ "$BRIDGE" = "virbr0" ]
    then
        log "Not removing $TAP from virbr to avoid route flap."
        log "Please remove it manually if you need to."
        return
    fi

    if [ -d /sys/devices/virtual/net/$TAP ]; then
        #
        # Check the if is enslaved to this bridge
        #
        sudo_check_trace brctl show $BRIDGE | grep -q "\<$TAP\>"
        if [ $? -eq 0 ]; then
            log_debug "Deleting bridge $BRIDGE interface $TAP"

            sudo_check_trace brctl delif $BRIDGE $TAP

            sudo_check_trace brctl show $BRIDGE | grep -q "\<$TAP\>"
            if [ $? -eq 0 ]; then
                err "Could not remove tap $TAP from bridge $BRIDGE"
            fi
        fi
    fi
}

brctl_count_if()
{
    local BRIDGE=$1

    if [ "$BRIDGE" = "" ]; then
        err "No bridge specified in $FUNCNAME"
        backtrace
        return
    fi

    if [ ! -d /sys/devices/virtual/net/$BRIDGE ]; then
        echo 0
        return
    fi

    /bin/ls -1 /sys/devices/virtual/net/$BRIDGE/brif 2>/dev/null | wc -l
}

tunctl_del()
{
    local TAP=$1

    if [ "$TAP" = "" ]; then
        err "No tap specified in $FUNCNAME"
        backtrace
        return
    fi

    if [ ! -d /sys/devices/virtual/net/$TAP ]; then
        return
    fi

    TRIES=0
    while [ $TRIES -lt 3 ]
    do
        if [ -d /sys/devices/virtual/net/$TAP ]; then
            log "Deleting tap interface $TAP"

            sudo_check_trace tunctl -d $TAP

            if [ ! -d /sys/devices/virtual/net/$TAP ]; then
                return
            fi

            sleep 1
        fi

        TRIES=$(expr $TRIES + 1)
    done

    err "Could not remove tap $TAP, tried $TRIES times. Try running with -clean to clean up the old instance if there is one?"
}

ifconfig_down()
{
    local INTERFACE=$1

    if [ "$INTERFACE" = "" ]; then
        err "No interface specified in $FUNCNAME"
        backtrace
        return
    fi

    if [ -d /sys/devices/virtual/net/$INTERFACE ]; then
        sudo_check_trace ifconfig $INTERFACE down
    fi
}

cleanup_taps_force()
{
    I_CREATED_TAPS=

    for i in $(seq 1 $OPT_DATA_NICS)
    do
        ifconfig_down ${TAP_DATA_ETH[$i]}
        brctl_delif ${BRIDGE_DATA_ETH[$i]} ${TAP_DATA_ETH[$i]}
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        ifconfig_down ${TAP_HOST_ETH[$i]}
        brctl_delif ${BRIDGE_HOST_ETH[$i]} ${TAP_HOST_ETH[$i]}
    done

    #
    # Assume there are other instances running we do not want to touch
    #
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        BRIDGE=${BRIDGE_DATA_ETH[$i]}
        brctl_delbr $BRIDGE
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        #
        # Avoid touching the virtual bridge as it has led to hangs in the past 
        # on the host
        #
        BRIDGE=${BRIDGE_HOST_ETH[$i]}
        if [ "$BRIDGE" = "virbr0" ]; then
            continue
        fi

        brctl_delbr $BRIDGE
    done

    for i in $(seq 1 $OPT_DATA_NICS)
    do
        tunctl_del ${TAP_DATA_ETH[$i]}
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        tunctl_del ${TAP_HOST_ETH[$i]}
    done
}

cleanup_taps()
{
    if [ "$I_CREATED_TAPS" = "" ]; then
        return
    fi

    cleanup_taps_force
}

#
# Check if the taps may be in use in another VM and if we really want to
# remove them
#
cleanup_taps_check()
{
    local CLEANUP=0

    for n in $(seq 1 $OPT_DATA_NICS)
    do
        for i in ${TAP_DATA_ETH[$n]}
        do
            if [ -d /sys/devices/virtual/net/$i ]; then
                ps awwwwx | grep -v grep | grep -q "\<$i\>"
                if [ $? -eq 0 ]; then
                    err "Tap $i is in use by:" `ps awwwwx | grep -v grep | grep "\<$i\>"`
                else
                    log "Tap $i exists but is not in use?"
                fi

                CLEANUP=1
            fi
        done
    done

    for n in $(seq 1 $OPT_HOST_NICS)
    do
        for i in ${TAP_HOST_ETH[$n]}
        do
            if [ -d /sys/devices/virtual/net/$i ]; then
                ps awwwwx | grep -v grep | grep -q "\<$i\>"
                if [ $? -eq 0 ]; then
                    err "Tap $i is in use by:" `ps awwwwx | grep -v grep | grep "\<$i\>"`
                else
                    log "Tap $i exists but is not in use?"
                fi

                CLEANUP=1
            fi
        done
    done

    if [ "$CLEANUP" = "0" ]; then
        return
    fi

    local CLEAN=0

    if [ "$OPT_FORCE" = "" ]; then
        while true; do

            cat <<%%



********************************************************************************
*                       ---- Please read carefully ----                        *
*                                                                              *
* Interfaces I am trying to use are already in use. Check that there is not    *
* an existing KVM instance using these taps.                                   *
*                                                                              *
* You can use the "-net <name>" option to use a different network name if so.  *
*                                                                              *
* Hit enter below to exit with no changes.                                     *
*                                                                              *
* Or enter yes to try to use these existing interfaces.                        *
*                                                                              *
*                       ^^^^ Please read carefully ^^^^                        *
********************************************************************************



%%

            read -p "Use existing in-use interfaces [no]?" yn
            case $yn in
                [Yy]* ) break;;
                * ) exit;;
            esac
        done

        log "Attempting to use same taps."
        CLEAN=1
    else
        log "Doing a clean before start"
        CLEAN=1
    fi

    if [ "$CLEAN" = "1" ]; then
        cleanup_at_start_forced
    fi
}

cleanup_my_pid_file()
{
    if [ -s $MY_PID_FILE ]; then
        for i in `cat $MY_PID_FILE`
        do
            #
            # No suicide
            #
            if [ $MYPID -eq $i ]; then
                continue
            fi

            log "Doing a forced kill of my old pid file"

            PSNAME=`ps -p $i -o comm=`
            log "Killing my pid $i $PSNAME"
            trace kill $i 2>/dev/null

            while true
            do
                ps $i &>/dev/null
                if [ $? -eq 0 ]; then
                    log "Waiting for PID $i to exit cleanly"
                    sleep 1
                    continue
                fi

                break
            done
        done
    fi

    rm -f $MY_PID_FILE
}

cleanup_terminal_pids()
{
    if [ -s $MY_TERMINALS_PID_FILE ]; then
        log "Doing a forced kill of old terminal PIDs"

        for i in `cat $MY_TERMINALS_PID_FILE`
        do
            PSNAME=`ps -p $i -o comm=`
            log "Killing terminal pid $i $PSNAME"
            trace kill $i 2>/dev/null
        done
    fi

    rm -f $MY_TERMINALS_PID_FILE &>/dev/null
}

cleanup_qemu_pid()
{
    find_qemu_pid_one_shot

    #
    # Check we can read the QEMU pid file
    #
    if [ ! -f $MY_QEMU_PID_FILE ]
    then
        return
    fi

    cat $MY_QEMU_PID_FILE &>/dev/null
    if [ $? -ne 0 ]; then
        log "Doing a forced kill of old QEMU PIDs"

        $SUDO cat $MY_QEMU_PID_FILE &>/dev/null
        if [ $? -ne 0 ]; then
            err "Could not read $MY_QEMU_PID_FILE"
            err "You may need to do:"
            err "  kill \`cat $MY_QEMU_PID_FILE\`"
            sleep 3
        fi

        for i in `$SUDO cat $MY_QEMU_PID_FILE 2>/dev/null`
        do
            PSNAME=`ps -p $i -o comm=`
            log "Killing QEMU pid $i $PSNAME"
            trace kill $i 2>/dev/null
            trace $SUDO kill $i 2>/dev/null

            #
            # Give time to exit
            #
            sleep 3

            #
            # If it still exists, try harder
            #
            ps $i &>/dev/null
            if [ $? -eq 0 ]; then
                log "Killing -9 QEMU pid $i $PSNAME"
                trace kill -9 $i 2>/dev/null
                trace $SUDO kill -9 $i 2>/dev/null
            fi
        done
    else
        for i in `cat $MY_QEMU_PID_FILE 2>/dev/null`
        do
            PSNAME=`ps -p $i -o comm=`
            log "Killing QEMU pid $i $PSNAME"
            trace kill $i 2>/dev/null

            #
            # Give time to exit
            #
            sleep 3

            #
            # If it still exists, try harder
            #
            ps $i &>/dev/null
            if [ $? -eq 0 ]; then
                PSNAME=`ps -p $i -o comm=`
                log "Killing -9 QEMU pid $i $PSNAME"
                trace kill -9 $i 2>/dev/null
            fi
        done
    fi

    rm -f $MY_QEMU_PID_FILE &>/dev/null
    $SUDO rm -f $MY_QEMU_PID_FILE &>/dev/null
}

cleanup_qemu_and_terminals_forced()
{
    cleanup_terminal_pids

    cleanup_qemu_pid
}

cleanup_qemu_and_terminals()
{
    if [ "$I_STARTED_VM" = "" ]; then
        return
    fi

    I_STARTED_VM=

    cleanup_qemu_and_terminals_forced
}


tech_support_gather_()
{
    local WHAT=$1
    shift

    echo
    echo $WHAT
    echo $WHAT | sed 's/./=/g'
    echo
    echo " $*"
    $*
}

tech_support_gather()
{
    local WHAT=$1
    shift

    log_debug "+ $WHAT"

    tech_support_gather_ "$WHAT" "$*" >>$TECH_SUPPORT 2>&1
}

tech_support()
{
    TECH_SUPPORT=$PWD/${LOG_DIR}tech-support

    log "Gathering tech support info"

    tech_support_gather "Tool version"      "echo $VERSION"
    tech_support_gather "Tool arguments"    "echo $ORIGINAL_ARGS"

    tech_support_gather "Kernel version"    "uname -a"
    tech_support_gather "Kernel cmdline"    "cat /proc/cmdline"
    uname=$(uname -r)
    tech_support_gather "Kernel flags"      "/boot/config-$uname"
    tech_support_gather "Kernel logs"       "dmesg"
    tech_support_gather "Kernel settings"   "sysctl -a"
    tech_support_gather "Ulimits"           "ulimit -a"
    tech_support_gather "QEMU version"      "$KVM_EXEC --version"
    tech_support_gather "PCI info"          "lspci"

    tech_support_gather "Disk usage"        "df"
    tech_support_gather "Top processes"     "top -b -n 1"
    tech_support_gather "Processes"         "ps -ef"
    tech_support_gather "Free mem"          "free"
    tech_support_gather "Free mem (gig)"    "free -g"
    tech_support_gather "Virtual memory"    "vmstat"
    tech_support_gather "NUMA nodes"        "numactl -show"
    tech_support_gather "NUMA memory"       "numastat -show"
    tech_support_gather "NUMA memory"       "numastat -v"
    tech_support_gather "NUMA memory"       "numastat -m"
    tech_support_gather "Open files"        "lsof"
    tech_support_gather "Bridged and taps"  "find /sys/devices/virtual/net"
    tech_support_gather "Route"             "route"
    tech_support_gather "Bridges"           "brctl show"
    tech_support_gather "Interfaces"        "ifconfig -a"
    tech_support_gather "Virbr0 ARP"        "arp -n -i virbr0"
    tech_support_gather "iptables"          "iptables --list"

    for i in `echo ${LOG_DIR}/*.xml`
    do
        tech_support_gather "$i" "cat $i"
    done

    for i in `echo ${LOG_DIR}/*.log`
    do
        tech_support_gather "$i" "cat $i"
    done

    log "Tech support info:"

    readlink -f $TECH_SUPPORT
}

cleanup_at_exit()
{
    lock_release

    fix_output $LOG_DIR/$TTY0_NAME.log &>/dev/null
    fix_output $LOG_DIR/$TTY1_NAME.log &>/dev/null
    fix_output $LOG_DIR/$TTY2_NAME.log &>/dev/null
    fix_output $LOG_DIR/$TTY3_NAME.log &>/dev/null
    fix_output $LOG_DIR/$TTY4_NAME.log &>/dev/null

    cleanup_qemu_and_terminals
    cleanup_taps
    cleanup_my_pid_file

    log "Logs in $LOG_DIR"

    #
    # Record some potentially useful info. Need to do this last as we record
    # our own output.
    #
    #tech_support
}

cleanup_at_start()
{
    cleanup_my_pid_file
    cleanup_qemu_and_terminals
    cleanup_taps_check
}

cleanup_at_start_forced()
{
    cleanup_my_pid_file
    cleanup_qemu_and_terminals_forced
    cleanup_taps_force
}

commonexit()
{
    cleanup_at_exit
}

errexit()
{
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        okexit
        return
    fi

    if [ "$EXITING" != "" ]; then
        exit $RET
    fi

    EXITING=1

    RET=$EXIT_CODE

    err "Exiting, code $RET"

    commonexit

    exit $RET
}

okexit()
{

    if [ "$EXITING" != "" ]; then
        exit 0
    fi

    EXITING=1

    log "Exiting..."

    if [ "$OPT_RUN_IN_BG" != "" ]; then
        if [ "$I_STARTED_VM" = "" ]; then
            log "Exiting, no instance running"
        else
            log "Exiting and leaving instance running, pid:"
            log_low " $MY_QEMU_PID_FILE"
            log_low " "`cat $MY_QEMU_PID_FILE`
            PID=`cat $MY_QEMU_PID_FILE`
            /home/cisco/sunstone/display.sh $PID $OPT_NET_NAME
        fi

        #tech_support

        exit 0
    fi

    log "$PROGRAM, exiting"

    commonexit
}

get_next_ip_addresses() {

    if [ "$SUB_ADDRESS1" = "" ]; then
        SUB_ADDRESS1=$(expr \( $RANDOM % 250 \))
        if [ "$SUB_ADDRESS1" = "" ]; then
            die "Do not run this tool with sh, call it directly."
        fi

        ADDRESS[$i]="192.${SUB_ADDRESS1}"
        IP_PATTERN="${ADDRESS[$i]}"
        RESULT=$(/sbin/ifconfig|egrep "inet.*${IP_PATTERN}")
        while [ -n "${RESULT}" ]
        do
            SUB_ADDRESS1=$(expr \( $RANDOM % 250 \))

            ADDRESS[$i]="192.${SUB_ADDRESS1}"
            IP_PATTERN="${ADDRESS[$i]}"
            RESULT=$(/sbin/ifconfig|egrep "inet.*${IP_PATTERN}")
        done
    fi

    for i in $(seq 1 $OPT_DATA_NICS)
    do
        ADDRESS[$i]="192.${SUB_ADDRESS1}.${i}.1"
        log_debug "Bridge $i using ${ADDRESS[$i]}"
    done
}

get_mac_address() {
    printf '52:46:01:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

get_next_mac_addresses() {

    for i in $(seq 1 $OPT_DATA_NICS)
    do
        MAC_DATA_ETH[$i]=`printf '52:46:01:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))`
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        MAC_HOST_ETH[$i]=`printf '52:46:01:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))`
    done
}

create_taps()
{
    if [ "$OPT_ENABLE_TAPS" = "0" ]; then
        return
    fi

    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    #
    # create the tap
    #
    log "Create taps"
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        sudo_check_trace tunctl -b -u $LOGNAME -t ${TAP_DATA_ETH[$i]}
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        sudo_check_trace tunctl -b -u $LOGNAME -t ${TAP_HOST_ETH[$i]}
    done

    log "Set taps with large queue len"
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        sudo_check_trace ifconfig ${TAP_DATA_ETH[$i]} txqueuelen 10000
    done

    #
    # bring up the tap
    #
    log "Bring up taps"
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        sudo_check_trace ifconfig ${TAP_DATA_ETH[$i]} up
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        sudo_check_trace ifconfig ${TAP_HOST_ETH[$i]} up
    done

    #
    # show the tap
    #
    if [ "$OPT_DEBUG" != "" ]; then
        log "Show taps"
        for i in $(seq 1 $OPT_DATA_NICS)
        do
            trace ifconfig ${TAP_DATA_ETH[$i]}
        done

        for i in $(seq 1 $OPT_HOST_NICS)
        do
            trace ifconfig ${TAP_HOST_ETH[$i]}
        done
    fi

    #
    # create the bridge
    #
    log "Create bridges"
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        BRIDGE=${BRIDGE_DATA_ETH[$i]}

        #
        # brctl show does not exit with failure on not found, so need to grep
        #
        brctl show | grep -q "\<$BRIDGE\>"
        if [ $? -ne 0 ]; then
            sudo_check_trace brctl addbr $BRIDGE
        else
            log_low " Bridge $BRIDGE already exists"
        fi
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        BRIDGE=${BRIDGE_HOST_ETH[$i]}
        if [ "$BRIDGE" = "virbr0" ]; then
            continue
        fi

        #
        # brctl show does not exit with failure on not found, so need to grep
        #
        brctl show | grep -q "\<$BRIDGE\>"
        if [ $? -ne 0 ]; then
            sudo_check_trace brctl addbr $BRIDGE
        else
            log_low " Bridge $BRIDGE already exists"
        fi
    done

    #
    # bring up the bridge
    #
    log "Bring up bridges"

    # make sure each session has unique IP addresses
    get_next_ip_addresses

    for i in $(seq 1 $OPT_DATA_NICS)
    do
        BRIDGE=${BRIDGE_DATA_ETH[$i]}
        sudo_check_trace ifconfig $BRIDGE ${ADDRESS[$i]} up
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        BRIDGE=${BRIDGE_HOST_ETH[$i]}
        if [ "$BRIDGE" = "virbr0" ]; then
            continue
        fi

        sudo_check_trace ifconfig $BRIDGE ${ADDRESS[$i]} up
    done

    #
    # show my bridge
    #
    if [ "$OPT_DEBUG" != "" ]; then
        log "Show bridges"
        for i in $(seq 1 $OPT_DATA_NICS)
        do
            trace ifconfig ${BRIDGE_DATA_ETH[$i]}
            trace brctl show ${BRIDGE_DATA_ETH[$i]}
            trace brctl showmacs ${BRIDGE_DATA_ETH[$i]}
        done

        for i in $(seq 1 $OPT_HOST_NICS)
        do
            trace ifconfig ${BRIDGE_HOST_ETH[$i]}
            trace brctl show ${BRIDGE_HOST_ETH[$i]}
            trace brctl showmacs ${BRIDGE_HOST_ETH[$i]}
        done
    fi

    #
    # attach tap interface to bridge
    #
    log "Add taps to bridges"
    for i in $(seq 1 $OPT_DATA_NICS)
    do
        sudo_check_trace brctl addif ${BRIDGE_DATA_ETH[$i]} ${TAP_DATA_ETH[$i]}
    done

    for i in $(seq 1 $OPT_HOST_NICS)
    do
        sudo_check_trace brctl addif ${BRIDGE_HOST_ETH[$i]} ${TAP_HOST_ETH[$i]}
    done

    I_CREATED_TAPS=1
}

init_colors()
{
    DULL=0
    FG_BLACK=30
    FG_RED=31
    FG_GREEN=32
    FG_YELLOW=33
    FG_BLUE=34
    FG_MAGENTA=35
    FG_CYAN=36
    FG_WHITE=37
    FG_NULL=00
    BG_NULL=00
    ESC="["
    RESET="${ESC}${DULL};${FG_WHITE};${BG_NULL}m"
    BLACK="${ESC}${DULL};${FG_BLACK}m"
    RED="${ESC}${DULL};${FG_RED}m"
    GREEN="${ESC}${DULL};${FG_GREEN}m"
    YELLOW="${ESC}${DULL};${FG_YELLOW}m"
    BLUE="${ESC}${DULL};${FG_BLUE}m"
    MAGENTA="${ESC}${DULL};${FG_MAGENTA}m"
    CYAN="${ESC}${DULL};${FG_CYAN}m"
    WHITE="${ESC}${DULL};${FG_WHITE}m"
}

log() {
    if [ "$LOG_DIR" = "" ]; then
        echo `date`": ${LOG_PREFIX}${GREEN}$*${RESET}"
    else
        echo `date`": ${LOG_PREFIX}${GREEN}$*${RESET}" | tee -a $LOG_DIR/$PROGRAM.log
    fi

    if [ $? -ne 0 ]; then
        die "Cannot write to log file"
    fi
}

log_low() {
    if [ "$LOG_DIR" = "" ]; then
        echo `date`": ${LOG_PREFIX}$*"
    else
        echo `date`": ${LOG_PREFIX}$*" | tee -a $LOG_DIR/$PROGRAM.log
    fi

    if [ $? -ne 0 ]; then
        die "Cannot write to log file"
    fi
}

log_debug() {
    if [ "$OPT_DEBUG" = "" ]; then
        #
        # Still log to the log file if not the screen
        #
        echo `date`": ${LOG_PREFIX}$*" >> $LOG_DIR/$PROGRAM.log

        if [ $? -ne 0 ]; then
            die "Cannot write to log file"
        fi

        return
    fi

    if [ "$LOG_DIR" = "" ]; then
        echo `date`": ${LOG_PREFIX}$*"
    else
        echo `date`": ${LOG_PREFIX}$*" | tee -a $LOG_DIR/$PROGRAM.log
    fi

    if [ $? -ne 0 ]; then
        die "Cannot write to log file"
        exit 1
    fi
}

backtrace() {
    local deptn=${#FUNCNAME[@]}

    for ((i=1; i<$deptn; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        local src="${BASH_SOURCE[$((i-1))]}"
        printf '%*s' $i '' # indent
        echo "at: $func(), $src, line $line"
    done
}

trace_top_caller() {
    local func="${FUNCNAME[1]}"
    local line="${BASH_LINENO[0]}"
    local src="${BASH_SOURCE[0]}"
    echo "  called from: $func(), $src, line $line"
}

trace() {
    echo `date`": + $*" | tee -a $LOG_DIR/$PROGRAM.log
    $* 2>&1 | tee -a $LOG_DIR/$PROGRAM.log
    return ${PIPESTATUS[0]}
}

trace_quiet() {
    echo `date`": + $*" | tee -a $LOG_DIR/$PROGRAM.log

    if [ "$OPT_DEBUG" != "" ]; then
        $*
    else
        $* >/dev/null
    fi
}

err() {
    if [ "$LOG_DIR" = "" ]; then
        echo `date`": ${LOG_PREFIX}${RED}ERROR: $*${RESET}"
    else
        echo `date`": ${LOG_PREFIX}${RED}ERROR: $*${RESET}" | tee -a $LOG_DIR/$PROGRAM.log
    fi

    record_error $* &>/dev/null
}

warn() {
    if [ "$LOG_DIR" = "" ]; then
        echo `date`": ${LOG_PREFIX}${RED}WARNING: $*${RESET}"
    else
        echo `date`": ${LOG_PREFIX}${RED}WARNING: $*${RESET}" | tee -a $LOG_DIR/$PROGRAM.log
    fi

    record_error $* &>/dev/null
}

die() {
    if [ "$LOG_DIR" = "" ]; then
        echo `date`": ${LOG_PREFIX}${RED}FATAL ERROR: $*${RESET}"
    else
        echo `date`": ${LOG_PREFIX}${RED}FATAL ERROR: $*${RESET}" | tee -a $LOG_DIR/$PROGRAM.log
    fi

    backtrace

    record_error $* &>/dev/null

    exit 1
}

banner() {
    echo $RED

    COLUMNS=$(tput cols)
    export COLUMNS

    arg="$*"

    perl - "$arg" <<'EOF'
    my $arg=shift;
    my $width = $ENV{COLUMNS};

    if ($width > 80) {
        $width = 80;
    }

    if ($width == 0) {
        $width = 80;
    }

    my $len = length($arg);

    printf "#" x $width . "\n";
    printf "#";

    my $pad1 = int(($width - $len - 1) / 2);
    printf " " x $pad1;

    printf "$arg";

    my $pad2 = int(($width - $len - 1) / 2);
    if ($pad2 + $pad1 + 2 + $len > $width) {
        $pad2--;
    }

    printf " " x $pad2;

    printf "#\n";
    printf "#" x $width . "\n";
EOF
    echo $RESET
}

fix_output()
{
    in=$*

    if [ ! -f "$in" ]; then
        return
    fi

    out=$in.tmp
    cat $in | perl -pe 's/\e([^\[\]]|\[.*?[a-zA-Z]|\].*?\a)//g' | col -b > $out
    mv $out $in
}

find_random_open_port_()
{
    RANDOM_ADDRESS=

    VM_ADDRESS=`expr \( $RANDOM % $RANDOM_PORT_RANGE \) + $RANDOM_PORT_BASE`
    if [ "$VM_ADDRESS" = "" ]; then
        die "Do not run this tool with sh, call it directly."
    fi

    RESULT=`netstat -plano 2>/dev/null | grep $VM_ADDRESS; lsof -iTCP:$VM_ADDRESS; lsof -iUDP:$VM_ADDRESS`
    while [ "$RESULT" != "" ]
    do
        VM_ADDRESS=`expr \( $RANDOM % $RANDOM_PORT_RANGE \) + $RANDOM_PORT_BASE`
        RESULT=`netstat -plano 2>/dev/null | grep $VM_ADDRESS; lsof -iTCP:$VM_ADDRESS; lsof -iUDP:$VM_ADDRESS`
    done

    RANDOM_ADDRESS=$VM_ADDRESS

    #
    # Double check
    #
    netstat -plano 2>/dev/null | grep $VM_ADDRESS; lsof -iTCP:$VM_ADDRESS; lsof -iUDP:$VM_ADDRESS
}

#
# Need to filter not just currently open ports but also those we plan to
# use. This does not filter out other processes running at the same time.
#
find_random_open_port()
{
    local EXISTING_PORTS=$*
    local TRIES=0

    while true
    do
        find_random_open_port_

        local COLLISION=0
        for PORT in $*
        do
            if [ $RANDOM_ADDRESS -eq $PORT ]; then
                COLLISION=1
                break
            fi
        done

        TRIES=$(expr $TRIES + 1)

        if [ "$TRIES" -eq 60 ]; then
            die "Cannot allocate a local port. Tried $TRIES times"
        fi

        if [ $COLLISION -eq 1 ]; then
            continue
        fi

        break
    done
}

create_telnet_ports()
{
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    if [ "$TTY_HOST" = "" ]; then
        TTY_HOST="localhost"

        #
        # 0.0.0.0 listens on all local interfaces
        #
        TTY_HOST="0.0.0.0"
    fi

    if [ "$QEMU_PORT" = "" ]; then
        find_random_open_port
        QEMU_PORT=$RANDOM_ADDRESS
    fi

    if [ "$TTY1_PORT" = "" ]; then
        find_random_open_port
        TTY1_PORT=$RANDOM_ADDRESS
    fi

    if [ "$TTY2_PORT" = "" ]; then
        find_random_open_port
        TTY2_PORT=$RANDOM_ADDRESS
    fi

    if [ "$TTY3_PORT" = "" ]; then
        find_random_open_port
        TTY3_PORT=$RANDOM_ADDRESS
    fi

    if [ "$TTY4_PORT" = "" ]; then
        find_random_open_port
        TTY4_PORT=$RANDOM_ADDRESS
    fi
}

create_disk()
{
    local NAME=$1
    local SIZE=$2
    local TYPE=$3

    trace rm -f $NAME
    log "Creating disk $NAME, size $SIZE"

    if [ "$OPT_INSTALL_CREATE_QCOW2" != "" ]; then
        trace_quiet $QEMU_IMG_EXEC create -f qcow2 -o preallocation=metadata $NAME $SIZE
    else
        trace_quiet dd if=/dev/zero of=$NAME bs=1 count=0 seek=$SIZE
    fi

    if [ "$OPT_DEBUG" != "" ]; then
        ls -lash $NAME
    fi
}

#
# Extract an ISO to disk one file at a time. Slow, but does not need root.
#
extract_iso()
{
    local ISO_FILE=$1
    local OUT_DIR=$2
    local DIR=
    local ERR=

    if [ "$ISO_FILE" = "" ]; then
        die "No ISO file"
    fi

    if [ "$OUT_DIR" = "" ]; then
        die "No out dir for ISO create"
    fi

    #
    # Extract the ISO contents
    #
    local TMP=`mktemp`
    log_debug "+ isoinfo -R -l -i ${ISO_FILE}"

    isoinfo -R -l -i ${ISO_FILE} > $TMP
    if [ $? -ne 0 ]; then
        die "Failed to extract $ISO_FILE"
    fi

    if [ ! -f "$TMP" ]; then
        die "Failed to make $TMP"
    fi

    exec< $TMP

    while read LINE
    do
        if [ "$OPT_DEBUG" != "" ]; then
            echo "$LINE"
        fi

        #
        # Ignore empty lines
        #
        if [ "$LINE" = "" ]; then
            continue
        fi

        #
        # Look for directory lines
        #
        local DIR_PREFIX="Directory listing of "

        if [[ $LINE == "${DIR_PREFIX}"* ]]; then
            #
            # Remove the "Directory listing of " prefix
            #
            DIR=`echo $LINE | sed s/"${DIR_PREFIX}"//g`

            mkdir -p ${OUT_DIR}/$DIR
        else
            #
            # Ignore directories
            #
            if [[ $LINE = "d"* ]]; then
                continue
            fi

            #
            # Strip leading fields
            #
            local FILE=`echo $LINE | cut -d" " -f12`

            #
            # isoinfo to leave .. as a file sometimes
            #
            if [ "$FILE" = ".." ]; then
                continue
            fi

            #
            # Extract the file
            #
            local DIR_FILE=${DIR}${FILE}
            local OUT_DIR_FILE=${OUT_DIR}${DIR}${FILE}

            if [ "$OPT_DEBUG" != "" ]; then
                log "isoinfo -R -i ${ISO_FILE} -x ${DIR_FILE}"
            fi

            isoinfo -R -i ${ISO_FILE} -x ${DIR_FILE} > ${OUT_DIR_FILE}
            if [ $? -ne 0 ]; then
                err "Failed to extract $DIR_FILE"
                ERR=1
            fi

            if [ "$OPT_DEBUG" != "" ]; then
                /bin/ls -lart ${OUT_DIR_FILE}
            fi
        fi
    done

    /bin/rm -f $TMP

    if [ "$ERR" != "" ]; then
        die "Failed to extract all files"
    fi
}

#
# Modify an ISO for development mode.
#
mount_iso()
{
    for i in isoinfo
    do
        which $i &>/dev/null
        if [ $? -ne 0 ]; then
            install_package_help $i
            exit 0
        fi
    done

    ISO_DIR=${WORK_DIR}iso

    if [ -d $ISO_DIR ]; then
        log_debug " Remove old ISO before starting"

        trace rm -rf $ISO_DIR
        if [ -d $ISO_DIR ]; then
            die "Failed to remove $ISO_DIR"
        fi
    fi

    mkdir -p $ISO_DIR
    if [ $? -ne 0 ]; then
        die "Failed to create $ISO_DIR for mounting/modifying ISO"
    fi

    ( extract_iso $OPT_BOOT_ISO $ISO_DIR ) &
    wait $!
}

modify_chef_container()
{

    if [[ "$OPT_BOOT_ISO" != *"sunstone-mini-x.iso.chef"* ]]; then
        return
    fi


    mkdir /tftpboot/chef_temp
    tar -xf /tftpboot/ubuntu-core-14.04-core-amd64_chef.tar -C /tftpboot/chef_temp/  
    sed -ri "s/CHEF_LXC_HOST=\"[a-zA-Z0-9\_\-]+\"/CHEF_LXC_HOST=\"$OPT_NODE_NAME\"/g" /tftpboot/container_rc.local
    cp /tftpboot/container_rc.local /tftpboot/chef_temp/etc/rc.local
    current_dir=$PWD
    cd /tftpboot/chef_temp 
    tar -cf ubuntu-core-14.04-core-amd64_chef.tar *
    cd $current_dir
    mv /tftpboot/chef_temp/ubuntu-core-14.04-core-amd64_chef.tar /tftpboot/ubuntu-core-14.04-core-amd64_chef.tar
    chown -Rf cisco:cisco /tftpboot/ubuntu-core-14.04-core-amd64_chef.tar
    chmod 777 /tftpboot/ubuntu-core-14.04-core-amd64_chef.tar
    rm -r /tftpboot/chef_temp/
}

modify_xr_hostname()
{

    if [[ "$OPT_BOOT_ISO" != *"sunstone-mini-x.iso.XR"* ]]; then
        return
    fi

    host=`echo "$OPT_NODE_NAME" | sed -r 's/[\!~#\$%^&*\(\)_\+:;,?\/]+/-/g'`
    sed -ri "s/XR_LXC_HOST=\"[\$\{a-zA-Z0-9\}\_\-]+\"/XR_LXC_HOST=\"\$\{host_prefix\}$host\"/g" /tftpboot/run_xr_commands.sh

    cat /tftpboot/run_xr_commands.sh
}

display_ports()
{
boot_port=`ps -ef | grep kvm | awk '{print $53}'`
host_port=`ps -ef | grep kvm | awk '{print $59}'`

echo $boot_port
echo "\n\n"
echo $host_port

split_var=(${boot_port//:/ })
echo $split_var
split_var_port=${split_var[2]}
echo $split_var_port
split_boot_final=(${split_var_port//,/ })
echo $split_boot_final

printf "\n\n\n\n##########################################################################\n"
printf "\n\nTo view the boot process, run \"telnet localhost $split_boot_final[0]\"\n"

split_var=(${host_port//:/ })
split_var_port=${split_var[2]}
split_host_final=(${split_var_port//,/ })

printf "\nTo telnet into host_linux, run \"telnet localhost $split_host_final[0]\"\n\n\n"
printf "\n\n\n\n##########################################################################\n\n\n"

}

#
# Modify an ISO for development mode.
#
modify_iso_linux_cmdline()
{
    local NEW_ISO=$1
    local CMDLINE_APPEND="$2"
    local CMDLINE_REMOVE="$3"
    local GRUB_REMOVE="$4"

    log "Modifying ISO..."
    log_debug " old: $OPT_BOOT_ISO"
    log_debug " new: $NEW_ISO"

    for i in mkisofs
    do
        which $i &>/dev/null
        if [ $? -ne 0 ]; then
            install_package_help $i
            exit 0
        fi
    done

    mount_iso

    NEW_ISO_DIR=${WORK_DIR}iso.new

    if [ -d $NEW_ISO_DIR ]; then
        find $NEW_ISO_DIR | xargs chmod +w
        trace rm -rf $NEW_ISO_DIR
        if [ $? -ne 0 ]; then
            die "Failed to remove $NEW_ISO_DIR"
        fi
    fi

    log_debug " Clone existing ISO"

    trace cp -rp $ISO_DIR $NEW_ISO_DIR
    if [ $? -ne 0 ]; then
        die "Failed to copy $OPT_BOOT_ISO in $ISO_DIR to $NEW_ISO_DIR"
    fi

    log_debug " Modify new ISO"

    #
    # Avoid using sed in place and mv as some odd nfs issues can prevent
    # remove of files
    #
    local MENU_LST=$NEW_ISO_DIR/boot/grub/menu.lst
    local MENU_LST_NEW=$NEW_ISO_DIR/boot/grub/menu.lst.tmp

    if [ "$CMDLINE_APPEND" != "" ]; then
        log_debug " Modify linux cmdline, add '$CMDLINE_APPEND'"

        sed "s;\(platform=sunstone\);\1 $CMDLINE_APPEND ;g" \
		$MENU_LST >$MENU_LST_NEW
        if [ $? -ne 0 ]; then
	    df $NEW_ISO_DIR/boot/grub/
            die "Failed to modify grub menu list $NEW_ISO, out of space?"
        fi

	cp $MENU_LST_NEW $MENU_LST
        if [ $? -ne 0 ]; then
            die "Failed to copy new grub menu list for $NEW_ISO"
        fi
    fi

    if [ "$CMDLINE_REMOVE" != "" ]; then
        for i in $CMDLINE_REMOVE
        do
            log_debug " Modify linux cmdline, remove '$i'"

            sed  "s;$i ;;g" $MENU_LST >$MENU_LST_NEW
            if [ $? -ne 0 ]; then
    	        df $NEW_ISO_DIR/boot/grub/
                die "Failed to modify (remove entry) grub menu list $NEW_ISO, out of space?"
            fi
    
    	    cp $MENU_LST_NEW $MENU_LST
            if [ $? -ne 0 ]; then
                die "Failed to copy new grub menu list for $NEW_ISO"
            fi
        done
    fi

    if [ "$GRUB_REMOVE" != "" ]; then
        for i in $GRUB_REMOVE
        do
            log_debug " Modify grub, remove line '$i'"

            sed "/$i/d" $MENU_LST >$MENU_LST_NEW
            if [ $? -ne 0 ]; then
    	        df $NEW_ISO_DIR/boot/grub/
                die "Failed to modify (remove line) grub menu list $NEW_ISO, out of space?"
            fi
    
    	    cp $MENU_LST_NEW $MENU_LST
            if [ $? -ne 0 ]; then
                die "Failed to copy new grub menu list for $NEW_ISO"
            fi
        done
    fi

    #
    # Clean up the cmdline so we don't have gaps from add/removes
    #
    sed "s/ / /g" $MENU_LST > $MENU_LST_NEW
    if [ $? -eq 0 ]
    then
        cp $MENU_LST_NEW $MENU_LST
    fi

    if [ "$OPT_DEBUG" != "" ]; then
        cat $MENU_LST
    fi

    log_debug " Create new ISO"

    trace mkisofs -quiet -R -b boot/grub/stage2_eltorito -no-emul-boot  -boot-load-size 4 -boot-info-table -o $NEW_ISO $NEW_ISO_DIR
    if [ $? -ne 0 ]; then
        die "Failed to create new ISO $NEW_ISO"
    fi

    log_debug " Remove new ISO temp dir"

    find $NEW_ISO_DIR | xargs chmod +w
    trace rm -rf $NEW_ISO_DIR

    log "Modified ISO:"
    log_low " $NEW_ISO"
}

create_disks()
{
    if [ $OPT_ENABLE_DISK_VIRTIO -eq 1 ]; then
        QEMU_DISK_VIRTIO_ARG="if=virtio,"
    fi

    #
    # If booting off of a disk then we are good to go and do not need to make
    # any disks.
    #
    if [ "$OPT_BOOT_DISK" != "" ]; then
        if [ "$QEMU_SHOULD_START" = "" ]; then
            return
        fi

        log "Booting from $OPT_BOOT_DISK"

        if [ "$OPT_BOOT_ISO" != "" ]; then
            die "Both -iso and -disk boot specified. Please choose one."
        fi

        add_qemu_cmd "-drive file=$OPT_BOOT_DISK,${QEMU_DISK_VIRTIO_ARG}media=disk "
        return
    fi

    add_qemu_cmd "-drive file=$DISK1,${QEMU_DISK_VIRTIO_ARG}media=disk " # vda

    if [ "$OPT_ENABLE_RECREATE_DISKS" = "" ]; then
        if [ -f "$DISK1" ]; then
            #
            # If not specifying an ISO and we have an existing disk then this
            # looks like a boot of a previous install. Good to go.
            #
            if [ "$OPT_BOOT_ISO" = "" ]; then
                log "No ISO, but have existing disk. Continue booting."
                return
            fi

            if [ "$OPT_FORCE" != "" ]; then
                if [ "$QEMU_SHOULD_START" = "" ]; then
                    return
                fi

                log "Reinstalling from ISO. Disks will be destroyed."
            else
                banner "Warning, disk $DISK1 exists"

                log "Use -f to avoid this question"

                while true; do
                    read -p "Destroy existing disk image and force a reinstall [no]?" yn
                    case $yn in
                        [Yy]* ) break;;
                        * ) return;;
                    esac
                done
            fi
        fi
    fi

    #
    # If creating disks then we need an ISO to boot off of.
    #
    if [ "$OPT_BOOT_ISO" = "" ]; then
        if [ -f $DISK1 ]; then
            log "Booting from existing disk"
            return
        fi

        die "I need an ISO to boot from as I can find no boot disk, please use the -iso option to specify one."
    fi

    log "Creating disks"

    #
    # Disks
    #
    create_disk $DISK1 $DISK1_SIZE $DISK_TYPE

    #
    # Modify linux command line
    #
    if [ "$LINUX_CMD_APPEND" != "" -o \
         "$LINUX_CMD_REMOVE" != "" ]
    then
        local NEW_ISO=${WORK_DIR}`basename $OPT_BOOT_ISO`.modified

        modify_iso_linux_cmdline \
            $NEW_ISO \
            "$LINUX_CMD_APPEND" \
            "$LINUX_CMD_REMOVE" \
            "$GRUB_LINE_REMOVE"

        if [ ! -f "$NEW_ISO" ]; then
            die "Failed to create sim ISO $OPT_BOOT_ISO.modified"
        fi

        OPT_BOOT_ISO=$NEW_ISO
    fi

    #
    # CDROM
    #
    # MUST BE BELOW modify_iso_linux_cmdline AS OPT_BOOT_ISO can be changed
    #
    # NOTE grub will not boot with virtio
    #
    add_qemu_cmd "-drive file=$OPT_BOOT_ISO,media=cdrom,index=3"
}

qemu_create_scripts()
{
    SLEEP=3

    SOURCE_COMMON_SCRIPT_FUNCTIONS="
err() {
    echo \`date\`\": ${LOG_PREFIX}${RED}ERROR: \$*${RESET}\"
}

die() {
    echo \`date\`\": ${LOG_PREFIX}${RED}FATAL ERROR: \$*${RESET}\"
    exit 1
}

log() {
    echo \`date\`\": ${LOG_PREFIX}${GREEN}\$*${RESET}\"
}

trace() {
    echo \`date\`\": + \$*\"
    \$* 2>&1
    return \${PIPESTATUS[0]}
}

telnet_wait()
{
    local HOST=\$1
    local PORT=\$2

    cd $PWD
    echo \$\$ >> $MY_TERMINALS_PID_FILE
    cd $LOG_DIR

    log \"Attempting telnet on \$HOST:\$PORT\"
    while true
    do
        echo | telnet \$HOST \$PORT | grep -q \"Connected to\"
        if [ \$? -eq 0 ]; then
            log Connected to \$HOST:\$PORT
            return
        fi
        sleep 1
    done
}

wait_on_port()
{
    local HOST=\$1
    local PORT=\$2

    log \"Waiting for listener on \$HOST:\$PORT\"
    while true
    do
        #
        # netstat output would need host name resolved, so skip that.
        #
#        netstat -plano 2>/dev/null | grep -q \"\$HOST:\$PORT.*LISTEN\"
        echo | telnet \$HOST \$PORT | grep -q \"Connected to\"
        if [ \$? -eq 0 ]; then
            log Listener found on \$HOST:\$PORT
            return
        fi
        sleep 1
    done
}

cd $PWD
cd $LOG_DIR
"
    cat >$TTY1_CMD <<%%%
$SOURCE_COMMON_SCRIPT_FUNCTIONS
telnet_wait $TTY_HOST $TTY1_PORT

if [ -r qemu.pid ]; then
    echo "Root pid: " \`cat qemu.pid\` > con
fi

script -q -f $TTY1_NAME.log -c '$TTY1_TELNET_CMD $TTY_HOST $TTY1_PORT'
%%%

    cat >$TTY2_CMD <<%%%
$SOURCE_COMMON_SCRIPT_FUNCTIONS
telnet_wait $TTY_HOST $TTY2_PORT
script -q -f $TTY2_NAME.log -c '$TTY2_TELNET_CMD $TTY_HOST $TTY2_PORT'
%%%

    cat >$TTY3_CMD <<%%%
$SOURCE_COMMON_SCRIPT_FUNCTIONS
telnet_wait $TTY_HOST $TTY3_PORT
script -q -f $TTY3_NAME.log -c '$TTY3_TELNET_CMD $TTY_HOST $TTY3_PORT'
%%%

    cat >$TTY4_CMD <<%%%
$SOURCE_COMMON_SCRIPT_FUNCTIONS
telnet_wait $TTY_HOST $TTY4_PORT
script -q -f $TTY4_NAME.log -c '$TTY4_TELNET_CMD $TTY_HOST $TTY4_PORT'
%%%

    chmod +x $TTY1_CMD
    chmod +x $TTY2_CMD
    chmod +x $TTY3_CMD
    chmod +x $TTY4_CMD
}

qemu_generate_virsh()
{
    cat >$TTY0_CMD_QEMU <<%%
$*
%%
    sed -i 's/ \-/ \\\n      -/g' $TTY0_CMD_QEMU

    which virsh &>/dev/null
    if [ $? -eq 0 ]; then
        log "VIRSH XML:"
        log_low " $TTY0_CMD_VIRSH_XML"

        sudo_check_trace_to "virsh domxml-from-native qemu-argv $TTY0_CMD_QEMU" $TTY0_CMD_VIRSH_XML
    fi

    log "QEMU command line:"
    log_low " $TTY0_CMD_QEMU"
}

qemu_launch()
{
    WHICH=$1
    shift

    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    LOG=$LOG_DIR/$TTY0_NAME.log

    #
    # Generate virsh command line in case it is useful
    #
    qemu_generate_virsh $*

    #
    # Show the port info right before QEMU starts in case it is running in
    # our process context and blocks us.
    #
    qemu_show_port_info

cat >$TTY0_PRE_CMD <<%%%
#!/bin/bash

qemu_pin()
{
    local PORT=\$1
    local SAVE_IFS=\$IFS
    local CPUID=0

    for TOKEN in \`( sleep 1; echo 'info cpus'; sleep 1 ) | telnet $TTY_HOST \$PORT 2>/dev/null\`
    do
        TOKEN=\`echo \$TOKEN | tr -d '\r'\`

        echo \$TOKEN | grep -q "^thread_id.[0-9]*"
        if [ \$? -eq 0 ]; then
            local TID=\`echo \$TOKEN | sed 's/.*=//g'\`

            local CPUID_FIELD=\`expr \$CPUID + 1\`
            local PIN_TO=\`echo $OPT_CPU_LIST | cut -d , -f \$CPUID_FIELD\`

            if [ "\$PIN_TO" = "" ]; then
                err "Not enough CPUs were given to pin all threads"
                break
            fi

            local MASK=0x\$(( 1 << \$PIN_TO ))

            log "Pinning thread \$TID to cpu \$PIN_TO"
            trace taskset -p \$MASK \$TID
            if [ \$? -eq 0 ]; then
                CPUID=\`expr \$CPUID + 1\`
            else
                err "Failed to pin thread \$TID to cpu \$PIN_TO"
            fi
        fi
    done
}

$SOURCE_COMMON_SCRIPT_FUNCTIONS

log "Running QEMU..."
cd $PWD
echo "$*" | sed -e 's/ \-/ \\\\\n      -/g'
#Now start the VM
$NUMA_MEM_ALLOC $* &

#
# Hijack the QEMU monitor so we can pin CPUs
#
wait_on_port $TTY_HOST $QEMU_PORT
if [ \$? -ne 0 ]; then
    exit 1
fi

#
# More robust polling to make sure the monitor is really up. It can take a few
# seconds.
#
while true
do
    log "Connecting to the QEMU monitor..."
    ( echo; sleep 1 ) | telnet $TTY_HOST $QEMU_PORT | grep "QEMU.*monitor"
    if [ \$? -eq 0 ]; then
        break
    fi
done

if [ "$OPT_CPU_LIST" != "" ]; then
    log "Performing CPU pinning..."
    qemu_pin $QEMU_PORT
fi

log "Collecting VM PCI info..."
( echo 'info pci'; sleep 3 ) | telnet $TTY_HOST $QEMU_PORT

log "Collecting VM CPU info..."
( echo 'info cpus'; sleep 3 ) | telnet $TTY_HOST $QEMU_PORT

exit 0
%%%

    chmod +x $TTY0_PRE_CMD
    chmod +x $TTY1_CMD
    chmod +x $TTY2_CMD
    chmod +x $TTY3_CMD
    chmod +x $TTY4_CMD

    #
    # Kick off QEMU directly and do cpu pinning or whatever we need
    #
    log "Start QEMU launch..."
    $TTY0_PRE_CMD
    if [ $? -ne 0 ]; then
        die "QEMU launch failed"
    fi

    log "QEMU launched"

    I_STARTED_VM=1

    wait_for_qemu_start
    if [ ! -s $MY_QEMU_PID_FILE ]; then
        die "QEMU did not start"
    fi

    #
    # Now create a telnet wrapper to access the QEMU monitor
    #
    cat >$TTY0_CMD <<%%%
$SOURCE_COMMON_SCRIPT_FUNCTIONS
telnet_wait $TTY_HOST $QEMU_PORT
script -a -f \`basename $LOG\` -c "$TTY0_TELNET_CMD $TTY_HOST $QEMU_PORT"
%%%

    chmod +x $TTY0_CMD

    if [ "$OPT_UI_LOG" = "1" ]; then
        log "Launching background telnet sessions"

        nohup sh -c $TTY0_CMD >/dev/null &
        echo $! >> $MY_TERMINALS_PID_FILE
        nohup sh -c $TTY1_CMD > /dev/null &
        echo $! >> $MY_TERMINALS_PID_FILE
        nohup sh -c $TTY2_CMD > /dev/null &
        echo $! >> $MY_TERMINALS_PID_FILE

        if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
            nohup sh -c $TTY3_CMD > /dev/null &
            echo $! >> $MY_TERMINALS_PID_FILE
            nohup sh -c $TTY4_CMD > /dev/null &
            echo $! >> $MY_TERMINALS_PID_FILE
        fi

    elif [ "$OPT_UI_SCREEN" = "1" ]; then
        log "Launching screen sessions"

        screen -t "${WHICH}${TTY0_NAME}" sh -c "sh $TTY0_CMD"
        sleep 1
        screen -t "${WHICH}${TTY1_NAME}" sh -c "sh $TTY1_CMD"
        sleep 1
        screen -t "${WHICH}${TTY2_NAME}" sh -c "sh $TTY2_CMD"
        sleep 1

        if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
            screen -t "${WHICH}${TTY3_NAME}" sh -c "sh $TTY3_CMD"
            sleep 1
            screen -t "${WHICH}${TTY4_NAME}" sh -c "sh $TTY4_CMD"
            sleep 1
        fi

    elif [ "$OPT_UI_XTERM" = "1" ]; then
        log "Launching xterms"

        if [ "$OPT_TERM_BG_COLOR" != "" ]; then
            OPT_TERM="${OPT_TERM}-bg $OPT_TERM_BG_COLOR "
        fi

        if [ "$OPT_TERM_FG_COLOR" != "" ]; then
            OPT_TERM="${OPT_TERM}-fg $OPT_TERM_FG_COLOR "
        fi

        if [ "$OPT_TERM_FONT" != "" ]; then
            OPT_TERM="${OPT_TERM}-font $OPT_TERM_FONT "
        fi

        xterm $OPT_TERM -title "${WHICH}${TTY0_NAME}" -e "sh $TTY0_CMD" &
        echo $! >> $MY_TERMINALS_PID_FILE
        xterm $OPT_TERM -title "${WHICH}${TTY1_NAME}" -e "sh $TTY1_CMD" &
        echo $! >> $MY_TERMINALS_PID_FILE
        xterm $OPT_TERM -title "${WHICH}${TTY2_NAME}" -e "sh $TTY2_CMD" &
        echo $! >> $MY_TERMINALS_PID_FILE

        if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
            xterm $OPT_TERM -title "${WHICH}${TTY3_NAME}" -e "sh $TTY3_CMD" &
            echo $! >> $MY_TERMINALS_PID_FILE
            xterm $OPT_TERM -title "${WHICH}${TTY4_NAME}" -e "sh $TTY4_CMD" &
            echo $! >> $MY_TERMINALS_PID_FILE
        fi
        sleep 1

    elif [ "$OPT_UI_KONSOLE" = "1" ]; then
        log "Launching konsole"

        cat <<%% >${LOG_DIR}.konsole
title: ${WHICH}${TTY0_NAME};; command: /bin/sh $PWD/$TTY0_CMD
title: ${WHICH}${TTY1_NAME};; command: /bin/sh $PWD/$TTY1_CMD
title: ${WHICH}${TTY2_NAME};; command: /bin/sh $PWD/$TTY2_CMD
%%
        if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
            cat <<%% >>${LOG_DIR}.konsole
title: ${WHICH}${TTY3_NAME};; command: /bin/sh $PWD/$TTY3_CMD
title: ${WHICH}${TTY4_NAME};; command: /bin/sh $PWD/$TTY4_CMD
%%
        fi

        if [ "$OPT_TERM_PROFILE" != "" ]; then
            OPT_TERM="${OPT_TERM}-profile $OPT_TERM_PROFILE "
        fi

        konsole $OPT_TERM --title "${WHICH}" --tabs-from-file ${LOG_DIR}.konsole
        echo $! >> $MY_TERMINALS_PID_FILE

    elif [ "$OPT_UI_MRXVT" = "1" ]; then
        log "Launching mrxvt"
        log_debug " $MRXVT"

        if [ "$OPT_TERM_BG_COLOR" != "" ]; then
            OPT_TERM="${OPT_TERM}-bg $OPT_TERM_BG_COLOR "
        fi

        if [ "$OPT_TERM_FG_COLOR" != "" ]; then
            OPT_TERM="${OPT_TERM}-fg $OPT_TERM_FG_COLOR "
        fi

        if [ "$OPT_TERM_FONT" != "" ]; then
            OPT_TERM="${OPT_TERM}-font $OPT_TERM_FONT "
        fi

        if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
            #
            # Putting profile 1 last seems to allow 5 tabs...
            #
            $MRXVT -sb -sl 5000 -title ${WHICH} -ip 1,2,3,4,5  \
                $OPT_TERM \
                -profile2.tabTitle ${WHICH}${TTY1_NAME}        \
                -profile2.command "/bin/sh $PWD/$TTY1_CMD"     \
                -profile3.tabTitle ${WHICH}${TTY2_NAME}        \
                -profile3.command "/bin/sh $PWD/$TTY2_CMD"     \
                -profile4.tabTitle ${WHICH}${TTY3_NAME}        \
                -profile4.command "/bin/sh $PWD/$TTY3_CMD"     \
                -profile5.tabTitle ${WHICH}${TTY4_NAME}        \
                -profile5.command "/bin/sh $PWD/$TTY4_CMD"     \
                -profile1.tabTitle ${WHICH}${TTY0_NAME}        \
                -profile1.command "/bin/sh $PWD/$TTY0_CMD"     \
                &
        else
            $MRXVT -sb -sl 5000 -title ${WHICH} -ip 1,2,3      \
                $OPT_TERM \
                -profile1.tabTitle ${WHICH}${TTY0_NAME}        \
                -profile1.command "/bin/sh $PWD/$TTY0_CMD"     \
                -profile2.tabTitle ${WHICH}${TTY1_NAME}        \
                -profile2.command "/bin/sh $PWD/$TTY1_CMD"     \
                -profile3.tabTitle ${WHICH}${TTY2_NAME}        \
                -profile3.command "/bin/sh $PWD/$TTY2_CMD"     \
                &
        fi

        echo $! >> $MY_TERMINALS_PID_FILE

    else
        #
        # Don't run a default terminal if background run was chosen
        #
        if [ "$OPT_UI_GNOME_TERMINAL" = "0" ]; then
            if [ "$OPT_RUN_IN_BG" != "" -o "$OPT_UI_NO_TERM" -eq 1 ]; then
                return
            fi
        fi

        log "Launching gnome terminal"

        if [ "$OPT_TERM_PROFILE" != "" ]; then
            OPT_TERM="${OPT_TERM}--window-with-profile $OPT_TERM_PROFILE "
        fi

        if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
            gnome-terminal --title "${WHICH}" --geometry 80x24        \
                    $OPT_TERM \
                    --tab -t "${WHICH}${TTY0_NAME}" -e "sh $TTY0_CMD" \
                    --tab -t "${WHICH}${TTY1_NAME}" -e "sh $TTY1_CMD" \
                    --tab -t "${WHICH}${TTY2_NAME}" -e "sh $TTY2_CMD" \
                    --tab -t "${WHICH}${TTY3_NAME}" -e "sh $TTY3_CMD" \
                    --tab -t "${WHICH}${TTY4_NAME}" -e "sh $TTY4_CMD" &
        else
            gnome-terminal --title "${WHICH}" --geometry 80x24        \
                    $OPT_TERM \
                    --tab -t "${WHICH}${TTY0_NAME}" -e "sh $TTY0_CMD" \
                    --tab -t "${WHICH}${TTY1_NAME}" -e "sh $TTY1_CMD" \
                    --tab -t "${WHICH}${TTY2_NAME}" -e "sh $TTY2_CMD" &
        fi

        echo $! >> $MY_TERMINALS_PID_FILE
    fi

    #
    # Give time for X errors to appear
    #
    sleep 1
}

qemu_start()
{
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    rm -f $MY_QEMU_PID_FILE &>/dev/null

    post_read_options_apply_qemu_options

    add_qemu_cmd "-monitor telnet:$TTY_HOST:$QEMU_PORT,server,nowait"

    #
    # Enable extra serial ports for development mode.
    #
    add_qemu_cmd "-serial telnet:$TTY_HOST:$TTY1_PORT,nowait,server"
    add_qemu_cmd "-serial telnet:$TTY_HOST:$TTY2_PORT,nowait,server"

    if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
        add_qemu_cmd "-serial telnet:$TTY_HOST:$TTY3_PORT,nowait,server"
        add_qemu_cmd "-serial telnet:$TTY_HOST:$TTY4_PORT,nowait,server"
    fi

    add_qemu_cmd "-boot once=d"

#
# pidfile leads to too many problems with permissions
#
#            -pidfile $QEMU_PID_FILE \

    qemu_launch $OPT_NODE_NAME $KVM_EXEC $QEMU_CMD

    # eth0 scheme
    # new scheme looks at eth0 encoding for nested or flat information.
    # The format is 00:N/F:CALV:XR:00:00  Where N(4E) is for nested and F(46)
    # is for Flat. For example a flat sim with 1 core for calv and 2 cores for
    #  XR will be mac=00:46:01:02:00:00  For now default is 1 core each

    # eth1 scheme
    # 0[10]:00 LC
    # 02:00 RP

    #
    # Allow -clean to be able to kill off this process if it goes headless
    #
#    echo $MYPID > $MY_PID_FILE
}

qemu_show_port_info()
{
    #
    # If we did not start QEMU, then return. We may just be creating VMDKs
    # from an existing disk.
    #
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    log "Router logs:"
    log_low " $LOG_DIR"

    #
    # Be careul changing the output format here as other scripts look at
    # this. (joby james)
    #
    log "${QEMU_NAME_LONG} is on port: $QEMU_PORT"
    log "${TTY1_NAME_LONG} is on port: $TTY1_PORT"
    log "${TTY2_NAME_LONG} is on port: $TTY2_PORT"

    if [ "$OPT_ENABLE_SER_3_4" = "1" ]; then
        log "${TTY3_NAME_LONG} is on port: $TTY3_PORT"
        log "${TTY4_NAME_LONG} is on port: $TTY4_PORT"
    fi
}

#
# Add arguments that will be passed through to QEMU
#
add_qemu_cmd()
{
    log_debug "+ '$*'"

    if [ "$QEMU_CMD" != "" ]; then
        QEMU_CMD="$QEMU_CMD $*"
    else
        QEMU_CMD="$1"
    fi
}

add_pci()
{
    local PCI=$1

    #ensure that kvm is configured for passthrough
    allow_unsafe_assigned_int_fordevicepassthru

    if [ ! -d /sys/bus/pci/devices/$PCI ]; then
        if [ -d /sys/bus/pci/devices/0000:$PCI ]; then
            PCI="0000:$PCI"
        else
            die "PCI device $PCI is not found in /sys/bus/pci/devices/"
        fi
    fi

    if [ "$OPT_PCI_LIST" != "" ]; then
        OPT_PCI_LIST="$OPT_PCI_LIST $PCI"
    else
        OPT_PCI_LIST="$PCI"
    fi

    log "Adding PCI device $PCI"
}

#
# Append arguments from the linux cmdline
#
add_linux_cmd()
{
    log_debug "+ linux '$*'"

    if [ "$LINUX_CMD_APPEND" != "" ]; then
        LINUX_CMD_APPEND="$LINUX_CMD_APPEND $*"
    else
        LINUX_CMD_APPEND="$1"
    fi
}

#
# Remove arguments from the linux cmdline
#
remove_grub_line()
{
    log_debug "- grub '$*'"

    if [ "$GRUB_LINE_REMOVE" != "" ]; then
        GRUB_LINE_REMOVE="$GRUB_LINE_REMOVE $*"
    else
        GRUB_LINE_REMOVE="$1"
    fi
}

#
# Remove arguments from the linux cmdline
#
remove_linux_cmd()
{
    log_debug "- linux '$*'"

    if [ "$LINUX_CMD_REMOVE" != "" ]; then
        LINUX_CMD_REMOVE="$LINUX_CMD_REMOVE $*"
    else
        LINUX_CMD_REMOVE="$1"
    fi
}


add_qemu_cmd_10g()
{
    if [ "$OPT_ENABLE_ALL_10G_NICS" = "" ]; then
        return
    fi

    log_debug "Adding 10G interfaces"

    allow_unsafe_assigned_int_fordevicepassthru

    if [ -z "${is_centos}" ]; then
        sudo_check_trace rmmod ixgbe
    fi

    for nic in 82599
    do
        for bdf in $(lspci -vv|egrep $nic|awk '{print $1}')
        do
            add_pci "0000:$bdf"
            add_qemu_cmd -device pci-assign,romfile=,host=0000:$bdf
        done
    done
}

net_name_truncate_to_fit()
{
    local TRUNCATE=$MAX_TAP_LEN
    local SPACE_NEEDED_FOR_SUFFIX=XXXXX

    while true
    do
        FULLNAME="${OPT_NET_NAME}${OPT_NODE_NAME}${SPACE_NEEDED_FOR_SUFFIX}"
        if [ ${#FULLNAME} -le $MAX_TAP_LEN ]
        then
            break
        fi

        OPT_NET_NAME=`echo $OPT_NET_NAME | sed 's/\(.*\)./\1/g'`

        if [ "$OPT_NET_NAME" = "" ]
        then
            die "Either the node or net name is too long to fit. Linux has a limit of $MAX_TAP_LEN characters and we need space for port numbers also"
        fi
    done
}

read_early_options()
{
    shift
    while [ "$#" -ne 0 ];
    do
        local OPTION=$1

        case $1 in
        -n | -net | --net | -name | --name )
            shift
            OPT_NET_NAME=$1

            if [ "$1" = "" ]; then
                help
                die "Expecting argument for $OPTION"
            fi
            ;;

        -node | --node )
            shift
            OPT_NODE_NAME=$1

            if [ "$1" = "" ]; then
                help
                die "Expecting argument for $OPTION"
            fi
            ;;

        -w | -workdir | --workdir )
            shift
            OPT_WORK_DIR_HOME=$1
            ;;
        esac

        shift
    done

    if [ "$OPT_NODE_NAME" != "" ]; then
        net_name_truncate_to_fit

        OPT_NODE_NAME="${OPT_NET_NAME}${OPT_NODE_NAME}"
    else
        OPT_NODE_NAME=$OPT_NET_NAME
    fi

    OPT_NET_AND_NODE_NAME=$OPT_NODE_NAME
}

read_option_sanity_check()
{
    local ARG=$1
    local OPTION=$2

    if [ "$ARG" = "" ]; then
        help
        die "Expecting argument for $OPTION"
    fi

    #
    # Things that begin with a - are usually options
    #
    if [[ "$ARG" =~ ^\- ]]; then
        help
        die "Missing argument for option $OPTION, error after $LAST_OPTION?"
    fi

    LAST_OPTION=$OPTION
}

read_option_sanity_check_dash_ok()
{
    local ARG=$1
    local OPTION=$2

    if [ "$ARG" = "" ]; then
        help
        die "Expecting argument for $OPTION"
    fi

    LAST_OPTION=$OPTION
}

read_options()
{
    shift
    while [ "$#" -ne 0 ];
    do
        local OPTION=$1

        case $OPTION in
        -noroot | --noroot )
            SUDO=
            ;;

        -i | -iso | --iso )
            shift
            OPT_BOOT_ISO=$1

            read_option_sanity_check "$1" "$OPTION"
            ;;

        -32 | --32 | -iosxrv32 | --iosxrv32 )
            init_platform_defaults_iosxrv_32
            ;;

        -disk | --disk )
            shift
            OPT_BOOT_DISK=$1

            read_option_sanity_check "$1" "$OPTION"

            #
            # Some hacks to tell the script to use defaults for IOSXRv
            #
            if [[ $OPT_BOOT_DISK =~ .*iosxrv.* ]]; then
                init_platform_defaults_iosxrv_32
            fi
            ;;

        -qcow | --qcow | -qcow2 | --qcow2 )
            OPT_INSTALL_CREATE_QCOW2=1
            ;;

        -export-raw | --export-raw )
            shift
            OPT_EXPORT_RAW=$1
            OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1

            read_option_sanity_check "$1" "$OPTION"
            ;;

        -export-qcow2 | --export-qcow2 )
            shift
            OPT_INSTALL_CREATE_QCOW2=1
            OPT_EXPORT_QCOW2=$1
            OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1

            read_option_sanity_check "$1" "$OPTION"
            ;;

        -export-images | --export-images )
            shift
            OPT_EXPORT_IMAGES=1
            OVA=${OPT_BOOT_ISO%.iso}.ova
            OVA_NAME=${OVA##*/}
            OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1
            ;;

        -ovf | --ovf )
            shift
            OPT_OVF_TEMPLATE=$1

            read_option_sanity_check "$1" "$OPTION"
            ;;

        -topo | --topo | -topology | --topology )
            shift
            OPT_TOPO=$1

            read_option_sanity_check "$1" "$OPTION"

            if [ ! -f "$OPT_TOPO" ]
            then
                die "Cannot read topology file, $OPT_TOPO"
            fi
            ;;

        -host | --host )
            shift

            read_option_sanity_check "$1" "$OPTION"

            TTY_HOST=$1
            ;;

        -port | --port )
            shift

            read_option_sanity_check "$1" "$OPTION"

            local PORT=$1

            if [ "$TTY1_PORT" = "" ]; then
                TTY1_PORT=$PORT
            else
                if [ "$TTY2_PORT" = "" ]; then
                    TTY2_PORT=$PORT
                else
                    if [ "$TTY3_PORT" = "" ]; then
                        TTY3_PORT=$PORT
                    else
                        if [ "$TTY4_PORT" = "" ]; then
                            TTY4_PORT=$PORT
                        else
                            die "Too many ports specified"
                        fi
                    fi
                fi
            fi
            ;;

        -n | -net | --net | -name | --name )
            shift
            ;;

        -node | --node )
            shift
            ;;

        -w | -workdir | --workdir )
            shift
            ;;

        -passthrough | --passthrough )
            shift
            add_qemu_cmd "$1"
            ;;

        -p | -pci | --pci )
            shift

            read_option_sanity_check "$1" "$OPTION"
            add_pci "$1"
            add_qemu_cmd "-device pci-assign,host=$1"
            ;;

        -clean | --clean )
            OPT_CLEAN=1
            ;;

        -tech-support | --tech-support )
            OPT_TECH_SUPPORT=1
            ;;

        -debug | --debug )
            OPT_DEBUG=1
            ;;

        -verbose | --verbose )
            OPT_VERBOSE=1

            LOG_PREFIX="$0(pid $MYPID): "
            ;;

        -sim | --sim )
            OPT_ENABLE_SIM_MODE=1
            err "-sim option is deprecated and will be removed"
            ;;

        -dev | --dev )
            OPT_ENABLE_DEV_MODE=1
            ;;

        -cloud | --cloud )
            OPT_ENABLE_CLOUD_MODE=1
            OPT_ENABLE_VGA=1

            remove_linux_cmd "console=ttyS0"

            remove_grub_line "serial --unit=0 --speed=115200"
            remove_grub_line "terminal serial"
            ;;

        -vga | --vga )
            OPT_ENABLE_VGA=1
            ;;

        -vnc| --vnc )
            shift

            read_option_sanity_check "$1" "$OPTION"
            OPT_VNC_SERVER="$1"
            OPT_ENABLE_VGA=1
            ;;

        -cmdline-append | --cmdline-append )
            shift
            add_linux_cmd "$1"
            ;;

        -huge | --huge )
            OPT_HUGE_PAGES_CHECK=1
            ;;

        -cpu | --cpu | -cpu-pin | --cpu-pin | -cpu-list | --cpu-list )
            shift

            read_option_sanity_check "$1" "$OPTION"
            OPT_CPU_LIST="$1"
            ;;

        -numa | --numa | -numa-pin | --numa-pin )
            shift

            read_option_sanity_check "$1" "$OPTION"
            OPT_NUMA_NODE="$1"
            ;;

        -cmdline-remove | --cmdline-remove )
            shift
            remove_linux_cmd "$1"
            ;;

        -prod | --prod )
            OPT_ENABLE_DEV_MODE=0
            OPT_ENABLE_SIM_MODE=0
            ;;

        -hw-profile | --hw-profile )
            shift

            read_option_sanity_check "$1" "$OPTION"
            OPT_ENABLE_HW_PROFILE="$1"
            ;;

        -10g | --10g | -10G | --10G )
            OPT_ENABLE_ALL_10G_NICS=1
            ;;

        -disable-extra-tty | --disable-extra-tty )
            OPT_ENABLE_SER_3_4=0
            ;;

        -enable-extra-tty | --enable-extra-tty )
            OPT_ENABLE_SER_3_4=1
            ;;

        -disable-kvm | --disable-kvm )
            OPT_ENABLE_KVM=0
            ;;

        -disable-smp | --disable-smp )
            OPT_ENABLE_SMP=0
            ;;

        -disable-numa | --disable-numa )
            OPT_ENABLE_NUMA=0
            ;;

        -m | -memory | --memory )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_PLATFORM_MEMORY_MB=$1
            ;;

        -data-nics | --data-nics )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_DATA_NICS=$1
            ;;

        -host-nics | --host-nics )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_HOST_NICS=$1
            ;;

        -host-nic-type | -host-nic-type )
	    shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_HOST_NIC_TYPE=$1
            ;;

        -smp | --smp )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_PLATFORM_SMP=$1
            ;;

        -disable-runas | --disable-runas )
            OPT_ENABLE_RUNAS=0
            ;;

        -disable-network | --disable-network )
            OPT_ENABLE_NETWORK=0
            ;;

        -disable-disk-virtio | --disable-disk-virtio )
            OPT_ENABLE_DISK_VIRTIO=0
            ;;

        -disable-taps | --disable-taps )
            OPT_ENABLE_TAPS=0
            ;;

        -no-reboot | --no-reboot )
            OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1
            ;;

        -disable-boot | --disable-boot )
            OPT_DISABLE_BOOT=1
            ;;

        -bg | --bg )
            OPT_RUN_IN_BG=1
            ;;

        -wait | --wait )
            # deprecated
            ;;

        -f | -force | --force )
            OPT_FORCE=1
            ;;

        -r | -recreate | --recreate )
            OPT_ENABLE_RECREATE_DISKS=1
            ;;

        -term-bg | --term-bg )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_TERM_BG_COLOR=$1
            ;;

        -term-fg | --term-fg )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_TERM_FG_COLOR=$1
            ;;

        -term-font | --term-font )
            shift

            read_option_sanity_check_dash_ok "$1" "$OPTION"

            OPT_TERM_FONT=$1
            ;;

        -term-profile | --term-profile )
            shift

            read_option_sanity_check "$1" "$OPTION"

            OPT_TERM_PROFILE=$1
            ;;

        -term-opt | --term-opt )
            shift

            read_option_sanity_check_dash_ok "$1" "$OPTION"

            OPT_TERM="$OPT_TERM $1 "
            ;;

        -gnome | --gnome )
            OPT_UI_GNOME_TERMINAL=1
            ;;

        -xterm | --xterm )
            OPT_UI_XTERM=1
            ;;

        -konsole | --konsole )
            OPT_UI_KONSOLE=1
            ;;

        -mrxvt | --mrxvt )
            OPT_UI_MRXVT=1
            ;;

        -screen | --screen )
            OPT_UI_SCREEN=1
            ;;

        -noterm | --noterm )
            OPT_UI_NO_TERM=1
            ;;

        -log | --log )
            OPT_UI_LOG=1
            ;;

        -h | -help | --help )
            help
            exit 0
            ;;

        -v | -version | --version )
            echo $VERSION
            exit 0
            ;;

        *)
            help
            die "Unknown option $*"
            ;;
        esac

        shift
    done
}

check_overwrite_ok()
{
    local FILE=$1

    if [ -f "$FILE" ]; then
        if [ "$OPT_FORCE" = "" ]; then
            log "$FILE exists. To continue will destroy it."
            read -p "Overwrite $FILE [no]?" yn
            case $yn in
                [Yy]* ) break;;
                * ) exit 1;;
            esac
            rm -f $FILE
        fi
    fi
}

post_read_options_check_sanity()
{
    #
    # Booting from ISO?
    #
    if [ "$OPT_BOOT_ISO" != "" ]; then
        if [ ! -f "$OPT_BOOT_ISO" ]; then
            die "ISO name: $OPT_BOOT_ISO not found"
        fi
    fi

    #
    # Exporting a raw disk? Need an ISO.
    #
    if [ "$OPT_EXPORT_RAW" != "" ]; then
        if [ ! -f $DISK1 ]; then
            die "You need to specify an ISO or boot disk to boot from for exporting RAW disks as $DISK1 does not exist"
        fi

        check_overwrite_ok $OPT_EXPORT_RAW

        #
        # If baking is on we want to exit on reboot
        #
        OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1
    fi

    #
    # Exporting a QCOW? Need an ISO.
    #
    if [ "$OPT_EXPORT_QCOW2" != "" ]; then
        if [ ! -f $DISK1 ]; then
            die "You need to specify an ISO or boot disk to boot from for exporting QCOW2 disks as $DISK1 does not exist"
        fi

        check_overwrite_ok $OPT_EXPORT_QCOW2

        #
        # If baking is on we want to exit on reboot
        #
        OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1
    fi

    #
    # Exporting a OVA? Need an ISO or an existing disk
    #
    if [ "$OPT_EXPORT_IMAGES" != "" ]; then
        if [ ! -f $DISK1 ]; then
            die "You need to specify an OVA or boot disk to boot from for creating VMDKs as $DISK1 does not exist"
        fi

        if [ "$OPT_BOOT_ISO" = "" ]; then
            die "I need an ISO for OVA generation as I read the XR versioning information from it."
        fi

        check_overwrite_ok $OPT_EXPORT_IMAGES

        #
        # If baking is on we want to exit on reboot
        #
        OPT_ENABLE_EXIT_ON_QEMU_REBOOT=1

        #
        # If we have no OVF we will use a template, but it is not advised.
        #
        if [ "$OPT_OVF_TEMPLATE" = "" ]; then
            banner "Warning, no OVF has been specified."
            banner "I will use a default OVF template. Check manually it looks ok."
        else
            if [ ! -f "$OPT_OVF_TEMPLATE" ]; then
                die "OFV template $OPT_OVF_TEMPLATE not found"
            fi
        fi
    fi

    #
    # Booting from a disk?
    #
    if [ "$OPT_BOOT_DISK" != "" ]; then
        if [ ! -f "$OPT_BOOT_DISK" ]; then
            die "Disk $OPT_BOOT_DISK not found."
        fi
    fi

    #
    # Check nic type
    #
    case "$OPT_HOST_NIC_TYPE" in 
      e1000)
        NIC_HOST_INTERFACE=$OPT_HOST_NIC_TYPE
      ;;
    
      *virtio*)
        NIC_HOST_INTERFACE=virtio-net-pci
      ;;

      *)
        if [[ $OPT_HOST_NIC_TYPE != "" ]]; then
            die "bad NIC type $OPT_HOST_NIC_TYPE"
        fi 
      ;;
    esac

    #
    # Check hw profile type
    #
    if [[ $OPT_ENABLE_HW_PROFILE != "" ]]; then
        case "$OPT_ENABLE_HW_PROFILE" in 
        vrr)
            init_platform_hw_profile_vrr
        ;;
        
        *)
            #
            # If the profile does not exist on disk either, warn the user.
            # We still pass the name through to grub though.
            #
            if [ ! -f $OPT_ENABLE_HW_PROFILE ]; then
                warn "Unknown hw profile: $OPT_ENABLE_HW_PROFILE"
                warn "Supported profiles:"
                warn "  vrr (Virtual Route Reflector mode)"
            fi
        ;;
        esac

        if [ -f $OPT_ENABLE_HW_PROFILE ]; then
            log "Sourcing hw profile template: $OPT_ENABLE_HW_PROFILE"
            . $OPT_ENABLE_HW_PROFILE
        fi
    fi
}

#
# Wait for the exit of the QEMU process. Or if not enabled, fall through
# to the code below for a manual wait.
#
wait_for_qemu_exit()
{
    local WAIT=1

    if [ "$OPT_RUN_IN_BG" != "" ]; then
        return
    fi

    if [ "$OPT_UI_NO_TERM" -eq 1 ]; then
        return
    fi

    if [ -s $MY_QEMU_PID_FILE ]; then
        cat $MY_QEMU_PID_FILE &>/dev/null
        if [ $? -ne 0 ]; then
            $SUDO cat $MY_QEMU_PID_FILE &>/dev/null
            if [ $? -ne 0 ]; then
                err "Could not read qemu pid file, $QEMU_PID_FILE."
                err "Cannot exit on QEMU exit."
                WAIT=0
            fi
        fi
    else
        err "No qemu pid file, $QEMU_PID_FILE."
        err "Cannot exit on QEMU exit."
        WAIT=0
    fi

    if [ $WAIT -eq 0 ]; then
        log "Hit ^C to quit"

        #
        # Background sleep so we can kill the main process
        #
        sleep 300000000 &
        local PID=$!
#        echo $PID >> $MY_PID_FILE
        wait $PID
    else
        log "Waiting for QEMU to exit. See logs in:"
        log_low " $LOG_DIR"

        while true
        do
            PID=`cat $MY_QEMU_PID_FILE &>/dev/null`
            if [ "$PID" != "" ]; then
                ps $PID &>/dev/null
                if [ $? -ne 0 ]; then
                    log "QEMU exited"
                    I_STARTED_VM=
                    return
                fi
            fi

            PID=`$SUDO cat $MY_QEMU_PID_FILE 2>/dev/null`
            if [ "$PID" != "" ]; then
                ps $PID &>/dev/null
                if [ $? -ne 0 ]; then
                    log "QEMU exited"
                    I_STARTED_VM=
                    return
                fi
            fi

            sleep 1
        done
    fi
}

find_qemu_pid()
{
    if [ -s $MY_QEMU_PID_FILE ]; then
        return
    fi

    local TRIES=0

    #
    # QEMU creates the pid file as root with the -pidfile option, so alas we
    # resort to this hackery to try and find the pid so we can kill it as non
    # root. We give the -runas option to QEMU precisely for this reason.
    #
    log "Find QEMU process..."

    while true
    do
        local gotone=
        local PIDS=

        if [ "$OPT_ENABLE_TAPS" = "1" ]; then
            #
            # More reliable to look for tap names
            #
            for i in $(seq 1 1)
            do
                if [ "${TAP_DATA_ETH[$i]}" = "" ]; then
                    local PID=`ps awwwwx | grep $OPT_NODE_NAME | grep -v grep | grep -v "script \-f" | awk '{print $1}'`
                    PIDS="$PIDS $PID"
                else
                    local PID=`ps awwwwx | grep ${TAP_DATA_ETH[$i]} | grep $OPT_NODE_NAME | grep -v grep | grep -v "script \-f" | awk '{print $1}'`
                    PIDS="$PIDS $PID"
                fi
            done
        else
            if [ "$TTY1_PORT" != "" ]; then
                PIDS=`ps awwwwx | grep $TTY1_PORT | grep $TTY2_PORT | grep $OPT_NODE_NAME | grep -v grep | grep -v "script \-f" | awk '{print $1}'`
            fi
        fi

        for i in $PIDS
        do
            ps $i &>/dev/null
            if [ $? -eq 0 ]; then
                if [ "$OPT_DEBUG" != "" ]; then
                    ps $i | grep -v COMMAND
                fi
                printf "$i " >> $MY_QEMU_PID_FILE
                gotone=1
            fi
        done

        if [ "$gotone" != "" ]; then
            log_debug "QEMU PIDs:"
            log_debug " "`cat $MY_QEMU_PID_FILE`
            break
        fi

        sleep 1

        #
        # If we have started QEMU then keep on waiting, else bail out as we
        # could be just doing a cleanup at start time.
        #
        if [ "$I_STARTED_VM" = "" ]; then
            return
        fi

        TRIES=$(expr $TRIES + 1)

        if [ "$TRIES" -eq 60 ]; then
            log "QEMU is not starting (1 min)."
        fi

        if [ "$TRIES" -eq 120 ]; then
            log "QEMU is still not starting (2 mins)."
        fi

        if [ "$TRIES" -eq 240 ]; then
            die "QEMU did not start (4 mins)."
        fi
    done
}

find_qemu_pid_one_shot()
{
    #
    # QEMU creates the pid file as root with the -pidfile option, so alas we
    # resort to this hackery to try and find the pid so we can kill it as non
    # root. We give the -runas option to QEMU precisely for this reason.
    #
    log "Find and stop existing processes for node \"$OPT_NODE_NAME\""

    local gotone=
    local PIDS=

    if [ "$OPT_ENABLE_TAPS" = "1" ]; then
        #
        # More reliable to look for tap names
        #
        for i in $(seq 1 1)
        do
            if [ "${TAP_DATA_ETH[$i]}" = "" ]; then
                local PID=`ps awwwwx | grep $OPT_NODE_NAME | grep -v grep | grep -v "script \-f" | awk '{print $1}'`
                PIDS="$PIDS $PID"
            else
                local PID=`ps awwwwx | grep ${TAP_DATA_ETH[$i]} | grep $OPT_NODE_NAME | grep -v grep | grep -v "script \-f" | awk '{print $1}'`
                PIDS="$PIDS $PID"
            fi
        done
    else
        if [ "$TTY1_PORT" != "" ]; then
            PIDS=`ps awwwwx | grep $TTY1_PORT | grep $TTY2_PORT | grep $OPT_NODE_NAME | grep -v grep | grep -v "script \-f" | awk '{print $1}'`
        fi
    fi

    for i in $PIDS
    do
        ps $i &>/dev/null
        if [ $? -eq 0 ]; then
            if [ "$OPT_DEBUG" != "" ]; then
                ps $i | grep -v COMMAND
            fi
            printf "$i " >> $MY_QEMU_PID_FILE
            gotone=1
        fi
    done

    if [ "$gotone" != "" ]; then
        log " Existing QEMU PIDs:"
        log_low "  "`cat $MY_QEMU_PID_FILE`
    fi
}

wait_for_qemu_start()
{
    #
    # If we did not start QEMU, then return. We may just be creating VMDKs
    # from an existing disk.
    #
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    find_qemu_pid

    if [ -s $MY_QEMU_PID_FILE ]; then
        I_STARTED_VM=1

        log "QEMU started, pid file:"
        log_low " $MY_QEMU_PID_FILE"
        log_low " "`cat $MY_QEMU_PID_FILE`
    fi
}

qemu_wait()
{
    #
    # If we did not start QEMU, then return. We may just be creating VMDKs
    # from an existing disk.
    #
    if [ "$QEMU_SHOULD_START" = "" ]; then
        return
    fi

    wait_for_qemu_exit
}

create_raw()
{
    if [ "$OPT_EXPORT_RAW" = "" ]; then
        return
    fi

    log "Exporting $OPT_EXPORT_RAW"
    $QEMU_IMG_EXEC info $DISK1

    trace $QEMU_IMG_EXEC convert $DISK1 -O raw $OPT_EXPORT_RAW
    if [ $? -ne 0 ]; then
        die "Converting raw disk to RAW format failed"
    fi

    log " $OPT_EXPORT_RAW created"
    $QEMU_IMG_EXEC info $OPT_EXPORT_RAW
}

create_qcow2()
{
    if [ "$OPT_EXPORT_QCOW2" = "" ]; then
        return
    fi

    log "Exporting $OPT_EXPORT_QCOW2"
    $QEMU_IMG_EXEC info $DISK1

    trace $QEMU_IMG_EXEC convert $DISK1 -O qcow2 $OPT_EXPORT_QCOW2
    if [ $? -ne 0 ]; then
        die "Converting raw disk to QCOW2 format failed"
    fi

    log " $OPT_EXPORT_QCOW2 created"
    $QEMU_IMG_EXEC info $OPT_EXPORT_QCOW2
}

# Create OVA and VMDK images
create_images()
{
    if [ "$OPT_EXPORT_IMAGES" = "" ]; then
        return
    fi

    log "Creating OVA and VMDK"
    
    which cot &>/dev/null
    if [ $? -ne 0 ]; then
        install_package_help cot
        exit 0
    fi

    which vmdktool &>/dev/null
    if [ $? -ne 0 ]; then
        install_package_help vmdktool
        exit 0
    fi

    local OVF_TEMPLATE=${WORK_DIR}template.ovf
    local OUT_OVF=${WORK_DIR}${PLATFORM_NAME}-template.ovf
    local OUT_OVA=$OVA_NAME

    #
    # Warn if we are using a potentially stale OVF file.
    #
    if [ "$OPT_OVF_TEMPLATE" = "" ]; then
        OVF_TEMPLATE=${WORK_DIR}template.ovf

        cat >$OVF_TEMPLATE <<%%
<?xml version="1.0" encoding="UTF-8"?>
<!-- XML comments in this template are stripped out at build time -->
<!-- Copyright (c) 2013-2014 by Cisco Systems, Inc. -->
<!-- All rights reserved. -->
<Envelope xmlns="http://schemas.dmtf.org/ovf/envelope/1"
          xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common"
          xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"
          xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData"
          xmlns:vmw="http://www.vmware.com/schema/ovf"
          xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <References>
    <!-- Reference to ${PLATFORM_NAME_WITH_SPACES} disk image will be added at build time -->
  </References>
  <DiskSection>
    <Info>Information about virtual disks</Info>
    <!-- Disk will be added at build time -->
  </DiskSection>
  <NetworkSection>
    <Info>List of logical networks that NICs can be assigned to</Info>
    <!-- Note that VMware's "ovftool" doesn't work with network names
    containing / characters, so we use _ instead -->
    <Network ovf:name="MgmtEth0_0_CPU0_0">
      <Description>Management network</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_0">
      <Description>Data network 1</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_1">
      <Description>Data network 2</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_2">
      <Description>Data network 3</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_3">
      <Description>Data network 4</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_4">
      <Description>Data network 5</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_5">
      <Description>Data network 6</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_6">
      <Description>Data network 7</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_7">
      <Description>Data network 8</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_8">
      <Description>Data network 9</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_9">
      <Description>Data network 10</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_10">
      <Description>Data network 11</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_11">
      <Description>Data network 12</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_12">
      <Description>Data network 13</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_13">
      <Description>Data network 14</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_14">
      <Description>Data network 15</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_15">
      <Description>Data network 16</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_16">
      <Description>Data network 17</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_17">
      <Description>Data network 18</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_18">
      <Description>Data network 19</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_19">
      <Description>Data network 20</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_20">
      <Description>Data network 21</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_21">
      <Description>Data network 22</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_22">
      <Description>Data network 23</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_23">
      <Description>Data network 24</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_24">
      <Description>Data network 25</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_25">
      <Description>Data network 26</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_26">
      <Description>Data network 27</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_27">
      <Description>Data network 28</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_28">
      <Description>Data network 29</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_29">
      <Description>Data network 30</Description>
    </Network>
    <Network ovf:name="GigabitEthernet0_0_0_30">
      <Description>Data network 31</Description>
    </Network>
  </NetworkSection>
  <DeploymentOptionSection>
    <Info>Configuration Profiles</Info>
    <Configuration ovf:default="true" ovf:id="1CPU-3GB-2NIC">
      <Label>Small</Label>
      <Description>Minimal hardware profile - 4 vCPU, 16 GB RAM, 2 NICs</Description>
    </Configuration>
    <Configuration ovf:id="4CPU-16GB-8NIC">
      <Label>Medium (ESXi 5.1+)</Label>
      <Description>Medium hardware profile - 4 vCPUs, 16 GB RAM, 8 NICs
(DO NOT USE WITH ESXi 5.0 - ESXi 5.1 or later is required)</Description>
    </Configuration>
    <Configuration ovf:id="4CPU-16GB-10NIC">
      <Label>Large (ESXi 5.1+)</Label>
      <Description>Large hardware profile for ESXi - 4 vCPUs, 16 GB RAM, 10 NICs
(DO NOT USE WITH ESXi 5.0 - ESXi 5.1 or later is required)</Description>
    </Configuration>
    <Configuration ovf:id="16CPU-16GB-16NIC">
      <Label>Large (non-ESXi)</Label>
      <Description>Large hardware profile for other hypervisors - 16 vCPUs, 16 GB RAM, 16 NICs.
(Note: ESXi only permits 10 NICs in a VM so this profile is unsupported on ESXi.)</Description>
    </Configuration>
    <Configuration ovf:id="8CPU-16GB-10NIC">
      <Label>Huge (ESXi 5.1+)</Label>
      <Description>Maximal hardware profile for ESXi - 8 vCPUs, 16 GB RAM, 10 NICs
(DO NOT USE WITH ESXi 5.0 - ESXi 5.1 or later is required)</Description>
    </Configuration>
    <Configuration ovf:id="8CPU-16GB-32NIC">
      <Label>Huge (non-ESXi)</Label>
      <Description>Maximal hardware profile for other hypervisors - 8 vCPUs, 16 GB RAM, 32 NICs.
(Note: ${PLATFORM_NAME_WITH_SPACES} supports up to 128 NICs but most hypervisors do not.)</Description>
    </Configuration>
  </DeploymentOptionSection>
  <VirtualSystem ovf:id="com.cisco.${PLATFORM_name}">
    <Info>${PLATFORM_NAME_WITH_SPACES} virtual machine</Info>
    <Name>${PLATFORM_NAME_WITH_SPACES}</Name>
    <OperatingSystemSection ovf:id="1" vmw:osType="otherGuest">
      <Info>Description of the guest operating system</Info>
      <Description>${PLATFORM_NAME_WITH_SPACES}</Description>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Info>Definition of virtual hardware items</Info>
      <System>
        <vssd:ElementName>Virtual System Type</vssd:ElementName>
        <vssd:InstanceID>0</vssd:InstanceID>
        <!-- TODO - the below needs to be updated for Xen, etc. -->
        <vssd:VirtualSystemType>vmx-08 vmx-09 Cisco:Internal:VMCloud-01</vssd:VirtualSystemType>
      </System>
      <!-- Default CPU allocation -->
      <Item>
        <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
        <rasd:Description>Virtual CPU</rasd:Description>
        <rasd:ElementName>1 virtual CPU</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
      </Item>
      <!-- CPU allocation overridden by different configurations -->
      <Item ovf:configuration="4CPU-16GB-8NIC">
        <rasd:ElementName>2 virtual CPUs</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>2</rasd:VirtualQuantity>
      </Item>
      <Item ovf:configuration="4CPU-16GB-10NIC 16CPU-16GB-16NIC">
        <rasd:ElementName>4 virtual CPUs</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>4</rasd:VirtualQuantity>
      </Item>
      <Item ovf:configuration="8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:ElementName>8 virtual CPUs</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>8</rasd:VirtualQuantity>
      </Item>
      <!-- Default memory allocation -->
      <Item>
        <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
        <rasd:Description>RAM</rasd:Description>
        <rasd:ElementName>16 GB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>16384</rasd:VirtualQuantity>
      </Item>
      <!-- Memory allocation overridden by different configurations -->
      <Item ovf:configuration="4CPU-16GB-8NIC">
        <rasd:ElementName>16 GB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>16384</rasd:VirtualQuantity>
      </Item>
      <Item ovf:configuration="4CPU-16GB-10NIC 16CPU-16GB-16NIC">
        <rasd:ElementName>16 GB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>16384</rasd:VirtualQuantity>
      </Item>
      <Item ovf:configuration="8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:ElementName>16 GB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>16384</rasd:VirtualQuantity>
      </Item>
      <!-- IDE controllers -->
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Description>IDE Controller 0</rasd:Description>
        <rasd:ElementName>VirtualIDEController 0</rasd:ElementName>
        <rasd:InstanceID>3</rasd:InstanceID>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:Address>1</rasd:Address>
        <rasd:Description>IDE Controller 1</rasd:Description>
        <rasd:ElementName>VirtualIDEController 1</rasd:ElementName>
        <rasd:InstanceID>4</rasd:InstanceID>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <!-- Empty CD-ROM drive -->
      <Item ovf:required="false">
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:Description>CD-ROM drive for CVAC bootstrap configuration</rasd:Description>
        <rasd:ElementName>CD-ROM drive at IDE 1:0</rasd:ElementName>
        <rasd:InstanceID>5</rasd:InstanceID>
        <rasd:Parent>4</rasd:Parent>
        <rasd:ResourceType>15</rasd:ResourceType>
      </Item>
      <!-- Serial ports -->
      <Item ovf:required="false">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Description>Console Port</rasd:Description>
        <rasd:ElementName>Serial 1</rasd:ElementName>
        <rasd:InstanceID>8</rasd:InstanceID>
        <rasd:ResourceType>21</rasd:ResourceType>
      </Item>
      <Item ovf:required="false">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Description>Auxiliary Port</rasd:Description>
        <rasd:ElementName>Serial 2</rasd:ElementName>
        <rasd:InstanceID>9</rasd:InstanceID>
        <rasd:ResourceType>21</rasd:ResourceType>
      </Item>
      <!-- NICs belonging to all profiles -->
      <Item>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>MgmtEth0_0_CPU0_0</rasd:Connection>
        <rasd:Description>NIC representing MgmtEth0/0/CPU0/0</rasd:Description>
        <rasd:ElementName>MgmtEth0/0/CPU0/0</rasd:ElementName>
        <rasd:InstanceID>10</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_0</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/0</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/0</rasd:ElementName>
        <rasd:InstanceID>11</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <!-- NICs belonging to the "medium" profile and larger -->
      <Item ovf:configuration="4CPU-16GB-8NIC 4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_1</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/1</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/1</rasd:ElementName>
        <rasd:InstanceID>12</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="4CPU-16GB-8NIC 4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_2</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/2</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/2</rasd:ElementName>
        <rasd:InstanceID>13</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="4CPU-16GB-8NIC 4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_3</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/3</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/3</rasd:ElementName>
        <rasd:InstanceID>14</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="4CPU-16GB-8NIC 4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_4</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/4</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/4</rasd:ElementName>
        <rasd:InstanceID>15</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="4CPU-16GB-8NIC 4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_5</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/5</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/5</rasd:ElementName>
        <rasd:InstanceID>16</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="4CPU-16GB-8NIC 4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_6</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/6</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/6</rasd:ElementName>
        <rasd:InstanceID>17</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <!-- NICs belonging to the "large" profile and larger -->
      <Item ovf:configuration="4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_7</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/7</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/7</rasd:ElementName>
        <rasd:InstanceID>18</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="4CPU-16GB-10NIC 16CPU-16GB-16NIC 8CPU-16GB-10NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_8</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/8</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/8</rasd:ElementName>
        <rasd:InstanceID>19</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="16CPU-16GB-16NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_9</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/9</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/9</rasd:ElementName>
        <rasd:InstanceID>20</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="16CPU-16GB-16NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_10</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/10</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/10</rasd:ElementName>
        <rasd:InstanceID>21</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="16CPU-16GB-16NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_11</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/11</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/11</rasd:ElementName>
        <rasd:InstanceID>22</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="16CPU-16GB-16NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_12</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/12</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/12</rasd:ElementName>
        <rasd:InstanceID>23</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="16CPU-16GB-16NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_13</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/13</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/13</rasd:ElementName>
        <rasd:InstanceID>24</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="16CPU-16GB-16NIC 8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_14</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/14</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/14</rasd:ElementName>
        <rasd:InstanceID>25</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <!-- NICs belonging to the "maximal" profile -->
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_15</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/15</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/15</rasd:ElementName>
        <rasd:InstanceID>26</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_16</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/16</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/16</rasd:ElementName>
        <rasd:InstanceID>27</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_17</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/17</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/17</rasd:ElementName>
        <rasd:InstanceID>28</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_18</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/18</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/18</rasd:ElementName>
        <rasd:InstanceID>29</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_19</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/19</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/19</rasd:ElementName>
        <rasd:InstanceID>30</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_20</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/20</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/20</rasd:ElementName>
        <rasd:InstanceID>31</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_21</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/21</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/21</rasd:ElementName>
        <rasd:InstanceID>32</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_22</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/22</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/22</rasd:ElementName>
        <rasd:InstanceID>33</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_23</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/23</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/23</rasd:ElementName>
        <rasd:InstanceID>34</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_24</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/24</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/24</rasd:ElementName>
        <rasd:InstanceID>35</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_25</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/25</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/25</rasd:ElementName>
        <rasd:InstanceID>36</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_26</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/26</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/26</rasd:ElementName>
        <rasd:InstanceID>37</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_27</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/27</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/27</rasd:ElementName>
        <rasd:InstanceID>38</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_28</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/28</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/28</rasd:ElementName>
        <rasd:InstanceID>39</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_29</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/29</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/29</rasd:ElementName>
        <rasd:InstanceID>40</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
      <Item ovf:configuration="8CPU-16GB-32NIC">
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>GigabitEthernet0_0_0_30</rasd:Connection>
        <rasd:Description>NIC representing GigabitEthernet0/0/0/30</rasd:Description>
        <rasd:ElementName>GigabitEthernet0/0/0/30</rasd:ElementName>
        <rasd:InstanceID>41</rasd:InstanceID>
        <rasd:ResourceSubType>virtio E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
    </VirtualHardwareSection>
    <ProductSection ovf:required="false" ovf:class="com.cisco.${PLATFORM_name}">
      <Info>Information about the installed software</Info>
      <Product>${PLATFORM_NAME_WITH_SPACES}</Product>
      <Vendor>Cisco Systems, Inc.</Vendor>
      <Version>DEV</Version>
      <FullVersion>DEVELOPMENT IMAGE</FullVersion>
      <ProductUrl>http://www.cisco.com/go/${PLATFORM_NAME}</ProductUrl>
      <VendorUrl>http://www.cisco.com</VendorUrl>
    </ProductSection>
  </VirtualSystem>
</Envelope>
%%
        banner "Warning, check ./${WORK_DIR}${PLATFORM_NAME}-template.ovf to verify validity"
    else
        OVF_TEMPLATE=$OPT_OVF_TEMPLATE
    fi

    mount_iso

    local VERSION_FILE=${WORK_DIR}/iso/iso_info.txt
    if [ ! -s "$VERSION_FILE" ]; then
        die "$VERSION_FILE not found in iso. Needed for creating OVA."
    fi

    local version_string=`cat $VERSION_FILE | awk '{print $4}'`

    log_debug "XR version $version_string"

    log "Create OVF"

    # Customize the OVF template with the proper version number
    COT_CMD=$WORK_DIR/cot..cmd
    cat >$COT_CMD <<%%
    cot -f edit-product \\
        $OVF_TEMPLATE \\
        -o $OUT_OVF \\
        -v '$version_string' \\
        -V 'Cisco IOS XR Software for the ${PLATFORM_NAME_WITH_SPACES}, Version $version_string'
%%
    chmod +x $COT_CMD
    if [ $? -ne 0 ]; then
        die "Make script runnable failed for $COT_CMD"
    fi

    cat $COT_CMD
    if [ $? -ne 0 ]; then
        die "Did create of $COT_CMD succeed"
    fi

    $COT_CMD
    if [ $? -ne 0 ]; then
        die "COT create of $OUT_OVF failed"
    fi

    log "Add disk to OVF"

    # Use the customized template to create OVAs.
    # We add the raw images rather than the vmdks because COT will
    # convert the raw images to stream-optimized VMDK as it embeds them.
    COT_CMD=$WORK_DIR/cot.add.disk.cmd
    cat >$COT_CMD <<%%
    cot -f add-disk \\
        $DISK1 \\
        $OUT_OVF \\
        --output $OUT_OVA \\
        --type harddisk --controller ide --address 0:0 \\
        --name 'Hard Disk at IDE 0:0' \\
        --description 'Primary disk drive'
%%
    chmod +x $COT_CMD
    if [ $? -ne 0 ]; then
        die "Make script runnable failed for $COT_CMD"
    fi

    cat $COT_CMD
    if [ $? -ne 0 ]; then
        die "Did create of $COT_CMD succeed"
    fi

    $COT_CMD
    if [ $? -ne 0 ]; then
        die "COT create of $OUT_OVA failed"
    fi

    log "Created $OUT_OVA"

    #Extract VMDK
    local VMDK_NAME=${OVA_NAME%.ova}.vmdk
    tar xfv ./$OVA_NAME

    #Clean up
    cp ./disk1.vmdk ./$VMDK_NAME
    rm ./disk1.*
    rm ./*.mf
    rm ./*.ovf
    
    log "Created $VMDK_NAME"
    
    $QEMU_IMG_EXEC info $VMDK_NAME
}

huge_pages_mount()
{
    mount | grep -q hugetlbfs
    if [ $? -eq 1 ]; then
        local hugepage_mnt_point="/mnt/huge"
        sudo_check mkdir -p $hugepage_mnt_point
        if [ $? -ne 0 ]; then
            die "Could not create huge pages mount point $hugepage_mnt_point"
        fi

        sudo_check_trace mount -t hugetlbfs nodev $hugepage_mnt_point
        if [ $? -ne 0 ]; then
            die "Could not mount huge pages"
        fi
    fi

    local hugepage_mnt_point=`mount | grep hugetlbfs | tail -1 | awk '{print \$3}'`
    if [ "$hugepage_mnt_point" = "" ]; then
        die "Could not find huge pages mount point"
    fi

    log "Hugepages mount: $hugepage_mnt_point"

    add_qemu_cmd "-mem-prealloc -mem-path $hugepage_mnt_point"
}

huge_pages_alloc()
{
    if [ $HUGE_PAGE_NEEDED -ge $HUGE_PAGE_TOTAL ]; then
        sudo_check_trace sysctl vm.nr_hugepages=$HUGE_PAGE_NEEDED
        if [ $? -ne 0 ]; then
            die "Failed to allocate needed huge pages"
        fi
    fi
}

huge_pages_get_size()
{
    HUGE_PAGE_SIZE_MB=`cat /proc/meminfo | grep Hugepagesize | awk '{ print $2 }'`
    if [ "$HUGE_PAGE_SIZE_MB" = "" ]; then
        HUGE_PAGE_SIZE_MB=0
    fi

    HUGE_PAGE_SIZE_KB=$(( $HUGE_PAGE_SIZE_MB / 1024 ))
}

huge_pages_get_total()
{
    HUGE_PAGE_TOTAL=`cat /proc/meminfo | grep HugePages_Total | awk '{ print $2 }'`
    if [ "$HUGE_PAGE_TOTAL" = "" ]; then
        HUGE_PAGE_TOTAL=0
    fi
}

huge_pages_get_free()
{
    HUGE_PAGE_FREE=`cat /proc/meminfo | grep HugePages_Free | awk '{ print $2 }'`
    if [ "$HUGE_PAGE_FREE" = "" ]; then
        HUGE_PAGE_FREE=0
    fi
}

huge_pages_get_needed()
{
    if [ $HUGE_PAGE_SIZE_MB -eq 0 ]; then
        die "Could not get huge page size"
    fi

    HUGE_PAGE_NEEDED=$(( $OPT_PLATFORM_MEMORY_MB / $HUGE_PAGE_SIZE_KB ))

    #
    # Seem to need to ask for double to get enough memory for KVM
    #
    log "Huge pages needed per NUMA node, $HUGE_PAGE_NEEDED"

    #
    # Note, the customer may have to do something like this to give enough
    # pages to each numa node.
    #
    # echo 16384 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
    # echo 16384 > /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages
    #
    # For now we just multiply the needed pages by the number of nodes and
    # hope the pages are load balanced appropriately.
    #
    numa_node_count

    HUGE_PAGE_NEEDED=$(( $HUGE_PAGE_NEEDED * $NUMA_NODE_COUNT ))

    log "Huge pages needed total $HUGE_PAGE_NEEDED"
}

huge_pages_enable()
{
    huge_pages_mount
    huge_pages_get_size
    huge_pages_get_total
    huge_pages_get_free
    huge_pages_get_needed
    huge_pages_alloc
}

huge_pages_info()
{
    log "Checking for huge page support:"

    # hugepage support info
    grep pse /proc/cpuinfo | uniq >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	log_low " Hugepages of 2MB are supported"
    fi

    grep pdpe1gb /proc/cpuinfo | uniq >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	log_low " Hugepages of 1GB are supported"
    fi

    local SAVED_IFS=$IFS
    IFS=$'\n'
        for i in `cat /proc/meminfo | grep -i HugePages`
        do
            log_low " $i"
        done
    IFS=$SAVED_IFS
}

print_system_info()
{
    log "Kernel flags:"
    for FLAG in HUGETLB IOMMU
    do
        local SAVED_IFS=$IFS
        IFS=$'\n'
        for i in `grep $FLAG /boot/config-\$(uname -r) | grep -v 'not set'`
        do
            log_low " $i"
        done
        IFS=$SAVED_IFS
    done
}

check_huge_pages()
{
    huge_pages_info

    if [ "$OPT_HUGE_PAGES_CHECK" = "1" ]; then
        huge_pages_enable
    fi
}

#
# The number of NUMA nodes, or 1 if not found
#
numa_node_count()
{
    NUMA_NODE_COUNT=`numactl --hardware | grep available | cut -d' ' -f2`
#    NUMA_NODE_COUNT=`numactl -show 2>/dev/null | grep nodebind | sed 's/.*://g' | awk -F' ' '{print NF; exit}'`
    if [ "$NUMA_NODE_COUNT" = "" ]; then
        NUMA_NODE_COUNT=1
    fi
}

#
# This function finds the number of numa nodes on the system
# It finds the cpu numbers on each numa node and writes them to a per numa file
#
numa_build_cpu_map()
{
    numa_node_count

    CPU_NODES=${LOG_DIR}/cpunodes

    #
    # list the cpu and node combination for the system
    #
    lscpu -p=node,cpu | sort -t, -n -k 1,1 -k 2,2 | grep -v "^#" > $CPU_NODES
    if [ $? != 0 ]; then
	die "Failed to find the node/cpu combination"
    fi

    log_debug "Total numa nodes: $NUMA_NODE_COUNT"
}

numa_build_node_cpu_map()
{
    local filename="$CPU_NODES"
    local total=`expr $NUMA_NODE_COUNT - 1`

    for i in `seq 0 $total`
    do
        fileout=`expr /tmp/nodecpulist$i.out`

	while read line
	do
            local node=`echo $line | cut -d',' -f1`
            local cpunum=`echo $line | cut -d',' -f2`

            if [ $node == $i ]; then
                if [ "${CPU_NODE_LIST[$i]}" = "" ]; then
                    CPU_NODE_LIST[$i]=$cpunum
                else
                    CPU_NODE_LIST[$i]=${CPU_NODE_LIST[$i]}",$cpunum"
                fi
                CPU_TO_NODE[$cpunum]=$node
            fi
	done < $filename
    done

    log "NUMA nodes:"
    for i in `seq 0 $total`
    do
        log_low " Node $i CPUs ${CPU_NODE_LIST[$i]}"
    done

    if [ "$OPT_NUMA_NODE" != "" ]; then
        NUMA_MEM_ALLOC="numactl --membind=$OPT_NUMA_NODE"

        if [ "$OPT_CPU_LIST" = "" ]; then
             OPT_CPU_LIST=${CPU_NODE_LIST[$OPT_NUMA_NODE]}
	fi

        if [ "$OPT_CPU_LIST" = "" ]; then
            die "Could not get CPU list for numa node $OPT_NUMA_NODE"
        else
            log_debug "Using NUMA cpu list for node $OPT_NUMA_NODE"
        fi
    fi
}

#
# Given a set of cpus, verify that they all are on the same node, else errmsg
# input cpu list of form: 1,2,3,4
#
check_numa_cpu_locality()
{
    local ERROR=0

    if [ "$OPT_CPU_LIST" = "" ]; then
        return
    fi

    local LIST=`echo $OPT_CPU_LIST | sed 's/,/ /g'`

    for cpu in $LIST
    do
        MY_NUMA_NODE=${CPU_TO_NODE[$cpu]}
        if [ "$MY_NUMA_NODE" = "" ]; then
            err "Could not map CPU $cpu to a numa node."
            CPU_TO_NODE[$cpu]="-1"
            ERROR=1
        fi
    done

    for cpu in $LIST
    do
        THIS_NODE=${CPU_TO_NODE[$cpu]}
        if [ "$MY_NUMA_NODE" != "$THIS_NODE" ]; then
            err "Not all CPUs are on the same numa node."
            for cpu in $LIST
            do
                err " CPU $cpu => node ${CPU_TO_NODE[$cpu]}"
            done
            ERROR=1
            break
        fi
    done

    if [ $ERROR == 1 ]; then
        err "Non optimal CPU list. Performance may suffer."

        if [ "$OPT_FORCE" = "" ]; then
            sleep 10
        fi
    else
        log "CPUs are all on the same NUMA node, $MY_NUMA_NODE"

        NUMA_MEM_ALLOC="numactl --membind=$MY_NUMA_NODE"

        for cpu in $LIST
        do
            log_low " CPU $cpu => node ${CPU_TO_NODE[$cpu]}"
        done
    fi
}

#
# Check PCI devices we plan to use are on the same NUMA node
#
check_numa_pci_locality()
{
    local ERROR=0

    if [ "$OPT_CPU_LIST" = "" ]; then
        return
    fi

    if [ "$OPT_PCI_LIST" = "" ]; then
        return
    fi

    if [ "$MY_NUMA_NODE" = "" ]; then
        return
    fi

    local LIST=`echo $OPT_CPU_LIST | sed 's/,/ /g'`

    for PCI in $OPT_PCI_LIST
    do
        local PCI_NODE=`cat /sys/bus/pci/devices/$PCI/numa_node`

        if [ "$PCI_NODE" = "" ]; then
            err "Cannot determine the NUMA node for PCI device at /sys/bus/pci/devices/$PCI"
            continue
        fi

        if [ "$PCI_NODE" != "$MY_NUMA_NODE" ]; then
            err "PCI device $PCI is on NUMA node $PCI_NODE whereas CPUs are using NUMA node $MY_NUMA_NODE"
            ERROR=1
        fi
    done

    if [ $ERROR == 1 ]; then
        err "Non optimal NUMA PCI configuration. Performance may suffer."

        if [ "$OPT_FORCE" = "" ]; then
            sleep 10
        fi
    else
        log "PCI devices are all on the same NUMA node, $MY_NUMA_NODE"

        for PCI in $OPT_PCI_LIST
        do
            local PCI_NODE=`cat /sys/bus/pci/devices/$PCI/numa_node`

            log_low " PCI $PCI => node $PCI_NODE"
        done
    fi
}

check_numa_locality()
{
    if [ $OPT_ENABLE_NUMA -eq 0 ]; then
        return
    fi

    for i in taskset lscpu numactl
    do
        which $i &>/dev/null
        if [ $? -ne 0 ]; then
            err "Lack of $i Cannot enable NUMA support"
            true
            return
        fi
    done

    numa_build_cpu_map
    numa_build_node_cpu_map
    check_numa_cpu_locality
    check_numa_pci_locality
}

init_linux_release_specific()
{
    #
    # Fedora?
    #
    if [ -f "/etc/issue.net" ]; then
        is_centos=$(egrep "CentOS" /etc/issue.net)
        if [ -n "${is_centos}" ]; then
            NO_SCRIPT=",script=no,downscript=no"

            uname_r=$(uname -r|egrep '^3\.1[4-9]+')
            if [ -z "${uname_r}" ]; then
                echo "This script need to run on CentOS with kernel 3.14 or higher"
                echo "Your kernel is `uname -r`"
                exit 1
            fi

            SUDO=
        fi

        is_fedora=$(egrep "Fedora" /etc/issue.net)
        if [ -n "${is_fedora}" ]; then
            NO_SCRIPT=",script=no,downscript=no"

            SUDO=
        fi
    fi

    #
    # Ubuntu?
    #
    lsb_release -a 2>/dev/null | grep -q Ubuntu
    if [ $? -eq 0 ]; then
        SUDO="sudo"
        is_ubuntu=1
    fi
}

init_paths()
{
    export PATH="/sbin:/usr/sbin:$PATH"

    #
    # Hard coded path for COT.
    #
    # Or get it from https://github.com/glennmatthews/cot
    #
    export PATH="$PATH:/auto/nsstg-tools/bin"

    #
    # Get rid of any ancient cisco tools sitting on the path
    #
    export PATH=`echo "$PATH" | sed 's;/router/bin;;g'`
}

init_globals()
{
    PWD=`pwd`

    #
    # Python saves centos/redhat/... information
    #
    HOST_PLATFORM=`python -mplatform`

    #
    # For telnet sessions
    #
    RANDOM_PORT_RANGE=10000
    RANDOM_PORT_BASE=10000
    #
    # For doing numa memory binding to a specific node
    #
    NUMA_MEM_ALLOC=""
}

lock_assert()
{
    LOCK_FILE=/tmp/$PROGRAM.lock
    HAVE_LOCK_FILE=

    local TRIES=0

    while [ $TRIES -lt 10 ]
    do
        TRIES=$(expr $TRIES + 1)

        if [ -f $LOCK_FILE ]; then
            log "Waiting on lock, $LOCK_FILE"
            sleep 1
            continue
        fi

        echo $MYPID > $LOCK_FILE
        if [ $? -ne 0 ]; then
            log "Could not write to lock file, $LOCK_FILE"
            sleep 1
            continue
        fi

        local LOCK_PID=`cat $LOCK_FILE`
        if [ $? -ne 0 ]; then
            log "Could not read lock file, $LOCK_FILE"
            sleep 1
            continue
        fi

        if [ "$LOCK_PID" != "$MYPID" ]; then
            log "Lock file grabbed by PID $LOCK_PID"
            sleep 1
            continue
        fi

        log "Grabbed lock"
        HAVE_LOCK_FILE=$LOCK_FILE
        break
    done

    if [ "$HAVE_LOCK_FILE" = "" ]; then
        err "Could not grab lock"
    fi
}

lock_release()
{
    if [ "$HAVE_LOCK_FILE" = "" ]; then
        return
    fi

    log "Released lock"
    rm -f $HAVE_LOCK_FILE
    HAVE_LOCK_FILE=
}

main()
{
    init_paths
    init_globals
    init_linux_release_specific
    init_tool_defaults
    init_platform_defaults_iosxrv_64

    record_usage &>/dev/null

    read_early_options $0 "$@"
    create_log_dir
    read_options $0 "$@"

    post_read_options_check_sanity
    post_read_options_init
    post_read_options_fini

    print_system_info

    modify_chef_container
    modify_xr_hostname

    check_net_tools_installed
    check_host_bridge_is_ok
    check_qemu_install_is_ok
    check_centos_install_is_ok
    check_ubuntu_install_is_ok
    check_kvm_accel
    check_huge_pages
    check_numa_locality

    create_disks

    if [ "$OPT_DISABLE_BOOT" != "" ]
    then
        log "QEMU boot disabled"
    else
        lock_assert
        create_taps
        create_telnet_ports
        lock_release

        qemu_create_scripts
        qemu_start
        qemu_wait
    fi

    create_raw
    create_qcow2
    create_images
}

main "$@"

okexit
