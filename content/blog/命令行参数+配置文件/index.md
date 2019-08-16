---
title: "命令行参数+配置文件"
date: 2019-08-16T14:45:07+08:00
categories:
- 技术
tags:
- 技巧
description: 使用TOML格式的配置文件，可以用命令行参数覆盖配置文件中的值
---

深度学习代码中有很多超参数，需要经常调整。而程序读取配置目前主要有两种主流方法：配置文件或者命令行参数。这两种方法各有优劣。

一般而言，命令行参数比较适合参数量较少的情况，灵活而方便。但对于参数比较多，参数的层次很多的情况，这种配置方法很不直观。比如[Pose-Transfer](https://github.com/tengteng95/Pose-Transfer/blob/master/options/base_options.py)这个项目，基础选项就有30多个，很难懂。

如果使用配置文件，不管是什么格式(yaml/json/toml/ini...)，面临的一个统一问题就是：不方便同时运行好几个程序。如果想测试某个参数对性能的影响，比如学习率，每个学习率都要写一个配置文件，然后将配置文件指定给程序，多个基本重复的配置文件同时存在，很不优雅。

如果程序可以从参数配置文件中读取参数作为“默认”，同时也可以从命令行单独指定某个参数的值就好了！怎么实现呢？这里介绍一种使用toml作为命令行参数格式的方法。

一般而言，不管是什么配置格式，都可以转换为嵌套的字典，类似`{"name": "first", "loss":{"weight":10}}`这种形式。那么问题就是，怎么通过命令行参数来修改嵌套的字典中的某个值呢？答案就是toml。

[toml](https://github.com/toml-lang/toml/blob/master/versions/cn/toml-v0.5.0.md)是一种语义明显且易于阅读的最小化配置文件格式，对空白符不敏感，不需要通过缩进等等表达层次。toml的具体格式可以参考[官方介绍]([toml](https://github.com/toml-lang/toml/blob/master/versions/cn/toml-v0.5.0.md))。

这里我们只用到了toml的一点内容：**点分隔键**（Dotted keys）。toml支持形如“`loss.weight.bias=10`”这样格式，对应的JSON为`{"loss":{"weight":{"bias":10}}}`，即只有单个值的嵌套的字典。

所以我们可以通过命令行参数，用点分割键指定要覆盖的原始配置。举个例子：

```bash
python mail.py -c ./path/to/config/file -t "loss.weight.bias=10" -t "title='hello, world'" -t "loss.type=['hello', 'world']"
```

我们可以多次指定要更改的参数。多次指定并存储配置这个功能python的官方库`argparse`已经支持：

```python
parser.add_argument("-t", "--toml", type=str, action="append")
```

指定`action`为`append`时，最后获取到的参数为一个列表：

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











