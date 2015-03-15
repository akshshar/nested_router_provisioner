#!/usr/bin/expect
proc ex {args} {

        send "$args\r"

        expect timeout {
                send_user "command execution timed out \r"
         } -re "#" {

        }
}
set count 0
#exp_internal 1
log_user 0

set host_telnet_port [lindex $argv 0]
proc login {} {
expect {
  "login:" {
    send "root\r"
    exp_continue
  }

  "Username:" {
    send "root\r"
    exp_continue
  }
  "Password:" {
    send "lab\r"
    exp_continue
  }
  "login incorrect" {
    incr count
    exp_continue
  }
  "*host:~*" {
      send -- "\r\r"
      expect -exact "\[host:~\]\$"
      send -- "ifconfig eth2\r\r"
      expect -re {inet addr:(\S+)}
      catch [set ipaddr $expect_out(1,string)]
      return $ipaddr
  }
}
}

spawn telnet localhost $host_telnet_port 
send "\r\r\r\r"
sleep 5
set ip ""
while 1 {
    set ip [login]
    if {[regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $ip]} {
        break
    }
}
puts $ip
