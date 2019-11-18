
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
}