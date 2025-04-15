#!/bin/bash
# Nginx 1.27.1 Compile Script for CDN VOD
# This script compiles Nginx with VOD-optimized modules for CDN usage
# Run with root privileges

# Exit on error
set -e

# Log function
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a nginx-build.log
}

# Configuration variables
NGINX_VERSION="1.27.1"
INSTALL_DIR="/opt/nginx"
NGINX_USER="nginx"
BUILD_DIR="/tmp/nginx-build-$$"

# Required modules & versions
OPENSSL_VERSION="3.1.5"
ZLIB_VERSION="1.3.1"
PCRE_VERSION="10.43"
HEADERS_MORE_VERSION="0.37"
VTS_VERSION="0.2.2"
VOD_MODULE_VERSION="1.33"
RTMP_MODULE_VERSION="1.2.2"

log "Starting Nginx $NGINX_VERSION compilation with VOD optimization"

# Check if running on Fedora
if [ ! -f /etc/fedora-release ]; then
  log "Warning: This script is optimized for Fedora Server 41"
fi

# Create nginx user if it doesn't exist
if ! id -u $NGINX_USER >/dev/null 2>&1; then
  log "Creating $NGINX_USER user"
  useradd -r -s /sbin/nologin $NGINX_USER
fi

# Install build dependencies for Fedora
log "Installing build dependencies"
dnf update -y
dnf install -y gcc gcc-c++ make cmake libxml2-devel libxslt-devel gd-devel \
    GeoIP-devel libmaxminddb-devel perl-devel libuuid-devel openssl-devel \
    perl pcre-devel pcre2-devel autoconf libtool automake git wget curl \
    diffutils patch which bison flex file findutils

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download and extract Nginx
log "Downloading Nginx $NGINX_VERSION"
wget -q "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"
tar -xzf "nginx-$NGINX_VERSION.tar.gz"

# Download and extract dependencies
log "Downloading dependencies"

# OpenSSL
wget -q "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
tar -xzf "openssl-$OPENSSL_VERSION.tar.gz"

# PCRE
wget -q "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE_VERSION/pcre2-$PCRE_VERSION.tar.gz"
tar -xzf "pcre2-$PCRE_VERSION.tar.gz"

# zlib
wget -q "https://www.zlib.net/zlib-$ZLIB_VERSION.tar.gz"
tar -xzf "zlib-$ZLIB_VERSION.tar.gz"

# Headers More module
log "Cloning headers-more-nginx-module"
git clone --depth 1 -b "v$HEADERS_MORE_VERSION" https://github.com/openresty/headers-more-nginx-module.git

# VTS module
log "Cloning nginx-module-vts"
git clone --depth 1 -b "v$VTS_VERSION" https://github.com/vozlt/nginx-module-vts.git

# VOD module
log "Cloning nginx-vod-module"
git clone --depth 1 -b "$VOD_MODULE_VERSION" https://github.com/kaltura/nginx-vod-module.git

# RTMP module
log "Cloning nginx-rtmp-module"
git clone --depth 1 -b "v$RTMP_MODULE_VERSION" https://github.com/arut/nginx-rtmp-module.git

# Navigate to Nginx directory
cd "nginx-$NGINX_VERSION"

# Configure Nginx with modules and optimizations
log "Configuring Nginx with VOD optimizations"

./configure \
  --prefix="$INSTALL_DIR" \
  --user="$NGINX_USER" \
  --group="$NGINX_USER" \
  --with-pcre="../pcre2-$PCRE_VERSION" \
  --with-pcre-jit \
  --with-zlib="../zlib-$ZLIB_VERSION" \
  --with-openssl="../openssl-$OPENSSL_VERSION" \
  --with-openssl-opt="enable-tls1_3" \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-http_realip_module \
  --with-http_addition_module \
  --with-http_sub_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_random_index_module \
  --with-http_secure_link_module \
  --with-http_slice_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-file-aio \
  --with-threads \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-http_geoip_module \
  --with-http_image_filter_module \
  --with-http_xslt_module \
  --add-module="../headers-more-nginx-module" \
  --add-module="../nginx-module-vts" \
  --add-module="../nginx-vod-module" \
  --add-module="../nginx-rtmp-module" \
  --with-cc-opt="-O3 -fomit-frame-pointer -march=native" \
  --with-ld-opt="-Wl,-rpath,$INSTALL_DIR/lib"

# Compile and install Nginx
log "Compiling Nginx (this might take a while)"
make -j$(nproc)

log "Installing Nginx to $INSTALL_DIR"
make install

# Set up SELinux context if SELinux is enabled
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
  log "Setting up SELinux contexts"
  dnf install -y policycoreutils-python-utils
  semanage port -a -t http_port_t -p tcp 1935
  semanage fcontext -a -t httpd_sys_content_t "$INSTALL_DIR(/.*)?"
  restorecon -Rv $INSTALL_DIR
fi

# Create systemd service
log "Creating systemd service"
cat > /etc/systemd/system/nginx.service << EOF
[Unit]
Description=Nginx Optimized for CDN VOD
After=network.target

[Service]
Type=forking
PIDFile=/opt/nginx/logs/nginx.pid
ExecStartPre=/opt/nginx/sbin/nginx -t -c /opt/nginx/conf/nginx.conf
ExecStart=/opt/nginx/sbin/nginx -c /opt/nginx/conf/nginx.conf
ExecReload=/opt/nginx/sbin/nginx -s reload
ExecStop=/opt/nginx/sbin/nginx -s stop
PrivateTmp=true
LimitNOFILE=1000000
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF

# Enable and start nginx service
log "Enabling and starting nginx service"
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

# Configure firewall if it's running
if systemctl is-active --quiet firewalld; then
  log "Configuring firewall"
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --permanent --add-port=1935/tcp
  firewall-cmd --reload
fi

log "Nginx installation completed successfully"