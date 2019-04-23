FROM lambci/lambda:build-provided

# install system libraries
RUN \
    yum makecache fast; \
    yum install -y wget libpng-devel nasm; \
    yum install -y bash-completion --enablerepo=epel; \
    yum clean all; \
    yum autoremove

# versions of packages
ENV \
    CURL_VERSION=7.59.0 \
    GEOS_VERSION=3.7.1 \
    GEOTIFF_VERSION=1.4.3 \
	GDAL_VERSION=2.4.1 \
    HDF4_VERSION=4.2.14 \
	HDF5_VERSION=1.10.5 \
    NETCDF_VERSION=4.6.2 \
    NGHTTP2_VERSION=1.35.1 \
	OPENJPEG_VERSION=2.3.0 \
    LIBJPEG_TURBO_VERSION=2.0.1 \
    PKGCONFIG_VERSION=0.29.2 \
    PROJ_VERSION=5.2.0 \
    SZIP_VERSION=2.1.1 \
    WEBP_VERSION=1.0.1 \
    ZSTD_VERSION=1.3.8 \
    MAPSERVER_VERSION=7.2.2

# Paths to things
ENV \
	BUILD=/build \
    NPROC=4 \
	PREFIX=/usr/local \
	GDAL_CONFIG=/usr/local/bin/gdal-config \
	LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:/usr/local/lib/postgresql \
    GDAL_DATA=/usr/local/share/gdal

# switch to a build directory
WORKDIR /build

# pkg-config - version > 2.5 required for GDAL 2.3+
RUN \
    mkdir pkg-config; \
    wget -qO- https://pkg-config.freedesktop.org/releases/pkg-config-$PKGCONFIG_VERSION.tar.gz \
        | tar xvz -C pkg-config --strip-components=1; cd pkg-config; \
    ./configure --prefix=$PREFIX CFLAGS="-O2 -Os"; \
    make -j ${NPROC} install; \
    cd ../; rm -rf pkg-config

# proj
RUN \
    mkdir proj; \
    wget -qO- http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz | tar xvz -C proj --strip-components=1; cd proj; \
    ./configure --prefix=$PREFIX; \
    make -j ${NPROC} install; \
    cd ..; rm -rf proj

# nghttp2
RUN \
    mkdir nghttp2; \
    wget -qO- https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.gz \
        | tar xvz -C nghttp2 --strip-components=1; cd nghttp2; \
    ./configure --enable-lib-only --prefix=${PREFIX}; \
    make -j ${NPROC} install; \
    cd ..; rm -rf nghttp2

# curl
RUN \
    mkdir curl; \
    wget -qO- https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz \
        | tar xvz -C curl --strip-components=1; cd curl; \
    ./configure --prefix=${PREFIX} --disable-manual --disable-cookies --with-nghttp2=${PREFIX}; \
    make -j ${NPROC} install; \
    cd ..; rm -rf curl

# GEOS
RUN \
    mkdir geos; \
	wget -qO- http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 \
        | tar xvj -C geos --strip-components=1; cd geos; \
	./configure --enable-python --prefix=$PREFIX CFLAGS="-O2 -Os"; \
	make -j ${NPROC} install; \
	cd ..; rm -rf geos

# WEBP
RUN \
    mkdir webp; \
    wget -qO- https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz \
        | tar xvz -C webp --strip-components=1; cd webp; \
    CFLAGS="-O2 -Wl,-S" PKG_CONFIG_PATH="/usr/lib64/pkgconfig" ./configure --prefix=$PREFIX; \
    make -j ${NPROC} install; \
    cd ..; rm -rf webp

# ZSTD
RUN \
    mkdir zstd; \
    wget -qO- https://github.com/facebook/zstd/archive/v${ZSTD_VERSION}.tar.gz \
        | tar -xvz -C zstd --strip-components=1; cd zstd; \
    make -j ${NPROC} install PREFIX=$PREFIX ZSTD_LEGACY_SUPPORT=0 CFLAGS=-O1 --silent; \
    cd ..; rm -rf zstd

# openjpeg
RUN \
    mkdir openjpeg; \
    wget -qO- https://github.com/uclouvain/openjpeg/archive/v$OPENJPEG_VERSION.tar.gz \
        | tar xvz -C openjpeg --strip-components=1; cd openjpeg; mkdir build; cd build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX; \
    make -j ${NPROC} install; \
    cd ../..; rm -rf openjpeg

