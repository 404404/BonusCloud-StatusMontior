# BonusCloud-StatusMontior

代码节选自：https://github.com/BonusCloud/BonusCloud-Node

Code excerpt from https://github.com/BonusCloud/BonusCloud-Node

----------------------------------------------------------------------------------------------------------------------

硬盘smart检测部分来自smartmontools (https://www.smartmontools.org/) ，需要在系统中先安装smartmontools。
同时目前脚本设定中，运行smartctl时均按照SATA磁盘处理，如果使用非SATA接口磁盘可能无法正确读取信息。

Hard drive smart detection part comes from smartmontools (https://www.smartmontools.org/), smartmontools need to be installed first.
At the same time, in the current script settings, when smartctl is run, it is processed according to the SATA disk. The information may not be read correctly if non-SATA interface disk is included in the system.

----------------------------------------------------------------------------------------------------------------------

x86-x64是针对电脑或服务器使用的，结尾带PM表示用于物理机，结尾带VM的表示用于虚拟机
aarch64是针对基于ARMv8架构的64位开发板设备，目前测试通过的主控为 瑞芯微 RK3328(我家云/粒子云) 和 晶晨 S905D(N1)

x86-x64 is used on computers or servers, with a PM ending for physical machines and a VM ending for virtual machines.
aarch64 is a 64-bit development board device based on ARMv8 architecture. Currently, the devices which has RockChip RK3328(ChainedBox) and Amlogic S905D(PHICOMM N1) on board have alrady passed the test.
