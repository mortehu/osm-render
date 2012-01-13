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
