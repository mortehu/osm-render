bin_PROGRAMS = osm osm-convert

AM_CPPFLAGS = -I$(srcdir)/ProtocolBuffers
AM_OBJCFLAGS = -Wall -g `pkg-config cairo --cflags` $(GNUSTEP_OBJCFLAGS)
AM_CFLAGS = -Wall -g

osm_SOURCES = \
  array.c array.h \
  main.m osm.h \
  osm-node-find.c \
  osm-node-sort.c \
  osm-parser.m \
  osm-tags.c \
  string-pool.c \
  MapWay.m \
  NSData+SWZlib.m \
  SWPath.m \
  SWCairo.m \
  Osm/fileformat.pb-c.c \
  Osm/osmformat.pb-c.c
osm_LDFLAGS = -lm -lz -lprotobuf-c `pkg-config cairo --libs` $(GNUSTEP_LIBS)

osm_convert_SOURCES = osm-convert.m SWXMLParser.m
osm_convert_LDFLAGS = -lexpat $(GNUSTEP_LIBS)
