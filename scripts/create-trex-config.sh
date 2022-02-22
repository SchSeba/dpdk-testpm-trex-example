set -ex
export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}

IFS="," read -ra arr <<< $CPU

export MASTER="${arr[0]}"
unset 'arr[0]'
export LATENCY="${arr[1]}"
unset 'arr[1]'
CPU=""
echo ${arr[@]}
for i in "${arr[@]}"
do
   CPU="$CPU,$i"
done
CPU="${CPU:1}"
echo $CPU

NODE=`lscpu | grep ${MASTER}, | awk '/node0/{print "0"}{print "1"}'`
export SOCKET="0"
if [[ ${NODE} -eq 1 ]]
then
export SOCKET="1"
fi

echo "Socket:" ${SOCKET}
envsubst <  /opt/templates/trex_cfg.yaml > "/etc/trex_cfg.yaml"
