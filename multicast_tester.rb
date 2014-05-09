#!/usr/bin/ruby -w
#
#TODO : exception handling, args filtering, output log file, number of seconds to run ("ping" function will have to become a thread)
#
#
require "socket"
require "ipaddr"



def listener(multicast_group, bind_ip, port)

   socket_response=Array.new()
   socket=""
   membership=""

   socket = UDPSocket.new
   membership = IPAddr.new(multicast_group).hton + IPAddr.new(bind_ip).hton
   socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, membership)
#   socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEPORT, 1)# SO_REUSEPORT doesn't exist in kernels <3.9 - for these kernels theres another flag we can use
#                                                                   that should have the same effect when dealing with multicast (??)
   socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1) #so we have to use this for compatibility purposes, is it safe? Application collisions?
   socket.bind(bind_ip, port)

   while (1)
      socket_response=socket.recvfrom(255)
      $message_mutex.lock #not really needed / provisioning for >1 threads when option to bind to multiple IPs is added
                                    $message = socket_response[0].chomp+"("+socket_response[1][3].chomp+")"
      $message_mutex.unlock
   end
end


def multicast_er(multicast_group, port, ttl)

   while (true)
      socket = UDPSocket.open
      socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, ttl)
      socket.send(`hostname`.chomp, 0, multicast_group.to_s, port)
                     #if (daft==1) then better to chomp habitually and produce useless code than not to chomp and occasionally produce bugs
      socket.close
      wait 1
   end
end


def keyboard_interrupt()

   input=""
   input=$stdin.gets.chomp
   return 0
end



def main

   $message=""
   $message_mutex=Mutex.new()
   hosts_array=Array.new()
   listener_thread=""


   if (ARGV[0] != nil)
      if (ARGV[3] != nil)
         multicast_group=ARGV[0]
         bind_ip=ARGV[1]
         port=ARGV[2].to_i
         ttl=ARGV[3].to_i
      else
         multicast_group=ARGV[0]
         bind_ip="0.0.0.0"
         port=ARGV[1].to_i
         ttl=ARGV[2].to_i
      end
   else
      puts "usage : ./multicast_tester.rb multicast_group_ip [ip_to_bind] port ttl"
      exit 0
   end

   listener_thread=Thread.new{listener(multicast_group, bind_ip, port)}
   puts "\e[H\e[2J"
   puts "listening to multicast group : %s on port %s       (press enter to exit)" % [multicast_group, port]
   keyboard_interrupt_thread=Thread.new{keyboard_interrupt()}
   multicast_er_thread=Thread.new{multicast_er(multicast_group, port, ttl)}

   while (keyboard_interrupt_thread.alive?)
      if (!(hosts_array.include?($message.chomp)) && $message!="")
         $message_mutex.lock
                                       hosts_array<<$message.chomp
         $message_mutex.unlock
         puts "\e[H\e[2J"
         puts "listening to multicast group : %s on port %s       (press enter to exit)\n\n" % [multicast_group, port]
         print "hosts found :\t"
         hosts_array.each {|blah| print " %s" % [blah]}
      end
   end

   listener_thread.exit
   multicast_er_thread.exit
end


main()
