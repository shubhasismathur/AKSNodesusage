#!/bin/bash
# We can pass config file as parameter else default path will be picked
if [ -z ${1} ]
then
    export KUBECONFIG="`echo ~`/.kube/config"
else
    export KUBECONFIG="${1}"

fi

THRESDHOLD=80
NAMESPACE="-n default"
if [ -z  ${2} ]
then
    NAMESPACE="--all-namespaces"
    FILTER="namespace"
else
    NAMESPACE="-n ${2}"
    FILTER="${2}$"
fi

tmp_file="/tmp/log.k8s"
#kubectl get po --all-namespaces -o=jsonpath="{range .items[*]}{.metadata.namespace}|{.metadata.name}|{range .spec.containers[*]}|{.name}|{.resources.requests.cpu}|{.resources.requests.cpu}|{'\n'}{end}{'\n'}{end}"
function cpu_format
{
    input=$1
    if [[ `echo  $input |grep -c "m"` -eq 1 ]]
    then
        #printf "%.3f" $(echo $(echo ${input} |sed -e "s/m//g")/1000  |bc -l )
        v=`echo - |awk "{print $(echo ${input} |sed -e 's/m//g')/1000}"`
        printf "%.3f" ${v}
    elif [[ -z $input ]]
    then
        echo "0"
    else
        printf "%d" $input
    fi
}
function mem_format
{
    input=$1

    if [[ `echo  $input |egrep -c "M"` -eq 1 ]]
    then

        #printf "%.3f" $(echo $(echo ${input} |sed -e "s/Mi//g" -e "s/M//g")/1000  |bc -l )
        v=`echo - |awk "{print $(echo ${input} |sed -e 's/Mi//g' -e 's/M//g')/1000}"`
        printf "%.3f" ${v}
    elif [[ `echo  $input |grep -c "Gi"` -eq 1 ]]
    then
        #printf "%.3f" $(echo $(echo ${input} |sed -e "s/Gi//g")  |bc -l )
        v=`echo - |awk "{print $(echo ${input} |sed -e 's/Gi//g')}"`
        printf "%.3f" ${v}
    elif [[ `echo  $input |grep -c "Ki"` -eq 1 ]]
    then
        #printf "%.3f" $(echo $(echo ${input} |sed -e "s/Gi//g")  |bc -l )
        v=`echo - |awk "{print $(echo ${input} |sed -e 's/Ki//g')/1000000}"`
        printf "%.3f" ${v}
    elif [[ -z $input ]]
    then
        echo "0"
    else
        printf "%d" $input
    fi

}

total_cpu_req=0
total_cpu_limit=0
total_mem_req=0
total_mem_limit=0


declare -A nsCpuReq
declare -A nsCpuLimit
declare -A nsMemReq
declare -A nsMemLimit



for x in `kubectl get ns -o name |grep ${FILTER} | cut -d '/' -f2`
do
    nsCpuReq[$x]=0
    nsCpuLimit[$x]=0
    nsMemReq[$x]=0
    nsMemLimit[$x]=0
    #nsResource[$x]['cpu_limit']=0
done



format="|%40s|%40s|%25s|%7s|%7s|%7s|%10s|\n"

printf '%0.1s' "-"{1..144}
printf "\n"
printf "$format" "NameSpace" "Pod" "Container"  "CPU_REQ" "CPU_LMT" "MEM_REQ" "MEM_LMT"
printf '%0.1s' "-"{1..144}
printf "\n"



for x in `kubectl get po ${NAMESPACE}  -o=jsonpath="{range .items[*]}{.metadata.namespace}|{.metadata.name}{'\n'}{end}"`
do
    namespace=`echo $x|cut -d "|" -f1`
    pod_name=`echo $x|cut -d "|" -f2`

    for y in `kubectl get pod ${pod_name} -n ${namespace}  -o jsonpath="{range .spec.containers[*]}{.name}|{.resources.requests.cpu}|{.resources.limits.cpu}|{.resources.requests.memory}|{.resources.limits.memory}{'\n'}{end}"`
    do
        container_name=`echo $y|cut -d "|" -f1`
        cpu_request=`cpu_format $(echo $y|cut -d "|" -f2)`
        cpu_limit=`cpu_format $(echo $y|cut -d "|" -f3)`
        mem_request=`mem_format $(echo $y|cut -d "|" -f4)`
        mem_limit=`mem_format $(echo $y|cut -d "|" -f5)`

        #total_cpu_req=$(echo ${total_cpu_req} + ${cpu_request} |bc -l)
        total_cpu_req=`echo - |awk "{print ${total_cpu_req} + ${cpu_request}}"`

        #total_cpu_limit=$(echo ${total_cpu_limit} + ${cpu_limit}|bc -l)
        total_cpu_limit=`echo - |awk "{print ${total_cpu_limit} + ${cpu_limit}}"`

        #total_mem_req=$(echo ${total_mem_req} + ${mem_request} |bc -l)
        total_mem_req=`echo - |awk "{print ${total_mem_req} + ${mem_request}}"`
        #total_mem_limit=$(echo ${total_mem_limit} + ${mem_limit} |bc -l)
        total_mem_limit=`echo - |awk "{print ${total_mem_limit} + ${mem_limit}}"`

        #nsCpuReq[${namespace}]=$(echo ${nsCpuReq[${namespace}]} + ${cpu_request} |bc -l)
        nsCpuReq[${namespace}]=`echo - |awk "{print  ${nsCpuReq[${namespace}]} + ${cpu_request}}"`
        #nsCpuLimit[${namespace}]=$(echo ${nsCpuLimit[${namespace}]} + ${cpu_limit} |bc -l)
        nsCpuLimit[${namespace}]=`echo - |awk "{print  ${nsCpuLimit[${namespace}]} + ${cpu_limit}}"`
        #nsMemReq[${namespace}]=$(echo ${nsMemReq[${namespace}]} + ${mem_request} |bc -l)
        nsMemReq[${namespace}]=`echo - |awk "{print  ${nsMemReq[${namespace}]} + ${mem_request}}"`
        #nsMemLimit[${namespace}]=$(echo ${nsMemLimit[${namespace}]} + ${mem_limit} |bc -l)
        nsMemLimit[${namespace}]=`echo - |awk "{print  ${nsMemLimit[${namespace}]} + ${mem_limit}}"`
        printf "$format" ${namespace:0:15} ${pod_name:0:40} ${container_name:0:25} ${cpu_request} ${cpu_limit} ${mem_request} ${mem_limit}
        #echo "${namespace}|${pod_name}|${container_name}|${cpu_request}|${cpu_limit}|${mem_request}|${mem_limit}"
    done

