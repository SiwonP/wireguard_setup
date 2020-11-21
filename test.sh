interface_regex="([a-z]{1,3}[0-9])\: \<BROADCAST"
interface=`ip link show`
if [[ $interface =~ $interface_regex ]]; then
    in=${BASH_REMATCH[1]}
fi


