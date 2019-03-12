#!/bin/bash

docker build -t rocketmqinc/rocketmq:4.3.2-k8s .
docker push rocketmqinc/rocketmq:4.3.2-k8s