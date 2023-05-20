@[TOC]
## 一、概述
Zookeeper是一个开源的分布式协调服务中间件，它提供了一种分布式数据管理服务，能够实现分布式锁、命名服务、配置管理、集群管理等功能，从而帮助用户构建高可用、高性能的分布式系统。以下是Zookeeper的一些主要特点和功能：

- 分布式协调服务：Zookeeper具有完备的分布式协调服务，如分布式锁、leader选举、命名服务、配置管理等，可以帮助用户构建高可用、高性能的分布式系统。

- **高可用性**：Zookeeper采用了多种机制保证服务的高可用性，其中包括主从复制、数据版本控制、环路日志等，从而构建了一个高度可靠、高度可用的分布式服务。

- **快速响应**：Zookeeper具有非常快速的响应能力，可以快速处理大量的请求并提供高效的数据存取服务。

- **数据一致性**：Zookeeper保证所有客户端看到服务端数据的一致性。它使用了一系列协议和算法，如ZAB协议、Paxos算法等，确保所有节点上的数据同步和协调。

- **开放API**：Zookeeper提供了众多的API，包括Java、C、C++等多种编程语言，可以方便地与其他软件系统进行集成和交互。

总之，Zookeeper是一个可靠、高效、易用的分布式协调服务中间件。它具有强大的分布式协调和管理功能，可以帮助用户轻松构建高可用、高性能的分布式系统。

