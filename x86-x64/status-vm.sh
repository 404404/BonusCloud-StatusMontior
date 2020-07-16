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
        OS=$(lsb_release -is)
        OS_CODENAME=$(lsb_release -cs)
        return 
    fi
    source /etc/os-release
    case $ID in
        Debian ) 
            OS="Debian"
            if [[ $VERSION_CODENAME != "" ]]; then
                OS_CODENAME=$VERSION_CODENAME
            else
                OS_CODENAME=$(echo "$VERSION"|sed -e 's/(//g' -e 's/)//g'|awk '{print $2}')
            fi
            ;;
        Centos ) OS="Centos" ;;
        *       ) OS="$ID"

    esac
}

#任务显示
declare -A dict
# 任务类型字典
dict=([iqiyi]="A" [65544]="B" [yunduan]="B" [65542v]="C" [65541v]="D" [65540v]="F")
#获取系统盘符，应对系统盘不是sda的情况
root_type=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $(NF-1)}')
root_name=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $1}')
root_disk=""
if [ x"${root_type}" == x"lvm" ];then
    root_vg_name=$(echo ${root_name} | awk -F- '{print $1}')
    root_disk=$(pvs 2>>/dev/null | grep ${root_vg_name} | awk '{print $1}' | sed 's/[0-9]//;s/\/dev\///')
else
    root_disk=$(lsblk -ar 2>>/dev/null | grep -w "/" | awk '{print $1}' | sed 's/[0-9]//')
fi

sys_osname
printf "OS name: ${OS} \t Type: "
disk_support=$(cat /lib/systemd/system/bxc-node.service | grep -q 'devoff' ;echo $?)
lvm_have=$(lvs 2>/dev/null | grep -q 'BonusVolGroup';echo $?)
vg_have=$(vgs 2>/dev/null | grep -q 'BonusVolGroup';echo $?)
if [[ ${disk_support} == 0 ]]; then
    printf "Dual \t"
else 
    printf "Single \t"
fi
# 版本信息，每次更新版本必须更改
printf " Version: v1.3-vm \n"
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

echowarn "任务 / Task: "
[[ ${lvm_have} -eq 0  ]] && lvs_info=$(lvs 2>/dev/null | grep BonusVolGroup | grep bonusvol)
[[ ${lvm_have} -eq 0  ]] && lvlist=$(echo "$lvs_info" | awk '{print $1}' | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g' | sed 's/65544v/yunduan/' | sort -ru -k 1.4)
for lv in $lvlist; do
    TYPEs=${dict[$lv]}
    lvm_nums=$(echo "$lvs_info"|awk '{print $1}'|grep -c "$lv")
    lvm_size=$(echo "$lvs_info"|grep "$lv"|awk '{print $4}'|head -n 1|sed 's/\.00g//g')
    printf "${TYPEs}-${lvm_nums}-${lvm_size}\t"
done
printf "\n"

roots_disk=$(ls /dev/* | grep "${root_disk}" | sed -n 1p)
smarts=$(smartctl -d sat -a "${roots_disk}")
echoinfo "${roots_disk} \t"
R0=$(echo "$smarts" | grep 'User Capacity' | awk '{print $5 $6}' | sed -r 's#\[##g' | sed -r 's#\]##g')
if [[ ${disk_support} == 0 ]]; then 
    root_pv=$(pvs 2>/dev/null | grep -q "${roots_disk}" ;echo $?)
    root_vg=$(pvs 2>/dev/null | grep "${roots_disk}" | grep -q "BonusVolGroup" ;echo $?)
    if [[ ${root_pv} == 0 && ${root_vg} == 0 ]]; then
        R1=$(lsblk ${roots_disk} | grep "BonusVolGroup-bonusvol" | awk 'BEGIN {sum = 0} {sum += $5} END {print sum}')
        R2=$(pvs 2>/dev/null | grep "${roots_disk}" | awk '{print $6}' | sed -r 's/\.[0-9][0-9]//g' | tr 'a-z' 'A-Z')
        if [[ ${R1} > 999 ]]; then
            R1=$(${R1} / 1000)
            printf "${R0} - ${R1}TB / ${R2}B"
        else  
            printf "${R0} - ${R1}GB / ${R2}B"
        fi
        echoinfo "\t root disks \n"
        printf "│  类型 / Type\t 已使用 / Used\t 可用 / Avail\t 已用百分比 / Used%% \n"
        for lvms in $(lsblk "${roots_disk}" | grep "BonusVolGroup-bonusvol" | awk '{print $2}' | sed -r 's#BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g'| sed 's/iqiyi/65543v/' | cut -b 7-20); do
            titles=$(lsblk "${roots_disk}" | grep "${lvms}" | awk '{print $2}' | cut -b 1-6)
            lvm_nam=$(lvs | awk '{print $1}' | grep "${lvms}" | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g' | sed 's/65544v/yunduan/')
            TYPE=${dict[${lvm_nam}]}
            echo -e "${titles}─${TYPE}${lvms:0-2:2} $(df -h | grep "${lvms}" | awk '{print "\t\t", $3, "\t\t", $4, "\t\t", $5}' | sed -r 's#/dev/mapper/BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 's/iqiyi/65543v/' | sort)"
        done
    else
        echoinfo "\t root disks \n"
        lsblk "${roots_disk}" | awk '{print $1}' | sed 1,2d
    fi
fi

for sd in $(ls /dev/* | grep -E '((sd)|(vd)|(hd)|(nvme))[a-z]$' | grep -v "${root_disk}" | sort); do
    smartinfo=$(smartctl -d sat -a "${sd}")
    pv_have=$(pvs 2>/dev/null | grep -q "${sd}" ;echo $?)
    vg_have=$(pvs 2>/dev/null | grep "${sd}" | grep -q "BonusVolGroup" ;echo $?)
    I1=$(echo "$smartinfo" | grep 'User Capacity' | awk '{print $5 $6}' | sed -r 's#\[##g' | sed -r 's#\]##g')

    echoinfo "${sd} \t"
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
        lvm_nam=$(lvs | awk '{print $1}' | grep "${lvms}" | sed -r 's#bonusvol([A-Za-z0-9]+)[0-9]{2}#\1#g' | sed 's/65544v/yunduan/')
        TYPE=${dict[${lvm_nam}]}
        echo -e "${titles}─${TYPE}${lvms:0-2:2} $(df -h | grep "${lvms}" | awk '{print "\t\t", $3, "\t\t", $4, "\t\t", $5}' | sed -r 's#/dev/mapper/BonusVolGroup-bonusvol([A-Za-z0-9])#\1#g' | sed 's/iqiyi/65543v/' | sort)"
    done
done