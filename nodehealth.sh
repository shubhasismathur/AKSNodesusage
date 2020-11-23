#!/bin/bash

# We can pass config file as parameter else default path will be picked
if [ $# -eq 1 ]
then
    export KUBECONFIG="${1}"
else
    export KUBECONFIG="`echo ~`/.kube/config"
fi

format="%40s|%10s|%7s|%15s|%15s|%15s|%15s|%15s|%15s|%15s|\n"

tmp_file="/tmp/log.k8s"
node_count=0

printf "$format" "NODE_NAME" "POD_COUNT" "CPU(s)"  "CPU_REQ" "CPU_USAGE(%)" "CPU_REQ(%)" "MEM" "MEM_REQ" "MEM_USAGE(%)"  "MEM_REQ(%)"

printf '%0.1s' "-"{1..152}
printf "\n"

for x in `kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}|{.status.capacity.cpu}|{.status.capacity.memory}{"\n"}{end}'`
do
    node=`echo $x |cut -d "|" -f1`
    cpu=`echo $x |cut -d "|" -f2`
    mem=`echo $x |cut -d "|" -f3`
    kubectl describe node $node > ${tmp_file}
    ####### Count of Pod Running on Node ################
    pod_count=`cat ${tmp_file} |grep  "Non-terminated Pods:"  |grep -Eo '[0-9]+'`
    ####### Calculate the Resource Usage  Count  #########
    usage=`kubectl top node --no-headers $node |grep  -Eo '\w+%' |tr -d "%" |tr "\n" " "` 
    cpu_usage_per=`echo $usage |cut -d " " -f1`
    mem_usage_per=`echo $usage |cut -d " " -f1`
    total_per_cpu_usage=$((total_per_cpu_usage + cpu_usage_per))
	total_per_mem_usage=$((total_per_mem_usage + mem_usage_per))
    ####### Calculate the Resource Request count #########
    resource=`cat ${tmp_file}|grep -E -A 3 "Requests(.*)Limits$" |grep -E "cpu|memory" |tr -s " " |sed -e "s/cpu//" -e "s/memory//" |tr "\n" "|"`
    cpu_req=`echo ${resource}|cut -d "|" -f1 |awk -F " " '{print $1}'`
    cpu_req_per=`echo ${resource}| cut -d "|" -f1 |awk -F "[()%]" '{print $2}'`
    mem_req=`echo ${resource}|cut -d "|" -f2 |awk -F " " '{print $1}'`
    mem_req_per=`echo ${resource}|cut -d "|" -f2 |awk -F "[()%]" '{print $2}'`
    #echo -e "${node}\t${cpu}\t${mem}\t${cpureq}\t${cpureqper}%\t${memreq}\t${memreq}%"
    printf "$format" ${node} ${pod_count} ${cpu} ${cpu_req} ${cpu_usage_per} ${cpu_req_per} ${mem} ${mem_req} ${mem_usage_per}  ${mem_req_per}
    node_count=$((node_count + 1))
    total_per_cpu=$((total_per_cpu + cpu_req_per))
	total_per_mem=$((total_per_mem + mem_req_per))
   
done

avg_per_cpu_req=$((total_per_cpu / node_count))
avg_per_mem_req=$((total_per_mem / node_count))

avg_per_cpu_usage=$((total_per_cpu_usage / node_count))
avg_per_mem_usage=$((total_per_mem_usage / node_count))

printf '%0.1s' "-"{1..152}
printf "\n"

printf "Avg Usage: %s cpu %s mem\tAvg Allocated Req: %s cpu %s mem\n" "${avg_per_cpu_usage}%" "${avg_per_mem_usage}%" "${avg_per_cpu_req}%" "${avg_per_mem_req}%"

rm ${tmp_file}

