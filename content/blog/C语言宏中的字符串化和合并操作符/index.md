---
title: c语言宏中的字符串化和合并操作符
date: 2018-08-25 14:20:45
description: 简单梳理一下C语言中#，##的使用方法以及用途。
categories:
- 技术
tags:
- C/C++
thumbnail: https://lowentropy.jinxiapu.cn/img/blog/2/carbon.png
---

C语言中的宏是一个很简单粗暴的设计，主要功能就是`replace`。为了更方便地替换，引入了宏函数这一概念。宏函数用参数替换预先定义的标识符在宏定义中的每一次出现。配合#和##，可以用宏简单高效地完成一些复杂的操作。

## 操作符#和##的作用

### “#”运算符

运算符#的名字是`Stringizing Operator`，它将函数宏的实际参数转换为对应的字符串常量。

举个例子：

```c
// stringizer.c
#include <stdio.h>
#define MAX 100
#define stringer( x ) printf( #x "\n" ) // 这里使用了#.
int main() {
   stringer( In quotes in the printf function call );
   stringer(In  quotes in the  printf      function call );
   stringer( "In quotes when printed to the screen" );
   stringer( "This: \"  prints an escaped double quote" );
   stringer( MAX );
   return 0;
}
```

你可以使用[在线IDE](https://ide.geeksforgeeks.org/shFiVkTLm4)运行程序，得到输出结果如下：

```output
In quotes in the printf function call
In quotes in the printf function call
"In quotes when printed to the screen"
"This: \"  prints an escaped double quote"
MAX
```

从上面的例子我们可以看到，#的功能比较容易理解：其实就是将原本宏应该展开的内容用`""`括起来形成一个字面值常量。那是不是相当于把宏函数的参数内容两边直接加个`""`呢?不，不只是这样。#对空格以及特殊字符的处理正是理解使用#时的难点。事实上，上面的例子最后展开的结果是：

```c
#include <stdio.h>
#define MAX 100
#define stringer( x ) printf( #x "\n" ) // 这里使用了#.

int main() {  
   printf( "In quotes in the printf function call\n" "\n" );
   printf( "In quotes in the printf function call\n" "\n" );  
   printf( "\"In quotes when printed to the screen\"\n" "\n" );  
   printf( "\"This: \\\" prints an escaped double quote\"" "\n" );
   printf( "MAX" );
   return 0;
}  
```

注意到了吗？第一行和第二行的结果是一致的，中间的空格被忽略了一部分！同样的，第三行，第四行中，会把字符串中的特殊字符前会自动添加`\`，保证得到的字符串常量是参数本身的样子。当参数是`"\m"`时，转换后的结果不是`\"\\\m\"`而是`""\m""`。 而C语言编译时，`\"\\\m\"`正对应着内存中的`"\m"`。在第5行中预先定义的宏MAX并**没有**展开，替换为字符串时并不进行宏展开这一点一定要注意。这个可以解释为预处理器并不替换字符串中的宏（被引号包起来的宏）。如果想让宏展开应该怎么做呢？这个问题我们稍后再讲。

总结一下，对于#操作符来说

1. "#"的功能是对参数执行字符串化，如果没有特殊情况，这就意味着直接用`""`将参数包裹起来做替换。

2. 如果实际参数中包含在字符串中使用时需要转义的字符(比如`"`和`\`)，那么这些字符就会被转义。

3. 被字符串化的文本中的所有前导和尾随空白被忽略。文本中间的任何空格序列都将转换为单个空格。至于注释，因为注释往往在编译器处理源代码刚开始就被去除，远早于字符串化的发生，所以注释不可能包含在转换的结果中。

4. 参数直接转换成字符串，参数中的宏不展开。

### “##”运算符

`##`称之为标记粘贴运算符(Token-Pasting Operator)，也可以叫做合并运算符("merging" operator)。用来合并标识符。当宏展开时，位于##两边的标记合并成一个标识符，如果##两边的标识符时宏函数的参数时，用实际参数取代标识符后再合并。##两边的空格在合并时都会被删除，空格多少是无关紧要的。
比如这个宏定义`#define macro_start i ## n ##t m         ##ain(void)`，展开后得到`int main(void)`。

`##`可以用在宏函数以外的地方，但一般来说，用在宏函数之外的地方并无多大意义。上面的例子就是一个证明，在这里使用##并没有太大意义。##真正发光发热的时候是用在宏函数时，用参数替换形成了新的标识符。比如`#define my_macro(x) x##_macrofied`这个宏在使用时`my_macro(identifier)`展开为`identifier_macrofied`。

如果合并后的结果不是有效的标识符，如`mai ## n ##()`合并后产生`main()`, 这时编译器如何处理是**未定义**的。目前GCC是不允许这种情况的，会报如*pasting "main" and "(" does not give a valid preprocessing token*这样的错误。而Visual C++是允许这种行为的。这里的`标识符`实际上不止是变量名的意思，如`#define macro_increment(x) x+ ## +`这样的宏GCC和Visual C++都是允许的，因为宏展开后得到`x++`,这可以解释为`x`和`++`两个标识符。

## 使用范例

一般而言，并不特别鼓励使用C/C++的宏，因为宏是简单的字符串替换，特别容易出错，还不利于IDE的补全等等功能。因此使用宏就需要特别注意，没有很好的理由一般不使用宏，对于#,##更是如此。

在介绍##和#的应用场景之前，先回答一个问题：如何展开参数中的宏？

宏作为参数时，#是默认不展开宏的，为了使参数中的宏展开后再转成字符串常量，需要两个宏：

```c
#define xstr(s) str(s)
#define str(s) #s
#define foo 4
```

这时候使用`str (foo)`展开为`"foo"`,如果用`xstr (foo)`，则按`xstr (4)`→`str (4)`→`"4"`的顺序逐步展开。

这样做的原因是除非是遇到#或者##，否则宏函数的参数一定是完全展开后再做宏函数参数，关于宏展开顺序更详细的解释可以参考GCC的[文档]((https://gcc.gnu.org/onlinedocs/cpp/Argument-Prescan.html#Argument-Prescan))。

### Don't repeat yourself

宏最常见的使用场景就是减少重复，以减少犯错，看下面这个例子：

在某些程序命令表中需要命令表，一般情况下是这样的申明方式：

```c
struct command
{
  char *name;
  void (*function) (void);
};
// Command Table.
struct command commands[] =
{
  { "quit", quit_command },
  { "help", help_command },
  …
};
```

这样的场景下，更好的方式是定义一个宏，程序变成了这样：

```c
#define COMMAND(NAME)  { #NAME, NAME ## _command }

struct command commands[] =
{
  COMMAND(quit),
  COMMAND(help),
  …
};
```

### 在C语言中模仿C++的模板功能

如果程序中有一系列函数或者结构体有相同的结构，但为了效率不能整合在一起等等其它因素必须写相似的代码很多遍，可以尝试用##和#实现，比如需要写一系列convert函数时，可以用下面这个宏

```c
/*
from – a descriptive name of the unit we are converting from
to – a descriptive name of the unit we are converting to
conversion – the conversion equation
  (yes, macro parameters can be complex)
from_type – the type we are converting from
to_type – the type we are converting to
*/
#define convert(from, to, conversion, from_type, to_type) \
to_type convert_##from##_to_##to(from_type f) \
{ \
   return conversion; \
} \
```

这样就可以用其声明一些类似的函数：

```C
convert(f, c, (f-32)*5.0/9.0, float, float);
convert(ft, in, ft * 12, int, int);
```

一般而言，关于C语言的奇巧淫技我们都可以从linux的代码中找到。#，##在Linux的源代码中大量出现。我随便找到一个主要用##来申明新结构体类型和对应方法的[头文件](https://github.com/torvalds/linux/blob/master/include/linux/average.h)，大家可以参考一下。

### assert和log功能

assert和log场景下，经常需要将部分代码原样输出，这时候#的应用就很广泛了，举几个最简单的例子

```c
#define assert(x) ((x)?(void)0:__assert(#x, __FILE__, __LINE__))
```

```c
#define showlist(...) puts(#__VA_ARGS__)
showlist();            // expands to puts("")
showlist(1, "x", int); // expands to puts("1, \"x\", int")
```

## 总结

宏因为其只是简单地字符串替换，使用时顾忌很多，尤其是在C++中，除了条件编译甚至可以说是建议尽量不使用宏了。然而#，和##的妥善使用在精简重复代码，提示可读性时有很多应用，是C/C++预处理机制中非常关键的部分，用好了可以使代码可读性有很大提高，同时践行DRY法则。

## 进一步阅读：

1. [GCC文档中对##的介绍](https://gcc.gnu.org/onlinedocs/cpp/Concatenation.html)

2. [Visual C++文档中对##的介绍](https://msdn.microsoft.com/en-us/library/09dwwt6y.aspx)

3. [用宏实现if,while等等，试图证明C的预处理器是图灵完备的。其中涉及到了很多#，##的技巧](https://github.com/pfultz2/Cloak/wiki/C-Preprocessor-tricks,-tips,-and-idioms)