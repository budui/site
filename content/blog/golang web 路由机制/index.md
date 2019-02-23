---
title: "Golang http库路由机制"
date: 2018-10-01T14:40:53+08:00
categories:
- 技术
tags:
- Golang
- Web
description: 为你理清源代码中一堆Handler方法，Handle函数，Handler接口，handle变量，HandleFunc函数/方法之间的关系。
---

## 自带路由的使用

首先我们来研究下`net/http`库自带的路由。只要用`HandleFunc`将请求URL模式和回调函数注册成一条路由，然后调用`http.ListenAndServe`，当请求路径匹配路由表的某一项时，就调用这一项对应的回调函数(这里的“调用”并不指直接调用，具体如何，接着往下看)。
举个例子：

```Golang
package main

import (
    "io"
    "log"
    "net/http"
)

func main() {
    // Hello world, the web server
    helloHandler := func(w http.ResponseWriter, req *http.Request) {
        io.WriteString(w, "Hello, world!\n")
    }

    http.HandleFunc("/hello", helloHandler)
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

对于这个例子，当访问`/hello`时会执行我们刚才注册的那个路由对应的函数：

``` plaintext
$ curl -i 127.0.0.1:8080/hello
HTTP/1.1 200 OK
Date: Tue, 02 Oct 2018 06:21:59 GMT
Content-Length: 14
Content-Type: text/plain; charset=utf-8

Hello, world!
```

当访问未注册的路由如`/test`时没有对应的路由，会返回404.

```plaintext
HTTP/1.1 404 Not Found
Content-Type: text/plain; charset=utf-8
X-Content-Type-Options: nosniff
Date: Tue, 02 Oct 2018 06:23:52 GMT
Content-Length: 19

404 page not found
```

再看下代码的最后两行，调用`http.HandleFunc`,接着再运行`http.ListenAndServe`。注意这两个函数没有互相传参，只是分别调用，那我们的路由表项注册到哪里了？以我们写程序的经验，这个路由一定是保存在一个这两个函数都能访问的变量了，多半是个全局变量。事实就是如此，路由表项被注册在`http.DefaultServeMux`中，`ServeMux`指`Serve multiplexer`负责分发路由。`http.ListenAndServe`的第二个参数为`Handler`,按照[文档](https://golang.org/pkg/net/http/#ListenAndServe)所言:“The handler is typically nil, in which case the DefaultServeMux is used.”。如果`http.ListenAndServe`第二个参数是`nil`，就用`http.DefaultServeMux`来保存路由，接着分发不同的请求。

### 不使用默认的ServeMux

我们这次不使用默认的ServeMux来完成路由功能：

```golang
package main

import (
    "fmt"
    "io"
    "log"
    "net/http"
    "strings"
)