done
printf '%0.1s' "-"{1..144}
printf "\n"
printf "$format" "Total" "" "" ${total_cpu_req} ${total_cpu_limit} ${total_mem_req} ${total_mem_limit}
printf '%0.1s' "-"{1..144}
printf "\n"
printf "$format" "NameSpace" "" ""  "CPU_REQ" "CPU_LMT" "MEM_REQ" "MEM_LMT"
printf '%0.1s' "-"{1..144}
printf "\n"

for x in `kubectl get ns -o name |grep ${FILTER} | cut -d '/' -f2`
do
    printf "$format" ${x:0:10} "" ""  ${nsCpuReq[$x]} ${nsCpuLimit[$x]} ${nsMemReq[$x]} ${nsMemLimit[$x]}

done

format="|%40s|%9s|%09b|%9b|%10b|%15s|%7s|%7s|%7s|%10s|\n"
printf '%0.1s' "-"{1..144}
printf "\n"
printf "$format" "Node" "CPU" "CPU_REQ%" "MEM_REQ%" "POD_CNT%" "Total Mem"  "CPU_REQ" "CPU_LMT" "MEM_REQ" "MEM_LMT"
printf '%0.1s' "-"{1..144}
printf "\n"
for x in `kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}|{.status.allocatable.cpu}|{.status.allocatable.memory}|{.status.allocatable.pods}{"\n"}{end}'`
do
    node=`echo $x |cut -d "|" -f1`
    cpu=`echo $x |cut -d "|" -f2`
    mem=`echo $x |cut -d "|" -f3`
    pods=`echo $x |cut -d "|" -f4`
    kubectl describe node $node > ${tmp_file}
    p_count=`cat ${tmp_file} |grep  "Non-terminated Pods:"  |grep -Eo '[0-9]+'`

    pod_count=$(printf "%.2f" `echo - |awk "{print ($p_count/$pods)*100 }"`)


    resource=`cat ${tmp_file}|grep -E -A 3 "Requests(.*)Limits$" |grep -E "cpu|memory" |tr -s " " |sed -e "s/cpu//" -e "s/memory//" |tr "\n" "|"`
    cpu_req=`cpu_format $(echo ${resource}|cut -d "|" -f1 |awk -F " " '{print $1}')`
    cpu_req_per=`echo ${resource}| cut -d "|" -f1 |awk -F "[()%]" '{print $2}'`
    if [[ $cpu_req_per -gt ${THRESDHOLD} ]]
    then
        cpu_req_per="      \e[1;31m${cpu_req_per}\e[0m"
    fi
    cpu_limit=`cpu_format $(echo ${resource}|cut -d "|" -f1 |awk -F " " '{print $3}')`
    mem_req=`mem_format $(echo ${resource}|cut -d "|" -f2 |awk -F " " '{print $1}')`
    mem_req_per=`echo ${resource}|cut -d "|" -f2 |awk -F "[()%]" '{print $2}'`
    if [[ $mem_req_per -gt ${THRESDHOLD} ]]
    then
        mem_req_per="      \e[1;31m${mem_req_per}\e[0m"
    fi
    mem_limit=`mem_format $(echo ${resource}|cut -d "|" -f2 |awk -F " " '{print $3}')`

    printf "$format" ${node} ${cpu} "${cpu_req_per}%" "${mem_req_per}%" "${pod_count}%" ${mem} ${cpu_req} ${cpu_limit} ${mem_req} ${mem_limit}
done
printf '%0.1s' "-"{1..144}
printf "\n"