---
title: "查看linux服务器开放端口"
date: 2019-07-30T12:56:38+08:00
author: Ray Wong
---

很多命令都可以查看当前开发的端口

## netstat

```bash
sudo netstat -tulpn | grep LISTEN
```

* **-t**: 所有TCP端口
* **-u**: 所有UDP端口
* **-l**: 显示正在监听中的socket
* **-p**: 显示socket对应的程序名字、PID
* **-n**: 不需要解析名字

## ss

```bash
sudo ss -tulpn
```

## lsof

```bash
sudo lsof -i -P -n | grep LISTEN
```

## nmap

```bash
sudo nmap -sT -O localhost
```

实际用起来，感觉`ss`输出信息比较直观。
