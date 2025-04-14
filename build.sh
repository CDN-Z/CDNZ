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
CACHE_PURGE_VERSION="2.5.3"
VTS_VERSION="0.2.2"
VOD_MODULE_VERSION="1.33"
RTMP_MODULE_VERSION="1.2.2"

log "Starting Nginx $NGINX_VERSION compilation with VOD optimization"

# Install build dependencies
log "Installing build dependencies"
apt-get update
apt-get install -y build-essential cmake libxml2-dev libxslt1-dev libgd-dev \
    libgeoip-dev libmaxminddb-dev libperl-dev uuid-dev libssl-dev \
    perl libpcre3-dev autoconf libtool automake git wget curl software-properties-common

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

# Cache Purge module
log "Cloning ngx_cache_purge"
git clone --depth 1 -b "$CACHE_PURGE_VERSION" https://github.com/nginx-modules/ngx_cache_purge.git

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
  --add-module="../ngx_cache_purge" \
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

