#!/bin/sh

dev=$(ls /sys/class/net)
dns="8.8.8.8 8.8.4.4"

iptables -F
iptables -F -t nat
iptables -F -t mangle

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

#allow loopback
#iptables -A INPUT -i lo -j ACCEPT
#iptables -A OUTPUT -o lo -j ACCEPT

for d in $dev
do
addr=$(/sbin/ifconfig $d | grep 'inet addr' | cut -d: -f2 | awk '{print $1}') 

for a in $addr
do
#allow ssh from outside
iptables -A INPUT -i $d -d $a -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $d -s $a -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

#allow ssh to outside
iptables -A OUTPUT -o $d -s $a -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i $d -d $a -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

#allow ping
#in
iptables -A INPUT -i $d -d $a -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o $d -s $a -p icmp --icmp-type echo-reply -j ACCEPT
#out
iptables -A INPUT -i $d -d $a -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -o $d -s $a -p icmp --icmp-type echo-request -j ACCEPT


#allow ports from outside to inside
#iptables -A INPUT -i $d -d $a -p tcp -m multiport --dports 80,5080,1935,53,443,25 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -o $d -s $a -p tcp -m multiport --sports 80,5080,1935,53,443,25 -m state --state ESTABLISHED -j ACCEPT
#allow http from inside to outside
iptables -A INPUT -i $d -d $a -p tcp -m multiport  --sports 80,443 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $d -s $a -p tcp -m multiport --dports 80,443 -m state --state NEW,ESTABLISHED -j ACCEPT

#NAMESERVER from inside to outside

#allow dhcp
#iptables -A INPUT -i $d -d $a -p udp --dport 67:68 --sport 67:68 -j ACCEPT
#iptables -A OUTPUT -o $dev -s $a -p udp --sport 67:68 --dport 67:68 -m state --state ESTABLISHED -j ACCEPT

done
for ip in $dns
do
iptables -A OUTPUT -o $d -s $a -d $ip -p tcp --dport 53 -m state --state  NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i $d -d $a -s $ip -p tcp --sport 53 -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $d -s $a -d $ip -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i $d -d $a -s $ip -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
echo $d " : " $a " : " $ip
done
done

