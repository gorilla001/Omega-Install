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
    [ "$(docker --version | cut -d" " -f3 | tr -d ',')" != "1.9.1" ] && apt-get remove -y docker-engine && {
   	curl -sSL https://coding.net/u/upccup/p/dm-agent-installer/git/raw/master/install-docker.sh | sh
    }	
fi

if [ -z "`which go`" ]; then
    apt-get update && apt-get install -y golang 
fi

if [ -z "`which npm`" ]; then
    apt-get update && apt-get install -y npm 
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
	docker rm -fv rmq > /dev/null 2>&1
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
               	   --name=rmq \
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

update_repositories() {
    git submodule init 
    git submodule update --remote 
}

uninstall_harbor() {
	docker rm -f harbor > /dev/null 2>&1
}

build_harbor() {
	base=$(pwd)
	export GOPATH="/usr/local/go"
	mkdir -p /usr/local/go/src/github.com/vmware
	rm -rf /usr/local/go/src/github.com/vmware/harbor
	cp -r $base/src/harbor /usr/local/go/src/github.com/vmware
	cd /usr/local/go/src/github.com/vmware/harbor
	make localbuild 
	cp harbor $base/src/harbor 
	cd $base/src
        docker build -t harbor:env -f harbor/dockerfiles/Dockerfile_runtime . 
	cd ..
}
start_harbor() {
	uninstall_harbor
        docker run -d  \
		   --name=harbor \
		   --restart=always \
		   --link=redis \
		   --link=mysql \
		   --add-host=registry:${NET_IP} \
		   -e MYSQL_HOST=mysql \
		   -e MYSQL_PORT=3306 \
		   -e MYSQL_USR=root \
		   -e MYSQL_PWD=111111 \
		   -e REGISTRY_URL=http://registry:5000 \
		   -e CONFIG_PATH=/etc/ui/app.conf \
		   -e HARBOR_REG_URL=http://registry:5000 \
		   -e HARBOR_ADMIN_PASSWORD=Harbor12345 \
		   -e HARBOR_URL=http://harbor:5005 \
		   -e AUTH_MODE=db_auth \
		   -e REDIS_HOST=redis \
		   -e REDIS_PORT=6379 \
		   -e SQL_PATH=/sql \
		   harbor:env
}

uninstall_cluster(){
	docker rm -f cluster > /dev/null 2>&1
}

build_cluster() {
	cd src
        docker build -t demoregistry.dataman-inc.com/library/python34:v0.1.063001 -f omega-cluster/dockerfiles/Dockerfile_compile_env .
	docker build -t cluster:env -f omega-cluster/dockerfiles/Dockerfile_runtime .
	cd ..
}

start_cluster() {
	uninstall_cluster
	docker run -d \
		   --name=cluster \
		   --link=mysql \
		   --link=redis \
		   --link=rmq \
		   --expose=8888 \
		   --expose=8000 \
		   --restart=always \
		   --env-file=$(pwd)/src/omega-cluster/deploy/env \
		   -e CLUSTER_REDIS_PW="" \
	           -e CLUSTER_LOGSTASH=${NET_IP}:4999 \
	           -e CLUSTER_MARKET_URL=${NET_IP}:8001 \
	           -e CLUSTER_DASHBOARD_URL=${NET_IP}:8000 \
	           -e CLUSTER_DOCKER_AUTH_SITE=${NET_IP} \
		   cluster:env
}

build_app() {
	base=$(pwd)
	export GOPATH="/usr/local/go"
	mkdir -p /usr/local/go/src/github.com/Dataman-Cloud
	rm -rf /usr/local/go/src/github.com/Dataman-Cloud/omega-app
	cp -r ${base}/src/omega-app /usr/local/go/src/github.com/Dataman-Cloud/
	cd /usr/local/go/src/github.com/Dataman-Cloud/omega-app
	make build
	cp bin/omega-app ${base}/src/omega-app/ 
	cd ${base}/src
        docker build -t omega-app:env -f omega-app/dockerfiles/Dockerfile_runtime .
	cd ..
}

start_app() {
	docker rm -f app > /dev/null 2>&1
	docker run -d \
		   --name=app \
		   --restart=always \
		   --link=mysql \
		   --link=redis \
		   --link=rmq \
		   --link=cluster \
		   --env-file=$(pwd)/src/omega-app/deploy/env \
	           -e APP_CLUSTER_HOST=cluster:8888 \
	           omega-app:env
}

