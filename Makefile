XCODE_DEVELOPER = $(shell xcode-select --print-path)
IOS_PLATFORM ?= iPhoneOS

# Pick latest SDK in the directory
IOS_PLATFORM_DEVELOPER = ${XCODE_DEVELOPER}/Platforms/${IOS_PLATFORM}.platform/Developer
IOS_SDK = ${IOS_PLATFORM_DEVELOPER}/SDKs/$(shell ls ${IOS_PLATFORM_DEVELOPER}/SDKs | sort -r | head -n1)

all: build/lib/libspatialite.a
build/lib/libspatialite.a: build_arches
	mkdir -p build/lib
	mkdir -p build/include

	# Copy includes
	cp -R build/arm64/include/geos build/include
	cp -R build/arm64/include/spatialite build/include
	cp -R build/arm64/include/*.h build/include

	# Make fat libraries for all architectures
	for file in build/arm64/lib/*.a; \
		do name=`basename $$file .a`; \
		lipo -create \
			-arch arm64 build/arm64/lib/$$name.a \
			-arch x86_64 build/x86_64/lib/$$name.a \
			-output build/lib/$$name.a \
		; \
		done;

# Build separate architectures
build_arches:
	${MAKE} arch ARCH=arm64 IOS_PLATFORM=iPhoneOS HOST=arm-apple-darwin
	${MAKE} arch ARCH=x86_64 IOS_PLATFORM=iPhoneSimulator HOST=x86_64-apple-darwin

SRCDIR = ${CURDIR}/sources
WORKDIR = ${CURDIR}/build/${ARCH}/sources
PREFIX = ${CURDIR}/build/${ARCH}
LIBDIR = ${PREFIX}/lib
BINDIR = ${PREFIX}/bin
INCLUDEDIR = ${PREFIX}/include

CXX = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
CC = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
CFLAGS = -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -arch ${ARCH} -I${INCLUDEDIR} -miphoneos-version-min=13.0 -O3 -fembed-bitcode
CXXFLAGS = -stdlib=libc++ -std=c++11 -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -arch ${ARCH} -I${INCLUDEDIR} -miphoneos-version-min=13.0 -O3 -fembed-bitcode
LDFLAGS = -stdlib=libc++ -isysroot ${IOS_SDK} -L${LIBDIR} -L${IOS_SDK}/usr/lib -arch ${ARCH} -miphoneos-version-min=13.0

arch: ${LIBDIR}/libspatialite.a

# Copy files to per-arch workdir so that we don't mess with source files unduly.
${WORKDIR}/%: ${SRCDIR}/%
	mkdir -p ${WORKDIR}
	cp -R $^ $@

# For now, we omit iconv because we can't figure out how to get it to build
${LIBDIR}/libspatialite.a: \
		${WORKDIR}/spatialite ${LIBDIR}/libproj.a ${LIBDIR}/libgeos.a \
		${LIBDIR}/librttopo.a ${LIBDIR}/libsqlite3.a \
		${LIBDIR}/libminizip.a ${LIBDIR}/libiconv.a
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS} -Wno-error=implicit-function-declaration" \
	CXXFLAGS="${CXXFLAGS} -Wno-error=implicit-function-declaration" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" \
		./configure --host=${HOST} --enable-freexl=no --enable-rttopo=yes \
	  --enable-libxml2=no --prefix=${PREFIX} --enable-static \
		--with-geosconfig=${BINDIR}/geos-config --disable-shared && make clean install-strip

${LIBDIR}/librttopo.a: ${WORKDIR}/rttopo ${LIBDIR}/libgeos.a ${LIBDIR}/libiconv.a
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" \
	./configure --host=${HOST} --prefix=${PREFIX} \
	    --disable-shared --enable-static \
			--with-geosconfig=${BINDIR}/geos-config && make clean install


${LIBDIR}/libproj.a: ${WORKDIR}/proj
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" ./configure --host=${HOST} --prefix=${PREFIX} --disable-shared && make clean install

# We fall back to CMake because we are having trouble setting the sysroot in the configure
# script. There isn't an apparent way to consume the `--disable-shared` flag in the configure
# script, so we are ignoring that for now.
${LIBDIR}/libgeos.a: ${WORKDIR}/geos
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" \
	cmake -DCMAKE_OSX_SYSROOT:PATH="${IOS_SDK}" -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" -DBUILD_SHARED_LIBS=OFF . && \
	make clean install

${LIBDIR}/libsqlite3.a: ${WORKDIR}/sqlite3
	cd $^ && env LIBTOOL=${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	CXXFLAGS="${CXXFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	LDFLAGS="-Wl,-arch -Wl,${ARCH} -arch_only ${ARCH} ${LDFLAGS}" \
	./configure --host=${HOST} --prefix=${PREFIX} --disable-shared \
	   --enable-dynamic-extensions --enable-static && make clean install-includeHEADERS install-libLTLIBRARIES

${LIBDIR}/libminizip.a: ${WORKDIR}/minizip
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" \
		./configure --host=${HOST} --enable-shared=no \
		--enable-static=yes --prefix=${PREFIX} && make clean install-strip

${LIBDIR}/libiconv.a: ${WORKDIR}/iconv
	cd $^ && env \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	LDFLAGS="${LDFLAGS}" \
		./configure --enable-shared=no \
		--enable-static=yes --prefix=${PREFIX} && make clean install

# SOURCE FILES

${SRCDIR}/proj:
	mkdir -p $@
	curl -L http://download.osgeo.org/proj/proj-4.9.3.tar.gz | tar -xz -C $@ --strip-components=1
	./change-deployment-target $@

${SRCDIR}/geos:
	mkdir -p $@
	curl http://download.osgeo.org/geos/geos-3.10.2.tar.bz2 | tar -xz -C $@ --strip-components=1
	./change-deployment-target $@

${SRCDIR}/spatialite:
	mkdir -p $@
	curl http://www.gaia-gis.it/gaia-sins/libspatialite-5.0.1.tar.gz | tar -xz -C $@ --strip-components=1
	./change-deployment-target $@

${SRCDIR}/rttopo:
	git clone https://git.osgeo.org/gogs/rttopo/librttopo.git $@
	cd $@ && git checkout librttopo-1.1.0 && ./autogen.sh
	./change-deployment-target $@

${SRCDIR}/sqlite3:
	mkdir -p $@
	curl https://www.sqlite.org/2022/sqlite-autoconf-3380100.tar.gz | tar -xz -C $@ --strip-components=1
	./change-deployment-target $@

${SRCDIR}/minizip:
	mkdir -p $@
	curl http://www.gaia-gis.it/gaia-sins/dataseltzer-sources/minizip-1.2.11.tar.gz | tar -xz -C $@ --strip-components=1

${SRCDIR}/iconv:
	mkdir -p $@
	curl http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz | tar -xz -C $@ --strip-components=1

clean:
	rm -rf build sources
