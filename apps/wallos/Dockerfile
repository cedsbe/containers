FROM php:8-fpm-alpine

# Version configuration
ARG WALLOS_VERSION=v4.6.0 # renovate: datasource=github-releases depName=ellite/Wallos
ARG NGINX_PORT=8080
ARG SUPERCRONIC_VERSION=v0.2.41 # renovate: datasource=github-releases depName=aptible/supercronic

# Build architecture (automatically set by Docker BuildKit)
ARG TARGETARCH

# OCI labels
LABEL org.opencontainers.image.source="https://github.com/cedsbe/containers"
LABEL org.opencontainers.image.description="Wallos - Open-Source Personal Subscription Tracker"
LABEL org.opencontainers.image.version="${WALLOS_VERSION}"

RUN <<EOF
    apk upgrade --no-cache
    apk add --no-cache \
        dumb-init \
        sqlite-dev \
        libpng \
        libpng-dev \
        libjpeg-turbo \
        libjpeg-turbo-dev \
        freetype \
        freetype-dev \
        curl \
        autoconf \
        libgomp \
        icu-dev \
        icu-data-full \
        nginx \
        tzdata \
        imagemagick \
        imagemagick-dev \
        libzip-dev \
        sqlite \
        libwebp-dev \
        dos2unix \
        unzip \
        wget
    docker-php-ext-install pdo pdo_sqlite calendar
    docker-php-ext-enable pdo pdo_sqlite
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
    docker-php-ext-install -j$(nproc) gd intl zip

    # imagick requires compilation
    # The PHPIZE_DEPS variable is provided by the php:*-alpine images
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS
    pecl install imagick
    docker-php-ext-enable imagick
    apk del .build-deps

    # Download and install supercronic for rootless cron support (multi-arch)
    curl -fsSLO "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}"
    chmod +x "supercronic-linux-${TARGETARCH}"
    mv "supercronic-linux-${TARGETARCH}" /usr/local/bin/supercronic
    supercronic -version
EOF

# Download and extract Wallos application
RUN <<EOF
    set -euo pipefail
    echo "Downloading Wallos version ${WALLOS_VERSION}"
    curl -fSL -o /tmp/wallos.zip https://github.com/ellite/Wallos/archive/refs/tags/${WALLOS_VERSION}.zip
    unzip -q /tmp/wallos.zip -d /tmp
    cp -r /tmp/Wallos-${WALLOS_VERSION#v}/* /var/www/html/
    rm -rf /tmp/wallos.zip /tmp/Wallos-${WALLOS_VERSION#v}
EOF

# Copy our custom startup.sh and nginx configs (overwrite Wallos release versions)
# Copy our custom nginx.conf (clean config without embedded server block)
COPY startup.sh /var/www/html/startup.sh
COPY nginx-default.conf /tmp/nginx-default.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Configure Nginx for non-root operation with arbitrary UID/GID
RUN <<EOF
    set -euo pipefail
    echo "Configuring Nginx"
    mkdir -p /etc/nginx/conf.d
    # Remove Wallos-provided nginx configs (we use our own with security rules)
    rm -f /var/www/html/nginx.conf /var/www/html/nginx.default.conf

    # Use our custom default.conf with proper PHP config and security rules
    cp /tmp/nginx-default.conf /etc/nginx/conf.d/default.conf
    rm /tmp/nginx-default.conf

    # Update port in default.conf
    sed -i \
        -e "s/listen[[:space:]]\+[[:digit:]]\+;/listen ${NGINX_PORT};/" \
        -e "s/listen[[:space:]]\+\[::\]:[[:digit:]]\+/listen [::]:${NGINX_PORT}/" \
        /etc/nginx/conf.d/default.conf

    # Create writable directories for arbitrary UID (group ownership with write permissions)
    # Kubernetes fsGroup will ensure the process GID can access these
    # Fix /var/lib/nginx permissions (nginx package creates it as nginx:nginx 750)
    chmod 755 /var/lib/nginx
    chown root:root /var/lib/nginx

    # Pre-create nginx tmp subdirectories that nginx expects
    # Use 2775 (group-writable only) for security - no world-writable directories
    install -d -m 2775 -o root -g root \
        /var/lib/nginx/tmp \
        /var/lib/nginx/tmp/client_body \
        /var/lib/nginx/tmp/proxy \
        /var/lib/nginx/tmp/fastcgi \
        /var/lib/nginx/tmp/uwsgi \
        /var/lib/nginx/tmp/scgi \
        /var/lib/nginx/logs \
        /var/log/nginx \
        /run/nginx \
        /tmp/nginx
EOF

# Configure cron jobs for Wallos
RUN <<EOF
    set -euo pipefail
    echo "Setting up cron jobs"
    cp /var/www/html/cronjobs /etc/crontab
    dos2unix /etc/crontab
    # Readable by all users (arbitrary UIDs need to read this)
    chmod 0644 /etc/crontab
    # Writable log directory for arbitrary UID (group ownership with write permissions)
    install -d -m 2775 -o root -g root /var/log/cron
    rm -f /var/www/html/cronjobs
EOF

# Configure PHP-FPM and set application permissions for arbitrary UID/GID
RUN <<EOF
    set -euo pipefail
    echo "Configuring PHP-FPM"
    # pm.max_children = 15: Limit based on typical 512MB container memory
    # Each PHP-FPM worker uses ~32MB, 15 workers = ~480MB + overhead
    echo 'pm.max_children = 15' >> /usr/local/etc/php-fpm.d/zz-docker.conf
    echo 'pm.max_requests = 500' >> /usr/local/etc/php-fpm.d/zz-docker.conf

    echo "Setting permissions for arbitrary user IDs (Kubernetes compatibility)"
    # Permission Strategy for Kubernetes/Docker Compatibility:
    # - Application code: root:root with read-only permissions (security)
    # - Data directories: root:root with group-writable (2775) for fsGroup access
    # - Kubernetes fsGroup ensures the process GID can write to data directories
    # - Docker users should use --user $(id -u):0 or bind mount with GID 0

    # Application code: read-only, executable where needed
    chown -R root:root /var/www/html
    chmod -R go+rX /var/www/html
    chmod +x /var/www/html/startup.sh

    # Data directories: group-writable for application data persistence
    install -d -m 2775 -o root -g root \
        /var/www/html/db \
        /var/www/html/images/uploads/logos/avatars \
        /var/www/html/.tmp

    # Ensure PHP-FPM can write its PID file with arbitrary UID
    install -d -m 2775 -o root -g root /run/php-fpm
EOF

WORKDIR /var/www/html

EXPOSE ${NGINX_PORT}

# Health check to verify the application is responding
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -fsS http://localhost:${NGINX_PORT}/health.php || exit 1

# Run as nobody by default for security (UID 65534)
# Kubernetes securityContext runAsUser will override this with the specified UID
# This ensures the container doesn't run as root when used outside Kubernetes
USER nobody

ENV NGINX_PORT=${NGINX_PORT}

ENTRYPOINT [ "dumb-init", "--" ]
CMD ["./startup.sh"]