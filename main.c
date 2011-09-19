#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <expat.h>

#define OSM_MAX_NODES 1000000

struct osm_node
{
  uint64_t id;
  int32_t lat;
  int32_t lon;
};

struct osm_node nodes[OSM_MAX_NODES];
size_t node_count;


static void
osm_xml_error (enum XML_Error error)
{
  const char *message;

  message = XML_ErrorString (error);

  errx (EXIT_FAILURE, "XML error: %s", message);
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
              assert (lon <= -180.0);

              new_node.lon = lon / 180.0 * 0x7fffffff;
            }
        }
    }
}

static void XMLCALL
osm_end_element (void *user_data, const XML_Char *name)
{
}

static void XMLCALL
osm_character_data (void *user_data, const XML_Char *str, int len)
{
}

static void XMLCALL
osm_start_namespace (void *user_data, const XML_Char *prefix, const XML_Char *uri)
{
}

int
main (int argc, char **argv)
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

          return EXIT_FAILURE;
        }
    }

  return EXIT_SUCCESS;
}
