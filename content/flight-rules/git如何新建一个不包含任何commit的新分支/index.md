---
title: "Git如何新建一个不包含任何commit的新分支"
date: 2019-11-16T09:23:12+08:00
author: Ray Wong
---

偶尔有这么一个奇怪的需求：新建一个不包含任何commit的git分支。比如你使用*GitHub Pages*，需要新增一个gh-pages分支，由于这个分支只需要一些HTML/CSS/JS，就需要新建一个不包含任何commit的新分支。

具体做法如下：

```bash
# 新建名为empty-branch的新分支
git checkout --orphan empty-branch
# 新建完分支后你原来的文件都还在，只不过没有被添加到git commit中罢了
# 用下面的命令删掉它们
git reset --hard
# 如果需要push到远程仓库，就执行下面的命令
git push origin empty-branch
```