
Iptables is a widely used firewall tool that interfaces with the kernel’s netfilter packet filtering framework  
Take a look!
### hooks
The following hooks represent various well-defined points in the networking stack:

+ **NF_IP_PRE_ROUTING:** This hook will be triggered by any incoming traffic very soon after entering the network stack. This hook is processed before any routing decisions have been made regarding where to send the packet.
+ **NF_IP_LOCAL_IN:** This hook is triggered after an incoming packet has been routed if the packet is destined for the local system.
+ **NF_IP_FORWARD:** This hook is triggered after an incoming packet has been routed if the packet is to be forwarded to another host.
+ **NF_IP_LOCAL_OUT:** This hook is triggered by any locally created outbound traffic as soon it hits the network stack.
+ **NF_IP_POST_ROUTING:** This hook is triggered by any outgoing or forwarded traffic after routing has taken place and just before being put out on the wire.

### chains 
built-in chains
+ **PREROUTING:** Triggered by the NF_IP_PRE_ROUTING hook.
+ **INPUT:** Triggered by the NF_IP_LOCAL_IN hook.
+ **FORWARD:** Triggered by the NF_IP_FORWARD hook.
+ **OUTPUT:** Triggered by the NF_IP_LOCAL_OUT hook.
+ **POSTROUTING:** Triggered by the NF_IP_POST_ROUTING hook.

### tables
+ **The Filter Table**
The filter table is one of the most widely used tables in iptables. The filter table is used to make decisions about whether to let a packet continue to its intended destination or to deny its request. In firewall parlance, this is known as “filtering” packets. This table provides the bulk of functionality that people think of when discussing firewalls.

+ **The NAT Table**
The nat table is used to implement network address translation rules. As packets enter the network stack, rules in this table will determine whether and how to modify the packet’s source or destination addresses in order to impact the way that the packet and any response traffic are routed. This is often used to route packets to networks when direct access is not possible.

+ **The Mangle Table**
The mangle table is used to alter the IP headers of the packet in various ways. For instance, you can adjust the TTL (Time to Live) value of a packet, either lengthening or shortening the number of valid network hops the packet can sustain. Other IP headers can be altered in similar ways.

This table can also place an internal kernel “mark” on the packet for further processing in other tables and by other networking tools. This mark does not touch the actual packet, but adds the mark to the kernel’s representation of the packet.

+ **The Raw Table**
The iptables firewall is stateful, meaning that packets are evaluated in regards to their relation to previous packets. The connection tracking features built on top of the netfilter framework allow iptables to view packets as part of an ongoing connection or session instead of as a stream of discrete, unrelated packets. The connection tracking logic is usually applied very soon after the packet hits the network interface.

The raw table has a very narrowly defined function. Its only purpose is to provide a mechanism for marking packets in order to opt-out of connection tracking.

+ **The Security Table**
The security table is used to set internal SELinux security context marks on packets, which will affect how SELinux or other systems that can interpret SELinux security contexts handle the packets. These marks can be applied on a per-packet or per-connection basis.

{{< figure src="img/tables-chains.png" caption="tables and chains" >}}

## Chain Traversal Order
Assuming that the server knows how to route a packet and that the firewall rules permit its transmission, the following flows represent the paths that will be traversed in different situations:
{{< figure src="img/1_flow.png" caption="packet flow" >}}
Incoming packets destined for the local system: PREROUTING -> INPUT (raw, mangle, and nat tables)
Incoming packets destined to another host: PREROUTING -> FORWARD -> POSTROUTING
Locally generated packets: OUTPUT -> POSTROUTING (mangle, filter, security, and nat tables)

## Targets
A target is the action that are triggered when a packet meets the matching criteria of a rule. Targets are generally divided into two categories:

+ **Terminating targets:** Terminating targets perform an action which terminates evaluation within the chain and returns control to the netfilter hook. Depending on the return value provided, the hook might drop the packet or allow the packet to continue to the next stage of processing.
+ **Non-terminating targets:** Non-terminating targets perform an action and continue evaluation within the chain. Although each chain must eventually pass back a final terminating decision, any number of non-terminating targets can be executed beforehand.

The availability of each target within rules will depend on context. For instance, the table and chain type might dictate the targets available. The extensions activated in the rule and the matching clauses can also affect the availability of targets.

## Jumping to User-Defined Chains
We should mention a special class of non-terminating target: the jump target. Jump targets are actions that result in evaluation moving to a different chain for additional processing. We’ve talked quite a bit about the built-in chains which are intimately tied to the netfilter hooks that call them. However, iptables also allows administrators to create their own chains for organizational purposes.

**Rules can be placed in user-defined chains in the same way that they can be placed into built-in chains. The difference is that user-defined chains can only be reached by “jumping” to them from a rule (they are not registered with a netfilter hook themselves).**

User-defined chains act as simple extensions of the chain which called them. For instance, in a user-defined chain, evaluation will pass back to the calling chain if the end of the rule list is reached or if a RETURN target is activated by a matching rule. Evaluation can also jump to additional user-defined chains.

## Connections tracking
The system checks each packet against a set of existing connections. It will update the state of the connection in its store if needed and will add new connections to the system when necessary. Packets that have been marked with the NOTRACK target in one of the raw chains will bypass the connection tracking routines.

Available States
Connections tracked by the connection tracking system will be in one of the following states:

