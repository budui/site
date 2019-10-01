---
title: "Manjaro I3连接蓝牙耳机"
date: 2019-10-01T11:07:58+08:00
author: Ray Wong
---

manjaro i3版本默认安装了 blueman 系列软件。其中：

* `blueman-manager` 可以选择连接蓝牙设备
* `blueman-adapters` 可以修改蓝牙名等本机蓝牙设置

但是，刚装好系统时，我尝试连接蓝牙耳机，一直提示错误：

> Bluetooth: "protocol not available"

查询后按照[这里](https://bbs.archlinux.org/viewtopic.php?id=222083)的解决方案解决了该问题：

1. 安装 pulseaudio-bluetooth: `sudo pacman -S pulseaudio-bluetooth`
2. 编辑`/etc/bluetooth/main.conf`文件，在该文件`[General]`项后添加一行`Enable=Source,Sink,Media,Socket`
3. 重启

我没有再继续查询背后的知识，先用起来再说。着急看国庆阅兵～
