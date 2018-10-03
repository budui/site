---
title: "Go语言老手如何组织后台程序？"
date: 2018-10-03T15:36:29+08:00
categories:
- 技术
- 翻译
tags:
- Golang
- Web
description: 翻译《How I write Go HTTP services after seven years》
---

> 本文翻译自[Mat Ryer](http://matryer.com/)的博文：[How I write Go HTTP services after seven years](https://medium.com/statuscode/how-i-write-go-http-services-after-seven-years-37c208122831). 有足够英语阅读能力的读者请直接阅读原文。

我一直在改进我写HTTP服务的方法，在写了7年Go程序后，我是怎么设计Go Web后端程序的呢？

## Server结构体

Server结构体是程序最基本的组件，这个结构体囊括了所有API共享的依赖组件：

```Golang
type server struct {
    db     *someDatabase //数据库
    router *someRouter // 路由表
    email  EmailSender // 邮件发送器
    // 还有更多程序需要共享的依赖组件
}
```

## routes.go

将所有的可用的路由规则写在同一个文件中：

```Golang
package app
//routes函数负责注册所有的路由
func (s *server) routes() {
    s.router.HandleFunc("/api/", s.handleAPI())
    s.router.HandleFunc("/about", s.handleAbout())
    s.router.HandleFunc("/", s.handleIndex())
}
```

将路由写在一起有利于Debug：一般错误发生在特定路由上，一看routes.go文件，我们就能找到对应的handler。方便后期维护。

## 请求处理方法是Server的方法

请求处理函数是Server的方法，一般格式：

```Golang
func (s *server) handleSomething() http.HandlerFunc { ... }
```

这样做可以保证我们每一个请求处理函数都可以访问到server结构体中存储着的依赖。

## 请求处理方法返回HTTP Handler

注册在Server结构体上的请求处理方法并不直接处理请求，而是返回一个HTTP Handler(在`net/http`包中定义)，这个Handler才是实际处理请求的函数。

这样做的目的是构造一个闭包，这有什么用呢？先看例子：

```Golang
func (s *server) handleSomething() http.HandlerFunc {
    thing := prepareThing()
    return func(w http.ResponseWriter, r *http.Request) {
        // use thing
    }
}
```

prepareThing函数只在注册路由时调用，这样你可以在其中完成一些只需要运行一次的Handler初始化步骤，比如声明一个用来读写数据库的指针，根据Golang的闭包特性，这个指针可以被返回的Handler访问。这样避免了传参过程。

但是这样做一定要确保Handler中**只读**这个数据，如果涉及到修改，一定要注意多线程的读写冲突问题，应该用个mutex保护下数据或者采取其它必要的措施防止冲突。

## 请求处理方法的参数依据对应Handler的需求来设计

如果某个Handler需要什么不在Server结构体中的依赖，就通过方法参数传进去：

如：

```Golang
func (s *server) handleGreeting(format string) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, format, "World")
    }
}
```

返回的Handler可以访问传进去的format参数。

## 程序Middleware就是一个Go函数

Midderware的参数就是Handler，返回值是一个新的Handler。为某个Handler添加Middleware只需要将其作为这个Middleware的参数就行了。Midderware可以在运行Handler前后添加一些如log，统计数据等等类型的代码——甚至可以决定是否运行这个Handler：

```Golang
func (s *server) adminOnly(h http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        if !currentUser(r).IsAdmin {
            http.NotFound(w, r)
            return
        }
        h(w, r)
    }
}
```

Middleware可以利用逻辑判断是否运行传进去来的Handler，比如上面这个函数，判断当前用户不是admin后直接返回404而不是对应的Handler。这就实现了鉴权功能。

相应的修改routes.go为：

```Golang
package app
func (s *server) routes() {
    s.router.HandleFunc("/api/", s.handleAPI())
    s.router.HandleFunc("/about", s.handleAbout())
    s.router.HandleFunc("/", s.handleIndex())
    s.router.HandleFunc("/admin", s.adminOnly(s.handleAdminIndex()))
}
```

## 为单独的Handler定制Request或Response类型。

某一条路由可能需要它特有的request和response类型，这种情况下，你可以在函数内部声明特有类型：

```Golang
func (s *server) handleSomething() http.HandlerFunc {
    type request struct {
        Name string
    }
    type response struct {
        Greeting string `json:"greeting"`
    }
    return func(w http.ResponseWriter, r *http.Request) {
        ...
    }
}
```

这样做保护了包级别的命名空间，在不同Handler中你可以声明相同名字的不同结构体。写测试代码时，复制粘贴相同的声明代码到相应的测试函数中就行了。这有助于后来人理解你的代码。

## 临时声明类型能帮助构建测试代码

如果你的request/response类型声明隐藏在Handler中，在编写测试代码时，直接申明一个新的所需类型就行了。

举个例子：

假设包代码中有一个Person类型，多个Handler都使用了这种结构体。但在`/greet`这个API测试代码中，我们可能只需要利用Person的name属性，我们可以这样写：

```Golang
func TestGreet(t *testing.T) {
    is := is.New(t)
    p := struct {
        Name string `json:"name"`
    }{
        Name: "Mat Ryer",
    }
    var buf bytes.Buffer
    err := json.NewEncoder(&buf).Encode(p)
    is.NoErr(err) // json.NewEncoder
    req, err := http.NewRequest(http.MethodPost, "/greet", &buf)
    is.NoErr(err)
    //... more test code here
```

从测试代码中我们可以很容易地看到，我们只关心Person的name属性，代码的自解释性更好了。

## 利用sync.Once来初始化依赖

有的时候我们为某个Handler初始化其依赖代价很大，我们希望只有在第一次请求某个API时才初始化依赖，显然这样可以加快程序的启动速度。

举例如下：

```Golang
func (s *server) handleTemplate(files string...) http.HandlerFunc {
    var (
        init sync.Once
        tpl  *template.Template
        err  error
    )
    return func(w http.ResponseWriter, r *http.Request) {
        init.Do(func(){
            tpl, err = template.ParseFiles(files...)
        })
        if err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        // use tpl
    }
}
```

[sync.Once](https://golang.org/pkg/sync/#Once)能确保初始化代码只运行一遍。并且在初始化代码运行完成之前，它能够阻塞对同一个Handler的请求。这段代码还有两个关键点：

1. 检查初始化依赖结果的代码放在sync.Once之外，这样如果初始化失败，对相同API的访问都能被捕获，可以记录到log中，同时也避免了无用的`tpl`在之后的调用中使用，提前报StatusInternalServerError错误避免更大的意外。

2. 如果这个API没有被访问，`init.Do()`中的代码就永远不会被运行——很显然这在初始化代价很大时很有好处。

> 不过，你要明白的是，这种用法是将程序启动时要运行的代码转移到runtime运行（API被第一次访问时）。我经常部署代码到Google App Engine，所以我有这种需求。你需要认真考虑下你是否也有同样的需求，根据自己的运行环境来选择是否使用`sync.Once`。
