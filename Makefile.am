bin_PROGRAMS = osm

AM_CFLAGS = -pthread -Wall -g -O1

osm_SOURCES =     \
  array.c array.h \
  main.c osm.h    \
  osm-node-find.c \
  osm-node-sort.c \
  osm-parser.c    \
  osm-tesselate.c

osm_LDFLAGS = -lexpat -lGL -lGLU -lGLEW -lX11 -lXi -lm -lpng
osm_LDADD = /usr/local/lib/libcelsius.a
