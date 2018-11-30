---
title: "使用Pandoc和KaTeX为HUGO添加LaTeX支持"
date: 2018-11-30T09:18:03+08:00
markup: pandoc
author: Ray Wong
---

最近在扫论文。写阅读笔记的时候，需要在Markdown中写公式。

我一般用[Visual Studio Code](https://code.visualstudio.com/)写Markdown文件，插件[Markdown All in One](https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one)可以给VScode添加LaTeX公式支持，在本地写作很方便。然而到了要生成网页展示的时候，却发现因为Markdown标识符(如`_`)和LaTeX标识符含义冲突，hugo对公式的支持有很多[问题](https://gohugo.io/content-management/formats/#issues-with-markdown)。

针对这个问题已经有几个解决方案：

1. hugo文档中的[解决方案](https://gohugo.io/content-management/formats/#solution)。配合一系列hack，效果还算可以。注意官网的流程可能是存在问题的，不如顺着这篇和hugo文档中解决方案一脉相承的[Setting MathJax with Hugo](https://divadnojnarg.github.io/blog/mathjax/)来想办法解决。
2. 谢益辉[^xie]的[解决方案](https://yihui.name/cn/2017/04/mathjax-markdown/)。谢的这篇文章同时也讲清楚了hugo和markdown中的公式不相容的原因，值得一看。
3. 魔改`blackfriday`。hugo用`blackfriday`这个库实现markdown到html的转换，强人们直接给`blackfriday`增加了处理行内公式的功能，同时去掉了Markdown中和LaTeX冲突的语法。

这些解决办法都比较麻烦，有一定限制，比如方案1，2需要用“``”把公式包起来，再用前端js处理。方案三似乎治本，但在blackfriday官方接受这个功能PR之前，想用任何hugo新版本都得重新编译，实在是麻烦，而且也不方便与netlify集成。

但是最近我发现hugo支持了调用第三方生成器！这意味着我们可以用伟大的Pandoc来做转换，hugo直接用转换结果就好了。方案四就此出炉。这种方案几乎不需要折腾。

hugo调用外部生成器需要两个条件：

1. hugo知道你要用哪个生成器。
2. hugo能调用这个生成器。

看文档发现hugo判断生成器的对应函数是[GuessType](https://github.com/gohugoio/hugo/blob/d970327d7b994b495ef3bb468c3e0599b0deef5a/helpers/general.go#L75)，hugo用文件后缀名或者front-matter中的`markup`值（markup值优先级更高）作为`GuessType`参数，所以`pandoc`, `pdc`都表示使用`pandoc`。

为了保证hugo可以调用pandoc，你需要先[安装](http://pandoc.org/installing.html)pandoc，再把pandoc加入到环境变量中（部分平台如Windows，安装pandoc时就添加了环境变量），最后[检查](http://pandoc.org/getting-started.html#step-2-open-a-terminal)下是否正确安装了Pandoc。

最终，我们只要在front-matter中添加一行`markup: pandoc`就保证了hugo生成的html是正确的了。

另外，一般前端用MathJax来显示公式，但最近又出现了一个[KaTeX](https://katex.org/))库同样可以显示公式，相比MathJax，KaTeX更轻量，更自然。

我的hugo主题引用KaTeX的代码块如下：

```HTML
{{- if (and .IsPage (eq .Params.markup "pandoc" ) ) -}}
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.css" integrity="sha384-9eLZqc9ds8eNjO3TmqPeYcDj8n+Qfa4nuSiGYa6DjLNcv9BtN69ZIulL9+8CqC9Y" crossorigin="anonymous">
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.js" integrity="sha384-K3vbOmF2BtaVai+Qk37uypf7VrgBubhQreNQe9aGsz9lB63dIFiQVlJbr92dw2Lx" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/contrib/auto-render.min.js" integrity="sha384-kmZOZB5ObwgQnS/DuDg6TScgOiWWBiVt0plIRkZCmE6rDZGrEOQeHM5PcHi+nyqe" crossorigin="anonymous"
        onload="renderMathInElement(document.querySelector('.single'));"></script>
{{- end -}}
```

如果是正文页且`markup`是`pandoc`（我只在正文包含公式时才改变默认的转换器），就引用KaTex那一套资源。

注意js代码中`document.querySelector('.single')`只适合我的hugo主题，如果你要用这段代码，记得换成你博客网页相应的选择器。

最后来测试下KaTeX的效果:

行内公式$A^2_1 = B^2_1+C^2_1$测试

复杂公式：

$$
\begin{cases}
\dot{x} & = \sigma(y-x) \newline
\dot{y} & = \rho x - y - xz \newline
\dot{z} & = -\beta z + xy
\end{cases}
$$

$$
1 +  \frac{q^2}{(1-q)}+\frac{q^6}{(1-q)(1-q^2)}+\cdots =
    \prod_{j=0}^{\infty}\frac{1}{(1-q^{5j+2})(1-q^{5j+3})},
     \quad\quad \text{for $|q|<1$}.
$$

$$
x(t) = e^{\int_{t_0}^tp(s)ds}\Bigg(\int_{t_0}^t\Big(q(s)e^{-\int_{t_0}^sp(\tau)d\tau}\Big)ds + x_0\Bigg).
$$

[^xie]: Flight Rules的主题就是从谢益辉写的hugo主题[xmin](https://github.com/yihui/hugo-xmin)中复制粘贴的。`xmin`中内置了谢的方案，但我删掉了。