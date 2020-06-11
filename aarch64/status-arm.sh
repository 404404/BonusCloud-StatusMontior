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

disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
if [[ ${disk_support} == 0 ]]; then
    printf "Type: Dual \n"
else 
    printf "Type: Single \n"
fi

echowarn "CPU温度 / CPU temperature: \t"
kel_v=$(uname -r | grep -q 'aml' ;echo $?)
if [[ ${kel_v} == 0 ]]; then
    T3=$(cat /sys/class/hwmon/hwmon0/temp1_input | awk '{print int($1/1000)}')
else
    T3=$(cat /sys/class/thermal/thermal_zone0/temp | awk '{print int($1/1000)}')
fi
if [[ ${T3} < 65 ]]; then  
    echoinfo "${T3}°C \n"
else
    echoerr "${T3}°C \n"
fi

echowarn "总缓存空间 / Total cache space: "
vgs_have=$(vgs | grep -q 'BonusVolGroup' ;echo $?)
free_space=$(vgdisplay | grep 'VG Size' | awk '{print $3,$4}' | sed -r 's/\i//g')
[[ ${vgs_have} -eq 0  ]] && echoinfo "${free_space} \t "
[[ ${vgs_have} -eq 1  ]] && echowarn "运行hdd.sh后重试 / run hdd.sh and try again \t "

lvm_have=$(lvs 2>/dev/null | grep -q 'BonusVolGroup';echo $?)
[[ ${lvm_have} -eq 0  ]] && { echorun "0";}|| echorun "1"
printf "\n"

#任务显示
declare -A dict
# 任务类型字典
dict=([iqiyi]="A" [yunduan]="B" [65542v]="C" [65541v]="D" [65540v]="F")

[[ ${lvm_have} -eq 0  ]] && lvs_info=$(lvs 2>/dev/null | grep BonusVolGroup | grep bonusvol)
[[ ${lvm_have} -eq 0  ]] && lvlist=$(echo "$lvs_info" | awk '{print $1}' | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g' | sort -ru -k 1.4)
[[ ${lvm_have} -eq 0  ]] && printf "─────────────────────────────────────────────────────────────────────\n"
[[ ${lvm_have} -eq 0  ]] && echowarn " 任务属性\t\t 已使用\t\t 可用 \t\t  已用百分比\n"
[[ ${lvm_have} -eq 0  ]] && echowarn "  Type   \t\t  Used \t\t Avail\t\t   Used%%  \n"
[[ ${lvm_have} -eq 0  ]] && printf "─────────────────────────────────────────────────────────────────────\n"

for lv in $lvlist; do
    TYPE=${dict[$lv]}
    lvm_num=$(echo "$lvs_info" | awk '{print $1}' | grep -c "$lv")
    lvm_size=$(echo "$lvs_info" |grep "$lv" | awk '{print $4}' | head -n 1 | sed 's/\.00g//g')
    echoinfo " ${TYPE}-${lvm_num}-${lvm_size}GB \n"
    echo -e "$(df -h | grep "bonusvol$lv" | awk '{print " ├─", $1, "\t\t", $3, "\t\t", $4, "\t\t   ", $5}' | sed -r 's#/dev/mapper/BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 's/iqiyi/65543v/' | sort)"
    printf "─────────────────────────────────────────────────────────────────────\n"
done

for sd in $(fdisk -l | grep -E 'Disk /dev/((sd)|(vd)|(hd))' | sed 's/Disk //g' | sed 's/\://g' | awk '{print $1}' | sort); do
    smartinfo=$(smartctl -d sat -a "${sd}")
    pv_have=$(pvs 2>/dev/null | grep -q "${sd}" ;echo $?)
    vg_have=$(pvs 2>/dev/null | grep "${sd}" | grep -q "BonusVolGroup" ;echo $?)
    temp_have=$(echo smartctl -d sat -a "${sd}" | grep -q "194 Temperature_Celsius" ;echo $?)
    I1=$(echo "$smartinfo" | grep 'User Capacity' | awk '{print $5 $6}' | sed -r 's#\[##g' | sed -r 's#\]##g')
    T1=$(echo "$smartinfo" | grep '194 Temperature_Celsius' | awk '{print $10}' | sed 2d)

    echoinfo "${sd}     "
    if [[ ${T1} < 60 ]]; then 
        echoinfo "${T1}°C     "
    else
        echoerr "${T1}°C     "
    fi

    [[ ${pv_have} -eq 0 ]] && C1=$(lsblk ${sd} | sed '1,2d' | awk 'BEGIN {sum = 0} {sum += $4} END {print sum}')
    [[ ${pv_have} -eq 0 ]] && C2=$(pvs 2>/dev/null | grep "${sd}" | awk '{print $6}' | sed -r 's/\.[0-9][0-9]//g' | tr 'a-z' 'A-Z')
    printf "${I1} - "
    if [[ ${pv_have} == 0 ]]; then 
        if [[ ${C1} > 999 ]]; then
            C1=$(${C1} / 1000)
            [[ ${vg_have} -eq 0 ]] && printf " ${C1}TB / ${C2}B "
        else  
            [[ ${vg_have} -eq 0 ]] && printf " ${C1}GB / ${C2}B "
        fi
    else
        echoerr "  --- "
        printf "/"
        echoerr " --- "
    fi
    [[ ${vg_have} -eq 1 ]] && C3=$(fdisk -l | grep "${sd}" | awk '{print int($3) $4}' | sed 's/\i//g' | sed 's/\,//g')
    [[ ${pv_have} -eq 0 && ${vg_have} -eq 1 ]] && echoerr "  --- " && printf "/ ${C3} "
    printf "\n"

    lsblk ${sd} | awk '{print $1}' | sed -r 's#BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 1,2d | sed 's/iqiyi/65543v/'
done
