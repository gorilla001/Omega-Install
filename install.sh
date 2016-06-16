#!/bin/bash

# NET_IF=`netstat -rn | awk '/^0.0.0.0/ {thif=substr($0,74,10); print thif;} /^default.*UG/ {thif=substr($0,65,10); print thif;}'`
#     
# NET_IP=`ifconfig ${NET_IF} | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

if [ -z "`which pip`" ]; then
    apt-get update && apt-get install -y python-pip
fi

if [ -z "`which docker`" ]; then
    curl -sSL https://coding.net/u/upccup/p/dm-agent-installer/git/raw/master/install-docker.sh | sh
else
    [ "$(docker --version | cut -d" " -f3 | tr -d ',')" != "1.9.1" ] && apt-get remove -y docker-engine && install_docker
fi

if [ -z "`which docker-compose`" ]; then
    pip install docker-compose==1.6.0
fi

function update_repositories {
    #git submodule init && git submodule foreach git pull origin master  && git submodule foreach git checkout master
    git submodule init 
    #expect -c 'spawn git submodule update; expect "(yes/no)?"; send "yes\n";interact'
    #git submodule foreach git pull origin master  && git submodule foreach git checkout master
    git submodule update
}

NET_IP=`docker run --rm --net=host alpine ip route get 8.8.8.8 | awk '{ print $7;  }'`
PORT=8000

function update_settings {

    
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

    #cluster
    sed -i "s/services_mysql_1/mysql/g" src/omega-cluster/omega/omega/alembic.ini 

    #licence
    sed -i "s/LICENCEON/false/" src/frontend/glance/js/confdev.js 
}

function update_database {
    echo "Update database"
    docker pull demoregistry.dataman-inc.com/srypoc/mysql:5.6 > /dev/null 2>&1
    until $(docker run --link mysql -v $(pwd)/db.sh:/opt/db.sh --entrypoint=/opt/db.sh demoregistry.dataman-inc.com/srypoc/mysql:5.6  > /dev/null 2>&1);do 
        printf '.'
        sleep 1
    done
    printf '\n'
}

# function install_shipyard {
#     curl -sSL https://shipyard-project.com/deploy | PORT=9000 bash -s
# }
#
function install_cmdline_tools {
    install ./bin/omega /usr/local/bin/
	chmod +x /usr/local/bin/omega
}
function install_finish {
    echo
    # echo "Dataman Cloud install finished. Welcome to use."
    # echo
    echo "Finished."
    echo 
    echo -e "Dataman Cloud available at http://${NET_IP}:8000/auth/login"
    echo 
    echo -e "username: admin passwd: Dataman1234"
    echo 
    echo "Enjoy."
    # echo -en "login:"
    # echo -e "  http://${NET_IP}:8000/auth/login  admin/Dataman1234"
    # echo 
    # echo -en "manage:"
    # echo -e "  http://${NET_IP}:9000"  admin/shipyard
    # echo 
    # echo "Enjoy."
}

function update_services {
    docker-compose -f compose.yml down
    docker-compose -f compose.yml up -d
}

update_repositories
update_settings
update_services
update_database 
install_cmdline_tools
install_finish
