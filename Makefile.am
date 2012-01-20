bin_PROGRAMS = OsmRender

AM_CPPFLAGS = -I$(srcdir)/ProtocolBuffers
AM_OBJCFLAGS = -Wall -g $(PACKAGES_CFLAGS) $(GNUSTEP_OBJCFLAGS)
AM_CFLAGS = -Wall -g

OsmRender_SOURCES = \
  OsmRender.m \
  MapData.m MapData.h \
  MapWay.m
nodist_OsmRender_SOURCES = \
  Osm/fileformat.pb-c.c \
  Osm/osmformat.pb-c.c \
  Osm/osmformat.pb-c.h \
  Osm/fileformat.pb-c.h
OsmRender_LDFLAGS = -lm -lz -lprotobuf-c -lswanston $(PACKAGES_LIBS) $(GNUSTEP_LIBS)

BUILT_SOURCES = \
  Osm/fileformat.pb-c.c \
  Osm/osmformat.pb-c.c \
  Osm/osmformat.pb-c.h \
  Osm/fileformat.pb-c.h
CLEANFILES = \
  Osm/fileformat.pb-c.c \
  Osm/osmformat.pb-c.c \
  Osm/osmformat.pb-c.h \
  Osm/fileformat.pb-c.h

Osm/fileformat.pb-c.c Osm/fileformat.pb-c.h: fileformat.proto
	@mkdir -p Osm
	protoc-c $< --c_out=Osm/

Osm/osmformat.pb-c.c Osm/osmformat.pb-c.h: osmformat.proto
	@mkdir -p Osm
	protoc-c $< --c_out=Osm/

EXTRA_DIST = cities.cfg options.cfg

REQUIRED_OSM_BUNDLES = map-data/great_britain.osm.pbf

map-data/%.osm.pbf:
	@mkdir -p map-data
	wget http://download.geofabrik.de/osm/europe/great_britain.osm.pbf -O $@

images: $(REQUIRED_OSM_BUNDLES)
	for a in `cat cities.cfg`; do wget http://www.stay.com/api/1.0/areas/?cityID=$$a -O"city-$$a.json" && cat options.cfg | xargs ./OsmRender --prefix="city-$$a" "city-$$a.json"; done
