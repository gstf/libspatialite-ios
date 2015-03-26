libspatialite-ios
=================

A Makefile for automatically downloading and compiling [libspatialite](https://www.gaia-gis.it/fossil/libspatialite/index) (including its dependencies [SQLite](http://sqlite.org/index.html), [GEOS](http://trac.osgeo.org/geos/) and [PROJ.4](https://trac.osgeo.org/proj/)) statically for iOS.

The resulting library is a "fat" library suitable for multiple architectures. This includes:

- armv7 (iOS)
- armv7s (iOS)
- arm64 (iOS)
- i386 (iOS Simulator)

Requirements
------------

Xcode 6 with Command Line Tools installed.

Installation
------------

Simply run

	make
