---
title: "怎么更改Windows下默认英文字体"
date: 2019-11-13T16:18:40+08:00
author: Ray Wong
---

Windows中文版默认英文字体为宋体，导致一些软件如Mendeley界面非常丑。

替换Windows下默认字体的方法如下：

1. 按下windows+R组合键打开**运行**；
2. 输入`regedit`并回车打开注册表管理器；
3. 打开注册表中的`[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\GRE_Initialize]`项；
4. 将`GUIFont.Facename`项更改为你喜欢的字体，如`Tahoma`或`Arial`;
5. 重启电脑
