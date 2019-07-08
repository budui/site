---
title: "可能是目前最简单方便的管理dotfiles的方法：使用裸Git仓库"
date: 2019-07-08T14:12:18+08:00
categories:
- 技术
tags:
- dotfiles
- 技巧
description: 
---

> 标题略有夸张，很多人都有独特的、适合自己的管理dotfiles的方案。本文无意诋毁其它方法，只是介绍一种仅仅依靠git就能优雅地管理dotfiles的方案。

不需要除git以外的工具、不需要文件链接、不会弄乱～文件夹、dotfiles的版本能被记录下来、甚至可以使用不同git分支方便不同电脑使用不同dotfiles，而且可以使用免费的github 私有repo备份dotfiles...你能想象吗？这么优秀的管理dotfiles的方案，只需要安装git，然后基于裸git仓库（bare git repository）就可以做到了！

基于裸git仓库管理dotfiles的思路很简单，使用git追踪所有关键的dotfiles。同时为了避免一大堆恼人的提示，如`$HOME`被识别为git仓库等等，使用了很多小技巧。下面来看看具体怎么做。

## 从头开始

现在你的家目录下已经有了很多你辛辛苦苦编辑的dotfiles，怎么开始用裸Git仓库管理它们呢？

首先在家目录下新建一个裸git仓库：

```bash
CONFIG_PATH=$HOME/.dfm
git init --bare $CONFIG_PATH
alias dfm="/usr/bin/git --git-dir $CONFIG_PATH --work-tree=$HOME"
```

上面几行命令的意思如下：

1. 定义这个裸Git仓库的git目录的存储位置，如果不特殊指定，git一般会使用`.git`文件夹保存git目录。这里替换掉`.git`的原因是不想让～目录被识别出git仓库。这里具体用啥名字不影响什么，但是为了和常见应用所使用的文件夹区分开来，使用了`.dfm`，你大可以改成`.hard_to_conflict`。不过最好别使用如`.config`的易冲突的名字
2. 初始化一个裸git仓库
3. 为了方便，定义一个alias。以后就可以使用`dfm`来替代带有一长串参数的`git`命令了。

新建完仓库后，你运行`dfm status`会发现git提示你`$HOME`下所有文件都没有添加到版本控制系统中。这很恼人，因为其实我们只需要管理某几个dotfiles。因此，接着运行下面的命令，以禁止git把所有`$HOME`下的文件都展示在untracked条目下。

```bash
dfm config --local status.showUntrackedFiles no
```

为了方便使用，我们可以把dfm这个alias放入`.bashrc`中，如果是zsh，则相应地放在`.zshrc`或者`$ZSH_CUSTOM`中。

```bash
echo "alias dfm='/usr/bin/git --git-dir=$HOME/.dfm/ --work-tree=$HOME'" >> $ZSH_CUSTOM/alias.zsh
```

好了，现在你就可以使用git那一套命令来管理dotfiles了。

```bash
dfm status
dfm add .vimrc
dfm commit -m "add .vimrc"
dfm add .bashrc
dfm commit -m "add .bashrc"
dfm push
...
```

为了备份dotfiles，可以新建一个github私有库，把dotfiles存到私有库中，以方便备份和迁移dotfiles。

## 迁移dotfiles

现在有一台新机器，我们怎么把dotfiles迁移到新机器上呢？

首先将裸仓库clone下来：

```bash
git clone --bare https://github.com/budui/dotfiles.git $HOME/.dfm
```

把上面的这行命令中的github链接换成你自己的位置。

在当前环境中新建一个alias：

```bash
alias dfm='/usr/bin/git --git-dir=$HOME/.dfm/ --work-tree=$HOME'
```

然后，checkout所有的dotfiles。

```bash
dfm checkout
```

上面这行命令一般都会报错：

```text
error: The following untracked working tree files would be overwritten by checkout:
	.zshrc
Please move or remove them before you can switch branches.
Aborting
```

这是因为你当前环境已经存在了一些dotfiles，checkout会覆盖掉你当前的dotfiles。怎么处理呢？很简单，如果当前环境的dotfiles还有用，你就改名备份它，如果没有用，你可以直接删除它。然后再checkout。

下面这行命令可供你使用：

```bash
mkdir -p dotfiles_backup && \
dfm checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | \
xargs -I{} mv {} dotfiles_backup/{}
```

这个命令会简单粗暴地把所有冲突的文件移动到`dotfiles_backup`中。

接着，运行下面的命令以禁止本地git显示untracked的文件：

```bash
dfm config --local status.showUntrackedFiles no
```

如果你保存的dotfiles中已经设置了`dfm`的alias，现在就搞完了！所有的dotfiles已经被拷贝到当前环境中。

当然，一般而言dotfiles中可能会有一些针对某个特定环境的内容，你可以使用git分支功能来保存各个环境的dotfiles。剩下的事情，就是看你熟悉不熟悉Git了！
