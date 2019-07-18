---
title: "怎么给一个docker容器新开一个端口"
date: 2019-07-18T16:23:42+08:00
author: Ray Wong
---

实验室最近在拿docker当虚拟机用。这当然完全违逆了docker的使用准则，但是考虑到docker配合nvidia-docker能同时使用不同的深度学习环境，而且管理较为简单，所以最终还是把docker的容器当虚拟机来用。

这样做并非没有问题。这不，我今天就遇到一个正常使用docker时不会遇到的问题：怎么给一个使用中的docker容器新开一个端口？

按照docker的规矩，每个容器都应该能使用对应的镜像文件重新创建，但在实验室的使用场景中，每一个容器都来自于一个基础镜像，然后由各个同学各自装自己需要的依赖库，这导致从镜像是不能直接重建出正在运行的容器的。给一个docker容器新开一个端口，不能直接重新`docker run 镜像名 -p 8080:8080`，只能使用下面说的两种方法。

## 用正在运行的容器构建一个新镜像

假设你想新开端口的容器id为033e:

1. 停止运行`033e`

```bash
docker stop test01
```

2. commit这个容器

```bash
docker commit 033e new_image
```

这里用容器构建了一个新的镜像

3. 重新运行新镜像

```bash
docker run -p 8080:8080 <还有一大堆你需要的参数> new_image
```

这种方法最正统，但对我现在的使用场景，每个新构建的镜像都太大了。实在是感觉不太方便。

## 直接修改配置文件

首先提醒：

> 这个方法太**hardcore**了，请谨慎使用，使用前一定要搞清楚自己在做什么。还有一个明显的缺点：要退出docker进程。所有的正在运行的容器都会被停止。

1. 停止运行`033e`: `docker stop 033e`
2. 停止运行docker: `sudo systemctl stop docker`
3. 分别编辑修改对应容器的配置文件`hostconfig.json`和`config.v2.json` 中`PortBindings`和`ExposedPorts`两个选项。
4. 重新启动docker: `sudo systemctl start docker`
5. 重新启动容器: `docker container start 033e`

这个方法需要root权限，如果遇到权限问题，记住使用sudo或者用`sudo -i`切换到root账户运行。

注意`PortBindings`在`hostconfig.json`中，`ExposedPorts`在`config.v2.json`中，这两个配置文件都在`/var/lib/docker/containers/<conainerID>/`下。注意这里的containerID不止只有前几位，是完整的。但只靠前几位就能区分开来。

一个完整的`PortBindings`的例子如下：

```json
"PortBindings":{"22/tcp":[{"HostIp":"","HostPort":"50005"}],"8000/tcp":[{"HostIp":"","HostPort":"40005"}],"8080/tcp":[{"HostIp":"","HostPort":"30005"}]}
```

一个完整的`ExposedPorts`的例子：

```json
"ExposedPorts":{"22/tcp":{},"8000/tcp":{},"8080/tcp":{}}
```

修改时一定要注意这两个文件的JSON格式，括号逗号要写对。修改前最好备份这两个文件。
如果格式错误，docker启动后会忽视这个容器。
