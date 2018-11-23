---
title: 《Disentangled Person Image Generation》论文理解
date: 2018-11-18T21:33:51+08:00
draft: true
description: Synthesize person images, while independently controlling foreground, background, and pose, in a self-supervised way.
categories:
- 学术
tags:
- Person Re-Identification
- 论文笔记
---

| title  | Disentangled Person Image Generation                                                  |
| ------ | :------------------------------------------------------------------------------------ |
| from   | CVPR2018 [spotlight](https://www.youtube.com/watch?v=vy2KgNdVRfo)                     |
| author | Liqian Ma, Qianru Sun, Stamatios Georgoulis, Luc Van Gool, Bernt Schiele, Mario Fritz |
| arxiv  | [1712.02621](https://arxiv.org/abs/1712.02621)                                        |

## 速览(翻译自作者的介绍[^intro])

**Motivation**:训练一个能明确表示前景，背景和姿势的图片生成模型

**Task**:以自监督学习方式，独立控制前景，背景和姿势生成，合成人类图片

**Key idea**:先将图片分解为上述三个部分，然后再融合起来。

**Contributions**:

1. 提出了一种通过将输入划分为弱相关因素的生成人物图像新任务。
2. 设计出一种两阶段的框架来学习可操作的嵌入特征(embedding features)
3. 创造了一种通过对抗训练(adversarial training)来匹配真假嵌入特征分布的技术
4. 贡献了一种生成re-ID任务图像对的方法

[^intro]:[Paper Project Page](https://homes.esat.kuleuven.be/~liqianma/CVPR18_DPIG/)