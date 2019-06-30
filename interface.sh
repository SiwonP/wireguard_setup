regex="([a-z]{1,3}[0-9])\: \<BROADCAST"

str="2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state
UP mode DEFAULT group default qlen 1000"

if [[ $str =~ $regex ]]; then
    echo oui
    echo ${BASH_REMATCH[1]}
fi
