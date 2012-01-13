bin_PROGRAMS = OsmRender

AM_CPPFLAGS = -I$(srcdir)/ProtocolBuffers
AM_OBJCFLAGS = -Wall -g $(PACKAGES_CFLAGS) $(GNUSTEP_OBJCFLAGS)
AM_CFLAGS = -Wall -g

OsmRender_SOURCES = \
  OsmRender.m \
  MapData.m MapData.h \
  MapWay.m \
  NSData+SWZlib.m \
  NSMutableArray+SWJSONStreamDelegate.m \
  NSMutableDictionary+SWJSONStreamDelegate.m \
  SWCairo.m \
  SWIndexSet.m \
  SWJSONStream.m \
  SWPath.m \
  SWPango.m \
  Osm/fileformat.pb-c.c \
  Osm/osmformat.pb-c.c
OsmRender_LDFLAGS = -lm -lz -lprotobuf-c $(PACKAGES_LIBS) $(GNUSTEP_LIBS)

REQUIRED_OSM_BUNDLES = map-data/great_britain.osm.pbf

map-data:
	mkdir map-data

map-data/%.osm.pbf: map-data
	wget http://download.geofabrik.de/osm/europe/great_britain.osm.pbf -O $@

images: $(REQUIRED_OSM_BUNDLES)
	for a in `cat cities.cfg`; do wget http://www.stay.com/api/1.0/areas/?cityID=160 -O"city-$$a.json" && cat options.cfg | xargs ./OsmRender --prefix="city-$$a" "city-$$a.json"; done
