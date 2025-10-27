# 使用 PHP 7.x 的官方镜像
FROM php:7.4-fpm

# 安装必要的 PHP 扩展和工具
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    zlib1g-dev \
    libzip-dev \
    unzip \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install gd mysqli pdo pdo_mysql zip bcmath \
    && pecl install redis \
    && docker-php-ext-enable redis

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# 将工作目录设置为 /var/www
WORKDIR /var/www

# 将当前目录复制到容器中的 /var/www
COPY . /var/www

# 设置文件权限
RUN chown -R www-data:www-data /var/www

# 暴露端口 9000 用于 PHP-FPM
EXPOSE 9000