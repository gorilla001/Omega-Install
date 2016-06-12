#!/bin/bash


function init {
    git submodule init
    git submodule update
}

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
    sed -i "s#EXAMPLE#$EXAMPLE#g" src/compose.yml
    
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
    sed -i "s#APIURL#$DASHBOARD#g" src/compose.yml
    sed -i "s#IPADDR#$IPADDR#g" src/compose.yml
    sed -i "s#IPADDR#$IPADDR#g" src/compose.yml
    
    #harbor
    sed -i "s#IPADDR#$IPADDR#g" src/compose.yml
}

case "${1}" in
    "up")
        init
        config
        docker-compose -f compose.yml up -d
        ;;
    "down")
        docker-compose -f compose.yml down 
        ;;
    "start")
        docker-compose -f compose.yml start -d
        ;;
    "stop")
        docker-compose -f compose.yml stop 
        ;;
       *)
        echo "./install [ up | down | start | stop]"
        ;;
esac
