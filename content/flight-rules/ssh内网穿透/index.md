---
title: "ssh内网穿透"
date: 2019-07-21T18:48:36+08:00
author: Ray Wong
---

这种方法需要有一台公网中的VPS。

将三台机器描述如下：

| 机器代号 | 网络位置描述 | 地址 | 账户 | 端口 | 运行程序 |
|:--------:|:--------------------------------:|:-----------------:|:----:|:----------:|:--------:|
| server | 内网或者防火墙后，只能主动连外网 | localhost | user | 22 | autossh |
| VPS | 有一个公网IP，公网双向可用 | lowentropy.me | rp | 2201, 2200 | sshd |
| PC | 自己的电脑，能访问到VPS |  |  |  | ssh |

我们的目标很简单：**在PC端使用ssh，以VPS作为跳板，连接内网中的服务器server**。

分别描述在三台机器上需要做的操作：

## vps

为了安全，创建一个专门用于端口转发的用户。这个用户不需要具有执行命令的权限。

```bash
# 增加一个新用户rp，rp只是一个名字，随便你怎么起，不是已有用户就行
sudo useradd -m rp
# 设定这个用户的密码
# 因为我这台vps禁止使用密码登录，不设密码应该也没什么，我只是顺手添加的。后面也不需要用到这个密码
sudo passwd rp
# 禁止新用户rp执行命令的权限
sudo chsh -s /bin/false rp
```

注释里提到了，这台vps我只允许秘钥登录，因此要给新用户rp添加`authorized_keys`。

```bash
# 首先生成一个秘钥
# 这个秘钥为了方便最好不要设置密码
# 按照提示指定秘钥文件
ssh-keygen -t rsa
# 添加authorized_keys
# 注意把cat后面替换为你生成的公钥的位置
cat {公钥位置} > /home/rp/.ssh/authorized_keys
```

给用户rp添加`authorized_keys`的方法很多，无论你怎么搞，最终目的都是将公钥内容复制到`~/.ssh/authorized_keys`中。

## server

首先在server上安装`autossh`。如果是Ubuntu，安装命令就是`apt install autossh`。

接着将刚才生成的私钥拷贝到server上。

运行

```bash
# -M指定的 2200 是autossh使用的监听端口，随便指定一个你的vps开放的端口就行。
# 2201 是你在vps上连接server的本地端口，依旧是你随便指定
# 22 就是server的sshd监听端口，一般就是22了。
autossh -M 2200 -NR 2201:localhost:22 rp@lowentropy.me -i {私钥位置} -p 2222

# 22以后的东西其实就是你在server上连接vps的命令
# 比如上面这一行，我首先指定了私钥位置，使用私钥登录，又用-p指定了连接vps的端口，（一般其实是22，不需要专门指定，只不过我改过我的vps端口）
```

需要的时候可以设置自动运行这个命令。

运行后，实际上只有你的VPS可以ssh连到server，不直接把server端口暴露到公网中是基本常识了。（其实我很担心实验室某些同学设置的内网穿透，能把整个内网都暴露在公网中，简直害人。）

## PC

将刚才生成的私钥拷贝到PC上。

在自己的ssh config中添加下面两项：

```ini
Host vps
        HostName lowentropy.me
        User rp
        Port 2222
        IdentityFile /home/budui/.ssh/rp_id_rsa
Host server
        HostName 127.0.0.1
        User user
        Port 2201
        ProxyCommand ssh -q -W %h:%p vps
```

`vps`这一项就是你连接vps使用的配置。server这一项是指你登陆到vps后，你连接server的操作。`ProxyCommand`表示使用vps做一次跳板。