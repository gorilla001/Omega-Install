#!/bin/bash



mysql -hmysql -uroot -p111111 --execute="create database alarm;"
mysql -hmysql -uroot -p111111 --execute="create database oapp;"
mysql -hmysql -uroot -p111111 --execute="create database alert;"
mysql -hmysql -uroot -p111111 --execute="create database drone;"
mysql -hmysql -uroot -p111111 --execute="create database billing;"
mysql -hmysql -uroot -p111111 --execute="create database registry;"

