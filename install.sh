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

NET_IP=`docker run --rm --net=host alpine ip route get 8.8.8.8 | awk '{ print $7;  }'`
PORT=8000

uninstall_redis() {
	docker rm -fv redis > /dev/null 2>&1
}

install_redis() {
	uninstall_redis
	docker pull demoregistry.dataman-inc.com/srypoc/redis:3.0.5
        docker run -d \
                  --expose=6379 \
                  --restart=always \
                  --name=redis \
		  demoregistry.dataman-inc.com/srypoc/redis:3.0.5 redis-server --appendonly yes
}       

uninstall_rmq() {
	docker rm -fv rabbitmq > /dev/null 2>&1
}

install_rmq() {
	uninstall_rmq
	docker pull demoregistry.dataman-inc.com/srypoc/rabbitmq:3.6.0-management
        docker run -d \
               	   --expose=4369 \
		   --expose=5671 \
		   --expose=5672 \
		   --expose=25672 \
		   --expose=15671 \
		   --expose=15672 \
               	   --restart=always \
               	   --name=rabbitmq \
		   -e RABBITMQ_DEFAULT_USER=guest \
	           -e RABBITMQ_DEFAULT_PASS=guest \
               	   demoregistry.dataman-inc.com/srypoc/rabbitmq:3.6.0-management 
}

uninstall_mysql() {
	docker rm -f mysql > /dev/null 2>&1
}

install_mysql() {
	uninstall_mysql
	docker pull demoregistry.dataman-inc.com/srypoc/mysql:5.6
        docker run -d \
               	   --expose=3306 \
               	   --restart=always \
               	   --name=mysql \
		   -v $(pwd)/src/omega-cluster/omega/omega/mysql_settings/my.cnf:/etc/my.cnf:ro \
		   -v $(pwd)/db/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d:ro \
		   -e MYSQL_ROOT_PASSWORD=111111 \
               	   demoregistry.dataman-inc.com/srypoc/mysql:5.6 
}

uninstall_influxdb() {
	docker rm -f influxdb > /dev/null 2>&1
}

install_influxdb() {
	uninstall_influxdb
	docker pull demoregistry.dataman-inc.com/srypoc/influxdb:0.10
	docker run -d \
		   -e PRE_CREATE_DB=shurenyun \
                   --restart=always \
                   --name=influxdb \
                   demoregistry.dataman-inc.com/srypoc/influxdb:0.10
}

uninstall_elasticsearch(){
	docker rm -f elasticsearch > /dev/null 2>&1
}

install_elasticsearch() {
	uninstall_elasticsearch
	docker pull demoregistry.dataman-inc.com/srypoc/centos7-jdk7-elasticsearch-1.4.5-alone:20160522230210
	docker run -d \
                   --name=elasticsearch \
                   --restart=always \
                   -e ES_MIN_MEM=1024M \
                   -e ES_MAX_MEM=1024M \
                   demoregistry.dataman-inc.com/srypoc/centos7-jdk7-elasticsearch-1.4.5-alone:20160522230210
}

uninstall_logstash() {
	docker rm -f logstash > /dev/null 2>&1
}

install_logstash() {
	uninstall_logstash
        docker pull demoregistry.dataman-inc.com/srypoc/logstash:1.5.6
        docker run -d \
                   --name=logstash \
                   --restart=always \
                   --link=elasticsearch \
                   -v $(pwd)/src/omega-es/third_party/logstash/dataman.conf:/etc/logstash/conf.d/dataman.conf:ro \
                   -v $(pwd)/src/omega-es/third_party/logstash/logstash.json:/usr/local/logstash/conf/logstash.json:ro \
                   demoregistry.dataman-inc.com/srypoc/logstash:1.5.6 logstash -f /etc/logstash/conf.d/dataman.conf
}

function update_repositories {
    git submodule init 
    git submodule update --remote 
}

uninstall_harbor() {
	docker rm -f harbor > /dev/null 2>&1
}

install_harbor() {
	uninstall_harbor
}

uninstall_cluster(){
	docker rm -f omega-cluster > /dev/null 2>&1
}

install_cluster() {
	uninstall_cluster
	cd src
        docker build -t demoregistry.dataman-inc.com/library/python34:v0.1.063001 -f omega-cluster/dockerfiles/Dockerfile_compile_env .
}

install_cmdline_tools() {
    pip install terminaltables > /dev/null 2>&1
    pip install sh > /dev/null 2>&1
    install ./bin/omega /usr/local/bin/
	chmod +x /usr/local/bin/omega
}

install_finish() {
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

install_redis
install_rmq
install_mysql
install_influxdb
install_elasticsearch
install_logstash
update_repositories
install_harbor
install_cluster
