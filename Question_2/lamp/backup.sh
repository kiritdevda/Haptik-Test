lamp/conf/                                                                                          000755  000765  000024  00000000000 13564465250 014237  5                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         lamp/conf/lamp                                                                                      000644  000765  000024  00000037417 13564465250 015127  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #!/usr/bin/env bash
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
# System Required:  CentOS 6+ / Fedora28+ / Debian 8+ / Ubuntu 14+
# Description:  Create, Delete, List Apache Virtual Host
# Website:  https://lamp.sh
# Github:   https://github.com/teddysun/lamp

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

apache_location=/usr/local/apache
mysql_location=/usr/local/mysql
mariadb_location=/usr/local/mariadb
percona_location=/usr/local/percona
web_root_dir=/data/www/default

rootness(){
    if [[ ${EUID} -ne 0 ]]; then
        echo -e "\033[31mError:\033[0m This script must be run as root" 1>&2
        exit 1
    fi
}

vhost(){
    local action=$1
    case ${action} in
        add ) vhost_add;;
        list ) vhost_list;;
        del ) vhost_del;;
        *) echo "action ${action} not found";exit 1;;
    esac
}

db_name(){
    if [ -d ${mysql_location} ]; then
        echo "MySQL"
    elif [ -d ${mariadb_location} ]; then
        echo "MariaDB"
    elif [ -d ${percona_location} ]; then
        echo "Percona"
    else
        echo "MySQL"
    fi
}

set_apache_allow_syntax(){
    if [ -s /usr/sbin/httpd ]; then
        if /usr/sbin/httpd -v | grep -q "Apache/2.4"; then
            allow_from_all="Require all granted"
        else
            echo -e "\033[31mError:\033[0m Can not get Apache version..."
            exit 1
        fi
    else
        echo -e "\033[31mError:\033[0m Can not find Apache, may be not installed. Please check it and try again."
        exit 1
    fi
}

check_email(){
    regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
    if [[ ${1} =~ ${regex} ]]; then
        return 0
    else
        return 1
    fi
}

filter_location(){
    local location=${1}
    if ! echo ${location} | grep -q "^/"; then
        while true
        do
            read -p "Please enter a correct location: " location
            echo ${location} | grep -q "^/" && echo ${location} && break
        done
    else
        echo ${location}
    fi
}

vhost_add(){
    set_apache_allow_syntax

    while :
    do
        read -p "Please enter server names (for example: lamp.sh www.lamp.sh): " server_names
        for i in ${server_names}; do
            if apache_vhost_is_exist ${i}; then
                echo -e "\033[31mError:\033[0m virtual host [${i}] is existed, please check it and try again."
                break
            fi
            break 2
        done
    done

    default_root="/data/www/${server_names%% *}"
    read -p "Please enter website root directory(default:$default_root): " website_root
    website_root=${website_root:=$default_root}
    website_root=$(filter_location "${website_root}")
    echo "website root directory: ${website_root}"
    echo
    php_admin_value=""
    if [ -s /usr/bin/php ]; then
        php_admin_value="php_admin_value open_basedir ${website_root}:/tmp:/var/tmp:/proc"
        if [ -d "${web_root_dir}/phpmyadmin" ]; then
            php_admin_value="${php_admin_value}:${web_root_dir}/phpmyadmin"
        fi
        if [ -d "${web_root_dir}/kod" ]; then
            php_admin_value="${php_admin_value}:${web_root_dir}/kod"
        fi
    fi

    while :
    do
        read -p "Please enter Administrator Email address: " email
        if [ -z "${email}" ]; then
            echo -e "\033[31mError:\033[0m Administrator Email address can not be empty."
        elif check_email ${email}; then
            echo "Administrator Email address:${email}"
            echo
            break
        else
            echo -e "\033[31mError:\033[0m Please enter a correct email address."
        fi
    done

    while :
    do
        read -p "Do you want to create a database and mysql user with same name? [y/n]:" create
        case ${create} in
        y|Y)
            if [ ! "$(command -v "mysql")" ]; then
                echo -e "\033[31mError:\033[0m $(db_name) is not installed, please check it and try again."
                exit 1
            fi
            mysql_count=$(ps -ef | grep -v grep | grep -c "mysqld")
            if [ ${mysql_count} -eq 0 ]; then
                echo "Info: $(db_name) looks like not running, Try to starting $(db_name)..."
                /etc/init.d/mysqld start > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    echo -e "\033[31mError:\033[0m $(db_name) starting failed!"
                    exit 1
                fi
            fi
            read -p "Please enter your $(db_name) root password:" mysqlroot_passwd
            mysql -uroot -p${mysqlroot_passwd} <<EOF
exit
EOF
            if [ $? -ne 0 ]; then
                echo -e "\033[31mError:\033[0m $(db_name) root password incorrect! Please check it and try again."
                exit 1
            fi
            read -p "Please enter the database name:" dbname
            [ -z ${dbname} ] && echo -e "\033[31mError:\033[0m database name can not be empty." && exit 1
            read -p "Please set the password for user ${dbname}:" mysqlpwd
            echo
            [ -z ${mysqlpwd} ] && echo -e "\033[31mError:\033[0m user password can not be empty." && exit 1
            create="y"
            break
            ;;
        n|N)
            echo "Do not create a database"
            echo
            create="n"
            break
            ;;
        *) echo "Please enter only y or n"
        esac
    done

    mkdir -p /data/wwwlog/${server_names%% *} ${website_root}

    cat > ${apache_location}/conf/vhost/${server_names%% *}.conf << EOF
<VirtualHost *:80>
    ServerAdmin ${email}
    ${php_admin_value}
    ServerName ${server_names%% *}
    ServerAlias ${server_names}
    DocumentRoot ${website_root}
    <Directory ${website_root}>
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Order Deny,Allow
        ${allow_from_all}
        DirectoryIndex index.php index.html index.htm
    </Directory>
    ErrorLog /data/wwwlog/${server_names%% *}/error.log
    CustomLog /data/wwwlog/${server_names%% *}/access.log combined
</VirtualHost>
EOF

    echo "Virtual host [${server_names%% *}] has been created"
    echo "Website root directory is: ${website_root}"

    if [ "$create" = "y" ]; then
        mysql -uroot -p${mysqlroot_passwd} <<EOF
CREATE DATABASE IF NOT EXISTS \`${dbname}\` CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON \`${dbname}\` . * TO '${dbname}'@'localhost' IDENTIFIED BY '${mysqlpwd}';
GRANT ALL PRIVILEGES ON \`${dbname}\` . * TO '${dbname}'@'127.0.0.1' IDENTIFIED BY '${mysqlpwd}';
FLUSH PRIVILEGES;
EOF
        echo "Database [${dbname}] and mysql user [${dbname}] has been created"
    fi

    echo "Reloading the apache config file..."
    if ${apache_location}/bin/apachectl -t; then
        /etc/init.d/httpd restart
        echo "Reload succeed"
        echo
    else
        echo -e "\033[31mError:\033[0m Reload failed. Apache config file had an error, please fix it and try again."
        exit 1
    fi

    read -p "Do you want to add a SSL certificate? [y/n]:" create_ssl
    if [ "${create_ssl}" = "y" ] || [ "${create_ssl}" = "Y" ]; then
        add_ssl_memu
        add_ssl_cert
        echo "Reloading the apache config file..."
        if ${apache_location}/bin/apachectl -t; then
            /etc/init.d/httpd restart
            echo "Reload succeed"
            echo
        else
            echo -e "\033[31mError:\033[0m Reload failed. Apache config file had an error, please fix it and try again."
        fi
    else
        echo "Do not add a SSL certificate"
        echo
    fi

    chown -R apache:apache /data/wwwlog/${server_names%% *} ${website_root}
    echo "All done"
}

add_ssl_memu(){
    echo -e "\033[32m1.\033[0m Use your own SSL Certificate and Key"
    echo -e "\033[32m2.\033[0m Use Let's Encrypt CA to create SSL Certificate and Key"
    echo -e "\033[32m3.\033[0m Use Buypass.com CA to create SSL Certificate and Key"
    while :
    do
        read -p "Please enter 1 or 2 or 3: " ssl_pick
        if [ "${ssl_pick}" = "1" ]; then
            while :
            do
            read -p "Please enter full path to SSL Certificate file: " ssl_certificate
            if [ -z "${ssl_certificate}" ]; then
                echo -e "\033[31mError:\033[0m SSL Certificate file can not be empty."
            elif [ -f "${ssl_certificate}" ]; then
                break
            else
                echo -e "\033[31mError:\033[0m ${ssl_certificate} does not exist or is not a file."
            fi
            done

            while :
            do
            read -p "Please enter full path to SSL Certificate Key file: " ssl_certificate_key
            if [ -z "${ssl_certificate_key}" ]; then
                echo -e "\033[31mError:\033[0m SSL Certificate Key file can not be empty."
            elif [ -f "${ssl_certificate_key}" ]; then
                break
            else
                echo -e "\033[31mError:\033[0m ${ssl_certificate_key} does not exist or is not a file."
            fi
            done
            break
        elif [ "${ssl_pick}" = "2" ]; then
            echo "You chosen Let's Encrypt CA, and it will be processed automatically"
            echo
            break
        elif [ "${ssl_pick}" = "3" ]; then
            echo "You chosen Buypass.com CA, and it will be processed automatically"
            echo
            break
        else
            echo -e "\033[31mError:\033[0m Please only enter 1 or 2 or 3"
        fi
    done

    read -p "Do you want force redirection from HTTP to HTTPS? [y/n]:" force_ssl
    if [ "${force_ssl}" = "y" ] || [ "${force_ssl}" = "Y" ]; then
        echo "You chosen force redirection from HTTP to HTTPS, and it will be processed automatically"
        echo
    else
        echo "Do not force redirection from HTTP to HTTPS"
        echo
    fi
}

create_ssl_config(){
    sed -i 's@#Include conf/extra/httpd-ssl.conf@Include conf/extra/httpd-ssl.conf@g' ${apache_location}/conf/httpd.conf
    cat >> ${apache_location}/conf/vhost/${server_names%% *}.conf << EOF
<VirtualHost *:443>
    ServerAdmin ${email}
    ${php_admin_value}
    DocumentRoot ${website_root}
    ServerName ${server_names%% *}
    ServerAlias ${server_names}
    SSLEngine on
    SSLCertificateFile ${ssl_certificate}
    SSLCertificateKeyFile ${ssl_certificate_key}
    <Directory ${website_root}>
        SetOutputFilter DEFLATE
        Options FollowSymLinks
        AllowOverride All
        Order Deny,Allow
        ${allow_from_all}
        DirectoryIndex index.php index.html index.htm
    </Directory>
    Header always set Strict-Transport-Security "max-age=31536000; preload"
    Header always edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options SAMEORIGIN
    ErrorLog  /data/wwwlog/${server_names%% *}/ssl_error.log
    CustomLog  /data/wwwlog/${server_names%% *}/ssl_access.log combined
</VirtualHost>
EOF
}

create_ssl_htaccess(){
    cat > ${website_root}/.htaccess << EOF
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R,L]
</IfModule>
EOF
}

check_lets_cron(){
    if [ "$(command -v crontab)" ]; then
        if crontab -l | grep -q "/bin/certbot renew --disable-hook-validation"; then
            echo "Cron job for automatic renewal of certificates is existed."
        else
            echo "Cron job for automatic renewal of certificates is not exist, create it."
            (crontab -l ; echo '0 3 */7 * * /bin/certbot renew --disable-hook-validation --renew-hook "/etc/init.d/httpd restart"') | crontab -
        fi
    else
        echo -e "\033[33mWarning:\033[0m crontab command not found, please set up a cron job by manually."
    fi
}

add_letsencrypt(){
    echo "Starting create Let's Encrypt SSL Certificate..."
    /bin/certbot certonly -m ${email} --agree-tos -n --webroot -w ${website_root} ${letsdomain}
    if [ $? -eq 0 ]; then
        ssl_certificate="/etc/letsencrypt/live/${server_names%% *}/fullchain.pem"
        ssl_certificate_key="/etc/letsencrypt/live/${server_names%% *}/privkey.pem"
        echo "Create Let's Encrypt SSL Certificate succeed"
    else
        echo -e "\033[31mError:\033[0m Create Let's Encrypt SSL Certificate failed."
        exit 1
    fi
}

add_buypass(){
    echo "Starting create Buypass.com SSL Certificate..."
    /bin/certbot certonly -m ${email} --agree-tos -n --webroot -w ${website_root} ${letsdomain} --server 'https://api.buypass.com/acme/directory'
    if [ $? -eq 0 ]; then
        ssl_certificate="/etc/letsencrypt/live/${server_names%% *}/fullchain.pem"
        ssl_certificate_key="/etc/letsencrypt/live/${server_names%% *}/privkey.pem"
        echo "Create Buypass.com SSL Certificate succeed"
    else
        echo -e "\033[31mError:\033[0m Create Buypass.com SSL Certificate failed."
        exit 1
    fi
}

add_ssl_cert(){
    if [ -z "${email}" ] || [ -z "${website_root}" ]; then
        echo -e "\033[31mError:\033[0m parameters must be specified."
        exit 1
    fi
    if [ ! -d "${website_root}" ]; then
        echo -e "\033[31mError:\033[0m ${website_root} does not exist or is not a directory."
        exit 1
    fi
    letsdomain=""
    if [ ! -z "${server_names}" ]; then
        for i in ${server_names}; do
            letsdomain=${letsdomain}" -d ${i}"
        done
    fi

    if [ ! -s /bin/certbot ]; then
        wget --no-check-certificate -qO /bin/certbot https://dl.eff.org/certbot-auto
        chmod +x /bin/certbot
    fi

    if [ "${ssl_pick}" = "2" ]; then
        add_letsencrypt
    elif [ "${ssl_pick}" = "3" ]; then
        add_buypass
    fi

    create_ssl_config
    check_lets_cron

    if [ "${force_ssl}" = "y" ] || [ "${force_ssl}" = "Y" ]; then
        create_ssl_htaccess
    fi
}

vhost_list(){
    if [ $(ls ${apache_location}/conf/vhost/ | grep ".conf$" | grep -v "none" | grep -v "default" | wc -l) -gt 0 ]; then
        echo "Server Name"
        echo "------------"
    else
        echo "Apache virtual host not found. You can create a new Apache virtual host with command: lamp add"
    fi
    ls ${apache_location}/conf/vhost/ | grep ".conf$" | grep -v "none" | grep -v "default" | sed 's/.conf//g'
}

vhost_del(){
    read -p "Please enter a domain you want to delete it (for example: www.lamp.sh): " domain
    if ! apache_vhost_is_exist "${domain}"; then
        echo -e "\033[31mError:\033[0m Virtual host [${domain}] not found."
        exit 1
    else
        rm -f ${apache_location}/conf/vhost/${domain}.conf
        echo "Virtual host [${domain}] has been deleted, and website files will not be deleted."
        echo "You need to delete the website files by manually if necessary."
        echo "Reloading the apache config file..."
        if ${apache_location}/bin/apachectl -t; then
            /etc/init.d/httpd restart
            echo "Reload succeed"
        else
            echo -e "\033[31mError:\033[0m Reload failed. Apache config file had an error, please fix it and try again"
            exit 1
        fi
    fi
}

apache_vhost_is_exist(){
    local conf_file="${apache_location}/conf/vhost/$1.conf"
    if [ -f "${conf_file}" ]; then
        return 0
    else
        return 1
    fi
}

display_usage(){
printf "

Usage: `basename $0` [ add | del | list ]
add     Create a new Apache virtual host
del     Delete a Apache virtual host
list    List all of Apache virtual hosts

"
}

#Run it
rootness
if [ $# -ne 1 ]; then
    display_usage
    exit 1
fi

action=$1
case ${action} in
    add)  vhost ${action} ;;
    list) vhost ${action} ;;
    del)  vhost ${action} ;;
    *)    display_usage   ;;
esac
                                                                                                                                                                                                                                                 lamp/conf/favicon.ico                                                                               000644  000765  000024  00000041076 13564465250 016370  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                             @@     (B     (   @   �           @                                                                                                                                                                                                                                                                                                              
                                       
                                                                                                                                                                                           $   &   (   ( , -LB DpZ >iP ":0               
                            $   &   ( 0 2VJ >jZ ?jX 3WF *                                                                                                           "   &   ,   0   4 : /NZ M|� [�� h�� m�� j�� ]�� ;cV   &   "                        $   *   .   4   6 &F R�� a�� g�� h�� d�� Y�� 2TP   (   $            
                                                                                 &   ,   2   : #:V P�� a�� r�� �� ��� ��� ��� ��� }�� d�� 9_� B   (   $   $   $   $   $   *   0   6   <   B   F J|� o�� �� ��� ��� ��� �� j�� Fv|   0   *   "                                                                                 ( 'CH L~� ^�� h�� t�� ��� ��� ��� ��� ��� ��� ��� ��� ��� ��� Y�� +�   �   �   |   t   l   h   d   b   n   �   �   � c�� ��� ��� ��� ��� ��� ��� ��� y�� X�� 6   *   "         
                                                             +@* p�� ��� ��� ��� ��� ��� ��� ��� ������	������������ ��� ��� ��� s�� )E�   �   �   �   �   �   �   �   �   �   �   �   � p�� ��� ������������������ ��� ��� p�� -JL   &                                                                       ��� ��� ��� ��� ��� ��� ���������$���*���-���.���.���)������ ��� ��� ��� 2R�   �   �   �   �   �   �   �   �   �   �   �   � x�� ���������'���+���+���)��� ��������� ��� b�v                                                                       ��� ������������&���-���0���2���3���3���3���3���3���2������ ��� �����;R�!!!�OOO�WWW�%%%�����   �   �   �   � r�� ������%���1���3���3���3���2���1���0���*���������|�N7K                                                             ������%���0���1���2���3���3���3���3���3���3���3���3���1������ ������K�����������������������������������OOO�333��   �   � g�� ������'���2���3���3���3���3���3���3���3���2���1���#�����z��4                                                           ���
���.���3���3���3���3���3���3���3���3���3���3���3���1������ ������������������������������������������������������555�� T�� ���	���%���2���3���3���3���3���3���3���3���3���3���3���1���$�����@                                                        ������)���3���3���3���3���3���3���3���3���3���3���3���/�����������������������������������������������������������������PPP� 8Z� ���������1���3���3���3���3���3���3���3���3���3���3���3���.������                                                         ������(���3���3���3���3���3���3���3���3���3���3���2���#���������������������������������������������������������������������#BT� ��� ������)���0���.���.���2���3���3���3���3���3���3���3���-�����                                                         ���
���/���3���3���3���3���3���3���3���3���3���3���-������ ��� -<����������������������������������������������������������~��� ��� ������������������*���3���3���3���3���3���3���-���%��\ ��                                                          ������1���2���3���3���3���3���3���3���3���3���1��������� Lc�   ��~~~��������������������������������������������������������� ��� ��� ��� ��� ������������2���3���3���3���2���)���(��N ��                                                             ���������������)���1���2���3���3���3���2���%���	��� ��� ��fff������������������������������������������������������������� ��� ��� ��� ��� ��� ��� ������.���3���3���2���&���!��N$��                                                                 ��� ��� ��� ��� ������$���2���3���3���2���-������ ��� )4���������������������������������������������������������������������� ��� ��� ��� ��� s�� d�� h�� ���������+��������T                                                                             e� p�X ��� ��� ������0���3���3���1��������� o��'7<���������������������������������������������������������������������������������� j�� +�  �   � ,C���������������T                                                                                         h�4 ������+���3���2���+������ ���5]i�����������������������������������������������������������������������������
���!������Kc�   �   �   � �-=����/������
��R                                                                                             ��T ������.���.���������Gy�������������������������������������������������������������������������������������/���*���[p�   �   �   �   ��Pe������ ��,                                                                                                 ��`������������F�����������������������������������������������������������������������������������������������H���@I��   �   ��)))�6=?�<J� i�\                                                                                                     �� I\� ������HU�����������������������������������������������������������������������������������������������������TTT�222�!!!��...�999���   n                                                                                                      
   � &2�+4�333�����������������������������������������������������������������������������������������������������aaa��)))����   �   �   �                                                                                                         ���000�www�������������������������������������������������������������������������������������������������ddd�   �888��   �   �   �   �   �                                                                                                          ^��,,,�ooo�������������������������������������������������������������������������������������������������ddd�   �###�...�   �   �   �   �   �                                                                                                          
   ��###�mmm�������������������������������������������������������������������������������������������������```�   ���   �   �   �   �   �                                                                                                              |��ggg�������������������������������������������������������������������������������������������������YYY�   ���   �   �   �   �   `                                                                                                               *��III�������������������������������������������������������������������������������������������������///�   ��///�   �   �   �   �   >                                                                                                               ��###��������������������������������������������������������������������������������������������������   �'''�999�   �   �   �   �                                                                                                                  H�$$$�nnn�����������������������������������������������������������������������������������������������555�$$$�   �   �   �   j                                                                                                                      ��%%%�����������������������������������������������������������������������������������������ppp���###��   �   �   �   &                                                                                                                       \��aaa�����������������������������������������������������������������������������������������   �   �   �   �                                                                                                                              $�����������������������������������������������������������������������������������xxx��111���   �   �   �                                                                                                                                      h   �   �===�����������������������������������������������������������������������������			�&&&���   �   �   �   ^                                                                                                                                       ,   �   ��{{{���������������������������������������������������������������������uuu�   �   �   �   �   �   �   �                                                                                                                                             \   �   �qqq����������������������������������������������������������������������   �   �   �   �   �   �   .                                                                                                                                                  �   �)))���������������������������������������������������������������������   �   �   �   �   �   �   h                                                                                                                                                          �   �����������������������������������������������������������������222�   �   �   �   �   �   �                                                                                                                                                              2   �>>>�������������������������������������������������������������   �   �   �   �   �   �   2                                                                                                                                                                 \���������������������������������������������������������???�   �   �   �   �   �   X                                                                                                                                                                          �///���������s���z��|��|�������������������������������   ���   �   �                                                                                                                                                                              d&&&�����a������ ��� ��� ��� ������r���������������QQQ���KKK��   �   D                                                                                                                                                                               <"�F���}�� ��� ��� ��� z�� ��� ��� ���1�������������aaa�^^^�000�   �                                                                                                                                                                                6!0���� ��� ��� ��� ���������
��� ��� ������Sf�		
�///�VVV�///��   V                                                                                                                                                                                 	H 9Q� ��� ��� ���	���������*���%��������� ��� p�� ���   �   �   $                                                                                                                                                                                 X +=� ��� ��� ������ ���������-���&������ ��� ��� #�   �   �   �   �                                                                                                                                                                                      j #�H��� ��� ������&���������������������Ha� �   �   �   �   n                                                                                                                                                                                       |444�����1w�� ��� ��������� ��� ������^{�����������   �   �   �   N                                                                                                                                                                                       �,,,������Aq��(���������K���{�������������333�   �   �   �   4                                                                                                                                                                                    �000�{{{�GGG���������YYY�111����������III���������333�   �   �   �   6                                                                                                                                                                                    �MMM�����}}}���������)))�   ���������xxx��������������   �   �   �   .                                                                                                                                                                                       �)))�������������ddd��   ���������������������MMM��   �   �   �                                                                                                                                                                                          ��BBB�eee�YYY�,,,��   ��nnn���������{{{�BBB��   �   �   �                                                                                                                                                                                          �   ������   �   ��"""�666�HHH�"""��   �   �   �                                                                                                                                                                                          h   �   ���   �   �   �   �   �   ����   �   �   �   j                                                                                                                                                                                           *   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �   �                                                                                                                                                                                                 �   �   �   �   �   �   �   �   �


�)))�&&&���   �   |                                                                                                                                                                                                  t   �   �   �   �   �   �   �   ��KKK�]]]�///��   �                                                                                                                                                                                                         �   �   �   �   �   �   �   ��000�<<<���   6                                                                                                                                                                                                          $   �   �   �   �   �   �   ����   �   .                                                                                                                                                                                                                     8   d   �   �   �   �   �   x   F                                                                                                                                                                                                                                        (   .   .                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      ��������������������������������� � ���� � ?���    ��     ��     ��     ��      �      ?�      ?�      ��     ��     ��     ���    ���    ���    ���    ���    ���    ���    ���    ���    ����   ����   ����   ����   ����   ����   ����   ?����   ����   ����   �����  �����  �����  �����  �����  ������ ������ ������ ������ ������ ������ ?������ ?�����  ?�����  ?�����  ?�����  ?�����  ?�����  ?������ ������ ������ ������� ������������������������������������������������                                                                                                                                                                                                                                                                                                                                                                                                                                                                  lamp/conf/index.html                                                                                000644  000765  000024  00000010130 13564465250 016227  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
    <title>LAMP stack installation scripts by Teddysun</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="keywords" content="LAMP,LAMP stack installation scripts">
    <meta name="description" content="LAMP install successfully">
    <style type="text/css">
        body {
            color: #333333;
            font-family: "Microsoft YaHei", tahoma, arial, helvetica, sans-serif;
            font-size: 14px;
        }
        
        .links {
            color: #06C
        }
        
        #main {
            margin-right: auto;
            margin-left: auto;
            width: 600px;
        }
        
        a {
            text-decoration: none;
            color: #06C;
            -webkit-transition: color .2s;
            -moz-transition: color .2s;
            -ms-transition: color .2s;
            -o-transition: color .2s;
            transition: color .2s
        }
    </style>
</head>

<body>
    <div id="main">
        <div align="center"><span style="font-size:18px;color:red;">Congratulations. LAMP is installed successfully!</span></div>
        <div align="center">
            <a href="https://lamp.sh/" target="_blank"><img src="./lamp.png" alt="LAMP stack installation scripts"></a>
        </div>
        <p>
            <span><strong>Check environment:</strong></span>
            <a href="./p.php" target="_blank" class="links">PHP Probe</a>
            <a href="./phpinfo.php" target="_blank" class="links">phpinfo</a>
            <a href="./phpmyadmin/" target="_blank" class="links">phpMyAdmin</a>
            <a href="./kod/" target="_blank" class="links">KodExplorer</a>
            <a href="./index_cn.html" target="_blank" class="links">中文</a>
        </p>
        <p><span><strong>LAMP Usage:</strong></span></p>
        <p>
            <li>lamp [add | del | list]: Create, Delete, List virtual website</li>
        </p>
        <p><span><strong>LAMP Upgrade:</strong></span></p>
        <p>
            <li>Execute script:
                <font color="#008000"> ./upgrade.sh</font>
            </li>
        </p>
        <p><span><strong>LAMP Uninstall:</strong></span></p>
        <p>
            <li>Execute script:
                <font color="#008000"> ./uninstall.sh</font>
            </li>
        </p>
        <p><span><strong>Default Location:</strong></span></p>
        <p>
            <li>Apache：/usr/local/apache</li>
        </p>
        <p>
            <li>PHP：/usr/local/php</li>
        </p>
        <p>
            <li>MySQL：/usr/local/mysql</li>
        </p>
        <p>
            <li>MariaDB：/usr/local/mariadb</li>
        </p>
        <p>
            <li>Percona：/usr/local/percona</li>
        </p>
        <p>
            <li>Web root default location：/data/www/default</li>
        </p>
        <p><span><strong>Process Management:</strong></span></p>
        <p>
            <li>Apache：/etc/init.d/httpd (start|stop|restart|status)</li>
        </p>
        <p>
            <li>MySQL：/etc/init.d/mysqld (start|stop|restart|status)</li>
        </p>
        <p>
            <li>MariaDB：/etc/init.d/mysqld (start|stop|restart|status)</li>
        </p>
        <p>
            <li>Percona：/etc/init.d/mysqld (start|stop|restart|status)</li>
        </p>
        <p>
            <li>Memcached：/etc/init.d/memcached (start|stop|restart)</li>
        </p>
        <p>
            <li>Redis-server：/etc/init.d/redis-server (start|stop|restart)</li>
        </p>
        <p><span><strong>More details:</strong></span></p>
        <p>
            <li><a href="https://github.com/teddysun/lamp" target="_blank">Github project</a></li>
        </p>
        <p>
            <li><a href="https://lamp.sh/faq.html" target="_blank">LAMP QA(Chinese)</a></li>
        </p>
        <p align="center">
            <hr>
        </p>
        <p align="center">LAMP stack installation scripts by <a href="https://lamp.sh/" target="_blank">Teddysun</a></p>
    </div>
</body>

</html>                                                                                                                                                                                                                                                                                                                                                                                                                                        lamp/conf/php.ini                                                                                   000644  000765  000024  00000207146 13564465250 015541  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         [PHP]

;;;;;;;;;;;;;;;;;;;
; About php.ini   ;
;;;;;;;;;;;;;;;;;;;
; PHP's initialization file, generally called php.ini, is responsible for
; configuring many of the aspects of PHP's behavior.

; PHP attempts to find and load this configuration from a number of locations.
; The following is a summary of its search order:
; 1. SAPI module specific location.
; 2. The PHPRC environment variable. (As of PHP 5.2.0)
; 3. A number of predefined registry keys on Windows (As of PHP 5.2.0)
; 4. Current working directory (except CLI)
; 5. The web server's directory (for SAPI modules), or directory of PHP
; (otherwise in Windows)
; 6. The directory from the --with-config-file-path compile time option, or the
; Windows directory (C:\windows or C:\winnt)
; See the PHP docs for more specific information.
; http://php.net/configuration.file

; The syntax of the file is extremely simple.  Whitespace and lines
; beginning with a semicolon are silently ignored (as you probably guessed).
; Section headers (e.g. [Foo]) are also silently ignored, even though
; they might mean something in the future.

; Directives following the section heading [PATH=/www/mysite] only
; apply to PHP files in the /www/mysite directory.  Directives
; following the section heading [HOST=www.example.com] only apply to
; PHP files served from www.example.com.  Directives set in these
; special sections cannot be overridden by user-defined INI files or
; at runtime. Currently, [PATH=] and [HOST=] sections only work under
; CGI/FastCGI.
; http://php.net/ini.sections

; Directives are specified using the following syntax:
; directive = value
; Directive names are *case sensitive* - foo=bar is different from FOO=bar.
; Directives are variables used to configure PHP or PHP extensions.
; There is no name validation.  If PHP can't find an expected
; directive because it is not set or is mistyped, a default value will be used.

; The value can be a string, a number, a PHP constant (e.g. E_ALL or M_PI), one
; of the INI constants (On, Off, True, False, Yes, No and None) or an expression
; (e.g. E_ALL & ~E_NOTICE), a quoted string ("bar"), or a reference to a
; previously set variable or directive (e.g. ${foo})

; Expressions in the INI file are limited to bitwise operators and parentheses:
; |  bitwise OR
; ^  bitwise XOR
; &  bitwise AND
; ~  bitwise NOT
; !  boolean NOT

; Boolean flags can be turned on using the values 1, On, True or Yes.
; They can be turned off using the values 0, Off, False or No.

; An empty string can be denoted by simply not writing anything after the equal
; sign, or by using the None keyword:

;  foo =         ; sets foo to an empty string
;  foo = None    ; sets foo to an empty string
;  foo = "None"  ; sets foo to the string 'None'

; If you use constants in your value, and these constants belong to a
; dynamically loaded extension (either a PHP extension or a Zend extension),
; you may only use these constants *after* the line that loads the extension.

;;;;;;;;;;;;;;;;;;;
; About this file ;
;;;;;;;;;;;;;;;;;;;
; PHP comes packaged with two INI files. One that is recommended to be used
; in production environments and one that is recommended to be used in
; development environments.

; php.ini-production contains settings which hold security, performance and
; best practices at its core. But please be aware, these settings may break
; compatibility with older or less security conscience applications. We
; recommending using the production ini in production and testing environments.

; php.ini-development is very similar to its production variant, except it's
; much more verbose when it comes to errors. We recommending using the
; development version only in development environments as errors shown to
; application users can inadvertently leak otherwise secure information.

;;;;;;;;;;;;;;;;;;;
; Quick Reference ;
;;;;;;;;;;;;;;;;;;;
; The following are all the settings which are different in either the production
; or development versions of the INIs with respect to PHP's default behavior.
; Please see the actual settings later in the document for more details as to why
; we recommend these changes in PHP's behavior.

; allow_call_time_pass_reference
;   Default Value: On
;   Development Value: Off
;   Production Value: Off

; display_errors
;   Default Value: On
;   Development Value: On
;   Production Value: Off

; display_startup_errors
;   Default Value: Off
;   Development Value: On
;   Production Value: Off

; error_reporting
;   Default Value: E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED
;   Development Value: E_ALL
;   Production Value: E_ALL & ~E_DEPRECATED & ~E_STRICT

; html_errors
;   Default Value: On
;   Development Value: On
;   Production value: Off

; log_errors
;   Default Value: Off
;   Development Value: On
;   Production Value: On

; magic_quotes_gpc
;   Default Value: On
;   Development Value: Off
;   Production Value: Off

; max_input_time
;   Default Value: -1 (Unlimited)
;   Development Value: 60 (60 seconds)
;   Production Value: 60 (60 seconds)

; output_buffering
;   Default Value: Off
;   Development Value: 4096
;   Production Value: 4096

; register_argc_argv
;   Default Value: On
;   Development Value: Off
;   Production Value: Off

; register_long_arrays
;   Default Value: On
;   Development Value: Off
;   Production Value: Off

; request_order
;   Default Value: None
;   Development Value: "GP"
;   Production Value: "GP"

; session.bug_compat_42
;   Default Value: On
;   Development Value: On
;   Production Value: Off

; session.bug_compat_warn
;   Default Value: On
;   Development Value: On
;   Production Value: Off

; session.gc_divisor
;   Default Value: 100
;   Development Value: 1000
;   Production Value: 1000

; session.hash_bits_per_character
;   Default Value: 4
;   Development Value: 5
;   Production Value: 5

; short_open_tag
;   Default Value: On
;   Development Value: Off
;   Production Value: Off

; track_errors
;   Default Value: Off
;   Development Value: On
;   Production Value: Off

; url_rewriter.tags
;   Default Value: "a=href,area=href,frame=src,form=,fieldset="
;   Development Value: "a=href,area=href,frame=src,input=src,form=fakeentry"
;   Production Value: "a=href,area=href,frame=src,input=src,form=fakeentry"

; variables_order
;   Default Value: "EGPCS"
;   Development Value: "GPCS"
;   Production Value: "GPCS"

;;;;;;;;;;;;;;;;;;;;
; php.ini Options  ;
;;;;;;;;;;;;;;;;;;;;
; Name for user-defined php.ini (.htaccess) files. Default is ".user.ini"
;user_ini.filename = ".user.ini"

; To disable this feature set this option to empty value
;user_ini.filename =

; TTL for user-defined php.ini files (time-to-live) in seconds. Default is 300 seconds (5 minutes)
;user_ini.cache_ttl = 300

;;;;;;;;;;;;;;;;;;;;
; Language Options ;
;;;;;;;;;;;;;;;;;;;;

; Enable the PHP scripting language engine under Apache.
; http://php.net/engine
engine = On

; This directive determines whether or not PHP will recognize code between
; <? and ?> tags as PHP source which should be processed as such. It is
; generally recommended that <?php and ?> should be used and that this feature
; should be disabled, as enabling it may result in issues when generating XML
; documents, however this remains supported for backward compatibility reasons.
; Note that this directive does not control the <?= shorthand tag, which can be
; used regardless of this directive.
; Default Value: On
; Development Value: Off
; Production Value: Off
; http://php.net/short-open-tag
short_open_tag = On

; Allow ASP-style <% %> tags.
; http://php.net/asp-tags
asp_tags = Off

; The number of significant digits displayed in floating point numbers.
; http://php.net/precision
precision = 14

; Enforce year 2000 compliance (will cause problems with non-compliant browsers)
; http://php.net/y2k-compliance
y2k_compliance = On

; Output buffering is a mechanism for controlling how much output data
; (excluding headers and cookies) PHP should keep internally before pushing that
; data to the client. If your application's output exceeds this setting, PHP
; will send that data in chunks of roughly the size you specify.
; Turning on this setting and managing its maximum buffer size can yield some
; interesting side-effects depending on your application and web server.
; You may be able to send headers and cookies after you've already sent output
; through print or echo. You also may see performance benefits if your server is
; emitting less packets due to buffered output versus PHP streaming the output
; as it gets it. On production servers, 4096 bytes is a good setting for performance
; reasons.
; Note: Output buffering can also be controlled via Output Buffering Control
;   functions.
; Possible Values:
;   On = Enabled and buffer is unlimited. (Use with caution)
;   Off = Disabled
;   Integer = Enables the buffer and sets its maximum size in bytes.
; Note: This directive is hardcoded to Off for the CLI SAPI
; Default Value: Off
; Development Value: 4096
; Production Value: 4096
; http://php.net/output-buffering
output_buffering = 4096

; You can redirect all of the output of your scripts to a function.  For
; example, if you set output_handler to "mb_output_handler", character
; encoding will be transparently converted to the specified encoding.
; Setting any output handler automatically turns on output buffering.
; Note: People who wrote portable scripts should not depend on this ini
;   directive. Instead, explicitly set the output handler using ob_start().
;   Using this ini directive may cause problems unless you know what script
;   is doing.
; Note: You cannot use both "mb_output_handler" with "ob_iconv_handler"
;   and you cannot use both "ob_gzhandler" and "zlib.output_compression".
; Note: output_handler must be empty if this is set 'On' !!!!
;   Instead you must use zlib.output_handler.
; http://php.net/output-handler
;output_handler =

; Transparent output compression using the zlib library
; Valid values for this option are 'off', 'on', or a specific buffer size
; to be used for compression (default is 4KB)
; Note: Resulting chunk size may vary due to nature of compression. PHP
;   outputs chunks that are few hundreds bytes each as a result of
;   compression. If you prefer a larger chunk size for better
;   performance, enable output_buffering in addition.
; Note: You need to use zlib.output_handler instead of the standard
;   output_handler, or otherwise the output will be corrupted.
; http://php.net/zlib.output-compression
zlib.output_compression = Off

; http://php.net/zlib.output-compression-level
;zlib.output_compression_level = -1

; You cannot specify additional output handlers if zlib.output_compression
; is activated here. This setting does the same as output_handler but in
; a different order.
; http://php.net/zlib.output-handler
;zlib.output_handler =

; Implicit flush tells PHP to tell the output layer to flush itself
; automatically after every output block.  This is equivalent to calling the
; PHP function flush() after each and every call to print() or echo() and each
; and every HTML block.  Turning this option on has serious performance
; implications and is generally recommended for debugging purposes only.
; http://php.net/implicit-flush
; Note: This directive is hardcoded to On for the CLI SAPI
implicit_flush = Off

; The unserialize callback function will be called (with the undefined class'
; name as parameter), if the unserializer finds an undefined class
; which should be instantiated. A warning appears if the specified function is
; not defined, or if the function doesn't include/implement the missing class.
; So only set this entry, if you really want to implement such a
; callback-function.
unserialize_callback_func =

; When floats & doubles are serialized store serialize_precision significant
; digits after the floating point. The default value ensures that when floats
; are decoded with unserialize, the data will remain the same.
serialize_precision = 17

; This directive allows you to enable and disable warnings which PHP will issue
; if you pass a value by reference at function call time. Passing values by
; reference at function call time is a deprecated feature which will be removed
; from PHP at some point in the near future. The acceptable method for passing a
; value by reference to a function is by declaring the reference in the functions
; definition, not at call time. This directive does not disable this feature, it
; only determines whether PHP will warn you about it or not. These warnings
; should enabled in development environments only.
; Default Value: On (Suppress warnings)
; Development Value: Off (Issue warnings)
; Production Value: Off (Issue warnings)
; http://php.net/allow-call-time-pass-reference
allow_call_time_pass_reference = Off

; Safe Mode
; http://php.net/safe-mode
safe_mode = Off

; By default, Safe Mode does a UID compare check when
; opening files. If you want to relax this to a GID compare,
; then turn on safe_mode_gid.
; http://php.net/safe-mode-gid
safe_mode_gid = Off

; When safe_mode is on, UID/GID checks are bypassed when
; including files from this directory and its subdirectories.
; (directory must also be in include_path or full path must
; be used when including)
; http://php.net/safe-mode-include-dir
safe_mode_include_dir =

; When safe_mode is on, only executables located in the safe_mode_exec_dir
; will be allowed to be executed via the exec family of functions.
; http://php.net/safe-mode-exec-dir
safe_mode_exec_dir =

; Setting certain environment variables may be a potential security breach.
; This directive contains a comma-delimited list of prefixes.  In Safe Mode,
; the user may only alter environment variables whose names begin with the
; prefixes supplied here.  By default, users will only be able to set
; environment variables that begin with PHP_ (e.g. PHP_FOO=BAR).
; Note:  If this directive is empty, PHP will let the user modify ANY
;   environment variable!
; http://php.net/safe-mode-allowed-env-vars
safe_mode_allowed_env_vars = PHP_

; This directive contains a comma-delimited list of environment variables that
; the end user won't be able to change using putenv().  These variables will be
; protected even if safe_mode_allowed_env_vars is set to allow to change them.
; http://php.net/safe-mode-protected-env-vars
safe_mode_protected_env_vars = LD_LIBRARY_PATH

; open_basedir, if set, limits all file operations to the defined directory
; and below.  This directive makes most sense if used in a per-directory
; or per-virtualhost web server configuration file. This directive is
; *NOT* affected by whether Safe Mode is turned On or Off.
; http://php.net/open-basedir
;open_basedir =

; This directive allows you to disable certain functions for security reasons.
; It receives a comma-delimited list of function names. This directive is
; *NOT* affected by whether Safe Mode is turned On or Off.
; http://php.net/disable-functions
disable_functions = passthru,exec,system,chroot,chgrp,chown,proc_open,proc_get_status,ini_alter,ini_alter,ini_restore

; This directive allows you to disable certain classes for security reasons.
; It receives a comma-delimited list of class names. This directive is
; *NOT* affected by whether Safe Mode is turned On or Off.
; http://php.net/disable-classes
disable_classes =

; Colors for Syntax Highlighting mode.  Anything that's acceptable in
; <span style="color: ???????"> would work.
; http://php.net/syntax-highlighting
;highlight.string  = #DD0000
;highlight.comment = #FF9900
;highlight.keyword = #007700
;highlight.default = #0000BB
;highlight.html    = #000000

; If enabled, the request will be allowed to complete even if the user aborts
; the request. Consider enabling it if executing long requests, which may end up
; being interrupted by the user or a browser timing out. PHP's default behavior
; is to disable this feature.
; http://php.net/ignore-user-abort
;ignore_user_abort = On

; Determines the size of the realpath cache to be used by PHP. This value should
; be increased on systems where PHP opens many files to reflect the quantity of
; the file operations performed.
; http://php.net/realpath-cache-size
;realpath_cache_size = 16k

; Duration of time, in seconds for which to cache realpath information for a given
; file or directory. For systems with rarely changing files, consider increasing this
; value.
; http://php.net/realpath-cache-ttl
;realpath_cache_ttl = 120

;;;;;;;;;;;;;;;;;
; Miscellaneous ;
;;;;;;;;;;;;;;;;;

; Decides whether PHP may expose the fact that it is installed on the server
; (e.g. by adding its signature to the Web server header).  It is no security
; threat in any way, but it makes it possible to determine whether you use PHP
; on your server or not.
; http://php.net/expose-php
expose_php = Off

;;;;;;;;;;;;;;;;;;;
; Resource Limits ;
;;;;;;;;;;;;;;;;;;;

; Maximum execution time of each script, in seconds
; http://php.net/max-execution-time
; Note: This directive is hardcoded to 0 for the CLI SAPI
max_execution_time = 300

; Maximum amount of time each script may spend parsing request data. It's a good
; idea to limit this time on productions servers in order to eliminate unexpectedly
; long running scripts.
; Note: This directive is hardcoded to -1 for the CLI SAPI
; Default Value: -1 (Unlimited)
; Development Value: 60 (60 seconds)
; Production Value: 60 (60 seconds)
; http://php.net/max-input-time
max_input_time = 300

; Maximum input variable nesting level
; http://php.net/max-input-nesting-level
;max_input_nesting_level = 64

; Maximum amount of memory a script may consume (128MB)
; http://php.net/memory-limit
memory_limit = 128M

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Error handling and logging ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This directive informs PHP of which errors, warnings and notices you would like
; it to take action for. The recommended way of setting values for this
; directive is through the use of the error level constants and bitwise
; operators. The error level constants are below here for convenience as well as
; some common settings and their meanings.
; By default, PHP is set to take action on all errors, notices and warnings EXCEPT
; those related to E_NOTICE and E_STRICT, which together cover best practices and
; recommended coding standards in PHP. For performance reasons, this is the
; recommend error reporting setting. Your production server shouldn't be wasting
; resources complaining about best practices and coding standards. That's what
; development servers and development settings are for.
; Note: The php.ini-development file has this setting as E_ALL. This
; means it pretty much reports everything which is exactly what you want during
; development and early testing.
;
; Error Level Constants:
; E_ALL             - All errors and warnings (includes E_STRICT as of PHP 5.4.0)
; E_ERROR           - fatal run-time errors
; E_RECOVERABLE_ERROR  - almost fatal run-time errors
; E_WARNING         - run-time warnings (non-fatal errors)
; E_PARSE           - compile-time parse errors
; E_NOTICE          - run-time notices (these are warnings which often result
;                     from a bug in your code, but it's possible that it was
;                     intentional (e.g., using an uninitialized variable and
;                     relying on the fact it's automatically initialized to an
;                     empty string)
; E_STRICT          - run-time notices, enable to have PHP suggest changes
;                     to your code which will ensure the best interoperability
;                     and forward compatibility of your code
; E_CORE_ERROR      - fatal errors that occur during PHP's initial startup
; E_CORE_WARNING    - warnings (non-fatal errors) that occur during PHP's
;                     initial startup
; E_COMPILE_ERROR   - fatal compile-time errors
; E_COMPILE_WARNING - compile-time warnings (non-fatal errors)
; E_USER_ERROR      - user-generated error message
; E_USER_WARNING    - user-generated warning message
; E_USER_NOTICE     - user-generated notice message
; E_DEPRECATED      - warn about code that will not work in future versions
;                     of PHP
; E_USER_DEPRECATED - user-generated deprecation warnings
;
; Common Values:
;   E_ALL (Show all errors, warnings and notices including coding standards.)
;   E_ALL & ~E_NOTICE  (Show all errors, except for notices)
;   E_ALL & ~E_NOTICE & ~E_STRICT  (Show all errors, except for notices and coding standards warnings.)
;   E_COMPILE_ERROR|E_RECOVERABLE_ERROR|E_ERROR|E_CORE_ERROR  (Show only errors)
; Default Value: E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED
; Development Value: E_ALL
; Production Value: E_ALL & ~E_DEPRECATED & ~E_STRICT
; http://php.net/error-reporting
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT

; This directive controls whether or not and where PHP will output errors,
; notices and warnings too. Error output is very useful during development, but
; it could be very dangerous in production environments. Depending on the code
; which is triggering the error, sensitive information could potentially leak
; out of your application such as database usernames and passwords or worse.
; It's recommended that errors be logged on production servers rather than
; having the errors sent to STDOUT.
; Possible Values:
;   Off = Do not display any errors
;   stderr = Display errors to STDERR (affects only CGI/CLI binaries!)
;   On or stdout = Display errors to STDOUT
; Default Value: On
; Development Value: On
; Production Value: Off
; http://php.net/display-errors
display_errors = Off

; The display of errors which occur during PHP's startup sequence are handled
; separately from display_errors. PHP's default behavior is to suppress those
; errors from clients. Turning the display of startup errors on can be useful in
; debugging configuration problems. But, it's strongly recommended that you
; leave this setting off on production servers.
; Default Value: Off
; Development Value: On
; Production Value: Off
; http://php.net/display-startup-errors
display_startup_errors = Off

; Besides displaying errors, PHP can also log errors to locations such as a
; server-specific log, STDERR, or a location specified by the error_log
; directive found below. While errors should not be displayed on productions
; servers they should still be monitored and logging is a great way to do that.
; Default Value: Off
; Development Value: On
; Production Value: On
; http://php.net/log-errors
log_errors = On

; Set maximum length of log_errors. In error_log information about the source is
; added. The default is 1024 and 0 allows to not apply any maximum length at all.
; http://php.net/log-errors-max-len
log_errors_max_len = 1024

; Do not log repeated messages. Repeated errors must occur in same file on same
; line unless ignore_repeated_source is set true.
; http://php.net/ignore-repeated-errors
ignore_repeated_errors = Off

; Ignore source of message when ignoring repeated messages. When this setting
; is On you will not log errors with repeated messages from different files or
; source lines.
; http://php.net/ignore-repeated-source
ignore_repeated_source = Off

; If this parameter is set to Off, then memory leaks will not be shown (on
; stdout or in the log). This has only effect in a debug compile, and if
; error reporting includes E_WARNING in the allowed list
; http://php.net/report-memleaks
report_memleaks = On

; This setting is on by default.
;report_zend_debug = 0

; Store the last error/warning message in $php_errormsg (boolean). Setting this value
; to On can assist in debugging and is appropriate for development servers. It should
; however be disabled on production servers.
; Default Value: Off
; Development Value: On
; Production Value: Off
; http://php.net/track-errors
track_errors = Off

; Turn off normal error reporting and emit XML-RPC error XML
; http://php.net/xmlrpc-errors
;xmlrpc_errors = 0

; An XML-RPC faultCode
;xmlrpc_error_number = 0

; When PHP displays or logs an error, it has the capability of formatting the
; error message as HTML for easier reading. This directive controls whether
; the error message is formatted as HTML or not.
; Note: This directive is hardcoded to Off for the CLI SAPI
; Default Value: On
; Development Value: On
; Production value: Off
; http://php.net/html-errors
html_errors = Off

; If html_errors is set to On *and* docref_root is not empty, then PHP
; produces clickable error messages that direct to a page describing the error
; or function causing the error in detail.
; You can download a copy of the PHP manual from http://php.net/docs
; and change docref_root to the base URL of your local copy including the
; leading '/'. You must also specify the file extension being used including
; the dot. PHP's default behavior is to leave these settings empty, in which
; case no links to documentation are generated.
; Note: Never use this feature for production boxes.
; http://php.net/docref-root
; Examples
;docref_root = "/phpmanual/"

; http://php.net/docref-ext
;docref_ext = .html

; String to output before an error message. PHP's default behavior is to leave
; this setting blank.
; http://php.net/error-prepend-string
; Example:
;error_prepend_string = "<span style='color: #ff0000'>"

; String to output after an error message. PHP's default behavior is to leave
; this setting blank.
; http://php.net/error-append-string
; Example:
;error_append_string = "</span>"

; Log errors to specified file. PHP's default behavior is to leave this value
; empty.
; http://php.net/error-log
; Example:
;error_log = php_errors.log
; Log errors to syslog (Event Log on Windows).
;error_log = syslog

;;;;;;;;;;;;;;;;;
; Data Handling ;
;;;;;;;;;;;;;;;;;

; The separator used in PHP generated URLs to separate arguments.
; PHP's default setting is "&".
; http://php.net/arg-separator.output
; Example:
;arg_separator.output = "&amp;"

; List of separator(s) used by PHP to parse input URLs into variables.
; PHP's default setting is "&".
; NOTE: Every character in this directive is considered as separator!
; http://php.net/arg-separator.input
; Example:
;arg_separator.input = ";&"

; This directive determines which super global arrays are registered when PHP
; starts up. G,P,C,E & S are abbreviations for the following respective super
; globals: GET, POST, COOKIE, ENV and SERVER. There is a performance penalty
; paid for the registration of these arrays and because ENV is not as commonly
; used as the others, ENV is not recommended on productions servers. You
; can still get access to the environment variables through getenv() should you
; need to.
; Default Value: "EGPCS"
; Development Value: "GPCS"
; Production Value: "GPCS";
; http://php.net/variables-order
variables_order = "GPCS"

; This directive determines which super global data (G,P,C,E & S) should
; be registered into the super global array REQUEST. If so, it also determines
; the order in which that data is registered. The values for this directive are
; specified in the same manner as the variables_order directive, EXCEPT one.
; Leaving this value empty will cause PHP to use the value set in the
; variables_order directive. It does not mean it will leave the super globals
; array REQUEST empty.
; Default Value: None
; Development Value: "GP"
; Production Value: "GP"
; http://php.net/request-order
request_order = "GP"

; Whether or not to register the EGPCS variables as global variables.  You may
; want to turn this off if you don't want to clutter your scripts' global scope
; with user data.
; You should do your best to write your scripts so that they do not require
; register_globals to be on;  Using form variables as globals can easily lead
; to possible security problems, if the code is not very well thought of.
; http://php.net/register-globals
register_globals = Off

; Determines whether the deprecated long $HTTP_*_VARS type predefined variables
; are registered by PHP or not. As they are deprecated, we obviously don't
; recommend you use them. They are on by default for compatibility reasons but
; they are not recommended on production servers.
; Default Value: On
; Development Value: Off
; Production Value: Off
; http://php.net/register-long-arrays
register_long_arrays = Off

; This directive determines whether PHP registers $argv & $argc each time it
; runs. $argv contains an array of all the arguments passed to PHP when a script
; is invoked. $argc contains an integer representing the number of arguments
; that were passed when the script was invoked. These arrays are extremely
; useful when running scripts from the command line. When this directive is
; enabled, registering these variables consumes CPU cycles and memory each time
; a script is executed. For performance reasons, this feature should be disabled
; on production servers.
; Note: This directive is hardcoded to On for the CLI SAPI
; Default Value: On
; Development Value: Off
; Production Value: Off
; http://php.net/register-argc-argv
register_argc_argv = Off

; When enabled, the ENV, REQUEST and SERVER variables are created when they're
; first used (Just In Time) instead of when the script starts. If these
; variables are not used within a script, having this directive on will result
; in a performance gain. The PHP directive register_argc_argv must be disabled
; for this directive to have any affect.
; http://php.net/auto-globals-jit
auto_globals_jit = On

; Maximum size of POST data that PHP will accept.
; Its value may be 0 to disable the limit. It is ignored if POST data reading
; is disabled through enable_post_data_reading.
; http://php.net/post-max-size
post_max_size = 50M

; Magic quotes are a preprocessing feature of PHP where PHP will attempt to
; escape any character sequences in GET, POST, COOKIE and ENV data which might
; otherwise corrupt data being placed in resources such as databases before
; making that data available to you. Because of character encoding issues and
; non-standard SQL implementations across many databases, it's not currently
; possible for this feature to be 100% accurate. PHP's default behavior is to
; enable the feature. We strongly recommend you use the escaping mechanisms
; designed specifically for the database your using instead of relying on this
; feature. Also note, this feature has been deprecated as of PHP 5.3.0 and is
; scheduled for removal in PHP 6.
; Default Value: On
; Development Value: Off
; Production Value: Off
; http://php.net/magic-quotes-gpc
magic_quotes_gpc = Off

; Magic quotes for runtime-generated data, e.g. data from SQL, from exec(), etc.
; http://php.net/magic-quotes-runtime
magic_quotes_runtime = Off

; Use Sybase-style magic quotes (escape ' with '' instead of \').
; http://php.net/magic-quotes-sybase
magic_quotes_sybase = Off

; Automatically add files before PHP document.
; http://php.net/auto-prepend-file
auto_prepend_file =

; Automatically add files after PHP document.
; http://php.net/auto-append-file
auto_append_file =

; By default, PHP will output a character encoding using
; the Content-type: header.  To disable sending of the charset, simply
; set it to be empty.
;
; PHP's built-in default is text/html
; http://php.net/default-mimetype
default_mimetype = "text/html"

; PHP's default character set is set to empty.
; http://php.net/default-charset
;default_charset = "UTF-8"

; Always populate the $HTTP_RAW_POST_DATA variable. PHP's default behavior is
; to disable this feature. If post reading is disabled through
; enable_post_data_reading, $HTTP_RAW_POST_DATA is *NOT* populated.
; http://php.net/always-populate-raw-post-data
;always_populate_raw_post_data = On

;;;;;;;;;;;;;;;;;;;;;;;;;
; Paths and Directories ;
;;;;;;;;;;;;;;;;;;;;;;;;;

; UNIX: "/path1:/path2"
;include_path = ".:/php/includes"
;
; Windows: "\path1;\path2"
;include_path = ".;c:\php\includes"
;
; PHP's default setting for include_path is ".;/path/to/php/pear"
; http://php.net/include-path

; The root of the PHP pages, used only if nonempty.
; if PHP was not compiled with FORCE_REDIRECT, you SHOULD set doc_root
; if you are running php as a CGI under any web server (other than IIS)
; see documentation for security issues.  The alternate is to use the
; cgi.force_redirect configuration below
; http://php.net/doc-root
doc_root =

; The directory under which PHP opens the script using /~username used only
; if nonempty.
; http://php.net/user-dir
user_dir =

; Directory in which the loadable extensions (modules) reside.
; http://php.net/extension-dir
; extension_dir = "./"
; On windows:
; extension_dir = "ext"

; Whether or not to enable the dl() function.  The dl() function does NOT work
; properly in multithreaded servers, such as IIS or Zeus, and is automatically
; disabled on them.
; http://php.net/enable-dl
enable_dl = Off

; cgi.force_redirect is necessary to provide security running PHP as a CGI under
; most web servers.  Left undefined, PHP turns this on by default.  You can
; turn it off here AT YOUR OWN RISK
; **You CAN safely turn this off for IIS, in fact, you MUST.**
; http://php.net/cgi.force-redirect
;cgi.force_redirect = 1

; if cgi.nph is enabled it will force cgi to always sent Status: 200 with
; every request. PHP's default behavior is to disable this feature.
;cgi.nph = 1

; if cgi.force_redirect is turned on, and you are not running under Apache or Netscape
; (iPlanet) web servers, you MAY need to set an environment variable name that PHP
; will look for to know it is OK to continue execution.  Setting this variable MAY
; cause security issues, KNOW WHAT YOU ARE DOING FIRST.
; http://php.net/cgi.redirect-status-env
;cgi.redirect_status_env =

; cgi.fix_pathinfo provides *real* PATH_INFO/PATH_TRANSLATED support for CGI.  PHP's
; previous behaviour was to set PATH_TRANSLATED to SCRIPT_FILENAME, and to not grok
; what PATH_INFO is.  For more information on PATH_INFO, see the cgi specs.  Setting
; this to 1 will cause PHP CGI to fix its paths to conform to the spec.  A setting
; of zero causes PHP to behave as before.  Default is 1.  You should fix your scripts
; to use SCRIPT_FILENAME rather than PATH_TRANSLATED.
; http://php.net/cgi.fix-pathinfo
;cgi.fix_pathinfo=1

; FastCGI under IIS (on WINNT based OS) supports the ability to impersonate
; security tokens of the calling client.  This allows IIS to define the
; security context that the request runs under.  mod_fastcgi under Apache
; does not currently support this feature (03/17/2002)
; Set to 1 if running under IIS.  Default is zero.
; http://php.net/fastcgi.impersonate
;fastcgi.impersonate = 1

; Disable logging through FastCGI connection. PHP's default behavior is to enable
; this feature.
;fastcgi.logging = 0

; cgi.rfc2616_headers configuration option tells PHP what type of headers to
; use when sending HTTP response code. If it's set 0 PHP sends Status: header that
; is supported by Apache. When this option is set to 1 PHP will send
; RFC2616 compliant header.
; Default is zero.
; http://php.net/cgi.rfc2616-headers
;cgi.rfc2616_headers = 0

;;;;;;;;;;;;;;;;
; File Uploads ;
;;;;;;;;;;;;;;;;

; Whether to allow HTTP file uploads.
; http://php.net/file-uploads
file_uploads = On

; Temporary directory for HTTP uploaded files (will use system default if not
; specified).
; http://php.net/upload-tmp-dir
;upload_tmp_dir =

; Maximum allowed size for uploaded files.
; http://php.net/upload-max-filesize
upload_max_filesize = 50M

; Maximum number of files that can be uploaded via a single request
max_file_uploads = 20

;;;;;;;;;;;;;;;;;;
; Fopen wrappers ;
;;;;;;;;;;;;;;;;;;

; Whether to allow the treatment of URLs (like http:// or ftp://) as files.
; http://php.net/allow-url-fopen
allow_url_fopen = On

; Whether to allow include/require to open URLs (like http:// or ftp://) as files.
; http://php.net/allow-url-include
allow_url_include = Off

; Define the anonymous ftp password (your email address). PHP's default setting
; for this is empty.
; http://php.net/from
;from="john@doe.com"

; Define the User-Agent string. PHP's default setting for this is empty.
; http://php.net/user-agent
;user_agent="PHP"

; Default timeout for socket based streams (seconds)
; http://php.net/default-socket-timeout
default_socket_timeout = 60

; If your scripts have to deal with files from Macintosh systems,
; or you are running on a Mac and need to deal with files from
; unix or win32 systems, setting this flag will cause PHP to
; automatically detect the EOL character in those files so that
; fgets() and file() will work regardless of the source of the file.
; http://php.net/auto-detect-line-endings
;auto_detect_line_endings = Off

;;;;;;;;;;;;;;;;;;;;;;
; Dynamic Extensions ;
;;;;;;;;;;;;;;;;;;;;;;

; If you wish to have an extension loaded automatically, use the following
; syntax:
;
;   extension=modulename.extension
;
; For example, on Windows:
;
;   extension=msql.dll
;
; ... or under UNIX:
;
;   extension=msql.so
;
; ... or with a path:
;
;   extension=/path/to/extension/msql.so
;
; If you only provide the name of the extension, PHP will look for it in its
; default extension directory.
;
; Windows Extensions
; Note that ODBC support is built in, so no dll is needed for it.
; Note that many DLL files are located in the extensions/ (PHP 4) ext/ (PHP 5)
; extension folders as well as the separate PECL DLL download (PHP 5).
; Be sure to appropriately set the extension_dir directive.
;
;extension=php_bz2.dll
;extension=php_curl.dll
;extension=php_fileinfo.dll
;extension=php_gd2.dll
;extension=php_gettext.dll
;extension=php_gmp.dll
;extension=php_intl.dll
;extension=php_imap.dll
;extension=php_interbase.dll
;extension=php_ldap.dll
;extension=php_mbstring.dll
;extension=php_exif.dll      ; Must be after mbstring as it depends on it
;extension=php_mysql.dll
;extension=php_mysqli.dll
;extension=php_oci8.dll      ; Use with Oracle 10gR2 Instant Client
;extension=php_oci8_11g.dll  ; Use with Oracle 11gR2 Instant Client
;extension=php_openssl.dll
;extension=php_pdo_firebird.dll
;extension=php_pdo_mysql.dll
;extension=php_pdo_oci.dll
;extension=php_pdo_odbc.dll
;extension=php_pdo_pgsql.dll
;extension=php_pdo_sqlite.dll
;extension=php_pgsql.dll
;extension=php_pspell.dll
;extension=php_shmop.dll

; The MIBS data available in the PHP distribution must be installed. 
; See http://www.php.net/manual/en/snmp.installation.php 
;extension=php_snmp.dll

;extension=php_soap.dll
;extension=php_sockets.dll
;extension=php_sqlite3.dll
;extension=php_sybase_ct.dll
;extension=php_tidy.dll
;extension=php_xmlrpc.dll
;extension=php_xsl.dll

;;;;;;;;;;;;;;;;;;;
; Module Settings ;
;;;;;;;;;;;;;;;;;;;

[Date]
; Defines the default timezone used by the date functions
; http://php.net/date.timezone
date.timezone = PRC

; http://php.net/date.default-latitude
;date.default_latitude = 31.7667

; http://php.net/date.default-longitude
;date.default_longitude = 35.2333

; http://php.net/date.sunrise-zenith
;date.sunrise_zenith = 90.583333

; http://php.net/date.sunset-zenith
;date.sunset_zenith = 90.583333

[filter]
; http://php.net/filter.default
;filter.default = unsafe_raw

; http://php.net/filter.default-flags
;filter.default_flags =

[iconv]
;iconv.input_encoding = ISO-8859-1
;iconv.internal_encoding = ISO-8859-1
;iconv.output_encoding = ISO-8859-1

[intl]
;intl.default_locale =
; This directive allows you to produce PHP errors when some error
; happens within intl functions. The value is the level of the error produced.
; Default is 0, which does not produce any errors.
;intl.error_level = E_WARNING

[sqlite]
; http://php.net/sqlite.assoc-case
;sqlite.assoc_case = 0

[sqlite3]
;sqlite3.extension_dir =

[Pcre]
;PCRE library backtracking limit.
; http://php.net/pcre.backtrack-limit
;pcre.backtrack_limit=100000

;PCRE library recursion limit.
;Please note that if you set this value to a high number you may consume all
;the available process stack and eventually crash PHP (due to reaching the
;stack size limit imposed by the Operating System).
; http://php.net/pcre.recursion-limit
;pcre.recursion_limit=100000

[Pdo]
; Whether to pool ODBC connections. Can be one of "strict", "relaxed" or "off"
; http://php.net/pdo-odbc.connection-pooling
;pdo_odbc.connection_pooling=strict

;pdo_odbc.db2_instance_name

[Pdo_mysql]
; If mysqlnd is used: Number of cache slots for the internal result set cache
; http://php.net/pdo_mysql.cache_size
pdo_mysql.cache_size = 2000

; Default socket name for local MySQL connects.  If empty, uses the built-in
; MySQL defaults.
; http://php.net/pdo_mysql.default-socket
pdo_mysql.default_socket=

[Phar]
; http://php.net/phar.readonly
;phar.readonly = On

; http://php.net/phar.require-hash
;phar.require_hash = On

;phar.cache_list =

[Syslog]
; Whether or not to define the various syslog variables (e.g. $LOG_PID,
; $LOG_CRON, etc.).  Turning it off is a good idea performance-wise.  In
; runtime, you can define these variables by calling define_syslog_variables().
; http://php.net/define-syslog-variables
define_syslog_variables  = Off

[mail function]
; For Win32 only.
; http://php.net/smtp
SMTP = localhost
; http://php.net/smtp-port
smtp_port = 25

; For Win32 only.
; http://php.net/sendmail-from
;sendmail_from = me@example.com

; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").
; http://php.net/sendmail-path
;sendmail_path =

; Force the addition of the specified parameters to be passed as extra parameters
; to the sendmail binary. These parameters will always replace the value of
; the 5th parameter to mail(), even in safe mode.
;mail.force_extra_parameters =

; Add X-PHP-Originating-Script: that will include uid of the script followed by the filename
mail.add_x_header = On

; The path to a log file that will log all mail() calls. Log entries include
; the full path of the script, line number, To address and headers.
;mail.log =

[SQL]
; http://php.net/sql.safe-mode
sql.safe_mode = Off

[ODBC]
; http://php.net/odbc.default-db
;odbc.default_db    =  Not yet implemented

; http://php.net/odbc.default-user
;odbc.default_user  =  Not yet implemented

; http://php.net/odbc.default-pw
;odbc.default_pw    =  Not yet implemented

; Controls the ODBC cursor model.
; Default: SQL_CURSOR_STATIC (default).
;odbc.default_cursortype

; Allow or prevent persistent links.
; http://php.net/odbc.allow-persistent
odbc.allow_persistent = On

; Check that a connection is still valid before reuse.
; http://php.net/odbc.check-persistent
odbc.check_persistent = On

; Maximum number of persistent links.  -1 means no limit.
; http://php.net/odbc.max-persistent
odbc.max_persistent = -1

; Maximum number of links (persistent + non-persistent).  -1 means no limit.
; http://php.net/odbc.max-links
odbc.max_links = -1

; Handling of LONG fields.  Returns number of bytes to variables.  0 means
; passthru.
; http://php.net/odbc.defaultlrl
odbc.defaultlrl = 4096

; Handling of binary data.  0 means passthru, 1 return as is, 2 convert to char.
; See the documentation on odbc_binmode and odbc_longreadlen for an explanation
; of odbc.defaultlrl and odbc.defaultbinmode
; http://php.net/odbc.defaultbinmode
odbc.defaultbinmode = 1

;birdstep.max_links = -1

[Interbase]
; Allow or prevent persistent links.
ibase.allow_persistent = 1

; Maximum number of persistent links.  -1 means no limit.
ibase.max_persistent = -1

; Maximum number of links (persistent + non-persistent).  -1 means no limit.
ibase.max_links = -1

; Default database name for ibase_connect().
;ibase.default_db =

; Default username for ibase_connect().
;ibase.default_user =

; Default password for ibase_connect().
;ibase.default_password =

; Default charset for ibase_connect().
;ibase.default_charset =

; Default timestamp format.
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"

; Default date format.
ibase.dateformat = "%Y-%m-%d"

; Default time format.
ibase.timeformat = "%H:%M:%S"

[MySQL]
; Allow accessing, from PHP's perspective, local files with LOAD DATA statements
; http://php.net/mysql.allow_local_infile
mysql.allow_local_infile = On

; Allow or prevent persistent links.
; http://php.net/mysql.allow-persistent
mysql.allow_persistent = On

; If mysqlnd is used: Number of cache slots for the internal result set cache
; http://php.net/mysql.cache_size
mysql.cache_size = 2000

; Maximum number of persistent links.  -1 means no limit.
; http://php.net/mysql.max-persistent
mysql.max_persistent = -1

; Maximum number of links (persistent + non-persistent).  -1 means no limit.
; http://php.net/mysql.max-links
mysql.max_links = -1

; Default port number for mysql_connect().  If unset, mysql_connect() will use
; the $MYSQL_TCP_PORT or the mysql-tcp entry in /etc/services or the
; compile-time value defined MYSQL_PORT (in that order).  Win32 will only look
; at MYSQL_PORT.
; http://php.net/mysql.default-port
mysql.default_port =

; Default socket name for local MySQL connects.  If empty, uses the built-in
; MySQL defaults.
; http://php.net/mysql.default-socket
mysql.default_socket =

; Default host for mysql_connect() (doesn't apply in safe mode).
; http://php.net/mysql.default-host
mysql.default_host =

; Default user for mysql_connect() (doesn't apply in safe mode).
; http://php.net/mysql.default-user
mysql.default_user =

; Default password for mysql_connect() (doesn't apply in safe mode).
; Note that this is generally a *bad* idea to store passwords in this file.
; *Any* user with PHP access can run 'echo get_cfg_var("mysql.default_password")
; and reveal this password!  And of course, any users with read access to this
; file will be able to reveal the password as well.
; http://php.net/mysql.default-password
mysql.default_password =

; Maximum time (in seconds) for connect timeout. -1 means no limit
; http://php.net/mysql.connect-timeout
mysql.connect_timeout = 60

; Trace mode. When trace_mode is active (=On), warnings for table/index scans and
; SQL-Errors will be displayed.
; http://php.net/mysql.trace-mode
mysql.trace_mode = Off

[MySQLi]

; Maximum number of persistent links.  -1 means no limit.
; http://php.net/mysqli.max-persistent
mysqli.max_persistent = -1

; Allow accessing, from PHP's perspective, local files with LOAD DATA statements
; http://php.net/mysqli.allow_local_infile
;mysqli.allow_local_infile = On

; Allow or prevent persistent links.
; http://php.net/mysqli.allow-persistent
mysqli.allow_persistent = On

; Maximum number of links.  -1 means no limit.
; http://php.net/mysqli.max-links
mysqli.max_links = -1

; If mysqlnd is used: Number of cache slots for the internal result set cache
; http://php.net/mysqli.cache_size
mysqli.cache_size = 2000

; Default port number for mysqli_connect().  If unset, mysqli_connect() will use
; the $MYSQL_TCP_PORT or the mysql-tcp entry in /etc/services or the
; compile-time value defined MYSQL_PORT (in that order).  Win32 will only look
; at MYSQL_PORT.
; http://php.net/mysqli.default-port
mysqli.default_port = 3306

; Default socket name for local MySQL connects.  If empty, uses the built-in
; MySQL defaults.
; http://php.net/mysqli.default-socket
mysqli.default_socket =

; Default host for mysql_connect() (doesn't apply in safe mode).
; http://php.net/mysqli.default-host
mysqli.default_host =

; Default user for mysql_connect() (doesn't apply in safe mode).
; http://php.net/mysqli.default-user
mysqli.default_user =

; Default password for mysqli_connect() (doesn't apply in safe mode).
; Note that this is generally a *bad* idea to store passwords in this file.
; *Any* user with PHP access can run 'echo get_cfg_var("mysqli.default_pw")
; and reveal this password!  And of course, any users with read access to this
; file will be able to reveal the password as well.
; http://php.net/mysqli.default-pw
mysqli.default_pw =

; Allow or prevent reconnect
mysqli.reconnect = Off

[mysqlnd]
; Enable / Disable collection of general statistics by mysqlnd which can be
; used to tune and monitor MySQL operations.
; http://php.net/mysqlnd.collect_statistics
mysqlnd.collect_statistics = On

; Enable / Disable collection of memory usage statistics by mysqlnd which can be
; used to tune and monitor MySQL operations.
; http://php.net/mysqlnd.collect_memory_statistics
mysqlnd.collect_memory_statistics = Off

; Size of a pre-allocated buffer used when sending commands to MySQL in bytes.
; http://php.net/mysqlnd.net_cmd_buffer_size
;mysqlnd.net_cmd_buffer_size = 2048

; Size of a pre-allocated buffer used for reading data sent by the server in
; bytes.
; http://php.net/mysqlnd.net_read_buffer_size
;mysqlnd.net_read_buffer_size = 32768

[OCI8]

; Connection: Enables privileged connections using external
; credentials (OCI_SYSOPER, OCI_SYSDBA)
; http://php.net/oci8.privileged-connect
;oci8.privileged_connect = Off

; Connection: The maximum number of persistent OCI8 connections per
; process. Using -1 means no limit.
; http://php.net/oci8.max-persistent
;oci8.max_persistent = -1

; Connection: The maximum number of seconds a process is allowed to
; maintain an idle persistent connection. Using -1 means idle
; persistent connections will be maintained forever.
; http://php.net/oci8.persistent-timeout
;oci8.persistent_timeout = -1

; Connection: The number of seconds that must pass before issuing a
; ping during oci_pconnect() to check the connection validity. When
; set to 0, each oci_pconnect() will cause a ping. Using -1 disables
; pings completely.
; http://php.net/oci8.ping-interval
;oci8.ping_interval = 60

; Connection: Set this to a user chosen connection class to be used
; for all pooled server requests with Oracle 11g Database Resident
; Connection Pooling (DRCP).  To use DRCP, this value should be set to
; the same string for all web servers running the same application,
; the database pool must be configured, and the connection string must
; specify to use a pooled server.
;oci8.connection_class =

; High Availability: Using On lets PHP receive Fast Application
; Notification (FAN) events generated when a database node fails. The
; database must also be configured to post FAN events.
;oci8.events = Off

; Tuning: This option enables statement caching, and specifies how
; many statements to cache. Using 0 disables statement caching.
; http://php.net/oci8.statement-cache-size
;oci8.statement_cache_size = 20

; Tuning: Enables statement prefetching and sets the default number of
; rows that will be fetched automatically after statement execution.
; http://php.net/oci8.default-prefetch
;oci8.default_prefetch = 100

; Compatibility. Using On means oci_close() will not close
; oci_connect() and oci_new_connect() connections.
; http://php.net/oci8.old-oci-close-semantics
;oci8.old_oci_close_semantics = Off

[PostgreSQL]
; Allow or prevent persistent links.
; http://php.net/pgsql.allow-persistent
pgsql.allow_persistent = On

; Detect broken persistent links always with pg_pconnect().
; Auto reset feature requires a little overheads.
; http://php.net/pgsql.auto-reset-persistent
pgsql.auto_reset_persistent = Off

; Maximum number of persistent links.  -1 means no limit.
; http://php.net/pgsql.max-persistent
pgsql.max_persistent = -1

; Maximum number of links (persistent+non persistent).  -1 means no limit.
; http://php.net/pgsql.max-links
pgsql.max_links = -1

; Ignore PostgreSQL backends Notice message or not.
; Notice message logging require a little overheads.
; http://php.net/pgsql.ignore-notice
pgsql.ignore_notice = 0

; Log PostgreSQL backends Notice message or not.
; Unless pgsql.ignore_notice=0, module cannot log notice message.
; http://php.net/pgsql.log-notice
pgsql.log_notice = 0

[Sybase-CT]
; Allow or prevent persistent links.
; http://php.net/sybct.allow-persistent
sybct.allow_persistent = On

; Maximum number of persistent links.  -1 means no limit.
; http://php.net/sybct.max-persistent
sybct.max_persistent = -1

; Maximum number of links (persistent + non-persistent).  -1 means no limit.
; http://php.net/sybct.max-links
sybct.max_links = -1

; Minimum server message severity to display.
; http://php.net/sybct.min-server-severity
sybct.min_server_severity = 10

; Minimum client message severity to display.
; http://php.net/sybct.min-client-severity
sybct.min_client_severity = 10

; Set per-context timeout
; http://php.net/sybct.timeout
;sybct.timeout=

;sybct.packet_size

; The maximum time in seconds to wait for a connection attempt to succeed before returning failure.
; Default: one minute
;sybct.login_timeout=

; The name of the host you claim to be connecting from, for display by sp_who.
; Default: none
;sybct.hostname=

; Allows you to define how often deadlocks are to be retried. -1 means "forever".
; Default: 0
;sybct.deadlock_retry_count=

[bcmath]
; Number of decimal digits for all bcmath functions.
; http://php.net/bcmath.scale
bcmath.scale = 0

[browscap]
; http://php.net/browscap
;browscap = extra/browscap.ini

[Session]
; Handler used to store/retrieve data.
; http://php.net/session.save-handler
session.save_handler = files

; Argument passed to save_handler.  In the case of files, this is the path
; where data files are stored. Note: Windows users have to change this
; variable in order to use PHP's session functions.
;
; The path can be defined as:
;
;     session.save_path = "N;/path"
;
; where N is an integer.  Instead of storing all the session files in
; /path, what this will do is use subdirectories N-levels deep, and
; store the session data in those directories.  This is useful if you
; or your OS have problems with lots of files in one directory, and is
; a more efficient layout for servers that handle lots of sessions.
;
; NOTE 1: PHP will not create this directory structure automatically.
;         You can use the script in the ext/session dir for that purpose.
; NOTE 2: See the section on garbage collection below if you choose to
;         use subdirectories for session storage
;
; The file storage module creates files using mode 600 by default.
; You can change that by using
;
;     session.save_path = "N;MODE;/path"
;
; where MODE is the octal representation of the mode. Note that this
; does not overwrite the process's umask.
; http://php.net/session.save-path
;session.save_path = "/tmp"

; Whether to use cookies.
; http://php.net/session.use-cookies
session.use_cookies = 1

; http://php.net/session.cookie-secure
;session.cookie_secure =

; This option forces PHP to fetch and use a cookie for storing and maintaining
; the session id. We encourage this operation as it's very helpful in combating
; session hijacking when not specifying and managing your own session id. It is
; not the end all be all of session hijacking defense, but it's a good start.
; http://php.net/session.use-only-cookies
session.use_only_cookies = 1

; Name of the session (used as cookie name).
; http://php.net/session.name
session.name = PHPSESSID

; Initialize session on request startup.
; http://php.net/session.auto-start
session.auto_start = 0

; Lifetime in seconds of cookie or, if 0, until browser is restarted.
; http://php.net/session.cookie-lifetime
session.cookie_lifetime = 0

; The path for which the cookie is valid.
; http://php.net/session.cookie-path
session.cookie_path = /

; The domain for which the cookie is valid.
; http://php.net/session.cookie-domain
session.cookie_domain =

; Whether or not to add the httpOnly flag to the cookie, which makes it inaccessible to browser scripting languages such as JavaScript.
; http://php.net/session.cookie-httponly
session.cookie_httponly =

; Handler used to serialize data.  php is the standard serializer of PHP.
; http://php.net/session.serialize-handler
session.serialize_handler = php

; Defines the probability that the 'garbage collection' process is started
; on every session initialization. The probability is calculated by using
; gc_probability/gc_divisor. Where session.gc_probability is the numerator
; and gc_divisor is the denominator in the equation. Setting this value to 1
; when the session.gc_divisor value is 100 will give you approximately a 1% chance
; the gc will run on any give request.
; Default Value: 1
; Development Value: 1
; Production Value: 1
; http://php.net/session.gc-probability
session.gc_probability = 1

; Defines the probability that the 'garbage collection' process is started on every
; session initialization. The probability is calculated by using the following equation:
; gc_probability/gc_divisor. Where session.gc_probability is the numerator and
; session.gc_divisor is the denominator in the equation. Setting this value to 1
; when the session.gc_divisor value is 100 will give you approximately a 1% chance
; the gc will run on any give request. Increasing this value to 1000 will give you
; a 0.1% chance the gc will run on any give request. For high volume production servers,
; this is a more efficient approach.
; Default Value: 100
; Development Value: 1000
; Production Value: 1000
; http://php.net/session.gc-divisor
session.gc_divisor = 1000

; After this number of seconds, stored data will be seen as 'garbage' and
; cleaned up by the garbage collection process.
; http://php.net/session.gc-maxlifetime
session.gc_maxlifetime = 1440

; NOTE: If you are using the subdirectory option for storing session files
;       (see session.save_path above), then garbage collection does *not*
;       happen automatically.  You will need to do your own garbage
;       collection through a shell script, cron entry, or some other method.
;       For example, the following script would is the equivalent of
;       setting session.gc_maxlifetime to 1440 (1440 seconds = 24 minutes):
;          find /path/to/sessions -cmin +24 -type f| xargs rm

; PHP 4.2 and less have an undocumented feature/bug that allows you to
; to initialize a session variable in the global scope, even when register_globals
; is disabled.  PHP 4.3 and later will warn you, if this feature is used.
; You can disable the feature and the warning separately. At this time,
; the warning is only displayed, if bug_compat_42 is enabled. This feature
; introduces some serious security problems if not handled correctly. It's
; recommended that you do not use this feature on production servers. But you
; should enable this on development servers and enable the warning as well. If you
; do not enable the feature on development servers, you won't be warned when it's
; used and debugging errors caused by this can be difficult to track down.
; Default Value: On
; Development Value: On
; Production Value: Off
; http://php.net/session.bug-compat-42
session.bug_compat_42 = Off

; This setting controls whether or not you are warned by PHP when initializing a
; session value into the global space. session.bug_compat_42 must be enabled before
; these warnings can be issued by PHP. See the directive above for more information.
; Default Value: On
; Development Value: On
; Production Value: Off
; http://php.net/session.bug-compat-warn
session.bug_compat_warn = Off

; Check HTTP Referer to invalidate externally stored URLs containing ids.
; HTTP_REFERER has to contain this substring for the session to be
; considered as valid.
; http://php.net/session.referer-check
session.referer_check =

; How many bytes to read from the file.
; http://php.net/session.entropy-length
session.entropy_length = 0

; Specified here to create the session id.
; http://php.net/session.entropy-file
; Defaults to /dev/urandom
; On systems that don't have /dev/urandom but do have /dev/arandom, this will default to /dev/arandom
; If neither are found at compile time, the default is no entropy file.
; On windows, setting the entropy_length setting will activate the 
; Windows random source (using the CryptoAPI)
;session.entropy_file = /dev/urandom

; Set to {nocache,private,public,} to determine HTTP caching aspects
; or leave this empty to avoid sending anti-caching headers.
; http://php.net/session.cache-limiter
session.cache_limiter = nocache

; Document expires after n minutes.
; http://php.net/session.cache-expire
session.cache_expire = 180

; trans sid support is disabled by default.
; Use of trans sid may risk your users security.
; Use this option with caution.
; - User may send URL contains active session ID
;   to other person via. email/irc/etc.
; - URL that contains active session ID may be stored
;   in publicly accessible computer.
; - User may access your site with the same session ID
;   always using URL stored in browser's history or bookmarks.
; http://php.net/session.use-trans-sid
session.use_trans_sid = 0

; Select a hash function for use in generating session ids.
; Possible Values
;   0  (MD5 128 bits)
;   1  (SHA-1 160 bits)
; This option may also be set to the name of any hash function supported by
; the hash extension. A list of available hashes is returned by the hash_algos()
; function.
; http://php.net/session.hash-function
session.hash_function = 0

; Define how many bits are stored in each character when converting
; the binary hash data to something readable.
; Possible values:
;   4  (4 bits: 0-9, a-f)
;   5  (5 bits: 0-9, a-v)
;   6  (6 bits: 0-9, a-z, A-Z, "-", ",")
; Default Value: 4
; Development Value: 5
; Production Value: 5
; http://php.net/session.hash-bits-per-character
session.hash_bits_per_character = 5

; The URL rewriter will look for URLs in a defined set of HTML tags.
; form/fieldset are special; if you include them here, the rewriter will
; add a hidden <input> field with the info which is otherwise appended
; to URLs.  If you want XHTML conformity, remove the form entry.
; Note that all valid entries require a "=", even if no value follows.
; Default Value: "a=href,area=href,frame=src,form=,fieldset="
; Development Value: "a=href,area=href,frame=src,input=src,form=fakeentry"
; Production Value: "a=href,area=href,frame=src,input=src,form=fakeentry"
; http://php.net/url-rewriter.tags
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"

[MSSQL]
; Allow or prevent persistent links.
mssql.allow_persistent = On

; Maximum number of persistent links.  -1 means no limit.
mssql.max_persistent = -1

; Maximum number of links (persistent+non persistent).  -1 means no limit.
mssql.max_links = -1

; Minimum error severity to display.
mssql.min_error_severity = 10

; Minimum message severity to display.
mssql.min_message_severity = 10

; Compatibility mode with old versions of PHP 3.0.
mssql.compatability_mode = Off

; Connect timeout
;mssql.connect_timeout = 5

; Query timeout
;mssql.timeout = 60

; Valid range 0 - 2147483647.  Default = 4096.
;mssql.textlimit = 4096

; Valid range 0 - 2147483647.  Default = 4096.
;mssql.textsize = 4096

; Limits the number of records in each batch.  0 = all records in one batch.
;mssql.batchsize = 0

; Specify how datetime and datetim4 columns are returned
; On => Returns data converted to SQL server settings
; Off => Returns values as YYYY-MM-DD hh:mm:ss
;mssql.datetimeconvert = On

; Use NT authentication when connecting to the server
mssql.secure_connection = Off

; Specify max number of processes. -1 = library default
; msdlib defaults to 25
; FreeTDS defaults to 4096
;mssql.max_procs = -1

; Specify client character set.
; If empty or not set the client charset from freetds.conf is used
; This is only used when compiled with FreeTDS
;mssql.charset = "ISO-8859-1"

[Assertion]
; Assert(expr); active by default.
; http://php.net/assert.active
;assert.active = On

; Issue a PHP warning for each failed assertion.
; http://php.net/assert.warning
;assert.warning = On

; Don't bail out by default.
; http://php.net/assert.bail
;assert.bail = Off

; User-function to be called if an assertion fails.
; http://php.net/assert.callback
;assert.callback = 0

; Eval the expression with current error_reporting().  Set to true if you want
; error_reporting(0) around the eval().
; http://php.net/assert.quiet-eval
;assert.quiet_eval = 0

[COM]
; path to a file containing GUIDs, IIDs or filenames of files with TypeLibs
; http://php.net/com.typelib-file
;com.typelib_file =

; allow Distributed-COM calls
; http://php.net/com.allow-dcom
;com.allow_dcom = true

; autoregister constants of a components typlib on com_load()
; http://php.net/com.autoregister-typelib
;com.autoregister_typelib = true

; register constants casesensitive
; http://php.net/com.autoregister-casesensitive
;com.autoregister_casesensitive = false

; show warnings on duplicate constant registrations
; http://php.net/com.autoregister-verbose
;com.autoregister_verbose = true

; The default character set code-page to use when passing strings to and from COM objects.
; Default: system ANSI code page
;com.code_page=

[mbstring]
; language for internal character representation.
; http://php.net/mbstring.language
;mbstring.language = Japanese

; internal/script encoding.
; Some encoding cannot work as internal encoding.
; (e.g. SJIS, BIG5, ISO-2022-*)
; http://php.net/mbstring.internal-encoding
;mbstring.internal_encoding = EUC-JP

; http input encoding.
; http://php.net/mbstring.http-input
;mbstring.http_input = auto

; http output encoding. mb_output_handler must be
; registered as output buffer to function
; http://php.net/mbstring.http-output
;mbstring.http_output = SJIS

; enable automatic encoding translation according to
; mbstring.internal_encoding setting. Input chars are
; converted to internal encoding by setting this to On.
; Note: Do _not_ use automatic encoding translation for
;       portable libs/applications.
; http://php.net/mbstring.encoding-translation
;mbstring.encoding_translation = Off

; automatic encoding detection order.
; auto means
; http://php.net/mbstring.detect-order
;mbstring.detect_order = auto

; substitute_character used when character cannot be converted
; one from another
; http://php.net/mbstring.substitute-character
;mbstring.substitute_character = none;

; overload(replace) single byte functions by mbstring functions.
; mail(), ereg(), etc are overloaded by mb_send_mail(), mb_ereg(),
; etc. Possible values are 0,1,2,4 or combination of them.
; For example, 7 for overload everything.
; 0: No overload
; 1: Overload mail() function
; 2: Overload str*() functions
; 4: Overload ereg*() functions
; http://php.net/mbstring.func-overload
;mbstring.func_overload = 0

; enable strict encoding detection.
;mbstring.strict_detection = Off

; This directive specifies the regex pattern of content types for which mb_output_handler()
; is activated.
; Default: mbstring.http_output_conv_mimetype=^(text/|application/xhtml\+xml)
;mbstring.http_output_conv_mimetype=

; Allows to set script encoding. Only affects if PHP is compiled with --enable-zend-multibyte
; Default: ""
;mbstring.script_encoding=

[gd]
; Tell the jpeg decode to ignore warnings and try to create
; a gd image. The warning will then be displayed as notices
; disabled by default
; http://php.net/gd.jpeg-ignore-warning
;gd.jpeg_ignore_warning = 0

[exif]
; Exif UNICODE user comments are handled as UCS-2BE/UCS-2LE and JIS as JIS.
; With mbstring support this will automatically be converted into the encoding
; given by corresponding encode setting. When empty mbstring.internal_encoding
; is used. For the decode settings you can distinguish between motorola and
; intel byte order. A decode setting cannot be empty.
; http://php.net/exif.encode-unicode
;exif.encode_unicode = ISO-8859-15

; http://php.net/exif.decode-unicode-motorola
;exif.decode_unicode_motorola = UCS-2BE

; http://php.net/exif.decode-unicode-intel
;exif.decode_unicode_intel    = UCS-2LE

; http://php.net/exif.encode-jis
;exif.encode_jis =

; http://php.net/exif.decode-jis-motorola
;exif.decode_jis_motorola = JIS

; http://php.net/exif.decode-jis-intel
;exif.decode_jis_intel    = JIS

[Tidy]
; The path to a default tidy configuration file to use when using tidy
; http://php.net/tidy.default-config
;tidy.default_config = /usr/local/lib/php/default.tcfg

; Should tidy clean and repair output automatically?
; WARNING: Do not use this option if you are generating non-html content
; such as dynamic images
; http://php.net/tidy.clean-output
tidy.clean_output = Off

[soap]
; Enables or disables WSDL caching feature.
; http://php.net/soap.wsdl-cache-enabled
soap.wsdl_cache_enabled=1

; Sets the directory name where SOAP extension will put cache files.
; http://php.net/soap.wsdl-cache-dir
soap.wsdl_cache_dir="/tmp"

; (time to live) Sets the number of second while cached file will be used
; instead of original one.
; http://php.net/soap.wsdl-cache-ttl
soap.wsdl_cache_ttl=86400

; Sets the size of the cache limit. (Max. number of WSDL files to cache)
soap.wsdl_cache_limit = 5

[sysvshm]
; A default size of the shared memory segment
;sysvshm.init_mem = 10000

[ldap]
; Sets the maximum number of open links or -1 for unlimited.
ldap.max_links = -1

[mcrypt]
; For more information about mcrypt settings see http://php.net/mcrypt-module-open

; Directory where to load mcrypt algorithms
; Default: Compiled in into libmcrypt (usually /usr/local/lib/libmcrypt)
;mcrypt.algorithms_dir=

; Directory where to load mcrypt modes
; Default: Compiled in into libmcrypt (usually /usr/local/lib/libmcrypt)
;mcrypt.modes_dir=

[dba]
;dba.default_handler=

; Local Variables:
; tab-width: 4
; End:
                                                                                                                                                                                                                                                                                                                                                                                                                          lamp/conf/phpinfo.php                                                                               000644  000765  000024  00000000024 13564465250 016407  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <?php
phpinfo();
?>
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            lamp/conf/libiconv-glibc-2.16.patch                                                                 000644  000765  000024  00000001061 13564465250 020525  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         --- srclib/stdio.in.h.orig	2019-01-28 05:12:37.000000000 +0800
+++ srclib/stdio.in.h	2019-08-12 11:44:16.902282369 +0800
@@ -751,7 +751,9 @@ _GL_WARN_ON_USE (getline, "getline is un
    removed it.  */
 #undef gets
 #if HAVE_RAW_DECL_GETS && !defined __cplusplus
-_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");
+#if defined(__GLIBC__) && !defined(__UCLIBC__) && !__GLIBC_PREREQ(2, 16)
+ _GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");
+#endif
 #endif
 
 #if @GNULIB_OBSTACK_PRINTF@ || @GNULIB_OBSTACK_PRINTF_POSIX@                                                                                                                                                                                                                                                                                                                                                                                                                                                                               lamp/conf/ocp.php                                                                                   000644  000765  000024  00000044275 13564465250 015545  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <?php
/*
 * OCP - Opcache Control Panel
 * Original Author: _ck_   (with contributions by GK, stasilok)
 * Version: 0.2.0
*/

// ini_set('display_errors',1); error_reporting(-1);

if ( count(get_included_files())>1 || php_sapi_name()=='cli' || empty($_SERVER['REMOTE_ADDR']) ) { die('Indirect access not allowed'); }  // weak block against indirect access

$time=time();
define('CACHEPREFIX',function_exists('opcache_reset')?'opcache_':(function_exists('accelerator_reset')?'accelerator_':''));

if ( !empty($_GET['RESET']) ) {	
	if ( function_exists(CACHEPREFIX.'reset') ) { call_user_func(CACHEPREFIX.'reset'); }
	header( 'Location: '.str_replace('?'.$_SERVER['QUERY_STRING'],'',$_SERVER['REQUEST_URI']) ); 
	exit;
}

if ( !empty($_GET['RECHECK']) ) {
	if ( function_exists(CACHEPREFIX.'invalidate') ) { 
		$recheck=trim($_GET['RECHECK']); $files=call_user_func(CACHEPREFIX.'get_status');
		if (!empty($files['scripts'])) { 
			foreach ($files['scripts'] as $file=>$value) { 
				if ( $recheck==='1' || strpos($file,$recheck)===0 )  call_user_func(CACHEPREFIX.'invalidate',$file); 
			} 
		}
		header( 'Location: '.str_replace('?'.$_SERVER['QUERY_STRING'],'',$_SERVER['REQUEST_URI']) ); 
	} else { echo 'Sorry, this feature requires Zend Opcache newer than April 8th 2013'; }
	exit;
}

topheader();

if ( !function_exists(CACHEPREFIX.'get_status') ) { echo '<h2>Opcache not detected?</h2>'; exit; }

if ( !empty($_GET['FILES']) ) { echo '<h2>files cached</h2>'; files_display(); echo '</div></body></html>'; exit; }

if ( !(isset($_REQUEST['GRAPHS']) && !$_REQUEST['GRAPHS']) && CACHEPREFIX=='opcache_') { graphs_display(); if ( !empty($_REQUEST['GRAPHS']) ) { exit; } }

// some info is only available via phpinfo? sadly buffering capture has to be used
ob_start();
phpinfo(8);
$phpinfo = ob_get_contents();
ob_end_clean();

if ( !preg_match( '/module\_Zend (Optimizer\+|OPcache).+?(\<table[^>]*\>.+?\<\/table\>).+?(\<table[^>]*\>.+?\<\/table\>)/s', $phpinfo, $opcache) ) { }  // todo

if ( function_exists(CACHEPREFIX.'get_configuration') ) { echo '<h2>general</h2>'; $configuration=call_user_func(CACHEPREFIX.'get_configuration'); }

$host=function_exists('gethostname')?@gethostname():@php_uname('n'); if (empty($host)) { $host=empty($_SERVER['SERVER_NAME'])?$_SERVER['HOST_NAME']:$_SERVER['SERVER_NAME']; }
$version=array('Host'=>$host);
$version['PHP Version']='PHP '.(defined('PHP_VERSION')?PHP_VERSION:'???').' '.(defined('PHP_SAPI')?PHP_SAPI:'').' '.(defined('PHP_OS')?' '.PHP_OS:'');
$version['Opcache Version']=empty($configuration['version']['version'])?'???':$configuration['version'][CACHEPREFIX.'product_name'].' '.$configuration['version']['version']; 
print_table($version);

if ( !empty($opcache[2]) ) { echo preg_replace('/\<tr\>\<td class\="e"\>[^>]+\<\/td\>\<td class\="v"\>[0-9\,\. ]+\<\/td\>\<\/tr\>/','',$opcache[2]); }

if ( function_exists(CACHEPREFIX.'get_status') && $status=call_user_func(CACHEPREFIX.'get_status') ) {
	$uptime=array();
	if ( !empty($status[CACHEPREFIX.'statistics']['start_time']) ) { 
		$uptime['uptime']=time_since($time,$status[CACHEPREFIX.'statistics']['start_time'],1,'');
	}
	if ( !empty($status[CACHEPREFIX.'statistics']['last_restart_time']) ) { 
		$uptime['last_restart']=time_since($time,$status[CACHEPREFIX.'statistics']['last_restart_time']); 		
	}
	if (!empty($uptime)) {print_table($uptime);}
	
	if ( !empty($status['cache_full']) ) { $status['memory_usage']['cache_full']=$status['cache_full']; }
	
	echo '<h2 id="memory">memory</h2>';
	print_table($status['memory_usage']);
	unset($status[CACHEPREFIX.'statistics']['start_time'],$status[CACHEPREFIX.'statistics']['last_restart_time']);
	echo '<h2 id="statistics">statistics</h2>';
	print_table($status[CACHEPREFIX.'statistics']);
}

if ( empty($_GET['ALL']) ) { meta_display(); exit; }
  
if ( !empty($configuration['blacklist']) ) { echo '<h2 id="blacklist">blacklist</h2>'; print_table($configuration['blacklist']); }

if ( !empty($opcache[3]) ) { echo '<h2 id="runtime">runtime</h2>'; echo $opcache[3]; }

$name='zend opcache';
$functions=get_extension_funcs($name); 
if (!$functions) { $name='zend optimizer+'; $functions=get_extension_funcs($name); }
if ($functions) { echo '<h2 id="functions">functions</h2>'; print_table($functions);  } else { $name=''; }

$level=trim(CACHEPREFIX,'_').'.optimization_level';
if (isset($configuration['directives'][$level])) {
	echo '<h2 id="optimization">optimization levels</h2>';		
	$levelset=strrev(base_convert($configuration['directives'][$level], 10, 2));
	$levels=array(
		1=>'<a href="http://wikipedia.org/wiki/Common_subexpression_elimination">Constants subexpressions elimination</a> (CSE) true, false, null, etc.<br />Optimize series of ADD_STRING / ADD_CHAR<br />Convert CAST(IS_BOOL,x) into BOOL(x)<br />Convert <a href="http://www.php.net/manual/internals2.opcodes.init-fcall-by-name.php">INIT_FCALL_BY_NAME</a> + <a href="http://www.php.net/manual/internals2.opcodes.do-fcall-by-name.php">DO_FCALL_BY_NAME</a> into <a href="http://www.php.net/manual/internals2.opcodes.do-fcall.php">DO_FCALL</a>',
		2=>'Convert constant operands to expected types<br />Convert conditional <a href="http://php.net/manual/internals2.opcodes.jmp.php">JMP</a>  with constant operands<br />Optimize static <a href="http://php.net/manual/internals2.opcodes.brk.php">BRK</a> and <a href="<a href="http://php.net/manual/internals2.opcodes.cont.php">CONT</a>',
		3=>'Convert $a = $a + expr into $a += expr<br />Convert $a++ into ++$a<br />Optimize series of <a href="http://php.net/manual/internals2.opcodes.jmp.php">JMP</a>',
		4=>'PRINT and ECHO optimization (<a href="https://github.com/zend-dev/ZendOptimizerPlus/issues/73">defunct</a>)',
		5=>'Block Optimization - most expensive pass<br />Performs many different optimization patterns based on <a href="http://wikipedia.org/wiki/Control_flow_graph">control flow graph</a> (CFG)',
		9=>'Optimize <a href="http://wikipedia.org/wiki/Register_allocation">register allocation</a> (allows re-usage of temporary variables)',
		10=>'Remove NOPs'
	);
	echo '<table width="600" border="0" cellpadding="3"><tbody><tr class="h"><th>Pass</th><th>Description</th></tr>';
	foreach ($levels as $pass=>$description) {
		$disabled=substr($levelset,$pass-1,1)!=='1' || $pass==4 ? ' white':'';
		echo '<tr><td class="v center middle'.$disabled.'">'.$pass.'</td><td class="v'.$disabled.'">'.$description.'</td></tr>';
	}
	echo '</table>';
}

if ( isset($_GET['DUMP']) ) { 
	if ($name) { echo '<h2 id="ini">ini</h2>'; print_table(ini_get_all($name,true)); } 
	foreach ($configuration as $key=>$value) { echo '<h2>',$key,'</h2>'; print_table($configuration[$key]); } 
	exit;
}

meta_display();

echo '</div></body></html>';

exit;

####################
### Functions ######

function time_since($time,$original,$extended=0,$text='ago') {	
	$time =  $time - $original; 
	$day = $extended? floor($time/86400) : round($time/86400,0); 
	$amount=0; $unit='';
	if ( $time < 86400) {
		if ( $time < 60)		{ $amount=$time; $unit='second'; }
		elseif ( $time < 3600) { $amount=floor($time/60); $unit='minute'; }
		else				{ $amount=floor($time/3600); $unit='hour'; }			
	} 
	elseif ( $day < 14) 	{ $amount=$day; $unit='day'; }
	elseif ( $day < 56) 	{ $amount=floor($day/7); $unit='week'; }
	elseif ( $day < 672) { $amount=floor($day/30); $unit='month'; }
	else {			  $amount=intval(2*($day/365))/2; $unit='year'; }
	
	if ( $amount!=1) {$unit.='s';}	
	if ($extended && $time>60) { $text=' and '.time_since($time,$time<86400?($time<3600?$amount*60:$amount*3600):$day*86400,0,'').$text; }
	
	return $amount.' '.$unit.' '.$text;
}

function print_table($array,$headers=false) {
	if ( empty($array) || !is_array($array) ) {return;} 
  	echo '<table border="0" cellpadding="3" width="600">';
  	if (!empty($headers)) {
  		if (!is_array($headers)) {$headers=array_keys(reset($array));}
  		echo '<tr class="h">';
  		foreach ($headers as $value) { echo '<th>',$value,'</th>'; }
  		echo '</tr>';  			
  	}
  	foreach ($array as $key=>$value) {
    		echo '<tr>';
    		if ( !is_numeric($key) ) { 
      			$key=ucwords(str_replace('_',' ',$key));
      			echo '<td class="e">',$key,'</td>'; 
      			if ( is_numeric($value) ) {
        				if ( $value>1048576) { $value=round($value/1048576,1).'M'; }
        				elseif ( is_float($value) ) { $value=round($value,1); }
      			}
    		}
    		if ( is_array($value) ) {
      			foreach ($value as $column) {
         			echo '<td class="v">',$column,'</td>';
      			}
      			echo '</tr>';
    		}
    		else { echo '<td class="v">',$value,'</td></tr>'; } 
	}
 	echo '</table>';
}

function files_display() {			
	$status=call_user_func(CACHEPREFIX.'get_status');
	if ( empty($status['scripts']) ) {return;}
	if ( isset($_GET['DUMP']) ) { print_table($status['scripts']); exit;}
    	$time=time(); $sort=0; 
	$nogroup=preg_replace('/\&?GROUP\=[\-0-9]+/','',$_SERVER['REQUEST_URI']);
	$nosort=preg_replace('/\&?SORT\=[\-0-9]+/','',$_SERVER['REQUEST_URI']);
	$group=empty($_GET['GROUP'])?0:intval($_GET['GROUP']); if ( $group<0 || $group>9) { $group=1;}
	$groupset=array_fill(0,9,''); $groupset[$group]=' class="b" ';
	
	echo '<div class="meta">';
	echo '<a '.$groupset[0].'href="'.$nogroup.'">ungroup</a> | ';
	for($i=1;$i<10;$i++){
		echo '<a '.$groupset[$i].'href="'.$nogroup.'&GROUP='.$i.'">'.$i.'</a> | ';
	}
	echo '</div>';
		
	if ( !$group ) { $files =& $status['scripts']; }
	else {		
		$files=array(); 
		foreach ($status['scripts'] as $data) { 
			if ( preg_match('@^[/]([^/]+[/]){'.$group.'}@',$data['full_path'],$path) ) { 
				if ( empty($files[$path[0]])) { $files[$path[0]]=array('full_path'=>'','files'=>0,'hits'=>0,'memory_consumption'=>0,'last_used_timestamp'=>'','timestamp'=>''); }
				$files[$path[0]]['full_path']=$path[0];
				$files[$path[0]]['files']++;
				$files[$path[0]]['memory_consumption']+=$data['memory_consumption'];						
				$files[$path[0]]['hits']+=$data['hits'];
				if ( $data['last_used_timestamp']>$files[$path[0]]['last_used_timestamp']) {$files[$path[0]]['last_used_timestamp']=$data['last_used_timestamp'];}
				if ( $data['timestamp']>$files[$path[0]]['timestamp']) {$files[$path[0]]['timestamp']=$data['timestamp'];}							
			}					
		}
	}
		
	if ( !empty($_GET['SORT']) ) {
		$keys=array(
			'full_path'=>SORT_STRING,
			'files'=>SORT_NUMERIC,
			'memory_consumption'=>SORT_NUMERIC,
			'hits'=>SORT_NUMERIC,
			'last_used_timestamp'=>SORT_NUMERIC,
			'timestamp'=>SORT_NUMERIC
		);
		$titles=array('','path',$group?'files':'','size','hits','last used','created');
		$offsets=array_keys($keys);
		$key=intval($_GET['SORT']);
		$direction=$key>0?1:-1;
		$key=abs($key)-1;
		$key=isset($offsets[$key])&&!($key==1&&empty($group))?$offsets[$key]:reset($offsets);
		$sort=array_search($key,$offsets)+1;
		$sortflip=range(0,7); $sortflip[$sort]=-$direction*$sort;
		if ( $keys[$key]==SORT_STRING) {$direction=-$direction; }
		$arrow=array_fill(0,7,''); $arrow[$sort]=$direction>0?' &#x25BC;':' &#x25B2;';
		$direction=$direction>0?SORT_DESC:SORT_ASC;
		$column=array(); foreach ($files as $data) { $column[]=$data[$key]; }
		array_multisort($column, $keys[$key], $direction, $files);
	}

	echo '<table border="0" cellpadding="3" width="960" id="files">
         		<tr class="h">';
         foreach ($titles as $column=>$title) {
         	if ($title) echo '<th><a href="',$nosort,'&SORT=',$sortflip[$column],'">',$title,$arrow[$column],'</a></th>';
         }
         echo '	</tr>';
    	foreach ($files as $data) {
    		echo '<tr>
    				<td class="v" nowrap><a title="recheck" href="?RECHECK=',rawurlencode($data['full_path']),'">x</a>',$data['full_path'],'</td>',
      				($group?'<td class="vr">'.number_format($data['files']).'</td>':''),
         			'<td class="vr">',number_format(round($data['memory_consumption']/1024)),'K</td>',
         			'<td class="vr">',number_format($data['hits']),'</td>',              					
         			'<td class="vr">',time_since($time,$data['last_used_timestamp']),'</td>',
         			'<td class="vr">',empty($data['timestamp'])?'':time_since($time,$data['timestamp']),'</td>
         		</tr>';
	}
	echo '</table>';
}

function graphs_display() {
	$graphs=array();
	$colors=array('green','brown','red');
	$primes=array(223, 463, 983, 1979, 3907, 7963, 16229, 32531, 65407, 130987);
	$configuration=call_user_func(CACHEPREFIX.'get_configuration'); 
	$status=call_user_func(CACHEPREFIX.'get_status');

	$graphs['memory']['total']=$configuration['directives']['opcache.memory_consumption'];
	$graphs['memory']['free']=$status['memory_usage']['free_memory'];
	$graphs['memory']['used']=$status['memory_usage']['used_memory'];
	$graphs['memory']['wasted']=$status['memory_usage']['wasted_memory'];

	$graphs['keys']['total']=$status[CACHEPREFIX.'statistics']['max_cached_keys'];	
	foreach ($primes as $prime) { if ($prime>=$graphs['keys']['total']) { $graphs['keys']['total']=$prime; break;} }
	$graphs['keys']['free']=$graphs['keys']['total']-$status[CACHEPREFIX.'statistics']['num_cached_keys'];
	$graphs['keys']['scripts']=$status[CACHEPREFIX.'statistics']['num_cached_scripts'];
	$graphs['keys']['wasted']=$status[CACHEPREFIX.'statistics']['num_cached_keys']-$status[CACHEPREFIX.'statistics']['num_cached_scripts'];

	$graphs['hits']['total']=0;
	$graphs['hits']['hits']=$status[CACHEPREFIX.'statistics']['hits'];
	$graphs['hits']['misses']=$status[CACHEPREFIX.'statistics']['misses'];
	$graphs['hits']['blacklist']=$status[CACHEPREFIX.'statistics']['blacklist_misses'];
	$graphs['hits']['total']=array_sum($graphs['hits']);

	$graphs['restarts']['total']=0;
	$graphs['restarts']['manual']=$status[CACHEPREFIX.'statistics']['manual_restarts'];
	$graphs['restarts']['keys']=$status[CACHEPREFIX.'statistics']['hash_restarts'];
	$graphs['restarts']['memory']=$status[CACHEPREFIX.'statistics']['oom_restarts'];
	$graphs['restarts']['total']=array_sum($graphs['restarts']);

	foreach ( $graphs as $caption=>$graph) {
	echo '<div class="graph"><div class="h">',$caption,'</div><table border="0" cellpadding="0" cellspacing="0">';	
	foreach ($graph as $label=>$value) {
		if ($label=='total') { $key=0; $total=$value; $totaldisplay='<td rowspan="3" class="total"><span>'.($total>999999?round($total/1024/1024).'M':($total>9999?round($total/1024).'K':$total)).'</span><div></div></td>'; continue;}
		$percent=$total?floor($value*100/$total):''; $percent=!$percent||$percent>99?'':$percent.'%';
		echo '<tr>',$totaldisplay,'<td class="actual">', ($value>999999?round($value/1024/1024).'M':($value>9999?round($value/1024).'K':$value)),'</td><td class="bar ',$colors[$key],'" height="',$percent,'">',$percent,'</td><td>',$label,'</td></tr>';
		$key++; $totaldisplay='';
	}
	echo '</table></div>',"\n";
	}
}
function topheader(){
	?><!DOCTYPE html>
<html>
<head>
	<title>OCP - Opcache Control Panel</title>
	<meta name="ROBOTS" content="NOINDEX,NOFOLLOW,NOARCHIVE" />

<style type="text/css">
	body {background-color: #fff; color: #000;}
	body, td, th, h1, h2 {font-family: sans-serif;}
	pre {margin: 0px; font-family: monospace;}
	a:link,a:visited {color: #000099; text-decoration: none;}
	a:hover {text-decoration: underline;}
	table {border-collapse: collapse; width: 600px; }
	.center {text-align: center;}
	.center table { margin-left: auto; margin-right: auto; text-align: left;}
	.center th { text-align: center !important; }
	.middle {vertical-align:middle;}
	td, th { border: 1px solid #000; font-size: 75%; vertical-align: baseline; padding: 3px; } 
	h1 {font-size: 150%;}
	h2 {font-size: 125%;}
	.p {text-align: left;}
	.e {background-color: #ccccff; font-weight: bold; color: #000; width:50%; white-space:nowrap;}
	.h {background-color: #9999cc; font-weight: bold; color: #000;}
	.v {background-color: #cccccc; color: #000;}
	.vr {background-color: #cccccc; text-align: right; color: #000; white-space: nowrap;}
	.b {font-weight:bold;}
	.white, .white a {color:#fff;} 	
	img {float: right; border: 0px;}
	hr {width: 600px; background-color: #cccccc; border: 0px; height: 1px; color: #000;}
	.meta, .small {font-size: 75%; }
	.meta {margin: 2em 0;}
	.meta a, th a {padding: 10px; white-space:nowrap; }
	.buttons {margin:0 0 1em;}
	.buttons a {margin:0 15px; background-color: #9999cc; color:#fff; text-decoration:none; padding:1px; border:1px solid #000; display:inline-block; width:5em; text-align:center;}
	#files td.v a {font-weight:bold; color:#9999cc; margin:0 10px 0 5px; text-decoration:none; font-size:120%;}
	#files td.v a:hover {font-weight:bold; color:#ee0000;}
	.graph {display:inline-block; width:145px; margin:1em 0 1em 1px; border:0; vertical-align:top;}
	.graph table {width:100%; height:150px; border:0; padding:0; margin:5px 0 0 0; position:relative;}
	.graph td {vertical-align:middle; border:0; padding:0 0 0 5px;}
	.graph .bar {width:25px; text-align:right; padding:0 2px; color:#fff;}
	.graph .total {width:34px; text-align:center; padding:0 5px 0 0;}
	.graph .total div {border:1px dashed #888; border-right:0; height:99%; width:12px; position:absolute; bottom:0; left:17px; z-index:-1;}
	.graph .total span {background:#fff; font-weight:bold;}
	.graph .actual {text-align:right; font-weight:bold; padding:0 5px 0 0;} 
	.graph .red {background:#ee0000;}
	.graph .green {background:#00cc00;}
	.graph .brown {background:#8B4513;}
</style>
<!--[if lt IE 9]><script type="text/javascript" defer="defer">
window.onload=function(){var i,t=document.getElementsByTagName('table');for(i=0;i<t.length;i++){if(t[i].parentNode.className=='graph')t[i].style.height=150-(t[i].clientHeight-150)+'px';}}
</script><![endif]--> 
</head>

<body>
<div class="center">

<h1><a href="?">Opcache Control Panel</a></h1>

<div class="buttons">
	<a href="?ALL=1">Details</a>
	<a href="?FILES=1&GROUP=2&SORT=3">Files</a>
	<a href="?RESET=1" onclick="return confirm('RESET cache ?')">Reset</a>
	<?php if ( function_exists(CACHEPREFIX.'invalidate') ) { ?>
	<a href="?RECHECK=1" onclick="return confirm('Recheck all files in the cache ?')">Recheck</a>
	<?php } ?>
	<a href="?" onclick="window.location.reload(true); return false">Refresh</a>
</div>

<?php

}

function meta_display() {
?>
<div class="meta">
	<a href="http://files.zend.com/help/Zend-Server-6/content/zendoptimizerplus.html">directives guide</a> | 
	<a href="http://files.zend.com/help/Zend-Server-6/content/zend_optimizer+_-_php_api.htm">functions guide</a> | 
	<a href="https://wiki.php.net/rfc/optimizerplus">wiki.php.net</a> |
	<a href="http://pecl.php.net/package/ZendOpcache">pecl</a> | 
	<a href="https://github.com/zend-dev/ZendOptimizerPlus/">Zend source</a> | 		
	<a href="https://gist.github.com/ck-on/4959032/?ocp.php">OCP latest</a>
</div>
<?php
}
                                                                                                                                                                                                                                                                                                                                   lamp/conf/httpd24-ssl.conf                                                                          000644  000765  000024  00000001040 13564465250 017171  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         Listen 443
AddType application/x-x509-ca-cert .crt
AddType application/x-pkcs7-crl .crl
SSLPassPhraseDialog  builtin
SSLSessionCache  "shmcb:logs/ssl_scache(512000)"
SSLSessionCacheTimeout  300
SSLUseStapling On
SSLStaplingCache "shmcb:logs/ssl_stapling(512000)"
SSLProtocol -All +TLSv1.2 +TLSv1.3
SSLProxyProtocol -All +TLSv1.2 +TLSv1.3
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES:!CAMELLIA:!AES128
SSLProxyCipherSuite HIGH:!aNULL:!MD5:!3DES:!CAMELLIA:!AES128
SSLHonorCipherOrder on
SSLCompression off
Mutex sysvsem default
SSLStrictSNIVHostCheck on                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                lamp/conf/libmemcached-build.patch                                                                  000644  000765  000024  00000001107 13564465250 020751  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         diff -up ./clients/memflush.cc.old ./clients/memflush.cc
--- ./clients/memflush.cc.old	2017-02-12 10:12:59.615209225 +0100
+++ ./clients/memflush.cc	2017-02-12 10:13:39.998382783 +0100
@@ -39,7 +39,7 @@ int main(int argc, char *argv[])
 {
   options_parse(argc, argv);
 
-  if (opt_servers == false)
+  if (!opt_servers)
   {
     char *temp;
 
@@ -48,7 +48,7 @@ int main(int argc, char *argv[])
       opt_servers= strdup(temp);
     }
 
-    if (opt_servers == false)
+    if (!opt_servers)
     {
       std::cerr << "No Servers provided" << std::endl;
       exit(EXIT_FAILURE);
                                                                                                                                                                                                                                                                                                                                                                                                                                                         lamp/conf/index_cn.html                                                                             000644  000765  000024  00000010312 13564465250 016711  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
    <title>LAMP一键安装包 by Teddysun</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="keywords" content="LAMP,LAMP一键安装包,一键安装包">
    <meta name="description" content="您已成功安装LAMP一键安装包！">
    <style type="text/css">
        body {
            color: #333333;
            font-family: "Microsoft YaHei", tahoma, arial, helvetica, sans-serif;
            font-size: 14px;
        }
        
        .links {
            color: #06C
        }
        
        #main {
            margin-right: auto;
            margin-left: auto;
            width: 600px;
        }
        
        a {
            text-decoration: none;
            color: #06C;
            -webkit-transition: color .2s;
            -moz-transition: color .2s;
            -ms-transition: color .2s;
            -o-transition: color .2s;
            transition: color .2s
        }
    </style>
</head>

<body>
    <div id="main">
        <div align="center"><span style="font-size:18px;color:red;">恭喜您，LAMP 一键安装包安装成功！</span></div>
        <div align="center">
            <a href="https://lamp.sh/" target="_blank"><img src="./lamp.png" alt="LAMP一键安装包"></a>
        </div>
        <p>
            <span><strong>查看本地环境：</strong></span>
            <a href="./p_cn.php" target="_blank" class="links">PHP探针</a>
            <a href="./phpinfo.php" target="_blank" class="links">phpinfo</a>
            <a href="./phpmyadmin/" target="_blank" class="links">phpMyAdmin</a>
            <a href="./kod/" target="_blank" class="links">KodExplorer</a>
            <a href="./index.html" target="_blank" class="links">English</a>
        </p>
        <p><span><strong>LAMP 使用方法：</strong></span></p>
        <p>
            <li>lamp [add | del | list]：创建，删除，列出虚拟主机</li>
        </p>
        <p><span><strong>LAMP 升级方法：</strong></span></p>
        <p>
            <li>执行脚本：
                <font color="#008000">./upgrade.sh</font>
            </li>
        </p>
        <p><span><strong>LAMP 卸载方法：</strong></span></p>
        <p>
            <li>执行脚本：
                <font color="#008000">./uninstall.sh</font>
            </li>
        </p>
        <p><span><strong>程序默认安装目录：</strong></span></p>
        <p>
            <li>Apache：/usr/local/apache</li>
        </p>
        <p>
            <li>PHP：/usr/local/php</li>
        </p>
        <p>
            <li>MySQL：/usr/local/mysql</li>
        </p>
        <p>
            <li>MariaDB：/usr/local/mariadb</li>
        </p>
        <p>
            <li>Percona：/usr/local/percona</li>
        </p>
        <p><span><strong>可用命令一览：</strong></span></p>
        <p>
            <li>Apache：/etc/init.d/httpd (start|stop|restart|status)</li>
        </p>
        <p>
            <li>MySQL：/etc/init.d/mysqld (start|stop|restart|status)</li>
        </p>
        <p>
            <li>MariaDB：/etc/init.d/mysqld (start|stop|restart|status)</li>
        </p>
        <p>
            <li>Percona：/etc/init.d/mysqld (start|stop|restart|status)</li>
        </p>
        <p>
            <li>Memcached：/etc/init.d/memcached (start|stop|restart)</li>
        </p>
        <p>
            <li>Redis-server：/etc/init.d/redis-server (start|stop|restart)</li>
        </p>
        <p><span><strong>网站默认根目录：</strong></span></p>
        <p>
            <li>网站默认根目录：/data/www/default</li>
        </p>
        <p><span><strong>更多说明详见：</strong></span></p>
        <p>
            <li><a href="https://github.com/teddysun/lamp" target="_blank">Github 项目地址</a></li>
        </p>
        <p>
            <li><a href="https://lamp.sh/faq.html" target="_blank">LAMP 一键安装包常见问题</a></li>
        </p>
        <p align="center">
            <hr>
        </p>
        <p align="center">LAMP 一键安装包 by <a href="https://lamp.sh/" target="_blank">Teddysun</a></p>
    </div>
</body>

</html>                                                                                                                                                                                                                                                                                                                      lamp/conf/lamp.png                                                                                  000644  000765  000024  00000145155 13564465250 015711  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         �PNG

   IHDR  b     �"M  �4IDATx��@TǺ����Ko���{/�4�/��7M�=��k��5�kԨIl`�ذ� � ������7g��gAWa~��w��s����o�aYV �@ ��I�@��2	�@ /P&!��$�@ �@��@ �(���e�@ ^�LB ��I�@x�2	�@ /P&!��$�@ �@��@ �(���e�@ ^�LB ��I�@x�2	�@ /P&!��$�@ �@��@ �(���e�@ ^�LB ��I�@x�2	�@ /P&!��$���/����5�mA HeRY2	N�#�&��"����܅ )+w#MI���"��X�"��η�t3�}A�P�	R�2����� �XlQע�$4�����E�����␔�"�4�����#ru����"I(5�l1ޟ�E,��1)x#b�G�&�b|9��,����[?+��P3�+`X�y�n��.H��S�O�-��ʑ��A�!�g�[���I	[��|���ah0D��q�B�X�{��P܋��a�ްѥ�r+ػ�0�<����?2O ��ڇ^�K��eM��^X�߃L�$���%�2������U]���6T�L��Ti^�γK3T������3w!@�DLܩ���**���I]z�nE�e��֤��2�PH�s��vj���էb�E���i*mR�v� s��-ws�h:D���+������ei�~a�aPL$Ĥ"���uW��v�$b+s?�y�D��:Gd�\�f�6M&֩��܅ )��]�>;7/�D�K$)�W�E5k�7�B�ʋW�n�_�p��I��9ڵ����b���v��2�P�J�}K�u�4o8��%Qux�Wx�o"���NiPN2��iR.s���W��G��(Z�\�LB�DJF�별���$Ei]��;��	'3>��~�'�	�J���BE�N�r�
�VXĎg/��I�&l�w����K��P	2Y��,�t���կ�E���~���IH��qw�W�p\Zl;x�(*��a������R&�n/ON��c����U㱞�+�BE�LV��5���l{�l�d�.�*Be��kX�;�u���i�z_W����IH��Y�IF�"�'�ﱮ�g���h�ۄ�E���Ӕj#��45k�vl3����2^�>����[D��f��]Cs�G�}�d>���F.si�b��}cs?}�eR:�^^�yu��� ÐR�K/��7#z��Q��/OeR��ð�����,�XWȵ>9� f�H�(����Ѧ�Ouܡ�^��eRK�:��ʻ�;�:�.���$�h��vcaFv$Ƴ��J���i��թ��oR
i���!�DB˒=�)�h�rZmW�
�+�2-'/CE%$)�g�/Z7m��"�C&9hZ'ڴo9�ɡ��ˠ�2	)�Ĕ�7�.G�o�����ְk�S�~��
':�tD�Β���Zw���/��s��BА�lh���i��~!��onHq�%��7#���Z/�ژ�*(��R�~o���kB\db�7^��{xm��*�OR������ْ�X�����|�Ţwmp���{��/8&���DB�޾[D�|!��l2	*)Mk�5��@�N0���To�� T�l��sCeeb
�&���	,�+9�UVG��5��I���e�)�]�R'������������)�

[���?P�04խ�Z;�z�.��@�2	4R"��U�������o\����2T��$��i�H:CE�����.���򷶬���P&!���?�Q,*=��>"�k��k���K�*�R�t�V����R�u��M�w�5��}q1h"�a|�	��$բ�z���:S�LҴ��c{��L�� 4�y�2�����3�24�_\[&�$U����n:�J:�A��������Y��#����{,ӡ�l7g��%%�AH�2Х1���]{u�"�%os�"�>;w7j;߈�����5{�k1�ܥR(�L:ڷ�m��L�ciY1���y�>N,KS?n���NQ�]�LBx��~z��la�֣d)�pU�C٪"�����Q�E"��ifn M��m6��k�s\�>/#��5� �6�=��UI��=S�2�����{Q;��0�شR��5Ѡ���.���$���Q�b��yE��R�@��g�B�d�{�����[�.���@R�Z.�;��Z��4��)Z������㉬zv^/����ʐI�D#��dߎؘ�~W?�`J))J���ѻ�\sF�eb�670t�V�Q�n�,Dn��֭�=ʏ��^��8;��х��f�LZ��k�PX�q�I��a˄bE��Mݽ7�Y�5w�|�T�5i@���F�9���!r�^�pLX�s@����������.�N-��=�7V�>Ju���c�%1�>�K�5Z��B�w�'&_-3�(:"�c�Y5���l>z*U&\>��w#7���2��,���/�ٙ�<*(��\���mzz�$z�p�c�ٮ5ڙ�	 EHL��Ĥ[M@&�u�>k�|��^E�;4��4hr�r�xܿl�l���棧�e� ����ti&J}�J��g�����ˣ��2	1BVN|@�T��~�1h�4��];��f!�񉇱�0�,2��ɥ�=}��m��������b�
��x���y�2w�|�T�Ln��?hzb[����e��UU[eb�{Q�����:�7�� /A�=:o��p6�s@�t{irZXY�B���鮝V�����ܸ��E��R���k��=|6Iť/̅��=����#�F1�D7K����e�ɲe�ㅢ��Ac��L�,��"b��N�fT)���֤� s?
$�a/OV���cI2�E�1=���*:]ޅk�*��n_@�DԹ�l'�j��2x2�x?r0A�� �L~�<{y�v�F�hv�h���j������5b.���}2�^>�Б�A�N�FRJ)� ���vO�5ewuNN�rc�H�(���؎&�4��Q���.���� ��	��P&+(�)4C���LN�ettNo)�7��N�O�^M�ƛ]n7J�˹JB+� 5=�����-��2g�	���8�����M	Ieq5@Qw��&���>nއ5�<�~���d�M�P&?R��/�L�g�%�}�-���)tVf�#>WX}hоm��2�A8b������"�5��t��U�˶����	*Mb��u��k��];��z���'�A&cb�����7�$0x���޾[��j��<*(��"܍���o�q�	��=���js:�1��J}�G�n^�2Gs?Dp�κ�)���S�a���:���������[fbү B�t�!�V�X��� �7��Lz��M�����u�e���A�/O2y� ���h\�+�n"9 x2�A�9� Mm\oH��_����;4M��6A�My��J��9����j[��p�1G���+�5���K������|��l�$I�����M���N$*��(��7p+�o-R��~�Qӽ�Z{�F�?i&�Ϊ��|6
�V��=�V�m��X�)���FSZ�P#��Q���K�w�:0xz���6#���y�Q`��w��e2-�ᥐ�B���mp	{ۦ];�0waT<P&!o��<9���r7?�����>{y�����/��Χ�Rg���~�jMB������o,��;T����`z���'�n����uv���v����#��e��ͥ)����:n�VIw(��|r�._��0:�A��@�J�ʟ�X���5|:��a�D>>��O���F��u�Zg�p5��ݨ�q�ϼm`໲T����3j��J���7nE�AL�:s�(l��s\k�5waT<P&!�D�~�'�0�0����d߸����Y�O��6sɒ���ޛ�ks?_u�\����2�"7z��Pvh1��;o=e�Rȴl��Rs��N�DV~�7H��#)'�'�/�o�E�Ӵ��� �Hh��Y*�0waT<P&!:"/0d�F�����˲V����g/�>���n����n�FVն�D��}������<K�}�u�-��}��mg��w��}q!h"��'� ?d��[���vM�]Z+�!�E>�;{E��>� Ս=�5k8��%Q)@��p�|u+4l1ο�� ���~ݼѷŶg�>�<�D�tP?���v����G� @��չk�LG����!5�e��������1q�܏�&����V�D  ��k�bZmw?s���JYd�ɡ�O�e9�F���r+���̜�8&*��˰��G�U/7�(��q��%��n��]�b?1� 0tzNn,߸��X�S�y�Б�$%�	
�/�y���T�Qi����)��Ao\oh�z����L.��@���8.Si�����4uj�mS�8���.�igݨS��K	q	P�����A�*�Rit��Yq�19��5D�-�d3x}N��|;,4w1TP&!�2�b�T��]0�9Y��{�n2�k��#�q�Q�/u �������v���:�gL�a!��7\֦鄌�؄���Nδ�ڪ>0J�a�*M�ƥ�s�")m�o����/.��������e���C�T�d98o,��Lo�}Pm��<�R��C�(
*2�](c`^�f�^m�\�7Ee�$��;�[�"�'$I��ڢ�0��fd�]�1S��b�ai����}4�?�n-MM��S�0���n)A憄-�r.Hzu�"����yb��{k���/
���ٖ�v?��o|})��QI��,N�.���ReR������#(���_J�R��<'Mk=�>o�|��ˠ�2Yݡi�RȬ��"xS:"��{��m�;P��ʍ�9�������Ӻ������q�#�4A�����2>r^�Q?eA��84�o �c��5�=��yo�˔�8f<�M�u{���z����<���X�Sݜ;���>J�"�� 7Qá]�ֳ��U(�՝g	W�nA���CɤN~^MԄ'��މ�&���Q��m�^���~��Enޫˡ�iVkb8�J��S?�~���IW���F����Z�v(�*�֤_�D3Z�D1C6�ڤ� �&�B�x�!����4��W�o�&#�]f%�In2�ʲv׎+EB���r�2YݹvkiJ���Q?��ss���z���de�_�1��V��	�uZgSE}�>L��#�ݜL=�y&�Ҹ��u���}n��d���N�e7�r�M���W�Dn�7T� ���XY�fe@�,��_�@�:g������	)�{�I}�J�L���~��EMs?}�e�Z�T%��6�V��tl=�ũ��S]���g*�'I�<=��n
ͅ���3��w�GN��V�'ԯ��ou`�,���:k�ڪ�O�^9��0>��ֺ8zy\�XA؃��/��K1�N�̭��Z!n|b��&���&C�>�k�6M�H%6�~�(�՚Gq����`pAt��� ��xE�y��w!E���{z��t�T�f߸��e���;�V����A�^�9-�z|JcC���Y�K�6���t��Ӵ��|2����n�������g��Dn�[^�o}�O�����0w�}|��Կ#B(R����I�A�~����j�Š)9J�&��aݡ����S�eD�L�,Ldme�y����\�P��&�ԯ�� �B���ւ��O�n��oG��P$���I"��LJ�w��\� -%Y���$~�,�{���iuy];�tvhe����L�ԯ%a�֢����O#ρ�n�~��
���KJzԵ��M��t���vXe���Z����T�_��k�-�����k
C�T>�y//�NgY��9�T�=���κ:'�'V �X�d���qu�v��g/���rS��~�[N,ؤRg�N!)%_��'k���F���]r*���2,�04���2�^�\�X[���Y� ���
+��+.�71LJʤ�}�l/��݋��$��~x�נ}��7��x����>�	W�EmU�O&��C��^�����\؃M<�h��#\:�Ch��4N�I�q�r��_��Т`#�0篎SkS��h�Cj8��i7��%��Q�u���K�Ӎ[�pa�p;�"E-��v6�\���\��2YM]�����1i���u�>k�|lϙ�rw)b2� 8��[��ͫ`R��{Q�c����B�����lTwH�I&�:5 h2�ϧ�J���eGvNܵ[֧&u��iu�ED����Ȋ��'CɥN�|w�剠^�)C�e2W�RӔ�-�I`����2��B�acY�B�"��
�꫎@���D=>�0�O�6T������lk]�짽4=Wgb�4�b����&IUL��Aq����p��w:����T|.�ڭ�)�w�:�p�<Hu��+��#����b��Ijy~ݬa�)��?==$č/��b���^�-�0��Q���5�z�[ lz��po�((*�p
'C�e�ڡ�L@����8qs�f6� ��U����IH�̎2!���8�M��u=z�~NHy!HM@�T�6�o�Ӱ�����Ԯ�O�	��<�G1�a�iZ���3O�*''�g�P;�o���6u�����[�W��@��j�vX�h������Q�!�m|�W���J��I���S�\jTk���G�C���ttc�{[�4�58&.5��!��o�%��Ź��t/��#��޾����M�7��J>we(a�gacѠ[�h�!N�6�B�d���wD����-qf���j��keɟ�󞟽<J,�4���E�Q�~Y�e�2��I�"�I-,�:����������
�BQƣ�B�e��o�4�V��	�V&�ʕ����^2���˟歉|ץS�����T���%�y���|c_��J��>�8�dix��pe�iٹ��_�kg��nj���;�n��xc͓����W-��`��
�?��Q�U��F�o]�>����]J���fO#�,~/m��:���T��_Ff��ç�������(�X*6�V}�t��^�5���*9�çB�<Hz��Ri@�mgceoo�պ������xЙy+��y�c�?�~���V�uN��2�����I�&Iҷc�y���ٶ����"!nc!_�x����a{Dt��y�riN�R��K�32im�~]�uh�����u���K��<pR*�:b��S�~��.����O��|MUe����5��m>�܅�v��o�����Ĺ�ڷnn�;��a̱�'�LD{���ZL�����ɩ���,C���a���I.�/�+MSWo-�4��Cʥ��|�����0h윸g�(��-f���Is:�զ����BQ���>}����p�a���E�4�p�l,�O���~%/���)���"n�?��q{��ڲ�Q&>��2p4M3Z����n]at���Wm��D,����tx����F���������p��^w�XF�q˲Bs���:j�C���T/�3c�'�[(dJ�z��a���Շ�*�p�v��1�\e�9�lz�n���ĩ���]�
�_&��Z��f�Э�j;�z<;.M�S%`��;��g�����:�<���/���[���Vﴀ]�Ru46:�B&�$�-K�F��Si�1ES�}�q�bG���_���Y=Iiu:���Z�a�T,�q�K�_�cm�س~�q9�Ȥ yx�����3�L>z��o�x�at:�_/�����m��u��#��l,��\���a��;������8A
8"D���-�6
��R�ү����B��쫗L�JN=syHX䗽}��δ�����
���+7g�D�5��V����j��[7s�[���W�j4��;zc?o��wl0&���G;�b���[[�vunǷ��3�1{1�Y���n�dB�����k���h��6֖ѹU�	Ç�qw��SE=~z⟀���ٻ�U�&��v���i��3>�n۬��}��ZÁ ��/^9���i�R�xʈi�~(|8��w�I�����vn݂f��L���C`�i����n�	?{�;�8��L
�^��S��\0{��}tdd=�|}
zk�!���6���]��sS�V�L��.�L%5ʟ?�R���g���d��_
���X�?���]O����NM{rw	_<<}�@ԫ�e�&?�h[�0�FD�����s�Ԯ�&v�F�=Ի�/06R$9h��K7�ɥ�Z3zX���F�do�"7'�����%	)����<{�ߣ����;�dvnގ�g}3���C�ED-X��Vx�P(Vf��u/���}�j�E&	�T����'*h��Je��&�F��h4#���28��LLNJMU��6�n�NvvF�u�t:�R͝��ml���.IQyyy
U&�H��S�����(�alm�Kv�	B��Ԡ���XdiQ��u7�oHH�*�M������>������@k%�ʇ���FJ���ɩ��'G[G{K~E���2��^�+�J�N��,]���Q�>�F�NLN��Fӌ\.qwqqr,�X�@&	��r��fM�?��")| 
��n-Wkk�R<5-=��K� %q���N�6hE{��J�tkγ�C���qu��l���O`Ȝ���ex`	RӰ��MLM�����&P��W�i��mӮ�T*�Vg�g�ZX(p7v���D�֌�ʤ$E7�:T@��};�<�g}��~�ߋcf�44�]:�:���!�g�8x�L"Qi4�~��а-��w�ɜ���g|�u�yߴ��Ǥ�fS�X*$�Gw����ς5P]d2�JȜ�[X�{òb�hÒ���{*;un��_h�ٴdF�F�+6�>�����h��9��o��%�"���}n��rYvv���;�z�M�� zĔ��3�"�Y����'`��6�:(�I����{ޔх���3sYl|�.B�����Ц���Pk����d�i�n��m����!,�Ij����m3#3�g�.ݰ��N�N���s��^��#ID�'ެA��>������υ�����x������U���١C�f?�ۥ����̬�-{߼s#<�a�%$ź;�ul�|���>��v+�IP>˧��}��՛�J5x�$I7�[k`_�Q��s̻�c߱���&�f��	�N���[6�a����"�8ǝ�����Ipz֬�������yb���x��D�"'�ܷ�R{[S�d@10dF��)߬�>Џ]O�� ��oN��F$
v�������!��^Z�~'�jZ�nӊY]:�m�{諴,����t�����d7��z��nK%"�$��Զ���_$z9�8�
5m.�:a���LV�LN����k�~�i��K�b�P"�.��Y��}���"�g�_�n�R�U"ٶܫS~����S����y}pcw��
q��c�a`�|��g���k��������"-#����y����z���B�'}3��%�g�����R����U3���Qp�ԅ�w�W,���o��[<�,�VvC��Y.+~�
4R8.�֬�����f��ha�<~>�����������q9D ��rr����� �$I�Z��-��Y$H��GN����_7�V�Jp7E��Y0���\�5k���	B�p� ��ՃcUjM�����m3�$x$PgD��R+���N����mӤ��}���޿<��Ofn�H(_�<	�AR�p∁s'�X!&>�07�oy�ȗ?���C�u鰦�C)��*u���ɴɈ��rk���/uϰS�'Azw�n���!��r����
ͷ]���\rEݏ�<ꚳ�u�}�6V�'/<q�\&Q��#��|�bSI�SR�:��^�%�[iP���
��C�������T��^=�K�&�c!P&uzO�=�_bzO�r���S�n��k!�Q���@W��2c��V��ҀFS,ܼ�s�6�_;=n�:�4�ae!k������_<x�Т)U�?\>�Mƃ��NM\����"5=�A����
_1�~d�aEBPmص�~�z����g}������.���ٿ�i#���י�#���ɤ�Gܧk�߷�
��ɰt.�X��nbM?��o>��c+�v�}!N�Y�����9��p���4�X2"��S�&,Z�+
�tʳV����ޣ����<�J,)՚�����Rx 6!1����b	x�n�v*�.,�IzF&Aq&2h_�N�W�Cp5����X����v��[[*?}��<1e��)�1�\ �����B&iX�V�:�QO�?{�Ց@�Am����V-�Z�q�޶i�a�X4L!��iV����YRZ��'�*��T����l滿e��MWk���g0�u��ؚ�b�El�⿲,�%��VM~�_�R�|���{��p�9^m���t4�sӮ����<M���m[Yn�8�Y���V��c����9?��W�o�9K"�ܹ�R��i;g����\ȭ{=���������7.5������b�^K��e]=k�~�H e�yIʫ]��g�ճ��@&�߱�̥���ՠkVv�O��i�9@�j�8^;�[*����*��$��:���ב H�:?sa�Ї��DFet��ծ�b��n>��d/\
��dCf��aG۫���ʟ*�L
8���ԥ��"��:�l����/��?6>9=�jk���[kת��n��O��z@ ���jMV����
Y+s$:� �?C&��^[�F�;�*���L�@#G�|Ղ)?�0iᆇ��A��]�N�q��o
~�(����M�
GO�7u�f`$��*��?~�P�v`�v�rD̳��������1�B��|ߋ�:z�✟F�p�L�4��h�}�쎯#\�:r�r�� 5����|tG���I�����d\$$)�EC��'�j��cy?"j����Y1����m�7��yI��L$ѿe�^k�x铎��o/�PQ��@C��w��ܹ�s�eD]�1�|�$)u�ڃ�7��	/���U��:bԐ��,*"c�;_�[*��$��v�n�� GM_z��yK9���H��Q����͵����·S�Z)�s�>�S~4q�O�;q�г��&|7���+�IT_/�,))ܠPH�iƄ�Ε��Wh�'77w��mO�VT���y�;�k��,�7�oF�dX�u�ɜ�w�܂�E�$��/`�̟q7*���
z=��.k_4�������me!��ιr����;��I���v�~R�����პ�H:j�J�޳v����}��Q��qx�;�T5��uA������-�w�����ʲH�� ��lpp{�E�|�cb{G3����wp�D\J����Eg.1Ao�6�^W����5k���Ev�r�衋f�ut����
��u��9���jP�v���Y����~�~!8L*�����+:�r7<���Ek4����uջ���q�N�&������qq���fvY�F���k4�4����s�iֵ��3O�2�aԈ	/�];,-��݄y�CAS[��.����>�ݿ�1"�)����js��u�u:ݢ5�������8:V�7i5r�S�|+��`�:���r`��1�[7.��i?3�@�%���`Z��:�I��Flh�5(BQ��!_�����+`��1����r#19� ����_������}�jf�I�
#�8�E��0R�!\jtnZ4I�6����O&e2��\v���	�|7��'�~�paVN������%~��H��౑���1�:�6=�o����2�_o�F�}1x*I������J�y�����d�����ML�$3@��ƞÚ5,�"�L"͜?��u��6֠ѳ�AO�Ex��~��ET6+'������7ã��;��RRC�?7ecmq�H$�(�	s�_�ޑ�����=����S�����-m[�{��y���l�r�T˦����q_%w0XB�����=���_��Aд:�7�����~+|˳�|���(M6�Դ��2��^��'�O�w�wy��M��q�+�	Aſ4Q�ND��x$b�޾��Z������)�yJ�������u��g�L�E��<���+�x�5)�ѓ�%�w]�y� �Q�{vh�d�9^�j�~���ɩ#͇2YȚ3��+�b���?�Q���:P$ ����D�Q��=jH��'��"-�eR�WJ�]E��(m횟vh5���Re�R.=�g]��EB��<���#霼���V��?J�.2	�q����T�q�Z�k߼ѡ?۔aQ���4�RX�ӱι�2W?sٿ#�/.ݎ؄�w�'v�\87a!����ԦE�诋�����1P��:�s��ko,P?rj��/�A����c�l4�2ō��X*.�����1#3�u�a:X��W���m,�qL� 2٬�`P�s���SGM��䕠C~Z`=�ڱU�6-������o@Pԓg@Ԝ쬯�e�n���ޘ����D�D��i>�ݥSO��})x�P$�{��+��Ư������՛��2���$�!R�K�^'q�j�]��1.�x�=�ZڹŸ!��w���T"qu��v�WK�G�������nܕʤ���ZӼA���K��DױS��Xf�t�6���J�z�Թ���7�:wܷ3&7l�2	j�o������+>7)�IWo��t�us�����BU�G�紳V���Q��͗)��2Y�P���k��-��X^���5tA1+��m{.\�+�q^�(r��-������F�t��u�����+2έV�{1d2A�bł
Ѫi[�T���Ĝ5;Y���U��}��T���^1�f���D���� `��\�6��+�v�pr����9x0�n}���RAi�"�qϛ�ȗ�%SGM���#�'�[ce� c�,�8+"� 	ǁu��hrr���e�wN��f"s���A!/�� 7�<9O�ȷ��$U�jh�6�G�{��~r���eȶ�'ծ��qa���~?.
Aa�����mZ䩔>�F&����d����,�f���=Wn��b@	`�9�N�7�t�n��lm,���/{m]9��YVn���M{--8�_V��?�e	ʤiO�9�6�0��
4���
4���"�@.��YY}ֽS���n5ͰV�0P&9J�&{���eR��|3a޵��(�����E3�*���g�Bg �>��Aºw^omU�m�]:��oy�x���� ��6֍�w\Y��T��s�����r�4�{����p�j��_��a;+Iy�i�e��-7��}Y����?wk+K�LFs�u"0%9����Ai�C&w�{�µ6V�47� ._�#H�q������.���1h���-����DD����	3aN��t����_��u��2Py�xHU���Z4z�i�y������{ ��}��ް������/nf��Ҳi�R�{���3�v#�ZA��n&)�����(��G�s���6����|?i�?����^�R�?����HLP&�q�dN����a_}J��TYY���X�@�����=�'������e�/�dR	E3(�}������,�����''��j:8'0%�,<�vZ!��X�/^�	[,*L<�!w/�M��S�etݾm�_�U:wp�R�.�sss���HM�� �<��F{�!�n랟w �H�L>�Թ���ͣz��?�c��4�!�GO_5s�\&Y9��O{`�=9�B$rqvz��NL�tk�X�;�	ꅻK�b�����p��tp�%{Zz�Y�޾[����}v��X��U��v�m��D�a#'/>y1H,�[[��gߌe�����h����޷Q$���~�F�Gǡ��ht�W�F���)a�+IRg��o��xx��W)��~���2I�����4A�|���~��ݠ�����I���d�� d2�ґ�E=#�b�'�q�����k��i�H$&)��[���\�V��"<��A�:�
�$5�'i��&=Y��4i������|!x�NW����_���H����?L�q!�`������t#l��y4+P�U�Yի�w��g-Y���?B\X0�
��>_���M -����Փ�ʤ��,�L���~���F��h�����	�UZ<:���m.	2�M�)�%��4!a?�J�Q��%Hu�z�4m�v_�����%�MQY�.���7ݻ�WC��_ �j�v҈AO���h)�\3��ÊD2�ќ8g���":�Y_=�ːtv��ߗm�#�J�:�K��'�n0z���v8��I��W�tٽ�$��#v��a`��!�F�|@��(�L�����+�RIVN��]�>��S��5[�����X�lq��}��捻g灎�L*�xh[XxԄ��B�F�kո�6I$��6������PLhҘ�QTڭ�*+�J�pq3|ˋ�(.2�G$������S��5���M�,�y'��o'�D"Шum���u8�_	�9l�B��)U'v�I�~�=M nd򯝆(w�7�^�u��B���\7�E����&T9d��>�&�e28��Brj���}�g���f* ��й���B:��9h�y�u�i��gNL�t{�H(+�!�]��>[--�n��C��$�]7�j�۵�J�"!���~���+��=�D.��l|b�L^����{�o�.�.EVI�����zl��P�j�����W������	/��q!�Uk��=~xqO�?��3a�:�ޓ@,ܺ�s����$� ��T���CP&+(���Qџ?� i`z�mzp��29���)�?�r�>-hdA�2�dr��C��t9y����5������ɗ�ߵ���T���X9����[��jzIM6�zt^]I��UZxH�b�LN��Mx�]�������$���|��Q��ߍ��DDO^���ӗ��T��M>�?�)*��g�M�$I����k�BCT3�V�uϑ�;`B�a+���Mu<����v8p!��I?��K.�7�<����{�������rȤ�"�ǜU;l�-u:ҫm����Ԯ�ye������_������(74M_���q���d=:��P8���5���!I2�����cm�ٽ���5�n������'��$�e��u=z�����?o���2����M���;<;;��g߉��W�u��������1�����j�}�X�����wE�%�����[�,,��1��}�7�3W''��=y��s���L���ٹ���ݴ���-�L�E"Ћ�=�[ �t�u��P�~����DP&+(��IP�}���z:��qq�suvbY$9--�y"�0b��+ݢ2�|�Ε[XY)�Z��=:��y�>� 99��q)iY�5't��sƏ�f�;Bvn�Š��'�Z1��m�lJ=���i`����C�䪞���^�K�έg��(�� �����T��+'7�ً$�bDB��C���u����Y���q7�ɥ c�k�88ز������!����^QD�u��/?�o|7�ؿ����")wG`hR�սH|�"1��w۳��j�'�$A|��䐰H97�'Ʊzu�-,�㰹yJp����SF,�6��9'���iZ���ϲR����/߼���^����^��W2�q��y��i{�x'r\u`���\�ulYDA����p��s�������Ҳi�$3�86e��L&��t��t��)3r��B�V��[�f�����,�����_��d���*��B�y`2tJj���dR	خ�h۷ltb�EQ7�LJ�U��R�6�ʞ�(`�+:%��J�e20d�J��"f�IZ���i�V?�h���ɤXtd�r�7���5gh^�L�yd���'=�2	z��\��o��^	�9x�\��A��/�fhn�#�񆞵=M ���&3��Ux�J��sP�>�Z.�n-������?�\As�#`��?hdN�p���?���l\�J�~��]�<�;}/j��j,x���k�uv�u
d4��>伜�����ڡ�H�B�'nܾ?x��<�Z�uP�Х��S�6a��Z`��d�F�g~����of��������m��o��M�Zʯ���>v���^�q�J��n�⡭��oy��Q�vֹy�e3����K�e�9+7�{��[Q+z��dMǫ�u�/%��i���v��j�͒F�Z�^�m��'9-��͹��3�иP��k�LZ��������{��G3��U��ErZ1�s�؈Gqbn�]עq��#ۋC'⇉�O�J�b.�=��C�����v-�_4�Y���Ri�/^{��UPE�N�8A���3�2���{�.�1����/�O�V85BI��\���ֿ�1��[��أ��{L�Iӌ�ɾm���s�-c��t�����㑘�-X���i�F�m-mws�omB���|9R/��+g�Џ}hT�L�C�R���<kBA��͹K�&Ej���p�/�N�����kk����-���Ln_9�X҉'�φO]LДR��_<�gW�¿���yϱȘ���t��pq�pw�qHߚ�N���̱����gJZ��˞%����NG��;�g7�b����?˹�k�m�6ܱf�HT&�������ͅJu��0cCY[xtn7��D�ٹ/��[:�<x��\<����t���	����uk��3;;�iBR�R-�k��qs�qؗ_�슋�77A�ö�?z/�IBR
ARNvVu�����������}���yjM�&���Z���f:-��M{?|�*%=W�U��J���\���o���]�7�i��I��u[5/�!��˾�N��R�T�#��,Zၨ�?|z��3�Y�S(��q�����ζ~]�	?jӼi�z�����GO���#����lX��9�B<C�I4|Q�'Z˵w�V��w6�6'$l��P��$����w��bq����U�O��Ġ��x��	#�d������'�]K��ԗ6-��NN���I����˥|=v���'>���Ubz?[��
�|N�v���֟�8~��w�M�V��ܝk�eu�[����>||�Ĳ+�&���oQΗe��O㿟��?�����i�|�����@����bφEs�w#��M�kmez��'�ЯO���SY2�r=n5���\�Y�x�-�z��I���O
Ġ��:-3ت#	`�p�Z$b�h����р�8�}��K�T⩞%�LJ��p���.�o@�T+�9���b`�p����o�ީ��IG�T�.ŒX"��s�h�IR�ɒ�W��Ӌ�!
�;���ՂR��kDD"�A&�ߠ_���:�k>}����H�"'��L�%��%�Jhok�Q�Y�:�����Je�z���]gdd$�e�4�&�2WgG�"�h�%�#t��ڬT*Ű"c��tU�U�xF,�u�F�'�LrjzbJ:I�8�9�Y���J��f��Z�,X�eH�)_-��K�Ǉ��<��b�hJ۾�t'�rx���'���~� ]���E�y׾#7�
s��<�˩��)_i��Y���˳]�ܙ�����IJ�Z(�^�Z�n���`�5o���>�ܮ���T��ljf����>9m���>�A�帨�f��	�&���\���*����PP#�%�-@����XF �!��@�U���s�F�PV��;�%�ȻPxA��?7�~��w�b��q������ G�k:�d��׺]�xi� ��@���֊$�[�n���I�
[��Ѐ2	�)u�$�Z������LJI?u��cgkt��^����p�s�Ŀ����"5�B&�B���mgVNn���.��T%�LB>D�LB
3m��?N^�Qk�b�D��1��M+*>��i���p�ԅ������`b��(��O4��0w!A*(����N��`+@)��xps��P&�5cg,���E�LB��D�����
Ż������������'�ۑ��3�}W��R��2	������K������}[hMVo&�Yq�B���m�FuG���:�kY�^0P&!"�99)�"`���E&���}�����I4�8:�JK���T8P&!��$�@ �@��@ �(���e�@ ^�LB ��I�@x�2	�@ /P&!��$�@ �@��@ �(���e�@ ^�LB ��I�@x�2	�@ /P&!��$�@ �@��@ �(���e�@ ^�LB ��I�@x�2	�@ /P&!��$�@ �@��@ �(���e�@ ^�LB�<��𝣌�A���?X��'��
�/�d��AX�����!�A��I�a������srrt:������c�z�d2��oR)0�? ��^)�]D1���#�H$�A�@�P,k�L�J1��DOu�ɧO��?��ٳ�^����BQ��������\��mllZ�h��g�0�����7�HX�3B8k�@,Y�lG��LK��F5/(�C��.*�-�ꋊC������dDD�ҥK?~ܨQ�nݺyzz���K�R�J�JMM;�;w����`�H$�۷�����}㐊��F�����U��VE��g�P�KD:Բn�#��z!E0s�8� ��2�|��}��8�0���<200��G�Phee�1**j͚5�o��mmm�;ֽ{ws�>�`�AX��$��Z���<���"IȒ4J����$��"8B,�8Q�P��29a���I�&Y[[ggg�t:�u�W��A21���P(�-
 �%������o�+�aN�ʤ4��	C>Й(�P�1�jp�޸]��(W�}Q��$1Peer����ƍKII�j���i��)�.]z��M��{��l��܏1�����r
|S_w�8V�.�R�ש0��b�&tB-+VH����u��}-@�z7���e�2	�@8��L.X�য়~JKKhH���+�S&��T�ٳg�$	����^�z��O1�ƃ��r2�_��h���J%S��ʻ4���V��@�dc"�\�K��4�+�4�ُ�2n5�~9�w�0Q���@8��L�'�ׯ_���q'"�9Khda˲������]�"##[N�>��_��� &0�=��5� �h� �h�J'_C����U�ȓ'�q�D�5���B�b�ጴf��D�d$1B�ɀ��e˖���#''��:�t-�	����Ս7Ο?o��]�v���@q��X�p!�`>���hS��0:'�h"�XC0���ԟv�c�*c*�)��JlY��k4!�Q��LN�<�իW���E�~����-
�""""00аð���:��� �a��#i�C$�0IK�%�H�֨�E�����ԟ��cm#�Y�Ay�ьE+K��a1��1 �Ib�*(�͚5kڴ)���L�ɂ�%w.��A&oݺU0�
�8q�M���X���Çʅ`EP��5�/C�o�/.������v��R,�U�o'c�Զ�e}��YRI��~�uOF��,�y��ےP&!���L޻w�K�.>>>��X�`�#��J `>^�tI�V�ЪU��w��ɪ/�D���E	8� �d��2�>��2�A�&D��F�8�����ٿ�~пW�I��%ux�ވ� ��Ǫ�DW� �r��@ �BT5�����ر�D"�i��|���/�333����$��bcc�����p��n��q�.*90�pJS"�,�J�F���B�H��u$�����vt��*�qI�:�e]I������z�@ e�����ݻ���5j����t:�|�:Rǂ�!���<B�E1�f�v����(��i#""�5kf�����Q��#q�%�$��<+�zFa���|��˓�r\����݌N�6�Q�NZ�EQ�bHFn!k2���mQ8	�@�DU��Y�f�Y�H 0�T*�D,Qk�r���wJ���޴Y��QˣV\l��ÇFE���<����b����\�؋(��!�����(�IV*G�tX4�b�P$	�4��|d���u��j���:� H�!1BVo8Z�+Ò7 �@�VR��L�7nǎ���O�س�'qObV��B��+�*+++�{���[�:�V��Hdr�l��;l��,X�t�������d�"����~�J���pD�qA�1C)F(�c�L��u�v��\3����B�#q\�V#�#��DX� �QZ��@��@ e����ȑ#���#���L�6}FRR���ͳ�q���Q�k�)ٲeˣ��JOO��cB`w�%bg�O>���Qt���ݶm������][iV�!����˗qU{�T�&�� B`EuD0�(�Y_�g�������¾--�C��"���7��Ņ@n1紣�m�:	�@J����#���[���?gN�T*E5Z�������W�Y[�۞=�}���efFŰ���iii�.�g�]7~B��~������7��UX��؏-�Y)DB'9C��1#�#�JH!T�B&�Nʜq�^��v+��S��(��%W=>5�Cq)�$�p.���+
e����&�kr���/[�*������͛*,,��3|���i�yGk+˰!(�&$$�~�XhH�����aC��3�F�^�&��;��;f.�,As�����"�:���r�F�
���q��i�E�\�ލO���0����y\IHB!@ww)ŵ���.Z����S��-8	$�"��r~k���`B��}mӻ�ݹ��;�͛y2z���^#������X�&iNe+�m���j�@4ہ,�)X#�[a��o�&-{���<b��Ӧύ�M�jҗ���c�z�ZD<z�)T��#�a��9^>�����ǭ!2�����m���Μ}��ƍ;v���_���|V����='ݍ%G񴂄�GA���"Ψ�$ 
`<�<�Hx������r8!��f
2�V/\����Ő�X3J��B����7��f�"1)E��X�-�[�ɑ#G.^�x�ڿ:wj_�~�2G�ٶ�ZuVm��������*�߼��Qx�V�K�*e4�=���5ukW�%Ҏ��9z�j�ԩs��ټܐ^�Gt�� �2I�/�뇱ݫ����Z&%H�xY�
Z*0�O��R�u|� �Í� I���"KW��FF�")�8�b�`ٕ�,��\t��Dȣ�3�_���v�Q���h�S�ϣ�oʊ��MΙ3g��ɿΙ:f�Xww#�g��oݺ�c�+��h�&�4����0bf<�P���Tb6�!v���Eú�hӦ��3ި�f͚.\��Y�a�!gH��O`��c�}�5�h
'x�Hx����V��Iv����'����Se?��9\���)�Ҁ.�?��1t���Lm���s��5Oַ������7��r{�>=�P*���Тr�R�}wV|���hr�ƍ=z��ضն]��4�s��y;uqFC?�!�[8z �d��cR0ߩ�����SWB�T
�OLK+]�n�Z�F��k�>w�\A7�[��	�#~p@ �e��������'��Q��$�2^*����θ6�VР�E�F�弽#oc�k4D���&�$���<�\H̪>�0|����]�1�c� ���S~?y�h�3N�Y���ց-\l}�V|}��hr����[�V)e���/�z���-�T�ZI��\+a���@���@�z&L����B�Ά��ݺ~m�^ޮ�nݺgΜ)��}��Q� �O�Q��q���n	mf�4��,�I)G�OI�i�}ϣ~<y@������iS�Y���d�L�.m1�'e�La�+f݌���}���W�p�{N�ڳ�){/��f6�L�Y�k��*h�pPH��}�V|��h�ĉ�7�*׬wiע���=pP���S6@>8�� ��� ����Dd�i�TIl^�Nׄ�QoW۰aCXsA7����A=-����#얝�ԀS�	��R xyIb)�)��ؔ������\��83Ia,�Pf
3�gp��M�i,��F�&��0B�`+M���bx�;��k6�y���nG��p()*P8�H�_��.�l�$ȳ��:%��������h�|��ׇ~��9��B��m�@ N^�) �-`� j'�)(&+��J6]�Gl��soʤiӦG�)��}�X��������3�`�q,���CE 
|ED�̻������q���7JH� % EC7;���ށ���,[�zB NZ]� _rҺ����?u�W�H�C)ن���&��q���1>K��� �t	����>�XA߾_(�5�<u�t���	����T�bU�`��f����#�r�rj) ���$��sU����oT[�^��D�V|&x�c�HZ8�p�B=2-E���}xثx}� N�y�� �T���؝�0�҃>%���'6<.���!О� �#�&[ �5xxP�!�B~�����'p����6yz�>��[	����cy�WkdN܏Zr�ԃ(����O�2�u�k+���g������ƿ�m�:���2������J�H�AN>AKv_<��)	8��tNp��Y}�ٯύT�1w�ŋ���,��}#C��g��!����܏0-Y.{��q���u�d�$�c:��K0�+#f�3���(���8��by��lJ�%@"0(�r�T�����塋V�V����:?c��v�*���'?I����u!w@�ѥ���]�w�P�-���·F��'MO8������8a�E5@/�EW�b�&r$�]7ΈR�l�.V�Ӝ���tfS�*��F�ќ�Z�{��9;;t���;��Zi�4���ܤ_A��	q��d`e��x������
���>�����
O.Q��YŠ�L�$F
GC���K`?�RB����qtX~`��[Gv�T5�Y�:�/ƕGIcv��|�1��n�˭��HB��+�|k4ٵG��{�~x�"�z���
e@:�a������猴��-�cʢY��� L�����>y�Z���={�V�ZݾoT'��H`ȟ�f87�sJ4Y�"�dc�q@B�I��<��<��H�Z��Mԍ�>3�	����L	J�A��Y�	�ǵ0�{���q<�Cí���ad����V�p���@�\��'4b���Jqx�3�M�su��@m�[���M�:�t;��"�MѤ^��L��}���0����f�S*�2(g.p<����pZJ�I;��k��g�4B��}��7��v�cǎ�?~A7�[ �IE�3���L��'�RA�8R��=�	3ULL�� �����A���:�U�(�fLऐ_����,3�L'�Ň���Ud�4G�ڊ�*��ml�r�����4�סfN���3��h�΄��.�:� ���qϒ�.��G��W�hA�Ê��7E�QQQE��x��l_ip�4�R,����q�t��#��`��)p��I
k���h4��`����q��ȵ�ڴ}�r//��NZi��e�B�ݸ�&$�n�g{Ogbcq_/��'�3F#�&��r	f�vyv+X.[W<��`zP��!5#I
`��0ӌߩ��y{����<�'��j���62լ��%nvʈ�})����OZ/�pzr�z%�����Lu��>~N:H��U��kA7Ŋ�7E����СC-�;��qH���C[=�
K���pz��s�����Q�)Ǥ�u�6��j�GgC��rIvfF���5����X�����ʯ<�A�XcJ y�~�B�i�쀕+�G�3S(Z�O�	)M�D2�������o�	p�zd��PS$xH��M�^�7nK�ꋓ4o�o��`ͺlh����7�\�c�".9�Yzӂc�'��"��==��eš��*ܔ���nX���bEA⛢�ʕ+_�~��y��QS���K���b_w�� ��(�'p`ξ@�v�T"-LH�1=!+9��˻E�nG��������ѣGJ�5xǧA܋P�pF�=y��;�HL坤Xq7Plt 1�" �r� #�d�i��'�߾A���XBB`$�a�)�,��z#Y�.>r&��r�ocmHx���L�\wv�<X�͖�<	�ԕ=��.��XQ`�vh�޽{���/�vm[߶C#8��m���E9@8A������|0�i����F������g��k�o6z�;e޼y�ƍ+�~e@��<`E�<��8�Y</�	���cS)�Fr�2|��G��Ɲ�J�TIt8�� �P�p<ϓ$ɚGb�<��C��L��M�f닎[Y�����^y�<Kg*;kM̳?��)=�R�;�ŷC�={�ܰa�峔��]>\M���h	�K�����'� �\)yo̮:]���$2'��yx����4�6��	�e����_�(�̙35j�(��~M�8�p��x7ﻀ��NR ����k��T�\I�"h� G�#��՛��k8�9\��A��<��(��Y�sPP����jV�ì��V�?n<������{U.�u�~Br�����R��(u`X;���x����j׮��V��G���X��D��o���jި�(�e14t���"E�4�������!�T�����	���1+ Xf3=�a���#�!c�vT^.ƻQ4E����X	�	�t���ER��JeD���H�hO�D6@�UP҉���Y�C&�*�u�����\~��ލ+���4o5�E'U��I��G����]��nP�C�1B����xi-��K����t�#����M6l��ԩS9_�0�,���e�PX�g1��� K��\�O 8��ZuVZaw�u�9f��?���ѦM�Z�~���n����_��=�<�i
��G(��+��Ǚ<��r
	##����	����OR/Λ$��NHq4K �W�J����o@��Bp�nX�tE+�%M]?!�ɼ��Nvy�a̶���8l�f�*���s�`0��F�``��NǨ������:�� ˍ��Ę�l�X�gYH��\�$q���BN�)�J������F��8�+�l�2�o�&Ǎ��/��.9qdo��~�T�X�B��_�s}��#t�lȔPe�y�z�F)�io�ٵkW�B���9y��n��^�4���2(�Ƙ�?�%,��R���f��1�A {&\b�Y��(q�L�Nٓ�_$�cX0�)���� $i��f�z��i�\��|u�;l�Eg��p�޳��7֫pzlǼ�`f���6�}]����I=�՗z����j�13K��5�E.4�8D�&�a�v��CM���<��p��1�,���,�1�����y�!)LBr!WH�\l}��v-VԭpaG�����Ƀ�5�h4���YJ����^LOϐɕI���kM~�>�D�$.�4�,��q���si˖�y�n޼yѢE�Ǐo׮]A���%d+�>	�
�O]e��Q0�&���r�h\�9ycxB R�K��;D�`d��K���0!@��p�-R4�3&�P�:5g�*��-3+MZ�!�X}d��+c;7�ߡv�j��8��ܭ��0�K�)��t��h=��Ƞj�љ�Zc��`2��C
������f���X��5�93+��h�U�J��P�O��b���",�R��H�f�� Gi���?t&��̚I��)TԫP��E����q����(���'O�t��i���&MJMM�v��~���QQ1�\*���4ɿS��h��jЂ� �T���gu�;tr�ƍ;v�8k֬3g�x{{��,��pn��n��p0$���d4����m�+���@�@ʓ)������x��I�h�B��y����)�hx�����b(|o�i��!U�m�hW��#c;6�c`�^���?z�����ٽ�_w"�?M&���df`75�8����������,�Έ��%
{3��,�=q˟�~���E:E�AH���l����fe�թY��2�\F���T�R�V��K���)��b�T��͛74hжm�:�S~`2�32�(�TL��s]��6�B��yT*-#��{�MZ�ݼ��__�dITT������¬�#�A@[�f�P��"u�&cq�%G̉	��vK���BOp}쟜���K��$Z� � �RI���#�<��J|�i��p�+
��Lg��)���q�ΰU{֏hߣz���<#�o��F��wӑ�*t����uLz�Vo�T ����6=�ɈM�&�����B���Hԫ>�o	�?"Pw�D�'0¢��,��fge$�%E��&fe��,��lX�x��U5�V�ű`����Q�������6�SX������)��H��\�)���\�/�%p��_�^
�Pح���;G���_

�2eʜ9sjԨ����0
H=�?Ŝ�<�`p���$���~·���c���h��ahɔ�% �n��N�U��Wmo P�9��P�X�j��q��=�'��e��źDj��
YiҊ����q����pT幒V�>�\�"7��(�}<��ǲ\r�6%MmҳRj�B��}����m2Y��%4�vI�q�����k�!r���0�?/$(�3fcfZBBtDRb�:#���nM�h٢^�*�
J�_+M�߿���#G�:t�G�r�G�1bؐ��d�hI8����er9�$Rh���Ѿ���1��$1�DV�J5�VĔ�$E=�?�0}�������ݻ�ER`@}�Σ�$h@�y���/�U�B�h��c�hI#Q�d^��޶���3�E(o��"m���^�� ��Y��H�Id��L[QmL̕e	k�H+�	��1+Z�7���Գ�����$T���
t�>
z����	�E�z#�,^�4N��F��)
'	�.㣗�`�3�y;{;���%�"�^K�8���<"��i�IP$�2���踨�Q�o�3RT�������۱v��2��{����Ɉ���ݻ���O;w�ܵkWN������)�2�H��w˳ȕ]"�iZ*���B��-�l�L&3��d�z:h�=�#��{xx̚9{���𫽃��3׬\y7���777xO�<ٸq�ݻw}||
Z0j�(�H���T(	��cٽ�A�nG ��8[ap���T(���^��ߘ�K3,@Q�yJ@���)������G��[��ce��N|��[�����80�s˲�>��U���vxT�F��hQ��� �:��{	�)j8ʓ��i|���6p� !	���0����l�yp�`%��כ-��󜽽ݭH��6���>�5�T29���N���Q��Ͽذ�=�um����$�J�lӦM�ҥmmm!KU�^#4,�h0���u�3wN\l<|�k�#��Fe��d����TO�k�ʋ �Գk4��Y�0)�ZO�8. �\���nڬ�E���w�6s�9s��-�t�СR�J�V(,h� �A��čBj�$f��8��L>>��А�BO�h	��)�H�@/`]>�5;5A����	9��i�<�(�ll��-�	��J���9dC+��$�4i��bؖ���Y0����gV���큫�lea�z���۰l�L��'���!��$�n�I�d�X�p�C��y5�`X^*��o �Q�J��Cz�i=c��[J�m��.�*$�=�yy쳻<�5hPo��n͚���H������C�K�.3gΔ�%Jnݺ�r���c���j�򟣃����R���+����d`Y{EF̈Ŕ\fFFll,�D%�e�^���>g�ϫV��\U�T����6��G���K߾}	�X�t�u�Z�jU��)���Eۆ�	1AoL�8�?t�$(�i�xp�2�71��i�6��쟮�ƯS�hop4Ba"S8��	��	$�,�;
~^�#�B� �bPE�>2��gk>I+>�7Z�3")����4���+��\r���Q�ZU��{��n�;�4*-��S��,��T5��כ8��)�mE47t:S`?/彶m_sBݻ{s�6(�^�\���o���c$%�A85)�F��w�KhY���&��W����WF����-[��ܹshh�ƍ�Ϙ�x��tx�V�Z�7o~��)I�%K�R)f��X��h���D �v#q��(�%6::.!��$�p��2q�F͚Qa��ҵ�����K[�6k�,  ����!!!w��qvv.h!��'}
X��Z�/m�v턕\�v}qX���	�F��(�2�V�6�����d��^`��ϛp a9P'�(�9��{�Wm}��[�Y�P����;��h�����4�� �o�ӷ��C��D��W�ٶ���
Z��̅G��'���bӌ#G�8���j��}���K�&M����ڵ�-'u�������L%��%2�������䖳k��S���ߔ��F��&M����;wn���~~�W�Za9���U�W��dB�3�͟��`1��i:!!���g4-�����5j��ܛ�k�o�4a\bb�����*�{�����o�����@����<r�`�Rj��ĥB��;x�"SB��0�^�V��%�ެ�Gw0NʊӘB*��ɠ��Y���t��b�3�I�f9�`@4�)�f[� Cg(=e]Q'����Qn+���&�ht�ǭV�e�Ԯ�/�t�,�� .A����FO�T���X\L���dndk���T�;��ᣯRڪdgBn/���FA���q�v����k Y
1pP���٨>wE�}��hj�}���ڵ�C���6w���3��Fx�����wjt�R�JB=C�x��O뵷).2�4>>1**���P<R�L��4n؀�_�Z6�ߠq�f?�e�ڤI����S�N=|�~.hQ�_�����1���|f�i�V
8/��	d���wL0 ����J�;-��`c <$?Hȴ��1;)��gd�~�Fw��9�m)�GZ�ъ� ]k(5i���ݥI]s
��\�%k��nW��>u�|��CWlm���稒t��۱���c9Hd�/�{,�?f����#z
�����Z��������j���m:9{�'�+��T�/w�sA�J�CR\䑝?'��/[����+K��7��5�dӦM]]].\ؾC'[�5�VZ���z�(D�2��O�'�
$iLLlBR���9�uw/��ܟ�oX�s�����Νs��-��p��u�ԁ/�ٳg�7o�bŊ���hc(��q!��<�p��X�G�6��؀'��%��M�o��Y%�ܲp2,��,�KI�Sj=�Q?�������B����V��S�idyo��-8���jߎ��W��Էv�<�����֐�9�{����䡆|���;r���H��d1�Ȣ�q� H�Y���$	�?����"@�4�����;ǩTʮMd�+�0�_��ѽ}�>���}��A��PP%<��O�^	�rz#�9�c��}��k9��+mIJzp˴7���ڷG�Z5�]�_M^�|�W�^�ڵ�q��ɓ'׮�0u�丸�𐻇��=��r��{a��(�� ��R�q�>��w��aJ�2>!�]���K�4xp1_�ѣF��4MC
G��t����@./h����<��M}|�-gp��#��p��
�uB�9Hr�:o�\]�z�"����+�c��2%�3�ЎbY$~�	�i�I+�3�֚�5.S5?	�Lx.>y^s���@�^W'w�۫�o��Շ.�q���FQ`v�'.��=x�"���@B����#X�')|X��$���6�gK����57��E>�SH	���Da01��q�úvm/pؐ!3�����M ���XL�����Ϣm���0�>�ʫ�-w�5���Yw##"�d2\.�rSdn����g�y���";v�]�V>��jh�M�6P"����֭�Z�z��'�c94y��]�)�r	E�<�/9��X$4����FS�����=��˨x�
��ؽ�u�f��k�J� 5�$	)|ҤI���!b�9,e���>��B�bɉi� ""�xN𧴩��m����
�7�(d�<*Q�W�'y����Pm�DT.%�����j�c���>��� o'dq3��ӿ���`��ݫ�Ψ����7�u�}�]ݣej�|=uoס�$&'�
����:�NgnX���닗��^"��k#I�v�+Wh�]�bU��x��I���<-KߥM���������c��\�푑ޫ�;�lTժVj׾��[Ц}��6
i��ظ~)!���acU*����֦F���Z����dB�X{[in���9��lܮ�Zw��"���Bș���磜���zd�ƍ���v���׊�;�l>w�<}��Y���x�S~��	(K3����Đ"M*mlEFt��)Gt���_�j��È8}||���x��������۷e��߱�7�b��/̆1������X��hV!�3F
�<��PDB���<�A%.���06��,��ĸ�Py��)R�m�}B�H'��>b%Iɺ5iEޱ�Bx��w�߹m����[.�yZ'�ؽ�'�����y[ҟ���'���_�������I���}�p9z��ӄ W9���!�
A��6�WԀ�/]��_iP�ڌ�s�D;]�����UgM����O��Q������'Z����?�-�a��M[�|R%���Z��N��عG;Yn��z�����/�Z�Q�h��P;���:�_M:��ٳPc{���È��;��m��V�hòْ%��5��fs>�(��f����E�[8r��wt�_�nBB���3fC�q���3T%M"n޼y�ʕ*U
p��_/f 81b�9�쁫�\�� Ga��g�hU�q��B�����ު��F�u%!��8�V�G�%�l���J��'LTO	K�'�����Ί����L��+�/�g���N]��|d�g	ٿl9spZ����{g03�8|�1��������f��T	���z��l�i䔽�YF�B��T��X�D�stܔ��[6��8�SK!���<}��0a��ͫ�ƥ|j%ujU^���i�N8=�g��m�>z���ت���9n'<J���>����ml\n�v/�`�n��޴1����dbbbٲe���mllBB.+�߯_�~xa��n��ʕ��FWW��>eN���=�9����'�|��"S��X�~��=���оe�&�T*-S��i������t�҂�ܿ�p��<yJ�&�4������I�64ǡ=I�c� �H��Kx2�Jds[���ӂ]m8�y$�1�@r<� ���e�'�b��'�/rpY�ъ|C���v\~pcz�@O'�1�S���Իf)W�Q�����/�3����7�l��������,Vx�w�{���B��B ��u��ǅ�\l�Uo�
|,�SI�f�5��7�y�������󊻽[ȫV����޽sKS.�v̸��˗��Ly�����ܥ����*e���
�))J"Sح��63-f��:4_����U�F�U�^=���<y~���;mL.�v��!��H����˲�B����-@m�ĚS��	��;8���u����-[M�<�j�� ���J��7@Q��Ǐ����NYВ�w��O1�G�<P�b��w=������n��Y�T@� ��g+�l�EO4�����s�q���Y3�,��{��a�XKN;+MZ����4~u`��m�v]uH�κ>kh�bN����Z�oA�֣�|nn�[���B�>n���ܰ¢Nu]���g.>Y��	�\Q����Ao0��z�(�}��s�7kڤ}�v���������7�;�v%�W�p(�ɘx�K��˿��u�fM��+yF�ڛa�����F�'���d�񳑭k���k���6lعS���gy6=5����B޾����*�?��K�\��8N��O����Go�**:�������d�<x�0��ӧ�l��p�Bx�y��+�/��{����s!�~���C����/�k��i33�H��H��(�I�V�u��۴�y�/���4Z-��bŊY*fd������V(G��XpRB������@FbLsm+)'H ��W�i�eaA��_��R2#GB*���#mB	CΠ��Gɨv(��j�BX�I+�3�L�t
���ȨTQ��sT�ay�ٛo<���m`�|��89}�O�y-�w��5�=�p�>|����	E|��*9�r�X�֚�-��d��r�_�~#"�#=5�D�&���bE�����5��J���b���C/����W�]{�⑚�!Vb�����W|��.��ޞ��S~*YcpB��I�=fܔ�r��N�8�ƔMH�"H=�p�<��"���.����kS��[��j�+*��(;���<���믿�3��e���dJJJ`` �!M^�|���C���]�j<:g���ڧe��!���������h����
H�Tg1&S�j'nn}<r�8�:`�q���+������D���:�.555,,,88�����y�5	�e
��1�7ᜄ�3����I�<����3��A��v��� 
XGq( :	�ɨ�mV�i�@���Gp�uY�v����!wg��9mk�)_�R��7֜�=�<&�b���|g���̌�[�nZ!��i����	C�m���-���1�$�Fc�֮��߇n�~ ��$����=�q� ��?d��j��ȁ���l��ܕT�R�򕫕*U�q�FN������&,�����:��r�����O�]öm��dV��aɏ6��)�Q)n߾5]�Ѡ%D{]A\(������^?�x��Y��	
,�~g��m��0����La���h��}|��=��з���+W�U�UI�\i�!��<|�_�~x�^_ߢZ�j!J�J*�A��[}��	��H�=S��rrrZ�v���s��+V�{�P�<��innn�סZi6����6m�ԭ[���_�C�,@��67eG�의J�KC
!X���<g#pk��������k��@z���c���9��R��&���D�#.`�� ����o�WLgb(�_��y���h��A����Ǎ���$9���cnG�j\im�f�U���7l������䄶�>l�+�¨�U�4)��YLN�����C�g/��h'y��F3�Qص~PF�ZMs�R�\��ǏW�P!666��|��;ݞ��!{�r'�O��ܶE��G�۰-�LL�����׿w��7����p=y�ނ���\�*���\��[�RYM�b�T�b[��Y�����4�|�*�M�I�?�|�Z�>S�_:M.]�tȐ!�b�V��۷o�\8vs��ю�׮\`�P�3�[���F%��=�9����z��@�J=�"�K���7o����;~LtL�v� ��!mmm!MB�U�����;vlA�/�!X�U��$R��ߒ0��R��\;x3��iHq�7IrS �u��E%˳8�
b&�qb�I��olG�CQ��q�m��������#��oP<�]{!|�S-����1���6*:�X@	����Z�;�#�T6��w��e�ń�4m\k�f->��(�͵f3��S��wl��mr��fѢEU�TC��@�����hǁ�6��N���I#��P�ڍ;9���7B�L����N��+��F�M�N���ύ����F��˽�[��m��]^&�㮛�V�V)��~'�*;��K�O��m��iӦM�L��4٥K��[��(Qq�޽�;��+Z6���W��Neg�V�8�\I��!��� ��x���u�:�B�An	��`ϡ����8���a��^E�H
�MdD�4����S����ׅ3L�g�&8IIZ!z�Q>�@�@��H���4ŵsD�mٞ��٘�4��7=-�ƹk}��#���P���n��yd��۬�oYo�<W���x7.%9K�6�������w�ѩ�o�|�VB�Z�{�j3����d�1��L��w�`��&�^��Az6�8o����� ��jR"�M�27��}���رc�F�)v�6,��j�ߋ�����c�����Y�b|�+����~{���k�ݦ�i�7�]��ɣ�5�y�M;���ht�jKҺӽ��]޴q��sv��z��=�-!�Q�D��X�k��k�g�����N�M�6=v옯���&��?i��I��W�X��RG�Og�A�O*�#K̼� /�,ō|�(V/,z �x��]��ߖ$���v.ԱS�v�ۜ>{n��aO�E#K�y��2u��3f���HU�t��7e��Vl���񩻮f��ar���'ʯyaҥY5�y%XmF�l!(b�و+h��?K�� �"L+OZ�@gbvܼ_�ӷ���S�MRk�މ��_~�����X��MJGۚ~��6sV�?���Ť�F�����c��J���mhްb���c~���|��0�Mo�{�^֗�i��W�E3;��{4��.T�T����]x�ܹca���d�~Q�����ڶ�#�Z�R�3�5�?f��[�SY�����КU�H�&�/ܶQ�F����v�����h����S'��6�ęp��i�$%P�Y2�A�
eC.^�H$�3��dժU�^���A
�Z�]�x�k�.�_�v��gO���������ƣ��Q�K'`,kU9�@��l._�ѽϏ�F�R��	���O��{׷�����Z�j5e��e+���5gΜ�'��6�h�4��4	��:s�'�f��dҙ�,=��$.�,��;D�hcp[����5CI)Q��Rd�;M�Pxfw �_Z�X���h枥fw���4��}řb����d�v�
���E
�����-VX�R~���	�>~�����W1�1}�&a�J�ЏXs��[���)�(�왣G�+�ӳ�\��9����?��U50953wU����?�ҒS"��!��/��LB�9.�P�X��Cu�u���/�=s��oo�U���<��#G��>q��K��a�B"腙#�թV*�yb��O�8z��S|B��=1�P|2�l��FE�ݾ}W��,Ϝ/�&˔)���G�x ��Դ����(�������ӫ�H��H��	�i�'I��`��<�b�EH=u�.ںu[�b4HKK��dp�����z��G����?s�ة3g��E�U�V��۷����56r�����Qm�cܻ�kk��g88��Kr�[���7j23u5�o�T1i�t�G!Z�z�fA>;& �pZ@J�uoҊ�c���mgPJ��h<�n��'n�ǌ����ӳXq��a���{��٫t���<~�<��F)�z�ϭј`����Z���i��]p�ݭ�zm�_��?2"���}9�ի/]{`��������5�-�\?�����a�-7b���*޾i�����(�KWCW�J8�$����DSt}��~�q���r����|�L�ܿn����k�4y������d����uV��
���Ӳ��ԫS����Y�l5�2&}N�Њ mLxaZ����+�E*��� X�����ӫ\�Ie�6�ݲ����I���I*�*��}��]�~������s?y
%,�x�b���Z~� 1� r��Q.@�\����Go�<���I8;�X�़"�H�!�K�N�Wo`�6F�����d9�3G�)|w���U�Ek��Gf�V����F��TjƲ�X���á��x�}��}x�4p�_r��%��4	��8)���C�JA�ˋ��u���?�ȥh�g�b�y�fA��4l��r�?{���;Z"��v�Ҧ��U+6�u�W�܈F���<s|���/��̹�}�;�֬����)�+���	�^�S�@���e2�wM�:�Ϛ7k����g��q���u0��^�>�,�©������x�2�?G�_:M�٥w�u/9�x���{��ޛ�]:uX��ϸ�82[��yML�w�v�_6�m烋n/75_'PΒۛw7̊(]�����}�y��:%��lڴ��&�د���ryDD�œ�k��&�e+ڶ<�cg!��/y�뮃��|  *�$GH �Fyiq��;CS�����%�0�s��?�/��b��,YVm2O�}��������w�:%<��	%�"��F'�9��N��Z��=M���C��|�F`�@\���+0���oO��16kLK��wGMж�"��I�&&�;��r����ؤ&w�$�P�6#�o^�A��)���n��<�\ŏ1�1�/o��"�͚��]ޥS�Em?y)^*%bT!'\Iivo_3}�<�uw��}�>ۼqC�^=s���y�C�.W�=P�t�B5�Ĩ^����OIy�f+�Q����A�0H��u#�ڵ�?wiہ���S8��+�쳧�9��� �l�}�.N[rY�������	�,;+i���m۶ٹs�gf��riݖ&1s�X!��"�D��䀰���Ѭ�Oz�����j�2�Z�����Ԅ�����7~�K�P:r{��i��y�<L�e.�S�՜+%)I�Z�644 �*��������5�\�p��E�?��?!�}�6+*���P̚K�f�XVE�X�}�U��x2}��8�kG3�+�=M�F�I8ģf	Gb�C���{�A��z�hx��aʒ߳���������O\��_����vh���	�1q���ן<z��"ƞ4U���ʞ��<]��&��5��=��eF��3~̫ �Fʩ�S��P[�)�Mc�aó�\�cV�	���̀S4چ��\����I
Wr�	挈�-E�@\��{m�v�>�E1�?�<y!��y�r]ѭy��"�(�^?��(.�b5�T��Gg0׮��`��I?�.��,ҢES�2��3�cc�B.]W�uo�`���=x���|`���ZG�(�䱃'oۦedQċ�Tdre���*V�d0�JDQ�L�?������O�8$w�P�A��m6cbb�_���޸	M\�v��5 ��F��7�B�]n���̡%�b#���$ϱi[�Si�m��x[����]�q.3�'��x<eϓzuk/[�wQ��qP��	�7$��&J*`�0G����O��l�3�_٘A��řL(�都�c�x_��ܱd�:#�
��&�~�\L�l1qԉi��Q2���A�i�=.��lY ���H�*Ϲ��յ�����r�qN�ie�Kn�
�`Q� 8�b�:+M~*�zc��M�b�[
r|�yd�R%��ʄ��S���gnF�]��ha��7�|�\C��`'����� �d/s�u`���@`]��s�8������/O`R"QU�˪�7`����ؑ&����/&d�^�U����%�c臤>5�;�|��^�h��Y|"�IS{��6u&���_�s��Uk��,\ȣ(Ú�y�"[c�ݵ΂i��X�WBNވv��]������;9�ݼ9g�gs:/T^}���p�hݦk�JZ�h0`�&�1���E-��m�ر}c6^����b���-
�Ӧ?z'>�R���fi�ri2��/�[[]�Y<x$p&�	�� |9w��yv�#�韛�-�?w��A���^�%_�k�U�Q���;���]|mA�.Wc�U��#��0ɿ\���թ�뚡r����6�3�v-�J���

b�xq��g��q+,���ls�ɛ��"�p��?. ��D2e��xo�T�c�7@�(U�YgPQ�<8�.��|�<`QFJ �&<y��;�[-܍��":��ČG�Lc�6�c�J%>����t�uP�_\�<�D~��ÿo����9@o�&6ic^��h������c�R��%ȩ�%�Bz�����]���	H��*�`�jQ��_�����L�.����&����dF ��� ����sn�S�,Y��ٰ�g��3�}_}e���"��G�;��oggS�J�5���x��g��۪Q���g��CŋټuWD��Ɲ�N�ҡU��ǯ��T�Zaņ��,�`�|��#3�Ъq����g�Y����C���;���0�_��[�?�NJ�Y�bE�����;�N�~=x�S(�G�޶��%�>��|��4�{p:s�W-�Q	�tɖ%?4J�^q}��ť��L>�6�1�^��W�p�Uff��(��s!Jn�O�l�ʷ�\%M��?v����w���ǲ1�;:ds>3�`�|�Y�K��,����h[#�i�4=��s,�I��/�����7��I̝��85����Ե���e�ƺ�m��L^��<˘�/�a�k��(
�
�␀?�S֊w`Ǎ��K���9���.Q�1����Y}�Ҿ!:L=U�l��0�| �{9�<K�DL��������^�_jBօ	��y�\|x@:����v�H_��
<N�Ю����3��ش'�� �sH$��]�E[�s��<P:T�Ĥ��\_,����"��5�ٶ

�M�un&om�J�Zz��o�/Mh[��6u�En�\r����J���M&��|瑵�@��S�rp�[��� '���l۱��3�7�<vuu��XU��kTƎԬ��5�Bm_��T���ާւ����?����+��&ͫ˂�����?��Ѧ���N8r!�jh������HK~f[G�-��~rc���Ç�|�q4ɛ4�a�5�69(����hD��Ytk�,�Vu�p������"���n-W�/�yA���e�R88�l���l��^�����}��x�ʴ�J�a�t��6x�C-AMp<ŧ<�Mg+���,��A|אY7�B$ ɣ��`d3�8�@�h���>ݐ�~w���KQzڰ�8�T���Ԡ����	x	&�ZF�*)1��W��Pe�9% �:J~6v�F��S􄃜`0����ڳ��W 	X�9ؽY�K����ftR�i� I01�*kT�{���@!W��~ͺW�Wh�;i;뙢�b(>T�$NC$�y	�jN������2��M��6U�)T�e'Ҝt-}_6;�D:�������4iAH�����)�?�m���ɳa��S(��7a3��}��ȸ���ո�kV3.��%��p�j*'Z� �HJ�.U�A=߀j��c�B"�F��>>�[V5t�����*�f�ϲ�C�>�	S�$#�<}X�y3��{���М�%2��?�8p��]2�F��|.�qvr*��'ҹ'E$���ϯy��E�U�N�>}�1�Tr�Ñ�N�r�{v{�򁶶����vvv�/�/�&-aBMO��"N��^%��v�����	$J��Q7F�t�� �R{�� �f49֝{�zt���\�~��v��%���}f�()�N�vs)"#} \���U
NN�;t���D��v̀
����A��l���@(	��Mr�D�@Uw��{A��؊�� mI
�LA'��:����Ӹl>�ə4�3�J"��.�^����I�K�I��URfI/�������F�"�V��|���Ӥ޸�o3O{U��;�^��3jQ�������+m9s�%�ʣy}��8t�~ UX��=��H�V���*T� M�R�k�HBᖇz1'3�6�pN�*��k龍䣲be�Asg!A{��[�n(i��$@٬�;�v)4�E��ݼ߶o�z�X�~�M� �#����������.�q��c��Z�1�%���<!�IT��GIF��VE�9wy��hո���c΀
绱q)���!�W���7�:U��)U�"�W�/&�݉�ֱ��m���)��8��D�V�)�`����'�k<J�x����c���<GK�E/��Z�M[�~}�=>_��K�I4�3�3��bztF"*BJ�1���-��N�-�h�f��P�/!|Ϊv^����+�c��C;�ԭ��G�gܖ �M|���c�y�/�01�k�VdRtN�Y�k Q��;@}P4�a�3،� �~�0:?����'"X�[Y������ �������3)�	-�H�"UA�E�(�Z�-꯫k[��u�u])�����(*�K	�	��>����7�IGZ@���r_��=��hI�|Rف<M��-�����vkeż���J�����}NWLpы����S;O
\��^x}tI��������-L16GZ4&���� �4yv�I���w������yZAi%�yU�u8��6!-�����^��Ǣ�� jj����cŖW�lֺ�����B��gQ2���h�Ⱈ�lgn�gon)�W�g���xC���R��0M:����]g�C<�c��k�T�LN�p��4mF�����>�������~�&�����9(��	g���*�]������7,%-=�0��\R�	=xW��s_~￳#_:�浛�^��%p��d�P��?V��Z�����b\h����"������G�ib��
��O���c�EE%�c7m�����kZ�ej��琘���1M�h�r�I�j�_f���{�͛w���8�f�I5�)��)�|O|ω�-�6Á���#1;�i~`�.��V��	�^ܸ7�٠�n۾em��Ā��e�0�eU�b��`׿��>$@��eЫ��{��	�c�L��C�5ɣ0���΄�f�R�K�y�Q�G�%�Xx ϕ��;S�O�"�,*����۲�Ve�}{d�p������4&Ci�H* ��#;�o�ЫM\�d�f���6TB�,��i��\)�x�շ�o�g[�&��cȔۇ��xë�+�i$��[�y�Um��Y�f��3pЋ/��=#^�e��_��˵Ⱦ�C�7M�j��C���Hu��th���V�<c9�bBJ�}d�c�{���? �m5h��H�p�w�����M��Ĥ�8���udM��g��d��q;�y�Iv��b�a͆�zv�&��K�^����t_@{�~����[�re���Z���	q���4x��K+B/L��[���:��sF��ov�k�z��;K���&�Y�ढ़�HOo�w�>����s���4Y��[ʞ���0@��)���U 9�q��qE���p8&z�#>v�O%��Ȍ�f���7�[��>M����t֕��}Zb�T&�;TU�$@�tA2�&�q+���<�2�M)��Y���k��g؊� bIt�1���u8�uJlJ�1��@�(�p:�^��|;7{�w�}��v����IK0���s�3z�v$:9��q�\Hzq�3��S�5�1)]�gtu����ԯ�ir̐)c��{ӟ�P
) Zo���v�2�ތ�S����R�)��-��o=�2��ܗ�|��^�?c��?�&�Ъ�^��o��}��~����o��`C>~�CC{��s�d���A�Ի���>�<�Y�l[���9����|��P��k�Ȅ��P��b�6�w��ճKt����c�?����k������&��#cZ^ٯGt��Iǎ{������g�K���l�I���n_7/��ްqcFF�9<����;��3���N�ݵ(�+��S7�S�J���X�{�<^畯n:XTC��)/�寏V����t�u&{��`�}��Ƹ2��9bG� ���S�� � ���eK�*j�E�����W'?��%�bD֤��>FV|e����[����9�%�0"3m�����a1�[y�`���˖N1i�.�1~��k[������p<-߁h����O�%,vӢ7�k�n0an@ir�0����Z�� 0�h�w՛��������8� $��4�%�Q��Fhr埬ٍh����핉�E�kv?:}Y�&���� �IԺ�3J�<�Zp��Ǚ���$S�!�`5�%]gx��Zyw7��͚�Y������zw��1��LLi�{�>+)jZ�{p���������si�\�)�i?�����$'�����y����ߛ:%%��v;�g���Cyu��jw��_���u��\�ŋ�>|��m�!43Mjr�x��q��I@�$�"!t�H~t�ڪz�)��(�I���Ŷrwը����m3woV�ea+���\��U�sG��KOe�mQ���&H<I�H!5r&�Rra!C�,�j�R�*��R�Փ��<��cWu�]�� 	HEe"���4lm���Uyd	L���?��������!�Gϴ��-���\�'��̩�;2&�1��5��aUϱ�I@�HD.mꬫ��7#��7��Mn>~j�k��mJy�e�7�m\�u���@�PX,�ny����-���I��5���7�"Ƅ��.���I�g%p�4�ewۺ���v���[�I��sW��?hS��]>�m��(*���Çt?�{Ƌ/��𪕋7J.,*��D����t`*V����D���%�>z�f=�F�- �U��O"�Ğ�Ą���W�s/:��֤��| Ʊ������� H��Z %�ݛ��S��:6.5"������q�h'�$>7���)��p��vFQ�3�ID��Ċo[N.w�n	,ɀURdq7���0YBj����cg,�I��VY�p��&������9�' cRSQ��3�I��jCMC�&:bd"���]7b�֭�?��ީ�� ����9�1��8R��������`�Mr�p�Ib4�ɪ�1Y��͓�"V�a��vʆh������E��Sͬ��#���^w������O�3 (�6�ˢ'n%?5J�+>Y����$�X�ٻ}���DWB:�)�j�X�+O�	 3�����Q��7N��6�z����-R���;�b���/}��g��ṟ-q`]YUUSRV|��YG8 _�Xs�O���~��=�Ѭ��|!�l6a��u-*dt9+{��F$k2;�	G��-���P����{����$���4	�]4�!;��3	�|�D�� ��FhŨ�/�c�k�g�x���I�{<��W6*4�hS��kS+�7��#�p��������$0���	�?���Jf%�b �h�a�v��#����[�q6Q��Aܡ�� 렏X����!E)�<���ʺj�U%e�K�X|�M�`��H�ϕ�8�l�dO�հ؝����ݭhH�+QJh�*� �4^�m	�X|b��G�`)�c�,��2�����4B�?d����O���0��9�FU�����,�~7�5C��꒧�a�5B����f�=�&�`H�<*���i������i��=)�R<��Q#r��'ܹ��r Cic����_�03�+6�g���娡m:��!�D2���d�N���sڛQ>W���������
n��"�-�&3�a�E���6&6Yմ���c�|��ĉ�~�m��頭3Cs[� �.z�+�&.CA�EI�X�4@C����W<$�;D��L["���S��s��ڑ_��j��wF��z*�dЄ��p?�Kn�v+���v$1(y�0%��!YJ'��	�U�%�^�4*]���L����ߍk�&#��
Vͩ>=X��;�<���i)i�7�ܢE��k�]x��=��`sĤ'����E]�Y�
���� #��Xdj�(I ����� �@H����5I���LD�N^ ��	o���������:4�Fh��+��<�L<��L|�+�g�0hc��c7��  xK�gM��z��#+6B��N�泵{���;�<Mh����	d~�b1;-�'�]?��d~�~5��U�������d�q��^TV�8�T�f�)�q���.�"�nX,���E�-9�QSU��-V'Ú��X�v崀��펟2升z�A��d���J�{�~&��I�0e�� �/�U\�C��U%��a�GLB�%�^��x��Eܩ>O���da��Rpfw�Y��`���&��r"c�aS��	wʇcyxh�QE��8���4L�p�kU�J�x����w��*t��7�z>�@3�FPτI�>�5o�Ļg���,�L:اyE9(:�cY�h5U���h����Z�A7H��%�q� �i#Z�,�K�$�uE�c!B~dm; ��IȒEL��4r���yZ���&?ݔ5��/*'� Y~�w޽w���w��u�؞�>}l�����/Z�H4gG��~�����]�p���q��tPk�::����dd����ض=뭩���=�hZ�N=�t��p�+���2��`.���iZ�ߟ�h��+"�fk���k���r�b�����|��-�D����iһsyh�K	�+��	��}į(i�	\]k�d𢊧�4�/��_�P�%Uy瀉�a�j���
�/o.��ƧyW�
f�N�jG;�� �y<-jX���*ݏ8�0��"�{1��θ<v�k��C����=�W"/�ԍ7��ܷ�����&�I�e�x��Ǳ��K�
d��J
�s&�EEH����D�du*��4���	m�z��M"A=<��y��@U,��j�n55���y�c�H�e�q�$�D?�q6N����33�+<H�GVS�b�>�n�u~n&�p@R��co<�1�M�=mɂu���&��ͥ�L���c�G-��&��&�7�I]��y�~F�"�*��V�Nw�֡��"/ �f�UE�)�����,�вo��Ѣ�G�G���u��K�L)�A�s�#q�r� Ą:��nGJG��n�~va�^�~�A�<���ѣ/Lc��&�~�P>:=a`pȃ��i����@HD��U��@��Ul|hl�;9�sZ�yY�q�::����@��<=�-밋gc�ʑ=ۡm�9s�a F��t#!�$�G�W�0��vI	��9��ܢc��G�&7nX?|䰎;��hn߾}q�&����p�`��UY�4�SU�gQ�A�U\i�<���4�kBix���j�Do�!�^����Uw���WBxؠ4��ڋ6*�G$mh���aL�ym�I�4	�ܢuS�ހ�x��>~��w~|�����X@V�v��WoRc��i���.ܰ7L���W&^�.��v�Kk�`k��	"��:6~4�ɓ�˿�.J�.1���D�^91�Ǌ�c��
2�	+nȟ���dX��^��~��9a��<n7\K.7
i��.Ŗ>"��Mւg��c�Z���ْļ-��x�M�0܅�,/����e߬9r$>#)i��v왐Ԋ���KM!��/��@��Y�x���M��*p檊�{�۳uiE�	�D��]�{����>-Y�s��������� Aޘ�D�/��!�Bq���4kq	�M�����V��W���Y��ދKk-��㞱	8��~�8ۧ_�x�ϓW>��>��]�\4����P`d��,F���Wލ%s�M������Er?��4:<��f~4顇����E_,�;�X�E�HAIRE��N8~��"��f���5\�Ȉ��9�5|uj��8���n;�M�苉iR#kc)B�Ԡɰ+�o����$[�8�g����2O��>.��㬏��]V?wK�?M+�� �w�s���b��k5B������MY�&Q�-i���l�t����yd��sB����K^K� Mڻ����𽔿�h�p�5��<�|�
S��JUN��1���!j�e�6�}�)���1<�6��]�x�vx���DK]U�%�K҄�_j��Uϑ�%cc�|�`�v�,[����a���-�<��V/[�n߾����bݭһ�������"�TU	G��f�L����~>�&���M�@e���Y�V�\t4�:|�Փ'?	-Ț���f�I��Tь�����^��zB̚*�D' !pN��l���|�@`9�Ǜ����>=y<�e��L��z��	��f�8��U?L��ԟ~Z7�Ҝɽ���kZ�����7ѯ��k���(b�;�����h�m��쯠P3}eEQ�����o������De�?	��+��
�۞g��(���T@Bm5:���m��B:r�2u���7�L4f	�"
�K�$
�%��#%���G �z�0�a228נL���Ng�:#����M�$��׼�pp���v��n�_�|)\%�����M>�����C�Cp�����!V�	�蓍Y�_��kM"K_�P��G!�r�S��?��`�p�1��3�U�>PR4���0��A�ŷu��\H��`�T�/5T�������8{;��al	���P(�	��@܉.�*]xu���ll���QG��8k
ڠ��&�ݰ��,���H�<lj}��T[��}[_��v��&ܳ���c��C[�g͙�43�@aa��,�ŧ���Km����s�SE�����*��0�6�),�l6Y��O��;������씂�p�x�{�c'M�ԧ����hd��d���Қ	172!(\����;X�sEQ�V�������0SX���rk�Y�3�yrM�n='?�Э�\����D�b�Q!Ù8`�B;��(wٷ���x�VC����=�ե'�1p�\"�ǿfMڪ�E��K�b��me������7
ac3��s���r�@ ڑ۶����cn}#��c�㭔d>�`�1����:�7�l��	;�#�S#�ǠI=:K2B�ا�I28�"��:@V��f���o���E\���h���fp��dNI�e�}$J�Q?V���������]F��,���2�Hn��x +�$�Ac�j��Ex�˭��/CRֺ^�&u�t���8�6��J�+жC�j� ��*鞟9{"Y�j�U�^c,F����%wG�n��QQ��}����i�V�2�pt�0n�9u����K^�`Y��X�:Zb�m�64�*n�tk�[}{g��� Mv���
\W���S*V�J�g�\P�� /�x톟W�ذ�ࡲ�2U�mvGr˶�)�\qɮ�D�����KSP�P(��4jw���ޟX�G����̊*{**Js�r����PV��(p�w���F����!C��7�|^�l4��x��5Kc��jU <�����*WӸ$�I��l �d���4�H�7JA���3�'�Or����=�UˑÇ��٥�����g5]�e5���훷�?t���WUy"m�]ʞ�v��g��F�	��0(�kG���$�,I�.eS�@UG��:ۀ[-�]�X|�\�)�M�:�;���ǳs�o�ݽk��	?AzUU��F%:4%#��an��+�k,�(��F��:k�C��fBt���&�o�Q^XĤѳ�����C*H'�_}�\�0M☲ �ɡuib�K�كL��Q�3%������ꉀ�4�XqJ%`>y�F!����g��r�b2��ٯ�5$ϑsM��%gH����q�1�>�LW˄��S���e�n\NLC����F����r$kv8�?���,�Z�V��cZHg��	 �r��a�}����t_�ʉ��Ok�|SR?��%|�C).������=��f��v>z"�x�$Mfx�1qq�Twb�#&�fup��8��q�3|,TTRC�4�{��L�� U����CPӧ�b(��zKJ��*�?Z\��JUxE�Sǌ���뮺jhJJ�3��F�*��Ul[m�z�q�	�҆,B=lM�p���z���+�3c;��J�2�Β	Z����sS��e�Y`q�VES%8ʮ�NS�?�$�) �L"+�󬆳>HD+l�Ҙ��oSִVt�z�d�}��L�� <Z��9A�Q��gJ�����o}���[7�JLH �<�#�.�AEQ���Q^�ޜM��	D%�D��e-�Ļ�=(���Yk;���x��qHz��)�frd@�r��t��qS�wЀ�&�y��p�G4J����z��l#7���ݓW���DG=b�쇩� ��$�L����Y��`�΃��u�����p�6�8e�uaQ�h�Դ���ɥ'���$6�X�]��h���5㞺�$��:�̷�]�p�&�u��F��>�<*d���Hg��9��ub����C���|�zO �-+��Ԇ�4�p�LG��{��̷�zؔ�۳����T��?0\�����8x|�������)-++/��5��6��c���Ƞ��bu��3�F�Mѳ�����2TeY�B�����@��SZQz�_URY^XYY4RӉ��q���]ֹ�С�nu]RR���<��9/h�D�
Uc86PzJ�������n�ς��
����+��5ܰa�lB�6%�(������i�ֵpY���W�n'���׈�3(�Y�lbpc��������+o�.��7��#����V��4+�]�@]KNN���2�d|�p��b�TEV%E����&�I
Ǟ��r�608��v2����zu�k��M"u�1�1���nl*F��jm?ܰ�,0��0D<(���bh�ȣt�@U��GM<:�^�2�k��Sra�W��Yw�7$;,��Ni#�����۹?��@A�E@Q����k�)Y�έ��DȒZ���j4�3�e��x�a���	�Z�J�4Y�:c�gmIBL�����ZuR�:��R� ޘckguKE;*�{HWTT�K�+.��i�w6�M�wJU�rU����B�Rp�T��X�3�o�,��������=yf����%�'󲲎���9�s�Dn�Š�
��FLx��3��g!'-�IE���� ���1�`2�-������:uhߥ�e�mZ�m��"���&���rf�o�\v�lK�lХ�������(ak�#
8�5�q��ԸZ�Z��'Z2W�zN�x��l���@�g6CxDyV��2ݪC�0�X�E�i����c�`U��˄r�H8 ��K~���`�%2���T���g��!͘-ˢ��%><Ǜ-v�@�L�!+!�������XC���+�9�a�R�۬湊(	��c����D�r�A�8�K�UOsbSR��W�C�X��X��*�^��N=ڣ��V�ns����CӼ[���kv�~�2$0��X�?
�S$N��5O�4ʔi�'_�G�ˑzǡ��t����5�����ִH�s���- ᕖV�*�/*.+�(-�@̇K�u��(*E p� ��H_����,qq�-R[�Jk��Ԫm��渴�E3�$<�2vp�/;3�i��tk����y�XQp��E��!%&�X 72(V�s5�&��,f�+�2�Ea
Z|4������Lg��b��NZ96���r@�
E8����%E��$��R��D�ֿ��_yܘ�Q�պf�Y�c�/;
F07=��]b�R#� 1O"AR�q%�:lM^�4���Y8�3���=�����E���3	f��j6[HBE���ZB9"�4�H��\F��I%$/�؏Hӡ�i:G	O�T���^t�4������菵�|�#v���u�V�e#A{FfQ���=�����+�ٖ�<o����܍2�?����To%��
�I9=��7iPPh��I4��؅�r��_e���JO�
�@�� o>*�e+Mq>=��Ե������jx"�S�h���PU���a�^��2&9�qY���ϱ�_F��"� �m=$�	�rȸM�y��o���+���T2_�+��f���B�o:�9C�{_�B�"��5�!j�F$��#!9r�8Y��W�tO���_�58�y��g<��a7	V��o�T�*�V iՈ���:J�Ɵ����Sq�1�z獦sE�C»ct]��ij�(�Ԟ��'1j����O��H%��f��A�*�T�W�<�d����S�k�-�yMr�U�ú���m�1�����g��Z�9<�������S�o4k���c�ľl8�5��p�
|��^�m��i���s��L	"90�LRV���&Miuzaq����Հ"J��沌\�D�� ,�,9�̣?�&gs'���n�G�gE�aMz�HY�������/ɶ%�x369ư&y��L��HrIw���!��6nܔ�}tܸ�0�p��%��iHŞ������:oԛE���ί�!)P��O�8j熅�.b���KS[�����o#xdΪ�e25��p2ҳSuQAR,��~��w{{�U�}5`�S�#a��#RI�%As�M��P ��(2�0Ok���Q4kΙ̚�j�����[�*�inw�Ա�i�N	�f��~D���(u�[�*}ݏ��Ư
�@�ٓ��X"�-�\"���"�s��fk�k~B�ˈ�����W�
	R.�H+2�������D%P�	f�:�HbD��Bÿ;2��A� ����]T;���\��?_���=��F��}p6'5Zĕ�<8�ۙ���/,�+Ë��'�=yM�oxiN�Q������9`eUTTP�^t�������,v�l���1�ǜZ�5��:� ��S�R���]�Գ��p�f�KmVG�.�r�a�+hr�%��X����-s�m���q!���f?�igKyO_�p�5�����_x�ڏ�ي�H��,~�����G"?kj&b8�	�5�>�3-�l��Q�<���GV�;�}b�V�j�X_����_ͥ<}<�����a�`j205=�e�h;�C��C���9(GR\�h~MW�V���%�Q��!R�Pq�9�k�`�LF�|����"��^U�z���N�k��&���,�F`b��$���q�I. *e&J���kR��,s�sZ���J�U�B��$g�����}Ġ�
�8���AԈ�Zф$ʫ��t]-ݖK����~�*�w�������e"U�\��h����Ns4�II�N;��&��Y�8���NAq�(h� \9�'*�{@	tR��"��_�'�lc9^B�(r)jb�/�|�Dv$�8��k�AV� \�Wg���%�ʢ&��lsi%9򡝚���d,8��6�N=���YM��^<�	�&b�"\���#k���+ř�"�I���.l(�2�
RD�;���T�P�=(x��7�"!�@c��)$�Q{3���9R'l�ܤ8i�����e����b( ����dK��D���h��9



�s���&�i�����4�с��U�($� �?���e�K�?�k�]D�H�9No�Thҍ4�X�]�$��*a�0�'����"\�4Y�C$\tR zѣ��a���MC��Z�,��N�#_Dh�!�+,Ch��asӨ;Q#i������W�K�&���zM�btB��	���V�	��b)Q�u�"��^�V�C�I��;ʋ�)\�4IAAAAAq�Ai�������AP�������h�&)(((((�I




�Ai�������AP�������h�&)(((((�I




�Ai�������AP�������h�&)(((((�I




�Ai�������AP�������h�&)(((((�I




�Ai�������AP�������h�&)(((((�I




�Ai�������AP�������h�&)(((((�I




�Ai�������AP�������h�&)(((((�I




�Ai�������A�?`Y�=�n�^    IEND�B`�                                                                                                                                                                                                                                                                                                                                                                                                                   lamp/conf/p.php                                                                                     000644  000765  000024  00000163073 13564465250 015221  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <?php
/* ----------------This probe is based on the YaHei.net probe------------------- */
error_reporting(0); //Suppress all error messages
ini_set('display_errors','Off');
@header("content-Type: text/html; charset=utf-8"); //Language coercion
ob_start();
date_default_timezone_set('Asia/Shanghai');//Time zone setting
$title = 'PHP Probe';
$version = "v0.4.7"; //version
define('HTTP_HOST', preg_replace('~^www\.~i', '', $_SERVER['HTTP_HOST']));
$time_start = microtime_float();
function memory_usage() 
{
    $memory = ( ! function_exists('memory_get_usage')) ? '0' : round(memory_get_usage()/1024/1024, 2).'MB';
    return $memory;
}

// Timing
function microtime_float() 
{
    $mtime = microtime();
    $mtime = explode(' ', $mtime);
    return $mtime[1] + $mtime[0];
}

//Unit conversion
function formatsize($size) 
{
    $danwei=array(' B ',' K ',' M ',' G ',' T ');
    $allsize=array();
    $i=0;
    for($i = 0; $i <5; $i++) 
    {
        if(floor($size/pow(1024,$i))==0){break;}
    }

    for($l = $i-1; $l >=0; $l--) 
    {
        $allsize1[$l]=floor($size/pow(1024,$l));
        $allsize[$l]=$allsize1[$l]-$allsize1[$l+1]*1024;
    }

    $len=count($allsize);

    for($j = $len-1; $j >=0; $j--) 
    {
        $fsize=$fsize.$allsize[$j].$danwei[$j];
    }    
    return $fsize;
}

function valid_email($str) 
{
    return ( ! preg_match("/^([a-z0-9\+_\-]+)(\.[a-z0-9\+_\-]+)*@([a-z0-9\-]+\.)+[a-z]{2,6}$/ix", $str)) ? FALSE : TRUE;
}

//Detect PHP set parameters
function show($varName)
{
    switch($result = get_cfg_var($varName))
    {
        case 0:
            return '<font color="red"><i class="fa fa-times"></i></font>';
        break;
        case 1:
            return '<font color="green"><i class="fa fa-check"></i></font>';
        break;
        default:
            return $result;
        break;
    }
}

//Keep server performance test results
$valInt = isset($_POST['pInt']) ? $_POST['pInt'] : "Not Tested";
$valFloat = isset($_POST['pFloat']) ? $_POST['pFloat'] : "Not Tested";
$valIo = isset($_POST['pIo']) ? $_POST['pIo'] : "Not Tested";

if (isset($_GET['act']) && $_GET['act'] == "phpinfo") 
{
    phpinfo();
    exit();
} 
elseif(isset($_POST['act']) && $_POST['act'] == "Integer Test")
{
    $valInt = test_int();
} 
elseif(isset($_POST['act']) && $_POST['act'] == "Floating Test")
{
    $valFloat = test_float();
} 
elseif(isset($_POST['act']) && $_POST['act'] == "IO Test")
{
    $valIo = test_io();
} 
//Speed ​​test - start
elseif(isset($_POST['act']) && $_POST['act']=="Start Testing")
{
?>
    <script language="javascript" type="text/javascript">
        var acd1;
        acd1 = new Date();
        acd1ok=acd1.getTime();
    </script>
    <?php
    for($i=1;$i<=204800;$i++)
    {
        echo "<!--34567890#########0#########0#########0#########0#########0#########0#########0#########012345-->";
    }
    ?>
    <script language="javascript" type="text/javascript">
        var acd2;
        acd2 = new Date();
        acd2ok=acd2.getTime();
        window.location = '?speed=' +(acd2ok-acd1ok)+'#w_networkspeed';
    </script>
<?php
}
elseif(isset($_GET['act']) && $_GET['act'] == "Function")
{
    $arr = get_defined_functions();
    Function php()
    {
    }
    echo "<pre>";
    Echo "This shows all the functions supported by the system, and custom functions\n";
    print_r($arr);
    echo "</pre>";
    exit();
}
elseif(isset($_GET['act']) && $_GET['act'] == "disable_functions")
{
    $disFuns=get_cfg_var("disable_functions");
    if(empty($disFuns))
    {
        $arr = '<font color=red><i class="fa fa-times"></i></font>';
    }
    else
    { 
        $arr = $disFuns;
    }
    Function php()
    {
    }
    echo "<pre>";
    Echo "This shows all the functions disable by the system\n";
    print_r($arr);
    echo "</pre>";
    exit();
}

//MySQL Test
if (isset($_POST['act']) && $_POST['act'] == 'MySQL Test')
{
    $host = isset($_POST['host']) ? trim($_POST['host']) : '';
    $port = isset($_POST['port']) ? (int) $_POST['port'] : '';
    $login = isset($_POST['login']) ? trim($_POST['login']) : '';
    $password = isset($_POST['password']) ? trim($_POST['password']) : '';
    $host = preg_match('~[^a-z0-9\-\.]+~i', $host) ? '' : $host;
    $port = intval($port) ? intval($port) : '';
    $login = preg_match('~[^a-z0-9\_\-]+~i', $login) ? '' : htmlspecialchars($login);
    $password = is_string($password) ? htmlspecialchars($password) : '';
}
elseif (isset($_POST['act']) && $_POST['act'] == 'Function Test')
{
    $funRe = "Function ".$_POST['funName']." Support status Test results：".isfun1($_POST['funName']);
} 
elseif (isset($_POST['act']) && $_POST['act'] == 'Mail Test')
{
    $mailRe = "Mail sending test result: send";
    if($_SERVER['SERVER_PORT']==80){$mailContent = "http://".$_SERVER['SERVER_NAME'].($_SERVER['PHP_SELF'] ? $_SERVER['PHP_SELF'] : $_SERVER['SCRIPT_NAME']);}
    else{$mailContent = "http://".$_SERVER['SERVER_NAME'].":".$_SERVER['SERVER_PORT'].($_SERVER['PHP_SELF'] ? $_SERVER['PHP_SELF'] : $_SERVER['SCRIPT_NAME']);}
    $mailRe .= (false !== @mail($_POST["mailAdd"], $mailContent, "This is a test mail!")) ? "Complete ":" failed";
}

//Get MySQL version
function getMySQLVersion() {
    $output = shell_exec('mysql -V');
    if (empty($output)){
        return null;
    }
    preg_match('@[0-9]+\.[0-9]+\.[0-9]+@', $output, $version);
    return $version[0];
}

// Network speed test
if(isset($_POST['act']) && $_POST['speed'])
{
    $speed=round(100/($_POST['speed']/2048),2);
}
elseif(isset($_GET['speed']) && $_GET['speed']=="0")
{
    $speed=6666.67;
}
elseif(isset($_GET['speed']) and $_GET['speed']>0)
{
    $speed=round(100/($_GET['speed']/2048),2); //download speed：$speed kb/s
}
else
{
    $speed="<font color=\"red\">&nbsp;Not Test&nbsp;</font>";
}    

// Detection function support
function isfun($funName = '')
{
    if (!$funName || trim($funName) == '' || preg_match('~[^a-z0-9\_]+~i', $funName, $tmp)) return 'error';
    return (false !== function_exists($funName)) ? '<font color="green"><i class="fa fa-check"></i></font>' : '<font color="red"><i class="fa fa-times"></i></font>';
}
function isfun1($funName = '')
{
    if (!$funName || trim($funName) == '' || preg_match('~[^a-z0-9\_]+~i', $funName, $tmp)) return 'error';
    return (false !== function_exists($funName)) ? '<i class="fa fa-check"></i>' : '<i class="fa fa-times"></i>';
}

//Integer arithmetic capability test
function test_int()
{
    $timeStart = gettimeofday();
    for($i = 0; $i < 3000000; $i++)
    {
        $t = 1+1;
    }
    $timeEnd = gettimeofday();
    $time = ($timeEnd["usec"]-$timeStart["usec"])/1000000+$timeEnd["sec"]-$timeStart["sec"];
    $time = round($time, 3)."Second";
    return $time;
}

//Floating point computing capability test
function test_float()
{
    //Get the pi value
    $t = pi();
    $timeStart = gettimeofday();
    for($i = 0; $i < 3000000; $i++)
    {
        //square
        sqrt($t);
    }

    $timeEnd = gettimeofday();
    $time = ($timeEnd["usec"]-$timeStart["usec"])/1000000+$timeEnd["sec"]-$timeStart["sec"];
    $time = round($time, 3)."Second";
    return $time;
}

//IO capability test
function test_io()
{
    $fp = @fopen(PHPSELF, "r");
    $timeStart = gettimeofday();
    for($i = 0; $i < 10000; $i++) 
    {
        @fread($fp, 10240);
        @rewind($fp);
    }
    $timeEnd = gettimeofday();
    @fclose($fp);
    $time = ($timeEnd["usec"]-$timeStart["usec"])/1000000+$timeEnd["sec"]-$timeStart["sec"];
    $time = round($time, 3)."Second";
    return($time);
}

function GetCoreInformation() {$data = file('/proc/stat');$cores = array();foreach( $data as $line ) {if( preg_match('/^cpu[0-9]/', $line) ){$info = explode(' ', $line);$cores[]=array('user'=>$info[1],'nice'=>$info[2],'sys' => $info[3],'idle'=>$info[4],'iowait'=>$info[5],'irq' => $info[6],'softirq' => $info[7]);}}return $cores;}
function GetCpuPercentages($stat1, $stat2) {if(count($stat1)!==count($stat2)){return;}$cpus=array();for( $i = 0, $l = count($stat1); $i < $l; $i++) {    $dif = array();    $dif['user'] = $stat2[$i]['user'] - $stat1[$i]['user'];$dif['nice'] = $stat2[$i]['nice'] - $stat1[$i]['nice'];    $dif['sys'] = $stat2[$i]['sys'] - $stat1[$i]['sys'];$dif['idle'] = $stat2[$i]['idle'] - $stat1[$i]['idle'];$dif['iowait'] = $stat2[$i]['iowait'] - $stat1[$i]['iowait'];$dif['irq'] = $stat2[$i]['irq'] - $stat1[$i]['irq'];$dif['softirq'] = $stat2[$i]['softirq'] - $stat1[$i]['softirq'];$total = array_sum($dif);$cpu = array();foreach($dif as $x=>$y) $cpu[$x] = round($y / $total * 100, 2);$cpus['cpu' . $i] = $cpu;}return $cpus;}
$stat1 = GetCoreInformation();sleep(1);$stat2 = GetCoreInformation();$data = GetCpuPercentages($stat1, $stat2);
$cpu_show = $data['cpu0']['user']."%us,  ".$data['cpu0']['sys']."%sy,  ".$data['cpu0']['nice']."%ni, ".$data['cpu0']['idle']."%id,  ".$data['cpu0']['iowait']."%wa,  ".$data['cpu0']['irq']."%irq,  ".$data['cpu0']['softirq']."%softirq";
function makeImageUrl($title, $data) {$api='http://api.yahei.net/tz/cpu_show.php?id=';$url.=$data['user'].',';$url.=$data['nice'].',';$url.=$data['sys'].',';$url.=$data['idle'].',';$url.=$data['iowait'];$url.='&chdl=User|Nice|Sys|Idle|Iowait&chdlp=b&chl=';$url.=$data['user'].'%25|';$url.=$data['nice'].'%25|';$url.=$data['sys'].'%25|';$url.=$data['idle'].'%25|';$url.=$data['iowait'].'%25';$url.='&chtt=Core+'.$title;return $api.base64_encode($url);}
if($_GET['act'] == "cpu_percentage"){echo "<center><b><font face='Microsoft YaHei' color='#666666' size='3'>Image loading slow, please be patient！</font></b><br /><br />";foreach( $data as $k => $v ) {echo '<img src="' . makeImageUrl( $k, $v ) . '" style="width:360px;height:240px;border: #CCCCCC 1px solid;background: #FFFFFF;margin:5px;padding:5px;" />';}echo "</center>";exit();}

// According to different systems to obtain CPU-related information
switch(PHP_OS)
{
    case "Linux":
        $sysReShow = (false !== ($sysInfo = sys_linux()))?"show":"none";
    break;
    case "FreeBSD":
        $sysReShow = (false !== ($sysInfo = sys_freebsd()))?"show":"none";
    break;
/*    
    case "WINNT":
        $sysReShow = (false !== ($sysInfo = sys_windows()))?"show":"none";
    break;
*/    
    default:
    break;
}

//linux System detection
function sys_linux()
{
    // CPU
    if (false === ($str = @file("/proc/cpuinfo"))) return false;
    $str = implode("", $str);
    @preg_match_all("/model\s+name\s{0,}\:+\s{0,}([\w\s\)\(\@.-]+)([\r\n]+)/s", $str, $model);
    @preg_match_all("/cpu\s+MHz\s{0,}\:+\s{0,}([\d\.]+)[\r\n]+/", $str, $mhz);
    @preg_match_all("/cache\s+size\s{0,}\:+\s{0,}([\d\.]+\s{0,}[A-Z]+[\r\n]+)/", $str, $cache);
    @preg_match_all("/bogomips\s{0,}\:+\s{0,}([\d\.]+)[\r\n]+/", $str, $bogomips);
    if (false !== is_array($model[1]))
    {
        $res['cpu']['num'] = sizeof($model[1]);
        /*
        for($i = 0; $i < $res['cpu']['num']; $i++)
        {
            $res['cpu']['model'][] = $model[1][$i].'&nbsp;('.$mhz[1][$i].')';
            $res['cpu']['mhz'][] = $mhz[1][$i];
            $res['cpu']['cache'][] = $cache[1][$i];
            $res['cpu']['bogomips'][] = $bogomips[1][$i];
        }*/
        if($res['cpu']['num']==1)
            $x1 = '';
        else
            $x1 = ' ×'.$res['cpu']['num'];
        $mhz[1][0] = ' | frequency:'.$mhz[1][0];
        $cache[1][0] = ' | Secondary cache:'.$cache[1][0];
        $bogomips[1][0] = ' | Bogomips:'.$bogomips[1][0];
        $res['cpu']['model'][] = $model[1][0].$mhz[1][0].$cache[1][0].$bogomips[1][0].$x1;
        if (false !== is_array($res['cpu']['model'])) $res['cpu']['model'] = implode("<br />", $res['cpu']['model']);
        if (false !== is_array($res['cpu']['mhz'])) $res['cpu']['mhz'] = implode("<br />", $res['cpu']['mhz']);
        if (false !== is_array($res['cpu']['cache'])) $res['cpu']['cache'] = implode("<br />", $res['cpu']['cache']);
        if (false !== is_array($res['cpu']['bogomips'])) $res['cpu']['bogomips'] = implode("<br />", $res['cpu']['bogomips']);
    }

    // UPTIME
    if (false === ($str = @file("/proc/uptime"))) return false;
    $str = explode(" ", implode("", $str));
    $str = trim($str[0]);
    $min = $str / 60;
    $hours = $min / 60;
    $days = floor($hours / 24);
    $hours = floor($hours - ($days * 24));
    $min = floor($min - ($days * 60 * 24) - ($hours * 60));
    if ($days !== 0) $res['uptime'] = $days." Days ";
    if ($hours !== 0) $res['uptime'] .= $hours." Hours ";
    $res['uptime'] .= $min." Minutes";

    // MEMORY
    if (false === ($str = @file("/proc/meminfo"))) return false;
    $str = implode("", $str);
    preg_match_all("/MemTotal\s{0,}\:+\s{0,}([\d\.]+).+?MemFree\s{0,}\:+\s{0,}([\d\.]+).+?Cached\s{0,}\:+\s{0,}([\d\.]+).+?SwapTotal\s{0,}\:+\s{0,}([\d\.]+).+?SwapFree\s{0,}\:+\s{0,}([\d\.]+)/s", $str, $buf);
    preg_match_all("/Buffers\s{0,}\:+\s{0,}([\d\.]+)/s", $str, $buffers);
    $res['memTotal'] = round($buf[1][0]/1024, 2);
    $res['memFree'] = round($buf[2][0]/1024, 2);
    $res['memBuffers'] = round($buffers[1][0]/1024, 2);
    $res['memCached'] = round($buf[3][0]/1024, 2);
    $res['memUsed'] = $res['memTotal']-$res['memFree'];
    $res['memPercent'] = (floatval($res['memTotal'])!=0)?round($res['memUsed']/$res['memTotal']*100,2):0;
    $res['memRealUsed'] = $res['memTotal'] - $res['memFree'] - $res['memCached'] - $res['memBuffers']; //Real memory is used
    $res['memRealFree'] = $res['memTotal'] - $res['memRealUsed']; //Really free
    $res['memRealPercent'] = (floatval($res['memTotal'])!=0)?round($res['memRealUsed']/$res['memTotal']*100,2):0; //Real memory usage
    $res['memCachedPercent'] = (floatval($res['memCached'])!=0)?round($res['memCached']/$res['memTotal']*100,2):0; //Cached Memory usage
    $res['swapTotal'] = round($buf[4][0]/1024, 2);
    $res['swapFree'] = round($buf[5][0]/1024, 2);
    $res['swapUsed'] = round($res['swapTotal']-$res['swapFree'], 2);
    $res['swapPercent'] = (floatval($res['swapTotal'])!=0)?round($res['swapUsed']/$res['swapTotal']*100,2):0;

    // LOAD AVG
    if (false === ($str = @file("/proc/loadavg"))) return false;
    $str = explode(" ", implode("", $str));
    $str = array_chunk($str, 4);
    $res['loadAvg'] = implode(" ", $str[0]);

    return $res;
}

//FreeBSD System detection
function sys_freebsd()
{
    //CPU
    if (false === ($res['cpu']['num'] = get_key("hw.ncpu"))) return false;
    $res['cpu']['model'] = get_key("hw.model");
    //LOAD AVG
    if (false === ($res['loadAvg'] = get_key("vm.loadavg"))) return false;
    //UPTIME
    if (false === ($buf = get_key("kern.boottime"))) return false;
    $buf = explode(' ', $buf);
    $sys_ticks = time() - intval($buf[3]);
    $min = $sys_ticks / 60;
    $hours = $min / 60;
    $days = floor($hours / 24);
    $hours = floor($hours - ($days * 24));
    $min = floor($min - ($days * 60 * 24) - ($hours * 60));
    if ($days !== 0) $res['uptime'] = $days."Days ";
    if ($hours !== 0) $res['uptime'] .= $hours."Hours ";
    $res['uptime'] .= $min."Minutes";

    //MEMORY
    if (false === ($buf = get_key("hw.physmem"))) return false;
    $res['memTotal'] = round($buf/1024/1024, 2);
    $str = get_key("vm.vmtotal");
    preg_match_all("/\nVirtual Memory[\:\s]*\(Total[\:\s]*([\d]+)K[\,\s]*Active[\:\s]*([\d]+)K\)\n/i", $str, $buff, PREG_SET_ORDER);
    preg_match_all("/\nReal Memory[\:\s]*\(Total[\:\s]*([\d]+)K[\,\s]*Active[\:\s]*([\d]+)K\)\n/i", $str, $buf, PREG_SET_ORDER);
    $res['memRealUsed'] = round($buf[0][2]/1024, 2);
    $res['memCached'] = round($buff[0][2]/1024, 2);
    $res['memUsed'] = round($buf[0][1]/1024, 2) + $res['memCached'];
    $res['memFree'] = $res['memTotal'] - $res['memUsed'];
    $res['memPercent'] = (floatval($res['memTotal'])!=0)?round($res['memUsed']/$res['memTotal']*100,2):0;
    $res['memRealPercent'] = (floatval($res['memTotal'])!=0)?round($res['memRealUsed']/$res['memTotal']*100,2):0;
    return $res;
}

//Get the parameter value FreeBSD
function get_key($keyName)
{
    return do_command('sysctl', "-n $keyName");
}

//Determine the execution file location FreeBSD
function find_command($commandName)
{
    $path = array('/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin');
    foreach($path as $p) 
    {
        if (@is_executable("$p/$commandName")) return "$p/$commandName";
    }
    return false;
}

//Execute system commands FreeBSD
function do_command($commandName, $args)
{
    $buffer = "";
    if (false === ($command = find_command($commandName))) return false;
    if ($fp = @popen("$command $args", 'r')) 
    {
        while (!@feof($fp))
        {
            $buffer .= @fgets($fp, 4096);
        }
        return trim($buffer);
    }
    return false;
}

//windows System detection
function sys_windows()
{
    if (PHP_VERSION >= 5)
    {
        $objLocator = new COM("WbemScripting.SWbemLocator");
        $wmi = $objLocator->ConnectServer();
        $prop = $wmi->get("Win32_PnPEntity");
    }
    else
    {
        return false;
    }

    //CPU
    $cpuinfo = GetWMI($wmi,"Win32_Processor", array("Name","L2CacheSize","NumberOfCores"));
    $res['cpu']['num'] = $cpuinfo[0]['NumberOfCores'];
    if (null == $res['cpu']['num']) 
    {
        $res['cpu']['num'] = 1;
    }
    /*
    for ($i=0;$i<$res['cpu']['num'];$i++)
    {
        $res['cpu']['model'] .= $cpuinfo[0]['Name']."<br />";
        $res['cpu']['cache'] .= $cpuinfo[0]['L2CacheSize']."<br />";
    }*/
    $cpuinfo[0]['L2CacheSize'] = ' ('.$cpuinfo[0]['L2CacheSize'].')';
    if($res['cpu']['num']==1)
        $x1 = '';
    else
        $x1 = ' ×'.$res['cpu']['num'];
    $res['cpu']['model'] = $cpuinfo[0]['Name'].$cpuinfo[0]['L2CacheSize'].$x1;

    // SYSINFO
    $sysinfo = GetWMI($wmi,"Win32_OperatingSystem", array('LastBootUpTime','TotalVisibleMemorySize','FreePhysicalMemory','Caption','CSDVersion','SerialNumber','InstallDate'));
    $sysinfo[0]['Caption']=iconv('GBK', 'UTF-8',$sysinfo[0]['Caption']);
    $sysinfo[0]['CSDVersion']=iconv('GBK', 'UTF-8',$sysinfo[0]['CSDVersion']);
    $res['win_n'] = $sysinfo[0]['Caption']." ".$sysinfo[0]['CSDVersion']." serial number:{$sysinfo[0]['SerialNumber']} in".date('Y-m-d-H:i:s',strtotime(substr($sysinfo[0]['InstallDate'],0,14)))."installation";

    //UPTIME
    $res['uptime'] = $sysinfo[0]['LastBootUpTime'];
    $sys_ticks = 3600*8 + time() - strtotime(substr($res['uptime'],0,14));
    $min = $sys_ticks / 60;
    $hours = $min / 60;
    $days = floor($hours / 24);
    $hours = floor($hours - ($days * 24));
    $min = floor($min - ($days * 60 * 24) - ($hours * 60));
    if ($days !== 0) $res['uptime'] = $days."Day";
    if ($hours !== 0) $res['uptime'] .= $hours."Hour";
    $res['uptime'] .= $min."Minute";

    //MEMORY
    $res['memTotal'] = round($sysinfo[0]['TotalVisibleMemorySize']/1024,2);
    $res['memFree'] = round($sysinfo[0]['FreePhysicalMemory']/1024,2);
    $res['memUsed'] = $res['memTotal']-$res['memFree'];    //The above two lines have been divided by 1024, this line no longer except
    $res['memPercent'] = round($res['memUsed'] / $res['memTotal']*100,2);
    $swapinfo = GetWMI($wmi,"Win32_PageFileUsage", array('AllocatedBaseSize','CurrentUsage'));

    // LoadPercentage
    $loadinfo = GetWMI($wmi,"Win32_Processor", array("LoadPercentage"));
    $res['loadAvg'] = $loadinfo[0]['LoadPercentage'];
    
    return $res;
}

function GetWMI($wmi,$strClass, $strValue = array())
{
    $arrData = array();
    $objWEBM = $wmi->Get($strClass);
    $arrProp = $objWEBM->Properties_;
    $arrWEBMCol = $objWEBM->Instances_();
    foreach($arrWEBMCol as $objItem) 
    {
        @reset($arrProp);
        $arrInstance = array();
        foreach($arrProp as $propItem) 
        {
            eval("\$value = \$objItem->" . $propItem->Name . ";");
            if (empty($strValue)) 
            {
                $arrInstance[$propItem->Name] = trim($value);
            } 
            else
            {
                if (in_array($propItem->Name, $strValue)) 
                {
                    $arrInstance[$propItem->Name] = trim($value);
                }
            }
        }
        $arrData[] = $arrInstance;
    }

    return $arrData;
}

// Proportional bar
function bar($percent)
{
?>
    <div class="bar"><div class="barli" style="width:<?php echo $percent?>%">&nbsp;</div></div>
<?php
}

$uptime = $sysInfo['uptime']; //online time
$stime = date('Y-m-d H:i:s'); //The current time of the system

//hard disk
$dt = round(@disk_total_space(".")/(1024*1024*1024),3); //total
$df = round(@disk_free_space(".")/(1024*1024*1024),3); //Available
$du = $dt-$df; //used
$hdPercent = (floatval($dt)!=0)?round($du/$dt*100,2):0;
$load = $sysInfo['loadAvg'];    //System load

//If the memory is less than 1G, it will display M, otherwise it will display G units
if($sysInfo['memTotal']<1024)
{
    $memTotal = $sysInfo['memTotal']." M";
    $mt = $sysInfo['memTotal']." M";
    $mu = $sysInfo['memUsed']." M";
    $mf = $sysInfo['memFree']." M";
    $mc = $sysInfo['memCached']." M";    //cacheMemory
    $mb = $sysInfo['memBuffers']." M";    //buffer
    $st = $sysInfo['swapTotal']." M";
    $su = $sysInfo['swapUsed']." M";
    $sf = $sysInfo['swapFree']." M";
    $swapPercent = $sysInfo['swapPercent'];
    $memRealUsed = $sysInfo['memRealUsed']." M"; //Real memory is used
    $memRealFree = $sysInfo['memRealFree']." M"; //Real memory is free
    $memRealPercent = $sysInfo['memRealPercent']; //Real memory usage ratio
    $memPercent = $sysInfo['memPercent']; //Total memory usage
    $memCachedPercent = $sysInfo['memCachedPercent']; //Cache memory usage
}
else
{
    $memTotal = round($sysInfo['memTotal']/1024,3)." G";
    $mt = round($sysInfo['memTotal']/1024,3)." G";
    $mu = round($sysInfo['memUsed']/1024,3)." G";
    $mf = round($sysInfo['memFree']/1024,3)." G";
    $mc = round($sysInfo['memCached']/1024,3)." G";
    $mb = round($sysInfo['memBuffers']/1024,3)." G";
    $st = round($sysInfo['swapTotal']/1024,3)." G";
    $su = round($sysInfo['swapUsed']/1024,3)." G";
    $sf = round($sysInfo['swapFree']/1024,3)." G";
    $swapPercent = $sysInfo['swapPercent'];
    $memRealUsed = round($sysInfo['memRealUsed']/1024,3)." G"; //Real memory is used
    $memRealFree = round($sysInfo['memRealFree']/1024,3)." G"; //Real memory is free
    $memRealPercent = $sysInfo['memRealPercent']; //Real memory usage ratio
    $memPercent = $sysInfo['memPercent']; //Total memory usage
    $memCachedPercent = $sysInfo['memCachedPercent']; //cacheMemory usage
}

//Cache memory usage
$strs = @file("/proc/net/dev"); 

for ($i = 2; $i < count($strs); $i++ )
{
    preg_match_all( "/([^\s]+):[\s]{0,}(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/", $strs[$i], $info );
    $NetOutSpeed[$i] = $info[10][0];
    $NetInputSpeed[$i] = $info[2][0];
    $NetInput[$i] = formatsize($info[2][0]);
    $NetOut[$i]  = formatsize($info[10][0]);
}

//ajax call real-time refresh
if ($_GET['act'] == "rt")
{
    $arr=array('useSpace'=>"$du",'freeSpace'=>"$df",'hdPercent'=>"$hdPercent",'barhdPercent'=>"$hdPercent%",'TotalMemory'=>"$mt",'UsedMemory'=>"$mu",'FreeMemory'=>"$mf",'CachedMemory'=>"$mc",'Buffers'=>"$mb",'TotalSwap'=>"$st",'swapUsed'=>"$su",'swapFree'=>"$sf",'loadAvg'=>"$load",'uptime'=>"$uptime",'freetime'=>"$freetime",'bjtime'=>"$bjtime",'stime'=>"$stime",'memRealPercent'=>"$memRealPercent",'memRealUsed'=>"$memRealUsed",'memRealFree'=>"$memRealFree",'memPercent'=>"$memPercent%",'memCachedPercent'=>"$memCachedPercent",'barmemCachedPercent'=>"$memCachedPercent%",'swapPercent'=>"$swapPercent",'barmemRealPercent'=>"$memRealPercent%",'barswapPercent'=>"$swapPercent%",'NetOut2'=>"$NetOut[2]",'NetOut3'=>"$NetOut[3]",'NetOut4'=>"$NetOut[4]",'NetOut5'=>"$NetOut[5]",'NetOut6'=>"$NetOut[6]",'NetOut7'=>"$NetOut[7]",'NetOut8'=>"$NetOut[8]",'NetOut9'=>"$NetOut[9]",'NetOut10'=>"$NetOut[10]",'NetInput2'=>"$NetInput[2]",'NetInput3'=>"$NetInput[3]",'NetInput4'=>"$NetInput[4]",'NetInput5'=>"$NetInput[5]",'NetInput6'=>"$NetInput[6]",'NetInput7'=>"$NetInput[7]",'NetInput8'=>"$NetInput[8]",'NetInput9'=>"$NetInput[9]",'NetInput10'=>"$NetInput[10]",'NetOutSpeed2'=>"$NetOutSpeed[2]",'NetOutSpeed3'=>"$NetOutSpeed[3]",'NetOutSpeed4'=>"$NetOutSpeed[4]",'NetOutSpeed5'=>"$NetOutSpeed[5]",'NetInputSpeed2'=>"$NetInputSpeed[2]",'NetInputSpeed3'=>"$NetInputSpeed[3]",'NetInputSpeed4'=>"$NetInputSpeed[4]",'NetInputSpeed5'=>"$NetInputSpeed[5]");
    $jarr=json_encode($arr); 
    $_GET['callback'] = htmlspecialchars($_GET['callback']);
    echo $_GET['callback'],'(',$jarr,')';
    exit;
}
?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title><?php echo $title; ?></title>
<meta http-equiv="X-UA-Compatible" content="IE=EmulateIE7" />
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<link href="//cdn.bootcss.com/font-awesome/4.5.0/css/font-awesome.min.css" rel="stylesheet">
<link href="data:image/png;base64,Qk02AwAAAAAAADYAAAAoAAAAEAAAABAAAAABABgAAAAAAAADAADEDgAAxA4AAAAAAAAAAAAAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICA19fX19fX19fXwICAwICAwICAwICAwICAwICAwICA19fX19fX19fXwICAwICAwICA19fXAAAA19fXwICAwICAwICAwICAwICAwICAwICA19fXAAAA19fXwICAwICAwICA19fXAAAA19fX19fXwICAwICA19fXwICAwICA19fX19fXAAAA19fX19fXwICAwICA19fXAAAAAAAAAAAA19fX19fXAAAA19fX19fXAAAA19fXAAAAAAAAAAAA19fX19fX19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fX19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fX19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fX19fXAAAAAAAAAAAA19fX19fXAAAAAAAAAAAA19fX19fXAAAAAAAAAAAA19fX19fXwICA19fX19fX19fXwICA19fXAAAA19fX19fXwICAwICA19fX19fX19fXwICAwICAwICAwICAwICAwICAwICA19fXAAAA19fXwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICA19fX19fX19fXwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICA" type="image/x-icon" rel="icon" />
<style type="text/css">
<!--
body{margin: 0 auto; padding: 0; background-color:#eee;font-size:14px;font-family: Noto Sans CJK SC,Microsoft Yahei,Hiragino Sans GB,WenQuanYi Micro Hei,sans-serif;}
a,input,button{outline: none !important;-webkit-appearance: none;border-radius: 0;}
button::-moz-focus-inner,input::-moz-focus-inner{border-color:transparent !important;}
:focus {border: none;outline: 0;}
h1 {font-size: 26px; padding: 0; margin: 0; color: #333333;}
h1 small {font-size: 11px; font-family: Tahoma; font-weight: bold; }
a{color: #666; text-decoration:none;}
a.black{color: #000000; text-decoration:none;}
table{width:100%;clear:both;padding: 0; margin: 0 0 18px;border-collapse:collapse; border-spacing: 0;box-shadow: 1px 1px 4px #999;}
th{padding: 6px 12px; font-weight:bold;background:#9191c4;color:#000;border:1px solid #9191c4; text-align:left;font-size:16px;border-bottom: 0px;font-weight: normal;}
tr{padding: 0; background:#FFFFFF;}
td{padding: 3px 6px; border:1px solid #CCCCCC;}
#nav{height:48px;font-size: 15px;background-color:#447;color:#fff !important;position:fixed;top:0px;width:100%;cursor: default;}
.w_logo{height:29px; padding:9px 24px;display: inline-block;font-size: 18px;float:left;}
.w_top{height:24px;color:#fff;font-size: 15px;display: inline-block;padding:12px 24px;transition: background-color 0.2s;float:left;cursor: default;}
.w_top:hover{background:#0C2136;}
.w_foot{height:25px;text-align:center; background:#dedede;}
input{padding: 2px; background: #FFFFFF;border:1px solid #888;font-size:12px; color:#000;}
input:focus{border:1px solid #666;}
input.btn{line-height: 20px; padding: 6px 15px; color:#fff; background: #447; font-size:12px; border:0;transition: background-color 0.2s;box-shadow: 0 0 1px #888888;}
input.btn:hover{background:#558;}
.bar {border:0; background:#ddd; height:15px; font-size:2px; width:89%; margin:2px 0 5px 0;overflow: hidden;}
.barli_red{background:#d9534f; height:15px; margin:0px; padding:0;}
.barli_blue{background:#337ab7; height:15px; margin:0px; padding:0;}
.barli_green{background:#5cb85c; height:15px; margin:0px; padding:0;}
.barli_orange{background:#f0ad4e; height:15px; margin:0px; padding:0;}
.barli_blue2{background:#5bc0de; height:15px; margin:0px; padding:0;}
#page {max-width: 1080px; padding: 0 auto; margin: 80px auto 0; text-align: left;}
#header{position:relative; padding:5px;}
.w_small{font-family: Courier New;}
.w_number{color: #177BBE;}
.sudu {padding: 0; background:#5dafd1; }
.suduk { margin:0px; padding:0;}
.resYes{}
.resNo{color: #FF0000;}
.word{word-break:break-all;}
@media screen and (max-width: 1180px){
	#page {margin: 80px 50px 0; }
}
-->
</style>
<script language="JavaScript" type="text/javascript" src="./jquery.js"></script>
<script type="text/javascript"> 
<!--
$(document).ready(function(){getJSONData();});
var OutSpeed2=<?php echo floor($NetOutSpeed[2]) ?>;
var OutSpeed3=<?php echo floor($NetOutSpeed[3]) ?>;
var OutSpeed4=<?php echo floor($NetOutSpeed[4]) ?>;
var OutSpeed5=<?php echo floor($NetOutSpeed[5]) ?>;
var InputSpeed2=<?php echo floor($NetInputSpeed[2]) ?>;
var InputSpeed3=<?php echo floor($NetInputSpeed[3]) ?>;
var InputSpeed4=<?php echo floor($NetInputSpeed[4]) ?>;
var InputSpeed5=<?php echo floor($NetInputSpeed[5]) ?>;

function getJSONData()
{
    setTimeout("getJSONData()", 1000);
    $.getJSON('?act=rt&callback=?', displayData);
}
function ForDight(Dight,How)
{ 
  if (Dight<0){
      var Last=0+"B/s";
  }else if (Dight<1024){
      var Last=Math.round(Dight*Math.pow(10,How))/Math.pow(10,How)+"B/s";
  }else if (Dight<1048576){
      Dight=Dight/1024;
      var Last=Math.round(Dight*Math.pow(10,How))/Math.pow(10,How)+"K/s";
  }else{
      Dight=Dight/1048576;
      var Last=Math.round(Dight*Math.pow(10,How))/Math.pow(10,How)+"M/s";
  }
    return Last; 
}

function displayData(dataJSON)
{
    $("#useSpace").html(dataJSON.useSpace);
    $("#freeSpace").html(dataJSON.freeSpace);
    $("#hdPercent").html(dataJSON.hdPercent);
    $("#barhdPercent").width(dataJSON.barhdPercent);
    $("#TotalMemory").html(dataJSON.TotalMemory);
    $("#UsedMemory").html(dataJSON.UsedMemory);
    $("#FreeMemory").html(dataJSON.FreeMemory);
    $("#CachedMemory").html(dataJSON.CachedMemory);
    $("#Buffers").html(dataJSON.Buffers);
    $("#TotalSwap").html(dataJSON.TotalSwap);
    $("#swapUsed").html(dataJSON.swapUsed);
    $("#swapFree").html(dataJSON.swapFree);
    $("#swapPercent").html(dataJSON.swapPercent);
    $("#loadAvg").html(dataJSON.loadAvg);
    $("#uptime").html(dataJSON.uptime);
    $("#freetime").html(dataJSON.freetime);
    $("#stime").html(dataJSON.stime);
    $("#bjtime").html(dataJSON.bjtime);
    $("#memRealUsed").html(dataJSON.memRealUsed);
    $("#memRealFree").html(dataJSON.memRealFree);
    $("#memRealPercent").html(dataJSON.memRealPercent);
    $("#memPercent").html(dataJSON.memPercent);
    $("#barmemPercent").width(dataJSON.memPercent);
    $("#barmemRealPercent").width(dataJSON.barmemRealPercent);
    $("#memCachedPercent").html(dataJSON.memCachedPercent);
    $("#barmemCachedPercent").width(dataJSON.barmemCachedPercent);
    $("#barswapPercent").width(dataJSON.barswapPercent);
    $("#NetOut2").html(dataJSON.NetOut2);
    $("#NetOut3").html(dataJSON.NetOut3);
    $("#NetOut4").html(dataJSON.NetOut4);
    $("#NetOut5").html(dataJSON.NetOut5);
    $("#NetOut6").html(dataJSON.NetOut6);
    $("#NetOut7").html(dataJSON.NetOut7);
    $("#NetOut8").html(dataJSON.NetOut8);
    $("#NetOut9").html(dataJSON.NetOut9);
    $("#NetOut10").html(dataJSON.NetOut10);
    $("#NetInput2").html(dataJSON.NetInput2);
    $("#NetInput3").html(dataJSON.NetInput3);
    $("#NetInput4").html(dataJSON.NetInput4);
    $("#NetInput5").html(dataJSON.NetInput5);
    $("#NetInput6").html(dataJSON.NetInput6);
    $("#NetInput7").html(dataJSON.NetInput7);
    $("#NetInput8").html(dataJSON.NetInput8);
    $("#NetInput9").html(dataJSON.NetInput9);
    $("#NetInput10").html(dataJSON.NetInput10);    
    $("#NetOutSpeed2").html(ForDight((dataJSON.NetOutSpeed2-OutSpeed2),3));
    OutSpeed2=dataJSON.NetOutSpeed2;
    $("#NetOutSpeed3").html(ForDight((dataJSON.NetOutSpeed3-OutSpeed3),3));
    OutSpeed3=dataJSON.NetOutSpeed3;
    $("#NetOutSpeed4").html(ForDight((dataJSON.NetOutSpeed4-OutSpeed4),3));
    OutSpeed4=dataJSON.NetOutSpeed4;
    $("#NetOutSpeed5").html(ForDight((dataJSON.NetOutSpeed5-OutSpeed5),3));
    OutSpeed5=dataJSON.NetOutSpeed5;
    $("#NetInputSpeed2").html(ForDight((dataJSON.NetInputSpeed2-InputSpeed2),3));
    InputSpeed2=dataJSON.NetInputSpeed2;
    $("#NetInputSpeed3").html(ForDight((dataJSON.NetInputSpeed3-InputSpeed3),3));
    InputSpeed3=dataJSON.NetInputSpeed3;
    $("#NetInputSpeed4").html(ForDight((dataJSON.NetInputSpeed4-InputSpeed4),3));
    InputSpeed4=dataJSON.NetInputSpeed4;
    $("#NetInputSpeed5").html(ForDight((dataJSON.NetInputSpeed5-InputSpeed5),3));
    InputSpeed5=dataJSON.NetInputSpeed5;
}
-->
</script>
</head>

<body>
<a name="w_top"></a>
<div id="nav">
    <div style="display: inline-block">
        <div class="w_logo"><span>PHP Probe</span></div>
    </div>
    <div style="display: inline-block">
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: 0 }, 200);"><i class="fa fa-tasks"></i> Server Information</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_php').offset().top }, 200);"><i class="fa fa-tags"></i> PHP Parameters</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_module').offset().top }, 200);"><i class="fa fa-cogs"></i> Components</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_module_other').offset().top }, 200);"><i class="fa fa-cubes"></i> Third Party components</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_db').offset().top }, 200);"><i class="fa fa-database"></i> Database</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_performance').offset().top }, 200);"><i class="fa fa-tachometer"></i> Performance</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_performance').offset().top }, 200);"><i class="fa fa-cloud-upload"></i> Network Speed</a>
    </div>
</div>
<div id="page">
<!--Server related parameters -->
<table>
  <tr><th colspan="4"><i class="fa fa-tasks"></i> Server Parameters</th></tr>
  <tr>
    <td>Server Domain/IP</td>
    <td colspan="3"><?php echo @get_current_user();?> - <?php echo $_SERVER['SERVER_NAME'];?>(<?php if('/'==DIRECTORY_SEPARATOR){echo $_SERVER['SERVER_ADDR'];}else{echo @gethostbyname($_SERVER['SERVER_NAME']);} ?>)&nbsp;&nbsp;Your IP address is：<?php echo @$_SERVER['REMOTE_ADDR'];?></td>
  </tr>

  <tr>
    <td>Server ID</td>

    <td colspan="3"><?php echo php_uname();?></td>

  </tr>

  <tr>
    <td width="13%">Server OS</td>
    <td width="40%"><?php $os = explode(" ", php_uname()); echo $os[0];?> &nbsp;Kernel version：<?php if('/'==DIRECTORY_SEPARATOR){echo $os[2];}else{echo $os[1];} ?></td>
    <td width="13%">Web Server</td>
    <td width="34%"><?php echo $_SERVER['SERVER_SOFTWARE'];?></td>
  </tr>

  <tr>
    <td>Server Language</td>
    <td><?php echo getenv("HTTP_ACCEPT_LANGUAGE");?></td>
    <td>Server Port</td>
    <td><?php echo $_SERVER['SERVER_PORT'];?></td>
  </tr>

  <tr>
      <td>Server Hostname</td>
      <td><?php if('/'==DIRECTORY_SEPARATOR ){echo $os[1];}else{echo $os[2];} ?></td>
      <td>Root Path</td>
      <td><?php echo $_SERVER['DOCUMENT_ROOT']?str_replace('\\','/',$_SERVER['DOCUMENT_ROOT']):str_replace('\\','/',dirname(__FILE__));?></td>
    </tr>

  <tr>
      <td>Server Admin</td>
      <td><?php if(isset($_SERVER['SERVER_ADMIN'])) echo $_SERVER['SERVER_ADMIN'];?></td>
        <td>Prober Path</td>
        <td><?php echo str_replace('\\','/',__FILE__)?str_replace('\\','/',__FILE__):$_SERVER['SCRIPT_FILENAME'];?></td>
    </tr>    
</table>

<?if("show"==$sysReShow){?>
<table>
  <tr><th colspan="6"><i class="fa fa-area-chart"></i> Server Real time Data</th></tr>

  <tr>
    <td width="13%" >Current Time</td>
    <td width="40%" ><span id="stime"><?php echo $stime;?></span></td>
    <td width="13%" >Server Uptime</td>
    <td width="34%" colspan="3"><span id="uptime"><?php echo $uptime;?></span></td>
  </tr>
  <tr>
    <td width="13%">CPU Model [<?php echo $sysInfo['cpu']['num'];?>Core]</td>
    <td width="87%" colspan="5"><?php echo $sysInfo['cpu']['model'];?></td>
  </tr>
  <tr>
    <td>CPU Usage</td>
    <td colspan="5"><?php if('/'==DIRECTORY_SEPARATOR){echo $cpu_show." | <a href='".$phpSelf."?act=cpu_percentage' target='_blank' class='static'>View chart <i class=\"fa fa-external-link\"></i> </a>";}else{echo "Temporarily only support Linux";}?>
    </td>
  </tr>
  <tr>
    <td>Space Usage</td>
    <td colspan="5">
        Total Space <?php echo $dt;?>&nbsp;G，
        Used <font color='#333333'><span id="useSpace"><?php echo $du;?></span></font>&nbsp;G，
        Free <font color='#333333'><span id="freeSpace"><?php echo $df;?></span></font>&nbsp;G，
        Rate <span id="hdPercent"><?php echo $hdPercent;?></span>%
        <div class="bar"><div id="barhdPercent" class="barli_orange" style="width:<?php echo $hdPercent;?>%" >&nbsp;</div> </div>
    </td>
  </tr>
  <tr>
        <td>Memory Usage</td>
        <td colspan="5">
<?php
$tmp = array(
    'memTotal', 'memUsed', 'memFree', 'memPercent',
    'memCached', 'memRealPercent',
    'swapTotal', 'swapUsed', 'swapFree', 'swapPercent'
);
foreach ($tmp AS $v) {
    $sysInfo[$v] = $sysInfo[$v] ? $sysInfo[$v] : 0;
}
?>
          Total Memory:
          <font color='#CC0000'><?php echo $memTotal;?> </font>
           , Used
          <font color='#CC0000'><span id="UsedMemory"><?php echo $mu;?></span></font>
          , Free
          <font color='#CC0000'><span id="FreeMemory"><?php echo $mf;?></span></font>
          , Rate
          <span id="memPercent"><?php echo $memPercent;?></span>
          <div class="bar"><div id="barmemPercent" class="barli_green" style="width:<?php echo $memPercent?>%" >&nbsp;</div> </div>
<?php
//If the cache is 0, it is not displayed
if($sysInfo['memCached']>0)
{
?>        
          Cache Memory <span id="CachedMemory"><?php echo $mc;?></span>
          , Rate
          <span id="memCachedPercent"><?php echo $memCachedPercent;?></span>
          %    | Buffers <span id="Buffers"><?php echo $mb;?></span>
          <div class="bar"><div id="barmemCachedPercent" class="barli_blue" style="width:<?php echo $memCachedPercent?>%" >&nbsp;</div></div>
          Real Memory Used
          <span id="memRealUsed"><?php echo $memRealUsed;?></span>
          , Real Memory Free
          <span id="memRealFree"><?php echo $memRealFree;?></span>
          , Rate
          <span id="memRealPercent"><?php echo $memRealPercent;?></span>
          %
          <div class="bar"><div id="barmemRealPercent" class="barli_blue2" style="width:<?php echo $memRealPercent?>%" >&nbsp;</div></div> 
<?php
}
//If the SWAP area is 0, it is not displayed
if($sysInfo['swapTotal']>0)
{
?>    
          SWAP:
          <?php echo $st;?>
          , Used
          <span id="swapUsed"><?php echo $su;?></span>
          , Free
          <span id="swapFree"><?php echo $sf;?></span>
          , Rate
          <span id="swapPercent"><?php echo $swapPercent;?></span>
          %
          <div class="bar"><div id="barswapPercent" class="barli_red" style="width:<?php echo $swapPercent?>%" >&nbsp;</div> </div>

<?php
}    
?>          
        </td>
    </tr>

    <tr>
        <td>System Load</td>
        <td colspan="5" class="w_number"><span id="loadAvg"><?php echo $load;?></span></td>
    </tr>
</table>
<?}?>

<?php if (false !== ($strs = @file("/proc/net/dev"))) : ?>
<table>
    <tr><th colspan="5"><i class="fa fa-bar-chart"></i> Network</th></tr>
<?php for ($i = 2; $i < count($strs); $i++ ) : ?>
<?php preg_match_all( "/([^\s]+):[\s]{0,}(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/", $strs[$i], $info );?>
     <tr>
        <td width="13%"><?php echo $info[1][0]?> : </td>
        <td width="29%">In: <font color='#CC0000'><span id="NetInput<?php echo $i?>"><?php echo $NetInput[$i]?></span></font></td>
        <td width="14%">Real time: <font color='#CC0000'><span id="NetInputSpeed<?php echo $i?>">0B/s</span></font></td>
        <td width="29%">Out : <font color='#CC0000'><span id="NetOut<?php echo $i?>"><?php echo $NetOut[$i]?></span></font></td>
        <td width="14%">Real time: <font color='#CC0000'><span id="NetOutSpeed<?php echo $i?>">0B/s</span></font></td>
    </tr>

<?php endfor; ?>
</table>
<?php endif; ?>

<table width="100%" cellpadding="3" cellspacing="0" align="center">
  <tr>
    <th colspan="4"><i class="fa fa-download "></i> PHP Modules</th>
  </tr>
  <tr>
    <td colspan="4"><span class="w_small">
<?php
$able=get_loaded_extensions();
foreach ($able as $key=>$value) {
    if ($key!=0 && $key%13==0) {
        echo '<br />';
    }
    echo "$value&nbsp;&nbsp;";
}
?></span>
    </td>
  </tr>
</table>

<a name="w_php" id="w_php" style="position:relative;top:-60px;"></a>
<table>
  <tr><th colspan="4"><i class="fa fa-tags"></i> PHP Parameters</th></tr>
  <tr>
    <td width="30%">PHP information </td>
    <td width="20%">
        <?php
        $phpSelf = $_SERVER['PHP_SELF'] ? $_SERVER['PHP_SELF'] : $_SERVER['SCRIPT_NAME'];
        $disFuns=get_cfg_var("disable_functions");
        ?>
       <?php echo (false!==preg_match("phpinfo",$disFuns))? '<font color="red"><i class="fa fa-times"></i></font>' :"<a href='$phpSelf?act=phpinfo' target='_blank'>PHPINFO <i class=\"fa fa-external-link\"></i></a>";?>
    </td>
    <td width="30%">PHP Version </td>
    <td width="20%"><?php echo PHP_VERSION;?></td>
  </tr>

  <tr>
    <td>Run PHP </td>
    <td><?php echo strtoupper(php_sapi_name());?></td>
    <td>Memory Limit </td>
    <td><?php echo show("memory_limit");?></td>
  </tr>

  <tr>
    <td>PHP Safe Mode </td>
    <td><?php echo show("safe_mode");?></td>
    <td>POST Max Size </td>
    <td><?php echo show("post_max_size");?></td>
  </tr>

  <tr>
    <td>Upload Max Filesize</td>
    <td><?php echo show("upload_max_filesize");?></td>
    <td>Floating point data of significant digits </td>
    <td><?php echo show("precision");?></td>
  </tr>

  <tr>
    <td>Max Execution Time </td>
    <td><?php echo show("max_execution_time");?> Second</td>
    <td>Socket TimeOut </td>
    <td><?php echo show("default_socket_timeout");?> Second</td>
  </tr>

  <tr>
    <td>PHP Doc Root </td>
    <td><?php echo show("doc_root");?></td>
    <td>User Dir </td>
    <td><?php echo show("user_dir");?></td>
  </tr>

  <tr>
    <td>Enable Dl </td>
    <td><?php echo show("enable_dl");?></td>
    <td>Set Include Path </td>
    <td><?php echo show("set_include_path");?></td>
  </tr>

  <tr>
    <td>Display Errors </td>
    <td><?php echo show("display_errors");?></td>
    <td>Register Globals </td>
    <td><?php echo show("register_globals");?></td>
  </tr>

  <tr>
    <td>Magic Quotes Gpc </td>
    <td><?php echo show("magic_quotes_gpc");?></td>
    <td>"&lt;?...?&gt;"Short Open Tag </td>
    <td><?php echo show("short_open_tag");?></td>
  </tr>

  <tr>
    <td>"&lt;% %&gt;"ASP Tags </td>
    <td><?php echo show("asp_tags");?></td>
    <td>Ignore Repeated Errors </td>
    <td><?php echo show("ignore_repeated_errors");?></td>
  </tr>

  <tr>
    <td>Ignore Repeated Source </td>
    <td><?php echo show("ignore_repeated_source");?></td>
    <td>Report Memory leaks </td>
    <td><?php echo show("report_memleaks");?></td>
  </tr>

  <tr>
    <td>Disabling Magic Quotes </td>
    <td><?php echo show("magic_quotes_gpc");?></td>
    <td>Magic Quotes Runtime </td>
    <td><?php echo show("magic_quotes_runtime");?></td>
  </tr>

  <tr>
    <td>Allow URL fopen </td>
    <td><?php echo show("allow_url_fopen");?></td>
    <td>Register Argc Argv </td>
    <td><?php echo show("register_argc_argv");?></td>
  </tr>

  <tr>
    <td>Cookie </td>
    <td><?php echo isset($_COOKIE)?'<font color="green"><i class="fa fa-check"></i></font>' : '<font color="red"><i class="fa fa-times"></i></font>';?></td>
    <td>PSpell Check </td>
    <td><?php echo isfun("pspell_check");?></td>
  </tr>
   <tr>
    <td>BCMath </td>
    <td><?php echo isfun("bcadd");?></td>
    <td>PCRE </td>
    <td><?php echo isfun("preg_match");?></td>
  </tr>

  <tr>
    <td>PDF </td>
    <td><?php echo isfun("pdf_close");?></td>
    <td>SNMP </td>
    <td><?php echo isfun("snmpget");?></td>
  </tr> 
   <tr>
    <td>Vmailmgr </td>
    <td><?php echo isfun("vm_adduser");?></td>
    <td>Curl </td>
    <td><?php echo isfun("curl_init");?></td>
  </tr> 
   <tr>
    <td>SMTP </td>
    <td><?php echo get_cfg_var("SMTP")?'<font color="green"><i class="fa fa-check"></i></font>' : '<font color="red"><i class="fa fa-times"></i></font>';?></td>
    <td>SMTP Address</td>
    <td><?php echo get_cfg_var("SMTP")?get_cfg_var("SMTP"):'<font color="red"><i class="fa fa-times"></i></font>';?></td>
  </tr> 

  <tr>
    <td>Enable Functions </td>
    <td colspan="3"><a href='<?php echo $phpSelf;?>?act=Function' target='_blank' class='static'>Click here for details <i class="fa fa-external-link"></i></a></td>        
  </tr>

  <tr>
    <td>Disable Functions </td>
    <td colspan="3" class="word">
<?php 
$disFuns=get_cfg_var("disable_functions");
if(empty($disFuns))
{
    echo '<font color=red><i class="fa fa-times"></i></font>';
}
else
{ 
    //echo $disFuns;
    $disFuns_array =  explode(',',$disFuns);
    foreach ($disFuns_array as $key=>$value) 
    {
        if ($key!=0 && $key%6==0) {
            echo '<br />';
    }
    echo "$value&nbsp;&nbsp;";
}    
}
?>
    </td>
  </tr>
</table>

<a name="w_module" id="w_module" style="position:relative;top:-60px;"></a>
<!--Component information -->
<table>
  <tr><th colspan="4" ><i class="fa fa-cogs"></i> Components</th></tr>

  <tr>
    <td width="30%">FTP </td>
    <td width="20%"><?php echo isfun("ftp_login");?></td>
    <td width="30%">XML </td>
    <td width="20%"><?php echo isfun("xml_set_object");?></td>
  </tr>

  <tr>
    <td>Session </td>
    <td><?php echo isfun("session_start");?></td>
    <td>Socket </td>
    <td><?php echo isfun("socket_accept");?></td>
  </tr>

  <tr>
    <td>Calendar </td>
    <td><?php echo isfun('cal_days_in_month');?></td>
    <td>Allow URL Fopen </td>
    <td><?php echo show("allow_url_fopen");?></td>
  </tr>

  <tr>
    <td>GD Library </td>
    <td>
    <?php
        if(function_exists(gd_info)) {
            $gd_info = @gd_info();
            echo $gd_info["GD Version"];
        }else{echo '<font color="red"><i class="fa fa-times"></i></font>';}
    ?></td>
    <td>Zlib </td>
    <td><?php echo isfun("gzclose");?></td>
  </tr>

  <tr>
    <td>IMAP </td>
    <td><?php echo isfun("imap_close");?></td>
    <td>Jdtogregorian </td>
    <td><?php echo isfun("jdtogregorian");?></td>
  </tr>

  <tr>
    <td>Regular Expression </td>
    <td><?php echo isfun("preg_match");?></td>
    <td>WDDX </td>
    <td><?php echo isfun("wddx_add_vars");?></td>
  </tr>

  <tr>
    <td>iconv Encoding </td>
    <td><?php echo isfun("iconv");?></td>
    <td>mbstring </td>
    <td><?php echo isfun("mb_eregi");?></td>
  </tr>

  <tr>
    <td>BCMath </td>
    <td><?php echo isfun("bcadd");?></td>
    <td>LDAP </td>
    <td><?php echo isfun("ldap_close");?></td>
  </tr>

  <tr>
    <td>OpenSSL </td>
    <td><?php echo isfun("openssl_open");?></td>
    <td>Mhash </td>
    <td><?php echo isfun("mhash_count");?></td>
  </tr>
</table>

<a name="w_module_other" id="w_module_other" style="position:relative;top:-60px;"></a>
<!--Third party component information -->
<table>
  <tr><th colspan="4" ><i class="fa fa-cubes"></i> Third Party Components</th></tr>
  <tr>
    <td width="30%">Zend Version</td>
    <td width="20%"><?php $zend_version = zend_version();if(empty($zend_version)){echo "<font color=red><i class=\"fa fa-times\"></i></font>";}else{echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo $zend_version;}?></td>
    <td width="30%">
<?php
$PHP_VERSION = PHP_VERSION;
$PHP_VERSION = substr($PHP_VERSION,0,1);
if($PHP_VERSION > 2)
{
    echo "Zend Guard Loader";
}
else
{
    echo "Zend Optimizer";
}
?>
    </td>
    <td width="20%"><?php if($PHP_VERSION > 2){if(function_exists("zend_loader_version")){ echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo zend_loader_version();} else { echo "<font color=red><i class=\"fa fa-times\"></i></font>";}} else{if(function_exists('zend_optimizer_version')){ echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo zend_optimizer_version();}else{echo (get_cfg_var("zend_optimizer.optimization_level")||get_cfg_var("zend_extension_manager.optimizer_ts")||get_cfg_var("zend.ze1_compatibility_mode")||get_cfg_var("zend_extension_ts"))?'<font color=green><i class="fa fa-check"></i></font>':'<font color=red><i class="fa fa-times"></i></font>';}}?></td>
  </tr>

  <tr>
    <td>eAccelerator</td>
    <td><?php if((phpversion('eAccelerator'))!=''){echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo phpversion('eAccelerator');}else{ echo "<font color=red><i class=\"fa fa-times\"></i></font>";} ?></td>
    <td>ionCube Loader</td>
    <td><?php if(extension_loaded('ionCube Loader')){$ys = ioncube_loader_iversion();$gm = ".".(int)substr($ys,3,2);echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo ionCube_Loader_version().$gm;}else{echo "<font color=red><i class=\"fa fa-times\"></i></font>";}?></td>
  </tr>

  <tr>
    <td>XCache</td>
    <td><?php if((phpversion('XCache'))!=''){echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo phpversion('XCache');}else{ echo "<font color=red><i class=\"fa fa-times\"></i></font>";} ?></td>
    <td>Zend OPcache</td>
    <td><?php if(function_exists('opcache_get_configuration')){echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";$configuration=call_user_func('opcache_get_configuration'); echo $configuration['version']['version'];}else{ echo "<font color=red><i class=\"fa fa-times\"></i></font>";} ?></td>
  </tr>
</table>

<a name="w_db" id="w_db" style="position:relative;top:-60px;"></a>
<!--Database support -->
<table>
  <tr><th colspan="4"><i class="fa fa-database"></i> Database</th></tr>

  <tr>
    <td width="30%">MySQL </td>
    <td width="20%"><?php echo isfun("mysqli_connect"); ?>
    <?php $mysql_ver = getMySQLVersion(); if(!empty($mysql_ver)){ echo "&nbsp;&nbsp;Ver&nbsp;" . $mysql_ver;} ?>
    </td>
    <td width="30%">ODBC </td>
    <td width="20%"><?php echo isfun("odbc_close");?></td>
  </tr>

  <tr>
    <td>Oracle OCI8 </td>
    <td><?php echo isfun("oci_close");?></td>
    <td>SQL Server </td>
    <td><?php echo isfun("mssql_close");?></td>
  </tr>

  <tr>
    <td>dBASE </td>
    <td><?php echo isfun("dbase_close");?></td>
    <td>mSQL </td>
    <td><?php echo isfun("msql_close");?></td>
  </tr>

  <tr>
    <td>SQLite</td>
    <td><?php if(extension_loaded('sqlite3')) {$sqliteVer = SQLite3::version();echo '<font color=green><i class="fa fa-check"></i></font>　Ver ';echo $sqliteVer[versionString];}else {echo isfun("sqlite_close");if(isfun("sqlite_close") == '<font color="green">√</font>　') {echo "Ver ".@sqlite_libversion();}}?></td>
    <td>Hyperwave</td>
    <td><?php echo isfun("hw_close");?></td>
  </tr>

  <tr>
    <td>Postgre SQL </td>
    <td><?php echo isfun("pg_close"); ?></td>
    <td>Informix </td>
    <td><?php echo isfun("ifx_close");?></td>
  </tr>

  <tr>
    <td>DBA database </td>
    <td><?php echo isfun("dba_close");?></td>
    <td>DBM database </td>
    <td><?php echo isfun("dbmclose");?></td>
  </tr>

  <tr>
    <td>FilePro database </td>
    <td><?php echo isfun("filepro_fieldcount");?></td>
    <td>SyBase database </td>
    <td><?php echo isfun("sybase_close");?></td>
  </tr> 
</table>

<a name="w_performance" id="w_performance" style="position:relative;top:-60px;"></a>
<form action="<?php echo $_SERVER[PHP_SELF]."#w_performance";?>" method="post">
<!-- Server performance test -->
<table>
  <tr><th colspan="5"><i class="fa fa-tachometer"></i> Server performance Test</th></tr>

  <tr align="center">
    <td width="19%">Reference Object</td>
    <td width="17%">Int Test<br />(1+1 Count 3 Million)</td>
    <td width="17%">Float Test<br />(Pi times the square root of 3 million)</td>
    <td width="17%">I/O Test<br />(10K file read 10,000 times)</td>
    <td width="30%">CPU Information</td>
  </tr>

  <tr align="center">
    <td>Linode</td>
    <td>0.357 Second</td>
    <td>0.802 Second</td>
    <td>0.023 Second</td>
    <td align="left">4 x Xeon L5520 @ 2.27GHz</td>
  </tr> 

  <tr align="center">
    <td>PhotonVPS.com</td>
    <td>0.431 Second</td>
    <td>1.024 Second</td>
    <td>0.034 Second</td>
    <td align="left">8 x Xeon E5520 @ 2.27GHz</td>
  </tr>

  <tr align="center">
    <td>SpaceRich.com</td>
    <td>0.421 Second</td>
    <td>1.003 Second</td>
    <td>0.038 Second</td>
    <td align="left">4 x Core i7 920 @ 2.67GHz</td>
  </tr>

  <tr align="center">
    <td>RiZie.com</td>
    <td>0.521 Second</td>
    <td>1.559 Second</td>
    <td>0.054 Second</td>
    <td align="left">2 x Pentium4 3.00GHz</td>
  </tr>

  <tr align="center">
    <td>CitynetHost.com</a></td>
    <td>0.343 Second</td>
    <td>0.761 Second</td>
    <td>0.023 Second</td>
    <td align="left">2 x Core2Duo E4600 @ 2.40GHz</td>
  </tr>

  <tr align="center">
    <td>IXwebhosting.com</td>
    <td>0.535 Second</td>
    <td>1.607 Second</td>
    <td>0.058 Second</td>
    <td align="left">4 x Xeon E5530 @ 2.40GHz</td>
  </tr>

  <tr align="center">
    <td>This Server</td>
    <td><?php echo $valInt;?><br /><input class="btn" name="act" type="submit" value="Integer Test" /></td>
    <td><?php echo $valFloat;?><br /><input class="btn" name="act" type="submit" value="Floating Test" /></td>
    <td><?php echo $valIo;?><br /><input class="btn" name="act" type="submit" value="IO Test" /></td>
    <td></td>
  </tr>
</table>

<input type="hidden" name="pInt" value="<?php echo $valInt;?>" />
<input type="hidden" name="pFloat" value="<?php echo $valFloat;?>" />
<input type="hidden" name="pIo" value="<?php echo $valIo;?>" />

<a name="w_networkspeed" style="position:relative;top:-60px;"></a>
<!-- Network speed test-->
<table>
    <tr><th colspan="3"><i class="fa fa-cloud-upload"></i> Network Speed Test</th></tr>
  <tr>
    <td width="19%" align="center"><input name="act" type="submit" class="btn" value="Start Testing" />
    <br />
    2048k bytes sent to the client data
    </td>
    <td width="81%" align="center" >

  <table align="center" width="550" border="0" cellspacing="0" cellpadding="0" >
    <tr >
    <td height="15" width="50">Bandwidth</td>
    <td height="15" width="50">1M</td>
    <td height="15" width="50">2M</td>
    <td height="15" width="50">3M</td>
    <td height="15" width="50">4M</td>
    <td height="15" width="50">5M</td>
    <td height="15" width="50">6M</td>
    <td height="15" width="50">7M</td>
    <td height="15" width="50">8M</td>
    <td height="15" width="50">9M</td>
    <td height="15" width="50">10M</td>
    </tr>
   <tr>
    <td colspan="11" class="suduk" ><table align="center" width="550" border="0" cellspacing="0" cellpadding="0" height="8" class="suduk">
    <tr>
      <td class="sudu"  width="<?php 
    if(preg_match("/[^\d-., ]/",$speed))
        {
            echo "0";
        }
    else{
            echo 550*($speed/11000);
        } 
        ?>"></td>
      <td class="suduk" width="<?php 
    if(preg_match("/[^\d-., ]/",$speed))
        {
            echo "550";
        }
    else{
            echo 550-550*($speed/11000);
        } 
        ?>"></td>
    </tr>
    </table>
   </td>
  </tr>
  </table>
  <?php echo (isset($_GET['speed']))?"Download 2048KB Used <font color='#cc0000'>".$_GET['speed']."</font> Millisecond, Download Speed："."<font color='#cc0000'>".$speed."</font>"." kb/s":"<font color='#cc0000'>&nbsp;Not Test&nbsp;</font>" ?>
    </td>
  </tr>
</table>

<a name="w_MySQL" style="position:relative;top:-60px;"></a>
<!--MySQL database Connection detection -->
<table>
  <tr><th colspan="3"><i class="fa fa-link"></i> MySQL Database connection detection</th></tr>

  <tr>
    <td width="15%"></td>
    <td width="70%">
      Host：<input type="text" name="host" value="localhost" size="10" />
      Port：<input type="text" name="port" value="3306" size="10" />
      Username：<input type="text" name="login" size="10" />
      Password：<input type="password" name="password" size="10" />
    </td>
    <td width="15%">
      <input class="btn" type="submit" name="act" value="MySQL Test" />
    </td>
  </tr>
</table>
<?php
  if (isset($_POST['act']) && $_POST['act'] == 'MySQL Test') {
      if(class_exists("mysqli")) {
        $link = new mysqli($host,$login,$password,'information_schema',$port);
        if ($link){
            echo "<script>alert('Connect to the MySQL database success!')</script>";
        } else {
            echo "<script>alert('Connect to MySQL database failed!')</script>";
        }
    } else {
        echo "<script>alert('Server does not support MySQL database!')</script>";
    }
  }
?>

<a name="w_function" style="position:relative;top:-60px;"></a>
<!-- function Test-->
<table>

  <tr><th colspan="3"><i class="fa fa-code"></i> Function Test</th></tr>

  <tr>
    <td width="15%"></td>
    <td width="70%">
      Enter the function you want to test: 
      <input type="text" name="funName" size="50" />
    </td>
    <td width="15%">
      <input class="btn" type="submit" name="act" align="right" value="Function Test" />
    </td>
  </tr>

<?php
  if (isset($_POST['act']) && $_POST['act'] == 'Function Test') {
      echo "<script>alert('$funRe')</script>";
  }
?>
</table>

<a name="w_mail" style="position:relative;top:-60px;"></a>
<!--Mail Send Test-->
<table>
  <tr><th colspan="3"><i class="fa fa-envelope-o "></i> Mail Send Test</th></tr>
  <tr>
    <td width="15%"></td>
    <td width="70%">
      Please enter your email address to test: 
      <input type="text" name="mailAdd" size="50" />
    </td>
    <td width="15%">
    <input class="btn" type="submit" name="act" value="Mail Test" />
    </td>
  </tr>
<?php
  if (isset($_POST['act']) && $_POST['act'] == 'Mail Test') {
      echo "<script>alert('$mailRe')</script>";
  }
?>
</table>
</form>
    <table>
        <tr>
            <td class="w_foot"><a href="https://lamp.sh" target="_blank">Based on YaHei.net probe</a></td>
            <td class="w_foot"><?php $run_time = sprintf('%0.4f', microtime_float() - $time_start);?>Processed in <?php echo $run_time?> seconds. <?php echo memory_usage();?> memory usage.</td>
            <td class="w_foot"><a href="#w_top">Back to top</a></td>
        </tr>
    </table>
</div>
</body>
</html>
                                                                                                                                                                                                                                                                                                                                                                                                                                                                     lamp/conf/config.inc.php                                                                            000644  000765  000024  00000010535 13564465250 016771  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <?php
/* vim: set expandtab sw=4 ts=4 sts=4: */
/**
 * phpMyAdmin sample configuration, you can use it as base for
 * manual configuration. For easier setup you can use setup/
 *
 * All directives are explained in documentation in the doc/ folder
 * or at <https://docs.phpmyadmin.net/>.
 *
 * @package PhpMyAdmin
 */
 
/*
 * This is needed for cookie based authentication to encrypt password in
 * cookie. Needs to be 32 chars long.
 */
$cfg['blowfish_secret'] = 'c8e0ca9c430c714ffc1104394c02a053'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */

/*
 * Servers configuration
 */
$i = 0;

/*
 * First server
 */
$i++;
/* Authentication type */
$cfg['Servers'][$i]['auth_type'] = 'cookie';
/* Server parameters */
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['connect_type'] = 'tcp';
$cfg['Servers'][$i]['compress'] = false;
/* Select mysqli if your server has it */
$cfg['Servers'][$i]['extension'] = 'mysqli';
$cfg['Servers'][$i]['AllowNoPassword'] = false;

/*
 * phpMyAdmin configuration storage settings.
 */

/* User used to manipulate with storage */
// $cfg['Servers'][$i]['controlhost'] = '';
// $cfg['Servers'][$i]['controlport'] = '';
// $cfg['Servers'][$i]['controluser'] = 'pma';
// $cfg['Servers'][$i]['controlpass'] = 'pmapass';

/* Storage database and tables */
$cfg['Servers'][$i]['pmadb'] = 'phpmyadmin';
$cfg['Servers'][$i]['bookmarktable'] = 'pma__bookmark';
$cfg['Servers'][$i]['relation'] = 'pma__relation';
$cfg['Servers'][$i]['table_info'] = 'pma__table_info';
$cfg['Servers'][$i]['table_coords'] = 'pma__table_coords';
$cfg['Servers'][$i]['pdf_pages'] = 'pma__pdf_pages';
$cfg['Servers'][$i]['column_info'] = 'pma__column_info';
$cfg['Servers'][$i]['history'] = 'pma__history';
$cfg['Servers'][$i]['table_uiprefs'] = 'pma__table_uiprefs';
$cfg['Servers'][$i]['tracking'] = 'pma__tracking';
$cfg['Servers'][$i]['userconfig'] = 'pma__userconfig';
$cfg['Servers'][$i]['recent'] = 'pma__recent';
$cfg['Servers'][$i]['favorite'] = 'pma__favorite';
$cfg['Servers'][$i]['users'] = 'pma__users';
$cfg['Servers'][$i]['usergroups'] = 'pma__usergroups';
$cfg['Servers'][$i]['navigationhiding'] = 'pma__navigationhiding';
$cfg['Servers'][$i]['savedsearches'] = 'pma__savedsearches';
$cfg['Servers'][$i]['central_columns'] = 'pma__central_columns';
$cfg['Servers'][$i]['designer_settings'] = 'pma__designer_settings';
$cfg['Servers'][$i]['export_templates'] = 'pma__export_templates';
/*
 * End of servers configuration
 */

/*
 * Directories for saving/loading files from server
 */
$cfg['UploadDir'] = 'upload';
$cfg['SaveDir'] = 'save';

/**
 * Whether to display icons or text or both icons and text in table row
 * action segment. Value can be either of 'icons', 'text' or 'both'.
 */
//$cfg['RowActionType'] = 'both';

/**
 * Defines whether a user should be displayed a "show all (records)"
 * button in browse mode or not.
 * default = false
 */
//$cfg['ShowAll'] = true;

/**
 * Number of rows displayed when browsing a result set. If the result
 * set contains more rows, "Previous" and "Next".
 * default = 30
 */
//$cfg['MaxRows'] = 50;

/**
 * disallow editing of binary fields
 * valid values are:
 *   false    allow editing
 *   'blob'   allow editing except for BLOB fields
 *   'noblob' disallow editing except for BLOB fields
 *   'all'    disallow editing
 * default = blob
 */
//$cfg['ProtectBinary'] = 'false';

/**
 * Default language to use, if not browser-defined or user-defined
 * (you find all languages in the locale folder)
 * uncomment the desired line:
 * default = 'en'
 */
//$cfg['DefaultLang'] = 'en';
$cfg['DefaultLang'] = 'zh_CN';

/**
 * How many columns should be used for table display of a database?
 * (a value larger than 1 results in some information being hidden)
 * default = 1
 */
//$cfg['PropertiesNumColumns'] = 2;

/**
 * Set to true if you want DB-based query history.If false, this utilizes
 * JS-routines to display query history (lost by window close)
 *
 * This requires configuration storage enabled, see above.
 * default = false
 */
//$cfg['QueryHistoryDB'] = true;

/**
 * When using DB-based query history, how many entries should be kept?
 *
 * default = 25
 */
//$cfg['QueryHistoryMax'] = 100;

/**
 * Should error reporting be enabled for JavaScript errors
 *
 * default = 'ask'
 */
//$cfg['SendErrorReports'] = 'ask';

/*
 * You can find more configuration options in the documentation
 * in the doc/ folder or at <https://docs.phpmyadmin.net/>.
 */
?>
                                                                                                                                                                   lamp/conf/p_cn.php                                                                                  000644  000765  000024  00000164731 13564465250 015703  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         <?php
/* ----------------本探针基于YaHei.net探针------------------- */
error_reporting(0); //抑制所有错误信息
ini_set('display_errors','Off');
@header("content-Type: text/html; charset=utf-8"); //语言强制
ob_start();
date_default_timezone_set('Asia/Shanghai');//时区设置
$title = 'PHP探针';
$version = "v0.4.7"; //版本
define('HTTP_HOST', preg_replace('~^www\.~i', '', $_SERVER['HTTP_HOST']));
$time_start = microtime_float();
function memory_usage() 
{
    $memory = ( ! function_exists('memory_get_usage')) ? '0' : round(memory_get_usage()/1024/1024, 2).'MB';
    return $memory;
}

// 计时
function microtime_float() 
{
    $mtime = microtime();
    $mtime = explode(' ', $mtime);
    return $mtime[1] + $mtime[0];
}

//单位转换
function formatsize($size) 
{
    $danwei=array(' B ',' K ',' M ',' G ',' T ');
    $allsize=array();
    $i=0;
    for($i = 0; $i <5; $i++) 
    {
        if(floor($size/pow(1024,$i))==0){break;}
    }

    for($l = $i-1; $l >=0; $l--) 
    {
        $allsize1[$l]=floor($size/pow(1024,$l));
        $allsize[$l]=$allsize1[$l]-$allsize1[$l+1]*1024;
    }

    $len=count($allsize);

    for($j = $len-1; $j >=0; $j--) 
    {
        $fsize=$fsize.$allsize[$j].$danwei[$j];
    }    
    return $fsize;
}

function valid_email($str) 
{
    return ( ! preg_match("/^([a-z0-9\+_\-]+)(\.[a-z0-9\+_\-]+)*@([a-z0-9\-]+\.)+[a-z]{2,6}$/ix", $str)) ? FALSE : TRUE;
}

//检测PHP设置参数
function show($varName)
{
    switch($result = get_cfg_var($varName))
    {
        case 0:
            return '<font color="red"><i class="fa fa-times"></i></font>';
        break;
        case 1:
            return '<font color="green"><i class="fa fa-check"></i></font>';
        break;
        default:
            return $result;
        break;
    }
}

//保留服务器性能测试结果
$valInt = isset($_POST['pInt']) ? $_POST['pInt'] : "未测试";
$valFloat = isset($_POST['pFloat']) ? $_POST['pFloat'] : "未测试";
$valIo = isset($_POST['pIo']) ? $_POST['pIo'] : "未测试";

if (isset($_GET['act']) && $_GET['act'] == "phpinfo") 
{
    phpinfo();
    exit();
} 
elseif(isset($_POST['act']) && $_POST['act'] == "整型测试")
{
    $valInt = test_int();
} 
elseif(isset($_POST['act']) && $_POST['act'] == "浮点测试")
{
    $valFloat = test_float();
} 
elseif(isset($_POST['act']) && $_POST['act'] == "IO测试")
{
    $valIo = test_io();
} 
//网速测试-开始
elseif(isset($_POST['act']) && $_POST['act']=="开始测试")
{
?>
    <script language="javascript" type="text/javascript">
        var acd1;
        acd1 = new Date();
        acd1ok=acd1.getTime();
    </script>
    <?php
    for($i=1;$i<=204800;$i++)
    {
        echo "<!--34567890#########0#########0#########0#########0#########0#########0#########0#########012345-->";
    }
    ?>
    <script language="javascript" type="text/javascript">
        var acd2;
        acd2 = new Date();
        acd2ok=acd2.getTime();
        window.location = '?speed=' +(acd2ok-acd1ok)+'#w_networkspeed';
    </script>
<?php
}
elseif(isset($_GET['act']) && $_GET['act'] == "Function")
{
    $arr = get_defined_functions();
    Function php()
    {
    }
    echo "<pre>";
    Echo "这里显示系统所支持的所有函数,和自定义函数\n";
    print_r($arr);
    echo "</pre>";
    exit();
}
elseif(isset($_GET['act']) && $_GET['act'] == "disable_functions")
{
    $disFuns=get_cfg_var("disable_functions");
    if(empty($disFuns))
    {
        $arr = '<font color=red><i class="fa fa-times"></i></font>';
    }
    else
    { 
        $arr = $disFuns;
    }
    Function php()
    {
    }
    echo "<pre>";
    Echo "这里显示系统被禁用的函数\n";
    print_r($arr);
    echo "</pre>";
    exit();
}

//MySQL检测
if (isset($_POST['act']) && $_POST['act'] == 'MySQL检测')
{
    $host = isset($_POST['host']) ? trim($_POST['host']) : '';
    $port = isset($_POST['port']) ? (int) $_POST['port'] : '';
    $login = isset($_POST['login']) ? trim($_POST['login']) : '';
    $password = isset($_POST['password']) ? trim($_POST['password']) : '';
    $host = preg_match('~[^a-z0-9\-\.]+~i', $host) ? '' : $host;
    $port = intval($port) ? intval($port) : '';
    $login = preg_match('~[^a-z0-9\_\-]+~i', $login) ? '' : htmlspecialchars($login);
    $password = is_string($password) ? htmlspecialchars($password) : '';
}
elseif (isset($_POST['act']) && $_POST['act'] == '函数检测')
{
    $funRe = "函数".$_POST['funName']."支持状况检测结果：".isfun1($_POST['funName']);
} 
elseif (isset($_POST['act']) && $_POST['act'] == '邮件检测')
{
    $mailRe = "邮件发送检测结果：发送";
    if($_SERVER['SERVER_PORT']==80){$mailContent = "http://".$_SERVER['SERVER_NAME'].($_SERVER['PHP_SELF'] ? $_SERVER['PHP_SELF'] : $_SERVER['SCRIPT_NAME']);}
    else{$mailContent = "http://".$_SERVER['SERVER_NAME'].":".$_SERVER['SERVER_PORT'].($_SERVER['PHP_SELF'] ? $_SERVER['PHP_SELF'] : $_SERVER['SCRIPT_NAME']);}
    $mailRe .= (false !== @mail($_POST["mailAdd"], $mailContent, "This is a test mail!")) ? "完成":"失败";
}

//获取 MySQL 版本
function getMySQLVersion() {
    $output = shell_exec('mysql -V');
    if (empty($output)){
        return null;
    }
    preg_match('@[0-9]+\.[0-9]+\.[0-9]+@', $output, $version);
    return $version[0];
}

//网络速度测试
if(isset($_POST['act']) && $_POST['speed'])
{
    $speed=round(100/($_POST['speed']/2048),2);
}
elseif(isset($_GET['speed']) && $_GET['speed']=="0")
{
    $speed=6666.67;
}
elseif(isset($_GET['speed']) and $_GET['speed']>0)
{
    $speed=round(100/($_GET['speed']/2048),2); //下载速度：$speed kb/s
}
else
{
    $speed="<font color=\"red\">&nbsp;未探测&nbsp;</font>";
}    

// 检测函数支持
function isfun($funName = '')
{
    if (!$funName || trim($funName) == '' || preg_match('~[^a-z0-9\_]+~i', $funName, $tmp)) return '错误';
    return (false !== function_exists($funName)) ? '<font color="green"><i class="fa fa-check"></i></font>' : '<font color="red"><i class="fa fa-times"></i></font>';
}
function isfun1($funName = '')
{
    if (!$funName || trim($funName) == '' || preg_match('~[^a-z0-9\_]+~i', $funName, $tmp)) return '错误';
    return (false !== function_exists($funName)) ? '<i class="fa fa-check"></i>' : '<i class="fa fa-times"></i>';
}

//整数运算能力测试
function test_int()
{
    $timeStart = gettimeofday();
    for($i = 0; $i < 3000000; $i++)
    {
        $t = 1+1;
    }
    $timeEnd = gettimeofday();
    $time = ($timeEnd["usec"]-$timeStart["usec"])/1000000+$timeEnd["sec"]-$timeStart["sec"];
    $time = round($time, 3)."秒";
    return $time;
}

//浮点运算能力测试
function test_float()
{
    //得到圆周率值
    $t = pi();
    $timeStart = gettimeofday();
    for($i = 0; $i < 3000000; $i++)
    {
        //开平方
        sqrt($t);
    }

    $timeEnd = gettimeofday();
    $time = ($timeEnd["usec"]-$timeStart["usec"])/1000000+$timeEnd["sec"]-$timeStart["sec"];
    $time = round($time, 3)."秒";
    return $time;
}

//IO能力测试
function test_io()
{
    $fp = @fopen(PHPSELF, "r");
    $timeStart = gettimeofday();
    for($i = 0; $i < 10000; $i++) 
    {
        @fread($fp, 10240);
        @rewind($fp);
    }
    $timeEnd = gettimeofday();
    @fclose($fp);
    $time = ($timeEnd["usec"]-$timeStart["usec"])/1000000+$timeEnd["sec"]-$timeStart["sec"];
    $time = round($time, 3)."秒";
    return($time);
}

function GetCoreInformation() {$data = file('/proc/stat');$cores = array();foreach( $data as $line ) {if( preg_match('/^cpu[0-9]/', $line) ){$info = explode(' ', $line);$cores[]=array('user'=>$info[1],'nice'=>$info[2],'sys' => $info[3],'idle'=>$info[4],'iowait'=>$info[5],'irq' => $info[6],'softirq' => $info[7]);}}return $cores;}
function GetCpuPercentages($stat1, $stat2) {if(count($stat1)!==count($stat2)){return;}$cpus=array();for( $i = 0, $l = count($stat1); $i < $l; $i++) {    $dif = array();    $dif['user'] = $stat2[$i]['user'] - $stat1[$i]['user'];$dif['nice'] = $stat2[$i]['nice'] - $stat1[$i]['nice'];    $dif['sys'] = $stat2[$i]['sys'] - $stat1[$i]['sys'];$dif['idle'] = $stat2[$i]['idle'] - $stat1[$i]['idle'];$dif['iowait'] = $stat2[$i]['iowait'] - $stat1[$i]['iowait'];$dif['irq'] = $stat2[$i]['irq'] - $stat1[$i]['irq'];$dif['softirq'] = $stat2[$i]['softirq'] - $stat1[$i]['softirq'];$total = array_sum($dif);$cpu = array();foreach($dif as $x=>$y) $cpu[$x] = round($y / $total * 100, 2);$cpus['cpu' . $i] = $cpu;}return $cpus;}
$stat1 = GetCoreInformation();sleep(1);$stat2 = GetCoreInformation();$data = GetCpuPercentages($stat1, $stat2);
$cpu_show = $data['cpu0']['user']."%us,  ".$data['cpu0']['sys']."%sy,  ".$data['cpu0']['nice']."%ni, ".$data['cpu0']['idle']."%id,  ".$data['cpu0']['iowait']."%wa,  ".$data['cpu0']['irq']."%irq,  ".$data['cpu0']['softirq']."%softirq";
function makeImageUrl($title, $data) {$api='http://api.yahei.net/tz/cpu_show.php?id=';$url.=$data['user'].',';$url.=$data['nice'].',';$url.=$data['sys'].',';$url.=$data['idle'].',';$url.=$data['iowait'];$url.='&chdl=User|Nice|Sys|Idle|Iowait&chdlp=b&chl=';$url.=$data['user'].'%25|';$url.=$data['nice'].'%25|';$url.=$data['sys'].'%25|';$url.=$data['idle'].'%25|';$url.=$data['iowait'].'%25';$url.='&chtt=Core+'.$title;return $api.base64_encode($url);}
if($_GET['act'] == "cpu_percentage"){echo "<center><b><font face='Microsoft YaHei' color='#666666' size='3'>图片加载慢，请耐心等待！</font></b><br /><br />";foreach( $data as $k => $v ) {echo '<img src="' . makeImageUrl( $k, $v ) . '" style="width:360px;height:240px;border: #CCCCCC 1px solid;background: #FFFFFF;margin:5px;padding:5px;" />';}echo "</center>";exit();}

// 根据不同系统取得CPU相关信息
switch(PHP_OS)
{
    case "Linux":
        $sysReShow = (false !== ($sysInfo = sys_linux()))?"show":"none";
    break;
    case "FreeBSD":
        $sysReShow = (false !== ($sysInfo = sys_freebsd()))?"show":"none";
    break;
/*    
    case "WINNT":
        $sysReShow = (false !== ($sysInfo = sys_windows()))?"show":"none";
    break;
*/    
    default:
    break;
}

//linux系统探测
function sys_linux()
{
    // CPU
    if (false === ($str = @file("/proc/cpuinfo"))) return false;
    $str = implode("", $str);
    @preg_match_all("/model\s+name\s{0,}\:+\s{0,}([\w\s\)\(\@.-]+)([\r\n]+)/s", $str, $model);
    @preg_match_all("/cpu\s+MHz\s{0,}\:+\s{0,}([\d\.]+)[\r\n]+/", $str, $mhz);
    @preg_match_all("/cache\s+size\s{0,}\:+\s{0,}([\d\.]+\s{0,}[A-Z]+[\r\n]+)/", $str, $cache);
    @preg_match_all("/bogomips\s{0,}\:+\s{0,}([\d\.]+)[\r\n]+/", $str, $bogomips);
    if (false !== is_array($model[1]))
    {
        $res['cpu']['num'] = sizeof($model[1]);
        /*
        for($i = 0; $i < $res['cpu']['num']; $i++)
        {
            $res['cpu']['model'][] = $model[1][$i].'&nbsp;('.$mhz[1][$i].')';
            $res['cpu']['mhz'][] = $mhz[1][$i];
            $res['cpu']['cache'][] = $cache[1][$i];
            $res['cpu']['bogomips'][] = $bogomips[1][$i];
        }*/
        if($res['cpu']['num']==1)
            $x1 = '';
        else
            $x1 = ' ×'.$res['cpu']['num'];
        $mhz[1][0] = ' | 频率:'.$mhz[1][0];
        $cache[1][0] = ' | 二级缓存:'.$cache[1][0];
        $bogomips[1][0] = ' | Bogomips:'.$bogomips[1][0];
        $res['cpu']['model'][] = $model[1][0].$mhz[1][0].$cache[1][0].$bogomips[1][0].$x1;
        if (false !== is_array($res['cpu']['model'])) $res['cpu']['model'] = implode("<br />", $res['cpu']['model']);
        if (false !== is_array($res['cpu']['mhz'])) $res['cpu']['mhz'] = implode("<br />", $res['cpu']['mhz']);
        if (false !== is_array($res['cpu']['cache'])) $res['cpu']['cache'] = implode("<br />", $res['cpu']['cache']);
        if (false !== is_array($res['cpu']['bogomips'])) $res['cpu']['bogomips'] = implode("<br />", $res['cpu']['bogomips']);
    }

    // UPTIME
    if (false === ($str = @file("/proc/uptime"))) return false;
    $str = explode(" ", implode("", $str));
    $str = trim($str[0]);
    $min = $str / 60;
    $hours = $min / 60;
    $days = floor($hours / 24);
    $hours = floor($hours - ($days * 24));
    $min = floor($min - ($days * 60 * 24) - ($hours * 60));
    if ($days !== 0) $res['uptime'] = $days."天";
    if ($hours !== 0) $res['uptime'] .= $hours."小时";
    $res['uptime'] .= $min."分钟";

    // MEMORY
    if (false === ($str = @file("/proc/meminfo"))) return false;
    $str = implode("", $str);
    preg_match_all("/MemTotal\s{0,}\:+\s{0,}([\d\.]+).+?MemFree\s{0,}\:+\s{0,}([\d\.]+).+?Cached\s{0,}\:+\s{0,}([\d\.]+).+?SwapTotal\s{0,}\:+\s{0,}([\d\.]+).+?SwapFree\s{0,}\:+\s{0,}([\d\.]+)/s", $str, $buf);
    preg_match_all("/Buffers\s{0,}\:+\s{0,}([\d\.]+)/s", $str, $buffers);
    $res['memTotal'] = round($buf[1][0]/1024, 2);
    $res['memFree'] = round($buf[2][0]/1024, 2);
    $res['memBuffers'] = round($buffers[1][0]/1024, 2);
    $res['memCached'] = round($buf[3][0]/1024, 2);
    $res['memUsed'] = $res['memTotal']-$res['memFree'];
    $res['memPercent'] = (floatval($res['memTotal'])!=0)?round($res['memUsed']/$res['memTotal']*100,2):0;
    $res['memRealUsed'] = $res['memTotal'] - $res['memFree'] - $res['memCached'] - $res['memBuffers']; //真实内存使用
    $res['memRealFree'] = $res['memTotal'] - $res['memRealUsed']; //真实空闲
    $res['memRealPercent'] = (floatval($res['memTotal'])!=0)?round($res['memRealUsed']/$res['memTotal']*100,2):0; //真实内存使用率
    $res['memCachedPercent'] = (floatval($res['memCached'])!=0)?round($res['memCached']/$res['memTotal']*100,2):0; //Cached内存使用率
    $res['swapTotal'] = round($buf[4][0]/1024, 2);
    $res['swapFree'] = round($buf[5][0]/1024, 2);
    $res['swapUsed'] = round($res['swapTotal']-$res['swapFree'], 2);
    $res['swapPercent'] = (floatval($res['swapTotal'])!=0)?round($res['swapUsed']/$res['swapTotal']*100,2):0;

    // LOAD AVG
    if (false === ($str = @file("/proc/loadavg"))) return false;
    $str = explode(" ", implode("", $str));
    $str = array_chunk($str, 4);
    $res['loadAvg'] = implode(" ", $str[0]);

    return $res;
}

//FreeBSD系统探测
function sys_freebsd()
{
    //CPU
    if (false === ($res['cpu']['num'] = get_key("hw.ncpu"))) return false;
    $res['cpu']['model'] = get_key("hw.model");
    //LOAD AVG
    if (false === ($res['loadAvg'] = get_key("vm.loadavg"))) return false;
    //UPTIME
    if (false === ($buf = get_key("kern.boottime"))) return false;
    $buf = explode(' ', $buf);
    $sys_ticks = time() - intval($buf[3]);
    $min = $sys_ticks / 60;
    $hours = $min / 60;
    $days = floor($hours / 24);
    $hours = floor($hours - ($days * 24));
    $min = floor($min - ($days * 60 * 24) - ($hours * 60));
    if ($days !== 0) $res['uptime'] = $days."天";
    if ($hours !== 0) $res['uptime'] .= $hours."小时";
    $res['uptime'] .= $min."分钟";

    //MEMORY
    if (false === ($buf = get_key("hw.physmem"))) return false;
    $res['memTotal'] = round($buf/1024/1024, 2);
    $str = get_key("vm.vmtotal");
    preg_match_all("/\nVirtual Memory[\:\s]*\(Total[\:\s]*([\d]+)K[\,\s]*Active[\:\s]*([\d]+)K\)\n/i", $str, $buff, PREG_SET_ORDER);
    preg_match_all("/\nReal Memory[\:\s]*\(Total[\:\s]*([\d]+)K[\,\s]*Active[\:\s]*([\d]+)K\)\n/i", $str, $buf, PREG_SET_ORDER);
    $res['memRealUsed'] = round($buf[0][2]/1024, 2);
    $res['memCached'] = round($buff[0][2]/1024, 2);
    $res['memUsed'] = round($buf[0][1]/1024, 2) + $res['memCached'];
    $res['memFree'] = $res['memTotal'] - $res['memUsed'];
    $res['memPercent'] = (floatval($res['memTotal'])!=0)?round($res['memUsed']/$res['memTotal']*100,2):0;
    $res['memRealPercent'] = (floatval($res['memTotal'])!=0)?round($res['memRealUsed']/$res['memTotal']*100,2):0;
    return $res;
}

//取得参数值 FreeBSD
function get_key($keyName)
{
    return do_command('sysctl', "-n $keyName");
}

//确定执行文件位置 FreeBSD
function find_command($commandName)
{
    $path = array('/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin');
    foreach($path as $p) 
    {
        if (@is_executable("$p/$commandName")) return "$p/$commandName";
    }
    return false;
}

//执行系统命令 FreeBSD
function do_command($commandName, $args)
{
    $buffer = "";
    if (false === ($command = find_command($commandName))) return false;
    if ($fp = @popen("$command $args", 'r')) 
    {
        while (!@feof($fp))
        {
            $buffer .= @fgets($fp, 4096);
        }
        return trim($buffer);
    }
    return false;
}

//windows系统探测
function sys_windows()
{
    if (PHP_VERSION >= 5)
    {
        $objLocator = new COM("WbemScripting.SWbemLocator");
        $wmi = $objLocator->ConnectServer();
        $prop = $wmi->get("Win32_PnPEntity");
    }
    else
    {
        return false;
    }

    //CPU
    $cpuinfo = GetWMI($wmi,"Win32_Processor", array("Name","L2CacheSize","NumberOfCores"));
    $res['cpu']['num'] = $cpuinfo[0]['NumberOfCores'];
    if (null == $res['cpu']['num']) 
    {
        $res['cpu']['num'] = 1;
    }
    /*
    for ($i=0;$i<$res['cpu']['num'];$i++)
    {
        $res['cpu']['model'] .= $cpuinfo[0]['Name']."<br />";
        $res['cpu']['cache'] .= $cpuinfo[0]['L2CacheSize']."<br />";
    }*/
    $cpuinfo[0]['L2CacheSize'] = ' ('.$cpuinfo[0]['L2CacheSize'].')';
    if($res['cpu']['num']==1)
        $x1 = '';
    else
        $x1 = ' ×'.$res['cpu']['num'];
    $res['cpu']['model'] = $cpuinfo[0]['Name'].$cpuinfo[0]['L2CacheSize'].$x1;

    // SYSINFO
    $sysinfo = GetWMI($wmi,"Win32_OperatingSystem", array('LastBootUpTime','TotalVisibleMemorySize','FreePhysicalMemory','Caption','CSDVersion','SerialNumber','InstallDate'));
    $sysinfo[0]['Caption']=iconv('GBK', 'UTF-8',$sysinfo[0]['Caption']);
    $sysinfo[0]['CSDVersion']=iconv('GBK', 'UTF-8',$sysinfo[0]['CSDVersion']);
    $res['win_n'] = $sysinfo[0]['Caption']." ".$sysinfo[0]['CSDVersion']." 序列号:{$sysinfo[0]['SerialNumber']} 于".date('Y年m月d日H:i:s',strtotime(substr($sysinfo[0]['InstallDate'],0,14)))."安装";

    //UPTIME
    $res['uptime'] = $sysinfo[0]['LastBootUpTime'];
    $sys_ticks = 3600*8 + time() - strtotime(substr($res['uptime'],0,14));
    $min = $sys_ticks / 60;
    $hours = $min / 60;
    $days = floor($hours / 24);
    $hours = floor($hours - ($days * 24));
    $min = floor($min - ($days * 60 * 24) - ($hours * 60));
    if ($days !== 0) $res['uptime'] = $days."天";
    if ($hours !== 0) $res['uptime'] .= $hours."小时";
    $res['uptime'] .= $min."分钟";

    //MEMORY
    $res['memTotal'] = round($sysinfo[0]['TotalVisibleMemorySize']/1024,2);
    $res['memFree'] = round($sysinfo[0]['FreePhysicalMemory']/1024,2);
    $res['memUsed'] = $res['memTotal']-$res['memFree'];    //上面两行已经除以1024,这行不用再除了
    $res['memPercent'] = round($res['memUsed'] / $res['memTotal']*100,2);
    $swapinfo = GetWMI($wmi,"Win32_PageFileUsage", array('AllocatedBaseSize','CurrentUsage'));

    // LoadPercentage
    $loadinfo = GetWMI($wmi,"Win32_Processor", array("LoadPercentage"));
    $res['loadAvg'] = $loadinfo[0]['LoadPercentage'];
    
    return $res;
}

function GetWMI($wmi,$strClass, $strValue = array())
{
    $arrData = array();
    $objWEBM = $wmi->Get($strClass);
    $arrProp = $objWEBM->Properties_;
    $arrWEBMCol = $objWEBM->Instances_();
    foreach($arrWEBMCol as $objItem) 
    {
        @reset($arrProp);
        $arrInstance = array();
        foreach($arrProp as $propItem) 
        {
            eval("\$value = \$objItem->" . $propItem->Name . ";");
            if (empty($strValue)) 
            {
                $arrInstance[$propItem->Name] = trim($value);
            } 
            else
            {
                if (in_array($propItem->Name, $strValue)) 
                {
                    $arrInstance[$propItem->Name] = trim($value);
                }
            }
        }
        $arrData[] = $arrInstance;
    }

    return $arrData;
}

//比例条
function bar($percent)
{
?>
    <div class="bar"><div class="barli" style="width:<?php echo $percent?>%">&nbsp;</div></div>
<?php
}

$uptime = $sysInfo['uptime']; //在线时间
$stime = date('Y-m-d H:i:s'); //系统当前时间

//硬盘
$dt = round(@disk_total_space(".")/(1024*1024*1024),3); //总
$df = round(@disk_free_space(".")/(1024*1024*1024),3); //可用
$du = $dt-$df; //已用
$hdPercent = (floatval($dt)!=0)?round($du/$dt*100,2):0;
$load = $sysInfo['loadAvg'];    //系统负载

//判断内存如果小于1G，就显示M，否则显示G单位
if($sysInfo['memTotal']<1024)
{
    $memTotal = $sysInfo['memTotal']." M";
    $mt = $sysInfo['memTotal']." M";
    $mu = $sysInfo['memUsed']." M";
    $mf = $sysInfo['memFree']." M";
    $mc = $sysInfo['memCached']." M";    //cache化内存
    $mb = $sysInfo['memBuffers']." M";    //缓冲
    $st = $sysInfo['swapTotal']." M";
    $su = $sysInfo['swapUsed']." M";
    $sf = $sysInfo['swapFree']." M";
    $swapPercent = $sysInfo['swapPercent'];
    $memRealUsed = $sysInfo['memRealUsed']." M"; //真实内存使用
    $memRealFree = $sysInfo['memRealFree']." M"; //真实内存空闲
    $memRealPercent = $sysInfo['memRealPercent']; //真实内存使用比率
    $memPercent = $sysInfo['memPercent']; //内存总使用率
    $memCachedPercent = $sysInfo['memCachedPercent']; //cache内存使用率
}
else
{
    $memTotal = round($sysInfo['memTotal']/1024,3)." G";
    $mt = round($sysInfo['memTotal']/1024,3)." G";
    $mu = round($sysInfo['memUsed']/1024,3)." G";
    $mf = round($sysInfo['memFree']/1024,3)." G";
    $mc = round($sysInfo['memCached']/1024,3)." G";
    $mb = round($sysInfo['memBuffers']/1024,3)." G";
    $st = round($sysInfo['swapTotal']/1024,3)." G";
    $su = round($sysInfo['swapUsed']/1024,3)." G";
    $sf = round($sysInfo['swapFree']/1024,3)." G";
    $swapPercent = $sysInfo['swapPercent'];
    $memRealUsed = round($sysInfo['memRealUsed']/1024,3)." G"; //真实内存使用
    $memRealFree = round($sysInfo['memRealFree']/1024,3)." G"; //真实内存空闲
    $memRealPercent = $sysInfo['memRealPercent']; //真实内存使用比率
    $memPercent = $sysInfo['memPercent']; //内存总使用率
    $memCachedPercent = $sysInfo['memCachedPercent']; //cache内存使用率
}

//网卡流量
$strs = @file("/proc/net/dev"); 

for ($i = 2; $i < count($strs); $i++ )
{
    preg_match_all( "/([^\s]+):[\s]{0,}(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/", $strs[$i], $info );
    $NetOutSpeed[$i] = $info[10][0];
    $NetInputSpeed[$i] = $info[2][0];
    $NetInput[$i] = formatsize($info[2][0]);
    $NetOut[$i]  = formatsize($info[10][0]);
}

//ajax调用实时刷新
if ($_GET['act'] == "rt")
{
    $arr=array('useSpace'=>"$du",'freeSpace'=>"$df",'hdPercent'=>"$hdPercent",'barhdPercent'=>"$hdPercent%",'TotalMemory'=>"$mt",'UsedMemory'=>"$mu",'FreeMemory'=>"$mf",'CachedMemory'=>"$mc",'Buffers'=>"$mb",'TotalSwap'=>"$st",'swapUsed'=>"$su",'swapFree'=>"$sf",'loadAvg'=>"$load",'uptime'=>"$uptime",'freetime'=>"$freetime",'bjtime'=>"$bjtime",'stime'=>"$stime",'memRealPercent'=>"$memRealPercent",'memRealUsed'=>"$memRealUsed",'memRealFree'=>"$memRealFree",'memPercent'=>"$memPercent%",'memCachedPercent'=>"$memCachedPercent",'barmemCachedPercent'=>"$memCachedPercent%",'swapPercent'=>"$swapPercent",'barmemRealPercent'=>"$memRealPercent%",'barswapPercent'=>"$swapPercent%",'NetOut2'=>"$NetOut[2]",'NetOut3'=>"$NetOut[3]",'NetOut4'=>"$NetOut[4]",'NetOut5'=>"$NetOut[5]",'NetOut6'=>"$NetOut[6]",'NetOut7'=>"$NetOut[7]",'NetOut8'=>"$NetOut[8]",'NetOut9'=>"$NetOut[9]",'NetOut10'=>"$NetOut[10]",'NetInput2'=>"$NetInput[2]",'NetInput3'=>"$NetInput[3]",'NetInput4'=>"$NetInput[4]",'NetInput5'=>"$NetInput[5]",'NetInput6'=>"$NetInput[6]",'NetInput7'=>"$NetInput[7]",'NetInput8'=>"$NetInput[8]",'NetInput9'=>"$NetInput[9]",'NetInput10'=>"$NetInput[10]",'NetOutSpeed2'=>"$NetOutSpeed[2]",'NetOutSpeed3'=>"$NetOutSpeed[3]",'NetOutSpeed4'=>"$NetOutSpeed[4]",'NetOutSpeed5'=>"$NetOutSpeed[5]",'NetInputSpeed2'=>"$NetInputSpeed[2]",'NetInputSpeed3'=>"$NetInputSpeed[3]",'NetInputSpeed4'=>"$NetInputSpeed[4]",'NetInputSpeed5'=>"$NetInputSpeed[5]");
    $jarr=json_encode($arr); 
    $_GET['callback'] = htmlspecialchars($_GET['callback']);
    echo $_GET['callback'],'(',$jarr,')';
    exit;
}
?>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title><?php echo $title; ?></title>
<meta http-equiv="X-UA-Compatible" content="IE=EmulateIE7" />
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<link href="//cdn.bootcss.com/font-awesome/4.5.0/css/font-awesome.min.css" rel="stylesheet">
<link href="data:image/png;base64,Qk02AwAAAAAAADYAAAAoAAAAEAAAABAAAAABABgAAAAAAAADAADEDgAAxA4AAAAAAAAAAAAAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICA19fX19fX19fXwICAwICAwICAwICAwICAwICAwICA19fX19fX19fXwICAwICAwICA19fXAAAA19fXwICAwICAwICAwICAwICAwICAwICA19fXAAAA19fXwICAwICAwICA19fXAAAA19fX19fXwICAwICA19fXwICAwICA19fX19fXAAAA19fX19fXwICAwICA19fXAAAAAAAAAAAA19fX19fXAAAA19fX19fXAAAA19fXAAAAAAAAAAAA19fX19fX19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fX19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fX19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fXAAAA19fX19fXAAAA19fX19fXAAAAAAAAAAAA19fX19fXAAAAAAAAAAAA19fX19fXAAAAAAAAAAAA19fX19fXwICA19fX19fX19fXwICA19fXAAAA19fX19fXwICAwICA19fX19fX19fXwICAwICAwICAwICAwICAwICAwICA19fXAAAA19fXwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICA19fX19fX19fXwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICAwICA" type="image/x-icon" rel="icon" />
<style type="text/css">
<!--
body{margin: 0 auto; padding: 0; background-color:#eee;font-size:14px;font-family: Noto Sans CJK SC,Microsoft Yahei,Hiragino Sans GB,WenQuanYi Micro Hei,sans-serif;}
a,input,button{outline: none !important;-webkit-appearance: none;border-radius: 0;}
button::-moz-focus-inner,input::-moz-focus-inner{border-color:transparent !important;}
:focus {border: none;outline: 0;}
h1 {font-size: 26px; padding: 0; margin: 0; color: #333333;}
h1 small {font-size: 11px; font-family: Tahoma; font-weight: bold; }
a{color: #666; text-decoration:none;}
a.black{color: #000000; text-decoration:none;}
table{width:100%;clear:both;padding: 0; margin: 0 0 18px;border-collapse:collapse; border-spacing: 0;box-shadow: 1px 1px 4px #999;}
th{padding: 6px 12px; font-weight:bold;background:#9191c4;color:#000;border:1px solid #9191c4; text-align:left;font-size:16px;border-bottom: 0px;font-weight: normal;}
tr{padding: 0; background:#FFFFFF;}
td{padding: 3px 6px; border:1px solid #CCCCCC;}
#nav{height:48px;font-size: 15px;background-color:#447;color:#fff !important;position:fixed;top:0px;width:100%;cursor: default;}
.w_logo{height:29px; padding:9px 24px;display: inline-block;font-size: 18px;float:left;}
.w_top{height:24px;color:#fff;font-size: 15px;display: inline-block;padding:12px 24px;transition: background-color 0.2s;float:left;cursor: default;}
.w_top:hover{background:#0C2136;}
.w_foot{height:25px;text-align:center; background:#dedede;}
input{padding: 2px; background: #FFFFFF;border:1px solid #888;font-size:12px; color:#000;}
input:focus{border:1px solid #666;}
input.btn{line-height: 20px; padding: 6px 15px; color:#fff; background: #447; font-size:12px; border:0;transition: background-color 0.2s;box-shadow: 0 0 1px #888888;}
input.btn:hover{background:#558;}
.bar {border:0; background:#ddd; height:15px; font-size:2px; width:89%; margin:2px 0 5px 0;overflow: hidden;}
.barli_red{background:#d9534f; height:15px; margin:0px; padding:0;}
.barli_blue{background:#337ab7; height:15px; margin:0px; padding:0;}
.barli_green{background:#5cb85c; height:15px; margin:0px; padding:0;}
.barli_orange{background:#f0ad4e; height:15px; margin:0px; padding:0;}
.barli_blue2{background:#5bc0de; height:15px; margin:0px; padding:0;}
#page {max-width: 1080px; padding: 0 auto; margin: 80px auto 0; text-align: left;}
#header{position:relative; padding:5px;}
.w_small{font-family: Courier New;}
.w_number{color: #177BBE;}
.sudu {padding: 0; background:#5dafd1; }
.suduk { margin:0px; padding:0;}
.resYes{}
.resNo{color: #FF0000;}
.word{word-break:break-all;}
@media screen and (max-width: 1180px){
	#page {margin: 80px 50px 0; }
}
-->
</style>
<script language="JavaScript" type="text/javascript" src="./jquery.js"></script>
<script type="text/javascript"> 
<!--
$(document).ready(function(){getJSONData();});
var OutSpeed2=<?php echo floor($NetOutSpeed[2]) ?>;
var OutSpeed3=<?php echo floor($NetOutSpeed[3]) ?>;
var OutSpeed4=<?php echo floor($NetOutSpeed[4]) ?>;
var OutSpeed5=<?php echo floor($NetOutSpeed[5]) ?>;
var InputSpeed2=<?php echo floor($NetInputSpeed[2]) ?>;
var InputSpeed3=<?php echo floor($NetInputSpeed[3]) ?>;
var InputSpeed4=<?php echo floor($NetInputSpeed[4]) ?>;
var InputSpeed5=<?php echo floor($NetInputSpeed[5]) ?>;

function getJSONData()
{
    setTimeout("getJSONData()", 1000);
    $.getJSON('?act=rt&callback=?', displayData);
}
function ForDight(Dight,How)
{ 
  if (Dight<0){
      var Last=0+"B/s";
  }else if (Dight<1024){
      var Last=Math.round(Dight*Math.pow(10,How))/Math.pow(10,How)+"B/s";
  }else if (Dight<1048576){
      Dight=Dight/1024;
      var Last=Math.round(Dight*Math.pow(10,How))/Math.pow(10,How)+"K/s";
  }else{
      Dight=Dight/1048576;
      var Last=Math.round(Dight*Math.pow(10,How))/Math.pow(10,How)+"M/s";
  }
    return Last; 
}

function displayData(dataJSON)
{
    $("#useSpace").html(dataJSON.useSpace);
    $("#freeSpace").html(dataJSON.freeSpace);
    $("#hdPercent").html(dataJSON.hdPercent);
    $("#barhdPercent").width(dataJSON.barhdPercent);
    $("#TotalMemory").html(dataJSON.TotalMemory);
    $("#UsedMemory").html(dataJSON.UsedMemory);
    $("#FreeMemory").html(dataJSON.FreeMemory);
    $("#CachedMemory").html(dataJSON.CachedMemory);
    $("#Buffers").html(dataJSON.Buffers);
    $("#TotalSwap").html(dataJSON.TotalSwap);
    $("#swapUsed").html(dataJSON.swapUsed);
    $("#swapFree").html(dataJSON.swapFree);
    $("#swapPercent").html(dataJSON.swapPercent);
    $("#loadAvg").html(dataJSON.loadAvg);
    $("#uptime").html(dataJSON.uptime);
    $("#freetime").html(dataJSON.freetime);
    $("#stime").html(dataJSON.stime);
    $("#bjtime").html(dataJSON.bjtime);
    $("#memRealUsed").html(dataJSON.memRealUsed);
    $("#memRealFree").html(dataJSON.memRealFree);
    $("#memRealPercent").html(dataJSON.memRealPercent);
    $("#memPercent").html(dataJSON.memPercent);
    $("#barmemPercent").width(dataJSON.memPercent);
    $("#barmemRealPercent").width(dataJSON.barmemRealPercent);
    $("#memCachedPercent").html(dataJSON.memCachedPercent);
    $("#barmemCachedPercent").width(dataJSON.barmemCachedPercent);
    $("#barswapPercent").width(dataJSON.barswapPercent);
    $("#NetOut2").html(dataJSON.NetOut2);
    $("#NetOut3").html(dataJSON.NetOut3);
    $("#NetOut4").html(dataJSON.NetOut4);
    $("#NetOut5").html(dataJSON.NetOut5);
    $("#NetOut6").html(dataJSON.NetOut6);
    $("#NetOut7").html(dataJSON.NetOut7);
    $("#NetOut8").html(dataJSON.NetOut8);
    $("#NetOut9").html(dataJSON.NetOut9);
    $("#NetOut10").html(dataJSON.NetOut10);
    $("#NetInput2").html(dataJSON.NetInput2);
    $("#NetInput3").html(dataJSON.NetInput3);
    $("#NetInput4").html(dataJSON.NetInput4);
    $("#NetInput5").html(dataJSON.NetInput5);
    $("#NetInput6").html(dataJSON.NetInput6);
    $("#NetInput7").html(dataJSON.NetInput7);
    $("#NetInput8").html(dataJSON.NetInput8);
    $("#NetInput9").html(dataJSON.NetInput9);
    $("#NetInput10").html(dataJSON.NetInput10);    
    $("#NetOutSpeed2").html(ForDight((dataJSON.NetOutSpeed2-OutSpeed2),3));
    OutSpeed2=dataJSON.NetOutSpeed2;
    $("#NetOutSpeed3").html(ForDight((dataJSON.NetOutSpeed3-OutSpeed3),3));
    OutSpeed3=dataJSON.NetOutSpeed3;
    $("#NetOutSpeed4").html(ForDight((dataJSON.NetOutSpeed4-OutSpeed4),3));
    OutSpeed4=dataJSON.NetOutSpeed4;
    $("#NetOutSpeed5").html(ForDight((dataJSON.NetOutSpeed5-OutSpeed5),3));
    OutSpeed5=dataJSON.NetOutSpeed5;
    $("#NetInputSpeed2").html(ForDight((dataJSON.NetInputSpeed2-InputSpeed2),3));
    InputSpeed2=dataJSON.NetInputSpeed2;
    $("#NetInputSpeed3").html(ForDight((dataJSON.NetInputSpeed3-InputSpeed3),3));
    InputSpeed3=dataJSON.NetInputSpeed3;
    $("#NetInputSpeed4").html(ForDight((dataJSON.NetInputSpeed4-InputSpeed4),3));
    InputSpeed4=dataJSON.NetInputSpeed4;
    $("#NetInputSpeed5").html(ForDight((dataJSON.NetInputSpeed5-InputSpeed5),3));
    InputSpeed5=dataJSON.NetInputSpeed5;
}
-->
</script>
</head>

<body>
<a name="w_top"></a>
<div id="nav">
    <div style="display: inline-block">
        <div class="w_logo"><span>PHP探针</span></div>
    </div>
    <div style="display: inline-block">
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: 0 }, 200);"><i class="fa fa-tasks"></i> 服务器信息</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_php').offset().top }, 200);"><i class="fa fa-tags"></i> PHP参数</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_module').offset().top }, 200);"><i class="fa fa-cogs"></i> 组件支持</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_module_other').offset().top }, 200);"><i class="fa fa-cubes"></i> 第三方组件</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_db').offset().top }, 200);"><i class="fa fa-database"></i> 数据库支持</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_performance').offset().top }, 200);"><i class="fa fa-tachometer"></i> 性能检测</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_performance').offset().top }, 200);"><i class="fa fa-cloud-upload"></i> 网络测试</a>
        <a class="w_top" onclick="$('body,html').animate({ scrollTop: $('#w_performance').offset().top }, 200);"><i class="fa fa-link"></i> MySQL连接检测</a>
    </div>
</div>
<div id="page">
<!--服务器相关参数-->
<table>
  <tr><th colspan="4"><i class="fa fa-tasks"></i> 服务器参数</th></tr>
  <tr>
    <td>服务器域名/IP地址</td>
    <td colspan="3"><?php echo @get_current_user();?> - <?php echo $_SERVER['SERVER_NAME'];?>(<?php if('/'==DIRECTORY_SEPARATOR){echo $_SERVER['SERVER_ADDR'];}else{echo @gethostbyname($_SERVER['SERVER_NAME']);} ?>)&nbsp;&nbsp;你的 IP 地址是：<?php echo @$_SERVER['REMOTE_ADDR'];?></td>
  </tr>

  <tr>
    <td>服务器标识</td>

    <td colspan="3"><?php echo php_uname();?></td>

  </tr>

  <tr>
    <td width="13%">服务器操作系统</td>
    <td width="40%"><?php $os = explode(" ", php_uname()); echo $os[0];?> &nbsp;内核版本：<?php if('/'==DIRECTORY_SEPARATOR){echo $os[2];}else{echo $os[1];} ?></td>
    <td width="13%">服务器解译引擎</td>
    <td width="34%"><?php echo $_SERVER['SERVER_SOFTWARE'];?></td>
  </tr>

  <tr>
    <td>服务器语言</td>
    <td><?php echo getenv("HTTP_ACCEPT_LANGUAGE");?></td>
    <td>服务器端口</td>
    <td><?php echo $_SERVER['SERVER_PORT'];?></td>
  </tr>

  <tr>
      <td>服务器主机名</td>
      <td><?php if('/'==DIRECTORY_SEPARATOR ){echo $os[1];}else{echo $os[2];} ?></td>
      <td>绝对路径</td>
      <td><?php echo $_SERVER['DOCUMENT_ROOT']?str_replace('\\','/',$_SERVER['DOCUMENT_ROOT']):str_replace('\\','/',dirname(__FILE__));?></td>
    </tr>

  <tr>
      <td>管理员邮箱</td>
      <td><?php if(isset($_SERVER['SERVER_ADMIN'])) echo $_SERVER['SERVER_ADMIN'];?></td>
        <td>探针路径</td>
        <td><?php echo str_replace('\\','/',__FILE__)?str_replace('\\','/',__FILE__):$_SERVER['SCRIPT_FILENAME'];?></td>
    </tr>    
</table>

<?if("show"==$sysReShow){?>
<table>
  <tr><th colspan="6"><i class="fa fa-area-chart"></i> 服务器实时数据</th></tr>

  <tr>
    <td width="13%" >服务器当前时间</td>
    <td width="40%" ><span id="stime"><?php echo $stime;?></span></td>
    <td width="13%" >服务器已运行时间</td>
    <td width="34%" colspan="3"><span id="uptime"><?php echo $uptime;?></span></td>
  </tr>
  <tr>
    <td width="13%">CPU 型号 [<?php echo $sysInfo['cpu']['num'];?>核]</td>
    <td width="87%" colspan="5"><?php echo $sysInfo['cpu']['model'];?></td>
  </tr>
  <tr>
    <td>CPU使用状况</td>
    <td colspan="5"><?php if('/'==DIRECTORY_SEPARATOR){echo $cpu_show." | <a href='".$phpSelf."?act=cpu_percentage' target='_blank' class='static'>查看图表 <i class=\"fa fa-external-link\"></i> </a>";}else{echo "暂时只支持Linux系统";}?>
    </td>
  </tr>
  <tr>
    <td>硬盘使用状况</td>
    <td colspan="5">
        总空间 <?php echo $dt;?>&nbsp;G，
        已用 <font color='#333333'><span id="useSpace"><?php echo $du;?></span></font>&nbsp;G，
        空闲 <font color='#333333'><span id="freeSpace"><?php echo $df;?></span></font>&nbsp;G，
        使用率 <span id="hdPercent"><?php echo $hdPercent;?></span>%
        <div class="bar"><div id="barhdPercent" class="barli_orange" style="width:<?php echo $hdPercent;?>%" >&nbsp;</div> </div>
    </td>
  </tr>
  <tr>
        <td>内存使用状况</td>
        <td colspan="5">
<?php
$tmp = array(
    'memTotal', 'memUsed', 'memFree', 'memPercent',
    'memCached', 'memRealPercent',
    'swapTotal', 'swapUsed', 'swapFree', 'swapPercent'
);
foreach ($tmp AS $v) {
    $sysInfo[$v] = $sysInfo[$v] ? $sysInfo[$v] : 0;
}
?>
          物理内存：共
          <font color='#CC0000'><?php echo $memTotal;?> </font>
           , 已用
          <font color='#CC0000'><span id="UsedMemory"><?php echo $mu;?></span></font>
          , 空闲
          <font color='#CC0000'><span id="FreeMemory"><?php echo $mf;?></span></font>
          , 使用率
          <span id="memPercent"><?php echo $memPercent;?></span>
          <div class="bar"><div id="barmemPercent" class="barli_green" style="width:<?php echo $memPercent?>%" >&nbsp;</div> </div>
<?php
//判断如果cache为0，不显示
if($sysInfo['memCached']>0)
{
?>        
          Cache化内存为 <span id="CachedMemory"><?php echo $mc;?></span>
          , 使用率 
          <span id="memCachedPercent"><?php echo $memCachedPercent;?></span>
          %    | Buffers缓冲为  <span id="Buffers"><?php echo $mb;?></span>
          <div class="bar"><div id="barmemCachedPercent" class="barli_blue" style="width:<?php echo $memCachedPercent?>%" >&nbsp;</div></div>
          真实内存使用
          <span id="memRealUsed"><?php echo $memRealUsed;?></span>
          , 真实内存空闲
          <span id="memRealFree"><?php echo $memRealFree;?></span>
          , 使用率
          <span id="memRealPercent"><?php echo $memRealPercent;?></span>
          %
          <div class="bar"><div id="barmemRealPercent" class="barli_blue2" style="width:<?php echo $memRealPercent?>%" >&nbsp;</div></div> 
<?php
}
//判断如果SWAP区为0，不显示
if($sysInfo['swapTotal']>0)
{
?>    
          SWAP区：共
          <?php echo $st;?>
          , 已使用
          <span id="swapUsed"><?php echo $su;?></span>
          , 空闲
          <span id="swapFree"><?php echo $sf;?></span>
          , 使用率
          <span id="swapPercent"><?php echo $swapPercent;?></span>
          %
          <div class="bar"><div id="barswapPercent" class="barli_red" style="width:<?php echo $swapPercent?>%" >&nbsp;</div> </div>

<?php
}    
?>          
        </td>
    </tr>

    <tr>
        <td>系统平均负载</td>
        <td colspan="5" class="w_number"><span id="loadAvg"><?php echo $load;?></span></td>
    </tr>
</table>
<?}?>

<?php if (false !== ($strs = @file("/proc/net/dev"))) : ?>
<table>
    <tr><th colspan="5"><i class="fa fa-bar-chart"></i> 网络使用状况</th></tr>
<?php for ($i = 2; $i < count($strs); $i++ ) : ?>
<?php preg_match_all( "/([^\s]+):[\s]{0,}(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/", $strs[$i], $info );?>
     <tr>
        <td width="13%"><?php echo $info[1][0]?> : </td>
        <td width="29%">入网: <font color='#CC0000'><span id="NetInput<?php echo $i?>"><?php echo $NetInput[$i]?></span></font></td>
        <td width="14%">实时: <font color='#CC0000'><span id="NetInputSpeed<?php echo $i?>">0B/s</span></font></td>
        <td width="29%">出网: <font color='#CC0000'><span id="NetOut<?php echo $i?>"><?php echo $NetOut[$i]?></span></font></td>
        <td width="14%">实时: <font color='#CC0000'><span id="NetOutSpeed<?php echo $i?>">0B/s</span></font></td>
    </tr>

<?php endfor; ?>
</table>
<?php endif; ?>

<table width="100%" cellpadding="3" cellspacing="0" align="center">
  <tr>
    <th colspan="4"><i class="fa fa-download "></i> PHP 已编译模块检测</th>
  </tr>
  <tr>
    <td colspan="4"><span class="w_small">
<?php
$able=get_loaded_extensions();
foreach ($able as $key=>$value) {
    if ($key!=0 && $key%13==0) {
        echo '<br />';
    }
    echo "$value&nbsp;&nbsp;";
}
?></span>
    </td>
  </tr>
</table>

<a name="w_php" id="w_php" style="position:relative;top:-60px;"></a>
<table>
  <tr><th colspan="4"><i class="fa fa-tags"></i> PHP 参数</th></tr>
  <tr>
    <td width="30%">PHP 信息(phpinfo)</td>
    <td width="20%">
        <?php
        $phpSelf = $_SERVER['PHP_SELF'] ? $_SERVER['PHP_SELF'] : $_SERVER['SCRIPT_NAME'];
        $disFuns=get_cfg_var("disable_functions");
        ?>
       <?php echo (false!==preg_match("phpinfo",$disFuns))? '<font color="red"><i class="fa fa-times"></i></font>' :"<a href='$phpSelf?act=phpinfo' target='_blank'>PHPINFO <i class=\"fa fa-external-link\"></i></a>";?>
    </td>
    <td width="30%">PHP 版本(php_version)</td>
    <td width="20%"><?php echo PHP_VERSION;?></td>
  </tr>

  <tr>
    <td>PHP 运行方式</td>
    <td><?php echo strtoupper(php_sapi_name());?></td>
    <td>脚本占用最大内存(memory_limit)</td>
    <td><?php echo show("memory_limit");?></td>
  </tr>

  <tr>
    <td>PHP 安全模式(safe_mode)</td>
    <td><?php echo show("safe_mode");?></td>
    <td>POST 方法提交最大限制(post_max_size)</td>
    <td><?php echo show("post_max_size");?></td>
  </tr>

  <tr>
    <td>上传文件最大限制(upload_max_filesize)</td>
    <td><?php echo show("upload_max_filesize");?></td>
    <td>浮点型数据显示的有效位数(precision)</td>
    <td><?php echo show("precision");?></td>
  </tr>

  <tr>
    <td>脚本超时时间(max_execution_time)</td>
    <td><?php echo show("max_execution_time");?>秒</td>
    <td>socket 超时时间(default_socket_timeout)</td>
    <td><?php echo show("default_socket_timeout");?>秒</td>
  </tr>

  <tr>
    <td>PHP 页面根目录(doc_root)</td>
    <td><?php echo show("doc_root");?></td>
    <td>用户根目录(user_dir)</td>
    <td><?php echo show("user_dir");?></td>
  </tr>

  <tr>
    <td>dl() 函数(enable_dl)</td>
    <td><?php echo show("enable_dl");?></td>
    <td>指定包含文件目录(set_include_path)</td>
    <td><?php echo show("set_include_path");?></td>
  </tr>

  <tr>
    <td>显示错误信息(display_errors)</td>
    <td><?php echo show("display_errors");?></td>
    <td>自定义全局变量(register_globals)</td>
    <td><?php echo show("register_globals");?></td>
  </tr>

  <tr>
    <td>数据反斜杠转义(magic_quotes_gpc)</td>
    <td><?php echo show("magic_quotes_gpc");?></td>
    <td>"&lt;?...?&gt;"短标签(short_open_tag)</td>
    <td><?php echo show("short_open_tag");?></td>
  </tr>

  <tr>
    <td>"&lt;% %&gt;"ASP 风格标记(asp_tags)</td>
    <td><?php echo show("asp_tags");?></td>
    <td>忽略重复错误信息(ignore_repeated_errors)</td>
    <td><?php echo show("ignore_repeated_errors");?></td>
  </tr>

  <tr>
    <td>忽略重复的错误源(ignore_repeated_source)</td>
    <td><?php echo show("ignore_repeated_source");?></td>
    <td>报告内存泄漏(report_memleaks)</td>
    <td><?php echo show("report_memleaks");?></td>
  </tr>

  <tr>
    <td>自动字符串转义(magic_quotes_gpc)</td>
    <td><?php echo show("magic_quotes_gpc");?></td>
    <td>外部字符串自动转义(magic_quotes_runtime)</td>
    <td><?php echo show("magic_quotes_runtime");?></td>
  </tr>

  <tr>
    <td>打开远程文件(allow_url_fopen)</td>
    <td><?php echo show("allow_url_fopen");?></td>
    <td>声明 argv 和 argc 变量(register_argc_argv)</td>
    <td><?php echo show("register_argc_argv");?></td>
  </tr>

  <tr>
    <td>Cookie 支持</td>
    <td><?php echo isset($_COOKIE)?'<font color="green"><i class="fa fa-check"></i></font>' : '<font color="red"><i class="fa fa-times"></i></font>';?></td>
    <td>拼写检查(PSpell Check)</td>
    <td><?php echo isfun("pspell_check");?></td>
  </tr>

  <tr>
    <td>高精度数学运算(BCMath)</td>
    <td><?php echo isfun("bcadd");?></td>
    <td>PREL 相容语法(PCRE)</td>
    <td><?php echo isfun("preg_match");?></td>
  </tr>

  <tr>
    <td>PDF 文档支持</td>
    <td><?php echo isfun("pdf_close");?></td>
    <td>SNMP 网络管理协议</td>
    <td><?php echo isfun("snmpget");?></td>
  </tr> 

  <tr>
    <td>VMailMgr 邮件处理</td>
    <td><?php echo isfun("vm_adduser");?></td>
    <td>Curl 支持：</td>
    <td><?php echo isfun("curl_init");?></td>
  </tr> 

  <tr>
    <td>SMTP 支持</td>
    <td><?php echo get_cfg_var("SMTP")?'<font color="green"><i class="fa fa-check"></i></font>' : '<font color="red"><i class="fa fa-times"></i></font>';?></td>
    <td>SMTP 地址</td>
    <td><?php echo get_cfg_var("SMTP")?get_cfg_var("SMTP"):'<font color="red"><i class="fa fa-times"></i></font>';?></td>
  </tr> 

  <tr>
    <td>默认支持函数(enable_functions)</td>
    <td colspan="3"><a href='<?php echo $phpSelf;?>?act=Function' target='_blank' class='static'>查看详细 <i class="fa fa-external-link"></i></a></td>        
  </tr>

  <tr>
    <td>被禁用的函数(disable_functions)</td>
    <td colspan="3" class="word">
<?php 
$disFuns=get_cfg_var("disable_functions");
if(empty($disFuns))
{
    echo '<font color=red><i class="fa fa-times"></i></font>';
}
else
{ 
    //echo $disFuns;
    $disFuns_array =  explode(',',$disFuns);
    foreach ($disFuns_array as $key=>$value) 
    {
        if ($key!=0 && $key%6==0) {
            echo '<br />';
    }
    echo "$value&nbsp;&nbsp;";
}    
}
?>
    </td>
  </tr>
</table>

<a name="w_module" id="w_module" style="position:relative;top:-60px;"></a>
<!--组件信息-->
<table>
  <tr><th colspan="4" ><i class="fa fa-cogs"></i> 组件支持</th></tr>

  <tr>
    <td width="30%">FTP 支持</td>
    <td width="20%"><?php echo isfun("ftp_login");?></td>
    <td width="30%">XML 解析支持</td>
    <td width="20%"><?php echo isfun("xml_set_object");?></td>
  </tr>

  <tr>
    <td>Session 支持</td>
    <td><?php echo isfun("session_start");?></td>
    <td>Socket 支持</td>
    <td><?php echo isfun("socket_accept");?></td>
  </tr>

  <tr>
    <td>Calendar 支持</td>
    <td><?php echo isfun('cal_days_in_month');?></td>
    <td>允许 URL 打开文件</td>
    <td><?php echo show("allow_url_fopen");?></td>
  </tr>

  <tr>
    <td>GD 库支持</td>
    <td>
    <?php
        if(function_exists(gd_info)) {
            $gd_info = @gd_info();
            echo $gd_info["GD Version"];
        }else{echo '<font color="red"><i class="fa fa-times"></i></font>';}
    ?></td>
    <td>压缩文件支持(Zlib)</td>
    <td><?php echo isfun("gzclose");?></td>
  </tr>

  <tr>
    <td>IMAP 电子邮件系统函数库</td>
    <td><?php echo isfun("imap_close");?></td>
    <td>历法运算函数库</td>
    <td><?php echo isfun("jdtogregorian");?></td>
  </tr>

  <tr>
    <td>正则表达式函数库</td>
    <td><?php echo isfun("preg_match");?></td>
    <td>WDDX 支持</td>
    <td><?php echo isfun("wddx_add_vars");?></td>
  </tr>

  <tr>
    <td>iconv 编码转换</td>
    <td><?php echo isfun("iconv");?></td>
    <td>mbstring</td>
    <td><?php echo isfun("mb_eregi");?></td>
  </tr>

  <tr>
    <td>BCMath 高精度数学运算</td>
    <td><?php echo isfun("bcadd");?></td>
    <td>LDAP 目录协议</td>
    <td><?php echo isfun("ldap_close");?></td>
  </tr>

  <tr>
    <td>OpenSSL 加密处理</td>
    <td><?php echo isfun("openssl_open");?></td>
    <td>Mhash 哈稀计算</td>
    <td><?php echo isfun("mhash_count");?></td>
  </tr>
</table>

<a name="w_module_other" id="w_module_other" style="position:relative;top:-60px;"></a>
<!--第三方组件信息-->
<table>
  <tr><th colspan="4" ><i class="fa fa-cubes"></i> 第三方组件</th></tr>
  <tr>
    <td width="30%">Zend 版本</td>
    <td width="20%"><?php $zend_version = zend_version();if(empty($zend_version)){echo "<font color=red><i class=\"fa fa-times\"></i></font>";}else{echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo $zend_version;}?></td>
    <td width="30%">
<?php
$PHP_VERSION = PHP_VERSION;
$PHP_VERSION = substr($PHP_VERSION,0,1);
if($PHP_VERSION > 2)
{
    echo "Zend Guard Loader";
}
else
{
    echo "Zend Optimizer";
}
?>
    </td>
    <td width="20%"><?php if($PHP_VERSION > 2){if(function_exists("zend_loader_version")){ echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo zend_loader_version();} else { echo "<font color=red><i class=\"fa fa-times\"></i></font>";}} else{if(function_exists('zend_optimizer_version')){ echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo zend_optimizer_version();}else{echo (get_cfg_var("zend_optimizer.optimization_level")||get_cfg_var("zend_extension_manager.optimizer_ts")||get_cfg_var("zend.ze1_compatibility_mode")||get_cfg_var("zend_extension_ts"))?'<font color=green><i class="fa fa-check"></i></font>':'<font color=red><i class="fa fa-times"></i></font>';}}?></td>
  </tr>

  <tr>
    <td>eAccelerator</td>
    <td><?php if((phpversion('eAccelerator'))!=''){echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo phpversion('eAccelerator');}else{ echo "<font color=red><i class=\"fa fa-times\"></i></font>";} ?></td>
    <td>ionCube Loader</td>
    <td><?php if(extension_loaded('ionCube Loader')){$ys = ioncube_loader_iversion();$gm = ".".(int)substr($ys,3,2);echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo ionCube_Loader_version().$gm;}else{echo "<font color=red><i class=\"fa fa-times\"></i></font>";}?></td>
  </tr>

  <tr>
    <td>XCache</td>
    <td><?php if((phpversion('XCache'))!=''){echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";echo phpversion('XCache');}else{ echo "<font color=red><i class=\"fa fa-times\"></i></font>";} ?></td>
    <td>Zend OPcache</td>
    <td><?php if(function_exists('opcache_get_configuration')){echo "<font color=green><i class=\"fa fa-check\"></i></font>　Ver ";$configuration=call_user_func('opcache_get_configuration'); echo $configuration['version']['version'];}else{ echo "<font color=red><i class=\"fa fa-times\"></i></font>";} ?></td>
  </tr>
</table>

<a name="w_db" id="w_db" style="position:relative;top:-60px;"></a>
<!--数据库支持-->
<table>
  <tr><th colspan="4"><i class="fa fa-database"></i> 数据库支持</th></tr>

  <tr>
    <td width="30%">MySQL</td>
    <td width="20%"><?php echo isfun("mysqli_connect"); ?>
    <?php $mysql_ver = getMySQLVersion(); if(!empty($mysql_ver)){ echo "&nbsp;&nbsp;Ver&nbsp;" . $mysql_ver;} ?>
    </td>
    <td width="30%">ODBC</td>
    <td width="20%"><?php echo isfun("odbc_close");?></td>
  </tr>

  <tr>
    <td>Oracle OCI8</td>
    <td><?php echo isfun("oci_close");?></td>
    <td>SQL Server</td>
    <td><?php echo isfun("mssql_close");?></td>
  </tr>

  <tr>
    <td>dBASE</td>
    <td><?php echo isfun("dbase_close");?></td>
    <td>mSQL</td>
    <td><?php echo isfun("msql_close");?></td>
  </tr>

  <tr>
    <td>SQLite</td>
    <td><?php if(extension_loaded('sqlite3')) {$sqliteVer = SQLite3::version();echo '<font color=green><i class="fa fa-check"></i></font>　Ver ';echo $sqliteVer[versionString];}else {echo isfun("sqlite_close");if(isfun("sqlite_close") == '<font color="green">√</font>　') {echo "Ver ".@sqlite_libversion();}}?></td>
    <td>Hyperwave</td>
    <td><?php echo isfun("hw_close");?></td>
  </tr>

  <tr>
    <td>Postgre SQL</td>
    <td><?php echo isfun("pg_close"); ?></td>
    <td>Informix</td>
    <td><?php echo isfun("ifx_close");?></td>
  </tr>

  <tr>
    <td>DBA</td>
    <td><?php echo isfun("dba_close");?></td>
    <td>DBM</td>
    <td><?php echo isfun("dbmclose");?></td>
  </tr>

  <tr>
    <td>FilePro</td>
    <td><?php echo isfun("filepro_fieldcount");?></td>
    <td>SyBase</td>
    <td><?php echo isfun("sybase_close");?></td>
  </tr> 
</table>

<a name="w_performance" id="w_performance" style="position:relative;top:-60px;"></a>
<form action="<?php echo $_SERVER[PHP_SELF]."#w_performance";?>" method="post">
<!--服务器性能检测-->
<table>
  <tr><th colspan="5"><i class="fa fa-tachometer"></i> 服务器性能检测</th></tr>

  <tr align="center">
    <td width="19%">参照对象</td>
    <td width="17%">整数运算能力检测<br />(1+1运算300万次)</td>
    <td width="17%">浮点运算能力检测<br />(圆周率开平方300万次)</td>
    <td width="17%">数据I/O能力检测<br />(读取10K文件1万次)</td>
    <td width="30%">CPU信息</td>
  </tr>

  <tr align="center">
    <td align="left">美国 LinodeVPS</td>
    <td>0.357秒</td>
    <td>0.802秒</td>
    <td>0.023秒</td>
    <td align="left">4 x Xeon L5520 @ 2.27GHz</td>
  </tr> 

  <tr align="center">
    <td align="left">美国 PhotonVPS.com</td>
    <td>0.431秒</td>
    <td>1.024秒</td>
    <td>0.034秒</td>
    <td align="left">8 x Xeon E5520 @ 2.27GHz</td>
  </tr>

  <tr align="center">
    <td align="left">德国 SpaceRich.com</td>
    <td>0.421秒</td>
    <td>1.003秒</td>
    <td>0.038秒</td>
    <td align="left">4 x Core i7 920 @ 2.67GHz</td>
  </tr>

  <tr align="center">
    <td align="left">美国 RiZie.com</td>
    <td>0.521秒</td>
    <td>1.559秒</td>
    <td>0.054秒</td>
    <td align="left">2 x Pentium4 3.00GHz</td>
  </tr>

  <tr align="center">
    <td align="left">埃及 CitynetHost.com</a></td>
    <td>0.343秒</td>
    <td>0.761秒</td>
    <td>0.023秒</td>
    <td align="left">2 x Core2Duo E4600 @ 2.40GHz</td>
  </tr>

  <tr align="center">
    <td align="left">美国 IXwebhosting.com</td>
    <td>0.535秒</td>
    <td>1.607秒</td>
    <td>0.058秒</td>
    <td align="left">4 x Xeon E5530 @ 2.40GHz</td>
  </tr>

  <tr align="center">
    <td>本台服务器</td>
    <td><?php echo $valInt;?><br /><input class="btn" name="act" type="submit" value="整型测试" /></td>
    <td><?php echo $valFloat;?><br /><input class="btn" name="act" type="submit" value="浮点测试" /></td>
    <td><?php echo $valIo;?><br /><input class="btn" name="act" type="submit" value="IO测试" /></td>
    <td></td>
  </tr>
</table>

<input type="hidden" name="pInt" value="<?php echo $valInt;?>" />
<input type="hidden" name="pFloat" value="<?php echo $valFloat;?>" />
<input type="hidden" name="pIo" value="<?php echo $valIo;?>" />

<a name="w_networkspeed" style="position:relative;top:-60px;"></a>
<!--网络速度测试-->
<table>
	<tr><th colspan="3"><i class="fa fa-cloud-upload"></i> 网络速度测试</th></tr>
  <tr>
    <td width="19%" align="center"><input name="act" type="submit" class="btn" value="开始测试" />
    <br />
    向客户端传送2048KB数据<br />
    带宽比例按理想值计算
    </td>
    <td width="81%" align="center" >

  <table align="center" width="550" border="0" cellspacing="0" cellpadding="0" >
    <tr >
    <td height="15" width="50">带宽</td>
    <td height="15" width="50">1M</td>
    <td height="15" width="50">2M</td>
    <td height="15" width="50">3M</td>
    <td height="15" width="50">4M</td>
    <td height="15" width="50">5M</td>
    <td height="15" width="50">6M</td>
    <td height="15" width="50">7M</td>
    <td height="15" width="50">8M</td>
    <td height="15" width="50">9M</td>
    <td height="15" width="50">10M</td>
    </tr>
   <tr>
    <td colspan="11" class="suduk" ><table align="center" width="550" border="0" cellspacing="0" cellpadding="0" height="8" class="suduk" style="box-shadow:0 0 0;">
    <tr>
      <td class="sudu" style="border: 0px none; height: 6px;" width="<?php 
	if(preg_match("/[^\d-., ]/",$speed))
		{
			echo "0";
		}
	else{
			echo 550*($speed/11000);
		} 
		?>"></td>
      <td class="suduk" style="border: 0px none; height: 6px;" width="<?php 
	if(preg_match("/[^\d-., ]/",$speed))
		{
			echo "550";
		}
	else{
			echo 550-550*($speed/11000);
		} 
		?>"></td>
    </tr>
    </table>
   </td>
  </tr>
  </table>
  <?php echo (isset($_GET['speed']))?"下载2048KB数据用时 <font color='#177BBE'>".$_GET['speed']."</font> 毫秒，下载速度："."<font color='#177BBE'>".$speed."</font>"." kb/s，需测试多次取平均值，超过10M直接看下载速度":"<font color='#177BBE'>&nbsp;未探测&nbsp;</font>" ?>

    </td>
  </tr>
</table>

<a name="w_MySQL" style="position:relative;top:-60px;"></a>

<!--MySQL数据库连接检测-->
<table>

	<tr><th colspan="3"><i class="fa fa-link"></i> MySQL数据库连接检测</th></tr>

  <tr>
    <td width="15%"></td>
    <td width="60%">
      地址：<input type="text" name="host" value="localhost" size="10" />
      端口：<input type="text" name="port" value="3306" size="10" />
      用户名：<input type="text" name="login" size="10" />
      密码：<input type="password" name="password" size="10" />
    </td>
    <td width="25%">
      <input class="btn" type="submit" name="act" value="MySQL检测" />
    </td>
  </tr>
</table>
<?php
  if (isset($_POST['act']) && $_POST['act'] == 'MySQL检测') {
      if(class_exists("mysqli")) {
	  
	  $link = new mysqli($host,$login,$password,'information_schema',$port);
          if ($link){
              echo "<script>alert('连接到MySql数据库正常')</script>";
          } else {
              echo "<script>alert('无法连接到MySql数据库！')</script>";
          }
      } else {
          echo "<script>alert('服务器不支持MySQL数据库！')</script>";
      }
  }
?>
    
<a name="w_function" style="position:relative;top:-60px;"></a>
<!--函数检测-->
<table>

  <tr><th colspan="3"><i class="fa fa-code"></i> 函数检测</th></tr>

  <tr>
    <td width="15%"></td>
    <td width="60%">
      请输入您要检测的函数：
      <input type="text" name="funName" size="50" />
    </td>
    <td width="25%">
      <input class="btn" type="submit" name="act" align="right" value="函数检测" />
    </td>
  </tr>

<?php
  if (isset($_POST['act']) && $_POST['act'] == '函数检测') {
      echo "<script>alert('$funRe')</script>";
  }
?>
</table>

<a name="w_mail" style="position:relative;top:-60px;"></a>
<!--邮件发送检测-->
<table>
  <tr><th colspan="3"><i class="fa fa-envelope-o "></i> 邮件发送检测</th></tr>
  <tr>
    <td width="15%"></td>
    <td width="60%">
      请输入您要检测的邮件地址：
      <input type="text" name="mailAdd" size="50" />
    </td>
    <td width="25%">
    <input class="btn" type="submit" name="act" value="邮件检测" />
    </td>
  </tr>
<?php
  if (isset($_POST['act']) && $_POST['act'] == '邮件检测') {
      echo "<script>alert('$mailRe')</script>";
  }
?>
</table>
</form>
    <table>
        <tr>
            <td class="w_foot"><a href="https://lamp.sh" target="_blank">基于 YaHei.net 探针</a></td>
            <td class="w_foot"><?php $run_time = sprintf('%0.4f', microtime_float() - $time_start);?>Processed in <?php echo $run_time?> seconds. <?php echo memory_usage();?> memory usage.</td>
            <td class="w_foot"><a href="#w_top">返回顶部</a></td>
        </tr>
    </table>
</div>
</body>
</html>
                                       lamp/conf/jquery.js                                                                                 000644  000765  000024  00000273052 13564465250 016125  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         /*! jQuery v1.11.1 | (c) 2005, 2014 jQuery Foundation, Inc. | jquery.org/license */
!function(a,b){"object"==typeof module&&"object"==typeof module.exports?module.exports=a.document?b(a,!0):function(a){if(!a.document)throw new Error("jQuery requires a window with a document");return b(a)}:b(a)}("undefined"!=typeof window?window:this,function(a,b){var c=[],d=c.slice,e=c.concat,f=c.push,g=c.indexOf,h={},i=h.toString,j=h.hasOwnProperty,k={},l="1.11.1",m=function(a,b){return new m.fn.init(a,b)},n=/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g,o=/^-ms-/,p=/-([\da-z])/gi,q=function(a,b){return b.toUpperCase()};m.fn=m.prototype={jquery:l,constructor:m,selector:"",length:0,toArray:function(){return d.call(this)},get:function(a){return null!=a?0>a?this[a+this.length]:this[a]:d.call(this)},pushStack:function(a){var b=m.merge(this.constructor(),a);return b.prevObject=this,b.context=this.context,b},each:function(a,b){return m.each(this,a,b)},map:function(a){return this.pushStack(m.map(this,function(b,c){return a.call(b,c,b)}))},slice:function(){return this.pushStack(d.apply(this,arguments))},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},eq:function(a){var b=this.length,c=+a+(0>a?b:0);return this.pushStack(c>=0&&b>c?[this[c]]:[])},end:function(){return this.prevObject||this.constructor(null)},push:f,sort:c.sort,splice:c.splice},m.extend=m.fn.extend=function(){var a,b,c,d,e,f,g=arguments[0]||{},h=1,i=arguments.length,j=!1;for("boolean"==typeof g&&(j=g,g=arguments[h]||{},h++),"object"==typeof g||m.isFunction(g)||(g={}),h===i&&(g=this,h--);i>h;h++)if(null!=(e=arguments[h]))for(d in e)a=g[d],c=e[d],g!==c&&(j&&c&&(m.isPlainObject(c)||(b=m.isArray(c)))?(b?(b=!1,f=a&&m.isArray(a)?a:[]):f=a&&m.isPlainObject(a)?a:{},g[d]=m.extend(j,f,c)):void 0!==c&&(g[d]=c));return g},m.extend({expando:"jQuery"+(l+Math.random()).replace(/\D/g,""),isReady:!0,error:function(a){throw new Error(a)},noop:function(){},isFunction:function(a){return"function"===m.type(a)},isArray:Array.isArray||function(a){return"array"===m.type(a)},isWindow:function(a){return null!=a&&a==a.window},isNumeric:function(a){return!m.isArray(a)&&a-parseFloat(a)>=0},isEmptyObject:function(a){var b;for(b in a)return!1;return!0},isPlainObject:function(a){var b;if(!a||"object"!==m.type(a)||a.nodeType||m.isWindow(a))return!1;try{if(a.constructor&&!j.call(a,"constructor")&&!j.call(a.constructor.prototype,"isPrototypeOf"))return!1}catch(c){return!1}if(k.ownLast)for(b in a)return j.call(a,b);for(b in a);return void 0===b||j.call(a,b)},type:function(a){return null==a?a+"":"object"==typeof a||"function"==typeof a?h[i.call(a)]||"object":typeof a},globalEval:function(b){b&&m.trim(b)&&(a.execScript||function(b){a.eval.call(a,b)})(b)},camelCase:function(a){return a.replace(o,"ms-").replace(p,q)},nodeName:function(a,b){return a.nodeName&&a.nodeName.toLowerCase()===b.toLowerCase()},each:function(a,b,c){var d,e=0,f=a.length,g=r(a);if(c){if(g){for(;f>e;e++)if(d=b.apply(a[e],c),d===!1)break}else for(e in a)if(d=b.apply(a[e],c),d===!1)break}else if(g){for(;f>e;e++)if(d=b.call(a[e],e,a[e]),d===!1)break}else for(e in a)if(d=b.call(a[e],e,a[e]),d===!1)break;return a},trim:function(a){return null==a?"":(a+"").replace(n,"")},makeArray:function(a,b){var c=b||[];return null!=a&&(r(Object(a))?m.merge(c,"string"==typeof a?[a]:a):f.call(c,a)),c},inArray:function(a,b,c){var d;if(b){if(g)return g.call(b,a,c);for(d=b.length,c=c?0>c?Math.max(0,d+c):c:0;d>c;c++)if(c in b&&b[c]===a)return c}return-1},merge:function(a,b){var c=+b.length,d=0,e=a.length;while(c>d)a[e++]=b[d++];if(c!==c)while(void 0!==b[d])a[e++]=b[d++];return a.length=e,a},grep:function(a,b,c){for(var d,e=[],f=0,g=a.length,h=!c;g>f;f++)d=!b(a[f],f),d!==h&&e.push(a[f]);return e},map:function(a,b,c){var d,f=0,g=a.length,h=r(a),i=[];if(h)for(;g>f;f++)d=b(a[f],f,c),null!=d&&i.push(d);else for(f in a)d=b(a[f],f,c),null!=d&&i.push(d);return e.apply([],i)},guid:1,proxy:function(a,b){var c,e,f;return"string"==typeof b&&(f=a[b],b=a,a=f),m.isFunction(a)?(c=d.call(arguments,2),e=function(){return a.apply(b||this,c.concat(d.call(arguments)))},e.guid=a.guid=a.guid||m.guid++,e):void 0},now:function(){return+new Date},support:k}),m.each("Boolean Number String Function Array Date RegExp Object Error".split(" "),function(a,b){h["[object "+b+"]"]=b.toLowerCase()});function r(a){var b=a.length,c=m.type(a);return"function"===c||m.isWindow(a)?!1:1===a.nodeType&&b?!0:"array"===c||0===b||"number"==typeof b&&b>0&&b-1 in a}var s=function(a){var b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u="sizzle"+-new Date,v=a.document,w=0,x=0,y=gb(),z=gb(),A=gb(),B=function(a,b){return a===b&&(l=!0),0},C="undefined",D=1<<31,E={}.hasOwnProperty,F=[],G=F.pop,H=F.push,I=F.push,J=F.slice,K=F.indexOf||function(a){for(var b=0,c=this.length;c>b;b++)if(this[b]===a)return b;return-1},L="checked|selected|async|autofocus|autoplay|controls|defer|disabled|hidden|ismap|loop|multiple|open|readonly|required|scoped",M="[\\x20\\t\\r\\n\\f]",N="(?:\\\\.|[\\w-]|[^\\x00-\\xa0])+",O=N.replace("w","w#"),P="\\["+M+"*("+N+")(?:"+M+"*([*^$|!~]?=)"+M+"*(?:'((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\"|("+O+"))|)"+M+"*\\]",Q=":("+N+")(?:\\((('((?:\\\\.|[^\\\\'])*)'|\"((?:\\\\.|[^\\\\\"])*)\")|((?:\\\\.|[^\\\\()[\\]]|"+P+")*)|.*)\\)|)",R=new RegExp("^"+M+"+|((?:^|[^\\\\])(?:\\\\.)*)"+M+"+$","g"),S=new RegExp("^"+M+"*,"+M+"*"),T=new RegExp("^"+M+"*([>+~]|"+M+")"+M+"*"),U=new RegExp("="+M+"*([^\\]'\"]*?)"+M+"*\\]","g"),V=new RegExp(Q),W=new RegExp("^"+O+"$"),X={ID:new RegExp("^#("+N+")"),CLASS:new RegExp("^\\.("+N+")"),TAG:new RegExp("^("+N.replace("w","w*")+")"),ATTR:new RegExp("^"+P),PSEUDO:new RegExp("^"+Q),CHILD:new RegExp("^:(only|first|last|nth|nth-last)-(child|of-type)(?:\\("+M+"*(even|odd|(([+-]|)(\\d*)n|)"+M+"*(?:([+-]|)"+M+"*(\\d+)|))"+M+"*\\)|)","i"),bool:new RegExp("^(?:"+L+")$","i"),needsContext:new RegExp("^"+M+"*[>+~]|:(even|odd|eq|gt|lt|nth|first|last)(?:\\("+M+"*((?:-\\d)?\\d*)"+M+"*\\)|)(?=[^-]|$)","i")},Y=/^(?:input|select|textarea|button)$/i,Z=/^h\d$/i,$=/^[^{]+\{\s*\[native \w/,_=/^(?:#([\w-]+)|(\w+)|\.([\w-]+))$/,ab=/[+~]/,bb=/'|\\/g,cb=new RegExp("\\\\([\\da-f]{1,6}"+M+"?|("+M+")|.)","ig"),db=function(a,b,c){var d="0x"+b-65536;return d!==d||c?b:0>d?String.fromCharCode(d+65536):String.fromCharCode(d>>10|55296,1023&d|56320)};try{I.apply(F=J.call(v.childNodes),v.childNodes),F[v.childNodes.length].nodeType}catch(eb){I={apply:F.length?function(a,b){H.apply(a,J.call(b))}:function(a,b){var c=a.length,d=0;while(a[c++]=b[d++]);a.length=c-1}}}function fb(a,b,d,e){var f,h,j,k,l,o,r,s,w,x;if((b?b.ownerDocument||b:v)!==n&&m(b),b=b||n,d=d||[],!a||"string"!=typeof a)return d;if(1!==(k=b.nodeType)&&9!==k)return[];if(p&&!e){if(f=_.exec(a))if(j=f[1]){if(9===k){if(h=b.getElementById(j),!h||!h.parentNode)return d;if(h.id===j)return d.push(h),d}else if(b.ownerDocument&&(h=b.ownerDocument.getElementById(j))&&t(b,h)&&h.id===j)return d.push(h),d}else{if(f[2])return I.apply(d,b.getElementsByTagName(a)),d;if((j=f[3])&&c.getElementsByClassName&&b.getElementsByClassName)return I.apply(d,b.getElementsByClassName(j)),d}if(c.qsa&&(!q||!q.test(a))){if(s=r=u,w=b,x=9===k&&a,1===k&&"object"!==b.nodeName.toLowerCase()){o=g(a),(r=b.getAttribute("id"))?s=r.replace(bb,"\\$&"):b.setAttribute("id",s),s="[id='"+s+"'] ",l=o.length;while(l--)o[l]=s+qb(o[l]);w=ab.test(a)&&ob(b.parentNode)||b,x=o.join(",")}if(x)try{return I.apply(d,w.querySelectorAll(x)),d}catch(y){}finally{r||b.removeAttribute("id")}}}return i(a.replace(R,"$1"),b,d,e)}function gb(){var a=[];function b(c,e){return a.push(c+" ")>d.cacheLength&&delete b[a.shift()],b[c+" "]=e}return b}function hb(a){return a[u]=!0,a}function ib(a){var b=n.createElement("div");try{return!!a(b)}catch(c){return!1}finally{b.parentNode&&b.parentNode.removeChild(b),b=null}}function jb(a,b){var c=a.split("|"),e=a.length;while(e--)d.attrHandle[c[e]]=b}function kb(a,b){var c=b&&a,d=c&&1===a.nodeType&&1===b.nodeType&&(~b.sourceIndex||D)-(~a.sourceIndex||D);if(d)return d;if(c)while(c=c.nextSibling)if(c===b)return-1;return a?1:-1}function lb(a){return function(b){var c=b.nodeName.toLowerCase();return"input"===c&&b.type===a}}function mb(a){return function(b){var c=b.nodeName.toLowerCase();return("input"===c||"button"===c)&&b.type===a}}function nb(a){return hb(function(b){return b=+b,hb(function(c,d){var e,f=a([],c.length,b),g=f.length;while(g--)c[e=f[g]]&&(c[e]=!(d[e]=c[e]))})})}function ob(a){return a&&typeof a.getElementsByTagName!==C&&a}c=fb.support={},f=fb.isXML=function(a){var b=a&&(a.ownerDocument||a).documentElement;return b?"HTML"!==b.nodeName:!1},m=fb.setDocument=function(a){var b,e=a?a.ownerDocument||a:v,g=e.defaultView;return e!==n&&9===e.nodeType&&e.documentElement?(n=e,o=e.documentElement,p=!f(e),g&&g!==g.top&&(g.addEventListener?g.addEventListener("unload",function(){m()},!1):g.attachEvent&&g.attachEvent("onunload",function(){m()})),c.attributes=ib(function(a){return a.className="i",!a.getAttribute("className")}),c.getElementsByTagName=ib(function(a){return a.appendChild(e.createComment("")),!a.getElementsByTagName("*").length}),c.getElementsByClassName=$.test(e.getElementsByClassName)&&ib(function(a){return a.innerHTML="<div class='a'></div><div class='a i'></div>",a.firstChild.className="i",2===a.getElementsByClassName("i").length}),c.getById=ib(function(a){return o.appendChild(a).id=u,!e.getElementsByName||!e.getElementsByName(u).length}),c.getById?(d.find.ID=function(a,b){if(typeof b.getElementById!==C&&p){var c=b.getElementById(a);return c&&c.parentNode?[c]:[]}},d.filter.ID=function(a){var b=a.replace(cb,db);return function(a){return a.getAttribute("id")===b}}):(delete d.find.ID,d.filter.ID=function(a){var b=a.replace(cb,db);return function(a){var c=typeof a.getAttributeNode!==C&&a.getAttributeNode("id");return c&&c.value===b}}),d.find.TAG=c.getElementsByTagName?function(a,b){return typeof b.getElementsByTagName!==C?b.getElementsByTagName(a):void 0}:function(a,b){var c,d=[],e=0,f=b.getElementsByTagName(a);if("*"===a){while(c=f[e++])1===c.nodeType&&d.push(c);return d}return f},d.find.CLASS=c.getElementsByClassName&&function(a,b){return typeof b.getElementsByClassName!==C&&p?b.getElementsByClassName(a):void 0},r=[],q=[],(c.qsa=$.test(e.querySelectorAll))&&(ib(function(a){a.innerHTML="<select msallowclip=''><option selected=''></option></select>",a.querySelectorAll("[msallowclip^='']").length&&q.push("[*^$]="+M+"*(?:''|\"\")"),a.querySelectorAll("[selected]").length||q.push("\\["+M+"*(?:value|"+L+")"),a.querySelectorAll(":checked").length||q.push(":checked")}),ib(function(a){var b=e.createElement("input");b.setAttribute("type","hidden"),a.appendChild(b).setAttribute("name","D"),a.querySelectorAll("[name=d]").length&&q.push("name"+M+"*[*^$|!~]?="),a.querySelectorAll(":enabled").length||q.push(":enabled",":disabled"),a.querySelectorAll("*,:x"),q.push(",.*:")})),(c.matchesSelector=$.test(s=o.matches||o.webkitMatchesSelector||o.mozMatchesSelector||o.oMatchesSelector||o.msMatchesSelector))&&ib(function(a){c.disconnectedMatch=s.call(a,"div"),s.call(a,"[s!='']:x"),r.push("!=",Q)}),q=q.length&&new RegExp(q.join("|")),r=r.length&&new RegExp(r.join("|")),b=$.test(o.compareDocumentPosition),t=b||$.test(o.contains)?function(a,b){var c=9===a.nodeType?a.documentElement:a,d=b&&b.parentNode;return a===d||!(!d||1!==d.nodeType||!(c.contains?c.contains(d):a.compareDocumentPosition&&16&a.compareDocumentPosition(d)))}:function(a,b){if(b)while(b=b.parentNode)if(b===a)return!0;return!1},B=b?function(a,b){if(a===b)return l=!0,0;var d=!a.compareDocumentPosition-!b.compareDocumentPosition;return d?d:(d=(a.ownerDocument||a)===(b.ownerDocument||b)?a.compareDocumentPosition(b):1,1&d||!c.sortDetached&&b.compareDocumentPosition(a)===d?a===e||a.ownerDocument===v&&t(v,a)?-1:b===e||b.ownerDocument===v&&t(v,b)?1:k?K.call(k,a)-K.call(k,b):0:4&d?-1:1)}:function(a,b){if(a===b)return l=!0,0;var c,d=0,f=a.parentNode,g=b.parentNode,h=[a],i=[b];if(!f||!g)return a===e?-1:b===e?1:f?-1:g?1:k?K.call(k,a)-K.call(k,b):0;if(f===g)return kb(a,b);c=a;while(c=c.parentNode)h.unshift(c);c=b;while(c=c.parentNode)i.unshift(c);while(h[d]===i[d])d++;return d?kb(h[d],i[d]):h[d]===v?-1:i[d]===v?1:0},e):n},fb.matches=function(a,b){return fb(a,null,null,b)},fb.matchesSelector=function(a,b){if((a.ownerDocument||a)!==n&&m(a),b=b.replace(U,"='$1']"),!(!c.matchesSelector||!p||r&&r.test(b)||q&&q.test(b)))try{var d=s.call(a,b);if(d||c.disconnectedMatch||a.document&&11!==a.document.nodeType)return d}catch(e){}return fb(b,n,null,[a]).length>0},fb.contains=function(a,b){return(a.ownerDocument||a)!==n&&m(a),t(a,b)},fb.attr=function(a,b){(a.ownerDocument||a)!==n&&m(a);var e=d.attrHandle[b.toLowerCase()],f=e&&E.call(d.attrHandle,b.toLowerCase())?e(a,b,!p):void 0;return void 0!==f?f:c.attributes||!p?a.getAttribute(b):(f=a.getAttributeNode(b))&&f.specified?f.value:null},fb.error=function(a){throw new Error("Syntax error, unrecognized expression: "+a)},fb.uniqueSort=function(a){var b,d=[],e=0,f=0;if(l=!c.detectDuplicates,k=!c.sortStable&&a.slice(0),a.sort(B),l){while(b=a[f++])b===a[f]&&(e=d.push(f));while(e--)a.splice(d[e],1)}return k=null,a},e=fb.getText=function(a){var b,c="",d=0,f=a.nodeType;if(f){if(1===f||9===f||11===f){if("string"==typeof a.textContent)return a.textContent;for(a=a.firstChild;a;a=a.nextSibling)c+=e(a)}else if(3===f||4===f)return a.nodeValue}else while(b=a[d++])c+=e(b);return c},d=fb.selectors={cacheLength:50,createPseudo:hb,match:X,attrHandle:{},find:{},relative:{">":{dir:"parentNode",first:!0}," ":{dir:"parentNode"},"+":{dir:"previousSibling",first:!0},"~":{dir:"previousSibling"}},preFilter:{ATTR:function(a){return a[1]=a[1].replace(cb,db),a[3]=(a[3]||a[4]||a[5]||"").replace(cb,db),"~="===a[2]&&(a[3]=" "+a[3]+" "),a.slice(0,4)},CHILD:function(a){return a[1]=a[1].toLowerCase(),"nth"===a[1].slice(0,3)?(a[3]||fb.error(a[0]),a[4]=+(a[4]?a[5]+(a[6]||1):2*("even"===a[3]||"odd"===a[3])),a[5]=+(a[7]+a[8]||"odd"===a[3])):a[3]&&fb.error(a[0]),a},PSEUDO:function(a){var b,c=!a[6]&&a[2];return X.CHILD.test(a[0])?null:(a[3]?a[2]=a[4]||a[5]||"":c&&V.test(c)&&(b=g(c,!0))&&(b=c.indexOf(")",c.length-b)-c.length)&&(a[0]=a[0].slice(0,b),a[2]=c.slice(0,b)),a.slice(0,3))}},filter:{TAG:function(a){var b=a.replace(cb,db).toLowerCase();return"*"===a?function(){return!0}:function(a){return a.nodeName&&a.nodeName.toLowerCase()===b}},CLASS:function(a){var b=y[a+" "];return b||(b=new RegExp("(^|"+M+")"+a+"("+M+"|$)"))&&y(a,function(a){return b.test("string"==typeof a.className&&a.className||typeof a.getAttribute!==C&&a.getAttribute("class")||"")})},ATTR:function(a,b,c){return function(d){var e=fb.attr(d,a);return null==e?"!="===b:b?(e+="","="===b?e===c:"!="===b?e!==c:"^="===b?c&&0===e.indexOf(c):"*="===b?c&&e.indexOf(c)>-1:"$="===b?c&&e.slice(-c.length)===c:"~="===b?(" "+e+" ").indexOf(c)>-1:"|="===b?e===c||e.slice(0,c.length+1)===c+"-":!1):!0}},CHILD:function(a,b,c,d,e){var f="nth"!==a.slice(0,3),g="last"!==a.slice(-4),h="of-type"===b;return 1===d&&0===e?function(a){return!!a.parentNode}:function(b,c,i){var j,k,l,m,n,o,p=f!==g?"nextSibling":"previousSibling",q=b.parentNode,r=h&&b.nodeName.toLowerCase(),s=!i&&!h;if(q){if(f){while(p){l=b;while(l=l[p])if(h?l.nodeName.toLowerCase()===r:1===l.nodeType)return!1;o=p="only"===a&&!o&&"nextSibling"}return!0}if(o=[g?q.firstChild:q.lastChild],g&&s){k=q[u]||(q[u]={}),j=k[a]||[],n=j[0]===w&&j[1],m=j[0]===w&&j[2],l=n&&q.childNodes[n];while(l=++n&&l&&l[p]||(m=n=0)||o.pop())if(1===l.nodeType&&++m&&l===b){k[a]=[w,n,m];break}}else if(s&&(j=(b[u]||(b[u]={}))[a])&&j[0]===w)m=j[1];else while(l=++n&&l&&l[p]||(m=n=0)||o.pop())if((h?l.nodeName.toLowerCase()===r:1===l.nodeType)&&++m&&(s&&((l[u]||(l[u]={}))[a]=[w,m]),l===b))break;return m-=e,m===d||m%d===0&&m/d>=0}}},PSEUDO:function(a,b){var c,e=d.pseudos[a]||d.setFilters[a.toLowerCase()]||fb.error("unsupported pseudo: "+a);return e[u]?e(b):e.length>1?(c=[a,a,"",b],d.setFilters.hasOwnProperty(a.toLowerCase())?hb(function(a,c){var d,f=e(a,b),g=f.length;while(g--)d=K.call(a,f[g]),a[d]=!(c[d]=f[g])}):function(a){return e(a,0,c)}):e}},pseudos:{not:hb(function(a){var b=[],c=[],d=h(a.replace(R,"$1"));return d[u]?hb(function(a,b,c,e){var f,g=d(a,null,e,[]),h=a.length;while(h--)(f=g[h])&&(a[h]=!(b[h]=f))}):function(a,e,f){return b[0]=a,d(b,null,f,c),!c.pop()}}),has:hb(function(a){return function(b){return fb(a,b).length>0}}),contains:hb(function(a){return function(b){return(b.textContent||b.innerText||e(b)).indexOf(a)>-1}}),lang:hb(function(a){return W.test(a||"")||fb.error("unsupported lang: "+a),a=a.replace(cb,db).toLowerCase(),function(b){var c;do if(c=p?b.lang:b.getAttribute("xml:lang")||b.getAttribute("lang"))return c=c.toLowerCase(),c===a||0===c.indexOf(a+"-");while((b=b.parentNode)&&1===b.nodeType);return!1}}),target:function(b){var c=a.location&&a.location.hash;return c&&c.slice(1)===b.id},root:function(a){return a===o},focus:function(a){return a===n.activeElement&&(!n.hasFocus||n.hasFocus())&&!!(a.type||a.href||~a.tabIndex)},enabled:function(a){return a.disabled===!1},disabled:function(a){return a.disabled===!0},checked:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&!!a.checked||"option"===b&&!!a.selected},selected:function(a){return a.parentNode&&a.parentNode.selectedIndex,a.selected===!0},empty:function(a){for(a=a.firstChild;a;a=a.nextSibling)if(a.nodeType<6)return!1;return!0},parent:function(a){return!d.pseudos.empty(a)},header:function(a){return Z.test(a.nodeName)},input:function(a){return Y.test(a.nodeName)},button:function(a){var b=a.nodeName.toLowerCase();return"input"===b&&"button"===a.type||"button"===b},text:function(a){var b;return"input"===a.nodeName.toLowerCase()&&"text"===a.type&&(null==(b=a.getAttribute("type"))||"text"===b.toLowerCase())},first:nb(function(){return[0]}),last:nb(function(a,b){return[b-1]}),eq:nb(function(a,b,c){return[0>c?c+b:c]}),even:nb(function(a,b){for(var c=0;b>c;c+=2)a.push(c);return a}),odd:nb(function(a,b){for(var c=1;b>c;c+=2)a.push(c);return a}),lt:nb(function(a,b,c){for(var d=0>c?c+b:c;--d>=0;)a.push(d);return a}),gt:nb(function(a,b,c){for(var d=0>c?c+b:c;++d<b;)a.push(d);return a})}},d.pseudos.nth=d.pseudos.eq;for(b in{radio:!0,checkbox:!0,file:!0,password:!0,image:!0})d.pseudos[b]=lb(b);for(b in{submit:!0,reset:!0})d.pseudos[b]=mb(b);function pb(){}pb.prototype=d.filters=d.pseudos,d.setFilters=new pb,g=fb.tokenize=function(a,b){var c,e,f,g,h,i,j,k=z[a+" "];if(k)return b?0:k.slice(0);h=a,i=[],j=d.preFilter;while(h){(!c||(e=S.exec(h)))&&(e&&(h=h.slice(e[0].length)||h),i.push(f=[])),c=!1,(e=T.exec(h))&&(c=e.shift(),f.push({value:c,type:e[0].replace(R," ")}),h=h.slice(c.length));for(g in d.filter)!(e=X[g].exec(h))||j[g]&&!(e=j[g](e))||(c=e.shift(),f.push({value:c,type:g,matches:e}),h=h.slice(c.length));if(!c)break}return b?h.length:h?fb.error(a):z(a,i).slice(0)};function qb(a){for(var b=0,c=a.length,d="";c>b;b++)d+=a[b].value;return d}function rb(a,b,c){var d=b.dir,e=c&&"parentNode"===d,f=x++;return b.first?function(b,c,f){while(b=b[d])if(1===b.nodeType||e)return a(b,c,f)}:function(b,c,g){var h,i,j=[w,f];if(g){while(b=b[d])if((1===b.nodeType||e)&&a(b,c,g))return!0}else while(b=b[d])if(1===b.nodeType||e){if(i=b[u]||(b[u]={}),(h=i[d])&&h[0]===w&&h[1]===f)return j[2]=h[2];if(i[d]=j,j[2]=a(b,c,g))return!0}}}function sb(a){return a.length>1?function(b,c,d){var e=a.length;while(e--)if(!a[e](b,c,d))return!1;return!0}:a[0]}function tb(a,b,c){for(var d=0,e=b.length;e>d;d++)fb(a,b[d],c);return c}function ub(a,b,c,d,e){for(var f,g=[],h=0,i=a.length,j=null!=b;i>h;h++)(f=a[h])&&(!c||c(f,d,e))&&(g.push(f),j&&b.push(h));return g}function vb(a,b,c,d,e,f){return d&&!d[u]&&(d=vb(d)),e&&!e[u]&&(e=vb(e,f)),hb(function(f,g,h,i){var j,k,l,m=[],n=[],o=g.length,p=f||tb(b||"*",h.nodeType?[h]:h,[]),q=!a||!f&&b?p:ub(p,m,a,h,i),r=c?e||(f?a:o||d)?[]:g:q;if(c&&c(q,r,h,i),d){j=ub(r,n),d(j,[],h,i),k=j.length;while(k--)(l=j[k])&&(r[n[k]]=!(q[n[k]]=l))}if(f){if(e||a){if(e){j=[],k=r.length;while(k--)(l=r[k])&&j.push(q[k]=l);e(null,r=[],j,i)}k=r.length;while(k--)(l=r[k])&&(j=e?K.call(f,l):m[k])>-1&&(f[j]=!(g[j]=l))}}else r=ub(r===g?r.splice(o,r.length):r),e?e(null,g,r,i):I.apply(g,r)})}function wb(a){for(var b,c,e,f=a.length,g=d.relative[a[0].type],h=g||d.relative[" "],i=g?1:0,k=rb(function(a){return a===b},h,!0),l=rb(function(a){return K.call(b,a)>-1},h,!0),m=[function(a,c,d){return!g&&(d||c!==j)||((b=c).nodeType?k(a,c,d):l(a,c,d))}];f>i;i++)if(c=d.relative[a[i].type])m=[rb(sb(m),c)];else{if(c=d.filter[a[i].type].apply(null,a[i].matches),c[u]){for(e=++i;f>e;e++)if(d.relative[a[e].type])break;return vb(i>1&&sb(m),i>1&&qb(a.slice(0,i-1).concat({value:" "===a[i-2].type?"*":""})).replace(R,"$1"),c,e>i&&wb(a.slice(i,e)),f>e&&wb(a=a.slice(e)),f>e&&qb(a))}m.push(c)}return sb(m)}function xb(a,b){var c=b.length>0,e=a.length>0,f=function(f,g,h,i,k){var l,m,o,p=0,q="0",r=f&&[],s=[],t=j,u=f||e&&d.find.TAG("*",k),v=w+=null==t?1:Math.random()||.1,x=u.length;for(k&&(j=g!==n&&g);q!==x&&null!=(l=u[q]);q++){if(e&&l){m=0;while(o=a[m++])if(o(l,g,h)){i.push(l);break}k&&(w=v)}c&&((l=!o&&l)&&p--,f&&r.push(l))}if(p+=q,c&&q!==p){m=0;while(o=b[m++])o(r,s,g,h);if(f){if(p>0)while(q--)r[q]||s[q]||(s[q]=G.call(i));s=ub(s)}I.apply(i,s),k&&!f&&s.length>0&&p+b.length>1&&fb.uniqueSort(i)}return k&&(w=v,j=t),r};return c?hb(f):f}return h=fb.compile=function(a,b){var c,d=[],e=[],f=A[a+" "];if(!f){b||(b=g(a)),c=b.length;while(c--)f=wb(b[c]),f[u]?d.push(f):e.push(f);f=A(a,xb(e,d)),f.selector=a}return f},i=fb.select=function(a,b,e,f){var i,j,k,l,m,n="function"==typeof a&&a,o=!f&&g(a=n.selector||a);if(e=e||[],1===o.length){if(j=o[0]=o[0].slice(0),j.length>2&&"ID"===(k=j[0]).type&&c.getById&&9===b.nodeType&&p&&d.relative[j[1].type]){if(b=(d.find.ID(k.matches[0].replace(cb,db),b)||[])[0],!b)return e;n&&(b=b.parentNode),a=a.slice(j.shift().value.length)}i=X.needsContext.test(a)?0:j.length;while(i--){if(k=j[i],d.relative[l=k.type])break;if((m=d.find[l])&&(f=m(k.matches[0].replace(cb,db),ab.test(j[0].type)&&ob(b.parentNode)||b))){if(j.splice(i,1),a=f.length&&qb(j),!a)return I.apply(e,f),e;break}}}return(n||h(a,o))(f,b,!p,e,ab.test(a)&&ob(b.parentNode)||b),e},c.sortStable=u.split("").sort(B).join("")===u,c.detectDuplicates=!!l,m(),c.sortDetached=ib(function(a){return 1&a.compareDocumentPosition(n.createElement("div"))}),ib(function(a){return a.innerHTML="<a href='#'></a>","#"===a.firstChild.getAttribute("href")})||jb("type|href|height|width",function(a,b,c){return c?void 0:a.getAttribute(b,"type"===b.toLowerCase()?1:2)}),c.attributes&&ib(function(a){return a.innerHTML="<input/>",a.firstChild.setAttribute("value",""),""===a.firstChild.getAttribute("value")})||jb("value",function(a,b,c){return c||"input"!==a.nodeName.toLowerCase()?void 0:a.defaultValue}),ib(function(a){return null==a.getAttribute("disabled")})||jb(L,function(a,b,c){var d;return c?void 0:a[b]===!0?b.toLowerCase():(d=a.getAttributeNode(b))&&d.specified?d.value:null}),fb}(a);m.find=s,m.expr=s.selectors,m.expr[":"]=m.expr.pseudos,m.unique=s.uniqueSort,m.text=s.getText,m.isXMLDoc=s.isXML,m.contains=s.contains;var t=m.expr.match.needsContext,u=/^<(\w+)\s*\/?>(?:<\/\1>|)$/,v=/^.[^:#\[\.,]*$/;function w(a,b,c){if(m.isFunction(b))return m.grep(a,function(a,d){return!!b.call(a,d,a)!==c});if(b.nodeType)return m.grep(a,function(a){return a===b!==c});if("string"==typeof b){if(v.test(b))return m.filter(b,a,c);b=m.filter(b,a)}return m.grep(a,function(a){return m.inArray(a,b)>=0!==c})}m.filter=function(a,b,c){var d=b[0];return c&&(a=":not("+a+")"),1===b.length&&1===d.nodeType?m.find.matchesSelector(d,a)?[d]:[]:m.find.matches(a,m.grep(b,function(a){return 1===a.nodeType}))},m.fn.extend({find:function(a){var b,c=[],d=this,e=d.length;if("string"!=typeof a)return this.pushStack(m(a).filter(function(){for(b=0;e>b;b++)if(m.contains(d[b],this))return!0}));for(b=0;e>b;b++)m.find(a,d[b],c);return c=this.pushStack(e>1?m.unique(c):c),c.selector=this.selector?this.selector+" "+a:a,c},filter:function(a){return this.pushStack(w(this,a||[],!1))},not:function(a){return this.pushStack(w(this,a||[],!0))},is:function(a){return!!w(this,"string"==typeof a&&t.test(a)?m(a):a||[],!1).length}});var x,y=a.document,z=/^(?:\s*(<[\w\W]+>)[^>]*|#([\w-]*))$/,A=m.fn.init=function(a,b){var c,d;if(!a)return this;if("string"==typeof a){if(c="<"===a.charAt(0)&&">"===a.charAt(a.length-1)&&a.length>=3?[null,a,null]:z.exec(a),!c||!c[1]&&b)return!b||b.jquery?(b||x).find(a):this.constructor(b).find(a);if(c[1]){if(b=b instanceof m?b[0]:b,m.merge(this,m.parseHTML(c[1],b&&b.nodeType?b.ownerDocument||b:y,!0)),u.test(c[1])&&m.isPlainObject(b))for(c in b)m.isFunction(this[c])?this[c](b[c]):this.attr(c,b[c]);return this}if(d=y.getElementById(c[2]),d&&d.parentNode){if(d.id!==c[2])return x.find(a);this.length=1,this[0]=d}return this.context=y,this.selector=a,this}return a.nodeType?(this.context=this[0]=a,this.length=1,this):m.isFunction(a)?"undefined"!=typeof x.ready?x.ready(a):a(m):(void 0!==a.selector&&(this.selector=a.selector,this.context=a.context),m.makeArray(a,this))};A.prototype=m.fn,x=m(y);var B=/^(?:parents|prev(?:Until|All))/,C={children:!0,contents:!0,next:!0,prev:!0};m.extend({dir:function(a,b,c){var d=[],e=a[b];while(e&&9!==e.nodeType&&(void 0===c||1!==e.nodeType||!m(e).is(c)))1===e.nodeType&&d.push(e),e=e[b];return d},sibling:function(a,b){for(var c=[];a;a=a.nextSibling)1===a.nodeType&&a!==b&&c.push(a);return c}}),m.fn.extend({has:function(a){var b,c=m(a,this),d=c.length;return this.filter(function(){for(b=0;d>b;b++)if(m.contains(this,c[b]))return!0})},closest:function(a,b){for(var c,d=0,e=this.length,f=[],g=t.test(a)||"string"!=typeof a?m(a,b||this.context):0;e>d;d++)for(c=this[d];c&&c!==b;c=c.parentNode)if(c.nodeType<11&&(g?g.index(c)>-1:1===c.nodeType&&m.find.matchesSelector(c,a))){f.push(c);break}return this.pushStack(f.length>1?m.unique(f):f)},index:function(a){return a?"string"==typeof a?m.inArray(this[0],m(a)):m.inArray(a.jquery?a[0]:a,this):this[0]&&this[0].parentNode?this.first().prevAll().length:-1},add:function(a,b){return this.pushStack(m.unique(m.merge(this.get(),m(a,b))))},addBack:function(a){return this.add(null==a?this.prevObject:this.prevObject.filter(a))}});function D(a,b){do a=a[b];while(a&&1!==a.nodeType);return a}m.each({parent:function(a){var b=a.parentNode;return b&&11!==b.nodeType?b:null},parents:function(a){return m.dir(a,"parentNode")},parentsUntil:function(a,b,c){return m.dir(a,"parentNode",c)},next:function(a){return D(a,"nextSibling")},prev:function(a){return D(a,"previousSibling")},nextAll:function(a){return m.dir(a,"nextSibling")},prevAll:function(a){return m.dir(a,"previousSibling")},nextUntil:function(a,b,c){return m.dir(a,"nextSibling",c)},prevUntil:function(a,b,c){return m.dir(a,"previousSibling",c)},siblings:function(a){return m.sibling((a.parentNode||{}).firstChild,a)},children:function(a){return m.sibling(a.firstChild)},contents:function(a){return m.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:m.merge([],a.childNodes)}},function(a,b){m.fn[a]=function(c,d){var e=m.map(this,b,c);return"Until"!==a.slice(-5)&&(d=c),d&&"string"==typeof d&&(e=m.filter(d,e)),this.length>1&&(C[a]||(e=m.unique(e)),B.test(a)&&(e=e.reverse())),this.pushStack(e)}});var E=/\S+/g,F={};function G(a){var b=F[a]={};return m.each(a.match(E)||[],function(a,c){b[c]=!0}),b}m.Callbacks=function(a){a="string"==typeof a?F[a]||G(a):m.extend({},a);var b,c,d,e,f,g,h=[],i=!a.once&&[],j=function(l){for(c=a.memory&&l,d=!0,f=g||0,g=0,e=h.length,b=!0;h&&e>f;f++)if(h[f].apply(l[0],l[1])===!1&&a.stopOnFalse){c=!1;break}b=!1,h&&(i?i.length&&j(i.shift()):c?h=[]:k.disable())},k={add:function(){if(h){var d=h.length;!function f(b){m.each(b,function(b,c){var d=m.type(c);"function"===d?a.unique&&k.has(c)||h.push(c):c&&c.length&&"string"!==d&&f(c)})}(arguments),b?e=h.length:c&&(g=d,j(c))}return this},remove:function(){return h&&m.each(arguments,function(a,c){var d;while((d=m.inArray(c,h,d))>-1)h.splice(d,1),b&&(e>=d&&e--,f>=d&&f--)}),this},has:function(a){return a?m.inArray(a,h)>-1:!(!h||!h.length)},empty:function(){return h=[],e=0,this},disable:function(){return h=i=c=void 0,this},disabled:function(){return!h},lock:function(){return i=void 0,c||k.disable(),this},locked:function(){return!i},fireWith:function(a,c){return!h||d&&!i||(c=c||[],c=[a,c.slice?c.slice():c],b?i.push(c):j(c)),this},fire:function(){return k.fireWith(this,arguments),this},fired:function(){return!!d}};return k},m.extend({Deferred:function(a){var b=[["resolve","done",m.Callbacks("once memory"),"resolved"],["reject","fail",m.Callbacks("once memory"),"rejected"],["notify","progress",m.Callbacks("memory")]],c="pending",d={state:function(){return c},always:function(){return e.done(arguments).fail(arguments),this},then:function(){var a=arguments;return m.Deferred(function(c){m.each(b,function(b,f){var g=m.isFunction(a[b])&&a[b];e[f[1]](function(){var a=g&&g.apply(this,arguments);a&&m.isFunction(a.promise)?a.promise().done(c.resolve).fail(c.reject).progress(c.notify):c[f[0]+"With"](this===d?c.promise():this,g?[a]:arguments)})}),a=null}).promise()},promise:function(a){return null!=a?m.extend(a,d):d}},e={};return d.pipe=d.then,m.each(b,function(a,f){var g=f[2],h=f[3];d[f[1]]=g.add,h&&g.add(function(){c=h},b[1^a][2].disable,b[2][2].lock),e[f[0]]=function(){return e[f[0]+"With"](this===e?d:this,arguments),this},e[f[0]+"With"]=g.fireWith}),d.promise(e),a&&a.call(e,e),e},when:function(a){var b=0,c=d.call(arguments),e=c.length,f=1!==e||a&&m.isFunction(a.promise)?e:0,g=1===f?a:m.Deferred(),h=function(a,b,c){return function(e){b[a]=this,c[a]=arguments.length>1?d.call(arguments):e,c===i?g.notifyWith(b,c):--f||g.resolveWith(b,c)}},i,j,k;if(e>1)for(i=new Array(e),j=new Array(e),k=new Array(e);e>b;b++)c[b]&&m.isFunction(c[b].promise)?c[b].promise().done(h(b,k,c)).fail(g.reject).progress(h(b,j,i)):--f;return f||g.resolveWith(k,c),g.promise()}});var H;m.fn.ready=function(a){return m.ready.promise().done(a),this},m.extend({isReady:!1,readyWait:1,holdReady:function(a){a?m.readyWait++:m.ready(!0)},ready:function(a){if(a===!0?!--m.readyWait:!m.isReady){if(!y.body)return setTimeout(m.ready);m.isReady=!0,a!==!0&&--m.readyWait>0||(H.resolveWith(y,[m]),m.fn.triggerHandler&&(m(y).triggerHandler("ready"),m(y).off("ready")))}}});function I(){y.addEventListener?(y.removeEventListener("DOMContentLoaded",J,!1),a.removeEventListener("load",J,!1)):(y.detachEvent("onreadystatechange",J),a.detachEvent("onload",J))}function J(){(y.addEventListener||"load"===event.type||"complete"===y.readyState)&&(I(),m.ready())}m.ready.promise=function(b){if(!H)if(H=m.Deferred(),"complete"===y.readyState)setTimeout(m.ready);else if(y.addEventListener)y.addEventListener("DOMContentLoaded",J,!1),a.addEventListener("load",J,!1);else{y.attachEvent("onreadystatechange",J),a.attachEvent("onload",J);var c=!1;try{c=null==a.frameElement&&y.documentElement}catch(d){}c&&c.doScroll&&!function e(){if(!m.isReady){try{c.doScroll("left")}catch(a){return setTimeout(e,50)}I(),m.ready()}}()}return H.promise(b)};var K="undefined",L;for(L in m(k))break;k.ownLast="0"!==L,k.inlineBlockNeedsLayout=!1,m(function(){var a,b,c,d;c=y.getElementsByTagName("body")[0],c&&c.style&&(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),typeof b.style.zoom!==K&&(b.style.cssText="display:inline;margin:0;border:0;padding:1px;width:1px;zoom:1",k.inlineBlockNeedsLayout=a=3===b.offsetWidth,a&&(c.style.zoom=1)),c.removeChild(d))}),function(){var a=y.createElement("div");if(null==k.deleteExpando){k.deleteExpando=!0;try{delete a.test}catch(b){k.deleteExpando=!1}}a=null}(),m.acceptData=function(a){var b=m.noData[(a.nodeName+" ").toLowerCase()],c=+a.nodeType||1;return 1!==c&&9!==c?!1:!b||b!==!0&&a.getAttribute("classid")===b};var M=/^(?:\{[\w\W]*\}|\[[\w\W]*\])$/,N=/([A-Z])/g;function O(a,b,c){if(void 0===c&&1===a.nodeType){var d="data-"+b.replace(N,"-$1").toLowerCase();if(c=a.getAttribute(d),"string"==typeof c){try{c="true"===c?!0:"false"===c?!1:"null"===c?null:+c+""===c?+c:M.test(c)?m.parseJSON(c):c}catch(e){}m.data(a,b,c)}else c=void 0}return c}function P(a){var b;for(b in a)if(("data"!==b||!m.isEmptyObject(a[b]))&&"toJSON"!==b)return!1;return!0}function Q(a,b,d,e){if(m.acceptData(a)){var f,g,h=m.expando,i=a.nodeType,j=i?m.cache:a,k=i?a[h]:a[h]&&h;
if(k&&j[k]&&(e||j[k].data)||void 0!==d||"string"!=typeof b)return k||(k=i?a[h]=c.pop()||m.guid++:h),j[k]||(j[k]=i?{}:{toJSON:m.noop}),("object"==typeof b||"function"==typeof b)&&(e?j[k]=m.extend(j[k],b):j[k].data=m.extend(j[k].data,b)),g=j[k],e||(g.data||(g.data={}),g=g.data),void 0!==d&&(g[m.camelCase(b)]=d),"string"==typeof b?(f=g[b],null==f&&(f=g[m.camelCase(b)])):f=g,f}}function R(a,b,c){if(m.acceptData(a)){var d,e,f=a.nodeType,g=f?m.cache:a,h=f?a[m.expando]:m.expando;if(g[h]){if(b&&(d=c?g[h]:g[h].data)){m.isArray(b)?b=b.concat(m.map(b,m.camelCase)):b in d?b=[b]:(b=m.camelCase(b),b=b in d?[b]:b.split(" ")),e=b.length;while(e--)delete d[b[e]];if(c?!P(d):!m.isEmptyObject(d))return}(c||(delete g[h].data,P(g[h])))&&(f?m.cleanData([a],!0):k.deleteExpando||g!=g.window?delete g[h]:g[h]=null)}}}m.extend({cache:{},noData:{"applet ":!0,"embed ":!0,"object ":"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"},hasData:function(a){return a=a.nodeType?m.cache[a[m.expando]]:a[m.expando],!!a&&!P(a)},data:function(a,b,c){return Q(a,b,c)},removeData:function(a,b){return R(a,b)},_data:function(a,b,c){return Q(a,b,c,!0)},_removeData:function(a,b){return R(a,b,!0)}}),m.fn.extend({data:function(a,b){var c,d,e,f=this[0],g=f&&f.attributes;if(void 0===a){if(this.length&&(e=m.data(f),1===f.nodeType&&!m._data(f,"parsedAttrs"))){c=g.length;while(c--)g[c]&&(d=g[c].name,0===d.indexOf("data-")&&(d=m.camelCase(d.slice(5)),O(f,d,e[d])));m._data(f,"parsedAttrs",!0)}return e}return"object"==typeof a?this.each(function(){m.data(this,a)}):arguments.length>1?this.each(function(){m.data(this,a,b)}):f?O(f,a,m.data(f,a)):void 0},removeData:function(a){return this.each(function(){m.removeData(this,a)})}}),m.extend({queue:function(a,b,c){var d;return a?(b=(b||"fx")+"queue",d=m._data(a,b),c&&(!d||m.isArray(c)?d=m._data(a,b,m.makeArray(c)):d.push(c)),d||[]):void 0},dequeue:function(a,b){b=b||"fx";var c=m.queue(a,b),d=c.length,e=c.shift(),f=m._queueHooks(a,b),g=function(){m.dequeue(a,b)};"inprogress"===e&&(e=c.shift(),d--),e&&("fx"===b&&c.unshift("inprogress"),delete f.stop,e.call(a,g,f)),!d&&f&&f.empty.fire()},_queueHooks:function(a,b){var c=b+"queueHooks";return m._data(a,c)||m._data(a,c,{empty:m.Callbacks("once memory").add(function(){m._removeData(a,b+"queue"),m._removeData(a,c)})})}}),m.fn.extend({queue:function(a,b){var c=2;return"string"!=typeof a&&(b=a,a="fx",c--),arguments.length<c?m.queue(this[0],a):void 0===b?this:this.each(function(){var c=m.queue(this,a,b);m._queueHooks(this,a),"fx"===a&&"inprogress"!==c[0]&&m.dequeue(this,a)})},dequeue:function(a){return this.each(function(){m.dequeue(this,a)})},clearQueue:function(a){return this.queue(a||"fx",[])},promise:function(a,b){var c,d=1,e=m.Deferred(),f=this,g=this.length,h=function(){--d||e.resolveWith(f,[f])};"string"!=typeof a&&(b=a,a=void 0),a=a||"fx";while(g--)c=m._data(f[g],a+"queueHooks"),c&&c.empty&&(d++,c.empty.add(h));return h(),e.promise(b)}});var S=/[+-]?(?:\d*\.|)\d+(?:[eE][+-]?\d+|)/.source,T=["Top","Right","Bottom","Left"],U=function(a,b){return a=b||a,"none"===m.css(a,"display")||!m.contains(a.ownerDocument,a)},V=m.access=function(a,b,c,d,e,f,g){var h=0,i=a.length,j=null==c;if("object"===m.type(c)){e=!0;for(h in c)m.access(a,b,h,c[h],!0,f,g)}else if(void 0!==d&&(e=!0,m.isFunction(d)||(g=!0),j&&(g?(b.call(a,d),b=null):(j=b,b=function(a,b,c){return j.call(m(a),c)})),b))for(;i>h;h++)b(a[h],c,g?d:d.call(a[h],h,b(a[h],c)));return e?a:j?b.call(a):i?b(a[0],c):f},W=/^(?:checkbox|radio)$/i;!function(){var a=y.createElement("input"),b=y.createElement("div"),c=y.createDocumentFragment();if(b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",k.leadingWhitespace=3===b.firstChild.nodeType,k.tbody=!b.getElementsByTagName("tbody").length,k.htmlSerialize=!!b.getElementsByTagName("link").length,k.html5Clone="<:nav></:nav>"!==y.createElement("nav").cloneNode(!0).outerHTML,a.type="checkbox",a.checked=!0,c.appendChild(a),k.appendChecked=a.checked,b.innerHTML="<textarea>x</textarea>",k.noCloneChecked=!!b.cloneNode(!0).lastChild.defaultValue,c.appendChild(b),b.innerHTML="<input type='radio' checked='checked' name='t'/>",k.checkClone=b.cloneNode(!0).cloneNode(!0).lastChild.checked,k.noCloneEvent=!0,b.attachEvent&&(b.attachEvent("onclick",function(){k.noCloneEvent=!1}),b.cloneNode(!0).click()),null==k.deleteExpando){k.deleteExpando=!0;try{delete b.test}catch(d){k.deleteExpando=!1}}}(),function(){var b,c,d=y.createElement("div");for(b in{submit:!0,change:!0,focusin:!0})c="on"+b,(k[b+"Bubbles"]=c in a)||(d.setAttribute(c,"t"),k[b+"Bubbles"]=d.attributes[c].expando===!1);d=null}();var X=/^(?:input|select|textarea)$/i,Y=/^key/,Z=/^(?:mouse|pointer|contextmenu)|click/,$=/^(?:focusinfocus|focusoutblur)$/,_=/^([^.]*)(?:\.(.+)|)$/;function ab(){return!0}function bb(){return!1}function cb(){try{return y.activeElement}catch(a){}}m.event={global:{},add:function(a,b,c,d,e){var f,g,h,i,j,k,l,n,o,p,q,r=m._data(a);if(r){c.handler&&(i=c,c=i.handler,e=i.selector),c.guid||(c.guid=m.guid++),(g=r.events)||(g=r.events={}),(k=r.handle)||(k=r.handle=function(a){return typeof m===K||a&&m.event.triggered===a.type?void 0:m.event.dispatch.apply(k.elem,arguments)},k.elem=a),b=(b||"").match(E)||[""],h=b.length;while(h--)f=_.exec(b[h])||[],o=q=f[1],p=(f[2]||"").split(".").sort(),o&&(j=m.event.special[o]||{},o=(e?j.delegateType:j.bindType)||o,j=m.event.special[o]||{},l=m.extend({type:o,origType:q,data:d,handler:c,guid:c.guid,selector:e,needsContext:e&&m.expr.match.needsContext.test(e),namespace:p.join(".")},i),(n=g[o])||(n=g[o]=[],n.delegateCount=0,j.setup&&j.setup.call(a,d,p,k)!==!1||(a.addEventListener?a.addEventListener(o,k,!1):a.attachEvent&&a.attachEvent("on"+o,k))),j.add&&(j.add.call(a,l),l.handler.guid||(l.handler.guid=c.guid)),e?n.splice(n.delegateCount++,0,l):n.push(l),m.event.global[o]=!0);a=null}},remove:function(a,b,c,d,e){var f,g,h,i,j,k,l,n,o,p,q,r=m.hasData(a)&&m._data(a);if(r&&(k=r.events)){b=(b||"").match(E)||[""],j=b.length;while(j--)if(h=_.exec(b[j])||[],o=q=h[1],p=(h[2]||"").split(".").sort(),o){l=m.event.special[o]||{},o=(d?l.delegateType:l.bindType)||o,n=k[o]||[],h=h[2]&&new RegExp("(^|\\.)"+p.join("\\.(?:.*\\.|)")+"(\\.|$)"),i=f=n.length;while(f--)g=n[f],!e&&q!==g.origType||c&&c.guid!==g.guid||h&&!h.test(g.namespace)||d&&d!==g.selector&&("**"!==d||!g.selector)||(n.splice(f,1),g.selector&&n.delegateCount--,l.remove&&l.remove.call(a,g));i&&!n.length&&(l.teardown&&l.teardown.call(a,p,r.handle)!==!1||m.removeEvent(a,o,r.handle),delete k[o])}else for(o in k)m.event.remove(a,o+b[j],c,d,!0);m.isEmptyObject(k)&&(delete r.handle,m._removeData(a,"events"))}},trigger:function(b,c,d,e){var f,g,h,i,k,l,n,o=[d||y],p=j.call(b,"type")?b.type:b,q=j.call(b,"namespace")?b.namespace.split("."):[];if(h=l=d=d||y,3!==d.nodeType&&8!==d.nodeType&&!$.test(p+m.event.triggered)&&(p.indexOf(".")>=0&&(q=p.split("."),p=q.shift(),q.sort()),g=p.indexOf(":")<0&&"on"+p,b=b[m.expando]?b:new m.Event(p,"object"==typeof b&&b),b.isTrigger=e?2:3,b.namespace=q.join("."),b.namespace_re=b.namespace?new RegExp("(^|\\.)"+q.join("\\.(?:.*\\.|)")+"(\\.|$)"):null,b.result=void 0,b.target||(b.target=d),c=null==c?[b]:m.makeArray(c,[b]),k=m.event.special[p]||{},e||!k.trigger||k.trigger.apply(d,c)!==!1)){if(!e&&!k.noBubble&&!m.isWindow(d)){for(i=k.delegateType||p,$.test(i+p)||(h=h.parentNode);h;h=h.parentNode)o.push(h),l=h;l===(d.ownerDocument||y)&&o.push(l.defaultView||l.parentWindow||a)}n=0;while((h=o[n++])&&!b.isPropagationStopped())b.type=n>1?i:k.bindType||p,f=(m._data(h,"events")||{})[b.type]&&m._data(h,"handle"),f&&f.apply(h,c),f=g&&h[g],f&&f.apply&&m.acceptData(h)&&(b.result=f.apply(h,c),b.result===!1&&b.preventDefault());if(b.type=p,!e&&!b.isDefaultPrevented()&&(!k._default||k._default.apply(o.pop(),c)===!1)&&m.acceptData(d)&&g&&d[p]&&!m.isWindow(d)){l=d[g],l&&(d[g]=null),m.event.triggered=p;try{d[p]()}catch(r){}m.event.triggered=void 0,l&&(d[g]=l)}return b.result}},dispatch:function(a){a=m.event.fix(a);var b,c,e,f,g,h=[],i=d.call(arguments),j=(m._data(this,"events")||{})[a.type]||[],k=m.event.special[a.type]||{};if(i[0]=a,a.delegateTarget=this,!k.preDispatch||k.preDispatch.call(this,a)!==!1){h=m.event.handlers.call(this,a,j),b=0;while((f=h[b++])&&!a.isPropagationStopped()){a.currentTarget=f.elem,g=0;while((e=f.handlers[g++])&&!a.isImmediatePropagationStopped())(!a.namespace_re||a.namespace_re.test(e.namespace))&&(a.handleObj=e,a.data=e.data,c=((m.event.special[e.origType]||{}).handle||e.handler).apply(f.elem,i),void 0!==c&&(a.result=c)===!1&&(a.preventDefault(),a.stopPropagation()))}return k.postDispatch&&k.postDispatch.call(this,a),a.result}},handlers:function(a,b){var c,d,e,f,g=[],h=b.delegateCount,i=a.target;if(h&&i.nodeType&&(!a.button||"click"!==a.type))for(;i!=this;i=i.parentNode||this)if(1===i.nodeType&&(i.disabled!==!0||"click"!==a.type)){for(e=[],f=0;h>f;f++)d=b[f],c=d.selector+" ",void 0===e[c]&&(e[c]=d.needsContext?m(c,this).index(i)>=0:m.find(c,this,null,[i]).length),e[c]&&e.push(d);e.length&&g.push({elem:i,handlers:e})}return h<b.length&&g.push({elem:this,handlers:b.slice(h)}),g},fix:function(a){if(a[m.expando])return a;var b,c,d,e=a.type,f=a,g=this.fixHooks[e];g||(this.fixHooks[e]=g=Z.test(e)?this.mouseHooks:Y.test(e)?this.keyHooks:{}),d=g.props?this.props.concat(g.props):this.props,a=new m.Event(f),b=d.length;while(b--)c=d[b],a[c]=f[c];return a.target||(a.target=f.srcElement||y),3===a.target.nodeType&&(a.target=a.target.parentNode),a.metaKey=!!a.metaKey,g.filter?g.filter(a,f):a},props:"altKey bubbles cancelable ctrlKey currentTarget eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),fixHooks:{},keyHooks:{props:"char charCode key keyCode".split(" "),filter:function(a,b){return null==a.which&&(a.which=null!=b.charCode?b.charCode:b.keyCode),a}},mouseHooks:{props:"button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),filter:function(a,b){var c,d,e,f=b.button,g=b.fromElement;return null==a.pageX&&null!=b.clientX&&(d=a.target.ownerDocument||y,e=d.documentElement,c=d.body,a.pageX=b.clientX+(e&&e.scrollLeft||c&&c.scrollLeft||0)-(e&&e.clientLeft||c&&c.clientLeft||0),a.pageY=b.clientY+(e&&e.scrollTop||c&&c.scrollTop||0)-(e&&e.clientTop||c&&c.clientTop||0)),!a.relatedTarget&&g&&(a.relatedTarget=g===a.target?b.toElement:g),a.which||void 0===f||(a.which=1&f?1:2&f?3:4&f?2:0),a}},special:{load:{noBubble:!0},focus:{trigger:function(){if(this!==cb()&&this.focus)try{return this.focus(),!1}catch(a){}},delegateType:"focusin"},blur:{trigger:function(){return this===cb()&&this.blur?(this.blur(),!1):void 0},delegateType:"focusout"},click:{trigger:function(){return m.nodeName(this,"input")&&"checkbox"===this.type&&this.click?(this.click(),!1):void 0},_default:function(a){return m.nodeName(a.target,"a")}},beforeunload:{postDispatch:function(a){void 0!==a.result&&a.originalEvent&&(a.originalEvent.returnValue=a.result)}}},simulate:function(a,b,c,d){var e=m.extend(new m.Event,c,{type:a,isSimulated:!0,originalEvent:{}});d?m.event.trigger(e,null,b):m.event.dispatch.call(b,e),e.isDefaultPrevented()&&c.preventDefault()}},m.removeEvent=y.removeEventListener?function(a,b,c){a.removeEventListener&&a.removeEventListener(b,c,!1)}:function(a,b,c){var d="on"+b;a.detachEvent&&(typeof a[d]===K&&(a[d]=null),a.detachEvent(d,c))},m.Event=function(a,b){return this instanceof m.Event?(a&&a.type?(this.originalEvent=a,this.type=a.type,this.isDefaultPrevented=a.defaultPrevented||void 0===a.defaultPrevented&&a.returnValue===!1?ab:bb):this.type=a,b&&m.extend(this,b),this.timeStamp=a&&a.timeStamp||m.now(),void(this[m.expando]=!0)):new m.Event(a,b)},m.Event.prototype={isDefaultPrevented:bb,isPropagationStopped:bb,isImmediatePropagationStopped:bb,preventDefault:function(){var a=this.originalEvent;this.isDefaultPrevented=ab,a&&(a.preventDefault?a.preventDefault():a.returnValue=!1)},stopPropagation:function(){var a=this.originalEvent;this.isPropagationStopped=ab,a&&(a.stopPropagation&&a.stopPropagation(),a.cancelBubble=!0)},stopImmediatePropagation:function(){var a=this.originalEvent;this.isImmediatePropagationStopped=ab,a&&a.stopImmediatePropagation&&a.stopImmediatePropagation(),this.stopPropagation()}},m.each({mouseenter:"mouseover",mouseleave:"mouseout",pointerenter:"pointerover",pointerleave:"pointerout"},function(a,b){m.event.special[a]={delegateType:b,bindType:b,handle:function(a){var c,d=this,e=a.relatedTarget,f=a.handleObj;return(!e||e!==d&&!m.contains(d,e))&&(a.type=f.origType,c=f.handler.apply(this,arguments),a.type=b),c}}}),k.submitBubbles||(m.event.special.submit={setup:function(){return m.nodeName(this,"form")?!1:void m.event.add(this,"click._submit keypress._submit",function(a){var b=a.target,c=m.nodeName(b,"input")||m.nodeName(b,"button")?b.form:void 0;c&&!m._data(c,"submitBubbles")&&(m.event.add(c,"submit._submit",function(a){a._submit_bubble=!0}),m._data(c,"submitBubbles",!0))})},postDispatch:function(a){a._submit_bubble&&(delete a._submit_bubble,this.parentNode&&!a.isTrigger&&m.event.simulate("submit",this.parentNode,a,!0))},teardown:function(){return m.nodeName(this,"form")?!1:void m.event.remove(this,"._submit")}}),k.changeBubbles||(m.event.special.change={setup:function(){return X.test(this.nodeName)?(("checkbox"===this.type||"radio"===this.type)&&(m.event.add(this,"propertychange._change",function(a){"checked"===a.originalEvent.propertyName&&(this._just_changed=!0)}),m.event.add(this,"click._change",function(a){this._just_changed&&!a.isTrigger&&(this._just_changed=!1),m.event.simulate("change",this,a,!0)})),!1):void m.event.add(this,"beforeactivate._change",function(a){var b=a.target;X.test(b.nodeName)&&!m._data(b,"changeBubbles")&&(m.event.add(b,"change._change",function(a){!this.parentNode||a.isSimulated||a.isTrigger||m.event.simulate("change",this.parentNode,a,!0)}),m._data(b,"changeBubbles",!0))})},handle:function(a){var b=a.target;return this!==b||a.isSimulated||a.isTrigger||"radio"!==b.type&&"checkbox"!==b.type?a.handleObj.handler.apply(this,arguments):void 0},teardown:function(){return m.event.remove(this,"._change"),!X.test(this.nodeName)}}),k.focusinBubbles||m.each({focus:"focusin",blur:"focusout"},function(a,b){var c=function(a){m.event.simulate(b,a.target,m.event.fix(a),!0)};m.event.special[b]={setup:function(){var d=this.ownerDocument||this,e=m._data(d,b);e||d.addEventListener(a,c,!0),m._data(d,b,(e||0)+1)},teardown:function(){var d=this.ownerDocument||this,e=m._data(d,b)-1;e?m._data(d,b,e):(d.removeEventListener(a,c,!0),m._removeData(d,b))}}}),m.fn.extend({on:function(a,b,c,d,e){var f,g;if("object"==typeof a){"string"!=typeof b&&(c=c||b,b=void 0);for(f in a)this.on(f,b,c,a[f],e);return this}if(null==c&&null==d?(d=b,c=b=void 0):null==d&&("string"==typeof b?(d=c,c=void 0):(d=c,c=b,b=void 0)),d===!1)d=bb;else if(!d)return this;return 1===e&&(g=d,d=function(a){return m().off(a),g.apply(this,arguments)},d.guid=g.guid||(g.guid=m.guid++)),this.each(function(){m.event.add(this,a,d,c,b)})},one:function(a,b,c,d){return this.on(a,b,c,d,1)},off:function(a,b,c){var d,e;if(a&&a.preventDefault&&a.handleObj)return d=a.handleObj,m(a.delegateTarget).off(d.namespace?d.origType+"."+d.namespace:d.origType,d.selector,d.handler),this;if("object"==typeof a){for(e in a)this.off(e,b,a[e]);return this}return(b===!1||"function"==typeof b)&&(c=b,b=void 0),c===!1&&(c=bb),this.each(function(){m.event.remove(this,a,c,b)})},trigger:function(a,b){return this.each(function(){m.event.trigger(a,b,this)})},triggerHandler:function(a,b){var c=this[0];return c?m.event.trigger(a,b,c,!0):void 0}});function db(a){var b=eb.split("|"),c=a.createDocumentFragment();if(c.createElement)while(b.length)c.createElement(b.pop());return c}var eb="abbr|article|aside|audio|bdi|canvas|data|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",fb=/ jQuery\d+="(?:null|\d+)"/g,gb=new RegExp("<(?:"+eb+")[\\s/>]","i"),hb=/^\s+/,ib=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/gi,jb=/<([\w:]+)/,kb=/<tbody/i,lb=/<|&#?\w+;/,mb=/<(?:script|style|link)/i,nb=/checked\s*(?:[^=]|=\s*.checked.)/i,ob=/^$|\/(?:java|ecma)script/i,pb=/^true\/(.*)/,qb=/^\s*<!(?:\[CDATA\[|--)|(?:\]\]|--)>\s*$/g,rb={option:[1,"<select multiple='multiple'>","</select>"],legend:[1,"<fieldset>","</fieldset>"],area:[1,"<map>","</map>"],param:[1,"<object>","</object>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],_default:k.htmlSerialize?[0,"",""]:[1,"X<div>","</div>"]},sb=db(y),tb=sb.appendChild(y.createElement("div"));rb.optgroup=rb.option,rb.tbody=rb.tfoot=rb.colgroup=rb.caption=rb.thead,rb.th=rb.td;function ub(a,b){var c,d,e=0,f=typeof a.getElementsByTagName!==K?a.getElementsByTagName(b||"*"):typeof a.querySelectorAll!==K?a.querySelectorAll(b||"*"):void 0;if(!f)for(f=[],c=a.childNodes||a;null!=(d=c[e]);e++)!b||m.nodeName(d,b)?f.push(d):m.merge(f,ub(d,b));return void 0===b||b&&m.nodeName(a,b)?m.merge([a],f):f}function vb(a){W.test(a.type)&&(a.defaultChecked=a.checked)}function wb(a,b){return m.nodeName(a,"table")&&m.nodeName(11!==b.nodeType?b:b.firstChild,"tr")?a.getElementsByTagName("tbody")[0]||a.appendChild(a.ownerDocument.createElement("tbody")):a}function xb(a){return a.type=(null!==m.find.attr(a,"type"))+"/"+a.type,a}function yb(a){var b=pb.exec(a.type);return b?a.type=b[1]:a.removeAttribute("type"),a}function zb(a,b){for(var c,d=0;null!=(c=a[d]);d++)m._data(c,"globalEval",!b||m._data(b[d],"globalEval"))}function Ab(a,b){if(1===b.nodeType&&m.hasData(a)){var c,d,e,f=m._data(a),g=m._data(b,f),h=f.events;if(h){delete g.handle,g.events={};for(c in h)for(d=0,e=h[c].length;e>d;d++)m.event.add(b,c,h[c][d])}g.data&&(g.data=m.extend({},g.data))}}function Bb(a,b){var c,d,e;if(1===b.nodeType){if(c=b.nodeName.toLowerCase(),!k.noCloneEvent&&b[m.expando]){e=m._data(b);for(d in e.events)m.removeEvent(b,d,e.handle);b.removeAttribute(m.expando)}"script"===c&&b.text!==a.text?(xb(b).text=a.text,yb(b)):"object"===c?(b.parentNode&&(b.outerHTML=a.outerHTML),k.html5Clone&&a.innerHTML&&!m.trim(b.innerHTML)&&(b.innerHTML=a.innerHTML)):"input"===c&&W.test(a.type)?(b.defaultChecked=b.checked=a.checked,b.value!==a.value&&(b.value=a.value)):"option"===c?b.defaultSelected=b.selected=a.defaultSelected:("input"===c||"textarea"===c)&&(b.defaultValue=a.defaultValue)}}m.extend({clone:function(a,b,c){var d,e,f,g,h,i=m.contains(a.ownerDocument,a);if(k.html5Clone||m.isXMLDoc(a)||!gb.test("<"+a.nodeName+">")?f=a.cloneNode(!0):(tb.innerHTML=a.outerHTML,tb.removeChild(f=tb.firstChild)),!(k.noCloneEvent&&k.noCloneChecked||1!==a.nodeType&&11!==a.nodeType||m.isXMLDoc(a)))for(d=ub(f),h=ub(a),g=0;null!=(e=h[g]);++g)d[g]&&Bb(e,d[g]);if(b)if(c)for(h=h||ub(a),d=d||ub(f),g=0;null!=(e=h[g]);g++)Ab(e,d[g]);else Ab(a,f);return d=ub(f,"script"),d.length>0&&zb(d,!i&&ub(a,"script")),d=h=e=null,f},buildFragment:function(a,b,c,d){for(var e,f,g,h,i,j,l,n=a.length,o=db(b),p=[],q=0;n>q;q++)if(f=a[q],f||0===f)if("object"===m.type(f))m.merge(p,f.nodeType?[f]:f);else if(lb.test(f)){h=h||o.appendChild(b.createElement("div")),i=(jb.exec(f)||["",""])[1].toLowerCase(),l=rb[i]||rb._default,h.innerHTML=l[1]+f.replace(ib,"<$1></$2>")+l[2],e=l[0];while(e--)h=h.lastChild;if(!k.leadingWhitespace&&hb.test(f)&&p.push(b.createTextNode(hb.exec(f)[0])),!k.tbody){f="table"!==i||kb.test(f)?"<table>"!==l[1]||kb.test(f)?0:h:h.firstChild,e=f&&f.childNodes.length;while(e--)m.nodeName(j=f.childNodes[e],"tbody")&&!j.childNodes.length&&f.removeChild(j)}m.merge(p,h.childNodes),h.textContent="";while(h.firstChild)h.removeChild(h.firstChild);h=o.lastChild}else p.push(b.createTextNode(f));h&&o.removeChild(h),k.appendChecked||m.grep(ub(p,"input"),vb),q=0;while(f=p[q++])if((!d||-1===m.inArray(f,d))&&(g=m.contains(f.ownerDocument,f),h=ub(o.appendChild(f),"script"),g&&zb(h),c)){e=0;while(f=h[e++])ob.test(f.type||"")&&c.push(f)}return h=null,o},cleanData:function(a,b){for(var d,e,f,g,h=0,i=m.expando,j=m.cache,l=k.deleteExpando,n=m.event.special;null!=(d=a[h]);h++)if((b||m.acceptData(d))&&(f=d[i],g=f&&j[f])){if(g.events)for(e in g.events)n[e]?m.event.remove(d,e):m.removeEvent(d,e,g.handle);j[f]&&(delete j[f],l?delete d[i]:typeof d.removeAttribute!==K?d.removeAttribute(i):d[i]=null,c.push(f))}}}),m.fn.extend({text:function(a){return V(this,function(a){return void 0===a?m.text(this):this.empty().append((this[0]&&this[0].ownerDocument||y).createTextNode(a))},null,a,arguments.length)},append:function(){return this.domManip(arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=wb(this,a);b.appendChild(a)}})},prepend:function(){return this.domManip(arguments,function(a){if(1===this.nodeType||11===this.nodeType||9===this.nodeType){var b=wb(this,a);b.insertBefore(a,b.firstChild)}})},before:function(){return this.domManip(arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this)})},after:function(){return this.domManip(arguments,function(a){this.parentNode&&this.parentNode.insertBefore(a,this.nextSibling)})},remove:function(a,b){for(var c,d=a?m.filter(a,this):this,e=0;null!=(c=d[e]);e++)b||1!==c.nodeType||m.cleanData(ub(c)),c.parentNode&&(b&&m.contains(c.ownerDocument,c)&&zb(ub(c,"script")),c.parentNode.removeChild(c));return this},empty:function(){for(var a,b=0;null!=(a=this[b]);b++){1===a.nodeType&&m.cleanData(ub(a,!1));while(a.firstChild)a.removeChild(a.firstChild);a.options&&m.nodeName(a,"select")&&(a.options.length=0)}return this},clone:function(a,b){return a=null==a?!1:a,b=null==b?a:b,this.map(function(){return m.clone(this,a,b)})},html:function(a){return V(this,function(a){var b=this[0]||{},c=0,d=this.length;if(void 0===a)return 1===b.nodeType?b.innerHTML.replace(fb,""):void 0;if(!("string"!=typeof a||mb.test(a)||!k.htmlSerialize&&gb.test(a)||!k.leadingWhitespace&&hb.test(a)||rb[(jb.exec(a)||["",""])[1].toLowerCase()])){a=a.replace(ib,"<$1></$2>");try{for(;d>c;c++)b=this[c]||{},1===b.nodeType&&(m.cleanData(ub(b,!1)),b.innerHTML=a);b=0}catch(e){}}b&&this.empty().append(a)},null,a,arguments.length)},replaceWith:function(){var a=arguments[0];return this.domManip(arguments,function(b){a=this.parentNode,m.cleanData(ub(this)),a&&a.replaceChild(b,this)}),a&&(a.length||a.nodeType)?this:this.remove()},detach:function(a){return this.remove(a,!0)},domManip:function(a,b){a=e.apply([],a);var c,d,f,g,h,i,j=0,l=this.length,n=this,o=l-1,p=a[0],q=m.isFunction(p);if(q||l>1&&"string"==typeof p&&!k.checkClone&&nb.test(p))return this.each(function(c){var d=n.eq(c);q&&(a[0]=p.call(this,c,d.html())),d.domManip(a,b)});if(l&&(i=m.buildFragment(a,this[0].ownerDocument,!1,this),c=i.firstChild,1===i.childNodes.length&&(i=c),c)){for(g=m.map(ub(i,"script"),xb),f=g.length;l>j;j++)d=i,j!==o&&(d=m.clone(d,!0,!0),f&&m.merge(g,ub(d,"script"))),b.call(this[j],d,j);if(f)for(h=g[g.length-1].ownerDocument,m.map(g,yb),j=0;f>j;j++)d=g[j],ob.test(d.type||"")&&!m._data(d,"globalEval")&&m.contains(h,d)&&(d.src?m._evalUrl&&m._evalUrl(d.src):m.globalEval((d.text||d.textContent||d.innerHTML||"").replace(qb,"")));i=c=null}return this}}),m.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){m.fn[a]=function(a){for(var c,d=0,e=[],g=m(a),h=g.length-1;h>=d;d++)c=d===h?this:this.clone(!0),m(g[d])[b](c),f.apply(e,c.get());return this.pushStack(e)}});var Cb,Db={};function Eb(b,c){var d,e=m(c.createElement(b)).appendTo(c.body),f=a.getDefaultComputedStyle&&(d=a.getDefaultComputedStyle(e[0]))?d.display:m.css(e[0],"display");return e.detach(),f}function Fb(a){var b=y,c=Db[a];return c||(c=Eb(a,b),"none"!==c&&c||(Cb=(Cb||m("<iframe frameborder='0' width='0' height='0'/>")).appendTo(b.documentElement),b=(Cb[0].contentWindow||Cb[0].contentDocument).document,b.write(),b.close(),c=Eb(a,b),Cb.detach()),Db[a]=c),c}!function(){var a;k.shrinkWrapBlocks=function(){if(null!=a)return a;a=!1;var b,c,d;return c=y.getElementsByTagName("body")[0],c&&c.style?(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),typeof b.style.zoom!==K&&(b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:1px;width:1px;zoom:1",b.appendChild(y.createElement("div")).style.width="5px",a=3!==b.offsetWidth),c.removeChild(d),a):void 0}}();var Gb=/^margin/,Hb=new RegExp("^("+S+")(?!px)[a-z%]+$","i"),Ib,Jb,Kb=/^(top|right|bottom|left)$/;a.getComputedStyle?(Ib=function(a){return a.ownerDocument.defaultView.getComputedStyle(a,null)},Jb=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ib(a),g=c?c.getPropertyValue(b)||c[b]:void 0,c&&(""!==g||m.contains(a.ownerDocument,a)||(g=m.style(a,b)),Hb.test(g)&&Gb.test(b)&&(d=h.width,e=h.minWidth,f=h.maxWidth,h.minWidth=h.maxWidth=h.width=g,g=c.width,h.width=d,h.minWidth=e,h.maxWidth=f)),void 0===g?g:g+""}):y.documentElement.currentStyle&&(Ib=function(a){return a.currentStyle},Jb=function(a,b,c){var d,e,f,g,h=a.style;return c=c||Ib(a),g=c?c[b]:void 0,null==g&&h&&h[b]&&(g=h[b]),Hb.test(g)&&!Kb.test(b)&&(d=h.left,e=a.runtimeStyle,f=e&&e.left,f&&(e.left=a.currentStyle.left),h.left="fontSize"===b?"1em":g,g=h.pixelLeft+"px",h.left=d,f&&(e.left=f)),void 0===g?g:g+""||"auto"});function Lb(a,b){return{get:function(){var c=a();if(null!=c)return c?void delete this.get:(this.get=b).apply(this,arguments)}}}!function(){var b,c,d,e,f,g,h;if(b=y.createElement("div"),b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",d=b.getElementsByTagName("a")[0],c=d&&d.style){c.cssText="float:left;opacity:.5",k.opacity="0.5"===c.opacity,k.cssFloat=!!c.cssFloat,b.style.backgroundClip="content-box",b.cloneNode(!0).style.backgroundClip="",k.clearCloneStyle="content-box"===b.style.backgroundClip,k.boxSizing=""===c.boxSizing||""===c.MozBoxSizing||""===c.WebkitBoxSizing,m.extend(k,{reliableHiddenOffsets:function(){return null==g&&i(),g},boxSizingReliable:function(){return null==f&&i(),f},pixelPosition:function(){return null==e&&i(),e},reliableMarginRight:function(){return null==h&&i(),h}});function i(){var b,c,d,i;c=y.getElementsByTagName("body")[0],c&&c.style&&(b=y.createElement("div"),d=y.createElement("div"),d.style.cssText="position:absolute;border:0;width:0;height:0;top:0;left:-9999px",c.appendChild(d).appendChild(b),b.style.cssText="-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;display:block;margin-top:1%;top:1%;border:1px;padding:1px;width:4px;position:absolute",e=f=!1,h=!0,a.getComputedStyle&&(e="1%"!==(a.getComputedStyle(b,null)||{}).top,f="4px"===(a.getComputedStyle(b,null)||{width:"4px"}).width,i=b.appendChild(y.createElement("div")),i.style.cssText=b.style.cssText="-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;display:block;margin:0;border:0;padding:0",i.style.marginRight=i.style.width="0",b.style.width="1px",h=!parseFloat((a.getComputedStyle(i,null)||{}).marginRight)),b.innerHTML="<table><tr><td></td><td>t</td></tr></table>",i=b.getElementsByTagName("td"),i[0].style.cssText="margin:0;border:0;padding:0;display:none",g=0===i[0].offsetHeight,g&&(i[0].style.display="",i[1].style.display="none",g=0===i[0].offsetHeight),c.removeChild(d))}}}(),m.swap=function(a,b,c,d){var e,f,g={};for(f in b)g[f]=a.style[f],a.style[f]=b[f];e=c.apply(a,d||[]);for(f in b)a.style[f]=g[f];return e};var Mb=/alpha\([^)]*\)/i,Nb=/opacity\s*=\s*([^)]*)/,Ob=/^(none|table(?!-c[ea]).+)/,Pb=new RegExp("^("+S+")(.*)$","i"),Qb=new RegExp("^([+-])=("+S+")","i"),Rb={position:"absolute",visibility:"hidden",display:"block"},Sb={letterSpacing:"0",fontWeight:"400"},Tb=["Webkit","O","Moz","ms"];function Ub(a,b){if(b in a)return b;var c=b.charAt(0).toUpperCase()+b.slice(1),d=b,e=Tb.length;while(e--)if(b=Tb[e]+c,b in a)return b;return d}function Vb(a,b){for(var c,d,e,f=[],g=0,h=a.length;h>g;g++)d=a[g],d.style&&(f[g]=m._data(d,"olddisplay"),c=d.style.display,b?(f[g]||"none"!==c||(d.style.display=""),""===d.style.display&&U(d)&&(f[g]=m._data(d,"olddisplay",Fb(d.nodeName)))):(e=U(d),(c&&"none"!==c||!e)&&m._data(d,"olddisplay",e?c:m.css(d,"display"))));for(g=0;h>g;g++)d=a[g],d.style&&(b&&"none"!==d.style.display&&""!==d.style.display||(d.style.display=b?f[g]||"":"none"));return a}function Wb(a,b,c){var d=Pb.exec(b);return d?Math.max(0,d[1]-(c||0))+(d[2]||"px"):b}function Xb(a,b,c,d,e){for(var f=c===(d?"border":"content")?4:"width"===b?1:0,g=0;4>f;f+=2)"margin"===c&&(g+=m.css(a,c+T[f],!0,e)),d?("content"===c&&(g-=m.css(a,"padding"+T[f],!0,e)),"margin"!==c&&(g-=m.css(a,"border"+T[f]+"Width",!0,e))):(g+=m.css(a,"padding"+T[f],!0,e),"padding"!==c&&(g+=m.css(a,"border"+T[f]+"Width",!0,e)));return g}function Yb(a,b,c){var d=!0,e="width"===b?a.offsetWidth:a.offsetHeight,f=Ib(a),g=k.boxSizing&&"border-box"===m.css(a,"boxSizing",!1,f);if(0>=e||null==e){if(e=Jb(a,b,f),(0>e||null==e)&&(e=a.style[b]),Hb.test(e))return e;d=g&&(k.boxSizingReliable()||e===a.style[b]),e=parseFloat(e)||0}return e+Xb(a,b,c||(g?"border":"content"),d,f)+"px"}m.extend({cssHooks:{opacity:{get:function(a,b){if(b){var c=Jb(a,"opacity");return""===c?"1":c}}}},cssNumber:{columnCount:!0,fillOpacity:!0,flexGrow:!0,flexShrink:!0,fontWeight:!0,lineHeight:!0,opacity:!0,order:!0,orphans:!0,widows:!0,zIndex:!0,zoom:!0},cssProps:{"float":k.cssFloat?"cssFloat":"styleFloat"},style:function(a,b,c,d){if(a&&3!==a.nodeType&&8!==a.nodeType&&a.style){var e,f,g,h=m.camelCase(b),i=a.style;if(b=m.cssProps[h]||(m.cssProps[h]=Ub(i,h)),g=m.cssHooks[b]||m.cssHooks[h],void 0===c)return g&&"get"in g&&void 0!==(e=g.get(a,!1,d))?e:i[b];if(f=typeof c,"string"===f&&(e=Qb.exec(c))&&(c=(e[1]+1)*e[2]+parseFloat(m.css(a,b)),f="number"),null!=c&&c===c&&("number"!==f||m.cssNumber[h]||(c+="px"),k.clearCloneStyle||""!==c||0!==b.indexOf("background")||(i[b]="inherit"),!(g&&"set"in g&&void 0===(c=g.set(a,c,d)))))try{i[b]=c}catch(j){}}},css:function(a,b,c,d){var e,f,g,h=m.camelCase(b);return b=m.cssProps[h]||(m.cssProps[h]=Ub(a.style,h)),g=m.cssHooks[b]||m.cssHooks[h],g&&"get"in g&&(f=g.get(a,!0,c)),void 0===f&&(f=Jb(a,b,d)),"normal"===f&&b in Sb&&(f=Sb[b]),""===c||c?(e=parseFloat(f),c===!0||m.isNumeric(e)?e||0:f):f}}),m.each(["height","width"],function(a,b){m.cssHooks[b]={get:function(a,c,d){return c?Ob.test(m.css(a,"display"))&&0===a.offsetWidth?m.swap(a,Rb,function(){return Yb(a,b,d)}):Yb(a,b,d):void 0},set:function(a,c,d){var e=d&&Ib(a);return Wb(a,c,d?Xb(a,b,d,k.boxSizing&&"border-box"===m.css(a,"boxSizing",!1,e),e):0)}}}),k.opacity||(m.cssHooks.opacity={get:function(a,b){return Nb.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?.01*parseFloat(RegExp.$1)+"":b?"1":""},set:function(a,b){var c=a.style,d=a.currentStyle,e=m.isNumeric(b)?"alpha(opacity="+100*b+")":"",f=d&&d.filter||c.filter||"";c.zoom=1,(b>=1||""===b)&&""===m.trim(f.replace(Mb,""))&&c.removeAttribute&&(c.removeAttribute("filter"),""===b||d&&!d.filter)||(c.filter=Mb.test(f)?f.replace(Mb,e):f+" "+e)}}),m.cssHooks.marginRight=Lb(k.reliableMarginRight,function(a,b){return b?m.swap(a,{display:"inline-block"},Jb,[a,"marginRight"]):void 0}),m.each({margin:"",padding:"",border:"Width"},function(a,b){m.cssHooks[a+b]={expand:function(c){for(var d=0,e={},f="string"==typeof c?c.split(" "):[c];4>d;d++)e[a+T[d]+b]=f[d]||f[d-2]||f[0];return e}},Gb.test(a)||(m.cssHooks[a+b].set=Wb)}),m.fn.extend({css:function(a,b){return V(this,function(a,b,c){var d,e,f={},g=0;if(m.isArray(b)){for(d=Ib(a),e=b.length;e>g;g++)f[b[g]]=m.css(a,b[g],!1,d);return f}return void 0!==c?m.style(a,b,c):m.css(a,b)},a,b,arguments.length>1)},show:function(){return Vb(this,!0)},hide:function(){return Vb(this)},toggle:function(a){return"boolean"==typeof a?a?this.show():this.hide():this.each(function(){U(this)?m(this).show():m(this).hide()})}});function Zb(a,b,c,d,e){return new Zb.prototype.init(a,b,c,d,e)}m.Tween=Zb,Zb.prototype={constructor:Zb,init:function(a,b,c,d,e,f){this.elem=a,this.prop=c,this.easing=e||"swing",this.options=b,this.start=this.now=this.cur(),this.end=d,this.unit=f||(m.cssNumber[c]?"":"px")
},cur:function(){var a=Zb.propHooks[this.prop];return a&&a.get?a.get(this):Zb.propHooks._default.get(this)},run:function(a){var b,c=Zb.propHooks[this.prop];return this.pos=b=this.options.duration?m.easing[this.easing](a,this.options.duration*a,0,1,this.options.duration):a,this.now=(this.end-this.start)*b+this.start,this.options.step&&this.options.step.call(this.elem,this.now,this),c&&c.set?c.set(this):Zb.propHooks._default.set(this),this}},Zb.prototype.init.prototype=Zb.prototype,Zb.propHooks={_default:{get:function(a){var b;return null==a.elem[a.prop]||a.elem.style&&null!=a.elem.style[a.prop]?(b=m.css(a.elem,a.prop,""),b&&"auto"!==b?b:0):a.elem[a.prop]},set:function(a){m.fx.step[a.prop]?m.fx.step[a.prop](a):a.elem.style&&(null!=a.elem.style[m.cssProps[a.prop]]||m.cssHooks[a.prop])?m.style(a.elem,a.prop,a.now+a.unit):a.elem[a.prop]=a.now}}},Zb.propHooks.scrollTop=Zb.propHooks.scrollLeft={set:function(a){a.elem.nodeType&&a.elem.parentNode&&(a.elem[a.prop]=a.now)}},m.easing={linear:function(a){return a},swing:function(a){return.5-Math.cos(a*Math.PI)/2}},m.fx=Zb.prototype.init,m.fx.step={};var $b,_b,ac=/^(?:toggle|show|hide)$/,bc=new RegExp("^(?:([+-])=|)("+S+")([a-z%]*)$","i"),cc=/queueHooks$/,dc=[ic],ec={"*":[function(a,b){var c=this.createTween(a,b),d=c.cur(),e=bc.exec(b),f=e&&e[3]||(m.cssNumber[a]?"":"px"),g=(m.cssNumber[a]||"px"!==f&&+d)&&bc.exec(m.css(c.elem,a)),h=1,i=20;if(g&&g[3]!==f){f=f||g[3],e=e||[],g=+d||1;do h=h||".5",g/=h,m.style(c.elem,a,g+f);while(h!==(h=c.cur()/d)&&1!==h&&--i)}return e&&(g=c.start=+g||+d||0,c.unit=f,c.end=e[1]?g+(e[1]+1)*e[2]:+e[2]),c}]};function fc(){return setTimeout(function(){$b=void 0}),$b=m.now()}function gc(a,b){var c,d={height:a},e=0;for(b=b?1:0;4>e;e+=2-b)c=T[e],d["margin"+c]=d["padding"+c]=a;return b&&(d.opacity=d.width=a),d}function hc(a,b,c){for(var d,e=(ec[b]||[]).concat(ec["*"]),f=0,g=e.length;g>f;f++)if(d=e[f].call(c,b,a))return d}function ic(a,b,c){var d,e,f,g,h,i,j,l,n=this,o={},p=a.style,q=a.nodeType&&U(a),r=m._data(a,"fxshow");c.queue||(h=m._queueHooks(a,"fx"),null==h.unqueued&&(h.unqueued=0,i=h.empty.fire,h.empty.fire=function(){h.unqueued||i()}),h.unqueued++,n.always(function(){n.always(function(){h.unqueued--,m.queue(a,"fx").length||h.empty.fire()})})),1===a.nodeType&&("height"in b||"width"in b)&&(c.overflow=[p.overflow,p.overflowX,p.overflowY],j=m.css(a,"display"),l="none"===j?m._data(a,"olddisplay")||Fb(a.nodeName):j,"inline"===l&&"none"===m.css(a,"float")&&(k.inlineBlockNeedsLayout&&"inline"!==Fb(a.nodeName)?p.zoom=1:p.display="inline-block")),c.overflow&&(p.overflow="hidden",k.shrinkWrapBlocks()||n.always(function(){p.overflow=c.overflow[0],p.overflowX=c.overflow[1],p.overflowY=c.overflow[2]}));for(d in b)if(e=b[d],ac.exec(e)){if(delete b[d],f=f||"toggle"===e,e===(q?"hide":"show")){if("show"!==e||!r||void 0===r[d])continue;q=!0}o[d]=r&&r[d]||m.style(a,d)}else j=void 0;if(m.isEmptyObject(o))"inline"===("none"===j?Fb(a.nodeName):j)&&(p.display=j);else{r?"hidden"in r&&(q=r.hidden):r=m._data(a,"fxshow",{}),f&&(r.hidden=!q),q?m(a).show():n.done(function(){m(a).hide()}),n.done(function(){var b;m._removeData(a,"fxshow");for(b in o)m.style(a,b,o[b])});for(d in o)g=hc(q?r[d]:0,d,n),d in r||(r[d]=g.start,q&&(g.end=g.start,g.start="width"===d||"height"===d?1:0))}}function jc(a,b){var c,d,e,f,g;for(c in a)if(d=m.camelCase(c),e=b[d],f=a[c],m.isArray(f)&&(e=f[1],f=a[c]=f[0]),c!==d&&(a[d]=f,delete a[c]),g=m.cssHooks[d],g&&"expand"in g){f=g.expand(f),delete a[d];for(c in f)c in a||(a[c]=f[c],b[c]=e)}else b[d]=e}function kc(a,b,c){var d,e,f=0,g=dc.length,h=m.Deferred().always(function(){delete i.elem}),i=function(){if(e)return!1;for(var b=$b||fc(),c=Math.max(0,j.startTime+j.duration-b),d=c/j.duration||0,f=1-d,g=0,i=j.tweens.length;i>g;g++)j.tweens[g].run(f);return h.notifyWith(a,[j,f,c]),1>f&&i?c:(h.resolveWith(a,[j]),!1)},j=h.promise({elem:a,props:m.extend({},b),opts:m.extend(!0,{specialEasing:{}},c),originalProperties:b,originalOptions:c,startTime:$b||fc(),duration:c.duration,tweens:[],createTween:function(b,c){var d=m.Tween(a,j.opts,b,c,j.opts.specialEasing[b]||j.opts.easing);return j.tweens.push(d),d},stop:function(b){var c=0,d=b?j.tweens.length:0;if(e)return this;for(e=!0;d>c;c++)j.tweens[c].run(1);return b?h.resolveWith(a,[j,b]):h.rejectWith(a,[j,b]),this}}),k=j.props;for(jc(k,j.opts.specialEasing);g>f;f++)if(d=dc[f].call(j,a,k,j.opts))return d;return m.map(k,hc,j),m.isFunction(j.opts.start)&&j.opts.start.call(a,j),m.fx.timer(m.extend(i,{elem:a,anim:j,queue:j.opts.queue})),j.progress(j.opts.progress).done(j.opts.done,j.opts.complete).fail(j.opts.fail).always(j.opts.always)}m.Animation=m.extend(kc,{tweener:function(a,b){m.isFunction(a)?(b=a,a=["*"]):a=a.split(" ");for(var c,d=0,e=a.length;e>d;d++)c=a[d],ec[c]=ec[c]||[],ec[c].unshift(b)},prefilter:function(a,b){b?dc.unshift(a):dc.push(a)}}),m.speed=function(a,b,c){var d=a&&"object"==typeof a?m.extend({},a):{complete:c||!c&&b||m.isFunction(a)&&a,duration:a,easing:c&&b||b&&!m.isFunction(b)&&b};return d.duration=m.fx.off?0:"number"==typeof d.duration?d.duration:d.duration in m.fx.speeds?m.fx.speeds[d.duration]:m.fx.speeds._default,(null==d.queue||d.queue===!0)&&(d.queue="fx"),d.old=d.complete,d.complete=function(){m.isFunction(d.old)&&d.old.call(this),d.queue&&m.dequeue(this,d.queue)},d},m.fn.extend({fadeTo:function(a,b,c,d){return this.filter(U).css("opacity",0).show().end().animate({opacity:b},a,c,d)},animate:function(a,b,c,d){var e=m.isEmptyObject(a),f=m.speed(b,c,d),g=function(){var b=kc(this,m.extend({},a),f);(e||m._data(this,"finish"))&&b.stop(!0)};return g.finish=g,e||f.queue===!1?this.each(g):this.queue(f.queue,g)},stop:function(a,b,c){var d=function(a){var b=a.stop;delete a.stop,b(c)};return"string"!=typeof a&&(c=b,b=a,a=void 0),b&&a!==!1&&this.queue(a||"fx",[]),this.each(function(){var b=!0,e=null!=a&&a+"queueHooks",f=m.timers,g=m._data(this);if(e)g[e]&&g[e].stop&&d(g[e]);else for(e in g)g[e]&&g[e].stop&&cc.test(e)&&d(g[e]);for(e=f.length;e--;)f[e].elem!==this||null!=a&&f[e].queue!==a||(f[e].anim.stop(c),b=!1,f.splice(e,1));(b||!c)&&m.dequeue(this,a)})},finish:function(a){return a!==!1&&(a=a||"fx"),this.each(function(){var b,c=m._data(this),d=c[a+"queue"],e=c[a+"queueHooks"],f=m.timers,g=d?d.length:0;for(c.finish=!0,m.queue(this,a,[]),e&&e.stop&&e.stop.call(this,!0),b=f.length;b--;)f[b].elem===this&&f[b].queue===a&&(f[b].anim.stop(!0),f.splice(b,1));for(b=0;g>b;b++)d[b]&&d[b].finish&&d[b].finish.call(this);delete c.finish})}}),m.each(["toggle","show","hide"],function(a,b){var c=m.fn[b];m.fn[b]=function(a,d,e){return null==a||"boolean"==typeof a?c.apply(this,arguments):this.animate(gc(b,!0),a,d,e)}}),m.each({slideDown:gc("show"),slideUp:gc("hide"),slideToggle:gc("toggle"),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){m.fn[a]=function(a,c,d){return this.animate(b,a,c,d)}}),m.timers=[],m.fx.tick=function(){var a,b=m.timers,c=0;for($b=m.now();c<b.length;c++)a=b[c],a()||b[c]!==a||b.splice(c--,1);b.length||m.fx.stop(),$b=void 0},m.fx.timer=function(a){m.timers.push(a),a()?m.fx.start():m.timers.pop()},m.fx.interval=13,m.fx.start=function(){_b||(_b=setInterval(m.fx.tick,m.fx.interval))},m.fx.stop=function(){clearInterval(_b),_b=null},m.fx.speeds={slow:600,fast:200,_default:400},m.fn.delay=function(a,b){return a=m.fx?m.fx.speeds[a]||a:a,b=b||"fx",this.queue(b,function(b,c){var d=setTimeout(b,a);c.stop=function(){clearTimeout(d)}})},function(){var a,b,c,d,e;b=y.createElement("div"),b.setAttribute("className","t"),b.innerHTML="  <link/><table></table><a href='/a'>a</a><input type='checkbox'/>",d=b.getElementsByTagName("a")[0],c=y.createElement("select"),e=c.appendChild(y.createElement("option")),a=b.getElementsByTagName("input")[0],d.style.cssText="top:1px",k.getSetAttribute="t"!==b.className,k.style=/top/.test(d.getAttribute("style")),k.hrefNormalized="/a"===d.getAttribute("href"),k.checkOn=!!a.value,k.optSelected=e.selected,k.enctype=!!y.createElement("form").enctype,c.disabled=!0,k.optDisabled=!e.disabled,a=y.createElement("input"),a.setAttribute("value",""),k.input=""===a.getAttribute("value"),a.value="t",a.setAttribute("type","radio"),k.radioValue="t"===a.value}();var lc=/\r/g;m.fn.extend({val:function(a){var b,c,d,e=this[0];{if(arguments.length)return d=m.isFunction(a),this.each(function(c){var e;1===this.nodeType&&(e=d?a.call(this,c,m(this).val()):a,null==e?e="":"number"==typeof e?e+="":m.isArray(e)&&(e=m.map(e,function(a){return null==a?"":a+""})),b=m.valHooks[this.type]||m.valHooks[this.nodeName.toLowerCase()],b&&"set"in b&&void 0!==b.set(this,e,"value")||(this.value=e))});if(e)return b=m.valHooks[e.type]||m.valHooks[e.nodeName.toLowerCase()],b&&"get"in b&&void 0!==(c=b.get(e,"value"))?c:(c=e.value,"string"==typeof c?c.replace(lc,""):null==c?"":c)}}}),m.extend({valHooks:{option:{get:function(a){var b=m.find.attr(a,"value");return null!=b?b:m.trim(m.text(a))}},select:{get:function(a){for(var b,c,d=a.options,e=a.selectedIndex,f="select-one"===a.type||0>e,g=f?null:[],h=f?e+1:d.length,i=0>e?h:f?e:0;h>i;i++)if(c=d[i],!(!c.selected&&i!==e||(k.optDisabled?c.disabled:null!==c.getAttribute("disabled"))||c.parentNode.disabled&&m.nodeName(c.parentNode,"optgroup"))){if(b=m(c).val(),f)return b;g.push(b)}return g},set:function(a,b){var c,d,e=a.options,f=m.makeArray(b),g=e.length;while(g--)if(d=e[g],m.inArray(m.valHooks.option.get(d),f)>=0)try{d.selected=c=!0}catch(h){d.scrollHeight}else d.selected=!1;return c||(a.selectedIndex=-1),e}}}}),m.each(["radio","checkbox"],function(){m.valHooks[this]={set:function(a,b){return m.isArray(b)?a.checked=m.inArray(m(a).val(),b)>=0:void 0}},k.checkOn||(m.valHooks[this].get=function(a){return null===a.getAttribute("value")?"on":a.value})});var mc,nc,oc=m.expr.attrHandle,pc=/^(?:checked|selected)$/i,qc=k.getSetAttribute,rc=k.input;m.fn.extend({attr:function(a,b){return V(this,m.attr,a,b,arguments.length>1)},removeAttr:function(a){return this.each(function(){m.removeAttr(this,a)})}}),m.extend({attr:function(a,b,c){var d,e,f=a.nodeType;if(a&&3!==f&&8!==f&&2!==f)return typeof a.getAttribute===K?m.prop(a,b,c):(1===f&&m.isXMLDoc(a)||(b=b.toLowerCase(),d=m.attrHooks[b]||(m.expr.match.bool.test(b)?nc:mc)),void 0===c?d&&"get"in d&&null!==(e=d.get(a,b))?e:(e=m.find.attr(a,b),null==e?void 0:e):null!==c?d&&"set"in d&&void 0!==(e=d.set(a,c,b))?e:(a.setAttribute(b,c+""),c):void m.removeAttr(a,b))},removeAttr:function(a,b){var c,d,e=0,f=b&&b.match(E);if(f&&1===a.nodeType)while(c=f[e++])d=m.propFix[c]||c,m.expr.match.bool.test(c)?rc&&qc||!pc.test(c)?a[d]=!1:a[m.camelCase("default-"+c)]=a[d]=!1:m.attr(a,c,""),a.removeAttribute(qc?c:d)},attrHooks:{type:{set:function(a,b){if(!k.radioValue&&"radio"===b&&m.nodeName(a,"input")){var c=a.value;return a.setAttribute("type",b),c&&(a.value=c),b}}}}}),nc={set:function(a,b,c){return b===!1?m.removeAttr(a,c):rc&&qc||!pc.test(c)?a.setAttribute(!qc&&m.propFix[c]||c,c):a[m.camelCase("default-"+c)]=a[c]=!0,c}},m.each(m.expr.match.bool.source.match(/\w+/g),function(a,b){var c=oc[b]||m.find.attr;oc[b]=rc&&qc||!pc.test(b)?function(a,b,d){var e,f;return d||(f=oc[b],oc[b]=e,e=null!=c(a,b,d)?b.toLowerCase():null,oc[b]=f),e}:function(a,b,c){return c?void 0:a[m.camelCase("default-"+b)]?b.toLowerCase():null}}),rc&&qc||(m.attrHooks.value={set:function(a,b,c){return m.nodeName(a,"input")?void(a.defaultValue=b):mc&&mc.set(a,b,c)}}),qc||(mc={set:function(a,b,c){var d=a.getAttributeNode(c);return d||a.setAttributeNode(d=a.ownerDocument.createAttribute(c)),d.value=b+="","value"===c||b===a.getAttribute(c)?b:void 0}},oc.id=oc.name=oc.coords=function(a,b,c){var d;return c?void 0:(d=a.getAttributeNode(b))&&""!==d.value?d.value:null},m.valHooks.button={get:function(a,b){var c=a.getAttributeNode(b);return c&&c.specified?c.value:void 0},set:mc.set},m.attrHooks.contenteditable={set:function(a,b,c){mc.set(a,""===b?!1:b,c)}},m.each(["width","height"],function(a,b){m.attrHooks[b]={set:function(a,c){return""===c?(a.setAttribute(b,"auto"),c):void 0}}})),k.style||(m.attrHooks.style={get:function(a){return a.style.cssText||void 0},set:function(a,b){return a.style.cssText=b+""}});var sc=/^(?:input|select|textarea|button|object)$/i,tc=/^(?:a|area)$/i;m.fn.extend({prop:function(a,b){return V(this,m.prop,a,b,arguments.length>1)},removeProp:function(a){return a=m.propFix[a]||a,this.each(function(){try{this[a]=void 0,delete this[a]}catch(b){}})}}),m.extend({propFix:{"for":"htmlFor","class":"className"},prop:function(a,b,c){var d,e,f,g=a.nodeType;if(a&&3!==g&&8!==g&&2!==g)return f=1!==g||!m.isXMLDoc(a),f&&(b=m.propFix[b]||b,e=m.propHooks[b]),void 0!==c?e&&"set"in e&&void 0!==(d=e.set(a,c,b))?d:a[b]=c:e&&"get"in e&&null!==(d=e.get(a,b))?d:a[b]},propHooks:{tabIndex:{get:function(a){var b=m.find.attr(a,"tabindex");return b?parseInt(b,10):sc.test(a.nodeName)||tc.test(a.nodeName)&&a.href?0:-1}}}}),k.hrefNormalized||m.each(["href","src"],function(a,b){m.propHooks[b]={get:function(a){return a.getAttribute(b,4)}}}),k.optSelected||(m.propHooks.selected={get:function(a){var b=a.parentNode;return b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex),null}}),m.each(["tabIndex","readOnly","maxLength","cellSpacing","cellPadding","rowSpan","colSpan","useMap","frameBorder","contentEditable"],function(){m.propFix[this.toLowerCase()]=this}),k.enctype||(m.propFix.enctype="encoding");var uc=/[\t\r\n\f]/g;m.fn.extend({addClass:function(a){var b,c,d,e,f,g,h=0,i=this.length,j="string"==typeof a&&a;if(m.isFunction(a))return this.each(function(b){m(this).addClass(a.call(this,b,this.className))});if(j)for(b=(a||"").match(E)||[];i>h;h++)if(c=this[h],d=1===c.nodeType&&(c.className?(" "+c.className+" ").replace(uc," "):" ")){f=0;while(e=b[f++])d.indexOf(" "+e+" ")<0&&(d+=e+" ");g=m.trim(d),c.className!==g&&(c.className=g)}return this},removeClass:function(a){var b,c,d,e,f,g,h=0,i=this.length,j=0===arguments.length||"string"==typeof a&&a;if(m.isFunction(a))return this.each(function(b){m(this).removeClass(a.call(this,b,this.className))});if(j)for(b=(a||"").match(E)||[];i>h;h++)if(c=this[h],d=1===c.nodeType&&(c.className?(" "+c.className+" ").replace(uc," "):"")){f=0;while(e=b[f++])while(d.indexOf(" "+e+" ")>=0)d=d.replace(" "+e+" "," ");g=a?m.trim(d):"",c.className!==g&&(c.className=g)}return this},toggleClass:function(a,b){var c=typeof a;return"boolean"==typeof b&&"string"===c?b?this.addClass(a):this.removeClass(a):this.each(m.isFunction(a)?function(c){m(this).toggleClass(a.call(this,c,this.className,b),b)}:function(){if("string"===c){var b,d=0,e=m(this),f=a.match(E)||[];while(b=f[d++])e.hasClass(b)?e.removeClass(b):e.addClass(b)}else(c===K||"boolean"===c)&&(this.className&&m._data(this,"__className__",this.className),this.className=this.className||a===!1?"":m._data(this,"__className__")||"")})},hasClass:function(a){for(var b=" "+a+" ",c=0,d=this.length;d>c;c++)if(1===this[c].nodeType&&(" "+this[c].className+" ").replace(uc," ").indexOf(b)>=0)return!0;return!1}}),m.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "),function(a,b){m.fn[b]=function(a,c){return arguments.length>0?this.on(b,null,a,c):this.trigger(b)}}),m.fn.extend({hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)},bind:function(a,b,c){return this.on(a,null,b,c)},unbind:function(a,b){return this.off(a,null,b)},delegate:function(a,b,c,d){return this.on(b,a,c,d)},undelegate:function(a,b,c){return 1===arguments.length?this.off(a,"**"):this.off(b,a||"**",c)}});var vc=m.now(),wc=/\?/,xc=/(,)|(\[|{)|(}|])|"(?:[^"\\\r\n]|\\["\\\/bfnrt]|\\u[\da-fA-F]{4})*"\s*:?|true|false|null|-?(?!0\d)\d+(?:\.\d+|)(?:[eE][+-]?\d+|)/g;m.parseJSON=function(b){if(a.JSON&&a.JSON.parse)return a.JSON.parse(b+"");var c,d=null,e=m.trim(b+"");return e&&!m.trim(e.replace(xc,function(a,b,e,f){return c&&b&&(d=0),0===d?a:(c=e||b,d+=!f-!e,"")}))?Function("return "+e)():m.error("Invalid JSON: "+b)},m.parseXML=function(b){var c,d;if(!b||"string"!=typeof b)return null;try{a.DOMParser?(d=new DOMParser,c=d.parseFromString(b,"text/xml")):(c=new ActiveXObject("Microsoft.XMLDOM"),c.async="false",c.loadXML(b))}catch(e){c=void 0}return c&&c.documentElement&&!c.getElementsByTagName("parsererror").length||m.error("Invalid XML: "+b),c};var yc,zc,Ac=/#.*$/,Bc=/([?&])_=[^&]*/,Cc=/^(.*?):[ \t]*([^\r\n]*)\r?$/gm,Dc=/^(?:about|app|app-storage|.+-extension|file|res|widget):$/,Ec=/^(?:GET|HEAD)$/,Fc=/^\/\//,Gc=/^([\w.+-]+:)(?:\/\/(?:[^\/?#]*@|)([^\/?#:]*)(?::(\d+)|)|)/,Hc={},Ic={},Jc="*/".concat("*");try{zc=location.href}catch(Kc){zc=y.createElement("a"),zc.href="",zc=zc.href}yc=Gc.exec(zc.toLowerCase())||[];function Lc(a){return function(b,c){"string"!=typeof b&&(c=b,b="*");var d,e=0,f=b.toLowerCase().match(E)||[];if(m.isFunction(c))while(d=f[e++])"+"===d.charAt(0)?(d=d.slice(1)||"*",(a[d]=a[d]||[]).unshift(c)):(a[d]=a[d]||[]).push(c)}}function Mc(a,b,c,d){var e={},f=a===Ic;function g(h){var i;return e[h]=!0,m.each(a[h]||[],function(a,h){var j=h(b,c,d);return"string"!=typeof j||f||e[j]?f?!(i=j):void 0:(b.dataTypes.unshift(j),g(j),!1)}),i}return g(b.dataTypes[0])||!e["*"]&&g("*")}function Nc(a,b){var c,d,e=m.ajaxSettings.flatOptions||{};for(d in b)void 0!==b[d]&&((e[d]?a:c||(c={}))[d]=b[d]);return c&&m.extend(!0,a,c),a}function Oc(a,b,c){var d,e,f,g,h=a.contents,i=a.dataTypes;while("*"===i[0])i.shift(),void 0===e&&(e=a.mimeType||b.getResponseHeader("Content-Type"));if(e)for(g in h)if(h[g]&&h[g].test(e)){i.unshift(g);break}if(i[0]in c)f=i[0];else{for(g in c){if(!i[0]||a.converters[g+" "+i[0]]){f=g;break}d||(d=g)}f=f||d}return f?(f!==i[0]&&i.unshift(f),c[f]):void 0}function Pc(a,b,c,d){var e,f,g,h,i,j={},k=a.dataTypes.slice();if(k[1])for(g in a.converters)j[g.toLowerCase()]=a.converters[g];f=k.shift();while(f)if(a.responseFields[f]&&(c[a.responseFields[f]]=b),!i&&d&&a.dataFilter&&(b=a.dataFilter(b,a.dataType)),i=f,f=k.shift())if("*"===f)f=i;else if("*"!==i&&i!==f){if(g=j[i+" "+f]||j["* "+f],!g)for(e in j)if(h=e.split(" "),h[1]===f&&(g=j[i+" "+h[0]]||j["* "+h[0]])){g===!0?g=j[e]:j[e]!==!0&&(f=h[0],k.unshift(h[1]));break}if(g!==!0)if(g&&a["throws"])b=g(b);else try{b=g(b)}catch(l){return{state:"parsererror",error:g?l:"No conversion from "+i+" to "+f}}}return{state:"success",data:b}}m.extend({active:0,lastModified:{},etag:{},ajaxSettings:{url:zc,type:"GET",isLocal:Dc.test(yc[1]),global:!0,processData:!0,async:!0,contentType:"application/x-www-form-urlencoded; charset=UTF-8",accepts:{"*":Jc,text:"text/plain",html:"text/html",xml:"application/xml, text/xml",json:"application/json, text/javascript"},contents:{xml:/xml/,html:/html/,json:/json/},responseFields:{xml:"responseXML",text:"responseText",json:"responseJSON"},converters:{"* text":String,"text html":!0,"text json":m.parseJSON,"text xml":m.parseXML},flatOptions:{url:!0,context:!0}},ajaxSetup:function(a,b){return b?Nc(Nc(a,m.ajaxSettings),b):Nc(m.ajaxSettings,a)},ajaxPrefilter:Lc(Hc),ajaxTransport:Lc(Ic),ajax:function(a,b){"object"==typeof a&&(b=a,a=void 0),b=b||{};var c,d,e,f,g,h,i,j,k=m.ajaxSetup({},b),l=k.context||k,n=k.context&&(l.nodeType||l.jquery)?m(l):m.event,o=m.Deferred(),p=m.Callbacks("once memory"),q=k.statusCode||{},r={},s={},t=0,u="canceled",v={readyState:0,getResponseHeader:function(a){var b;if(2===t){if(!j){j={};while(b=Cc.exec(f))j[b[1].toLowerCase()]=b[2]}b=j[a.toLowerCase()]}return null==b?null:b},getAllResponseHeaders:function(){return 2===t?f:null},setRequestHeader:function(a,b){var c=a.toLowerCase();return t||(a=s[c]=s[c]||a,r[a]=b),this},overrideMimeType:function(a){return t||(k.mimeType=a),this},statusCode:function(a){var b;if(a)if(2>t)for(b in a)q[b]=[q[b],a[b]];else v.always(a[v.status]);return this},abort:function(a){var b=a||u;return i&&i.abort(b),x(0,b),this}};if(o.promise(v).complete=p.add,v.success=v.done,v.error=v.fail,k.url=((a||k.url||zc)+"").replace(Ac,"").replace(Fc,yc[1]+"//"),k.type=b.method||b.type||k.method||k.type,k.dataTypes=m.trim(k.dataType||"*").toLowerCase().match(E)||[""],null==k.crossDomain&&(c=Gc.exec(k.url.toLowerCase()),k.crossDomain=!(!c||c[1]===yc[1]&&c[2]===yc[2]&&(c[3]||("http:"===c[1]?"80":"443"))===(yc[3]||("http:"===yc[1]?"80":"443")))),k.data&&k.processData&&"string"!=typeof k.data&&(k.data=m.param(k.data,k.traditional)),Mc(Hc,k,b,v),2===t)return v;h=k.global,h&&0===m.active++&&m.event.trigger("ajaxStart"),k.type=k.type.toUpperCase(),k.hasContent=!Ec.test(k.type),e=k.url,k.hasContent||(k.data&&(e=k.url+=(wc.test(e)?"&":"?")+k.data,delete k.data),k.cache===!1&&(k.url=Bc.test(e)?e.replace(Bc,"$1_="+vc++):e+(wc.test(e)?"&":"?")+"_="+vc++)),k.ifModified&&(m.lastModified[e]&&v.setRequestHeader("If-Modified-Since",m.lastModified[e]),m.etag[e]&&v.setRequestHeader("If-None-Match",m.etag[e])),(k.data&&k.hasContent&&k.contentType!==!1||b.contentType)&&v.setRequestHeader("Content-Type",k.contentType),v.setRequestHeader("Accept",k.dataTypes[0]&&k.accepts[k.dataTypes[0]]?k.accepts[k.dataTypes[0]]+("*"!==k.dataTypes[0]?", "+Jc+"; q=0.01":""):k.accepts["*"]);for(d in k.headers)v.setRequestHeader(d,k.headers[d]);if(k.beforeSend&&(k.beforeSend.call(l,v,k)===!1||2===t))return v.abort();u="abort";for(d in{success:1,error:1,complete:1})v[d](k[d]);if(i=Mc(Ic,k,b,v)){v.readyState=1,h&&n.trigger("ajaxSend",[v,k]),k.async&&k.timeout>0&&(g=setTimeout(function(){v.abort("timeout")},k.timeout));try{t=1,i.send(r,x)}catch(w){if(!(2>t))throw w;x(-1,w)}}else x(-1,"No Transport");function x(a,b,c,d){var j,r,s,u,w,x=b;2!==t&&(t=2,g&&clearTimeout(g),i=void 0,f=d||"",v.readyState=a>0?4:0,j=a>=200&&300>a||304===a,c&&(u=Oc(k,v,c)),u=Pc(k,u,v,j),j?(k.ifModified&&(w=v.getResponseHeader("Last-Modified"),w&&(m.lastModified[e]=w),w=v.getResponseHeader("etag"),w&&(m.etag[e]=w)),204===a||"HEAD"===k.type?x="nocontent":304===a?x="notmodified":(x=u.state,r=u.data,s=u.error,j=!s)):(s=x,(a||!x)&&(x="error",0>a&&(a=0))),v.status=a,v.statusText=(b||x)+"",j?o.resolveWith(l,[r,x,v]):o.rejectWith(l,[v,x,s]),v.statusCode(q),q=void 0,h&&n.trigger(j?"ajaxSuccess":"ajaxError",[v,k,j?r:s]),p.fireWith(l,[v,x]),h&&(n.trigger("ajaxComplete",[v,k]),--m.active||m.event.trigger("ajaxStop")))}return v},getJSON:function(a,b,c){return m.get(a,b,c,"json")},getScript:function(a,b){return m.get(a,void 0,b,"script")}}),m.each(["get","post"],function(a,b){m[b]=function(a,c,d,e){return m.isFunction(c)&&(e=e||d,d=c,c=void 0),m.ajax({url:a,type:b,dataType:e,data:c,success:d})}}),m.each(["ajaxStart","ajaxStop","ajaxComplete","ajaxError","ajaxSuccess","ajaxSend"],function(a,b){m.fn[b]=function(a){return this.on(b,a)}}),m._evalUrl=function(a){return m.ajax({url:a,type:"GET",dataType:"script",async:!1,global:!1,"throws":!0})},m.fn.extend({wrapAll:function(a){if(m.isFunction(a))return this.each(function(b){m(this).wrapAll(a.call(this,b))});if(this[0]){var b=m(a,this[0].ownerDocument).eq(0).clone(!0);this[0].parentNode&&b.insertBefore(this[0]),b.map(function(){var a=this;while(a.firstChild&&1===a.firstChild.nodeType)a=a.firstChild;return a}).append(this)}return this},wrapInner:function(a){return this.each(m.isFunction(a)?function(b){m(this).wrapInner(a.call(this,b))}:function(){var b=m(this),c=b.contents();c.length?c.wrapAll(a):b.append(a)})},wrap:function(a){var b=m.isFunction(a);return this.each(function(c){m(this).wrapAll(b?a.call(this,c):a)})},unwrap:function(){return this.parent().each(function(){m.nodeName(this,"body")||m(this).replaceWith(this.childNodes)}).end()}}),m.expr.filters.hidden=function(a){return a.offsetWidth<=0&&a.offsetHeight<=0||!k.reliableHiddenOffsets()&&"none"===(a.style&&a.style.display||m.css(a,"display"))},m.expr.filters.visible=function(a){return!m.expr.filters.hidden(a)};var Qc=/%20/g,Rc=/\[\]$/,Sc=/\r?\n/g,Tc=/^(?:submit|button|image|reset|file)$/i,Uc=/^(?:input|select|textarea|keygen)/i;function Vc(a,b,c,d){var e;if(m.isArray(b))m.each(b,function(b,e){c||Rc.test(a)?d(a,e):Vc(a+"["+("object"==typeof e?b:"")+"]",e,c,d)});else if(c||"object"!==m.type(b))d(a,b);else for(e in b)Vc(a+"["+e+"]",b[e],c,d)}m.param=function(a,b){var c,d=[],e=function(a,b){b=m.isFunction(b)?b():null==b?"":b,d[d.length]=encodeURIComponent(a)+"="+encodeURIComponent(b)};if(void 0===b&&(b=m.ajaxSettings&&m.ajaxSettings.traditional),m.isArray(a)||a.jquery&&!m.isPlainObject(a))m.each(a,function(){e(this.name,this.value)});else for(c in a)Vc(c,a[c],b,e);return d.join("&").replace(Qc,"+")},m.fn.extend({serialize:function(){return m.param(this.serializeArray())},serializeArray:function(){return this.map(function(){var a=m.prop(this,"elements");return a?m.makeArray(a):this}).filter(function(){var a=this.type;return this.name&&!m(this).is(":disabled")&&Uc.test(this.nodeName)&&!Tc.test(a)&&(this.checked||!W.test(a))}).map(function(a,b){var c=m(this).val();return null==c?null:m.isArray(c)?m.map(c,function(a){return{name:b.name,value:a.replace(Sc,"\r\n")}}):{name:b.name,value:c.replace(Sc,"\r\n")}}).get()}}),m.ajaxSettings.xhr=void 0!==a.ActiveXObject?function(){return!this.isLocal&&/^(get|post|head|put|delete|options)$/i.test(this.type)&&Zc()||$c()}:Zc;var Wc=0,Xc={},Yc=m.ajaxSettings.xhr();a.ActiveXObject&&m(a).on("unload",function(){for(var a in Xc)Xc[a](void 0,!0)}),k.cors=!!Yc&&"withCredentials"in Yc,Yc=k.ajax=!!Yc,Yc&&m.ajaxTransport(function(a){if(!a.crossDomain||k.cors){var b;return{send:function(c,d){var e,f=a.xhr(),g=++Wc;if(f.open(a.type,a.url,a.async,a.username,a.password),a.xhrFields)for(e in a.xhrFields)f[e]=a.xhrFields[e];a.mimeType&&f.overrideMimeType&&f.overrideMimeType(a.mimeType),a.crossDomain||c["X-Requested-With"]||(c["X-Requested-With"]="XMLHttpRequest");for(e in c)void 0!==c[e]&&f.setRequestHeader(e,c[e]+"");f.send(a.hasContent&&a.data||null),b=function(c,e){var h,i,j;if(b&&(e||4===f.readyState))if(delete Xc[g],b=void 0,f.onreadystatechange=m.noop,e)4!==f.readyState&&f.abort();else{j={},h=f.status,"string"==typeof f.responseText&&(j.text=f.responseText);try{i=f.statusText}catch(k){i=""}h||!a.isLocal||a.crossDomain?1223===h&&(h=204):h=j.text?200:404}j&&d(h,i,j,f.getAllResponseHeaders())},a.async?4===f.readyState?setTimeout(b):f.onreadystatechange=Xc[g]=b:b()},abort:function(){b&&b(void 0,!0)}}}});function Zc(){try{return new a.XMLHttpRequest}catch(b){}}function $c(){try{return new a.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}}m.ajaxSetup({accepts:{script:"text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"},contents:{script:/(?:java|ecma)script/},converters:{"text script":function(a){return m.globalEval(a),a}}}),m.ajaxPrefilter("script",function(a){void 0===a.cache&&(a.cache=!1),a.crossDomain&&(a.type="GET",a.global=!1)}),m.ajaxTransport("script",function(a){if(a.crossDomain){var b,c=y.head||m("head")[0]||y.documentElement;return{send:function(d,e){b=y.createElement("script"),b.async=!0,a.scriptCharset&&(b.charset=a.scriptCharset),b.src=a.url,b.onload=b.onreadystatechange=function(a,c){(c||!b.readyState||/loaded|complete/.test(b.readyState))&&(b.onload=b.onreadystatechange=null,b.parentNode&&b.parentNode.removeChild(b),b=null,c||e(200,"success"))},c.insertBefore(b,c.firstChild)},abort:function(){b&&b.onload(void 0,!0)}}}});var _c=[],ad=/(=)\?(?=&|$)|\?\?/;m.ajaxSetup({jsonp:"callback",jsonpCallback:function(){var a=_c.pop()||m.expando+"_"+vc++;return this[a]=!0,a}}),m.ajaxPrefilter("json jsonp",function(b,c,d){var e,f,g,h=b.jsonp!==!1&&(ad.test(b.url)?"url":"string"==typeof b.data&&!(b.contentType||"").indexOf("application/x-www-form-urlencoded")&&ad.test(b.data)&&"data");return h||"jsonp"===b.dataTypes[0]?(e=b.jsonpCallback=m.isFunction(b.jsonpCallback)?b.jsonpCallback():b.jsonpCallback,h?b[h]=b[h].replace(ad,"$1"+e):b.jsonp!==!1&&(b.url+=(wc.test(b.url)?"&":"?")+b.jsonp+"="+e),b.converters["script json"]=function(){return g||m.error(e+" was not called"),g[0]},b.dataTypes[0]="json",f=a[e],a[e]=function(){g=arguments},d.always(function(){a[e]=f,b[e]&&(b.jsonpCallback=c.jsonpCallback,_c.push(e)),g&&m.isFunction(f)&&f(g[0]),g=f=void 0}),"script"):void 0}),m.parseHTML=function(a,b,c){if(!a||"string"!=typeof a)return null;"boolean"==typeof b&&(c=b,b=!1),b=b||y;var d=u.exec(a),e=!c&&[];return d?[b.createElement(d[1])]:(d=m.buildFragment([a],b,e),e&&e.length&&m(e).remove(),m.merge([],d.childNodes))};var bd=m.fn.load;m.fn.load=function(a,b,c){if("string"!=typeof a&&bd)return bd.apply(this,arguments);var d,e,f,g=this,h=a.indexOf(" ");return h>=0&&(d=m.trim(a.slice(h,a.length)),a=a.slice(0,h)),m.isFunction(b)?(c=b,b=void 0):b&&"object"==typeof b&&(f="POST"),g.length>0&&m.ajax({url:a,type:f,dataType:"html",data:b}).done(function(a){e=arguments,g.html(d?m("<div>").append(m.parseHTML(a)).find(d):a)}).complete(c&&function(a,b){g.each(c,e||[a.responseText,b,a])}),this},m.expr.filters.animated=function(a){return m.grep(m.timers,function(b){return a===b.elem}).length};var cd=a.document.documentElement;function dd(a){return m.isWindow(a)?a:9===a.nodeType?a.defaultView||a.parentWindow:!1}m.offset={setOffset:function(a,b,c){var d,e,f,g,h,i,j,k=m.css(a,"position"),l=m(a),n={};"static"===k&&(a.style.position="relative"),h=l.offset(),f=m.css(a,"top"),i=m.css(a,"left"),j=("absolute"===k||"fixed"===k)&&m.inArray("auto",[f,i])>-1,j?(d=l.position(),g=d.top,e=d.left):(g=parseFloat(f)||0,e=parseFloat(i)||0),m.isFunction(b)&&(b=b.call(a,c,h)),null!=b.top&&(n.top=b.top-h.top+g),null!=b.left&&(n.left=b.left-h.left+e),"using"in b?b.using.call(a,n):l.css(n)}},m.fn.extend({offset:function(a){if(arguments.length)return void 0===a?this:this.each(function(b){m.offset.setOffset(this,a,b)});var b,c,d={top:0,left:0},e=this[0],f=e&&e.ownerDocument;if(f)return b=f.documentElement,m.contains(b,e)?(typeof e.getBoundingClientRect!==K&&(d=e.getBoundingClientRect()),c=dd(f),{top:d.top+(c.pageYOffset||b.scrollTop)-(b.clientTop||0),left:d.left+(c.pageXOffset||b.scrollLeft)-(b.clientLeft||0)}):d},position:function(){if(this[0]){var a,b,c={top:0,left:0},d=this[0];return"fixed"===m.css(d,"position")?b=d.getBoundingClientRect():(a=this.offsetParent(),b=this.offset(),m.nodeName(a[0],"html")||(c=a.offset()),c.top+=m.css(a[0],"borderTopWidth",!0),c.left+=m.css(a[0],"borderLeftWidth",!0)),{top:b.top-c.top-m.css(d,"marginTop",!0),left:b.left-c.left-m.css(d,"marginLeft",!0)}}},offsetParent:function(){return this.map(function(){var a=this.offsetParent||cd;while(a&&!m.nodeName(a,"html")&&"static"===m.css(a,"position"))a=a.offsetParent;return a||cd})}}),m.each({scrollLeft:"pageXOffset",scrollTop:"pageYOffset"},function(a,b){var c=/Y/.test(b);m.fn[a]=function(d){return V(this,function(a,d,e){var f=dd(a);return void 0===e?f?b in f?f[b]:f.document.documentElement[d]:a[d]:void(f?f.scrollTo(c?m(f).scrollLeft():e,c?e:m(f).scrollTop()):a[d]=e)},a,d,arguments.length,null)}}),m.each(["top","left"],function(a,b){m.cssHooks[b]=Lb(k.pixelPosition,function(a,c){return c?(c=Jb(a,b),Hb.test(c)?m(a).position()[b]+"px":c):void 0})}),m.each({Height:"height",Width:"width"},function(a,b){m.each({padding:"inner"+a,content:b,"":"outer"+a},function(c,d){m.fn[d]=function(d,e){var f=arguments.length&&(c||"boolean"!=typeof d),g=c||(d===!0||e===!0?"margin":"border");return V(this,function(b,c,d){var e;return m.isWindow(b)?b.document.documentElement["client"+a]:9===b.nodeType?(e=b.documentElement,Math.max(b.body["scroll"+a],e["scroll"+a],b.body["offset"+a],e["offset"+a],e["client"+a])):void 0===d?m.css(b,c,g):m.style(b,c,d,g)},b,f?d:void 0,f,null)}})}),m.fn.size=function(){return this.length},m.fn.andSelf=m.fn.addBack,"function"==typeof define&&define.amd&&define("jquery",[],function(){return m});var ed=a.jQuery,fd=a.$;return m.noConflict=function(b){return a.$===m&&(a.$=fd),b&&a.jQuery===m&&(a.jQuery=ed),m},typeof b===K&&(a.jQuery=a.$=m),m});
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      lamp/include/                                                                                       000755  000765  000024  00000000000 13564524033 014730  5                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         lamp/include/php.sh                                                                                 000644  000765  000024  00000011552 13564532772 016070  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #Intall PHP
install_php(){

    if [ "${php}" == "${php5_6_filename}" ]; then
        with_mysql="--enable-mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-mysql-sock=/tmp/mysql.sock --with-pdo-mysql=mysqlnd"
        with_gd="--with-gd --with-vpx-dir --with-jpeg-dir --with-png-dir --with-xpm-dir --with-freetype-dir"
    else
        with_mysql="--enable-mysqlnd --with-mysqli=mysqlnd --with-mysql-sock=/tmp/mysql.sock --with-pdo-mysql=mysqlnd"
        with_gd="--with-gd --with-webp-dir --with-jpeg-dir --with-png-dir --with-xpm-dir --with-freetype-dir"
    fi
    if [[ "${php}" == "${php7_2_filename}" || "${php}" == "${php7_3_filename}" ]]; then
        other_options="--enable-zend-test"
    else
        other_options="--with-mcrypt --enable-gd-native-ttf"
    fi
    if [ "${php}" == "${php7_3_filename}" ]; then
        with_libmbfl=""
    else
        with_libmbfl="--with-libmbfl"
    fi
    is_64bit && with_libdir="--with-libdir=lib64" || with_libdir=""
    php_configure_args="--prefix=${php_location} \
    --with-apxs2=${apache_location}/bin/apxs \
    --with-config-file-path=${php_location}/etc \
    --with-config-file-scan-dir=${php_location}/php.d \
    --with-pcre-dir=${depends_prefix}/pcre \
    --with-imap \
    --with-kerberos \
    --with-imap-ssl \
    --with-libxml-dir \
    --with-openssl \
    --with-snmp \
    ${with_libdir} \
    ${with_mysql} \
    ${with_gd} \
    --with-zlib \
    --with-bz2 \
    --with-curl=/usr \
    --with-gettext \
    --with-gmp \
    --with-mhash \
    --with-icu-dir=/usr \
    --with-ldap \
    --with-ldap-sasl \
    ${with_libmbfl} \
    --with-onig \
    --with-unixODBC \
    --with-pspell=/usr \
    --with-enchant=/usr \
    --with-readline \
    --with-tidy=/usr \
    --with-xmlrpc \
    --with-xsl \
    --without-pear \
    ${other_options} \
    --enable-bcmath \
    --enable-calendar \
    --enable-dba \
    --enable-exif \
    --enable-ftp \
    --enable-gd-jis-conv \
    --enable-intl \
    --enable-mbstring \
    --enable-pcntl \
    --enable-shmop \
    --enable-soap \
    --enable-sockets \
    --enable-wddx \
    --enable-zip \
    ${disable_fileinfo}"

    #Install PHP depends
    install_php_depends

    cd ${cur_dir}/software/

    if [ "${php}" == "${php5_6_filename}" ]; then
        download_file  "${php5_6_filename}.tar.gz" "${php5_6_filename_url}"
        tar zxf ${php5_6_filename}.tar.gz
        cd ${php5_6_filename}
    elif [ "${php}" == "${php7_0_filename}" ]; then
        download_file  "${php7_0_filename}.tar.gz" "${php7_0_filename_url}"
        tar zxf ${php7_0_filename}.tar.gz
        cd ${php7_0_filename}
    elif [ "${php}" == "${php7_1_filename}" ]; then
        download_file  "${php7_1_filename}.tar.gz" "${php7_1_filename_url}"
        tar zxf ${php7_1_filename}.tar.gz
        cd ${php7_1_filename}
    elif [ "${php}" == "${php7_2_filename}" ]; then
        download_file  "${php7_2_filename}.tar.gz" "${php7_2_filename_url}"
        tar zxf ${php7_2_filename}.tar.gz
        cd ${php7_2_filename}
    elif [ "${php}" == "${php7_3_filename}" ]; then
        download_file  "${php7_3_filename}.tar.gz" "${php7_3_filename_url}"
        tar zxf ${php7_3_filename}.tar.gz
        cd ${php7_3_filename}
    fi

    unset LD_LIBRARY_PATH
    unset CPPFLAGS
    ldconfig
    error_detect "./configure ${php_configure_args}"
    error_detect "parallel_make ZEND_EXTRA_LIBS='-liconv'"
    error_detect "make install"

    mkdir -p ${php_location}/{etc,php.d}
    cp -f ${cur_dir}/conf/php.ini ${php_location}/etc/php.ini
    config_php
}


config_php(){

    rm -f /etc/php.ini /usr/bin/php /usr/bin/php-config /usr/bin/phpize
    ln -s ${php_location}/etc/php.ini /etc/php.ini
    ln -s ${php_location}/bin/php /usr/bin/
    ln -s ${php_location}/bin/php-config /usr/bin/
    ln -s ${php_location}/bin/phpize /usr/bin/

    extension_dir=$(php-config --extension-dir)
    cat > ${php_location}/php.d/opcache.ini<<-EOF
[opcache]
zend_extension=${extension_dir}/opcache.so
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.save_comments=0
EOF

    cp -f ${cur_dir}/conf/ocp.php ${web_root_dir}/ocp.php
    chown apache:apache ${web_root_dir}/ocp.php

    if [ -d "${mysql_data_location}" ]; then
        sock_location=/tmp/mysql.sock
        sed -i "s#mysql.default_socket.*#mysql.default_socket = ${sock_location}#" ${php_location}/etc/php.ini
        sed -i "s#mysqli.default_socket.*#mysqli.default_socket = ${sock_location}#" ${php_location}/etc/php.ini
        sed -i "s#pdo_mysql.default_socket.*#pdo_mysql.default_socket = ${sock_location}#" ${php_location}/etc/php.ini
    fi

    if [[ -d "${apache_location}" ]]; then
        sed -i "s@AddType\(.*\)Z@AddType\1Z\n    AddType application/x-httpd-php .php .phtml\n    AddType appication/x-httpd-php-source .phps@" ${apache_location}/conf/httpd.conf
    fi

}
                                                                                                                                                      lamp/include/mysql.sh                                                                               000644  000765  000024  00000027232 13564532777 016455  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         # Copyright (C) 2013 - 2019 Teddysun <i@teddysun.com>
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


                                                                                                                                                                                                                                                                                                                                                                      lamp/include/php-modules.sh                                                                         000644  000765  000024  00000016304 13564532774 017540  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         
install_php_depends(){
    if check_sys packageManager apt; then
        apt_depends=(
            autoconf patch m4 bison libbz2-dev libgmp-dev libicu-dev libldb-dev libpam0g-dev
            libldap-2.4-2 libldap2-dev libsasl2-dev libsasl2-modules-ldap libc-client2007e-dev libkrb5-dev
            autoconf2.13 pkg-config libxslt1-dev zlib1g-dev libpcre3-dev libtool unixodbc-dev libtidy-dev
            libjpeg-dev libpng-dev libfreetype6-dev libpspell-dev libmhash-dev libenchant-dev libmcrypt-dev
            libcurl4-gnutls-dev libwebp-dev libxpm-dev libvpx-dev libreadline-dev snmp libsnmp-dev libzip-dev
        )
        _info "Starting to install dependencies packages for PHP..."
        for depend in ${apt_depends[@]}
        do
            error_detect_depends "apt-get -y install ${depend}"
        done
        _info "Install dependencies packages for PHP completed..."

        if is_64bit; then
            if [ ! -d /usr/lib64 ] && [ -d /usr/lib ]; then
                ln -sf /usr/lib /usr/lib64
            fi

            if [ -f /usr/include/gmp-x86_64.h ]; then
                ln -sf /usr/include/gmp-x86_64.h /usr/include/
            elif [ -f /usr/include/x86_64-linux-gnu/gmp.h ]; then
                ln -sf /usr/include/x86_64-linux-gnu/gmp.h /usr/include/
            fi

            ln -sf /usr/lib/x86_64-linux-gnu/libldap* /usr/lib64/
            ln -sf /usr/lib/x86_64-linux-gnu/liblber* /usr/lib64/

            if [ -d /usr/include/x86_64-linux-gnu/curl ] && [ ! -d /usr/include/curl ]; then
                ln -sf /usr/include/x86_64-linux-gnu/curl /usr/include/
            fi

            create_lib_link libc-client.a
            create_lib_link libc-client.so
        else
            if [ -f /usr/include/gmp-i386.h ]; then
                ln -sf /usr/include/gmp-i386.h /usr/include/
            elif [ -f /usr/include/i386-linux-gnu/gmp.h ]; then
                ln -sf /usr/include/i386-linux-gnu/gmp.h /usr/include/
            fi

            ln -sf /usr/lib/i386-linux-gnu/libldap* /usr/lib/
            ln -sf /usr/lib/i386-linux-gnu/liblber* /usr/lib/

            if [ -d /usr/include/i386-linux-gnu/curl ] && [ ! -d /usr/include/curl ]; then
                ln -sf /usr/include/i386-linux-gnu/curl /usr/include/
            fi
        fi
    elif check_sys packageManager yum; then
        yum_depends=(
            autoconf patch m4 bison bzip2-devel pam-devel gmp-devel libicu-devel
            curl-devel pcre-devel libtool-libs libtool-ltdl-devel libwebp-devel libXpm-devel
            libvpx-devel libjpeg-devel libpng-devel freetype-devel oniguruma-devel
            aspell-devel enchant-devel readline-devel unixODBC-devel libtidy-devel
            openldap-devel libxslt-devel net-snmp net-snmp-devel krb5-devel
        )
        _info "Starting to install dependencies packages for PHP..."
        for depend in ${yum_depends[@]}
        do
            error_detect_depends "yum -y install ${depend}"
        done
        if yum list | grep "libc-client-devel" > /dev/null 2>&1; then
            error_detect_depends "yum -y install libc-client-devel"
        elif yum list | grep "uw-imap-devel" > /dev/null 2>&1; then
            error_detect_depends "yum -y install uw-imap-devel"
        else
            _error "There is no rpm package libc-client-devel or uw-imap-devel, please check it and try again."
        fi
        _info "Install dependencies packages for PHP completed..."

        install_mhash
        install_libmcrypt
        install_mcrypt
        install_libzip
    fi

    install_libiconv
    install_re2c
    install_phpmyadmin
    # Fixed unixODBC issue
    if [ -f /usr/include/sqlext.h ] && [ ! -f /usr/local/include/sqlext.h ]; then
        ln -sf /usr/include/sqlext.h /usr/local/include/
    fi
}

install_libiconv(){
    if [ ! -e "/usr/local/bin/iconv" ]; then
        cd ${cur_dir}/software/
        _info "${libiconv_filename} install start..."
        download_file  "${libiconv_filename}.tar.gz" "${libiconv_filename_url}"
        tar zxf ${libiconv_filename}.tar.gz
        patch -d ${libiconv_filename} -p0 < ${cur_dir}/conf/libiconv-glibc-2.16.patch
        cd ${libiconv_filename}

        error_detect "./configure"
        error_detect "parallel_make"
        error_detect "make install"
        _info "${libiconv_filename} install completed..."
    fi
}

install_re2c(){
    if [ ! -e "/usr/local/bin/re2c" ]; then
        cd ${cur_dir}/software/
        _info "${re2c_filename} install start..."
        download_file "${re2c_filename}.tar.xz" "${re2c_filename_url}"
        tar Jxf ${re2c_filename}.tar.xz
        cd ${re2c_filename}

        error_detect "./configure"
        error_detect "make"
        error_detect "make install"
        _info "${re2c_filename} install completed..."
    fi
}

install_mhash(){
    if [ ! -e "/usr/local/lib/libmhash.a" ]; then
        cd ${cur_dir}/software/
        _info "${mhash_filename} install start..."
        download_file "${mhash_filename}.tar.gz" "${mhash_filename_url}"
        tar zxf ${mhash_filename}.tar.gz
        cd ${mhash_filename}

        error_detect "./configure"
        error_detect "parallel_make"
        error_detect "make install"
        _info "${mhash_filename} install completed..."
    fi
}

install_mcrypt(){
    if [ ! -e "/usr/local/bin/mcrypt" ]; then
        cd ${cur_dir}/software/
        _info "${mcrypt_filename} install start..."
        download_file "${mcrypt_filename}.tar.gz" "${mcrypt_filename_url}"
        tar zxf ${mcrypt_filename}.tar.gz
        cd ${mcrypt_filename}

        ldconfig
        error_detect "./configure"
        error_detect "parallel_make"
        error_detect "make install"
        _info "${mcrypt_filename} install completed..."
    fi
}

install_libmcrypt(){
    if [ ! -e "/usr/local/lib/libmcrypt.la" ]; then
        cd ${cur_dir}/software/
        _info "${libmcrypt_filename} install start..."
        download_file "${libmcrypt_filename}.tar.gz" "${libmcrypt_filename_url}"
        tar zxf ${libmcrypt_filename}.tar.gz
        cd ${libmcrypt_filename}

        error_detect "./configure"
        error_detect "parallel_make"
        error_detect "make install"
        _info "${libmcrypt_filename} install completed..."
    fi
}

install_libzip(){
    if [ ! -e "/usr/lib/libzip.la" ]; then
        cd ${cur_dir}/software/
        _info "${libzip_filename} install start..."
        download_file "${libzip_filename}.tar.gz" "${libzip_filename_url}"
        tar zxf ${libzip_filename}.tar.gz
        cd ${libzip_filename}

        error_detect "./configure --prefix=/usr"
        error_detect "parallel_make"
        error_detect "make install"
        _info "${libzip_filename} install completed..."
    fi
}

install_phpmyadmin(){
    if [ -d "${web_root_dir}/phpmyadmin" ]; then
        rm -rf ${web_root_dir}/phpmyadmin
    fi

    cd ${cur_dir}/software

    _info "${phpmyadmin_filename} install start..."
    download_file "${phpmyadmin_filename}.tar.gz" "${phpmyadmin_filename_url}"
    tar zxf ${phpmyadmin_filename}.tar.gz
    mv ${phpmyadmin_filename} ${web_root_dir}/phpmyadmin
    cp -f ${cur_dir}/conf/config.inc.php ${web_root_dir}/phpmyadmin/config.inc.php
    mkdir -p ${web_root_dir}/phpmyadmin/{upload,save}
    chown -R apache:apache ${web_root_dir}/phpmyadmin
    _info "${phpmyadmin_filename} install completed..."
}                                                                                                                                                                                                                                                                                                                            lamp/include/public.sh                                                                              000644  000765  000024  00000052615 13564532770 016562  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         # Copyright (C) 2013 - 2019 Teddysun <i@teddysun.com>
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

_red(){
    printf '\033[1;31;31m%b\033[0m' "$1"
}

_green(){
    printf '\033[1;31;32m%b\033[0m' "$1"
}

_yellow(){
    printf '\033[1;31;33m%b\033[0m' "$1"
}

_printargs(){
    printf -- "%s" "$1"
    printf "\n"
}

_info(){
    _printargs "$@"
}

_warn(){
    _yellow "$1"
    printf "\n"
}

_error(){
    _red "$1"
    printf "\n"
    exit 1
}

rootness(){
    if [[ ${EUID} -ne 0 ]]; then
        _error "This script must be run as root"
    fi
}

generate_password(){
    cat /dev/urandom | head -1 | md5sum | head -c 8
}

get_ip(){
    local ipv4=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
    egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z "${ipv4}" ] && ipv4=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z "${ipv4}" ] && ipv4=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    printf -- "%s" "${ipv4}"
}

get_ip_country(){
    local country=$( wget -qO- -t1 -T2 ipinfo.io/$(get_ip)/country )
    printf -- "%s" "${country}"
}

get_libc_version(){
    getconf -a | grep GNU_LIBC_VERSION | awk '{print $NF}'
}

get_opsy(){
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

get_os_info(){
    cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    tram=$( free -m | awk '/Mem/ {print $2}' )
    swap=$( free -m | awk '/Swap/ {print $2}' )
    up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60} {printf("%ddays, %d:%d:%d\n",a,b,c,d)}' /proc/uptime )
    load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    opsy=$( get_opsy )
    arch=$( uname -m )
    lbit=$( getconf LONG_BIT )
    host=$( hostname )
    kern=$( uname -r )
    ramsum=$( expr $tram + $swap )
}

get_php_extension_dir(){
    local phpConfig="$1"
    ${phpConfig} --extension-dir
}

get_php_version(){
    local phpConfig="$1"
    ${phpConfig} --version | cut -d'.' -f1-2
}

get_char(){
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty ${SAVEDSTTY}
}

get_valid_valname(){
    local val="$1"
    local new_val=$(eval echo $val | sed 's/[-.]/_/g')
    echo ${new_val}
}

get_hint(){
    local val="$1"
    local new_val=$(get_valid_valname $val)
    eval echo "\$hint_${new_val}"
}

set_hint(){
    local val="$1"
    local hint="$2"
    local new_val=$(get_valid_valname $val)
    eval hint_${new_val}="\$hint"
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

#Display Memu


display_os_info(){
    clear
    echo
    echo "+-------------------------------------------------------------------+"
    echo "| Auto Install LAMP(Linux + Apache + MySQL/MariaDB/Percona + PHP )  |"
    echo "| Website: https://lamp.sh                                          |"
    echo "| Author : Teddysun <i@teddysun.com>                                |"
    echo "+-------------------------------------------------------------------+"
    echo
    echo "--------------------- System Information ----------------------------"
    echo
    echo "CPU model            : ${cname}"
    echo "Number of cores      : ${cores}"
    echo "CPU frequency        : ${freq} MHz"
    echo "Total amount of ram  : ${tram} MB"
    echo "Total amount of swap : ${swap} MB"
    echo "System uptime        : ${up}"
    echo "Load average         : ${load}"
    echo "OS                   : ${opsy}"
    echo "Arch                 : ${arch} (${lbit} Bit)"
    echo "Kernel               : ${kern}"
    echo "Hostname             : ${host}"
    echo "IPv4 address         : $(get_ip)"
    echo
    echo "---------------------------------------------------------------------"
}

check_command_exist(){
    local cmd="$1"
    if eval type type > /dev/null 2>&1; then
        eval type "$cmd" > /dev/null 2>&1
    elif command > /dev/null 2>&1; then
        command -v "$cmd" > /dev/null 2>&1
    else
        which "$cmd" > /dev/null 2>&1
    fi
    rt=$?
    if [ ${rt} -ne 0 ]; then
        _error "$cmd is not installed, please install it and try again."
    fi
}

check_installed(){
    local cmd="$1"
    local location="$2"
    if [ -d "${location}" ]; then
        _info "${location} already exists, skipped the installation."
        add_to_env "${location}"
    else
        ${cmd}
    fi
}

check_os(){
    is_support_flg=0
    if check_sys packageManager yum || check_sys packageManager apt; then
        # Not support CentOS prior to 6 & Debian prior to 8 & Ubuntu prior to 14 versions
        if [ -n "$(get_centosversion)" ] && [ $(get_centosversion) -lt 6 ]; then
            is_support_flg=1
        fi
        if [ -n "$(get_debianversion)" ] && [ $(get_debianversion) -lt 8 ]; then
            is_support_flg=1
        fi
        if [ -n "$(get_ubuntuversion)" ] && [ $(get_ubuntuversion) -lt 14 ]; then
            is_support_flg=1
        fi
    else
        is_support_flg=1
    fi
    if [ ${is_support_flg} -eq 1 ]; then
        _error "Not supported OS, please change OS to CentOS 6+ or Debian 8+ or Ubuntu 14+ and try again."
    fi
}

check_ram(){
    get_os_info
    if [ ${ramsum} -lt 480 ]; then
        _error "Not enough memory. The LAMP installation needs memory: ${tram}MB*RAM + ${swap}MB*SWAP >= 480MB"
    fi
    [ ${ramsum} -lt 600 ] && disable_fileinfo="--disable-fileinfo" || disable_fileinfo=""
}

#Check system
check_sys(){
    local checkType="$1"
    local value="$2"
    local release=''
    local systemPackage=''
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

create_lib_link(){
    local lib="$1"
    if [ ! -s "/usr/lib64/$lib" ] && [ ! -s "/usr/lib/$lib" ]; then
        libdir=$(find /usr/lib /usr/lib64 -name "$lib" | awk 'NR==1{print}')
        if [ "$libdir" != "" ]; then
            if is_64bit; then
                mkdir /usr/lib64
                ln -s ${libdir} /usr/lib64/${lib}
                ln -s ${libdir} /usr/lib/${lib}
            else
                ln -s ${libdir} /usr/lib/${lib}
            fi
        fi
    fi
    if is_64bit; then
        [ ! -d /usr/lib64 ] && mkdir /usr/lib64
        [ ! -s "/usr/lib64/$lib" ] && [ -s "/usr/lib/$lib" ] && ln -s /usr/lib/${lib}  /usr/lib64/${lib}
        [ ! -s "/usr/lib/$lib" ] && [ -s "/usr/lib64/$lib" ] && ln -s /usr/lib64/${lib} /usr/lib/${lib}
    fi
}

create_lib64_dir(){
    local dir="$1"
    if is_64bit; then
        if [ -s "$dir/lib/" ] && [ ! -s  "$dir/lib64/" ]; then
            cd ${dir}
            ln -s lib lib64
        fi
    fi
}

error_detect_depends(){
    local command="$1"
    local work_dir=$(pwd)
    local depend=$(echo "$1" | awk '{print $4}')
    _info "Starting to install package ${depend}"
    ${command} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        distro=$(get_opsy)
        version=$(cat /proc/version)
        architecture=$(uname -m)
        mem=$(free -m)
        disk=$(df -ah)
        cat >> ${cur_dir}/lamp.log<<EOF
        Errors Detail:
        Distributions:${distro}
        Architecture:${architecture}
        Version:${version}
        Memery:
        ${mem}
        Disk:
        ${disk}
        Issue:failed to install ${depend}
EOF
        echo
        echo "+------------------+"
        echo "|  ERROR DETECTED  |"
        echo "+------------------+"
        echo "Installation package ${depend} failed."
        echo "The Full Log is available at ${cur_dir}/lamp.log"
        echo "Please visit website: https://lamp.sh/faq.html for help"
        exit 1
    fi
}

error_detect(){
    local command="$1"
    local work_dir=$(pwd)
    local cur_soft=$(echo ${work_dir#$cur_dir} | awk -F'/' '{print $3}')
    ${command}
    if [ $? -ne 0 ]; then
        distro=$(get_opsy)
        version=$(cat /proc/version)
        architecture=$(uname -m)
        mem=$(free -m)
        disk=$(df -ah)
        cat >>${cur_dir}/lamp.log<<EOF
        Errors Detail:
        Distributions:${distro}
        Architecture:${architecture}
        Version:${version}
        Memery:
        ${mem}
        Disk:
        ${disk}
        PHP Version: ${php}
        PHP compile parameter: ${php_configure_args}
        Issue:failed to install ${cur_soft}
EOF
        echo
        echo "+------------------+"
        echo "|  ERROR DETECTED  |"
        echo "+------------------+"
        echo "Installation ${cur_soft} failed."
        echo "The Full Log is available at ${cur_dir}/lamp.log"
        echo "Please visit website: https://lamp.sh/faq.html for help"
        exit 1
    fi
}

upcase_to_lowcase(){
    echo ${1} | tr '[A-Z]' '[a-z]'
}

untar(){
    local tarball_type
    local cur_dir=$(pwd)
    if [ -n ${1} ]; then
        software_name=$(echo $1 | awk -F/ '{print $NF}')
        tarball_type=$(echo $1 | awk -F. '{print $NF}')
        wget --no-check-certificate -cv -t3 -T60 ${1} -P ${cur_dir}/
        if [ $? -ne 0 ]; then
            rm -rf ${cur_dir}/${software_name}
            wget --no-check-certificate -cv -t3 -T60 ${2} -P ${cur_dir}/
            software_name=$(echo ${2} | awk -F/ '{print $NF}')
            tarball_type=$(echo ${2} | awk -F. '{print $NF}')
        fi
    else
        software_name=$(echo ${2} | awk -F/ '{print $NF}')
        tarball_type=$(echo ${2} | awk -F. '{print $NF}')
        wget --no-check-certificate -cv -t3 -T60 ${2} -P ${cur_dir}/ || exit
    fi
    extracted_dir=$(tar tf ${cur_dir}/${software_name} | tail -n 1 | awk -F/ '{print $1}')
    case ${tarball_type} in
        gz|tgz)
            tar zxf ${cur_dir}/${software_name} -C ${cur_dir}/ && cd ${cur_dir}/${extracted_dir} || return 1
        ;;
        bz2|tbz)
            tar jxf ${cur_dir}/${software_name} -C ${cur_dir}/ && cd ${cur_dir}/${extracted_dir} || return 1
        ;;
        xz)
            tar Jxf ${cur_dir}/${software_name} -C ${cur_dir}/ && cd ${cur_dir}/${extracted_dir} || return 1
        ;;
        tar|Z)
            tar xf ${cur_dir}/${software_name} -C ${cur_dir}/ && cd ${cur_dir}/${extracted_dir} || return 1
        ;;
        *)
        echo "${software_name} is wrong tarball type ! "
    esac
}

version_lt(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"
}

version_gt(){
    test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

version_le(){
    test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"
}

version_ge(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

versionget(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion(){
    if check_sys sysRelease centos; then
        local code=${1}
        local version="$(versionget)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_centosversion(){
    if check_sys sysRelease centos; then
        local version="$(versionget)"
        echo ${version%%.*}
    else
        echo ""
    fi
}

debianversion(){
    if check_sys sysRelease debian; then
        local version=$( get_opsy )
        local code=${1}
        local main_ver=$( echo ${version} | sed 's/[^0-9]//g')
        if [ "${main_ver}" == "${code}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_debianversion(){
    if check_sys sysRelease debian; then
        local version=$( get_opsy )
        local main_ver=$( echo ${version} | grep -oE  "[0-9.]+")
        echo ${main_ver%%.*}
    else
        echo ""
    fi
}

ubuntuversion(){
    if check_sys sysRelease ubuntu; then
        local version=$( get_opsy )
        local code=${1}
        echo ${version} | grep -q "${code}"
        if [ $? -eq 0 ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ubuntuversion(){
    if check_sys sysRelease ubuntu; then
        local version=$( get_opsy )
        local main_ver=$( echo ${version} | grep -oE  "[0-9.]+")
        echo ${main_ver%%.*}
    else
        echo ""
    fi
}

parallel_make(){
    local para="$1"
    cpunum=$(cat /proc/cpuinfo | grep 'processor' | wc -l)

    if [ ${parallel_compile} -eq 0 ]; then
        cpunum=1
    fi

    if [ ${cpunum} -eq 1 ]; then
        [ "${para}" == "" ] && make || make "${para}"
    else
        [ "${para}" == "" ] && make -j${cpunum} || make -j${cpunum} "${para}"
    fi
}

boot_start(){
    if check_sys packageManager apt; then
        update-rc.d -f "$1" defaults
    elif check_sys packageManager yum; then
        chkconfig --add "$1"
        chkconfig "$1" on
    fi
}

boot_stop(){
    if check_sys packageManager apt; then
        update-rc.d -f "$1" remove
    elif check_sys packageManager yum; then
        chkconfig "$1" off
        chkconfig --del "$1"
    fi
}

filter_location(){
    local location="$1"
    if ! echo ${location} | grep -q "^/"; then
        while true
        do
            read -p "Input error, please input location again: " location
            echo ${location} | grep -q "^/" && echo ${location} && break
        done
    else
        echo ${location}
    fi
}

# Download a file
# $1: file name
# $2: primary url
download_file(){
    local cur_dir=$(pwd)
    if [ -s "$1" ]; then
        _info "$1 [found]"
    else
        _info "$1 not found, download now..."
        wget --no-check-certificate -cv -t3 -T60 -O ${1} ${2}
        if [ $? -eq 0 ]; then
            _info "$1 download completed..."
        else
            rm -f "$1"
            _info "$1 download failed, retrying download from secondary url..."
            wget --no-check-certificate -cv -t3 -T60 -O "$1" "${download_root_url}${1}"
            if [ $? -eq 0 ]; then
                _info "$1 download completed..."
            else
                _error "Failed to download $1, please download it to ${cur_dir} directory manually and try again."
            fi
        fi
    fi
}

is_64bit(){
    if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ]; then
        return 0
    else
        return 1
    fi
}

is_digit(){
    local input="$1"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

if_in_array(){
    local element="$1"
    local array="$2"
    for i in ${array}
    do
        if [ "$i" == "$element" ]; then
            return 0
        fi
    done
    return 1
}

add_to_env(){
    local location="$1"
    cd ${location} && [ ! -d lib ] && [ -d lib64 ] && ln -s lib64 lib
    [ -d "${location}/lib" ] && export LD_LIBRARY_PATH=${location}/lib:${LD_LIBRARY_PATH}
    [ -d "${location}/bin" ] && export PATH=${location}/bin:${PATH}
    [ -d "${location}/include" ] && export CPPFLAGS="-I${location}/include $CPPFLAGS"
}

firewall_set(){
    _info "Starting set Firewall..."

    if centosversion 6; then
        if [ -e /etc/init.d/iptables ]; then
            /etc/init.d/iptables status > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                iptables -L -n | grep -qi 80
                if [ $? -ne 0 ]; then
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
                fi
                iptables -L -n | grep -qi 443
                if [ $? -ne 0 ]; then
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
                fi
                /etc/init.d/iptables save > /dev/null 2>&1
                /etc/init.d/iptables restart > /dev/null 2>&1
            else
                _warn "iptables looks like not running, please manually set if necessary."
            fi
        else
            _warn "iptables looks like not installed."
        fi
    else
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            default_zone=$(firewall-cmd --get-default-zone)
            firewall-cmd --permanent --zone=${default_zone} --add-service=http > /dev/null 2>&1
            firewall-cmd --permanent --zone=${default_zone} --add-service=https > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        else
            _warn "firewalld looks like not running, please manually set if necessary."
        fi
    fi
    _info "Firewall set completed..."
}

remove_packages(){
    _info "Starting remove the conflict packages..."
    if check_sys packageManager apt; then
        [ "${apache}" != "do_not_install" ] && apt-get -y remove --purge apache2 apache2-* &> /dev/null
        [ "${mysql}" != "do_not_install" ] && apt-get -y remove --purge mysql-client mysql-server mysql-common libmysqlclient18 &> /dev/null
        [ "${php}" != "do_not_install" ] && apt-get -y remove --purge php5 php5-* php7.0 php7.0-* php7.1 php7.1-* php7.2 php7.2-* php7.3 php7.3-* &> /dev/null
    elif check_sys packageManager yum; then
        [ "${apache}" != "do_not_install" ] && yum -y remove httpd-* &> /dev/null
        [ "${mysql}" != "do_not_install" ] && yum -y remove mysql-* &> /dev/null
        [ "${php}" != "do_not_install" ] && yum -y remove php-* libzip-devel libzip &> /dev/null
    fi
    _info "Remove the conflict packages completed..."
}

sync_time(){
    _info "Starting to sync time..."
    ntpdate -bv cn.pool.ntp.org
    rm -f /etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    _info "Sync time completed..."

    StartDate=$(date "+%Y-%m-%d %H:%M:%S")
    StartDateSecond=$(date +%s)
    _info "Start time: ${StartDate}"

}

start_install(){
    echo "Press any key to start...or Press Ctrl+C to cancel"
    echo
    char=$(get_char)
}

#Last confirm
last_confirm(){
    clear
    echo
    echo "------------------------- Install Overview --------------------------"
    echo
    echo "Apache: ${apache}"
    [ "${apache}" != "do_not_install" ] && echo "Apache Location: ${apache_location}"

    echo
    echo "Database: ${mysql}"
    if echo "${mysql}" | grep -qi "mysql"; then
        echo "MySQL Location: ${mysql_location}"
        echo "MySQL Data Location: ${mysql_data_location}"
        echo "MySQL Root Password: ${mysql_root_pass}"
    fi
    echo
    echo "PHP: ${php}"
    [ "${php}" != "do_not_install" ] && echo "PHP Location: ${php_location}"
    if [ "${php_modules_install}" != "do_not_install" ]; then
        echo "PHP Additional Extensions:"
        for m in ${php_modules_install[@]}
        do
            echo "${m}"
        done
    fi
    
    echo
    echo "---------------------------------------------------------------------"
    echo
}

#Finally to do


#Install tools
install_tools(){
    _info "Starting to install development tools..."
    if check_sys packageManager apt; then
        apt-get -y update > /dev/null 2>&1
        apt_tools=(gcc g++ make wget perl curl bzip2 libreadline-dev net-tools python python-dev cron ca-certificates ntpdate)
        for tool in ${apt_tools[@]}; do
            error_detect_depends "apt-get -y install ${tool}"
        done
    elif check_sys packageManager yum; then
        yum makecache > /dev/null 2>&1
        yum_tools=(yum-utils gcc gcc-c++ make wget perl curl bzip2 readline readline-devel net-tools python python-devel crontabs ca-certificates ntpdate)
        for tool in ${yum_tools[@]}; do
            error_detect_depends "yum -y install ${tool}"
        done
        if centosversion 6 || centosversion 7; then
            error_detect_depends "yum -y install epel-release"
            yum-config-manager --enable epel > /dev/null 2>&1
        fi
    fi
    _info "Install development tools completed..."

    check_command_exist "gcc"
    check_command_exist "g++"
    check_command_exist "make"
    check_command_exist "wget"
    check_command_exist "perl"
    check_command_exist "netstat"
    check_command_exist "ntpdate"
}





#Pre-installation settings

                                                                                                                   lamp/include/wordpress.sh                                                                           000644  000765  000024  00000002545 13564532766 017336  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         install_wordpress(){
        cd ${cur_dir}/software/
        _info "Downloading and Extracting WordPress files..."
        download_file "${wordpress_filename}.tar.gz" "${wordpress_filename_url}"
        tar zxf ${wordpress_filename}.tar.gz
        mv wordpress/* ${web_root_dir}
        chown -R apache:apache ${web_root_dir}
        chmod -R 755 ${web_root_dir}
        config_wordpress
        _info "You can access the wordpress protal at http://localhost:80"
}
config_wordpress(){
    cd ${web_root_dir}/
    cp wp-config-sample.php wp-config-sample.php.bkp
    mv wp-config-sample.php wp-config.php
    define('DB_NAME', 'database_name_here'); /** MySQL database username */ define('DB_USER', 'username_here'); /** MySQL database password */ define('DB_PASSWORD', 'password_here'); /** MySQL hostname */ define('DB_HOST', 'localhost'); /** Database Charset to use in creating database tables. */ define('DB_CHARSET', 'utf8'); /** The Database Collate type. Don't change this if in doubt. */ define('DB_COLLATE', '');
    sed  -i "s/^define(.*'DB_PASSWORD'.*/define( \x27DB_PASSWORD\x27, \x27${mysql_word_press_password}\x27 )/" wp-config.php
    sed  -i "s/^define(.*'DB_USER'.*/define( \x27DB_PASSWORD\x27, \x27${mysql_word_press_user}\x27 )/" wp-config.php
    sed  -i "s/^define(.*'DB_NAME'.*/define( \x27DB_PASSWORD\x27, \x27${mysql_word_press_db}\x27 )/" wp-config.php
}                                                                                                                                                           lamp/include/config.sh                                                                              000644  000765  000024  00000010426 13564533002 016530  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         # Copyright (C) 2013 - 2019 Teddysun <i@teddysun.com>
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

load_config(){


#Install location
apache_location=/usr/local/apache
mysql_location=/usr/local/mysql
php_location=/usr/local/php
openssl_location=/usr/local/openssl

#Install depends location
depends_prefix=/usr/local

#Web root location
web_root_dir=/data/www/default

#Download root URL
download_root_url="https://dl.lamp.sh/files/"

#parallel compile option,1:enable,0:disable
parallel_compile=1

##Software version
#nghttp2
nghttp2_filename="nghttp2-1.40.0"
nghttp2_filename_url="https://github.com/nghttp2/nghttp2/releases/download/v1.40.0/nghttp2-1.40.0.tar.gz"
#openssl
openssl_filename="openssl-1.1.1d"
openssl_filename_url="https://www.openssl.org/source/openssl-1.1.1d.tar.gz"
#apache2.4
apache2_4_filename="httpd-2.4.41"
apache2_4_filename_url="http://ftp.jaist.ac.jp/pub/apache//httpd/httpd-2.4.41.tar.gz"
#mysql5.5
mysql5_5_filename="mysql-5.5.62"
#mysql5.6
mysql5_6_filename="mysql-5.6.46"
#mysql5.7
mysql5_7_filename="mysql-5.7.28"
#mysql8.0
mysql8_0_filename="mysql-8.0.18"

#php5.6
php5_6_filename="php-5.6.40"
php5_6_filename_url="https://www.php.net/distributions/php-5.6.40.tar.gz"
#php7.0
php7_0_filename="php-7.0.33"
php7_0_filename_url="https://www.php.net/distributions/php-7.0.33.tar.gz"
#php7.1
php7_1_filename="php-7.1.33"
php7_1_filename_url="https://www.php.net/distributions/php-7.1.33.tar.gz"
#php7.2
php7_2_filename="php-7.2.24"
php7_2_filename_url="https://www.php.net/distributions/php-7.2.24.tar.gz"
#php7.3
php7_3_filename="php-7.3.11"
php7_3_filename_url="https://www.php.net/distributions/php-7.3.11.tar.gz"

#phpMyAdmin
phpmyadmin_filename="phpMyAdmin-4.9.1-all-languages"
phpmyadmin_filename_url="https://files.phpmyadmin.net/phpMyAdmin/4.9.1/phpMyAdmin-4.9.1-all-languages.tar.gz"

#apr
apr_filename="apr-1.7.0"
apr_filename_url="http://ftp.jaist.ac.jp/pub/apache//apr/apr-1.7.0.tar.gz"
#apr-util
apr_util_filename="apr-util-1.6.1"
apr_util_filename_url="http://ftp.jaist.ac.jp/pub/apache//apr/apr-util-1.6.1.tar.gz"
#mod_wsgi
mod_wsgi_filename="mod_wsgi-4.6.5"
mod_wsgi_filename_url="https://github.com/GrahamDumpleton/mod_wsgi/archive/4.6.5.tar.gz"
#mod_jk
mod_jk_filename="tomcat-connectors-1.2.46-src"
mod_jk_filename_url="http://ftp.jaist.ac.jp/pub/apache/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.46-src.tar.gz"
set_hint ${mod_jk_filename} "mod_jk-1.2.46"
#mod_security
mod_security_filename="modsecurity-2.9.3"
mod_security_filename_url="https://github.com/SpiderLabs/ModSecurity/releases/download/v2.9.3/modsecurity-2.9.3.tar.gz"
set_hint ${mod_security_filename} "mod_security-2.9.3"
#mhash
mhash_filename="mhash-0.9.9.9"
mhash_filename_url="https://sourceforge.net/projects/mhash/files/mhash/0.9.9.9/mhash-0.9.9.9.tar.gz/download"
#libmcrypt
libmcrypt_filename="libmcrypt-2.5.8"
libmcrypt_filename_url="https://sourceforge.net/projects/mcrypt/files/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.gz/download"
#mcrypt
mcrypt_filename="mcrypt-2.6.8"
mcrypt_filename_url="https://sourceforge.net/projects/mcrypt/files/MCrypt/2.6.8/mcrypt-2.6.8.tar.gz/download"
#pcre
pcre_filename="pcre-8.43"
pcre_filename_url="https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz"
#re2c
re2c_filename="re2c-1.2.1"
re2c_filename_url="https://github.com/skvadrik/re2c/releases/download/1.2.1/re2c-1.2.1.tar.xz"
#libzip
libzip_filename="libzip-1.3.2"
libzip_filename_url="https://libzip.org/download/libzip-1.3.2.tar.gz"
#libiconv
libiconv_filename="libiconv-1.16"
libiconv_filename_url="https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz"

#wordpress
wordpress_filename="latest"
wordpress_filename_url="http://wordpress.org/latest.tar.gz"

## Set below values to version which you would like to install

apache=${apache2_4_filename}
mysql=${mysql8_0_filename}
php=${php7_3_filename}

# Wordpress DB setting
mysql_word_press_db="wp_myblog"
mysql_word_press_user="wordpress"

#software array setting
apache_arr=(
${apache2_4_filename}
do_not_install
)

}
                                                                                                                                                                                                                                          lamp/include/apache.sh                                                                              000644  000765  000024  00000030641 13564533005 016510  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #Install apache

install_apache(){
    apache_configure_args="--prefix=${apache_location} \
    --with-pcre=${depends_prefix}/pcre \
    --with-mpm=event \
    --with-included-apr \
    --with-ssl \
    --with-nghttp2 \
    --enable-modules=reallyall \
    --enable-mods-shared=reallyall"

    _info "Starting to install dependencies packages for Apache..."
    local apt_list=(zlib1g-dev openssl libssl-dev libxml2-dev lynx lua-expat-dev libjansson-dev)
    local yum_list=(zlib-devel openssl-devel libxml2-devel lynx expat-devel lua-devel lua jansson-devel)
    if check_sys packageManager apt; then
        for depend in ${apt_list[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
    elif check_sys packageManager yum; then
        for depend in ${yum_list[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
    fi
    _info "Install dependencies packages for Apache completed..."

    if ! grep -qE "^/usr/local/lib" /etc/ld.so.conf.d/*.conf; then
        echo "/usr/local/lib" > /etc/ld.so.conf.d/locallib.conf
    fi
    ldconfig

    check_installed "install_pcre" "${depends_prefix}/pcre"
    check_installed "install_openssl" "${openssl_location}"
    install_nghttp2

    cd ${cur_dir}/software/
    download_file "${apr_filename}.tar.gz" "${apr_filename_url}"
    tar zxf ${apr_filename}.tar.gz
    download_file "${apr_util_filename}.tar.gz" "${apr_util_filename_url}"
    tar zxf ${apr_util_filename}.tar.gz
    download_file "${apache2_4_filename}.tar.gz" "${apache2_4_filename_url}"
    tar zxf ${apache2_4_filename}.tar.gz
    cd ${apache2_4_filename}
    mv ${cur_dir}/software/${apr_filename} srclib/apr
    mv ${cur_dir}/software/${apr_util_filename} srclib/apr-util

    LDFLAGS=-ldl
    if [ -d "${openssl_location}" ]; then
        apache_configure_args=$(echo ${apache_configure_args} | sed -e "s@--with-ssl@--with-ssl=${openssl_location}@")
    fi
    error_detect "./configure ${apache_configure_args}"
    error_detect "parallel_make"
    error_detect "make install"
    unset LDFLAGS
    config_apache
}


config_apache(){
    id -u apache >/dev/null 2>&1
    [ $? -ne 0 ] && groupadd apache && useradd -M -s /sbin/nologin -g apache apache
    [ ! -d "${web_root_dir}" ] && mkdir -p ${web_root_dir} && chmod -R 755 ${web_root_dir}
    if [ -f "${apache_location}/conf/httpd.conf" ]; then
        cp -f ${apache_location}/conf/httpd.conf ${apache_location}/conf/httpd.conf.bak
    fi
    mv ${apache_location}/conf/extra/httpd-vhosts.conf ${apache_location}/conf/extra/httpd-vhosts.conf.bak
    mkdir -p ${apache_location}/conf/vhost/
    grep -qE "^\s*#\s*Include conf/extra/httpd-vhosts.conf" ${apache_location}/conf/httpd.conf && \
    sed -i 's#^\s*\#\s*Include conf/extra/httpd-vhosts.conf#Include conf/extra/httpd-vhosts.conf#' ${apache_location}/conf/httpd.conf || \
    sed -i '$aInclude conf/extra/httpd-vhosts.conf' ${apache_location}/conf/httpd.conf
    sed -i 's/^User.*/User apache/i' ${apache_location}/conf/httpd.conf
    sed -i 's/^Group.*/Group apache/i' ${apache_location}/conf/httpd.conf
    sed -i 's/^#ServerName www.example.com:80/ServerName 0.0.0.0:80/' ${apache_location}/conf/httpd.conf
    sed -i 's/^ServerAdmin you@example.com/ServerAdmin admin@localhost/' ${apache_location}/conf/httpd.conf
    sed -i 's@^#Include conf/extra/httpd-info.conf@Include conf/extra/httpd-info.conf@' ${apache_location}/conf/httpd.conf
    sed -i 's@DirectoryIndex index.html@DirectoryIndex index.html index.php@' ${apache_location}/conf/httpd.conf
    sed -i "s@^DocumentRoot.*@DocumentRoot \"${web_root_dir}\"@" ${apache_location}/conf/httpd.conf
    sed -i "s@^<Directory \"${apache_location}/htdocs\">@<Directory \"${web_root_dir}\">@" ${apache_location}/conf/httpd.conf
    echo "ServerTokens ProductOnly" >> ${apache_location}/conf/httpd.conf
    echo "ProtocolsHonorOrder On" >> ${apache_location}/conf/httpd.conf
    echo "Protocols h2 http/1.1" >> ${apache_location}/conf/httpd.conf
    cat > /etc/logrotate.d/httpd <<EOF
${apache_location}/logs/*log {
    daily
    rotate 14
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${apache_location}/logs/httpd.pid ] || kill -USR1 \`cat ${apache_location}/logs/httpd.pid\`
    endscript
}
EOF
    cat > ${apache_location}/conf/extra/httpd-vhosts.conf <<EOF
Include ${apache_location}/conf/vhost/*.conf
EOF
    cat > ${apache_location}/conf/vhost/default.conf <<EOF
<VirtualHost _default_:80>
ServerName localhost
DocumentRoot ${web_root_dir}
<Directory ${web_root_dir}>
    SetOutputFilter DEFLATE
    Options FollowSymLinks
    AllowOverride All
    Order Deny,Allow
    Allow from All
    DirectoryIndex index.php index.html index.htm
</Directory>
</VirtualHost>
EOF

# httpd modules array
httpd_mod_list=(
mod_actions.so
mod_auth_digest.so
mod_auth_form.so
mod_authn_anon.so
mod_authn_dbd.so
mod_authn_dbm.so
mod_authn_socache.so
mod_authnz_fcgi.so
mod_authz_dbd.so
mod_authz_dbm.so
mod_authz_owner.so
mod_buffer.so
mod_cache.so
mod_cache_socache.so
mod_case_filter.so
mod_case_filter_in.so
mod_charset_lite.so
mod_data.so
mod_dav.so
mod_dav_fs.so
mod_dav_lock.so
mod_deflate.so
mod_echo.so
mod_expires.so
mod_ext_filter.so
mod_http2.so
mod_include.so
mod_info.so
mod_proxy.so
mod_proxy_connect.so
mod_proxy_fcgi.so
mod_proxy_ftp.so
mod_proxy_html.so
mod_proxy_http.so
mod_proxy_http2.so
mod_proxy_scgi.so
mod_ratelimit.so
mod_reflector.so
mod_request.so
mod_rewrite.so
mod_sed.so
mod_session.so
mod_session_cookie.so
mod_socache_dbm.so
mod_socache_memcache.so
mod_socache_shmcb.so
mod_speling.so
mod_ssl.so
mod_substitute.so
mod_suexec.so
mod_unique_id.so
mod_userdir.so
mod_vhost_alias.so
mod_xml2enc.so
)
    # enable some modules by default
    for mod in ${httpd_mod_list[@]}; do
        if [ -s "${apache_location}/modules/${mod}" ]; then
            sed -i -r "s/^#(.*${mod})/\1/" ${apache_location}/conf/httpd.conf
        fi
    done
    # add mod_md to httpd.conf
    if [[ $(grep -Ec "^\s*LoadModule md_module modules/mod_md.so" ${apache_location}/conf/httpd.conf) -eq 0 ]]; then
        if [ -f "${apache_location}/modules/mod_md.so" ]; then
            lnum=$(sed -n '/LoadModule/=' ${apache_location}/conf/httpd.conf | tail -1)
            sed -i "${lnum}aLoadModule md_module modules/mod_md.so" ${apache_location}/conf/httpd.conf
        fi
    fi

    [ -d "${openssl_location}" ] && sed -i "s@^export LD_LIBRARY_PATH.*@export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${openssl_location}/lib@" ${apache_location}/bin/envvars
    sed -i 's/Allow from All/Require all granted/' ${apache_location}/conf/extra/httpd-vhosts.conf
    sed -i 's/Require host .example.com/Require host localhost/g' ${apache_location}/conf/extra/httpd-info.conf
    cp -f ${cur_dir}/conf/httpd24-ssl.conf ${apache_location}/conf/extra/httpd-ssl.conf
    rm -f /etc/init.d/httpd
    if centosversion 6; then
        cp -f ${cur_dir}/init.d/httpd-init-centos6 /etc/init.d/httpd
    else
        cp -f ${cur_dir}/init.d/httpd-init /etc/init.d/httpd
    fi
    sed -i "s#^apache_location=.*#apache_location=${apache_location}#" /etc/init.d/httpd
    chmod +x /etc/init.d/httpd
    rm -fr /var/log/httpd /usr/sbin/httpd
    ln -s ${apache_location}/bin/httpd /usr/sbin/httpd
    ln -s ${apache_location}/logs /var/log/httpd
    cp -f ${cur_dir}/conf/index.html ${web_root_dir}
    cp -f ${cur_dir}/conf/index_cn.html ${web_root_dir}
    cp -f ${cur_dir}/conf/lamp.png ${web_root_dir}
    cp -f ${cur_dir}/conf/jquery.js ${web_root_dir}
    cp -f ${cur_dir}/conf/p.php ${web_root_dir}
    cp -f ${cur_dir}/conf/p_cn.php ${web_root_dir}
    cp -f ${cur_dir}/conf/phpinfo.php ${web_root_dir}
    cp -f ${cur_dir}/conf/favicon.ico ${web_root_dir}
    chown -R apache.apache ${web_root_dir}
    boot_start httpd

}

install_apache_modules(){
    if_in_array "${mod_wsgi_filename}" "${apache_modules_install}" && install_mod_wsgi
    if_in_array "${mod_security_filename}" "${apache_modules_install}" && install_mod_security
    if_in_array "${mod_jk_filename}" "${apache_modules_install}" && install_mod_jk
}

install_pcre(){
    cd ${cur_dir}/software/
    _info "${pcre_filename} install start..."
    download_file "${pcre_filename}.tar.gz" "${pcre_filename_url}"
    tar zxf ${pcre_filename}.tar.gz
    cd ${pcre_filename}

    error_detect "./configure --prefix=${depends_prefix}/pcre"
    error_detect "parallel_make"
    error_detect "make install"
    add_to_env "${depends_prefix}/pcre"
    create_lib64_dir "${depends_prefix}/pcre"
    _info "${pcre_filename} install completed..."
}

install_nghttp2(){
    cd ${cur_dir}/software/
    _info "${nghttp2_filename} install start..."
    download_file "${nghttp2_filename}.tar.gz" "${nghttp2_filename_url}"
    tar zxf ${nghttp2_filename}.tar.gz
    cd ${nghttp2_filename}

    if [ -d "${openssl_location}" ]; then
        export OPENSSL_CFLAGS="-I${openssl_location}/include"
        export OPENSSL_LIBS="-L${openssl_location}/lib -lssl -lcrypto"
    fi
    error_detect "./configure --prefix=/usr --enable-lib-only"
    error_detect "parallel_make"
    error_detect "make install"
    unset OPENSSL_CFLAGS OPENSSL_LIBS
    _info "${nghttp2_filename} install completed..."
}

install_openssl(){
    local openssl_version=$(openssl version -v)
    local major_version=$(echo ${openssl_version} | awk '{print $2}' | grep -oE "[0-9.]+")

    if version_lt ${major_version} 1.1.1; then
        cd ${cur_dir}/software/
        _info "${openssl_filename} install start..."
        download_file "${openssl_filename}.tar.gz" "${openssl_filename_url}"
        tar zxf ${openssl_filename}.tar.gz
        cd ${openssl_filename}

        error_detect "./config --prefix=${openssl_location} -fPIC shared zlib"
        error_detect "make"
        error_detect "make install"

        if ! grep -qE "^${openssl_location}/lib" /etc/ld.so.conf.d/*.conf; then
            echo "${openssl_location}/lib" > /etc/ld.so.conf.d/openssl.conf
        fi
        ldconfig
        _info "${openssl_filename} install completed..."
    else
        _info "OpenSSL version is greater than or equal to 1.1.1, installation skipped."
    fi
}

install_mod_wsgi(){
    cd ${cur_dir}/software/
    _info "${mod_wsgi_filename} install start..."
    download_file "${mod_wsgi_filename}.tar.gz" "${mod_wsgi_filename_url}"
    tar zxf ${mod_wsgi_filename}.tar.gz
    cd ${mod_wsgi_filename}

    error_detect "./configure --with-apxs=${apache_location}/bin/apxs"
    error_detect "make"
    error_detect "make install"
    # add mod_wsgi to httpd.conf
    if [[ $(grep -Ec "^\s*LoadModule wsgi_module modules/mod_wsgi.so" ${apache_location}/conf/httpd.conf) -eq 0 ]]; then
        lnum=$(sed -n '/LoadModule/=' ${apache_location}/conf/httpd.conf | tail -1)
        sed -i "${lnum}aLoadModule wsgi_module modules/mod_wsgi.so" ${apache_location}/conf/httpd.conf
    fi
    _info "${mod_wsgi_filename} install completed..."
}

install_mod_jk(){
    cd ${cur_dir}/software/
    _info "${mod_jk_filename} install start..."
    download_file "${mod_jk_filename}.tar.gz" "${mod_jk_filename_url}"
    tar zxf ${mod_jk_filename}.tar.gz
    cd ${mod_jk_filename}/native

    error_detect "./configure --with-apxs=${apache_location}/bin/apxs --enable-api-compatibility"
    error_detect "make"
    error_detect "make install"
    # add mod_jk to httpd.conf
    if [[ $(grep -Ec "^\s*LoadModule jk_module modules/mod_jk.so" ${apache_location}/conf/httpd.conf) -eq 0 ]]; then
        lnum=$(sed -n '/LoadModule/=' ${apache_location}/conf/httpd.conf | tail -1)
        sed -i "${lnum}aLoadModule jk_module modules/mod_jk.so" ${apache_location}/conf/httpd.conf
    fi
    _info "${mod_jk_filename} install completed..."
}

install_mod_security(){
    cd ${cur_dir}/software/
    _info "${mod_security_filename} install start..."
    download_file "${mod_security_filename}.tar.gz" "${mod_security_filename_url}"
    tar zxf ${mod_security_filename}.tar.gz
    cd ${mod_security_filename}

    error_detect "./configure --prefix=${depends_prefix} --with-apxs=${apache_location}/bin/apxs --with-apr=${apache_location}/bin/apr-1-config --with-apu=${apache_location}/bin/apu-1-config"
    error_detect "make"
    error_detect "make install"
    chmod 755 ${apache_location}/modules/mod_security2.so
    # add mod_security2 to httpd.conf
    if [[ $(grep -Ec "^\s*LoadModule security2_module modules/mod_security2.so" ${apache_location}/conf/httpd.conf) -eq 0 ]]; then
        lnum=$(sed -n '/LoadModule/=' ${apache_location}/conf/httpd.conf | tail -1)
        sed -i "${lnum}aLoadModule security2_module modules/mod_security2.so" ${apache_location}/conf/httpd.conf
    fi
    _info "${mod_security_filename} install completed..."
}
                                                                                               lamp/init.d/                                                                                        000755  000765  000024  00000000000 13564502144 014471  5                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         lamp/init.d/httpd-init-centos6                                                                      000644  000765  000024  00000010721 13564465250 020066  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# httpd        Startup script for the Apache Web Server
#
# chkconfig: - 85 15
# description: The Apache HTTP Server is an efficient and extensible  \
#             server implementing the current HTTP standards.
# processname: httpd
# pidfile: /var/run/httpd.pid
# config: /etc/sysconfig/httpd
#
### BEGIN INIT INFO
# Provides: httpd
# Required-Start: $local_fs $remote_fs $network $named
# Required-Stop: $local_fs $remote_fs $network
# Should-Start: distcache
# Short-Description: start and stop Apache HTTP Server
# Description: The Apache HTTP Server is an extensible server 
#  implementing the current HTTP standards.
### END INIT INFO

# Source function library.
. /etc/rc.d/init.d/functions

# What were we called? Multiple instances of the same daemon can be
# created by creating suitably named symlinks to this startup script
prog=$(basename $0 | sed -e 's/^[SK][0-9][0-9]//')

if [ -f /etc/sysconfig/${prog} ]; then
        . /etc/sysconfig/${prog}
fi

# Start httpd in the C locale by default.
HTTPD_LANG=${HTTPD_LANG-"C"}

# This will prevent initlog from swallowing up a pass-phrase prompt if
# mod_ssl needs a pass-phrase from the user.
INITLOG_ARGS=""

# Set HTTPD=/usr/sbin/httpd.worker in /etc/sysconfig/httpd to use a server
# with the thread-based "worker" MPM; BE WARNED that some modules may not
# work correctly with a thread-based MPM; notably PHP will refuse to start.
apache_location=/usr/local/apache

httpd=${apache_location}/bin/httpd
pidfile=${apache_location}/logs/${prog}.pid
lockfile=${LOCKFILE-/var/lock/subsys/${prog}}
RETVAL=0

# pick up any necessary environment variables
if test -f ${apache_location}/bin/envvars; then
  . ${apache_location}/bin/envvars
fi


# check for 1.3 configuration
check13 () {
	CONFFILE=${apache_location}/conf/httpd.conf
	GONE="(ServerType|BindAddress|Port|AddModule|ClearModuleList|"
	GONE="${GONE}AgentLog|RefererLog|RefererIgnore|FancyIndexing|"
	GONE="${GONE}AccessConfig|ResourceConfig)"
	if grep -Eiq "^[[:space:]]*($GONE)" $CONFFILE; then
		echo
		echo 1>&2 " Apache 1.3 configuration directives found"
		echo 1>&2 " please read @docdir@/migration.html"
		failure "Apache 1.3 config directives test"
		echo
		exit 1
	fi
}

# The semantics of these two functions differ from the way apachectl does
# things -- attempting to start while running is a failure, and shutdown
# when not running is also a failure.  So we just do it the way init scripts
# are expected to behave here.
start() {
        echo -n $"Starting $prog: "
        check13 || exit 1
        LANG=$HTTPD_LANG daemon --pidfile=${pidfile} $httpd $OPTIONS
        RETVAL=$?
        echo
        [ $RETVAL = 0 ] && touch ${lockfile}
        return $RETVAL
}
stop() {
	echo -n $"Stopping $prog: "
	killproc -p ${pidfile} -d 10 $httpd
	RETVAL=$?
	echo
	[ $RETVAL = 0 ] && rm -f ${lockfile} ${pidfile}
}
reload() {
	echo -n $"Reloading $prog: "
	check13 || exit 1
	killproc -p ${pidfile} $httpd -HUP
	RETVAL=$?
	echo
}

# See how we were called.
case "$1" in
  start)
	start
	;;
  stop)
	stop
	;;
  status)
        if ! test -f ${pidfile}; then
            echo $prog is stopped
            RETVAL=3
        else  
            status -p ${pidfile} $httpd
            RETVAL=$?
        fi
        ;;
  restart)
	stop
	start
	;;
  condrestart)
	if test -f ${pidfile} && status -p ${pidfile} $httpd >&/dev/null; then
		stop
		start
	fi
	;;
  reload)
        reload
	;;
  configtest)
        LANG=$HTTPD_LANG $httpd $OPTIONS -t
        RETVAL=$?
        ;;
  graceful)
        echo -n $"Gracefully restarting $prog: "
        LANG=$HTTPD_LANG $httpd $OPTIONS -k $@
        RETVAL=$?
        echo
        ;;
  *)
	echo $"Usage: $prog {start|stop|restart|condrestart|reload|status|graceful|help|configtest}"
	exit 1
esac

exit $RETVAL
                                               lamp/init.d/httpd-init                                                                              000644  000765  000024  00000007703 13564465250 016515  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #!/bin/bash
# Startup script for the Apache Web Server
# chkconfig: 345 85 15
# Description: Startup script for Apache webserver on Debian. Place in /etc/init.d and
# run 'update-rc.d -f httpd defaults', or use the appropriate command on your
# distro. For CentOS/Redhat run: 'chkconfig --add httpd'

### BEGIN INIT INFO
# Provides:          httpd
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts Apache Web Server
# Description:       starts Apache Web Server
### END INIT INFO

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# Apache control script designed to allow an easy command line interface
# to controlling Apache.  Written by Marc Slemko, 1997/08/23
# 
# The exit codes returned are:
#   XXX this doc is no longer correct now that the interesting
#   XXX functions are handled by httpd
#   0 - operation completed successfully
#   1 - 
#   2 - usage error
#   3 - httpd could not be started
#   4 - httpd could not be stopped
#   5 - httpd could not be started during a restart
#   6 - httpd could not be restarted during a restart
#   7 - httpd could not be restarted during a graceful restart
#   8 - configuration syntax error
#
# When multiple arguments are given, only the error from the _last_
# one is reported.  Run "apachectl help" for usage info
#
ARGV="$@"
#
# |||||||||||||||||||| START CONFIGURATION SECTION  ||||||||||||||||||||
# --------------------                              --------------------
# 
# the path to your httpd binary, including options if necessary
apache_location=/usr/local/apache
HTTPD=${apache_location}/bin/httpd
#
# pick up any necessary environment variables
if test -f ${apache_location}/bin/envvars; then
  . ${apache_location}/bin/envvars
fi
#
# a command that outputs a formatted text version of the HTML at the
# url given on the command line.  Designed for lynx, however other
# programs may work.  
LYNX="lynx -dump"
#
# the URL to your server's mod_status status page.  If you do not
# have one, then status and fullstatus will not work.
STATUSURL="http://localhost:80/server-status"
#
# Set this variable to a command that increases the maximum
# number of file descriptors allowed per child process. This is
# critical for configurations that use many file descriptors,
# such as mass vhosting, or a multithreaded server.
ULIMIT_MAX_FILES="ulimit -S -n `ulimit -H -n`"
# --------------------                              --------------------
# ||||||||||||||||||||   END CONFIGURATION SECTION  ||||||||||||||||||||

# Set the maximum number of file descriptors allowed per child process.
if [ "x$ULIMIT_MAX_FILES" != "x" ] ; then
    $ULIMIT_MAX_FILES
fi

ERROR=0
if [ "x$ARGV" = "x" ] ; then 
    ARGV="-h"
fi

case $ARGV in
start|stop|restart|graceful|graceful-stop)
    $HTTPD -k $ARGV
    ERROR=$?
    ;;
startssl|sslstart|start-SSL)
    echo The startssl option is no longer supported.
    echo Please edit httpd.conf to include the SSL configuration settings
    echo and then use "apachectl start".
    ERROR=2
    ;;
configtest)
    $HTTPD -t
    ERROR=$?
    ;;
status)
    $LYNX $STATUSURL | awk ' /process$/ { print; exit } { print } '
    ;;
fullstatus)
    $LYNX $STATUSURL
    ;;
*)
    $HTTPD $ARGV
    ERROR=$?
esac

exit $ERROR

                                                             lamp/lamp.sh                                                                                        000644  000765  000024  00000007053 13564507656 014613  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cur_dir=$(pwd)

include(){
    local include=${1}
    if [[ -s ${cur_dir}/include/${include}.sh ]];then
        . ${cur_dir}/include/${include}.sh
    else
        echo "Error: ${cur_dir}/include/${include}.sh not found, shell can not be executed."
        exit 1
    fi
}

#lamp auto process
lamp_pre_check(){
    check_os
    check_ram
    display_os_info
    last_confirm
}

#start install lamp
lamp_install(){
    disable_selinux
    install_tools
    sync_time
    remove_packages

    if [ ! -d ${cur_dir}/software ]; then
        mkdir -p ${cur_dir}/software
    fi
    [ "${apache}" != "do_not_install" ] && check_installed "install_apache" "${apache_location}"
    [ "${apache_modules_install}" != "do_not_install" ] && install_apache_modules
    check_installed "install_mysqld" "${mysql_location}"
    [ "${php}" != "do_not_install" ] && check_installed "install_php" "${php_location}"
    install_finally
}

install_finally(){
    _info "Starting clean up..."
    cd ${cur_dir}
    rm -rf ${cur_dir}/software
    _info "Clean up completed..."

    if check_sys packageManager yum; then
        firewall_set
    fi

    echo
    echo "Congratulations, LAMP install completed!"
    echo
    echo "------------------------ Installed Overview -------------------------"
    echo
    echo "Apache: ${apache}"
    if [ "${apache}" != "do_not_install" ]; then
        echo "Default Website: http://$(get_ip)"
        echo "Apache Location: ${apache_location}"
    fi
    
    echo
    echo "Database: ${mysql}"
    if [ -d ${mysql_location} ]; then
        echo "MySQL Location: ${mysql_location}"
        echo "MySQL Data Location: ${mysql_data_location}"
        echo "MySQL Root Password: ${mysql_root_pass}"
        dbrootpwd=${mysql_root_pass}
    fi

    echo
    echo "PHP: ${php}"
    [ "${php}" != "do_not_install" ] && echo "PHP Location: ${php_location}"
    
    echo
    echo "---------------------------------------------------------------------"
    echo

    cp -f ${cur_dir}/conf/lamp /usr/bin/lamp
    chmod +x /usr/bin/lamp
    sed -i "s@^apache_location=.*@apache_location=${apache_location}@" /usr/bin/lamp
    sed -i "s@^mysql_location=.*@mysql_location=${mysql_location}@" /usr/bin/lamp
    sed -i "s@^web_root_dir=.*@web_root_dir=${web_root_dir}@" /usr/bin/lamp

    ldconfig

    # Add phpmyadmin Alias
    if [ -d "${web_root_dir}/phpmyadmin" ]; then
        cat >> ${apache_location}/conf/httpd.conf <<EOF
<IfModule alias_module>
    Alias /phpmyadmin ${web_root_dir}/phpmyadmin
</IfModule>
EOF
    fi


    if [ "${apache}" != "do_not_install" ]; then
        echo "Starting Apache..."
        /etc/init.d/httpd start > /dev/null 2>&1
    fi
    if [ "${mysql}" != "do_not_install" ]; then
        echo "Starting Database..."
        /etc/init.d/mysqld start > /dev/null 2>&1
    fi

    # Install phpmyadmin database
    if [ -d "${web_root_dir}/phpmyadmin" ] && [ -f /usr/bin/mysql ]; then
        /usr/bin/mysql -uroot -p${dbrootpwd} < ${web_root_dir}/phpmyadmin/sql/create_tables.sql > /dev/null 2>&1
    fi

    sleep 1
    netstat -tunlp
    echo
    _info "Start time     : ${StartDate}"
    _info "Completion time: $(date "+%Y-%m-%d %H:%M:%S") (Use:$(_red $[($(date +%s)-StartDateSecond)/60]) minutes)"
    exit 0
}

ask_mysql_settings(){
    mysql_preinstall_settings
}

main() {
    lamp_pre_check
    lamp_install
}

include config
include public
include apache
include mysql
include php
include php-modules
load_config
rootness

#Run it
main "$@" 2>&1 | tee ${cur_dir}/lamp.log                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     lamp/uninstall.sh                                                                                   000644  000765  000024  00000006614 13564465250 015666  0                                                                                                    ustar 00kiritdevda                      staff                           000000  000000                                                                                                                                                                         #!/usr/bin/env bash
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
# System Required:  CentOS 6+ / Fedora28+ / Debian 8+ / Ubuntu 14+
# Description:  Uninstall LAMP(Linux + Apache + MySQL/MariaDB/Percona + PHP )
# Website:  https://lamp.sh
# Github:   https://github.com/teddysun/lamp

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cur_dir=$(pwd)

include(){
    local include=$1
    if [[ -s ${cur_dir}/include/${include}.sh ]]; then
        . ${cur_dir}/include/${include}.sh
    else
        echo "Error:${cur_dir}/include/${include}.sh not found, shell can not be executed."
        exit 1
    fi
}

uninstall_lamp(){
    _info "uninstalling Apache"
    if [ -f /etc/init.d/httpd ] && [ $(ps -ef | grep -v grep | grep -c "httpd") -gt 0 ]; then
        /etc/init.d/httpd stop > /dev/null 2>&1
    fi
    rm -f /etc/init.d/httpd
    rm -rf ${apache_location} /usr/sbin/httpd /var/log/httpd /etc/logrotate.d/httpd /var/spool/mail/apache
    _info "Success"
    echo
    _info "uninstalling MySQL or MariaDB or Percona Server"
    if [ -f /etc/init.d/mysqld ] && [ $(ps -ef | grep -v grep | grep -c "mysqld") -gt 0 ]; then
        /etc/init.d/mysqld stop > /dev/null 2>&1
    fi
    rm -f /etc/init.d/mysqld
    rm -rf ${mysql_location} ${mariadb_location} ${percona_location} /usr/bin/mysqldump /usr/bin/mysql /etc/my.cnf /etc/ld.so.conf.d/mysql.conf
    _info "Success"
    echo
    _info "uninstalling PHP"
    rm -rf ${php_location} /usr/bin/php /usr/bin/php-config /usr/bin/phpize /etc/php.ini
    _info "Success"
    echo
    _info "uninstalling others software"
    [ -f /etc/init.d/memcached ] && /etc/init.d/memcached stop > /dev/null 2>&1
    rm -f /etc/init.d/memcached
    rm -fr ${depends_prefix}/memcached /usr/bin/memcached
    [ -f /etc/init.d/redis-server ] && /etc/init.d/redis-server stop > /dev/null 2>&1
    rm -f /etc/init.d/redis-server
    rm -rf ${depends_prefix}/redis
    rm -rf /usr/local/lib/libcharset* /usr/local/lib/libiconv* /usr/local/lib/charset.alias /usr/local/lib/preloadable_libiconv.so
    rm -rf ${depends_prefix}/imap
    rm -rf ${depends_prefix}/pcre
    rm -rf ${openssl_location} /etc/ld.so.conf.d/openssl.conf
    rm -rf /usr/lib/libnghttp2.*
    rm -rf /usr/local/lib/libmcrypt.*
    rm -rf /usr/local/lib/libmhash.*
    rm -rf /usr/local/bin/iconv
    rm -rf /usr/local/bin/re2c
    rm -rf /usr/local/bin/mcrypt
    rm -rf /usr/local/bin/mdecrypt
    rm -rf /etc/ld.so.conf.d/locallib.conf
    rm -rf ${web_root_dir}/phpmyadmin
    rm -rf ${web_root_dir}/kod
    rm -rf ${web_root_dir}/xcache /tmp/{pcov,phpcore}
    _info "Success"
    echo
    _info "Successfully uninstall LAMP"
}

include config
include public
load_config
rootness

while true
do
    read -p "Are you sure uninstall LAMP? (Default: n) (y/n)" uninstall
    [ -z ${uninstall} ] && uninstall="n"
    uninstall=$(upcase_to_lowcase ${uninstall})
    case ${uninstall} in
        y) uninstall_lamp ; break;;
        n) _info "Uninstall cancelled, nothing to do" ; break;;
        *) _warn "Input error, Please only input y or n";;
    esac
done
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    