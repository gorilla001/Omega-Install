#!/bin/bash

# NET_IF=`netstat -rn | awk '/^0.0.0.0/ {thif=substr($0,74,10); print thif;} /^default.*UG/ {thif=substr($0,65,10); print thif;}'`
#     
# NET_IP=`ifconfig ${NET_IF} | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

# if [ -z "`which pip`" ]; then
#     apt-get update && apt-get install -y python-pip
# fi

if [ -z "`which docker`" ]; then
	curl -sSL https://get.docker.com/ | sh
fi
# if [ -z "`which docker`" ]; then
#     curl -sSL https://coding.net/u/upccup/p/dm-agent-installer/git/raw/master/install-docker.sh | sh
# else
#     [ "$(docker --version | cut -d" " -f3 | tr -d ',')" != "1.9.1" ] && apt-get remove -y docker-engine && {
#    	curl -sSL https://coding.net/u/upccup/p/dm-agent-installer/git/raw/master/install-docker.sh | sh
#     }	
# fi

NET_IP=`docker run --rm --net=host alpine ip route get 8.8.8.8 | awk '{ print $7;  }'`
PORT=8000

pull_repositories() {
    git submodule init 
    git submodule update --remote 
    [ $? -ne 0 ] && exit 
}

install_redis() {
	docker rm -fv redis > /dev/null 2>&1
	docker pull demoregistry.dataman-inc.com/srypoc/redis:3.0.5
        docker run -d \
                  --expose=6379 \
                  --restart=always \
                  --name=redis \
		  demoregistry.dataman-inc.com/srypoc/redis:3.0.5 redis-server --appendonly yes
}       

