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
PREFIX = ${CURDIR}/build/${ARCH}
LIBDIR = ${PREFIX}/lib
BINDIR = ${PREFIX}/bin
INCLUDEDIR = ${PREFIX}/include

CXX = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
CC = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
CFLAGS = -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -arch ${ARCH} -I${INCLUDEDIR} -miphoneos-version-min=7.0 -O3 -fembed-bitcode
CXXFLAGS = -stdlib=libc++ -std=c++11 -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -arch ${ARCH} -I${INCLUDEDIR} -miphoneos-version-min=7.0 -O3 -fembed-bitcode
LDFLAGS = -stdlib=libc++ -isysroot ${IOS_SDK} -L${LIBDIR} -L${IOS_SDK}/usr/lib -arch ${ARCH} -miphoneos-version-min=7.0

arch: ${LIBDIR}/libspatialite.a

${LIBDIR}/libspatialite.a: ${LIBDIR}/libproj.a ${LIBDIR}/libgeos.a ${LIBDIR}/rttopo.a ${SRCDIR}/spatialite
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS} -Wno-error=implicit-function-declaration" \
	CXXFLAGS="${CXXFLAGS} -Wno-error=implicit-function-declaration" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" \
		./configure --host=${HOST} --enable-freexl=no --enable-rttopo=yes \
	  --enable-libxml2=no --prefix=${PREFIX} --with-geosconfig=${BINDIR}/geos-config --disable-shared && make clean install-strip

${LIBDIR}/rttopo.a: ${SRCDIR}/rttopo
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" \
	./configure --host=${HOST} --prefix=${PREFIX} \
	    --disable-shared --with-geosconfig=${BINDIR}/geos-config && make clean install


${LIBDIR}/libproj.a: ${SRCDIR}/proj
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" ./configure --host=${HOST} --prefix=${PREFIX} --disable-shared && make clean install

${LIBDIR}/libgeos.a: ${SRCDIR}/geos
	cd $^ && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" \
	CMAKE_OSX_SYSROOT=${IOS_SDK} \
	./configure --host=${HOST} --prefix=${PREFIX} --disable-shared && make clean install
	
# 	PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

${LIBDIR}/libsqlite3.a: ${SRCDIR}/sqlite3
	cd $^ && env LIBTOOL=${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	CXXFLAGS="${CXXFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	LDFLAGS="-Wl,-arch -Wl,${ARCH} -arch_only ${ARCH} ${LDFLAGS}" \
	./configure --host=${HOST} --prefix=${PREFIX} --disable-shared \
	   --enable-dynamic-extensions --enable-static && make clean install-includeHEADERS install-libLTLIBRARIES

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
#	./update-spatialite

${SRCDIR}/rttopo:
	git clone https://git.osgeo.org/gogs/rttopo/librttopo.git $@
	cd $@ && git checkout librttopo-1.1.0 && ./autogen.sh
	./change-deployment-target $@

${SRCDIR}/sqlite3:
	mkdir -p $@
	curl https://www.sqlite.org/2022/sqlite-autoconf-3380100.tar.gz | tar -xz -C $@ --strip-components=1
	./change-deployment-target $@

clean:
	rm -rf build sources