+ **NEW:** When a packet arrives that is not associated with an existing connection, but is not invalid as a first packet, a new connection will be added to the system with this label. This happens for both connection-aware protocols like TCP and for connectionless protocols like UDP.
+ **ESTABLISHED:** A connection is changed from NEW to ESTABLISHED when it receives a valid response in the opposite direction. For TCP connections, this means a SYN/ACK and for UDP and ICMP traffic, this means a response where source and destination of the original packet are switched.
+ **RELATED:** Packets that are not part of an existing connection, but are associated with a connection already in the system are labeled RELATED. This could mean a helper connection, as is the case with FTP data transmission connections, or it could be ICMP responses to connection attempts by other protocols.
+ **INVALID:** Packets can be marked INVALID if they are not associated with an existing connection and aren’t appropriate for opening a new connection, if they cannot be identified, or if they aren’t routable among other reasons.
+ **UNTRACKED:** Packets can be marked as UNTRACKED if they’ve been targeted in a raw table chain to bypass tracking.
+ **SNAT:** A virtual state set when the source address has been altered by NAT operations. This is used by the connection tracking system so that it knows to change the source addresses back in reply packets.
+ **DNAT:** A virtual state set when the destination address has been altered by NAT operations. This is used by the connection tracking system so that it knows to change the destination address back when routing reply packets.

### check connection table

```sh
conntrack -L -d 13.93.66.174
```

## Some examples of SNAT, DNAT with iptables with comments
> mainly used in start-up script

### masquarade all outgoing packets to be WLAN0 IP
```sh
iptables -t nat -A PREROUTING -s 192.168.1.2 -i eth0 -j MASQUERADE
```

#### All packets leaving eth0 will have src eth0 ip address
```sh
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to 192.168.1.1
```

## Match rule specifying a source port
> Below makes sure packets from Eth Devices have correct source IP Address
> Notice, when specifying a port, protocol needs to be specified as well
```sh
iptables -t nat -A POSTROUTING -o wlan0 -s 192.168.1.2 -p udp --dport 16020 -j SNAT --to 10.1.1.7:51889
iptables -t nat -A POSTROUTING -o wlan0 -s 192.168.1.2 -p tcp --dport 21 -j SNAT --to 10.1.1.7:21
iptables -t nat -A POSTROUTING -o wlan0 -s 192.168.1.3 -j SNAT --to 10.1.1.9


# Packets destined for IP 10.1.1.7 will be forwaded to 192.168.1.2 UDP,TCP
# Packets destined for IP 10.1.1.9 will be forwaded to 192.168.1.3 UDP,TCP
# Does work with ping (ICMP) correctly
iptables -t nat -A PREROUTING -i wlan0 -d 10.1.1.7 -j DNAT --to-destination 192.168.1.2
iptables -t nat -A PREROUTING -i wlan0 -d 10.1.1.9 -j DNAT --to-destination 192.168.1.3
```

### Packets destined for IP 10.1.1.7 will be forwaded to 192.168.1.2 UDP,TCP
> Does NOT work with ping (ICMP) correctly, does not handle ICMP protocol
> WLAN IP reply on a ping without
```sh
iptables -t nat -A PREROUTING -p tcp -i wlan0 -d 10.1.1.7 -j DNAT --to-destination 192.168.1.2
iptables -t nat -A PREROUTING -p udp -i wlan0 -d 10.1.1.7 -j DNAT --to-destination 192.168.1.2
```

### Change SNMP port of outgoing SNMP messages
```sh
iptables -t nat -A OUTPUT -p udp --dport 162 -j DNAT --to-destination 192.168.1.33:1162
```

### Add secondary IP to WLAN0
```sh
ip addr add 10.1.1.7/24 dev wlan0
ip addr add 10.1.1.9/24 dev wlan0
```
### List all IP addresses asign to wlan0
```ip add list dev wlan0```

### All packets leaving eth1 will change source IP to 192.168.20.1
```sh
iptables -t nat -A POSTROUTING -o eth1 -j SNAT --to 192.168.20.1
```

### All TCP packets leaving eth1 on port 443 will change source IP to 192.168.20.1
```sh
iptables -t nat -A POSTROUTING -o eth1 -s 192.168.1.22 -p tcp --dport 443 -j SNAT --to 192.168.20.1:443
```

### All ICMP packets leaving eth1 will change source IP to 192.168.20.1
```sh
iptables -t nat -A POSTROUTING -o eth1 -s 192.168.1.22 -p icmp -j SNAT --to 192.168.20.1
```

### All supported packets leaving eth1 which have source IP 192.168.1.22 will change source IP to 192.168.20.1
```sh
iptables -t nat -A POSTROUTING -o eth1 -s 192.168.1.22 -p all -j SNAT --to 192.168.20.1
```

## SNAT on dynamically assign interface

> usage with WIFI dual mode where WiFi can be AP and STA at the same time
> add to **start-up script**
```sh
# assuming wlan1 is STA interface
ip=$(ip -o addr show up primary scope global wlan1 |
      while read -r num dev fam addr rest; do echo ${addr%/*}; done)
echo $ip

# all packets leaving wlan1 will change source IP to STA interface IP
iptables -t nat -A POSTROUTING -o wlan1 -j SNAT --to $ip
```

## Check NAT table

```sh
iptables -t nat -L -n -v
```

