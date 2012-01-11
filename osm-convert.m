#import <assert.h>
#import <fcntl.h>
#import <limits.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <sys/mman.h>
#import <unistd.h>

#import <err.h>
#import <sysexits.h>

#import <Swanston/SWXMLParser.h>
#import <expat.h>

static FILE *nodes, *ways, *tags, *nodeRefs;

struct node_data
{
  double lat, lon;
};

struct way_data
{
  uint64_t nodeRefStart;
  uint64_t tagStart;
};

unsigned long long nextNodeID = 0;
unsigned long long nextWayID = 0;
unsigned long long nextNodeRefIndex;
unsigned long long nextTagOffset;

static FILE *
try_create (const char *path)
{
  FILE *result;

  if (!(result = fopen (path, "w")))
    err (EXIT_FAILURE, "Failed to create '%s'", path);

  return result;
}

enum OSMPlanetParserMode
{
  OSMPlanetParserUnknown,
  OSMPlanetParserRoot,
  OSMPlanetParserNode,
  OSMPlanetParserWay,
  OSMPlanetParserWayTag,
  OSMPlanetParserWayNodeRef
};

typedef enum OSMPlanetParserMode OSMPlanetParserMode;

@interface OSMPlanetParser : NSObject <SWXMLParserDelegate>
{
  OSMPlanetParserMode stack[16];
  unsigned int stackDepth;
}
@end

@implementation OSMPlanetParser
- (void)        xmlParser:(SWXMLParser *)parser
  didStartElementWithName:(const char *)name
                   length:(unsigned int)length
{
  OSMPlanetParserMode newMode = OSMPlanetParserUnknown;

  if (!stackDepth)
    newMode = OSMPlanetParserRoot;
  else
    {
      switch (stack[stackDepth - 1])
        {
        case OSMPlanetParserRoot:

          switch (length)
            {
            case 3:

              if (!memcmp (name, "way", 3))
                newMode = OSMPlanetParserWay;

              break;

            case 4:

              if (!memcmp (name, "node", 4))
                {
                  exit (0);
                  newMode = OSMPlanetParserNode;
                }
            }

          break;

        case OSMPlanetParserWay:

          switch (length)
            {
            case 2:

              if (!memcmp (name, "nd", 2))
                newMode = OSMPlanetParserWayNodeRef;

              break;

            case 3:

              if (!memcmp (name, "tag", 3))
                newMode = OSMPlanetParserWayTag;

              break;
            }

          break;

        default:

          ;
        }
    }

  stack[stackDepth++] = newMode;
}

- (void)xmlParserDidLeaveElement:(SWXMLParser *)parser
{
  assert (stackDepth);

  stackDepth--;
#if 0
  switch (name[0])
    {
    case 'n':

      if (!strcmp (name + 1, "ode"))
        {
          unsigned long long id = 0;
          struct node_data data;

          for (attr = atts; *attr; attr += 2)
            {
              if (!strcmp (attr[0], "id"))
                id = strtoll (attr[1], 0, 10);
              else if (!strcmp (attr[0], "lat"))
                {
                  data.lat = strtod (attr[1], 0);

                  assert (data.lat >= -90.0);
                  assert (data.lat <= 90.0);
                }
              else if (!strcmp (attr[0], "lon"))
                {
                  data.lon = strtod (attr[1], 0);

                  assert (data.lon >= -180.0);
                  assert (data.lon <= 180.0);
                }
            }

          if (id != nextNodeID)
            {
              if (id < nextNodeID)
                {
                  errx (EXIT_FAILURE, "Node ID not monotonically increasing after %llu.  Next was %llu",
                        nextNodeID, id);
                }

              fseek (nodes, (id - nextNodeID) * sizeof (data), SEEK_CUR);

              nextNodeID = id + 1;
            }
          else
            ++nextNodeID;

          fwrite (&data, sizeof (data), 1, nodes);
        }
      else if (!strcmp (name, "nd"))
        {
          if (inWay)
            {
              uint64_t ref = (uint64_t) -1;

              for (attr = atts; *attr; attr += 2)
                {
                  if (!strcmp (attr[0], "ref"))
                    ref = strtoll (attr[1], 0, 10);
                }

              if (ref != (uint64_t) -1)
                {
                  fwrite (&ref, sizeof (ref), 1, nodeRefs);

                  ++nextNodeRefIndex;
                }
            }
        }

      break;

    case 't':

      if (!strcmp (name, "tag"))
        {
          if (inWay)
            {
              const char *k = 0, *v = 0;
              size_t length;

              for (attr = atts; *attr; attr += 2)
                {
                  if (!strcmp (attr[0], "k"))
                    k = attr[1];
                  else if (!strcmp (attr[0], "v"))
                    v = attr[1];
                }

              assert (k && v);

              length = strlen (k) + 1;
              fwrite (k, 1, length, tags);
              nextTagOffset += length;

              length = strlen (v) + 1;
              fwrite (v, 1, length, tags);
              nextTagOffset += length;
            }
        }

      break;

    case 'w':

      if (!strcmp (name, "way"))
        {
          unsigned long long id = 0;
          struct way_data data;

          for (attr = atts; *attr; attr += 2)
            {
              if (!strcmp (attr[0], "id"))
                id = strtoll (attr[1], 0, 10);
            }

          if (id != nextWayID)
            {
              if (id < nextWayID)
                {
                  errx (EXIT_FAILURE, "Way ID not monotonically increasing after %llu.  Next was %llu",
                        nextWayID, id);
                }

              fseek (nodes, (id - nextWayID) * sizeof (data), SEEK_CUR);

              nextWayID = id + 1;
            }
          else
            ++nextWayID;

          data.nodeRefStart = nextNodeRefIndex;
          data.tagStart = nextTagOffset;

          fwrite (&data, sizeof (data), 1, ways);

          inWay = 1;
        }

      break;
    }
#endif
}

