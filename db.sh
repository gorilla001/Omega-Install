#!/bin/bash

mysql -hmysql -uroot -p${MYSQL_ENV_MYSQL_ROOT_PASSWORD} --execute="create database alarm;" \
                                                        --execute="create database oapp;" \
                                                        --execute="create database alert;" \
                                                        --execute="create database drone;" \
                                                        --execute="create database billing;" \
                                                        --execute="create database registry;" \

