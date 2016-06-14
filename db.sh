#!/bin/bash

mysql -hmysql -uroot -p${MYSQL_ENV_MYSQL_ROOT_PASSWORD} --execute="CREATE DATABASE IF NOT EXISTS alarm;" \
                                                        --execute="CREATE DATABASE IF NOT EXISTS oapp;" \
                                                        --execute="CREATE DATABASE IF NOT EXISTS alert;" \
                                                        --execute="CREATE DATABASE IF NOT EXISTS drone;" \
                                                        --execute="CREATE DATABASE IF NOT EXISTS billing;" \
                                                        --execute="CREATE DATABASE IF NOT EXISTS registry;" \

