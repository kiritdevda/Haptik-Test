# Copyright (C) 2013 - 2019 Teddysun <i@teddysun.com>
# 
# This file is part of the LAMP script.
#
# LAMP is a powerful bash script for the installation of 
# Apache + PHP + MySQL/MariaDB/Percona and so on.
# You can install Apache + PHP + MySQL/MariaDB/Percona in an very easy way.
# Just need to input numbers to choose what you want to install before installation.
# And all things will be done in a few minutes.
#
# Website:  https://lamp.sh
# Github:   https://github.com/teddysun/lamp

#Pre-installation mysql or mariadb or percona
mysql_preinstall_settings(){


    if [ "${mysql}" != "do_not_install" ];then
            #mysql data
            echo
            read -p "mysql data location(default:${mysql_location}/data, leave blank for default): " mysql_data_location
            mysql_data_location=${mysql_data_location:=${mysql_location}/data}
            mysql_data_location=$(filter_location "${mysql_data_location}")
            echo
            echo "mysql data location: ${mysql_data_location}"

            #set mysql server root password
            echo
            read -p "mysql server root password (default:lamp.sh, leave blank for default): " mysql_root_pass
            mysql_root_pass=${mysql_root_pass:=lamp.sh}
            echo
            echo "mysql server root password: ${mysql_root_pass}"


            echo
            read -p "mysql server wordpress user password (default:wordpresspass, leave blank for default): " mysql_word_press_password
            mysql_word_press_password=${mysql_word_press_password:=wordpresspass}
            echo
            echo "mysql server wordpress user  password: ${mysql_word_press_password}"

    fi
}

#Install Database common
common_install(){

    local apt_list=(libncurses5-dev cmake m4 bison libaio1 libaio-dev numactl)
    local yum_list=(ncurses-devel cmake m4 bison libaio libaio-devel numactl-devel libevent)
    if is_64bit; then
        local perl_data_dumper_url="${download_root_url}/perl-Data-Dumper-2.125-1.el6.rf.x86_64.rpm"
    else
        local perl_data_dumper_url="${download_root_url}/perl-Data-Dumper-2.125-1.el6.rf.i686.rpm"
    fi
    _info "Starting to install dependencies packages for Database..."
    if check_sys packageManager apt; then
        for depend in ${apt_list[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
    elif check_sys packageManager yum; then
        for depend in ${yum_list[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
        if centosversion 6; then
            rpm -q perl-Data-Dumper > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                _info "Starting to install package perl-Data-Dumper"
                rpm -Uvh ${perl_data_dumper_url} > /dev/null 2>&1
                [ $? -ne 0 ] && _error "Install package perl-Data-Dumper failed"
            fi
        else
            error_detect_depends "yum -y install perl-Data-Dumper"
        fi
        if echo $(get_opsy) | grep -Eqi "fedora"; then
            error_detect_depends "yum -y install ncurses-compat-libs"
        fi
    fi
    _info "Install dependencies packages for Database completed..."

    id -u mysql >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin mysql

    mkdir -p ${mysql_location} ${mysql_data_location}
    
}

#create mysql cnf
create_mysql_my_cnf(){

    local mysqlDataLocation=${1}
    local binlog=${2}
    local replica=${3}
    local my_cnf_location=${4}

    local memory=512M
    local storage=InnoDB
    local totalMemory=$(awk 'NR==1{print $2}' /proc/meminfo)
    if [[ ${totalMemory} -lt 393216 ]]; then
        memory=256M
    elif [[ ${totalMemory} -lt 786432 ]]; then
        memory=512M
    elif [[ ${totalMemory} -lt 1572864 ]]; then
        memory=1G
    elif [[ ${totalMemory} -lt 3145728 ]]; then
        memory=2G
    elif [[ ${totalMemory} -lt 6291456 ]]; then
        memory=4G
    elif [[ ${totalMemory} -lt 12582912 ]]; then
        memory=8G
    elif [[ ${totalMemory} -lt 25165824 ]]; then
        memory=16G
    else
        memory=32G
    fi

    case ${memory} in
        256M)innodb_log_file_size=32M;innodb_buffer_pool_size=64M;open_files_limit=512;table_open_cache=200;max_connections=64;;
        512M)innodb_log_file_size=32M;innodb_buffer_pool_size=128M;open_files_limit=512;table_open_cache=200;max_connections=128;;
        1G)innodb_log_file_size=64M;innodb_buffer_pool_size=256M;open_files_limit=1024;table_open_cache=400;max_connections=256;;
        2G)innodb_log_file_size=64M;innodb_buffer_pool_size=512M;open_files_limit=1024;table_open_cache=400;max_connections=300;;
        4G)innodb_log_file_size=128M;innodb_buffer_pool_size=1G;open_files_limit=2048;table_open_cache=800;max_connections=400;;
        8G)innodb_log_file_size=256M;innodb_buffer_pool_size=2G;open_files_limit=4096;table_open_cache=1600;max_connections=400;;
        16G)innodb_log_file_size=512M;innodb_buffer_pool_size=4G;open_files_limit=8192;table_open_cache=2000;max_connections=512;;
        32G)innodb_log_file_size=512M;innodb_buffer_pool_size=8G;open_files_limit=65535;table_open_cache=2048;max_connections=1024;;
        *) echo "input error, please input a number";;
    esac

    if ${binlog}; then
        binlog="# BINARY LOGGING #\nlog-bin = ${mysqlDataLocation}/mysql-bin\nserver-id = 1\nexpire-logs-days = 14\nsync-binlog = 1"
        binlog=$(echo -e $binlog)
    else
        binlog=""
    fi

    if ${replica}; then
        replica="# REPLICATION #\nrelay-log = ${mysqlDataLocation}/relay-bin\nslave-net-timeout = 60"
        replica=$(echo -e $replica)
    else
        replica=""
    fi

    _info "create my.cnf file..."
    cat >${my_cnf_location} <<EOF
