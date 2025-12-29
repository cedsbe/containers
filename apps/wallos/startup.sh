#!/bin/sh
#
# Wallos Container Startup Script
# Initializes the application and starts all required services
#
# This script runs as PID 1 under dumb-init (see Dockerfile ENTRYPOINT).
# dumb-init handles zombie reaping and forwards signals to this script.
# This script implements graceful shutdown orchestration for all services.
# The script is designed to work with arbitrary UID/GID assigned by Kubernetes.
#
# Note: This script uses POSIX sh (BusyBox ash on Alpine). Avoid bashisms.
#

set -eu

# Validate required environment variables
: "${NGINX_PORT:?NGINX_PORT environment variable is required}"

# Validate required files and executables exist
validate_environment() {
    [ -f /etc/crontab ] || { echo "ERROR: Missing crontab configuration" >&2; exit 1; }
    [ -d /var/www/html/endpoints ] || { echo "ERROR: Missing application files" >&2; exit 1; }

    # Verify required executables are available
    command -v php >/dev/null 2>&1 || { echo "ERROR: php executable not found" >&2; exit 1; }
    command -v php-fpm >/dev/null 2>&1 || { echo "ERROR: php-fpm executable not found" >&2; exit 1; }
    command -v nginx >/dev/null 2>&1 || { echo "ERROR: nginx executable not found" >&2; exit 1; }
    command -v supercronic >/dev/null 2>&1 || { echo "ERROR: supercronic executable not found" >&2; exit 1; }
}

# Initialize application database and run migrations
initialize_app() {
    echo "Initializing Wallos application..." >&2

    # Create database if it does not exist
    echo "Creating database..." >&2
    /usr/local/bin/php /var/www/html/endpoints/cronjobs/createdatabase.php || {
        echo "ERROR: Failed to create database" >&2
        return 1
    }

    # Perform any database migrations
    echo "Running database migrations..." >&2
    /usr/local/bin/php /var/www/html/endpoints/db/migrate.php || {
        echo "ERROR: Failed to run migrations" >&2
        return 1
    }

    echo "Application initialization complete" >&2
}

# Run initial cron jobs (optional startup tasks)
# These tasks are non-critical - they will be retried by supercronic on schedule
# Failures here should not prevent container startup
run_startup_tasks() {
    echo "Running startup tasks..." >&2

    # Update next payment dates (non-critical: runs daily via cron)
    if ! /usr/local/bin/php /var/www/html/endpoints/cronjobs/updatenextpayment.php 2>&1; then
        echo "WARNING: Failed to update payment dates (will retry via cron)" >&2
    fi

    # Update exchange rates (non-critical: runs daily via cron, requires network)
    if ! /usr/local/bin/php /var/www/html/endpoints/cronjobs/updateexchange.php 2>&1; then
        echo "WARNING: Failed to update exchange rates (will retry via cron)" >&2
    fi

    # Check for updates (non-critical: runs daily via cron, requires network)
    if ! /usr/local/bin/php /var/www/html/endpoints/cronjobs/checkforupdates.php 2>&1; then
        echo "WARNING: Failed to check for updates (will retry via cron)" >&2
    fi

    echo "Startup tasks complete" >&2
}

# Prepare runtime writable dirs for readonly rootfs environments
prepare_runtime_dirs() {
    echo "Preparing runtime writable directories for readonly rootfs..." >&2

    # Create required directories under writable mounts (mounted by Kubernetes)
    mkdir -p /var/ephemeral/run/nginx \
             /var/ephemeral/run/php-fpm \
             /var/ephemeral/tmp/client_body \
             /var/ephemeral/tmp/proxy \
             /var/ephemeral/tmp/fastcgi \
             /var/ephemeral/tmp/uwsgi \
             /var/ephemeral/tmp/scgi \
             /var/log/nginx \
             /var/log/cron \
             /tmp/nginx

    # Ensure log files exist (touch will succeed on writable mounts)
    touch /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log >/dev/null 2>&1 || true

    # Make directories group-writable where possible (attempt only; not fatal if it fails)
    chmod -R g+rwX /var/ephemeral /var/log /tmp >/dev/null 2>&1 || true

    # Try to set setgid and sane perms for new directories if permitted
    find /var/ephemeral /var/log -type d -exec chmod 2775 {} + >/dev/null 2>&1 || true

    echo "Runtime directories prepared" >&2
}

