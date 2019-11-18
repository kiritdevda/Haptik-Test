install_wordpress(){
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
    sed  -i "s/^define(.*'DB_PASSWORD'.*/define( \x27DB_PASSWORD\x27, \x27${mysql_word_press_password}\x27 );/" wp-config.php
    sed  -i "s/^define(.*'DB_USER'.*/define( \x27DB_USER\x27, \x27${mysql_word_press_user}\x27 );/" wp-config.php
    sed  -i "s/^define(.*'DB_NAME'.*/define( \x27DB_NAME\x27, \x27${mysql_word_press_db}\x27 );/" wp-config.php
        if check_sys packageManager apt; then
            error_detect_depends "apt-get -y install dos2unix"
        elif check_sys packageManager yum; then
            error_detect_depends "yum -y install dos2unix"
	fi
dos2unix wp-config.php
}