[mysql]

# CLIENT #
port                           = 3306
socket                         = /tmp/mysql.sock

[mysqld]
# GENERAL #
port                           = 3306
user                           = mysql
default-storage-engine         = ${storage}
socket                         = /tmp/mysql.sock
pid-file                       = ${mysqlDataLocation}/mysql.pid
skip-name-resolve
skip-external-locking

# INNODB #
innodb-log-files-in-group      = 2
innodb-log-file-size           = ${innodb_log_file_size}
innodb-flush-log-at-trx-commit = 2
innodb-file-per-table          = 1
innodb-buffer-pool-size        = ${innodb_buffer_pool_size}

# CACHES AND LIMITS #
tmp-table-size                 = 32M
max-heap-table-size            = 32M
max-connections                = ${max_connections}
thread-cache-size              = 50
open-files-limit               = ${open_files_limit}
table-open-cache               = ${table_open_cache}

# SAFETY #
max-allowed-packet             = 16M
max-connect-errors             = 1000000

# DATA STORAGE #
datadir                        = ${mysqlDataLocation}

# LOGGING #
log-error                      = ${mysqlDataLocation}/mysql-error.log

${binlog}

${replica}

EOF

    _info "create my.cnf file at ${my_cnf_location} completed."

}


common_setup(){

    rm -f /usr/bin/mysql /usr/bin/mysqldump /usr/bin/mysqladmin
    rm -f /etc/ld.so.conf.d/mysql.conf


    local db_name="MySQL"
    local db_pass="${mysql_root_pass}"
    ln -s ${mysql_location}/bin/mysql /usr/bin/mysql
    ln -s ${mysql_location}/bin/mysqldump /usr/bin/mysqldump
    ln -s ${mysql_location}/bin/mysqladmin /usr/bin/mysqladmin
    cp -f ${mysql_location}/support-files/mysql.server /etc/init.d/mysqld
    sed -i "s:^basedir=.*:basedir=${mysql_location}:g" /etc/init.d/mysqld
    sed -i "s:^datadir=.*:datadir=${mysql_data_location}:g" /etc/init.d/mysqld
    create_lib64_dir "${mysql_location}"
    echo "${mysql_location}/lib" >> /etc/ld.so.conf.d/mysql.conf
    echo "${mysql_location}/lib64" >> /etc/ld.so.conf.d/mysql.conf


    ldconfig
    chmod +x /etc/init.d/mysqld
    boot_start mysqld

    _info "Starting ${db_name}..."
    /etc/init.d/mysqld start > /dev/null 2>&1
    if [ "${mysql}" == "${mysql8_0_filename}" ]; then
        /usr/bin/mysql -uroot -hlocalhost -e "create user 'root'@'127.0.0.1' identified by \"${db_pass}\";"
        /usr/bin/mysql -uroot -hlocalhost -e "grant all privileges on *.* to 'root'@'127.0.0.1' with grant option;"
        /usr/bin/mysql -uroot -hlocalhost -e "grant all privileges on *.* to 'root'@'localhost' with grant option;"
        /usr/bin/mysql -uroot -hlocalhost -e "alter user 'root'@'localhost' identified by \"${db_pass}\";"
    else
        /usr/bin/mysql -e "grant all privileges on *.* to 'root'@'127.0.0.1' identified by \"${db_pass}\" with grant option;"
        /usr/bin/mysql -e "grant all privileges on *.* to 'root'@'localhost' identified by \"${db_pass}\" with grant option;"
        /usr/bin/mysql -uroot -p${db_pass} <<EOF
drop database if exists test;
delete from mysql.db where user='';
create user '${mysql_word_press_user}'@'127.0.0.1' identified by "${mysql_word_press_password}"
create user '${mysql_word_press_user}'@'localhost' identified by "${mysql_word_press_password}"
CREATE DATABASE ${mysql_word_press_db};
flush privileges;
exit
EOF
    fi

    if [ "${mysql}" == "${mysql8_0_filename}" ]; then
        /usr/bin/mysql -uroot -p${db_pass} <<EOF
create user '${mysql_word_press_user}'@'127.0.0.1' identified by "${mysql_word_press_password}";
create user '${mysql_word_press_user}'@'localhost' identified by "${mysql_word_press_password}";
CREATE DATABASE wp_myblog;
grant all privileges on ${mysql_word_press_db}.* to '${mysql_word_press_user}'@'127.0.0.1';
grant all privileges on ${mysql_word_press_db}.* to '${mysql_word_press_user}'@'localhost';
flush privileges;
exit
EOF
    else
        /usr/bin/mysql -uroot -p${db_pass} <<EOF
grant all privileges on ${mysql_word_press_db}.* to ${mysql_word_press_user}@'127.0.0.1' identified by "${mysql_word_press_password}" with grant option;
grant all privileges on ${mysql_word_press_db}.* to ${mysql_word_press_user}@'localhost' identified by "${mysql_word_press_password}" with grant option;
flush privileges;
exit
EOF
    fi    

    _info "Shutting down ${db_name}..."
    /etc/init.d/mysqld stop > /dev/null 2>&1

}

