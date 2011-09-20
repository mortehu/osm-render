#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <err.h>

#include <expat.h>

#include "osm.h"

#define OSM_MAX_NODES     1000000
#define OSM_MAX_NODE_REFS 1000000
#define OSM_MAX_WAYS       100000
#define OSM_MAX_STRINGS    100000

struct osm_node nodes[OSM_MAX_NODES];
size_t node_count;
size_t nodes_sorted;

uint32_t node_refs[OSM_MAX_NODE_REFS];
size_t node_ref_count;

struct osm_way ways[OSM_MAX_WAYS];
size_t way_count;

char strings[OSM_MAX_STRINGS];
size_t strings_length;

int32_t min_lat, min_lon;
int32_t max_lat, max_lon;

static struct osm_node *last_node;
static struct osm_way *last_way;

static void
osm_xml_error (enum XML_Error error)
{
  const char *message;

  message = XML_ErrorString (error);

  errx (EXIT_FAILURE, "XML error: %s", message);
}

static void
osm_sort_nodes ()
{
  if (nodes_sorted == node_count)
    return;

  osm_node_sort (nodes, node_count);

  nodes_sorted = node_count;
}

static void XMLCALL
osm_start_element (void *user_data, const XML_Char *name,
                    const XML_Char **atts)
{
  const XML_Char **attr;

  if (!strcmp (name, "node"))
    {
      struct osm_node new_node;

      memset (&new_node, 0, sizeof (new_node));

      for (attr = atts; *attr; attr += 2)
        {
          if (!strcmp (attr[0], "id"))
            new_node.id = strtoll (attr[1], 0, 10);
          else if (!strcmp (attr[0], "lat"))
            {
              double lat;

              lat = strtod (attr[1], 0);

              assert (lat >= -90.0);
              assert (lat <= 90.0);

              new_node.lat = lat / 90.0 * 0x7fffffff;
            }
          else if (!strcmp (attr[0], "lon"))
            {
              double lon;

              lon = strtod (attr[1], 0);

              assert (lon >= -180.0);
              assert (lon <= 180.0);

              new_node.lon = lon / 180.0 * 0x7fffffff;
            }
        }

      if (node_count == OSM_MAX_NODES)
        errx (EXIT_FAILURE, "Too many nodes");

      if (!node_count)
        {
          min_lat = max_lat = new_node.lat;
          min_lon = max_lon = new_node.lon;
        }
      else
        {
          if (new_node.lat < min_lat)
            min_lat = new_node.lat;
          else if (new_node.lat > max_lat)
            max_lat = new_node.lat;

          if (new_node.lon < min_lon)
            min_lon = new_node.lon;
          else if (new_node.lon > max_lon)
            max_lon = new_node.lon;
        }

      last_node = &nodes[node_count++];
      *last_node = new_node;
    }
  else if (!strcmp (name, "way"))
    {
      struct osm_way new_way;

      if (way_count == OSM_MAX_WAYS)
        errx (EXIT_FAILURE, "Too many ways");

      osm_sort_nodes ();

      memset (&new_way, 0, sizeof (new_way));
      new_way.first_node = node_ref_count;

      last_way = &ways[way_count++];
      *last_way = new_way;
    }
  else if (!strcmp (name, "nd"))
    {
      uint64_t ref = 0;
      int idx;

      assert (last_way);

      for (attr = atts; *attr; attr += 2)
        {
          if (!strcmp (attr[0], "ref"))
            ref = strtoll (attr[1], 0, 10);
        }

      if (ref)
        {
          idx = osm_node_find (ref, nodes, node_count);

          if (idx == -1)
            errx (EXIT_FAILURE, "Could not find node '%llu'", (unsigned long long) ref);

          node_refs[node_ref_count++] = idx;
          ++last_way->node_count;
        }
    }
  else if (!strcmp (name, "tag"))
    {
      const char *k = 0, *v = 0;

      for (attr = atts; *attr; attr += 2)
        {
          if (!strcmp (attr[0], "k"))
            k = attr[1];
          else if (!strcmp (attr[0], "v"))
            v = attr[1];
        }

      assert (k && v);

      if (last_node)
        {
        }
      else if (last_way)
        {
          osm_tag_add (last_way - ways, k, v);

          if (!strcmp (k, "landuse"))
            {
              if (!strcmp (v, "residential")
                  || !strcmp (v, "retail"))
                last_way->flags |= OSM_WAY_RESIDENTIAL;
              else if (!strcmp (v, "cemetery"))
                last_way->flags |= OSM_WAY_CEMETERY;
            }
          else if (!strcmp (k, "footway"))
            {
              if (!strcmp (v, "crossing"))
                last_way->flags |= OSM_WAY_CROSSING;
              else if (!strcmp (v, "sidewalk"))
                last_way->flags |= OSM_WAY_SIDEWALK;
            }
          else if (!strcmp (k, "leisure"))
            {
              if (!strcmp (v, "park"))
                last_way->flags |= OSM_WAY_PARK;
              else if (!strcmp (v, "pitch"))
                last_way->flags |= OSM_WAY_PARK;
              else if (!strcmp (v, "playground"))
                last_way->flags |= OSM_WAY_PARK;
              else if (!strcmp (v, "miniature_golf"))
                last_way->flags |= OSM_WAY_PARK;
              else if (!strcmp (v, "music_venue"))
                ;
              else if (!strcmp (v, "slipway"))
                ;
              else if (!strcmp (v, "sports_centre"))
                ;
              else if (!strcmp (v, "swimming_pool"))
                ;
            }
          else if (!strcmp (k, "highway"))
            {
              if (!strcmp (v, "bus_stop"))
                last_way->highway = OSM_HIGHWAY_BUS_STOP;
              else if (!strcmp (v, "construction"))
                last_way->highway = OSM_HIGHWAY_CONSTRUCTION;
              else if (!strcmp (v, "crossing"))
                last_way->highway = OSM_HIGHWAY_CROSSING;
              else if (!strcmp (v, "cycleway"))
                last_way->highway = OSM_HIGHWAY_CYCLEWAY;
              else if (!strcmp (v, "footway"))
                last_way->highway = OSM_HIGHWAY_FOOTWAY;
              else if (!strcmp (v, "living_street"))
                last_way->highway = OSM_HIGHWAY_LIVING_STREET;
              else if (!strcmp (v, "mini_roundabout"))
                last_way->highway = OSM_HIGHWAY_MINI_ROUNDABOUT;
              else if (!strcmp (v, "motorway"))
                last_way->highway = OSM_HIGHWAY_MOTORWAY;
              else if (!strcmp (v, "motorway_junction"))
                last_way->highway = OSM_HIGHWAY_MOTORWAY_JUNCTION;
              else if (!strcmp (v, "motorway_link"))
                last_way->highway = OSM_HIGHWAY_MOTORWAY_LINK;
              else if (!strcmp (v, "path"))
                last_way->highway = OSM_HIGHWAY_PATH;
              else if (!strcmp (v, "pedestrian"))
                last_way->highway = OSM_HIGHWAY_PEDESTRIAN;
              else if (!strcmp (v, "primary"))
                last_way->highway = OSM_HIGHWAY_PRIMARY;
              else if (!strcmp (v, "primary_link"))
                last_way->highway = OSM_HIGHWAY_PRIMARY_LINK;
              else if (!strcmp (v, "residential"))
                last_way->highway = OSM_HIGHWAY_RESIDENTIAL;
              else if (!strcmp (v, "road"))
                last_way->highway = OSM_HIGHWAY_ROAD;
              else if (!strcmp (v, "secondary"))
                last_way->highway = OSM_HIGHWAY_SECONDARY;
              else if (!strcmp (v, "secondary_link"))
                last_way->highway = OSM_HIGHWAY_SECONDARY_LINK;
              else if (!strcmp (v, "service"))
                last_way->highway = OSM_HIGHWAY_SERVICE;
              else if (!strcmp (v, "steps"))
                last_way->highway = OSM_HIGHWAY_STEPS;
              else if (!strcmp (v, "tertiary"))
                last_way->highway = OSM_HIGHWAY_TERTIARY;
              else if (!strcmp (v, "track"))
                last_way->highway = OSM_HIGHWAY_TRACK;
              else if (!strcmp (v, "traffic_signals"))
                last_way->highway = OSM_HIGHWAY_TRAFFIC_SIGNALS;
              else if (!strcmp (v, "trunk"))
                last_way->highway = OSM_HIGHWAY_TRUNK;
              else if (!strcmp (v, "trunk_link"))
                last_way->highway = OSM_HIGHWAY_TRUNK_LINK;
              else if (!strcmp (v, "turning_circle"))
                last_way->highway = OSM_HIGHWAY_TURNING_CIRCLE;
              else if (!strcmp (v, "unclassified"))
                last_way->highway = OSM_HIGHWAY_UNCLASSIFIED;
              else
                errx (EXIT_FAILURE, "Unknown 'highway' type '%s'", v);
            }
          else if (!strcmp (k, "natural"))
            {
              if (!strcmp (v, "bay"))
                last_way->natural = OSM_NATURAL_BAY;
              else if (!strcmp (v, "cliff"))
                last_way->natural = OSM_NATURAL_CLIFF;
              else if (!strcmp (v, "coastline"))
                last_way->natural = OSM_NATURAL_COASTLINE;
              else if (!strcmp (v, "land"))
                last_way->natural = OSM_NATURAL_LAND;
              else if (!strcmp (v, "scrub"))
                last_way->natural = OSM_NATURAL_SCRUB;
              else if (!strcmp (v, "tree"))
                last_way->natural = OSM_NATURAL_TREE;
              else if (!strcmp (v, "water"))
                last_way->natural = OSM_NATURAL_WATER;
              else if (!strcmp (v, "wood"))
                last_way->natural = OSM_NATURAL_WOOD;
              else
                fprintf (stderr, "Unknown 'natural' type '%s'\n", v);
            }
          else if (!strcmp (k, "building"))
            {
              /*if (!strcmp (v, "yes"))*/
                last_way->flags |= OSM_WAY_BUILDING;
            }
          else if (!strcmp (k, "name"))
            {
              size_t len;

              last_way->name = strings_length;

              len = strlen (v) + 1;

              memcpy (strings + strings_length, v, len);
              strings_length += len;
            }
        }
    }
}

static void XMLCALL
osm_end_element (void *user_data, const XML_Char *name)
{
  if (!strcmp (name, "node"))
    last_node = 0;
  else if (!strcmp (name, "way"))
    last_way = 0;
}

static void XMLCALL
osm_character_data (void *user_data, const XML_Char *str, int len)
{
}

static void XMLCALL
osm_start_namespace (void *user_data, const XML_Char *prefix, const XML_Char *uri)
{
}

void
osm_parse (int fd)
{
  XML_Parser xml_parser;
  char buffer[4096];
  int ret;

  xml_parser = XML_ParserCreateNS ("utf-8", '|');

  XML_SetUserData (xml_parser, 0);
  XML_SetElementHandler (xml_parser, osm_start_element, osm_end_element);
  XML_SetCharacterDataHandler (xml_parser, osm_character_data);
  XML_SetStartNamespaceDeclHandler (xml_parser, osm_start_namespace);

  while (0 < (ret = read (0, buffer, sizeof (buffer))))
    {
      if (!XML_Parse (xml_parser, buffer, ret, 0))
        {
          ret = XML_GetErrorCode (xml_parser);

          osm_xml_error (ret);
        }
    }
}
