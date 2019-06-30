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

dns()
{
    IP=$1

    if [[ $OSTYPE =~ "linux" ]]; then 
        apt-get install unbound unbound-host
    curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
    fi


    # cat > /etc/unbound/unbound.conf << ENDOFFILE
    cat > unbound.conf << ENDOFFILE
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

    echo \[Interface\] > wg0.conf
    echo Address = $SUBNET >> wg0.conf
    echo ListenPort = $PORT >> wg0.conf
    echo PrivateKey = $private >> wg0.conf

    dns "$SUBNET"
}

peer()
{
    echo "" >> wg0.conf
    echo \[Peer\] >> wg0.conf
    echo Enter the public key of the peer :
    read key
    echo PublicKey = $key >> wg0.conf
}

if [ $# -eq 0 ]; then
    show_help
elif [ $1 == "init" ]; then
    init
elif [ $1 == "peer" ]; then
    peer
fi
