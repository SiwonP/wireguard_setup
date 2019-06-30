#!/usr/bin/env bash

echo Name of the client :
read client

wg genkey | tee privatekey_$client | wg pubkey > publickey_$client

private=`cat privatekey_$client`
#public=`cat publickey_$client`

echo [Interface] > $client.conf
echo PrivateKey = $private >> $client.conf

Echo Enter allocated address by the server :
read ip

echo Address = $ip >> $client.conf
echo Enter local DNS IP :
read dns

echo DNS = $dns >> $client.conf

echo Enter Public IP address of the server and the port :
read public_ip

echo Enter public key of the server :
read key

echo >> $client.conf
echo [Peer] >> $client.conf
echo PublicKey = $key >> $client.conf
echo Endpoint = $public_ip >> $client.conf
echo AllowedIPs = 0.0.0.0/0 >> $client.conf
echo PersistentKeepalive = 21 >> $client.conf
