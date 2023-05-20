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