install_rmq() {
	docker rm -fv rmq > /dev/null 2>&1
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

install_mysql() {
	docker rm -f mysql > /dev/null 2>&1
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

install_influxdb() {
	docker rm -f influxdb > /dev/null 2>&1
	docker pull demoregistry.dataman-inc.com/srypoc/influxdb:0.10
	docker run -d \
		   -e PRE_CREATE_DB=shurenyun \
                   --restart=always \
                   --name=influxdb \
                   demoregistry.dataman-inc.com/srypoc/influxdb:0.10
}

install_elasticsearch() {
	docker rm -f elasticsearch > /dev/null 2>&1
	docker pull demoregistry.dataman-inc.com/srypoc/centos7-jdk7-elasticsearch-1.4.5-alone:20160522230210
	docker run -d \
                   --name=elasticsearch \
                   --restart=always \
                   -e ES_MIN_MEM=1024M \
                   -e ES_MAX_MEM=1024M \
		   -p 9200:9200 \
		   -p 9300:9300 \
                   demoregistry.dataman-inc.com/srypoc/centos7-jdk7-elasticsearch-1.4.5-alone:20160522230210
}

install_logstash() {
	docker rm -f logstash > /dev/null 2>&1
        docker pull demoregistry.dataman-inc.com/srypoc/logstash:1.5.6
        docker run -d \
                   --name=logstash \
                   --restart=always \
		   -p 4999:4999 \
                   --link=elasticsearch \
                   -v $(pwd)/src/omega-es/third_party/logstash/dataman.conf:/etc/logstash/conf.d/dataman.conf:ro \
                   -v $(pwd)/src/omega-es/third_party/logstash/logstash.json:/usr/local/logstash/conf/logstash.json:ro \
                   demoregistry.dataman-inc.com/srypoc/logstash:1.5.6 logstash -f /etc/logstash/conf.d/dataman.conf
}

build_harbor() {
	base=$(pwd)
	cd ${base}/src/harbor
	complie=$(cat /dev/urandom | tr -dc 'a-fA-F0-9' | fold -w 8 | head -n 1)
	docker pull demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500
	docker run --rm \
                    -v $(pwd):/usr/local/go/src/github.com/vmware/harbor \
                    -w /usr/local/go/src/github.com/vmware/harbor \
                    -e GOPATH="/usr/local/go" \
                    demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500 /bin/bash -c "make localbuild"
	cd $base/src
        docker build -t harbor:env -f harbor/dockerfiles/Dockerfile_runtime . 
	cd $base 
}
start_harbor() {
	docker rm -f harbor > /dev/null 2>&1
        docker run -d  \
		   --name=harbor \
		   --restart=always \
		   --link=redis \
		   --link=mysql \
		   --add-host=registry:${NET_IP} \
		   -p 5005:5005 \
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

start_registry() {
	docker rm -f registry > /dev/null 2>&1
	docker pull demoregistry.dataman-inc.com/srypoc/registry:2.3.0
	docker run -d \
		   --name=registry \
		   --link=harbor \
		   --restart=always \
		   -p 5001:5001 \
		   -p 5000:5000 \
		   -v $(pwd)/src/harbor/Deploy/Omega/registry/:/etc/registry/ \
		   demoregistry.dataman-inc.com/srypoc/registry:2.3.0 /etc/registry/config.yml
}

build_drone() {
	cd src
	image=$(tail -n 1 drone/dockerfiles/Dockerfile_compile_env | tr -d "#")
	docker pull ${image}
        docker run --rm \
		    -v $(pwd)/drone/:/usr/share/go/src/github.com/drone/drone/ \
		    -e GOPATH="/usr/share/go" \
	            -w="/usr/share/go/src/github.com/drone/drone" ${image} /bin/bash -c "make gen && make build_static" 
	docker build -t drone:env -f drone/dockerfiles/Dockerfile_runtime .
	cd ..
}

start_drone() {
	docker rm -f drone > /dev/null 2>&1
	docker run -d \
		   --name=drone \
		   --restart=always \
		   --link=registry \
		   --link=mysql \
		   --link=harbor \
		   -p 9898:9898 \
		   -e SERVER_ADDR=0.0.0.0:9898 \
	           -e REMOTE_DRIVER=sryun \
	           -e REMOTE_CONFIG="https://omdev.riderzen.com:10080?open=true&skip_verify=true" \
	           -e RC_SRY_REG_INSECURE=true \
	           -e RC_SRY_REG_HOST=registry:5000 \
	           -e PUBLIC_MODE=true \
	           -e DATABASE_DRIVER=mysql \
	           -e DATABASE_CONFIG=root:111111@tcp\(mysql:3306\)/drone?parseTime=true \
	           -e AGENT_URI=registry:5000/library/drone-exec:latest \
	           -e PLUGIN_FILTER=registry:5000/library/*\tplugins/*\tregistry.shurenyun.com/*\tregistry.shurenyun.com/*\tdevregistry.dataman-inc.com/library/* \
	           -e PLUGIN_PREFIX=library \
	           -e DOCKER_STORAGE=overlay \
	           -e DOCKER_EXTRA_HOSTS=registry:registry\tharbor:harbor \
		   drone:env
}

build_cluster() {
	cd src
	image="demoregistry.dataman-inc.com/library/python34:v0.1.063001"
	docker pull ${image}
        # docker build -t demoregistry.dataman-inc.com/library/python34:v0.1.063001 -f omega-cluster/dockerfiles/Dockerfile_compile_env .
	docker build -t cluster:env -f omega-cluster/dockerfiles/Dockerfile_runtime .
	cd ..
}

start_cluster() {
	docker rm -f cluster > /dev/null 2>&1
	docker run -d \
		   --name=cluster \
		   --link=mysql \
		   --link=redis \
		   --link=rmq \
		   --expose=8888 \
		   --restart=always \
		   --add-host=alert:${NET_IP} \
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
	cd ${base}/src/omega-app
	docker pull demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500
	docker run --rm \
                    -v $(pwd):/usr/local/go/src/github.com/Dataman-Cloud/omega-app \
                    -w /usr/local/go/src/github.com/Dataman-Cloud/omega-app \
                    -e GOPATH="/usr/local/go" \
		    -e GO15VENDOREXPERIMENT=1 \
                    demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500 /bin/bash -c "make build"
	install bin/omega-app ${base}/src/omega-app/ 
	cd $base/src

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
	cd ${base}/src/omega-metrics
	docker pull demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500
	docker run --rm \
                    -v $(pwd):/usr/local/go/src/github.com/Dataman-Cloud/omega-metrics \
                    -w /usr/local/go/src/github.com/Dataman-Cloud/omega-metrics \
                    -e GOPATH="/usr/local/go" \
                    demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500 /bin/bash -c "make build"
	# "yum install git -y && export PATH=$PATH:$GOPATH/bin && go get -u github.com/FiloSottile/gvt && gvt update && go get github.com/influxdata/influxdb/client/v2 && make build"
	cd $base/src
        docker build -t omega-metrics:env -f omega-metrics/dockerfiles/Dockerfile_runtime .
	cd ..
}

build_logging() {
	base=$(pwd)
	cd ${base}/src/omega-es
	docker pull demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500
	docker run --rm \
                    -v $(pwd):/usr/local/go/src/github.com/Dataman-Cloud/omega-es\
                    -w /usr/local/go/src/github.com/Dataman-Cloud/omega-es\
                    -e GOPATH="/usr/local/go" \
                    demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500 /bin/bash -c "make build"
	cd $base/src
        docker build -t omega-es:env -f omega-es/dockerfiles/Dockerfile_runtime .
	cd ..
}

build_billing() {
	base=$(pwd)
	cd ${base}/src/omega-billing
	docker pull demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500
	docker run --rm \
                    -v $(pwd):/usr/local/go/src/github.com/Dataman-Cloud/omega-billing\
                    -w /usr/local/go/src/github.com/Dataman-Cloud/omega-billing\
                    -e GOPATH="/usr/local/go" \
                    demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500 /bin/bash -c "make build"
	cd $base/src
        docker build -t omega-billing:env -f omega-billing/dockerfiles/Dockerfile_runtime .
	cd ..
}

build_alert() {
	base=$(pwd)
	cd ${base}/src/sryun-alert
	docker pull demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500
	docker run --rm \
                    -v $(pwd):/usr/local/go/src/github.com/Dataman-Cloud/sryun-alert \
                    -w /usr/local/go/src/github.com/Dataman-Cloud/sryun-alert \
                    -e GOPATH="/usr/local/go" \
                    demoregistry.dataman-inc.com/library/centos7-go1.5.4:v0.1.061500 /bin/bash -c "make build"
	cp bin/sryun-alert ${base}/src/sryun-alert/
	cd $base/src
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
	app=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" app)
	docker run -d \
		   --name=metrics \
		   --restart=always \
		   --link=redis \
		   --link=rmq \
		   --link=influxdb \
		   --env-file=$(pwd)/src/omega-metrics/deploy/env \
	           -e METRICS_OMEGA_APP_HOST=http://${app} \
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
	mysql=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" mysql)
	influxdb=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" influxdb)
	cluster=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" cluster)
	redis=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" redis)
	app=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" app)
        docker run -d \
		   --name=alert \
		   --restart=always \
		   --net=host \
		   -e ALERT_DB_DRIVER=mysql \
           	   -e ALERT_KAPACITOR_INFLUXDB=http://${influxdb}:5008 \
           	   -e ALERT_KAPACITOR_CONF=/etc/sryun-alert/kapacitor.conf \
           	   -e ALERT_DB_PORT=3306 \
           	   -e ALERT_DB_NAME=alert \
           	   -e ALERT_RETENTIONPOLICY=default \
           	   -e ALERT_INTERNAL_TOKEN_KEY=Sry-Svc-Token \
           	   -e ALERT_INFLUX_ADDR=http://${influxdb}:5008 \
           	   -e ALERT_CACHE_POLLSIZE=100 \
           	   -e ALERT_INFLUX_SERIE=ALERT_EVENTS \
           	   -e ALERT_KAPACITOR_HOSTNAME=${NET_IP} \
           	   -e ALERT_MONITOR_TABLE=Slave_state \
           	   -e ALERT_CACHE_ADDR=${redis}:6379 \
           	   -e ALERT_DB_USER=root \
           	   -e ALERT_DB_PASSWORD=111111 \
           	   -e ALERT_INFLUX_PASSWORD=root \
           	   -e ALERT_SMTP_ADDR=http://${cluster}:8888/api/v3/email \
           	   -e ALERT_TRIFFIC_TABLE=app_req_rate \
           	   -e ALERT_AUTH_ADDR=http://${cluster}:8888/api/v3/user \
           	   -e ALERT_NET_HOST=0.0.0.0 \
           	   -e ALERT_INFLUX_USERNAME=root \
           	   -e ALERT_DB_HOST=${mysql} \
           	   -e ALERT_APP_ADDR=http://${app}:6080 \
           	   -e ALERT_NET_PORT=5012 \
           	   -e ALERT_INFLUX_DATABASE=shurenyun \
		   sryun-alert:env
}

build_frontend() {
	cd src
	docker_file=$(cat /dev/urandom | tr -dc 'a-fA-F0-9' | fold -w 8 | head -n 1)
	update_settings=$(cat /dev/urandom | tr -dc 'a-fA-F0-9' | fold -w 8 | head -n 1)
	entrypoint=$(cat /dev/urandom | tr -dc 'a-fA-F0-9' | fold -w 8 | head -n 1)
	cat <<-'EOF' > ${update_settings}  
	#!/bin/bash
	sed -i "s#APIURL#$FRONTEND_APIURL#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#MARKET#$FRONTEND_MARKET#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#STREAMING#$FRONTEND_STREAMING#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#ENVIRONMENT#$FRONTEND_ENVIRONMENT#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#OFFLINE#$FRONTEND_OFFLINE#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#LOCAL_DM_HOST#$FRONTEND_LOCAL_DM_HOST#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#AGENT_URL#$FRONTEND_AGENT_URL#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#BODY_DOMAIN#$FRONTEND_BODY_DOMAIN#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#LICENCEON#$FRONTEND_LICENCEON#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#GROUP_URL#$FRONTEND_GROUP_URL#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#DEMO_URL#$FRONTEND_DEMO_URL#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#DEMO_USER#$FRONTEND_DEMO_USER#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#IMAGE_BASE_URL#$FRONTEND_IMAGE_BASE_URL#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#LOCAL_DM_HOST#$FRONTEND_LOCAL_DM_HOST#g" /usr/share/nginx/html/js/confdev.js
	sed -i "s#AGENT_URL#$FRONTEND_AGENT_URL#g" /usr/share/nginx/html/js/confdev.js
	EOF
	cat <<-EOF > ${entrypoint}
	#!/bin/bash
	set -x
	#check set config script
	if [ ! -f /update.sh ]; then
	    echo "update.sh doesn't exists." && exit
	fi
	# set js config
	cd / && ./update.sh
	# run nginx
	nginx -g "daemon off;"
	EOF
	cat <<-EOF > ${docker_file}
	FROM index.shurenyun.com/zqdou/nginx:1.9.6 
	COPY frontend/glance /usr/share/nginx/html/
	COPY frontend/conf/dataman/nginx.conf /etc/nginx/nginx.conf
	COPY frontend/conf/dataman/ssl/ssl_certificate.crt /etc/nginx/ssl_certificate.crt
	COPY frontend/conf/dataman/ssl/www.dataman.io-no-passphrase.key /etc/nginx/www.dataman.io-no-passphrase.key
	COPY ${update_settings} /update.sh 
	COPY ${entrypoint} /entrypoint.sh
	WORKDIR /
	RUN chmod +x update.sh entrypoint.sh
	ENTRYPOINT ["./entrypoint.sh"]
	EOF
        docker build -t frontend:env -f ${docker_file} .
	rm -f ${update_settings}
	rm -f ${entrypoint}
	rm -f ${docker_file}
	cd ..
	
}

start_frontend() {
        docker rm -f frontend > /dev/null 2>&1
	alert=$(docker inspect "--format='{{ .NetworkSettings.IPAddress }}'" alert)
        docker run -d \
		   --name=frontend \
		   --restart=always \
		   --link=cluster \
		   --link=logging \
		   --link=billing \
		   --link=metrics \
		   --link=elasticsearch \
		   --link=app \
		   --link=harbor \
		   --add-host=alert:${NET_IP} \
		   -p 8000:80 \
		   -e FRONTEND_APIURL=http://${NET_IP}:8000 \
		   -e FRONTEND_MARKET=http://${NET_IP}:8001 \
		   -e FRONTEND_STREAMING=ws://${NET_IP}:8000 \
		   -e FRONTEND_ENVIRONMENT=dev \
		   -e FRONTEND_OFFLINE=true \
		   -e FRONTEND_LOCAL_DM_HOST=DM_HOST=ws://${NET_IP}:8000 \
		   -e FRONTEND_LICENCEON=false \
		   -e FRONTEND_IMAGE_BASE_URL=http://${NET_IP}:8000 \
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

show_usage() {
	echo "Name:"
	echo -e "  install.sh - dataman cloud install script"
	echo
	echo "Usage:"
        echo -e "  ./install.sh [ help | all | base | metrics | alert | cluster | harbor | drone | logging | app | billing | frontend ]"
	echo
	echo "Commands:"
	echo -e "  help        show usage"
	echo -e "  all         install all components"
	echo -e "  base        install redis rmq mysql influxdb elasticsearch logstash"
	echo -e "  metrics     rebuild omega-metrics"
	echo -e "  alert       rebuild sryun-alert"
	echo -e "  cluster     rebuild omega-cluster"
	echo -e "  harbor      rebuild harbor"
	echo -e "  drone       rebuild drone"
	echo -e "  logging     rebuild omega-es"
	echo -e "  app 	       rebuild omega-app"
	echo -e "  billing     rebuild omega-billing"
	echo -e "  frontend    rebuild frontend"
	echo
}


case $1 in
    help)
	    show_usage ;;
    base)
	    install_redis
	    install_rmq
	    install_mysql
	    install_influxdb
	    install_elasticsearch
	    install_logstash
	    ;;
    metrics)
        build_metrics && start_metrics ;;
    alert)
	build_alert && start_alert ;;
    cluster)
	build_cluster && start_cluster ;;
    frontend)
	build_frontend && start_frontend ;;
    harbor)
	build_harbor && start_harbor ;;
    drone)
	build_drone && start_drone ;;
    registry)
	start_registry ;;
    logging)
	build_logging && start_logging ;;
    app)
	build_app && start_app ;;
    billing)
	build_billing && start_billing ;;
    all)
	pull_repositories
	install_redis
	install_rmq
	install_mysql
	install_influxdb
	install_elasticsearch
	install_logstash
	
	build_harbor
	start_harbor
	
	start_registry
	
	build_drone
	start_drone
	
	build_cluster
	build_app
	build_metrics
	build_logging
	build_billing
	build_alert
	build_frontend
	start_cluster
	start_app
	start_metrics
	start_logging
	start_billing
	start_alert
	start_frontend
	install_cmdline_tools
	install_finish
	;;
    *) 
	show_usage ;;
esac

