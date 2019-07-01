#!/bin/bash

check_ip_format()
{
    isip=1
    if [[ $1 =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2} ]]
    then
        isip=0
    fi
    return $isip
}

check_port_format()
{
    isport=1
    if [[ $1 =~ [0-9]{4,5} ]]
    then
        isport=0
    fi
    return $isport
}

show_help()
{
    echo
    echo This is a script to help configuring the server of a WireGuard VPN
    echo
    echo Usage : ./server_config.sh \<command\>
    echo
    echo Commands :
    echo init : Initiate the server for the first time.
    echo peer : Add a new peer to the configuration.
}

generate_keys()
{
    wg genkey | tee privatekey | wg pubkey > publickey
}

extract_address()
{
    regex_ip="([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)([0-9]{1,3})\/[0-9]{2}"
    if [[ $1 =~ $regex_ip ]]; then
        base=${BASH_REMATCH[1]}
        echo base:$base > /etc/wireguard/subnet
        current=${BASH_REMATCH[2]}
        echo current:$current >> /etc/wireguard/subnet
    fi

}

firewall()
{
    IP=$1
    PORT=$2

    echo 1 > /proc/sys/net/ipv4/ip_forward

    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p udp -m udp --dport $PORT -m conntrack --ctstate NEW -j ACCEPT
    iptables -A INPUT -s $IP -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
    iptables -A INPUT -s $IP -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT

}

dns()
{
    IP=$1

    if [[ $OSTYPE =~ "linux" ]]; then
        apt-get install unbound unbound-host
        curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
    fi


    # cat > unbound.conf << ENDOFFILE
    cat > /etc/unbound/unbound.conf << ENDOFFILE
server:
    num-threads: 4

    # enable logs
    verbosity: 1

    # list of root DNS servers
    root-hints: "/var/lib/unbound/root.hints"

    # use the root server's key for DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

    # respond to DNS requests on all interfaces
    interface: 0.0.0.0
    max-udp-size: 3072

    # IPs authorised to access the DNS Server
    access-control: 0.0.0.0/0                 refuse
    access-control: 127.0.0.1                 allow
    access-control: $IP                 allow

    # not allowed to be returned for public Internet  names
    private-address: $IP

    #hide DNS Server info
    hide-identity: yes
    hide-version: yes

    # limit DNS fraud and use DNSSEC
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes

    # add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
    unwanted-reply-threshold: 10000000

    # have the validator print validation failures to the log
    val-log-level: 1

    # minimum lifetime of cache entries in seconds
    cache-min-ttl: 1800

    # maximum lifetime of cached entries in seconds
    cache-max-ttl: 14400
    prefetch: yes
    prefetch-key: yes
ENDOFFILE

    chown -R unbound:unbound /var/lib/unbound
    systemctl enable unbound-resolvconf
    systemctl enable unbound
}



init()
{
    echo
    echo Begin the configuration for a VPN server using WireGuard
    echo

    generate_keys
    private=`cat privatekey`
    #public=`cat publickey`

    SUBNET="10.8.0.0/24"

    echo Enter the ip of the private network to be used : \($SUBNET\)
    read sub

    if [ -z $sub ]; then
        SUBNET="10.8.0.0/24"
    else
        SUBNET=$sub
    fi

    check_ip_format "$SUBNET"

    while [ $? -eq 1 ]
    do
        echo Enter a proper IPv4 format :
        read sub
        SUBNET=$sub
        check_ip_format "$SUBNET"

    done

    #echo Your sub-network will be $SUBNET

    echo Enter the listening port : \(1194\)
    read port

    if [ -z $port ]; then
        PORT=1194
    else
        PORT=$port
    fi

    check_port_format "$PORT"

    while [ $? -eq 1 ]
    do
        echo Enter a proper port format :
        read port
        PORT=$port
        check_port_format "$PORT"
    done

    echo \[Interface\] > /etc/wireguard/wg0.conf
    echo Address = $SUBNET >> /etc/wireguard/wg0.conf
    echo ListenPort = $PORT >> /etc/wireguard/wg0.conf
    echo PrivateKey = $private >> /etc/wireguard/wg0.conf

    interface_regex="([a-z]{1,3}[0-9])\: \<BROADCAST"
    interface=`ip link show`
    if [[ $interface =~ $interface_regex ]]; then
        in=${BASH_REMATCH[1]}
    fi

    echo "PostUp = iptables -t nat -A POSTROUTING -o $in -j MASQUERADE;
    ip6tables -t nat -A POSTROUTING -o $in -j MASQUERADE" >> /etc/wireguard/wg0.conf
    echo "PostDown = iptables -t nat -D POSTROUTING -o $in -j MASQUERADE;
    ip6tables -t nat -D POSTROUTING -o $in -j MASQUERADE" >> /etc/wireguard/wg0.conf

    wg-quick up wg0

    extract_address "$SUBNET"

    firewall "$SUBNET" "$PORT"

    dns "$SUBNET"
}

peer()
{
    wg-quick down wg0
    echo "" >> /etc/wireguard/wg0.conf
    echo \[Peer\] >> /etc/wireguard/wg0.conf
    echo Enter the public key of the peer :
    read key
    echo PublicKey = $key >> /etc/wireguard/wg0.conf
    file="/etc/wireguard/subnet"
    base_regex="base\:([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)"
    current_regex="current\:([0-9]*)"

    while read LINE
    do
    if [[ $LINE =~ $base_regex ]]; then
        base=${BASH_REMATCH[1]}
    elif [[ $LINE =~ $current_regex ]]; then
        current=${BASH_REMATCH[1]}
    fi

    done < $file

    current=$((current+1))

    echo $base$current
    echo AllowedIPs = $base$current/32 >> /etc/wireguard/wg0.conf
    echo base:$base > /etc/wireguard/subnet
    echo current:$current >> /etc/wireguard/subnet
    wg-quick up wg0
}

if [ $# -eq 0 ]; then
    show_help
elif [ $1 == "init" ]; then
    init
elif [ $1 == "peer" ]; then
    peer
fi
