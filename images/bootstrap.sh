#!/usr/bin/env sh

${ZOOKEEPER_HOME}/bin/zkServer.sh start

tail -f ${ZOOKEEPER_HOME}/logs/*.out
