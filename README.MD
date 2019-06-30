# WireGuard Setup

This script is made for simplifying the set up of a wireguard vpn as well as an unbound DNS server.

It's originally designed for a Debian server, but could be improved for other Os.

## Usage

Make sure you have WireGuard installed on your server. Follow [those instructions](https://www.wireguard.com/install/) from the official WireGuard website.

To initiate the VPN and configure the Unbound DNS, use the following command and let you guide :

```
./server_config.sh init
```

Every time you need to add a peer to your network, use this command and let you guide one more time :

```
./server_config.sh peer
```
