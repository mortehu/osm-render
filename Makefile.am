bin_PROGRAMS = osm

AM_CFLAGS = -pthread -Wall -g -O1 `pkg-config cairo --cflags`

osm_SOURCES =     \
  array.c array.h \
  main.c osm.h    \
  osm-node-find.c \
  osm-node-sort.c \
  osm-intersect.c \
  osm-parser.c    \
  osm-tags.c      \
  osm-tesselate.c \
  string-pool.c

osm_LDFLAGS = -lexpat -lm -lGLU `pkg-config cairo --libs`