func main() {
    // 这里生成一个ServeMux实例
    handler := http.NewServeMux()

    // 注册路由1
    handler.HandleFunc("/hello/", func(w http.ResponseWriter, r *http.Request) {
        name := strings.Replace(r.URL.Path, "/hello/", "", 1)

        w.Header().Set("Content-Type", "text/plain")
        w.WriteHeader(http.StatusOK)

        io.WriteString(w, fmt.Sprintf("Hello %s\n", name))
    })
    // 注册路由2
    handler.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "text/plain")
        w.WriteHeader(http.StatusOK)

        io.WriteString(w, "Hello world\n")
    })

    // 注册路由3
    handler.HandleFunc("/h", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "text/plain")
        w.WriteHeader(http.StatusNotFound)

        io.WriteString(w, "Not found\n")
    })

    err := http.ListenAndServe(":9000", handler)

    if err != nil {
        log.Fatalf("Could not start server: %s\n", err.Error())
    }
}
```

这里发生两处变化：

1. 所有/hello/的子路径都被路由1接管，“/hello/”后的子路径被赋值给name。
2. 注册了“/”的路由，所以所有没有匹配到前两个路由的URL都会被路由3接管，返回`Not found\n`

这里的行为涉及到ServeMux匹配路由项时的规则：子路径也能匹配(/hello/1, /hello/都可以匹配/hello/);优先匹配更特殊的模式。更详细的解释可以看[文档](https://golang.org/pkg/net/http/#ServeMux)。

默认ServeMux和自己生成的ServeMux有什么区别呢？其实并没有太大区别，完全可以把上面代码中的`handler := http.NewServeMux()`这一行改为`handler := http.DefaultServeMux`。其实`http.DefaultServeMux`本身就是一个`ServeMux`型变量，只是为了方便，为http包添加必要的API提供了便利罢了。 go中也有其它包使用了这样的思路，比如log包，设置一个包级别的Logger实例, 如`log.Printf()`这样的函数实际上是调用了这个实例的`Printf`方法，上面的DefaultServeMux也是这个目的。

然而，在工程上，自己生成一个ServeMux示例更方便代码结构的优化等等，比如可以写不同的路由规则组，通过其它逻辑来判断http.ListenAndServe时使用哪个路由组。

## 自带路由的实现

### 参数类型

如果细细看过文档就会发现，`ListenAndServe`的第二个参数是`Handler`而不是`ServeMux`。`Handler`的定义为：

```golang
type Handler interface {
        ServeHTTP(ResponseWriter, *Request)
}
```

也就是说，只要实现了ServeHTTP方法，就可以作为`ListenAndServe`的第二个参数。进而负责路由分发以及响应请求。可以这么理解：对于任何一个请求，Go都是调用Handler的ServeHTTP方法，ServeHTTP的参数有两个，*Requset中保存着这次请求的所有信息，而ResponseWriter是写响应的工具。

对于每一个新请求，有两个任务，一个是 **路由分发**，目的是找到对应于这个请求的处理函数，接下来这个任务就是处理函数 **响应请求**，显然：`ServerMux`需要完成这两个任务。

### ServeMux究竟是什么？

在源代码中找到[定义](https://golang.org/src/net/http/server.go?s=66347:66472#L2139)

```Golang
type ServeMux struct {
    mu    sync.RWMutex
    m     map[string]muxEntry
    hosts bool // whether any patterns contain hostnames
}

type muxEntry struct {
    h       Handler
    pattern string
}
```

ServeMux真的是个很简单的结构，m中保存着路由表项，路由表项是个匹配模式和Handler型的组合的结构体。继续看一下ServeMux的ServeHTTP方法究竟做了什么？

看[代码](https://golang.org/src/net/http/server.go?s=71923:71983#L2342)：

```golang
// ServeHTTP dispatches the request to the handler whose
// pattern most closely matches the request URL.
func (mux *ServeMux) ServeHTTP(w ResponseWriter, r *Request) {
    if r.RequestURI == "*" {
        if r.ProtoAtLeast(1, 1) {
            w.Header().Set("Connection", "close")
        }
        w.WriteHeader(StatusBadRequest)
        return
    }
    h, _ := mux.Handler(r) //找到对应的Handler
    h.ServeHTTP(w, r) //响应请求
}
```

所以关键是ServeMux的Handler方法，直接看文档："Handler returns the handler to use for the given request"，所以我们明白了，ServeMux的Handler方法返回一个Handler接口型变量，这个变量就是用来响应请求的Handler，应该就是我们写的那个回调函数了。那么就有一个问题，我们写的回调函数实际上并不具有ServeHTTP(ResponseWriter, *Request)方法，是怎么作Handler类型的呢？这个问题我们稍后讲解怎么添加路由时应该就明白了。

现在我们总结一下目前我们得到的信息，所有的请求都由ServeMux处理，路由分发由Handler方法完成。ServeMux的ServeHTTP方法调用Handler方法为请求选择合适的处理函数，这个函数的类型同时也具有ServeHTTP方法，调用这个方法就可以在响应请求具体内容，路由分发由Handler方法完成。再回头看ServeMux结构体的内容，muxEntry是路由表项。ServeMux的Handler方法的作用就很显然了，查找路由表项，找到合适的Handler返回。

### ServeMux的Handler方法是如何分发路由的？

还是分析[源代码](https://golang.org/src/net/http/server.go?s=70230:70298#L2286)，只观察主要的逻辑，我们可以看到，Hander方法接着调用[handler方法](https://golang.org/src/net/http/server.go?s=70230:70298#L2331)，而handler又调用[match方法](https://golang.org/src/net/http/server.go?s=70230:70298#L2216)

分析下match方法(一看match方法的官方注释就知道找对了)：

```golang
// Find a handler on a handler map given a path string.
// Most-specific (longest) pattern wins.
func (mux *ServeMux) match(path string) (h Handler, pattern string) {
    // Check for exact match first.
    v, ok := mux.m[path]
    if ok {
        return v.h, v.pattern
    }

    // Check for longest valid match.
    var n = 0
    for k, v := range mux.m {
        if !pathMatch(k, path) {
            continue
        }
        if h == nil || len(k) > n {
            n = len(k)
            h = v.h
            pattern = v.pattern
        }
    }
    return
}
```

代码逻辑分为两部分，一部分是应对URL直接对应存储的模式，另一部分是循环所有路由项，一个一个测试，直到找到最长匹配的。检查是否匹配的函数为pathMatch:

```golang
// Does path match pattern?
func pathMatch(pattern, path string) bool {
    if len(pattern) == 0 {
        // should not happen
        return false
    }
    n := len(pattern)
    if pattern[n-1] != '/' {
        return pattern == path
    }
    return len(path) >= n && path[0:n] == pattern
}
```

这个函数也好理解，如果pattern的最后一个字符不是/，也就是非URL的目录，而是文件时，直接比对是否和path相等，如果是/，就看pattern是否可以视作path的前缀。(这里有个**疑惑**,第一种情况理论上并不会发生，因为在match函数中首先检查了这种情况，即直接把path当作key来检测字典m中是否有对应项。pathMatch函数也只在match函数中调用，没有其它用途了)

### ServeMux如何添加路由

到目前为止，我们基本已经明白了整个路由的机制，只差如何添加路由项这一步了。

看文档中Serve所有的外部方法：

```plaintext
type ServeMux
    func NewServeMux() *ServeMux
    func (mux *ServeMux) Handle(pattern string, handler Handler)
    func (mux *ServeMux) HandleFunc(pattern string, handler func(ResponseWriter, *Request))
    func (mux *ServeMux) Handler(r *Request) (h Handler, pattern string)
    func (mux *ServeMux) ServeHTTP(w ResponseWriter, r *Request)
