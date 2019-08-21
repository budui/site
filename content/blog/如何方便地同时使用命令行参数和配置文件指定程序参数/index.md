---
title: "如何方便地同时使用命令行参数和配置文件指定程序参数"
date: 2019-08-16T14:45:07+08:00
categories:
- 技术
tags:
- 技巧
description: 介绍一种使用TOML格式作命令行参数值的方法，能同时使用命令行参数和配置文件指定程序参数
spotlight: true
---

最近在写深度学习代码，很头疼的一个问题是：代码中有很多需要经常调整的超参数，要能通过配置修改这些超参数，不能直接写死。

参数较少时，直接使用命令行参数指定就行了，灵活方便。但是，当参数量比较多时，命令行参数就不太合适了，主要有三个问题：

1. 命令行参数无法表达“层次”；

2. 每次运行时都需要指定一大堆命令行参数；

3. 新增参数需要预先指定，增加一行代码才能增加一个参数。

一个已经9300+star的项目[pytorch-CycleGAN-and-pix2pix](https://github.com/junyanz/pytorch-CycleGAN-and-pix2pix/tree/master/options)就是用命令行参数来指定配置。我们可以看下它的`options`文件夹:

```plaintext
options
├── base_options.py
├── __init__.py
├── test_options.py
└── train_options.py
```

由于参数量过大，而且一部分参数是共同的，这个项目还分为了三个文件，每个文件都指定了一大堆可能的参数。截取`train_options.py`中的一部分我们来看一下：

```python
parser = BaseOptions.initialize(self, parser)
# visdom and HTML visualization parameters
parser.add_argument('--display_freq', type=int, default=400, help='frequency of showing training results on screen')
parser.add_argument('--display_ncols', type=int, default=4, help='if positive, display all images in a single visdom web panel with certain number of images per row.')
parser.add_argument('--display_id', type=int, default=1, help='window id of the web display')
parser.add_argument('--display_server', type=str, default="http://localhost", help='visdom server of the web display')
parser.add_argument('--display_env', type=str, default='main', help='visdom display environment name (default is "main")')
parser.add_argument('--display_port', type=int, default=8097, help='visdom port of the web display')
parser.add_argument('--update_html_freq', type=int, default=1000, help='frequency of saving training results to html')
parser.add_argument('--print_freq', type=int, default=100, help='frequency of showing training results on console')
```

这些代码为了表现多个参数的相关关系，采用前缀的方法，所有`display`相关的参数都以`display`开头。这显然是因为**命令行参数无法表达“层次”**而做的妥协。指定时很不方便。同时我们也注意到，**每新增一个参数，都要在代码中显式指定**，即`add_argument`。不太适合炼丹时随时增加参数的使用场景。

说了这么命令行参数的坏话，那是不是使用如`yaml`, `ini`, `json`, `toml`...这样的配置文件就解决问题了呢？

先说配置文件能解决什么问题。使用一些如`yaml`,`json`这样表达能力比较强的配置文件时，配置终于有了层次，即可以生成如同`{"display":{"env": "main", "port":8097}}`这样的嵌套的字典。可以将某一部分的参数放在一起了。而运行时，直接指定使用哪个配置文件就可以，不需要指定一大堆参数。新增一个参数也可以直接在配置文件中加，不需要在代码中显式指定。我们前面说的命令行参数的三个问题得到了一定的解决。但是，使用配置文件并不是完美的。

使用配置文件，不管是什么格式(yaml/json/toml/ini...)，面临的一个统一问题是：不方便同时运行好几个程序实例。如果想测试某个参数对性能的影响，比如学习率，每个学习率都要写一个配置文件，然后将配置文件指定给程序，多个几乎完全一致的配置文件同时存在，很不优雅。

我们真正需要的配置解决方案，应该是**同时支持配置文件和命令行参数，配置文件指定默认参数，同时命令行可以单独修改配置文件中的某个参数的值**。

由于配置文件中，参数是嵌套着的，怎么用命令行参数来表达这个嵌套格式是个问题，总不能再专门写个转换函数将某个命令行参数转换为嵌套着的某个参数吧？

那怎么实现呢？这里介绍一种使用toml作为命令行参数格式的方法。

[toml](https://github.com/toml-lang/toml/blob/master/versions/cn/toml-v0.5.0.md)是一种语义明显且易于阅读的最小化配置文件格式，对空白符不敏感，不需要通过缩进等等表达层次。toml的具体格式可以参考[官方介绍]([toml](https://github.com/toml-lang/toml/blob/master/versions/cn/toml-v0.5.0.md))。

这里我们只用到了toml的一个特性：**点分隔键**（Dotted keys）。toml支持形如“`loss.weight.bias=10`”这样格式，对应的JSON为`{"loss":{"weight":{"bias":10}}}`，即只有单个值的嵌套的字典。

所以，利用点分割键，我们能使命令行参数表达“层次”。我们可以通过命令行参数，用点分割键指定要覆盖的原始配置。举个例子：

```bash
python mail.py -c ./path/to/config/file -t "loss.weight.bias=10" -t "title='hello, world'" -t "loss.type=['hello', 'world']"
```

其中`-t`被多次使用，这里后面的`-t`并没有被前面的`-t`所覆盖，与之相反，每个`-t`的值都会被保存到一个list中。我们可以多次指定要更改的参数。多次指定并存储配置这个功能python的官方库`argparse`已经支持：

```python
parser.add_argument("-t", "--toml", type=str, action="append")
```

只需要制定`argumnet`的`action`为`append`，最后程序获取到的参数就为一个列表：

```python
["loss.weight.bias=10", "title='hello, world'", "loss.type=['hello', 'world']"]
```

将这个列表拼成一个字符串后再作为toml文件解析，即可得到下面这个嵌套的字典：

```python
{
    'loss': {
        'weight': {
            'bias': 10
        }, 
        'type': ['hello', 'world']
    }, 
    'title': 'hello, world'
}
```

接着，再用这个字典更新从配置文件中读取到的字典即可。

最终全部代码如下：

```python
import toml
from argparse import ArgumentParser
from os import path

import collections

# python 3.8+ compatibility
try:
    collectionsAbc = collections.abc
except:
    collectionsAbc = collections

def update(d, u):
    for k, v in u.items():
        dv = d.get(k, {})
        if not isinstance(dv, collectionsAbc.Mapping):
            d[k] = v
        elif isinstance(v, collectionsAbc.Mapping):
            d[k] = update(dv, v)
        else:
            d[k] = v
    return d

def load_config(config_path):
    print("reading config from <{}>\n".format(path.abspath(config_path)))
    try:
        with open(config_path, "r") as f:
            config = toml.load(f)
            return config
    except FileNotFoundError as e:
        print("can not find config file")
        raise e


def parse_argument():
    parser = ArgumentParser("Train")
    parser.add_argument("-c", "--config", type=str, help="config file path", required=True)
    parser.add_argument("-t", "--toml", type=str, action="append")
    options = parser.parse_args()
    return options

def main():
    options = parse_argument()
    config = load_config(options.config)
    print(config)
    
    if options.toml is not None:
    	tomls = "\n".join(options.toml)
    	new_config = toml.loads(tomls)
    	print(new_config)
    	print(update(config, new_config))

if __name__ == "__main__":
    main()
```

注意，对于一些如GPU编号、输出文件夹这种每次运行程序肯定不一样的参数，我依然选择了用命令行参数指定，而非配置文件。这样可以继续利用命令行参数简单灵活的优势。我的项目[Human-Pose-Transfer](https://github.com/budui/Human-Pose-Transfer/blob/master/run.py)就是本篇文章的一个很好的实践。可以参考一下～