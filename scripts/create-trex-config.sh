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
echo "Socket:" ${SOCKET}
envsubst <  /opt/templates/trex_cfg.yaml > "/etc/trex_cfg.yaml"
