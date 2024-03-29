#Intall PHP
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
