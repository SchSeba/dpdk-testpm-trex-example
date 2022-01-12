set -ex

vpp -c /etc/vpp/startup.conf &
sleep 10

IP=10
vppctl show int | grep Virtual | awk '{print $1}'  | while read line; do
echo "vppctl set interface ip address $line 10.10.${IP}.1/24" >> /tmp/commands.sh
echo "vppctl set interface state $line up" >> /tmp/commands.sh
IP=$((IP + 10))
done

echo "vppctl ip route add 17.0.0.0/24 via 10.10.10.2" >> /tmp/commands.sh
echo "vppctl ip route add 18.0.0.0/24 via 10.10.20.2" >> /tmp/commands.sh

chmod +x /tmp/commands.sh
/tmp/commands.sh

echo "VPP is running"
sleep INF