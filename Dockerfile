FROM alpine:latest as build

ARG BUILD
ENV NGINX_VERSION=1.25.2

WORKDIR /src

# Install the required packages

RUN apk add --no-cache \
        ca-certificates \
        build-base \ 
        patch \
        cmake \ 
        git \
        libtool \
        autoconf \
        automake \
        libatomic_ops-dev \
        zlib-dev \
        pcre-dev \
        linux-headers \ 
        yajl-dev \
        libxml2-dev \ 
        libxslt-dev \
        perl-dev \
        curl-dev \
        lmdb-dev \
        geoip-dev \
        libmaxminddb-dev 
RUN git clone --recursive https://github.com/quictls/openssl --branch openssl-3.1.2+quic /src/openssl 

# ModSecurity

RUN (git clone --recursive https://github.com/SpiderLabs/ModSecurity /src/ModSecurity \
        && cd /src/ModSecurity \
        && /src/ModSecurity/build.sh \
        && /src/ModSecurity/configure \
        && make -j "$(nproc)" \
        && make -j "$(nproc)" install \
        && strip -s /usr/local/modsecurity/lib/libmodsecurity.so.3) 

# Modules

RUN (git clone --recursive https://github.com/google/ngx_brotli /src/ngx_brotli \
        && git clone --recursive https://github.com/openresty/headers-more-nginx-module /src/headers-more-nginx-module \
        && git clone --recursive https://github.com/nginx/njs /src/njs \
        && git clone --recursive https://github.com/SpiderLabs/ModSecurity-nginx /src/ModSecurity-nginx \
        && git clone --recursive https://github.com/leev/ngx_http_geoip2_module /src/ngx_http_geoip2_module) 
    
# Nginx

RUN (wget https://nginx.org/download/nginx-"$NGINX_VERSION".tar.gz -O - | tar xzC /src \
        && wget https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/master/nginx__dynamic_tls_records_1.25.1%2B.patch -O /src/nginx-"$NGINX_VERSION"/dynamic_tls_records.patch \
        && sed -i "s|nginx/|NGINX-QuicTLS/|g" /src/nginx-"$NGINX_VERSION"/src/core/nginx.h \
        && sed -i "s|Server: nginx|Server: NGINX-QuicTLS|g" /src/nginx-"$NGINX_VERSION"/src/http/ngx_http_header_filter_module.c \
        && sed -i "s|<hr><center>nginx</center>|<hr><center>NGINX-QuicTLS</center>|g" /src/nginx-"$NGINX_VERSION"/src/http/ngx_http_special_response.c \
        && cd /src/nginx-"$NGINX_VERSION" \
        && patch -p1 < dynamic_tls_records.patch) 
RUN cd /src/nginx-$NGINX_VERSION \
    && ./configure \
        --build=${BUILD} \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-threads \
        --with-file-aio \
        --with-libatomic \
        --with-pcre \
        --without-poll_module \
        --without-select_module \
        --with-openssl="/src/openssl" \
        --with-openssl-opt="no-ssl3 no-ssl3-method no-weak-ssl-ciphers" \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module=dynamic \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-http_ssl_module \
        --with-http_perl_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-http_realip_module \
        --with-http_gunzip_module \
        --with-http_addition_module \
        --with-http_gzip_static_module \
        --with-http_auth_request_module \
        --add-dynamic-module=/src/ngx_brotli \
        --add-dynamic-module=/src/headers-more-nginx-module \
        --add-dynamic-module=/src/njs/nginx \
        --add-dynamic-module=/src/ModSecurity-nginx \
        --add-dynamic-module=/src/ngx_http_geoip2_module \
    && make -j "$(nproc)" \
    && make -j "$(nproc)" install \
    && rm /src/nginx-$NGINX_VERSION/*.patch \
    && strip -s /usr/sbin/nginx \
    && strip -s /usr/lib/nginx/modules/*.so

FROM python:3.12.0-alpine3.18

COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx   /usr/sbin/nginx
COPY --from=build /usr/lib/nginx /usr/lib/nginx
COPY --from=build /usr/local/lib/perl5  /usr/local/lib/perl5
COPY --from=build /usr/lib/perl5/core_perl/perllocal.pod    /usr/lib/perl5/core_perl/perllocal.pod
COPY --from=build /usr/local/modsecurity/lib/libmodsecurity.so.3    /usr/local/modsecurity/lib/libmodsecurity.so.3

COPY assets/nginx.conf /etc/nginx/nginx.conf
COPY assets/default.conf /etc/nginx/conf.d/default.conf
COPY assets/index.html /etc/nginx/html/index.html

RUN addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    tini \
    zlib \
    pcre \
    libstdc++ \ 
    yajl \
    libxml2 \ 
    libxslt \
    perl \
    libcurl \
    geoip \
    libmaxminddb-libs 
RUN mkdir -p /var/log/nginx/ \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -s /usr/lib/nginx/modules /etc/nginx/modules

LABEL maintainer="Bence Kócsi <info@benedict.systems>" \
      nginx="nginx-quictls-$NGINX_VERSION"

EXPOSE 80 443 443/udp

ENTRYPOINT ["tini", "--", "nginx"]
CMD ["-g", "daemon off;"]