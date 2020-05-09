#!/usr/bin/env bash

# Base on: https://github.com/BonusCloud/BonusCloud-Node
# Special thanks to qinghon https://github.com/qinghon

echoerr() { 
    printf "\033[1;31m$1\033[0m" 
}
echoinfo() { 
    printf "\033[1;32m$1\033[0m"
}
echowarn() { 
    printf "\033[1;33m$1\033[0m"
}
echorun() {
    case $1 in
        "1" ) echoerr "未调度 / Not Running\t" ;;
        "0" ) echoinfo "已调度 / Running\t";;
    esac
}

sys_osname(){
    if  which lsb_release >/dev/null  2>&1; then
        OS=$(lsb_release -is|tr '[A-Z]' '[a-z]')
        OS_CODENAME=$(lsb_release -cs|tr '[A-Z]' '[a-z]')
        return 
    fi
    source /etc/os-release
    case $ID in
        ubuntu )
            OS="Ubuntu" 
            ;;
        debian ) 
            OS="Debian"
            ;;
        raspbian )
            OS="Raspbian"
            ;;
        centos ) OS="Centos" ;;
        *       ) OS="$ID"
    esac
}

_check_pg(){
    # Detection package manager
    if which apt >/dev/null 2>&1 ; then
        # echoinfo "Find apt\n"
        PG="apt"
    elif which yum >/dev/null 2>&1 ; then
        # echoinfo "Find yum\n"
        PG="yum"
    elif which pacman>/dev/null 2>&1 ; then
        # log "[info]" "Find pacman"
        PG="pacman"
    else
        log "[error]" "\"apt\" or \"yum\" ,not found ,exit "
        exit 1
    fi
}

smarttool_ins(){
    if which smartctl  >/dev/null 2>&1; then
        return
    fi
    case $PG in
        apt|yum ) $PG install smartmontools -y ;;
        pacman ) $PG --needed --noconfirm -S smartmontools ;;
    esac
}

smarttool_ins

sys_osname
printf "系统名称为 / The system name is： ${OS}"

echowarn "\n\n中央处理器温度 / CPU temperature:   "
T3=$(cat /sys/class/thermal/thermal_zone0/temp | awk '{print int($1/1000)}')
if [[ ${T3} < 65 ]]; then  
    echoinfo "${T3}°C"
else
    echoerr "${T3}°C"
fi

echowarn "\n\n运行进程和使用情况 / Progress and usage:  "
lvm_have=$(lvs 2>/dev/null|grep -q 'BonusVolGroup';echo $?)
[[ ${lvm_have} -eq 0  ]] && { echorun "0";}|| echorun "1"
[[ ${lvm_have} -eq 1  ]] && printf "\n"

[[ ${lvm_have} -eq 0  ]] &&echowarn "\n已同步数据 / Synced data:  "
[[ ${lvm_have} -eq 0  ]] &&syncd="$(df -BG|grep "bonusvol"|awk '{sum += int($3)}; END {print sum}')"
[[ ${lvm_have} -eq 0  ]] &&echoinfo "${syncd} GB "
[[ ${lvm_have} -eq 0  ]] &&echo -e "($(lvs|grep BonusVolGroup|grep bonusvol|awk '{sum += int($4)}; END {print ('${syncd}'/sum)*100}')%)"

[[ ${lvm_have} -eq 0  ]] &&echowarn "已分配空间 / Allocated space:  "
[[ ${lvm_have} -eq 0  ]] &&lvm_used="$(vgdisplay | grep 'Alloc PE / Size' | awk '{print $7,$8}' | sed 's/\i//g')"
[[ ${lvm_have} -eq 0  ]] &&echoinfo "${lvm_used}   "

[[ ${lvm_have} -eq 0  ]] &&echowarn "\n未分配空间 / Free space:  "
[[ ${lvm_have} -eq 0  ]] &&free_space=$(vgdisplay | grep 'Free  PE / Size' | awk '{print $7,$8}' | sed 's/\i//g')
[[ ${lvm_have} -eq 0  ]] &&echoinfo "${free_space}\n\n"

#任务显示
declare -A dict
# 任务类型字典
dict=([iqiyi]="A" [yunduan]="B" [65542v]="C" [65541v]="D" [65540v]="F")

[[ ${lvm_have} -eq 0  ]] &&lvs_info=$(lvs 2>/dev/null|grep BonusVolGroup|grep bonusvol)
[[ ${lvm_have} -eq 0  ]] &&lvlist=$(echo "$lvs_info"|awk '{print $1}'|sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g'|sort -ru -k 1.4)
[[ ${lvm_have} -eq 0  ]] &&echowarn "───────────────────────────────────────────────\n"
[[ ${lvm_have} -eq 0  ]] &&echowarn "| 任务属性\t 已使用\t   可用\t   已用百分比 | \n"
[[ ${lvm_have} -eq 0  ]] &&echowarn "|  Type   \t Used  \t   Avail      Used%%   |\n"
[[ ${lvm_have} -eq 0  ]] &&echowarn "───────────────────────────────────────────────\n"

for lv in $lvlist; do
    TYPE=${dict[$lv]}
    lvm_num=$(echo "$lvs_info"|awk '{print $1}'|grep -c "$lv")
    lvm_size=$(echo "$lvs_info"|grep "$lv"|awk '{print $4}'|head -n 1|sed 's/\.00g//g')
    printf "| "
    echoinfo "${TYPE}-${lvm_num}-${lvm_size}GB \t     \t \t     \t      "
    printf "| \n"
    echo -e "$(df -h |grep "bonusvol$lv" | awk '{print "|", $1, "  \t ", $3, "\t  ", $4, " \t ", $5, "|"}' | sed -r 's#/dev/mapper/BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g')"
    echowarn "───────────────────────────────────────────────\n"
done

echowarn "\n硬盘信息 / Hard Drive Information: \n"
for sd in $(ls /dev/*|grep -E '((sd)|(vd)|(hd))[a-z]$'); do
    smartinfo=$(smartctl -d sat -a "${sd}")
    I1=$(echo "$smartinfo" | grep 'User Capacity' | awk '{print $5 $6}')
    T1=$(echo "$smartinfo"| grep 194 | awk '{print $10}')
    echoinfo "${sd}   ${I1}   "
    if [[ ${T1} < 60 ]]; then 
        echoinfo "${T1}°C   "
    else
        echoerr "${T1}°C   "
    fi
    smart_test=$(echo "$smartinfo" | grep 'SMART overall-health self-assessment test result' | awk '{print $6}')
    if [[ ${smart_test} == "PASSED" ]]; then 
        echoinfo "通过 / Passed \n"
    else
        echoerr "警告 / Waning \n"
    fi 
    lsblk -b $sd | awk '{print $1}' | sed -r 's#BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 1,2d
done
