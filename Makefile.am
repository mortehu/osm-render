bin_PROGRAMS = osm

AM_OBJCFLAGS = -Wall -g -O1 `pkg-config cairo --cflags` $(GNUSTEP_OBJCFLAGS)

osm_SOURCES = \
  array.c array.h \
  main.m osm.h \
  osm-node-find.c \
  osm-node-sort.c \
  osm-parser.c \
  osm-tags.c \
  string-pool.c \
  SWPath.m \
  SWCairo.m

osm_LDFLAGS = -lexpat -lm -lGLU `pkg-config cairo --libs` $(GNUSTEP_LIBS)
