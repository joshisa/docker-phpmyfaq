FROM php:7.1.7-apache

MAINTAINER boilerupnc <joshisa@us.ibm.com>

#=== Install vim support ===
RUN set -xe; \
  \
  runtimeDeps=' \
    vim \
    vim-youcompleteme \
  ' \
  && apt-get update && apt-get install -y ${runtimeDeps} && vam install youcompleteme
 
#=== Install gd (php dependencie) ===
RUN set -xe; \
  \
  buildDeps=' \
    libpng12-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
  ' \
  && apt-get update && apt-get install -y ${buildDeps} \
  \
  && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
  && docker-php-ext-install gd \
  \
  && apt-get purge -y ${buildDeps} \
  && rm -rf /var/lib/apt/lists/*

#=== Install ldap (php dependencie) ===
RUN set -xe; \
  \
  buildDeps=' \
    libldap2-dev \
  ' \
  && apt-get update && apt-get install -y ${buildDeps} \
  \
  && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
  && docker-php-ext-install ldap \
  \
  && apt-get purge -y ${buildDeps} \
  && rm -rf /var/lib/apt/lists/*

#=== Install other php dependencies ===
RUN set -xe; \
  \
  runtimeDeps=' \
    re2c \
    libmcrypt-dev \
    file \
    zlib1g-dev \
    libxml2-dev \
    libpq-dev \
    sendmail \
  ' \
  && apt-get update && apt-get install -y ${runtimeDeps} \
  \
  && docker-php-ext-install mcrypt fileinfo zip soap mysqli pdo pdo_pgsql pgsql json \
  \
  && rm -rf /var/lib/apt/lists/*

#=== Add the www-data to the root group to work with files on volume ===
RUN usermod -a -G root www-data

#=== Add phpMyFAQ source code and set permissions ===
ENV PHPMYFAQ_VERSION=2.9.13
RUN set -x \
  && curl -sL http://download.phpmyfaq.de/phpMyFAQ-${PHPMYFAQ_VERSION}.tar.gz | tar xz \
  \
  && folders=' \
    ./phpmyfaq/attachments \
    ./phpmyfaq/data \
    ./phpmyfaq/images \
  ' \
  && mkdir ${folders} \
  && chmod 775 ${folders} \
  && chown -R www-data:www-data ./phpmyfaq

#=== Configure apache ===
RUN { \
    echo '<VirtualHost *:80>'; \
    echo 'ServerName phpmyfaq'; \
    echo 'DocumentRoot /var/www/html/phpmyfaq'; \
    echo; \
    echo '<Directory /var/www/html/phpmyfaq>'; \
    echo '\tOptions -Indexes'; \
    echo '\tAllowOverride all'; \
    echo '</Directory>'; \
    echo '</VirtualHost>'; \
  } | tee "$APACHE_CONFDIR/sites-available/phpmyfaq.conf" \
  \
  && a2ensite phpmyfaq \
  && a2dissite 000-default \
  && echo "ServerName localhost" >> "$APACHE_CONFDIR/apache2.conf"

#=== Configure php ===
RUN { \
    echo 'date.timezone = America/New_York'; \
    echo 'register_globals = off'; \
    echo 'safe_mode = off'; \
    echo 'memory_limit = 256M'; \
    echo 'file_upload = on'; \
  } | tee "$PHP_INI_DIR/php.ini"

#=== Enabling htaccess for search engine optimisations ===
RUN set -xe \
  \
  && a2enmod rewrite headers \
  \
  && mv ./phpmyfaq/_.htaccess ./phpmyfaq/.htaccess \
  && sed -ri 's~RewriteBase /phpmyfaq/~RewriteBase /~' ./phpmyfaq/.htaccess

#=== Entrypoint ===
RUN { \
    echo '#!/bin/bash'; \
    echo 'set -e'; \
    echo; \
#    echo 'chown www-data:www-data /var/www/html/phpmyfaq/attachments'; \
#    echo 'chown www-data:www-data /var/www/html/phpmyfaq/data'; \
#    echo 'chown www-data:www-data /var/www/html/phpmyfaq/images'; \
#    echo 'chown www-data:www-data /var/www/html/phpmyfaq/config'; \
    echo; \
    echo 'docker-php-entrypoint "$@"'; \
  } | tee "/usr/local/bin/phpmyfaq-entrypoint" \
  \
  && chmod +x /usr/local/bin/phpmyfaq-entrypoint

ENTRYPOINT [ "phpmyfaq-entrypoint" ]

CMD [ "apache2-foreground" ]
