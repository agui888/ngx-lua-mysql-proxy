性能：
    分支tcp-raw上，实现了对mysql协议的最简单解释，还没解释sql，相当于对tcp包拆箱。
    使用以下命令进行最简单压测，结果相当不理想

    > mysqlslap -a  --concurrency=20 --number-of-queries=1000 -P 1234

```
# 直接测不同机上的mysql，（与直接使用ngx的tcp stream代理性能接近）
root@172-16-9-28:# mysqlslap -a  --concurrency=20 --number-of-queries=1000 -P 3306
Benchmark
    Average number of seconds to run all queries: 0.483 seconds
    Minimum number of seconds to run all queries: 0.483 seconds
    Maximum number of seconds to run all queries: 0.483 seconds
    Number of clients running queries: 20
    Average number of queries per client: 50

# 使用lua+stream模块，就是使用lua解释mysql协议
root@172-16-9-28:# mysqlslap -a  --concurrency=20 --number-of-queries=1000 -P 1234
Benchmark
    Average number of seconds to run all queries: 1.472 seconds
    Minimum number of seconds to run all queries: 1.472 seconds
    Maximum number of seconds to run all queries: 1.472 seconds
    Number of clients running queries: 20
    Average number of queries per client: 50
```

    简单的结论就是： 慢3倍--- 太不理想了，暂停开发。

Dev
---
- openresty
- lua 5.1
- luarocks [penlight](https://github.comstevedonovan/Penlight)
- [lua-sqlparser](https://github.com/toontong/lua-sqlparser)
- [stream-lua-nginx-module](https://github.com/openresty/stream-lua-nginx-module#installation)

关于MySQL协议简短说明
---
1. 大致上采用一问多答的方式，由client发问。
1. 所有包头前3个字节为整个包的大小，第3个字节为此次应答中包的序号。
1. 故单包大小上限(2^24)-1=(16M-1)字节，序号0~255循环使用。
1. client端第一次连接时，先由服务端发送一个handshake报文给客户端。
1. handshake报文包含：
    - 协议版本、服务端版本、协议支持(兼容)内容标志位（32位)、分配连接ID；
    - 默认使用字符集，autocommit状态；
    - 分2段的随机字符串（前8后12），用于加密登录密码；
    - 10个无用填充字节。
1. 客户端接收handshake后，对兼容标志进行判断（取与），带上连接信息回复，
    - 如用户名、密码、字集、连接到哪个DB等。
    - 服务端回复OK后，握手完成。
1. 通信过程，即查询过程，只由客户端发起--除非svr直接close TCP。
2. 客户端使用一个字节(0~255)，定义命令集，至今只定义20多条命令。
3. 服务端返回报文包只有6大格式，（或称4种:ok,err,eof因除此之外可称data)；服务端根据客户端命令返回。
4. 6大报文中包包含几种结构：result-set、resutl-set-header、row-data、field、EOF、statement.
11. 其它注意事项
    - 报文格式在4.0以前与4.1后有变动，所以兼容标志位有标识是否使用4.1以上。
    - 由于4.0及以下版本太旧，无必要支持与解释。
    - 所谓的兼容标志，其实是双方支持使用方式与格式的通信，诸如双方是否支持ssl，compress等。
    - 包序号：每次应答开次的第一个包序号必需是从零开始，当大于255后，回滚为0.
    - 对于大于16M字节传输的包，需要对方再次去读取，即分包。