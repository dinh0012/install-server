#!/usr/bin/env bash
yum -y update && yum -y upgrade

yum install -y wget
sudo yum install epel-release yum-utils

wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
wget http://rpms.remirepo.net/enterprise/remi-release-7.rpm
rpm -Uvh remi-release-7.rpm epel-release-latest-7.noarch.rpm

echo "Install Nodejs, nginx"
yum install -y nodejs nginx


echo "Installing php7"
yum-config-manager --enable remi-php71
yum install -y php php-fpm php-mbstring php-xml php-gd php-pecl-zip php-pdo php-mysql php-pecl-xdebug git

echo "Installing mysql 5.7 server community version"
yum -y localinstall https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
yum install -y mysql-community-server

echo "Switch System Datetime to Asia/Tokyo "
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

echo "Temporary mysql root password"
grep -r 'A tempmysorary password is generated for' /var/log/mysqld.log

systemctl start mysqld
systemctl enable mysqld
MYSQL_TEMP_PWD=`sudo cat /var/log/mysqld.log | grep 'A temporary password is generated' | awk -F'root@localhost: ' '{print $2}'`
echo $MYSQL_TEMP_PWD
mysqladmin -u root -p echo $MYSQL_TEMP_PWD password 'Biznext2018'
mysql -uroot -pBiznext2018 -e 'CREATE DATABASE IF NOT EXISTS biznext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
mysql -uroot -pBiznext2018 -e "GRANT ALL ON *.* to root@'localhost' IDENTIFIED BY 'Biznext2018'; FLUSH PRIVILEGES;"
mysql -uroot -pBiznext2018 -e "GRANT ALL ON *.* to root@'localhost' IDENTIFIED BY 'Biznext2018'; FLUSH PRIVILEGES;"
wget https://getcomposer.org/composer.phar
chmod +x composer.phar
mv composer.phar /usr/bin/composer

 sed -i -e 's@;cgi\.fix_pathinfo=1@cgi\.fix_pathinfo=0@g' /etc/php.ini
  sed -i -e 's@listen = 127\.0\.0\.1\:9000@listen=\/var\/run\/php\-fpm\/php\-fpm\.sock@g' /etc/php-fpm.d/www.conf
  sed -i -e 's@;listen\.owner = nobody@listen\.owner = nginx@g'  /etc/php-fpm.d/www.conf
  sed -i -e 's@;listen\.group = nobody@listen\.group = nginx@g'  /etc/php-fpm.d/www.conf
  sed -i -e 's@user = apache@user = nginx@g'  /etc/php-fpm.d/www.conf
  sed -i -e 's@group = apache@group = nginx@g'  /etc/php-fpm.d/www.conf
  sed -i -e 's@;date\.timezone =@date\.timezone = Asia/Tokyo@g'  /etc/php.ini

  echo '
  [XDebug]
  xdebug.remote_enable = 1
  xdebug.remote_connect_back = 1
  ' > /etc/php.d/15-xdebug.ini

  systemctl start php-fpm
  systemctl enable php-fpm



echo  '
server {
    listen 80;
    #listen [::]:8181;
    root /var/www/biznext/source/owncloud;
    index  index.php index.html index.htm;
    server_name  _;

    #ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    #ssl_certificate /var/www/biznext/source/owncloud/resources/config/ca-bundle.crt;
    #ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;


    client_body_in_file_only clean;
    client_body_buffer_size 32K;
    client_max_body_size 4000M;
    sendfile on;
    send_timeout 600s;

    location / {
        rewrite ^ /index.php$uri;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   Host      $http_host;

        # these two lines here
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_read_timeout 150;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
        return 404;
    }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
        return 404;
    }

    location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+|core/templates/40[34])\.php(?:$|/) {
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        fastcgi_pass             unix:/var/run/php-fpm/php-fpm.sock; # Ubuntu 17.10
    #   fastcgi_pass             unix:/var/run/php-fpm/php-fpm.sock; # Ubuntu 17.04
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
        fastcgi_param htaccessWorking true;
        fastcgi_read_timeout 150;
    }

    location ~ ^/(?:updater|ocs-provider)(?:$|/) {
        try_files $uri $uri/ =404;
        index index.php;
    }

    location ~* \.(?:svg|gif|png|html|ttf|woff|ico|jpg|jpeg|js|css|map)$ {
        try_files $uri /index.php$uri$is_args$args;
        access_log off;
    }

}

' > /etc/nginx/conf.d/owncloud.conf

echo  '
server {
    listen   8080;
    server_name _;

    # note that these lines are originally from the "location /" block
    root   /var/www/biznext/source/biznext-react-app/build;
    index index.html index.htm;

    location / {
        #try_files $uri $uri/ /index.php?$query_string;
        try_files $uri $uri/ /index.html;
        #try_files $uri $uri/ =404;
    }
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }

    location /assets/ {
        root /var/www/biznext/source/biznext-react-app/src/;
        autoindex off;
    }

    location ~ \.php$ {
        #try_files $uri =404;
        fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}

' > /etc/nginx/conf.d/react-app.conf

nginx -t
systemctl start nginx
systemctl enable nginx.service