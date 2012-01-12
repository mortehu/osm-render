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
  SWPath.m \
  SWCairo.m \
  OSM/Fileformat.pb.m \
  OSM/Osmformat.pb.m \
  ProtocolBuffers/Field.m \
  ProtocolBuffers/CodedInputStream.m \
  ProtocolBuffers/ExtensionRegistry.m \
  ProtocolBuffers/AbstractMessage_Builder.m \
  ProtocolBuffers/ConcreteExtensionField.m \
  ProtocolBuffers/AbstractMessage.m \
  ProtocolBuffers/ExtendableMessage.m \
  ProtocolBuffers/ExtendableMessage_Builder.m \
  ProtocolBuffers/Utilities.m \
  ProtocolBuffers/MutableExtensionRegistry.m \
  ProtocolBuffers/WireFormat.m \
  ProtocolBuffers/TextFormat.m \
  ProtocolBuffers/CodedOutputStream.m \
  ProtocolBuffers/UnknownFieldSet_Builder.m \
  ProtocolBuffers/MutableField.m \
  ProtocolBuffers/GeneratedMessage_Builder.m \
  ProtocolBuffers/GeneratedMessage.m \
  ProtocolBuffers/UnknownFieldSet.m
osm_LDFLAGS = -lm `pkg-config cairo --libs` $(GNUSTEP_LIBS)

osm_convert_SOURCES = osm-convert.m SWXMLParser.m
osm_convert_LDFLAGS = -lexpat $(GNUSTEP_LIBS)
