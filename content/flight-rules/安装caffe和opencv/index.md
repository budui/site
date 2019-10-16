---
title: "安装caffe和opencv"
date: 2019-10-16T16:09:16+08:00
author: Ray Wong
---

现如今有了非常方便的PyTorch和Tensorflow，我们普遍觉得caffe很难安装。但如果只是使用最标准的caffe，没有新增加的layer的话，使用`conda`安装caffe也很简单。

下面就是我最近安装caffe和opencv时使用的命令，相当简单。

```bash
# 创建一个虚拟环境，使用python2
conda create -n caffe-python2 python=2.7
# 激活这个环境
conda activate caffe-python2
# 安装GPU版本的caffe，如果需要，CUDNN等等以来conda也会帮你装好
conda install -c defaults caffe-gpu
# 安装2.4版本的OpenCV
conda install -c https://conda.binstar.org/menpo opencv
```

不过，一般使用caffe时，基本都有一些caffe没有内置的layer，需要重新编译caffe。此时，又应该怎么安装caffe呢？

请继续关注本页面，等我黑眼圈消失了我就补上。