bin_PROGRAMS = OsmRender

AM_CPPFLAGS = -I$(srcdir)/ProtocolBuffers
AM_OBJCFLAGS = -Wall -g `pkg-config cairo --cflags` $(GNUSTEP_OBJCFLAGS)
AM_CFLAGS = -Wall -g

OsmRender_SOURCES = \
  OsmRender.m \
  MapData.m MapData.h \
  MapWay.m \
  NSData+SWZlib.m \
  SWPath.m \
  SWCairo.m \
  Osm/fileformat.pb-c.c \
  Osm/osmformat.pb-c.c
OsmRender_LDFLAGS = -lm -lz -lprotobuf-c `pkg-config cairo --libs` $(GNUSTEP_LIBS)