![在这里插入图片描述](https://img-blog.csdnimg.cn/6dbb7d2d6aba4c9c9bf20a8e58a1f67a.png)
想了解更多关于zookeeper的知识点可以参考我之前的文章：[分布式开源协调服务——Zookeeper](https://blog.csdn.net/qq_35745940/article/details/124810252)

## 二、前期准备
### 1）部署 docker
```bash
# 安装yum-config-manager配置工具
yum -y install yum-utils

# 建议使用阿里云yum源：（推荐）
#yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装docker-ce版本
yum install -y docker-ce
# 启动并开机启动
systemctl enable --now docker
docker --version
```
### 2）部署 docker-compose
```bash
curl -SL https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
docker-compose --version
```
## 三、创建网络

```bash
# 创建，注意不能使用hadoop_network，要不然启动hs2服务的时候会有问题！！！
docker network create hadoop-network

# 查看
docker network ls
```
## 四、Zookeeper 编排部署
### 1）下载 Zookeeper

```bash
wget https://dlcdn.apache.org/zookeeper/zookeeper-3.8.1/apache-zookeeper-3.8.1-bin.tar.gz --no-check-certificate
```
注意还需要java环境，可以去官网下载，也可以在我下面提供的地址下载：
> 链接: [https://pan.baidu.com/s/1o_z3t16v0eASYWN4VcjYeg?pwd=kuac](https://pan.baidu.com/s/1o_z3t16v0eASYWN4VcjYeg?pwd=kuac) 提取码: `kuac` 复制这段内容后打开百度网盘手机App，操作更方便哦
### 2）配置
```bash
mkdir conf data/{zookeeper-node1,zookeeper-node2,zookeeper-node3}/data -p

# zookeeper 主配置文件
cat >conf/zoo.cfg<<EOF
# tickTime：Zookeeper 服务器之间或客户端与服务器之间维持心跳的时间间隔，也就是每个 tickTime 时间就会发送一个心跳。tickTime以毫秒为单位。session最小有效时间为tickTime*2
tickTime=2000

# Zookeeper保存数据的目录，默认情况下，Zookeeper将写数据的日志文件也保存在这个目录里。不要使用/tmp目录
dataDir=/opt/apache/zookeeper/data

# 端口，默认就是2181
clientPort=2181

# 集群中的follower服务器(F)与leader服务器(L)之间初始连接时能容忍的最多心跳数（tickTime的数量），超过此数量没有回复会断开链接
initLimit=10

# 集群中的follower服务器与leader服务器之间请求和应答之间能容忍的最多心跳数（tickTime的数量）
syncLimit=5

# 最大客户端链接数量，0不限制，默认是0
maxClientCnxns=60

# zookeeper集群配置项，server.1，server.2，server.3是zk集群节点；zookeeper-node1,zookeeper-node2,zookeeper-node3是主机名称；2888是主从通信端口；3888用来选举leader
server.1=zookeeper-node1:2888:3888
server.2=zookeeper-node2:2888:3888
server.3=zookeeper-node3:2888:3888
EOF

# 在刚创建好的zk data数据目录下面创建一个文件 myid
# 里面内容是server.N中的N，会通过挂载的方式添加
echo 1 > ./data/zookeeper-node1/data/myid
echo 2 > ./data/zookeeper-node2/data/myid
echo 3 > ./data/zookeeper-node3/data/myid
```
### 3）启动脚本 bootstrap.sh

```bash
#!/usr/bin/env sh

${ZOOKEEPER_HOME}/bin/zkServer.sh start

tail -f ${ZOOKEEPER_HOME}/logs/*.out
```
### 4）构建镜像 Dockerfile
```bash
FROM registry.cn-hangzhou.aliyuncs.com/bigdata_cloudnative/centos:7.7.1908

RUN rm -f /etc/localtime && ln -sv /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone

RUN export LANG=zh_CN.UTF-8

# 创建用户和用户组，跟yaml编排里的user: 10000:10000
RUN groupadd --system --gid=10000 hadoop && useradd --system --home-dir /home/hadoop --uid=10000 --gid=hadoop hadoop -m

# 安装sudo
RUN yum -y install sudo ; chmod 640 /etc/sudoers

# 给hadoop添加sudo权限
RUN echo "hadoop ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN yum -y install install net-tools telnet wget nc less

RUN mkdir /opt/apache/

# 添加配置 JDK
ADD jdk-8u212-linux-x64.tar.gz /opt/apache/
ENV JAVA_HOME /opt/apache/jdk1.8.0_212
ENV PATH $JAVA_HOME/bin:$PATH

# 添加配置 trino server
ENV ZOOKEEPER_VERSION 3.8.1
ADD apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz /opt/apache/
ENV ZOOKEEPER_HOME /opt/apache/zookeeper
RUN ln -s /opt/apache/apache-zookeeper-${ZOOKEEPER_VERSION}-bin $ZOOKEEPER_HOME

# 创建数据存储目录
RUN mkdir ${ZOOKEEPER_HOME}/data
# copy 配置文件
RUN cp ${ZOOKEEPER_HOME}/conf/zoo_sample.cfg ${ZOOKEEPER_HOME}/conf/zoo.cfg
# 这里的值会根据挂载的而修改
RUN echo 1 >${ZOOKEEPER_HOME}/data/myid

# copy bootstrap.sh
COPY bootstrap.sh /opt/apache/
RUN chmod +x /opt/apache/bootstrap.sh

RUN chown -R hadoop:hadoop /opt/apache

WORKDIR $ZOOKEEPER_HOME
```
开始构建镜像

```bash
docker build -t registry.cn-hangzhou.aliyuncs.com/bigdata_cloudnative/zookeeper:3.8.1 . --no-cache

# 为了方便小伙伴下载即可使用，我这里将镜像文件推送到阿里云的镜像仓库
docker push registry.cn-hangzhou.aliyuncs.com/bigdata_cloudnative/zookeeper:3.8.1

### 参数解释
# -t：指定镜像名称
# . ：当前目录Dockerfile
# -f：指定Dockerfile路径
#  --no-cache：不缓存
```
### 5）编排 docker-compose.yaml
```yaml
version: '3'
services:
  zookeeper-node1:
    image: registry.cn-hangzhou.aliyuncs.com/bigdata_cloudnative/zookeeper:3.8.1
    user: "hadoop:hadoop"
    container_name: zookeeper-node1
    hostname: zookeeper-node1
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - privileged=true
    env_file:
      - .env
    volumes:
      - ./conf/zoo.cfg:${ZOOKEEPER_HOME}/conf/zoo.cfg
      - ./data/zookeeper-node1/data/myid:${ZOOKEEPER_HOME}/data/myid
    ports:
      - "${ZOOKEEPER_NODE1_SERVER_PORT}:2181"
    expose:
      - 2888
      - 3888
    command: ["sh","-c","/opt/apache/bootstrap.sh"]
    networks:
      - hadoop-network
    healthcheck:
      test: ["CMD-SHELL", "netstat -tnlp|grep :2181 || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 5
  zookeeper-node2:
    image: registry.cn-hangzhou.aliyuncs.com/bigdata_cloudnative/zookeeper:3.8.1
    user: "hadoop:hadoop"
    container_name: zookeeper-node2
    hostname: zookeeper-node2
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - privileged=true
    env_file:
      - .env
    volumes:
      - ./conf/zoo.cfg:${ZOOKEEPER_HOME}/conf/zoo.cfg
      - ./data/zookeeper-node2/data/myid:${ZOOKEEPER_HOME}/data/myid
    ports:
      - "${ZOOKEEPER_NODE2_SERVER_PORT}:2181"
    expose:
      - 2888
      - 3888
    command: ["sh","-c","/opt/apache/bootstrap.sh"]
    networks:
      - hadoop-network
    healthcheck:
      test: ["CMD-SHELL", "netstat -tnlp|grep :2181 || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 5
  zookeeper-node3:
    image: registry.cn-hangzhou.aliyuncs.com/bigdata_cloudnative/zookeeper:3.8.1
    user: "hadoop:hadoop"
    container_name: zookeeper-node3
    hostname: zookeeper-node3
    restart: always
    environment:
      - TZ=Asia/Shanghai
      - privileged=true
    env_file:
      - .env
    volumes:
      - ./conf/zoo.cfg:${ZOOKEEPER_HOME}/conf/zoo.cfg
      - ./data/zookeeper-node3/data/myid:${ZOOKEEPER_HOME}/data/myid
    ports:
      - "${ZOOKEEPER_NODE3_SERVER_PORT}:2181"
    expose:
      - 2888
      - 3888
    command: ["sh","-c","/opt/apache/bootstrap.sh"]
    networks:
      - hadoop-network
    healthcheck:
      test: ["CMD-SHELL", "netstat -tnlp|grep :2181 || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 5

# 连接外部网络
networks:
  hadoop-network:
    external: true
```
`.env` 环境变量文件内容如下：

```bash
# 对外暴露的端口
cat << EOF > .env
ZOOKEEPER_HOME=/opt/apache/zookeeper
ZOOKEEPER_NODE1_SERVER_PORT=31181
ZOOKEEPER_NODE2_SERVER_PORT=32181
ZOOKEEPER_NODE3_SERVER_PORT=33181
EOF
```
### 6）开始部署

```bash
docker-compose -f docker-compose.yaml up -d

# 查看
docker-compose -f docker-compose.yaml ps
```
![在这里插入图片描述](https://img-blog.csdnimg.cn/3cc0dd1290d54d8e95a0cd0754cb3af7.png)
## 五、简单测试验证

```bash
# 检查节点
docker exec -it zookeeper-node1 bash
${ZOOKEEPER_HOME}/bin/zkServer.sh status
exit
docker exec -it zookeeper-node2 bash
${ZOOKEEPER_HOME}/bin/zkServer.sh status
exit
docker exec -it zookeeper-node3 bash
${ZOOKEEPER_HOME}/bin/zkServer.sh status
```
![在这里插入图片描述](https://img-blog.csdnimg.cn/ef8eba4ccb65430c88a93e659f115c72.png)
## 六、常用的 zookeeper 客户端命令
在Zookeeper中，节点类型分为四种：**持久节点**、**临时节点**、**有序节点**和**有序临时节点**。

- **持久节点**：持久节点是指一旦创建，就**一直存在于Zookeeper中，直到主动删除**。它可以存储任意类型的数据，并且在节点的路径中，数据的路径是必须存在的。

- **临时节点**：临时节点是指**一旦客户端与Zookeeper会话失效或关闭后，节点将会从Zookeeper中删除**。它的创建和删除都由客户端来维护。客户端下线或会话失效时，与该客户端相关的所有临时节点都会被删除。

- **有序节点**：有序节点是指创建的节点路径后**增加一个自然数序列**，每个数值表示一个节点的次序。它是按照节点创建的顺序进行编号的，可以帮助节点在Zookeeper中排序并查询。有序节点需要通过自增序列来实现，并且可以同时维护完整路径信息。

- **有序临时节点**：有序临时节点是指同时拥有**临时节点和有序节点两个特性的节点**。它一旦被创建，就会在Zookeeper中保留一段时间，直到客户端连接断开或者会话过期。 它的序列号将会按照节点的创建顺序，由小到大进行排序，并且同样会在节点被删除时删除。

> 总之，不同类型的Zookeeper节点具有不同的生命周期和功能。合理地利用这些节点类型，可以帮助用户构建出更加高效、可靠的分布式应用系统。
### 1）创建节点
```bash
# 随便登录一个容器节点
docker exec -it zookeeper-node1 bash

# 登录
${ZOOKEEPER_HOME}/bin/zkCli.sh -server zookeeper-node1:2181

# 【持久节点】数据节点创建后，一直存在，直到有删除操作主动清除，示例如下：
create /zk-node data

# 【持久顺序节点】节点一直存在，zk自动追加数字后缀做节点名，后缀上限 MAX(int)，示例如下：
create -s /zk-node data

# 【临时节点】生命周期和会话相同，客户端会话失效，则临时节点被清除，示例如下：
create -e /zk-node-temp data

# 【临时顺序节点】临时节点+顺序节点后缀，示例如下：
create -s -e /zk-node-temp data
```
### 2）查看节点

```bash
# 随便登录一个容器节点
docker exec -it zookeeper-node1 bash

# 登录
${ZOOKEEPER_HOME}/bin/zkCli.sh -server zookeeper-node1:2181

# 列出zk执行节点的所有子节点，只能看到第一级子节点
ls /
# 获取zk指定节点数据内容和属性
get /zk-node
```
### 3）更新节点
```bash
# 表达式：set ${path} ${data} [version]
set /zk-node hello
get /zk-node
```
### 4）删除节点
```bash
# 对于包含子节点的节点，该命令无法成功删除，使用deleteall /zk-node
delete /zk-node
# 删除非空目录
deleteall /zk-node
```
### 5）退出交互式
```bash
#帮助
help
# 退出
quit
```
### 6）非交互式命令
```bash
# 直接后面接上命令执行即可
${ZOOKEEPER_HOME}/bin/zkCli.sh -server zookeeper-node1:2181 ls /
```

通过 docker-compose 快速部署 Zookeeper 教程就先到这里了，有任何疑问欢迎给我留言或私信，可关注我公众号【**大数据与云原生技术分享**】加群交流或私信沟通~

![输入图片说明](https://foruda.gitee.com/images/1684573982977999820/45afbe17_1350539.png "屏幕截图")