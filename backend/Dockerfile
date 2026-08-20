# syntax=docker/dockerfile:1
FROM php:8.3-apache

# mod_rewrite covers .htaccess front-controller routing (Laravel, Symfony,
# and the plain "route everything through index.php" pattern).
RUN a2enmod rewrite

# Common extensions. Kept to ones with no external dev headers so the build
# stays fast and never fails on a missing system library.
RUN docker-php-ext-install pdo pdo_mysql mysqli opcache

WORKDIR /var/www/html
COPY . .

# Dependencies only when the app actually declares them.
RUN if [ -f composer.json ]; then \
      curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
      composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader; \
    fi

# Serve from the app's real document root and listen on an unprivileged port.
RUN sed -ri "s#DocumentRoot /var/www/html#DocumentRoot /var/www/html#" /etc/apache2/sites-available/000-default.conf && \
    sed -ri "s#<Directory /var/www/>#<Directory /var/www/html>#" /etc/apache2/apache2.conf && \
    sed -ri "s/^Listen 80$/Listen 8080/" /etc/apache2/ports.conf && \
    sed -ri "s/:80>/:8080>/" /etc/apache2/sites-available/000-default.conf && \
    printf '<Directory %s>\n    AllowOverride All\n    Require all granted\n</Directory>\n' "/var/www/html" \
      > /etc/apache2/conf-available/deepagent-docroot.conf && \
    a2enconf deepagent-docroot && \
    chown -R www-data:www-data /var/www/html

USER www-data
EXPOSE 8080
CMD ["apache2-foreground"]
