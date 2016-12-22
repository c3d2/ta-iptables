#!/usr/bin/env bash

set -eux

sysctl -w net.ipv4.conf.all.forwarding=1 \
  net.ipv4.conf.default.forwarding=1 \
  net.ipv6.conf.all.forwarding=1 \
  net.ipv6.conf.default.forwarding=1

ip netns delete router >/dev/null 2>&1 || true
ip netns delete nas >/dev/null 2>&1 || true
ip netns delete pc >/dev/null 2>&1 || true
ip link delete router >/dev/null 2>&1 || true
ip link delete br0 >/dev/null 2>&1 || true

ip netns add pc
ip netns add router
ip netns add nas

ip netns exec pc bash -x -c '
  ip link set lo up
  ip link add eth0 type veth peer name pc
  ip link set eth0 up
  ip addr add 192.168.42.2/24 dev eth0
  ip addr add fd42::2/64 dev eth0
  ip route add default via 192.168.42.1 dev eth0
  ip route add default via fe80::1 dev eth0
  ip link set pc netns router
'

ip netns exec nas bash -x -c '
  ip link set lo up
  ip link add eth0 type veth peer name nas
  ip link set eth0 up
  ip addr add 192.168.42.3/24 dev eth0
  ip addr add fd42::3/64 dev eth0
  ip route add default via 192.168.42.1 dev eth0
  ip route add default via fe80::1 dev eth0
  ip link set nas netns router
'

ip netns exec router bash -x -c '
  ip link set lo up

  sysctl -w net.ipv4.conf.all.forwarding=1 \
    net.ipv4.conf.default.forwarding=1 \
    net.ipv6.conf.all.forwarding=1 \
    net.ipv6.conf.default.forwarding=1

  ip link add lan type bridge
  ip link set dev pc master lan
  ip link set dev nas master lan
  ip link set pc up
  ip link set nas up
  ip link set lan up

  ip addr add 192.168.42.1/24 dev lan
  ip addr add fe80::1/24 dev lan
  ip addr add fd42::1/64 dev lan

  ip link add wan type veth peer name router
  ip link set wan up
  # xxx hopefully free
  ip addr add 172.22.99.249/24 dev wan
  ip addr add fe80::92/65 dev wan

  ip route add default dev wan
  ip -6 route add default dev wan

  ip link set router netns 1
'

ip link add br0 type bridge
ip link set router master br0
ip link set router up
ip link set br0 up
# for debugging
#ip addr add 172.22.99.250/24 dev br0
#ip addr add fd43::1/64 dev br0

ip route a fd42::1/64 via fe80::92 dev br0
ip route add 192.168.42.0/24 via 172.22.99.249 dev br0
