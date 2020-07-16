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

smarttool_ins(){
    if which smartctl  >/dev/null 2>&1; then
        return
    fi
    apt-get update
    apt-get install smartmontools -y
}

smarttool_ins

disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
if [[ ${disk_support} == 0 ]]; then
    printf "Type: Dual \t"
else 
    printf "Type: Single \t"
fi
# 版本信息，每次更新版本必须更改
printf "Version: v1.3-arm \n"
# 版本信息，每次更新版本必须更改

echowarn "状态 / Status: "
lvm_have=$(lvs 2>/dev/null | grep -q 'BonusVolGroup';echo $?)
[[ ${lvm_have} -eq 0  ]] && { echorun "0";}|| echorun "1"
printf "\t"

echowarn "已同步 / Synced: "
syncd="$(df -BG|grep "bonusvol"|awk '{sum += int($3)}; END {print sum}')"
[[ ${lvm_have} -eq 0 ]] && printf "${syncd} GB "
[[ ${lvm_have} -eq 0 ]] && echo -e "($(lvs|grep BonusVolGroup|grep bonusvol|awk '{sum += int($4)}; END {print ('${syncd}'/sum)*100}')%)"

echowarn "总空间 / Total: "
vgs_have=$(vgs | grep -q 'BonusVolGroup' ;echo $?)
used_space=$(vgdisplay | grep 'VG Size' | awk '{print $3,$4}' | sed -r 's/\i//g')
[[ ${vgs_have} -eq 0  ]] && printf "${used_space} \t\t"
[[ ${vgs_have} -eq 1  ]] && echowarn "--- \t\t"

echowarn "未分配空间 / Avail: "
free_space=$(vgdisplay | grep 'Free  PE / Size' | awk '{print $7,$8}' | sed 's/\i//g')
[[ ${lvm_have} -eq 0 ]] && printf "${free_space}"
printf "\n"

echowarn "CPU温度 / CPU temperature: "
kel_v=$(uname -r | grep -q 'aml' ;echo $?)
if [[ ${kel_v} == 0 ]]; then
    T3=$(cat /sys/class/hwmon/hwmon0/temp1_input | awk '{print int($1/1000)}')
else
    T3=$(cat /sys/class/thermal/thermal_zone0/temp | awk '{print int($1/1000)}')
fi
if [[ ${T3} < 65 ]]; then  
    echoinfo "${T3}°C \t"
else
    echoerr "${T3}°C \t"
fi

echowarn "任务 / Task: "
#任务显示
declare -A dict
# 任务类型字典
dict=([iqiyi]="A" [65544v]="B" [yunduan]="B" [65542v]="C" [65541v]="D" [65540v]="F")
[[ ${lvm_have} -eq 0  ]] && lvs_info=$(lvs 2>/dev/null | grep BonusVolGroup | grep bonusvol)
[[ ${lvm_have} -eq 0  ]] && lvlist=$(echo "$lvs_info" | awk '{print $1}' | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g' | sort -ru -k 1.4)
for lv in $lvlist; do
    TYPEs=${dict[$lv]}
    lvm_nums=$(echo "$lvs_info"|awk '{print $1}'|grep -c "$lv")
    lvm_size=$(echo "$lvs_info"|grep "$lv"|awk '{print $4}'|head -n 1|sed 's/\.00g//g')
    printf "${TYPEs}-${lvm_nums}-${lvm_size}\t"
done
printf "\n"

[[ ${lvm_have} -eq 0  ]] && lvs_info=$(lvs 2>/dev/null | grep BonusVolGroup | grep bonusvol)
[[ ${lvm_have} -eq 0  ]] && lvlist=$(echo "$lvs_info" | awk '{print $1}' | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g' | sort -ru -k 1.4)

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
            [[ ${vg_have} -eq 0 ]] && printf "${C1}TB / ${C2}B "
        else  
            [[ ${vg_have} -eq 0 ]] && printf "${C1}GB / ${C2}B "
        fi
    else
        echoerr "  --- "
        printf "/"
        echoerr " --- "
    fi
    [[ ${vg_have} -eq 1 ]] && C3=$(fdisk -l | grep "${sd}" | awk '{print int($3) $4}' | sed 's/\i//g' | sed 's/\,//g')
    [[ ${pv_have} -eq 0 && ${vg_have} -eq 1 ]] && echoerr "  --- " && printf "/ ${C3} "
    printf "\n"

    printf "│  类型 / Type\t 已使用 / Used\t 可用 / Avail\t 已用百分比 / Used%% \n"
    for lvms in $(lsblk ${sd} | awk '{print $1}' | sed -r 's#BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 1,2d | sed 's/iqiyi/65543v/' | cut -b 7-20); do
        titles=$(lsblk "${sd}" | grep "${lvms}" | awk '{print $1}' | cut -b 1-6)
        lvm_nam=$(lvs | awk '{print $1}' | grep "${lvms}" | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g')
        TYPE=${dict[${lvm_nam}]}
        echo -e "${titles}─${TYPE}${lvms:0-2:2} $(df -h | grep "${lvms}" | awk '{print "\t\t", $3, "\t\t", $4, "\t\t", $5}' | sed -r 's#/dev/mapper/BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 's/iqiyi/65543v/' | sort)"
    done
done
