#!/bin/bash


function install_pip {
   which pip 1>/dev/null 2>&1 
   if [ $? != 0 ];then
       apt-get update && apt-get install -y python-pip
   fi
}

install_pip

function install_docker {
   which docker 1>/dev/null 2>&1 
   [ $? -ne 0 ] && {
       curl -sSL https://coding.net/u/upccup/p/dm-agent-installer/git/raw/master/install-docker.sh | sh
   } || {
       [ "$(docker --version | cut -d" " -f3 | tr -d ',')" != "1.9.1" ] && apt-get remove -y docker-engine && install_docker
   }   
}

install_docker

function install_compose {
   which docker-compose 1>/dev/null 2>&1 
   if [ $? != 0 ];then
       pip install docker-compose==1.6.0
   fi
}

install_compose

function init {
    git submodule init && yes | git submodule update
    [ $? != 0 ] && exit
}

function install_golang {
   which go 1>/dev/null 2>&1 
   if [ $? != 0 ];then
       apt-get update && apt-get install -y golang-go && { 
          echo 'export GOPATH="/usr/share/go/"'  >> ~/.bash_profile
          export GOPATH="/usr/share/go/:$(pwd)"
          echo $GOPATH
       } || exit
   fi
}
install_golang

function config {

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
    sed -i "s#LOGSTASH#$LOGSTASH#g" src/omega-cluster/omega/omega/config.conf
    sed -i "s#MARKET_URL#$MARKET#g" src/omega-cluster/omega/omega/config.conf
    sed -i "s#DASHBOARD_URL#$DASHBOARD#g" src/omega-cluster/omega/omega/config.conf
    sed -i "s#DOCKER_AUTH_SITE#$DOCKER_AUTH_SITE#g" src/omega-cluster/omega/omega/config.conf
    
    #frontend
    sed -i "s#APIURL#$DASHBOARD#g" src/frontend/glance/js/confdev.js
    sed -i "s#MARKET#$MARKET#g" src/frontend/glance/js/confdev.js
    sed -i "s#STREAMING#$STREAMING#g" src/frontend/glance/js/confdev.js
    sed -i "s#ENVIRONMENT#dev#g" src/frontend/glance/js/confdev.js
    sed -i "s#OFFLINE#true#g" src/frontend/glance/js/confdev.js
    sed -i "s#GF_BASE_URL#$GF_BASE_URL#g" src/frontend/glance/js/confdev.js
    sed -i "s#LOCAL_DM_HOST#DM_HOST=$STREAMING/#g" src/frontend/glance/js/confdev.js
    sed -i "s#BODY_DOMAIN##g" src/frontend/glance/js/confdev.js
    
    #webpage
    sed -i "s#DASHBOARD#$DASHBOARD#g" src/webpage/conf.js
    sed -i "s#APIURL#$DASHBOARD#g" src/webpage/conf.js
    sed -i "s#BODY_DOMAIN##g" src/webpage/conf.js
    sed -i "s#ENVIRONMENT#dev#g" src/webpage/conf.js
    sed -i "s#MARKET##g" src/webpage/conf.js
    sed -i "s#OFFLINE#true#g" src/webpage/conf.js
    
    #Drone
    sed -i "s#REGISTRY#$REGISTRY#g" src/drone/.env.sample
    sed -i "s#HARBOR#$HARBOR#g" src/drone/.env.sample
    sed -i "s#CI_AUFS_OR_OVERLAY#$CI_AUFS_OR_OVERLAY#g" src/drone/.env.sample
    
    #app
    sed -i "s#APIURL#$DASHBOARD#g" src/omega-app/omega-app.yaml.sample
    sed -i "s#CLUSTER_URL#$CLUSTER_URL#g" src/omega-app/omega-app.yaml.sample
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
    sed -i "s#APIURL#$DASHBOARD#g" src/omega-es/omega-es.yaml.sample
    
    #alert
    sed -i "s#APIURL#$DASHBOARD#g" compose.yml
    sed -i "s#IPADDR#$IPADDR#g" compose.yml
    sed -i "s#IPADDR#$IPADDR#g" compose.yml
    
    #harbor
    sed -i "s#IPADDR#$IPADDR#g" compose.yml
}

function up {
    docker-compose -f compose.yml up -d
}

function down {
    docker-compose -f compose.yml down 
}

function main {
    init
    config
    down
    up
}

main