# jpeg_turbo
RUN \
    mkdir jpeg; \
    wget -qO- https://github.com/libjpeg-turbo/libjpeg-turbo/archive/${LIBJPEG_TURBO_VERSION}.tar.gz \
        | tar xvz -C jpeg --strip-components=1; cd jpeg; \
    cmake -G"Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$PREFIX .; \
    make -j $(nproc) install; \
    cd ..; rm -rf jpeg

# geotiff
RUN \
    mkdir geotiff; \
    wget -qO- https://download.osgeo.org/geotiff/libgeotiff/libgeotiff-$GEOTIFF_VERSION.tar.gz \
        | tar xvz -C geotiff --strip-components=1; cd geotiff; \
    ./configure --prefix=${PREFIX} \
        --with-proj=${PREFIX} --with-jpeg=${PREFIX} --with-zip=yes;\
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf geotiff

# GDAL
RUN \
    mkdir gdal; \
    wget -qO- http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz \
        | tar xvz -C gdal --strip-components=1; cd gdal; \
    ./configure \
        --disable-debug \
        --disable-static \
        --prefix=${PREFIX} \
        --with-openjpeg \
        --with-geotiff=${PREFIX} \
        --with-webp=${PREFIX} \
        --with-zstd=${PREFIX} \
        --with-jpeg=${PREFIX} \
        --with-threads=yes \
		--with-curl=${PREFIX}/bin/curl-config \
        --without-python \
        --without-libtool \
        --with-geos=$PREFIX/bin/geos-config \
		--with-hide-internal-symbols=yes \
        CFLAGS="-O2 -Os" CXXFLAGS="-O2 -Os" \
        LDFLAGS="-Wl,-rpath,'\$\$ORIGIN'"; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf gdal

# Protobufc
Run \
    mkdir protobuf; \
    wget -qO- https://github.com/google/protobuf/archive/v3.0.2.tar.gz \
    | tar xvz -C protobuf --strip-components=1; \
    cd protobuf; \
    ./autogen.sh; \
    ./configure;  \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf protobuf

# Protobufc
Run \
    mkdir protobufc; \
    wget -qO- https://github.com/protobuf-c/protobuf-c/releases/download/v1.2.1/protobuf-c-1.2.1.tar.gz \
    | tar xvz -C protobufc --strip-components=1; \
    cd protobufc; \
    ./configure;  \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf protobufc

# #postgresql
RUN \
    mkdir postgresql; \
    wget -qO- https://ftp.postgresql.org/pub/source/v11.2/postgresql-11.2.tar.gz \
        | tar xvz -C postgresql --strip-components=1; \
    cd postgresql;   \
    ./configure  --with-openssl --prefix=$PREFIX; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf postgresql

#postgis
RUN \
    mkdir postgis; \
    wget -qO- https://download.osgeo.org/postgis/source/postgis-2.5.2.tar.gz \
        | tar xvz -C postgis --strip-components=1; \
    cd postgis; \
    ./configure --prefix=$PREFIX; \
    make -j ${NPROC} install; \
    cd ${BUILD}; rm -rf postgis

# # mapserver
RUN \
    mkdir mapserver; \
    wget -qO- http://download.osgeo.org/mapserver/mapserver-${MAPSERVER_VERSION}.tar.gz \
        | tar xvz -C mapserver --strip-components=1; cd mapserver; mkdir build; cd build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$PREFIX \
            -DLINK_STATIC_MAPSERVER=1 \
            -DBUILD_STATIC=1 \
            -DWITH_PROTOBUFC=1 \
            -DWITH_FRIBIDI=0 \
            -DWITH_HARFBUZZ=0 \
            -DWITH_FCGI=0 \
            -DWITH_POSTGIS=1 \
            -DWITH_GIF=0 \
            -DWITH_CURL=1 \
            -DWITH_PYTHON=0 \
            -DWITH_GDAL=1; \
    make -j ${NPROC} install; \
    cd ../..; rm -rf mapserver



# 
# Copy shell scripts and config files over
COPY bin/* /usr/local/bin/

WORKDIR /home/mapserverless
