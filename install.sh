#!/bin/bash


if [ ! -d "frontend" ]; then
    git clone git@github.com:Dataman-Cloud/frontend.git
fi

if [ ! -d "webpage" ]; then
    git clone git@github.com:Dataman-Cloud/webpage.git
fi

if [ ! -d "omega-cluster" ];then
    git clone git@github.com:Dataman-Cloud/omega-cluster.git
fi

if [ ! -f "omega-app/Dockerfile" ];then
    git clone git clone git@github.com:Dataman-Cloud/omega-app.git
fi

if [ ! -f "omega-billing/Dockerfile" ];then
    git clone git@github.com:Dataman-Cloud/omega-billing.git
fi

if [ ! -f "omega-metrics/Dockerfile" ];then
    git clone git@github.com:Dataman-Cloud/omega-metrics.git
fi

if [ ! -f "omega-es/Dockerfile" ];then
    git clone git@github.com:Dataman-Cloud/omega-es.git
fi

if [ ! -f "sryun-alert/Dockerfile" ];then
    git clone git@github.com:Dataman-Cloud/sryun-alert.git
fi

if [ ! -f "harbor/Dockerfile" ];then
    git clone git@github.com:Dataman-Cloud/harbor.git
fi

if [ ! -f "drone/Dockerfile" ];then
    git clone git@github.com:Dataman-Cloud/drone.git
fi

docker-compose -f compose.yml up -d
