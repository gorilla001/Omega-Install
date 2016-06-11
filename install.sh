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
    git clone git@github.com:Dataman-Cloud/omega-app.git
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

NET_IF=`netstat -rn | awk '/^0.0.0.0/ {thif=substr($0,74,10); print thif;} /^default.*UG/ {thif=substr($0,65,10); print thif;}'`

NET_IP=`ifconfig ${NET_IF} | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

EXAMPLE=${NET_IP}
IPADDR=${NET_IP}
CI_AUFS_OR_OVERLAY=aufs
DOCKER_AUTH_SITE=registry:5000
DASHBOARD=http://$EXAMPLE:8000
STREAMING=ws://$EXAMPLE:8000
MARKET=http://$EXAMPLE:8001
LOGSTASH=$IPADDR:4999
GF_BASE_URL=http://$EXAMPLE:5010
CLUSTER_URL=$EXAMPLE:8000
REGISTRY=$IPADDR
HARBOR=$IPADDR

#cluster
sed -i "s#LOGSTASH#$LOGSTASH#g" omega-cluster/omega/omega/config.conf
sed -i "s#MARKET_URL#$MARKET#g" omega-cluster/omega/omega/config.conf
sed -i "s#DASHBOARD_URL#$DASHBOARD#g" omega-cluster/omega/omega/config.conf
sed -i "s#DOCKER_AUTH_SITE#$DOCKER_AUTH_SITE#g" omega-cluster/omega/omega/config.conf

#frontend
sed -i "s#APIURL#$DASHBOARD#g" frontend/glance/js/confdev.js
sed -i "s#MARKET#$MARKET#g" frontend/glance/js/confdev.js
sed -i "s#STREAMING#$STREAMING#g" frontend/glance/js/confdev.js
sed -i "s#ENVIRONMENT#dev#g" frontend/glance/js/confdev.js
sed -i "s#OFFLINE#true#g" frontend/glance/js/confdev.js
sed -i "s#GF_BASE_URL#$GF_BASE_URL#g" frontend/glance/js/confdev.js
sed -i "s#LOCAL_DM_HOST#DM_HOST=$STREAMING/#g" frontend/glance/js/confdev.js
sed -i "s#BODY_DOMAIN##g" frontend/glance/js/confdev.js

#webpage
sed -i "s#DASHBOARD#$DASHBOARD#g" webpage/conf.js
sed -i "s#APIURL#$DASHBOARD#g" webpage/conf.js
sed -i "s#BODY_DOMAIN##g" webpage/conf.js
sed -i "s#ENVIRONMENT#dev#g" webpage/conf.js
sed -i "s#MARKET##g" webpage/conf.js
sed -i "s#OFFLINE#true#g" webpage/conf.js

#Drone
sed -i "s#REGISTRY#$REGISTRY#g" drone/.env.sample
sed -i "s#HARBOR#$HARBOR#g" drone/.env.sample
sed -i "s#CI_AUFS_OR_OVERLAY#$CI_AUFS_OR_OVERLAY#g" drone/.env.sample

#app
sed -i "s#APIURL#$DASHBOARD#g" omega-app/omega-app.yaml.sample
sed -i "s#CLUSTER_URL#$CLUSTER_URL#g" omega-app/omega-app.yaml.sample
sed -i "s#EXAMPLE#$EXAMPLE#g" compose.yml

#hosts
sed -i '/registry/d' /etc/hosts
sed -i '/harbor/d' /etc/hosts
echo "$REGISTRY registry" >> /etc/hosts
echo "$HARBOR   harbor"   >> /etc/hosts
if [ $IPADDR != $EXAMPLE ]; then
  echo "$IPADDR   $EXAMPLE"   >> /etc/hosts
fi

#es
sed -i "s#APIURL#$DASHBOARD#g" omega-es/omega-es.yaml.sample

#alert
sed -i "s#APIURL#$DASHBOARD#g" compose.yml
sed -i "s#IPADDR#$IPADDR#g" compose.yml
sed -i "s#IPADDR#$IPADDR#g" compose.yml

#harbor
sed -i "s#IPADDR#$IPADDR#g" compose.yml


case "${1}" in
    "up")
        docker-compose -f compose.yml up -d
        ;;
    "start")
        docker-compose -f compose.yml start -d
        ;;
    "stop")
        docker-compose -f compose.yml down 
        ;;
    "rm")
        echo "y" | docker-compose -f compose.yml rm 
        ;;
       *)
        echo "./install [ up | start | stop | rm ]"
        ;;
esac
        
