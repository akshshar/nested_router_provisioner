#!/usr/bin/expect
proc ex {args} {

        send "$args\r"

        expect timeout {
                send_user "command execution timed out \r"
         } -re "#" {

        }
}
set count 0
exp_internal 1
#log_user 0

set xr_telnet_port [lindex $argv 0]

proc login {} {
global done
expect {
  "Enter root-system username:" {
    send "root\r"
    puts "Set up Username condition"
    sleep 2
    exp_continue
  }

  "Enter secret:" {
    send "root\r"
    puts "Set up password"
    sleep 2
    exp_continue
  }

  "Enter secret again:" {
    send "root\r"
    puts "Re-enter password"
    sleep 2
    exp_continue
  }
    
  "Username:" {
    send "root\r"
    sleep 2
    exp_continue
  }
  "Password:" {
    send "root\r"
    sleep 2
    exp_continue
  }
  "RP/0/RP0/CPU0:ios#" {
    send "\r"
    sleep 2
    set done 1
  }
  "RP/0/RP0/CPU0:ios(config)#" {
    send " exit \r"
    sleep 2
    set done 1
  }
  "RP/0/RP0/CPU0:ios(config-if)" {
      send "exit \r"
      sleep 2
      set done 1
  }
}
}

spawn telnet localhost $xr_telnet_port 
send "\r\r\r\r"
set done 0
while 1 {
  login
  if {$done == 1} {
      break
   }
  send "\r\r\r\r"
sleep 5
}