build_metrics() {
	base=$(pwd)
	export GOPATH="/usr/local/go"
	mkdir -p /usr/local/go/src/github.com/Dataman-Cloud
	rm -rf /usr/local/go/src/github.com/Dataman-Cloud/omega-metrics
	cp -r ${base}/src/omega-metrics /usr/local/go/src/github.com/Dataman-Cloud/
	cd /usr/local/go/src/github.com/Dataman-Cloud/omega-metrics
	make build
	cp omega-metrics ${base}/src/omega-metrics/ 
	cd ${base}/src
        docker build -t omega-metrics:env -f omega-metrics/dockerfiles/Dockerfile_runtime .
	cd ..
}

build_logging() {
	base=$(pwd)
	export GOPATH="/usr/local/go"
	mkdir -p /usr/local/go/src/github.com/Dataman-Cloud
	rm -rf /usr/local/go/src/github.com/Dataman-Cloud/omega-es
	cp -r ${base}/src/omega-es /usr/local/go/src/github.com/Dataman-Cloud/
	cd /usr/local/go/src/github.com/Dataman-Cloud/omega-es
	make build
	cp omega-es ${base}/src/omega-es/ 
	cd ${base}/src
        docker build -t omega-es:env -f omega-es/dockerfiles/Dockerfile_runtime .
	cd ..
}

build_billing() {
	base=$(pwd)
	export GOPATH="/usr/local/go"
	mkdir -p /usr/local/go/src/github.com/Dataman-Cloud
	rm -rf /usr/local/go/src/github.com/Dataman-Cloud/omega-billing
	cp -r ${base}/src/omega-billing /usr/local/go/src/github.com/Dataman-Cloud/
	cd /usr/local/go/src/github.com/Dataman-Cloud/omega-billing
	make build
	cp omega-billing ${base}/src/omega-billing/ 
	cd ${base}/src
        docker build -t omega-billing:env -f omega-billing/dockerfiles/Dockerfile_runtime .
	cd ..
}

build_alert() {
	base=$(pwd)
	export GOPATH="/usr/local/go"
	mkdir -p /usr/local/go/src/github.com/Dataman-Cloud
	rm -rf /usr/local/go/src/github.com/Dataman-Cloud/sryun-alert
	cp -r ${base}/src/sryun-alert /usr/local/go/src/github.com/Dataman-Cloud/
	cd /usr/local/go/src/github.com/Dataman-Cloud/sryun-alert
	make build
	cp bin/sryun-alert ${base}/src/sryun-alert/
	cd ${base}/src
        docker build -t sryun-alert:env -f sryun-alert/dockerfiles/Dockerfile_runtime .
	cd ..
}

start_logging() {
	docker rm -f logging > /dev/null 2>&1
        docker run -d \
		   --name=logging \
		   --restart=always \
		   --link=redis \
		   --link=mysql \
		   --link=elasticsearch \
		   --env-file=$(pwd)/src/omega-es/deploy/env \
		   omega-es:env
}

start_metrics() {
	docker rm -f metrics > /dev/null 2>&1
	docker run -d \
		   --name=metrics \
		   --restart=always \
		   --link=app \
		   --link=redis \
		   --link=rmq \
		   --link=influxdb \
		   --env-file=$(pwd)/src/omega-metrics/deploy/env \
	           -e METRICS_OMEGA_APP_HOST=http://app \
		   omega-metrics:env
}

start_billing() {
	docker rm -f billing > /dev/null 2>&1
        docker run -d \
		   --name=billing \
		   --restart=always \
		   --link=mysql \
		   --link=redis \
		   --link=rmq \
		   --env-file=$(pwd)/src/omega-billing/deploy/env \
		   omega-billing:env
}

start_alert() {
	docker rm -f alert > /dev/null 2>&1
        docker run -d \
		   --name=alert \
		   --restart=always \
		   --link=mysql \
		   --link=influxdb \
		   --link=cluster \
		   --link=redis \
		   --link=app \
		   --env-file=$(pwd)/src/sryun-alert/deploy/env \
		   sryun-alert:env
}

build_frontend() {
	cd src/frontend/glance
	sh compress.sh
	cd ../..
	tar -cvzf frontend.tar.gz frontend
        docker build -t frontend:env -f frontend/dockerfiles/Dockerfile_runtime .
	cd ..
}

start_frontend() {
        docker rm -f frontend > /dev/null 2>&1
        docker run -d \
		   --name=frontend \
		   --restart=always \
		   --link=cluster \
		   --link=app \
		   --link=logging \
		   --link=billing \
		   --link=metrics \
		   --link=elasticsearch \
		   --link=alert \
		   -p 8000:80 \
		   frontend:env
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

# install_redis
# install_rmq
# install_mysql
# install_influxdb
# install_elasticsearch
# install_logstash
# update_repositories
# install_harbor
# build_cluster
# build_app
# build_metrics
# build_logging
# build_billing
# build_alert
build_frontend
# start_cluster
# start_app
# start_metrics
# start_logging
# start_billing
# start_alert
start_frontend

