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

  if (!(result = fopen (path, "wx")))
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
                {
                  newMode = OSMPlanetParserWay;

                  struct
                    {
                      uint64_t nodeRefStart;
                      uint64_t tagStart;
                    } data;

                  data.nodeRefStart = nextNodeRefIndex;
                  data.tagStart = nextTagOffset;

                  fwrite (&data, sizeof (data), 1, ways);
                }

              break;

            case 4:

              if (!memcmp (name, "node", 4))
                newMode = OSMPlanetParserNode;
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

      switch (nameLength)
        {
        case 2:

          if (!memcmp (name, "id", 2))
            {
              unsigned long long newID = 0;

              while (valueLength--)
                newID = newID * 10 + (*value++ - '0');

              if (newID != nextNodeID)
                {
                  if (newID < nextNodeID)
                    {
                      errx (EXIT_FAILURE, "Node ID not monotonically increasing after %llu.  Next was %llu",
                            nextNodeID, newID);
                    }

                  fseek (nodes, (newID - nextNodeID) * 2 * sizeof (double), SEEK_CUR);

                  nextNodeID = newID + 1;
                }
              else
                nextNodeID++;
            }

        case 3:

          if (!memcmp (name, "lat", 3)
              || !memcmp (name, "lon", 3))
            {
              char buf[16];
              double v;

              memcpy (buf, value, valueLength);
              buf[valueLength] = 0 ;

              v = strtod (value, 0);

              fwrite (&v, sizeof (v), 1, nodes);
            }

          break;
        }

      break;

    case OSMPlanetParserWayTag:

      if (nameLength == 1 && (*name == 'k' || *name == 'v'))
        {
          fwrite (value, 1, valueLength, tags);
          fputc (0, tags);
          nextTagOffset += valueLength + 1;
        }

      break;

    case OSMPlanetParserWayNodeRef:

      if (nameLength == 3 && !memcmp (name, "ref", 3))
        {
          uint64_t ref = 0;

          while (valueLength--)
            ref = ref * 10 + (*value++ - '0');

          fwrite (&ref, sizeof (ref), 1, nodeRefs);

          nextNodeRefIndex++;
        }

      break;

    default:

      ;
    }
}
@end

int
main (int argc, char **argv)
{
  void *buffer;
  off_t size;
  int fd;

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

  nodes = try_create ("planet/.nodes.new");
  ways = try_create ("planet/.ways.new");
  tags = try_create ("planet/.tags.new");
  nodeRefs = try_create ("planet/.nodeRefs.new");

  SWXMLParser *xmlParser;
  OSMPlanetParser *planetParser;

  planetParser = [OSMPlanetParser new];
  xmlParser = [[SWXMLParser alloc] initWithDelegate:planetParser];

  [xmlParser parseBytes:buffer
                 length:size];

  munmap (buffer, size);

  fsync (fileno (nodes));
  fsync (fileno (ways));
  fsync (fileno (tags));
  fsync (fileno (nodeRefs));

  rename ("planet/.nodes.new", "planet/nodes");
  rename ("planet/.ways.new", "planet/ways");
  rename ("planet/.tags.new", "planet/tags");
  rename ("planet/.nodeRefs.new", "planet/nodeRefs");

  return EXIT_SUCCESS;
}
