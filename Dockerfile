FROM alpine:3.19@sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b

MAINTAINER Jérôme Foray <moi@foray-jero.me>

# renovate: datasource=github-tags depName=openresty/luajit2 packageName=openresty/luajit2 versioning=loose
ENV LUAJIT_VERSION=v2.1-20240314
# renovate: datasource=docker depName=library/nginx versioning=docker
ENV NGINX_VERSION=1.26.0
# renovate: datasource=github-tags depName=arut/nginx-rtmp-module versioning=semver-coerced
ENV RTMP_VERSION=v1.2.2
# renovate: datasource=github-tags depName=openresty/headers-more-nginx-module versioning=semver-coerced
ENV HEADERS_MORE_VERSION=v0.37
# renovate: datasource=github-tags depName=openresty/lua-nginx-module versioning=semver-coerced
ENV LUA_VERSION=master
# renovate: datasource=github-tags depName=simpl/ngx_devel_kit versioning=semver-coerced
ENV NDK_VERSION=v0.3.3

Env LUAJIT_LIB /usr/local/lib
Env LUAJIT_INC /usr/local/include/luajit-2.1
RUN apk --update add ffmpeg ca-certificates libatomic_ops-dev openssl-dev pcre-dev zlib-dev wget build-base && \
    update-ca-certificates && \
    mkdir -p /tmp/src /var/lib/nginx /var/log/nginx && \
    cd /tmp/src && \
    wget -O- https://github.com/openresty/luajit2/archive/refs/tags/${LUAJIT_VERSION}.tar.gz | tar xvzf - && \
    wget -O- https://github.com/arut/nginx-rtmp-module/archive/${RTMP_VERSION}.tar.gz | tar xvzf - && \
    wget -O- https://github.com/simpl/ngx_devel_kit/archive/${NDK_VERSION}.tar.gz | tar xvzf - && \
    wget -O- https://github.com/openresty/headers-more-nginx-module/archive/${HEADERS_MORE_VERSION}.tar.gz | tar xvzf - && \
    wget -O- https://github.com/openresty/lua-nginx-module/archive/${LUA_VERSION}.tar.gz | tar xvzf - && \
    wget -O- http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xvzf - && \
    cd /tmp/src/luajit2-${LUAJIT_VERSION#v} && \
    make && make install && \
    cd /tmp/src/nginx-${NGINX_VERSION} && \
    ./configure \
        --with-cc-opt="-Wno-maybe-uninitialized -Wno-pointer-sign" \
        --with-ld-opt="-Wl,-rpath,/usr/local/lib" \
        --prefix=/etc/nginx \
        --sbin-path=/usr/local/sbin/nginx \
        --pid-path=/run/nginx.pid \
        --lock-path=/run/nginx.lock \
        --with-ipv6 \
        --with-libatomic \
        --with-pcre \
        --with-pcre-jit \
        --http-client-body-temp-path=/var/lib/nginx/client_body_temp \
        --http-proxy-temp-path=/var/lib/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/lib/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/lib/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/lib/nginx/scgi_temp \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --with-select_module \
        --with-poll_module \
        --with-http_v2_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_sub_module \
        --with-http_secure_link_module \
        --with-http_auth_request_module \
        --add-module=/tmp/src/nginx-rtmp-module-${RTMP_VERSION#v} \
        --add-module=/tmp/src/ngx_devel_kit-${NDK_VERSION#v} \
        --add-module=/tmp/src/lua-nginx-module-${LUA_VERSION#v} \
        --add-module=/tmp/src/headers-more-nginx-module-${HEADERS_MORE_VERSION#v} && \
    make && \
    make install && \
    rm -rf /var/www/html && mv /etc/nginx/html /var/www && \
    mv /tmp/src/nginx-rtmp-module-${RTMP_VERSION#v}/stat.xsl /var/www/html && \
    apk del build-base && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/*

ADD ./nginx.conf /etc/nginx/conf/nginx.conf
ADD ./sites-enabled /etc/nginx/sites-enabled/
ADD ./streams-enabled /etc/nginx/streams-enabled/

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/etc/nginx/sites-enabled", "/etc/nginx/streams-enabled", "/etc/nginx/certs", "/etc/nginx/conf.d", "/var/log/nginx", "/var/www/html"]

WORKDIR /etc/nginx

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
