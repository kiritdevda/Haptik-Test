#!/usr/bin/env bash
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
main "$@" 2>&1 | tee ${cur_dir}/lamp.log