# PIDs we'll track
PHP_FPM_PID=
NGINX_PID=
SUPERCRONIC_PID=
shutdown_in_progress=0

shutdown_once() {
    [ "$shutdown_in_progress" -eq 1 ] && return 0
    shutdown_in_progress=1

    echo "Received shutdown signal - shutting down gracefully..." >&2

    # Send graceful shutdown signals to all services
    # Nginx wants QUIT for graceful shutdown
    nginx -s quit 2>/dev/null || true

    # PHP-FPM graceful quit
    kill -QUIT "${PHP_FPM_PID}" 2>/dev/null || true

    # Supercronic terminates with TERM
    kill -TERM "${SUPERCRONIC_PID}" 2>/dev/null || true

    # Wait for processes to finish (with timeout)
    timeout=10
    count=0
    while [ $count -lt $timeout ]; do
        if ! kill -0 ${PHP_FPM_PID} 2>/dev/null && \
           ! kill -0 ${NGINX_PID} 2>/dev/null && \
           ! kill -0 ${SUPERCRONIC_PID} 2>/dev/null; then
            echo "All services stopped gracefully" >&2
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done

    echo "WARNING: Some services did not stop within timeout" >&2
}

# Handle all common stop signals (SIGHUP ignored - not used for config reload in this setup)
trap 'shutdown_once' SIGTERM SIGINT SIGQUIT
trap '' SIGHUP

# ============================================================================
# Main execution
# ============================================================================

echo "Wallos container starting..." >&2

# Step 1: Validate environment
validate_environment

# Step 2: Initialize application (database, migrations)
initialize_app

# Step 3: Run optional startup tasks in background (non-blocking)
# These are non-critical and will be retried by supercronic anyway
run_startup_tasks &

# Prepare runtime writable directories (for readonly rootfs)
prepare_runtime_dirs

# Step 4: Start services
echo "Starting services..." >&2

echo "Starting PHP-FPM..." >&2
php-fpm -F &
PHP_FPM_PID=$!

echo "Starting Supercronic (cron)..." >&2
supercronic /etc/crontab &
SUPERCRONIC_PID=$!

echo "Starting Nginx on port ${NGINX_PORT}..." >&2
nginx -g 'daemon off;' &
NGINX_PID=$!

# Step 5: Verify services started successfully
echo "Verifying service health..." >&2

# Brief pause to let services initialize before checking
sleep 2

# Check if all processes are still running
if ! kill -0 ${PHP_FPM_PID} 2>/dev/null; then
    echo "ERROR: PHP-FPM failed to start" >&2
    exit 1
fi

if ! kill -0 ${NGINX_PID} 2>/dev/null; then
    echo "ERROR: Nginx failed to start" >&2
    exit 1
fi

if ! kill -0 ${SUPERCRONIC_PID} 2>/dev/null; then
    echo "ERROR: Supercronic failed to start" >&2
    exit 1
fi

# Functional health check: verify nginx responds with HTTP 200
max_attempts=10
attempt=0
while [ $attempt -lt $max_attempts ]; do
    http_code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${NGINX_PORT}/health.php" 2>/dev/null) || true
    if [ "$http_code" = "200" ]; then
        echo "All services started successfully" >&2
        echo "Wallos is ready to accept connections on port ${NGINX_PORT}" >&2
        break
    fi
    attempt=$((attempt + 1))
    if [ $attempt -lt $max_attempts ]; then
        sleep 1
    else
        echo "WARNING: Nginx health check failed (HTTP ${http_code}), but process is running" >&2
    fi
done

# Wait for any child process to exit, then trigger shutdown.
# `wait -n` blocks until ONE child exits (BusyBox ash extension).
# This allows immediate detection of service failures rather than
# waiting for all processes, enabling faster restarts.
wait -n
exit_code=$?
echo "A service process exited with code ${exit_code}, initiating shutdown..." >&2
shutdown_once
exit ${exit_code}
