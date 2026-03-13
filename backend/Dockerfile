# Step1 Get the base image
FROM php:8.2-apache

# Step2 install php extension that allow php to communicate to MSQL
RUN docker-php-ext-install mysqli pdo pdo_mysql

# Step3 Enable apache rewrite module
RUN a2enmod rewrite

# Step4 Set working directory
WORKDIR /var/www/html

# Step5 Copy entire application code
COPY . .

# Step6 Set correct permissions for Apache to access the files
RUN chown -R www-data:www-data /var/www/html

# Step7 Expose
EXPOSE 80

# Step8 Start Apache server
CMD ["apache2-foreground"]