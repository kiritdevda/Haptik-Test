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
