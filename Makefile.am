bin_PROGRAMS = osm osm-convert

AM_OBJCFLAGS = -Wall -g `pkg-config cairo --cflags` $(GNUSTEP_OBJCFLAGS)
AM_CFLAGS = -Wall -g

osm_SOURCES = \
  array.c array.h \
  main.m osm.h \
  osm-node-find.c \
  osm-node-sort.c \
  osm-parser.c \
  osm-tags.c \
  string-pool.c \
  SWPath.m \
  SWCairo.m \
  SWXMLParser.m
osm_LDFLAGS = -lexpat -lm `pkg-config cairo --libs` $(GNUSTEP_LIBS)

osm_convert_SOURCES = osm-convert.m SWXMLParser.m
osm_convert_LDFLAGS = -lexpat $(GNUSTEP_LIBS)