```

显而易见，只有**Handle**和**HandleFunc**两个方法是用来添加路由表项的。

直接看[源码](https://golang.org/src/net/http/server.go?s=72291:72351#L2356)

```golang
// If a handler already exists for pattern, Handle panics.
func (mux *ServeMux) Handle(pattern string, handler Handler) {
    mux.mu.Lock()
    defer mux.mu.Unlock()

    if pattern == "" {
        panic("http: invalid pattern")
    }
    if handler == nil {
        panic("http: nil handler")
    }
    if _, exist := mux.m[pattern]; exist {
        panic("http: multiple registrations for " + pattern)
    }

    if mux.m == nil {
        mux.m = make(map[string]muxEntry)
    }
    mux.m[pattern] = muxEntry{h: handler, pattern: pattern}

    if pattern[0] != '/' {
        mux.hosts = true
    }
}

// HandleFunc registers the handler function for the given pattern.
func (mux *ServeMux) HandleFunc(pattern string, handler func(ResponseWriter, *Request)) {
    if handler == nil {
        panic("http: nil handler")
    }
    mux.Handle(pattern, HandlerFunc(handler))
}
```

不得不说GO的源码真的很容易理解，Handle方法检查下参数后直接把pattern和handler对应添加到map中。HandleFunc也是，检查下参数的可用性后，调用Handle方法。比较难理解的可能是`HandlerFunc(handler)`，我们根据这两个参数的类型可以猜测这个的作用是把func(ResponseWriter, *Request)型函数转换为Handler接口类型。

猜对了！原来源代码中有这样的[代码](https://golang.org/src/net/http/server.go?s=72834:72921#L1960)：

```golang
type HandlerFunc func(ResponseWriter, *Request)

// ServeHTTP calls f(w, r).
func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) {
    f(w, r)
}
```

也就是说HandlerFunc类型是实现了ServeHTTP方法的，用HandlerFunc(f)可将f强制转换为HandleFunc型，从而可以作为Handler看待。

## 总结

Golang的`net/http`库被视作经典，但其自带的路由却有些薄弱，但其路由机制为我们自己实现一个路由库提供了极其方便的接口，理解了自带的路由机制，下一步的问题就是如何自己编写功能更为强大的路由框架了。

P.S **我讨厌无穷无尽的Handler！**，就不能换个变量名吗！！！