- (void)       xmlParser:(SWXMLParser *)parser
  foundAttributeWithName:(const char *)name
              nameLength:(unsigned int)nameLength
                   value:(const char *)value
             valueLength:(unsigned int)valueLength
{
  switch (stack[stackDepth - 1])
    {
    case OSMPlanetParserNode:

      fprintf (stderr, "Node attribute: %.*s -> %.*s\n",
               (int) nameLength, name,
               (int) valueLength, value);

      break;

    case OSMPlanetParserWay:

      fprintf (stderr, "Way attribute: %.*s -> %.*s\n",
               (int) nameLength, name,
               (int) valueLength, value);

      break;

    case OSMPlanetParserWayTag:

      fprintf (stderr, "Way tag attribute: %.*s -> %.*s\n",
               (int) nameLength, name,
               (int) valueLength, value);

      break;

    case OSMPlanetParserWayNodeRef:

      fprintf (stderr, "Way node ref attribute: %.*s -> %.*s\n",
               (int) nameLength, name,
               (int) valueLength, value);

      break;

    default:

      ;
    }
}
@end

int
main (int argc, char **argv)
{
/*  XML_Parser xml_parser;*/
  int fd;
  void *buffer;
  off_t size;

  if (argc != 2)
    errx (EX_USAGE, "Usage: %s <PLANET.OSM>", argv[0]);

  if (-1 == (fd = open (argv[1], O_RDONLY)))
    err (EXIT_FAILURE, "Failed to open 'planet.osm' for reading");

  if (-1 == (size = lseek (fd, 0, SEEK_END)))
    err (EXIT_FAILURE, "Failed to seek to end of 'planet.osm'");

  if (MAP_FAILED == (buffer = mmap (0, size, PROT_READ, MAP_SHARED, fd, 0)))
    err (EXIT_FAILURE, "Failed to map %llu bytes of 'planet.osm'",
         (unsigned long long) size);

  close (fd);

  madvise (buffer, size, MADV_SEQUENTIAL);

  nodes = try_create ("planet/nodes");
  ways = try_create ("planet/ways");
  tags = try_create ("planet/tags");
  nodeRefs = try_create ("planet/nodeRefs");

  SWXMLParser *xmlParser;
  OSMPlanetParser *planetParser;

  planetParser = [OSMPlanetParser new];
  xmlParser = [[SWXMLParser alloc] initWithDelegate:planetParser];

  [xmlParser parseBytes:buffer
                 length:size];
#if 0
  xml_parser = XML_ParserCreate ("utf-8");

  XML_SetUserData (xml_parser, 0);
  XML_SetElementHandler (xml_parser, osm_start_element, osm_end_element);

  while (offset < size)
    {
      int amount;

      if (size - offset > INT_MAX / 2)
        amount = INT_MAX / 2;
      else
        amount = (int) (size - offset);

      fprintf (stderr, "At offset %llu, amount %d...\n", (unsigned long long) offset, amount);

      if (!(ret = XML_Parse (xml_parser, (const char *) buffer + offset, amount, 0)))
        {
          errx (EXIT_FAILURE, "expat failed to parse 'planet.osm': offset=%llu length=%d error-string=%s",
                (unsigned long long) offset,
                amount,
                XML_ErrorString (ret));
        }

      offset += amount;
    }
#endif

  munmap (buffer, size);

  return EXIT_SUCCESS;
}
