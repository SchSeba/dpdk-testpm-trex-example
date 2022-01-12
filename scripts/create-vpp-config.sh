set -ex
export CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
echo ${CPU}

IFS="," read -ra arr <<< $CPU

export MASTER="${arr[0]}"
unset 'arr[0]'
CPU=""
echo ${arr[@]}
for i in "${arr[@]}"
do
   CPU="$CPU,$i"
done
CPU="${CPU:1}"
echo $CPU

NODE=`lscpu | grep ${MASTER} | awk '/node0/{print "0"}{print "1"}'`
export SOCKET_MEM="socket-mem 2048,0"
if [[ ${NODE} -eq 1 ]]
then
export SOCKET_MEM="socket-mem 0,2048"
fi


envsubst <  /opt/templates/startup-template.conf > "/etc/vpp/startup.conf"
