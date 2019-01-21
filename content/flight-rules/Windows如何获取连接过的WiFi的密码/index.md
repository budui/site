---
title: "Windows 如何获取连接过的WiFi的密码"
date: 2019-01-21T20:18:03+08:00
author: Ray Wong
---

1. 打开cmd(win+r输入cmd)
2. 输入以下命令：`netsh wlan show profile WiFi名字 key=clear`，注意把WiFi名字部分替换为你想知道密码的WiFi名。
3. 输出的内容中，`安全设置->关键内容` 就是WiFi密码。

当然，当你因为记性不好，需要查看已经连过的WiFi的密码时，你可能同时因为记性，记不起正确的WiFi名字。你可以通过`netsh wlan show profile`这条命令查看本机连接过的所有WiFi。

下面这一行命令是上面两条命令的组合，可以输出所有连接过的WiFi密码。

```cmd
for /f "skip=9 tokens=1,2 delims=:" %i in ('netsh wlan show profiles') do  @echo %j | findstr -i -v echo | netsh wlan show profiles %j key=clear
```