#Install mysql server
install_mysqld(){

    common_install

    is_64bit && sys_bit=x86_64 || sys_bit=i686
    mysql_ver=$(echo ${mysql} | sed 's/[^0-9.]//g' | cut -d. -f1-2)
    cd ${cur_dir}/software/
    _info "Downloading and Extracting MySQL files..."

    mysql_filename="${mysql}-linux-glibc2.12-${sys_bit}"
    if [ "${mysql_ver}" == "8.0" ]; then
        mysql_filename_url="https://cdn.mysql.com/Downloads/MySQL-${mysql_ver}/${mysql_filename}.tar.xz"
        download_file "${mysql_filename}.tar.xz" "${mysql_filename_url}"
        tar Jxf ${mysql_filename}.tar.xz
    else
        mysql_filename_url="https://cdn.mysql.com/Downloads/MySQL-${mysql_ver}/${mysql_filename}.tar.gz"
        download_file "${mysql_filename}.tar.gz" "${mysql_filename_url}"
        tar zxf ${mysql_filename}.tar.gz
    fi

    _info "Moving MySQL files..."
    mv ${mysql_filename}/* ${mysql_location}

    config_mysql ${mysql_ver}

    add_to_env "${mysql_location}"
}

#Configuration mysql
config_mysql(){
    local version=${1}

    if [ -f /etc/my.cnf ];then
        mv /etc/my.cnf /etc/my.cnf.bak
    fi
    [ -d '/etc/mysql' ] && mv /etc/mysql{,_bk}

    chown -R mysql:mysql ${mysql_location} ${mysql_data_location}

    #create my.cnf
    create_mysql_my_cnf "${mysql_data_location}" "false" "false" "/etc/my.cnf"

    if [ "${version}" == "8.0" ]; then
        echo "default_authentication_plugin  = mysql_native_password" >> /etc/my.cnf
    fi
    if [ "${version}" == "5.5" ] || [ "${version}" == "5.6" ]; then
        ${mysql_location}/scripts/mysql_install_db --basedir=${mysql_location} --datadir=${mysql_data_location} --user=mysql
    elif [ "${version}" == "5.7" ] || [ "${version}" == "8.0" ]; then
        ${mysql_location}/bin/mysqld --initialize-insecure --basedir=${mysql_location} --datadir=${mysql_data_location} --user=mysql
    fi

    common_setup

}


