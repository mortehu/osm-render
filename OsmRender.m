#import <Foundation/Foundation.h>
#import <MapData.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWJSONStream.h>
#import <Swanston/SWPath.h>

#import <assert.h>
#import <err.h>
#import <fcntl.h>
#import <getopt.h>
#import <math.h>
#import <stdio.h>
#import <stdlib.h>
#import <sysexits.h>
#import <unistd.h>

#import <cairo/cairo.h>


static double lonMin, lonMax;
static double latMin, latMax;
static unsigned int imageWidth = 1024, imageHeight = 1024;

double
ClockwiseBoxPosition (NSPoint to, NSRect bounds)
{
  double result;

  if (to.y == NSMinY (bounds))
    return to.x - NSMinX (bounds);

  result = bounds.size.width;

  if (to.x == NSMaxX (bounds))
    return result + to.y - NSMinY (bounds);

  result += bounds.size.height;

  if (to.y == NSMaxY (bounds))
    return result + NSMaxX (bounds) - to.x;

  assert (to.x == NSMinX (bounds));

  result += bounds.size.width;

  return result + NSMaxY (bounds) - to.y;
}

void
ConnectClockwise (SWPath *path, NSPoint from, NSPoint to, NSRect bounds)
{
  unsigned int i, fromEdge, toEdge;

  fromEdge = (from.y == NSMinY (bounds)) ? 0
           : (from.x == NSMaxX (bounds)) ? 1
           : (from.y == NSMaxY (bounds)) ? 2
                                         : 3;

  toEdge = (to.y == NSMinY (bounds)) ? 0
         : (to.x == NSMaxX (bounds)) ? 1
         : (to.y == NSMaxY (bounds)) ? 2
                                     : 3;

  for (i = fromEdge; i != toEdge; i = (i + 1) & 3)
    {
      switch (i)
        {
        case 0: [path addPoint:NSMakePoint (NSMaxX (bounds), NSMinY (bounds))]; break;
        case 1: [path addPoint:NSMakePoint (NSMaxX (bounds), NSMaxY (bounds))]; break;
        case 2: [path addPoint:NSMakePoint (NSMinX (bounds), NSMaxY (bounds))]; break;
        case 3: [path addPoint:NSMakePoint (NSMinX (bounds), NSMinY (bounds))]; break;
        }
    }
}

struct CoastPathDescriptor
{
  SWPath *path;
  double startAngle;
  double endAngle;
};

void
ConnectEdgePaths (NSMutableArray *paths, NSRect bounds)
{
  struct CoastPathDescriptor *edgePaths;
  NSMutableIndexSet *discardedPaths;
  NSUInteger i = 0, j, count;
  double circumference;
  SWPath *path;

  count = [paths count];

  edgePaths = calloc (count, sizeof (*edgePaths));

  for (path in paths)
    {
      if (![path isCyclic])
        {
          edgePaths[i].startAngle = ClockwiseBoxPosition (path.firstPoint, bounds);
          edgePaths[i].endAngle = ClockwiseBoxPosition (path.lastPoint, bounds);
        }

      edgePaths[i].path = path;
      i++;
    }

  circumference = (bounds.size.width + bounds.size.height) * 2.0;
  discardedPaths = [NSMutableIndexSet indexSet];

  for (i = 0; i < count; ++i)
    {
      path = edgePaths[i].path;

      while (![discardedPaths containsIndex:i]
             && !path.isCyclic)
        {
          NSUInteger bestIndex;
          double bestScore = circumference;

          bestIndex = i;

          for (j = 0; j < count; ++j)
            {
              double score;

              if ([discardedPaths containsIndex:j] || edgePaths[j].path.isCyclic)
                continue;

              score = edgePaths[j].startAngle - edgePaths[i].endAngle;

              if (score < 0.0)
                score += circumference;

              if (score < bestScore)
                {
                  bestIndex = j;
                  bestScore = score;
                }
            }

          if (bestScore < circumference)
            {
              NSPoint from, to;

              from = edgePaths[i].path.lastPoint;
              to = edgePaths[bestIndex].path.firstPoint;

              if ((from.x != to.x && from.y != to.y)
                  || edgePaths[i].endAngle >= edgePaths[bestIndex].startAngle)
                {
                  ConnectClockwise (edgePaths[i].path, from, to, bounds);
                }

              if (bestIndex == i)
                [path addPoint:path.firstPoint];
              else
                {
                  [path addPointsFromPath:edgePaths[bestIndex].path];

                  edgePaths[i].endAngle = edgePaths[bestIndex].endAngle;

                  [discardedPaths addIndex:bestIndex];
                }
            }
          else
            {
              NSLog (@"Drats!");

              break;
            }
        }
    }

  [paths removeObjectsAtIndexes:discardedPaths];

  free (edgePaths);
}

static NSMutableArray *poorPaths;

void
MergeCoastPaths (NSMutableArray *paths, NSRect bounds)
{
  SWPath *pathA, *pathB;
  NSMutableIndexSet *discardedPaths;
  NSUInteger i, j, count;
  double minX, minY, maxX, maxY;

  minX = NSMinX (bounds);
  minY = NSMinY (bounds);
  maxX = NSMaxX (bounds);
  maxY = NSMaxY (bounds);

  discardedPaths = [NSMutableIndexSet indexSet];

  count = [paths count];

  /* Concatenate paths */

  for (i = 0; i < count; ++i)
    {
      BOOL wasUpdated;

      if ([discardedPaths containsIndex:i])
        continue;

      pathA = [paths objectAtIndex:i];

      if (pathA.isCyclic)
        continue;

      do
        {
          wasUpdated = NO;

          for (j = 0; j < count; ++j)
            {
              if (j == i || [discardedPaths containsIndex:j])
                continue;

              pathB = [paths objectAtIndex:j];

              if (pathB.isCyclic)
                continue;

              if (NSEqualPoints (pathA.lastPoint, pathB.firstPoint))
                {
                  [pathA addPointsFromPath:pathB];

                  [discardedPaths addIndex:j];

                  wasUpdated = YES;
                }
            }
        }
      while (wasUpdated);
    }

  poorPaths = [[NSMutableArray alloc] init];

  [paths removeObjectsAtIndexes:discardedPaths];
  count = [paths count];

  [discardedPaths removeAllIndexes];

  for (i = 0; i < count; ++i)
    {
      NSPoint begin, end;

      pathA = [paths objectAtIndex:i];

      begin = pathA.points[0];
      end = pathA.points[pathA.length - 1];

      if (NSEqualPoints (begin, end))
        continue;

      if ((begin.x > minX && begin.y > minY
           && begin.x < maxX && begin.y < maxY)
          || (end.x > minX && end.y > minY
              && end.x < maxX && end.y < maxY))
        {
          [poorPaths addObject:pathA];

          [discardedPaths addIndex:i];
        }
    }

    {
      for (i = 0; i < [poorPaths count]; ++i)
        {
          pathA = [poorPaths objectAtIndex:i];

          for (j = 0; j < [poorPaths count]; ++j)
            {
              NSPoint a, b;
              double distance;

              if (j == i)
                continue;

              pathB = [poorPaths objectAtIndex:j];

              a = pathA.lastPoint;
              b = pathB.firstPoint;

              if (NSEqualPoints (a, b))
                NSLog (@"Exactly equal");

              distance = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y);

              NSLog (@"Not exactly equal, but distance is: %g", sqrt (distance));
            }
        }
    }

  [paths removeObjectsAtIndexes:discardedPaths];

  ConnectEdgePaths (paths, bounds);
}

void
osm_paint (NSArray *ways)
{
  NSRect bounds;
  NSMutableArray *coastPaths;
  SWCairo *cairo;
  SWPath *path;
  MapWay *way;

  coastPaths = [[NSMutableArray alloc] init];

  cairo = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                 format:CAIRO_FORMAT_RGB24];

  bounds = NSMakeRect (0, 0, imageWidth, imageHeight);

  [cairo setColor:0xffefebe2];
  [cairo addRectangle:bounds];
  [cairo fill];

  /* Find coastline segments */

  for (way in ways)
    {
      NSString *natural;
      NSArray *clippedPaths;

      natural = [way.tags objectForKey:@"natural"];

      if (!natural || ![natural isEqualToString:@"coastline"])
        continue;

      [way.path translate:NSMakePoint (-lonMin, -latMax)];
      [way.path scale:NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax))];

      clippedPaths = [way.path clipToRect:bounds];

      if (clippedPaths)
        [coastPaths addObjectsFromArray:clippedPaths];
    }

  /* Merge coastlines into a single poly-polygon */

  MergeCoastPaths (coastPaths, bounds);

  /* ... and draw it */

  for (path in coastPaths)
    {
      if (![path isCyclic])
        continue;

      [cairo addPath:path];
    }

  [cairo setColor:0xffafbfdd];
  [cairo fill];

  /* Add ponds and such */

  for (way in ways)
    {
      if (   [[way.tags objectForKey:@"waterway"] isEqualToString:@"riverbank"]
          || [[way.tags objectForKey:@"waterway"] isEqualToString:@"dock"]
          || [[way.tags objectForKey:@"natural"] isEqualToString:@"water"]
          || [[way.tags objectForKey:@"natural"] isEqualToString:@"pond"]
          || [[way.tags objectForKey:@"natural"] isEqualToString:@"lake"]
          || [[way.tags objectForKey:@"landuse"] isEqualToString:@"water"]
          || [[way.tags objectForKey:@"landuse"] isEqualToString:@"pond"]
          || [[way.tags objectForKey:@"landuse"] isEqualToString:@"lake"]
          || [[way.tags objectForKey:@"landuse"] isEqualToString:@"reservoid"]
          || [[way.tags objectForKey:@"landuse"] isEqualToString:@"basin"])
        {
          [way.path translate:NSMakePoint (-lonMin, -latMax)];
          [way.path scale:NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax))];

          [cairo addPath:way.path
                  closed:YES];
          [cairo fill];
        }
    }

  for (path in poorPaths)
    {
      [cairo addPath:path];

      [cairo setColor:rand ()];
      [cairo setLineWidth:1.0f];
      [cairo stroke];
    }

  [cairo writeToPNG:@"output.png"];
  [cairo release];
}

static int print_version;
static int print_help;

static NSString *mapDataPath = @"planet-latest.osm.pbf";

static struct option long_options[] =
{
    { "version",        no_argument, &print_version, 1 },
    { "help",           no_argument, &print_help,    1 },
    { "map-data",       required_argument, 0, 'm' },
    { 0, 0, 0, 0 }
};

static void
OsmRenderParseOptions (int argc, char **argv)
{
  int i;

  while ((i = getopt_long (argc, argv, "", long_options, 0)) != -1)
    {
      switch (i)
        {
        case 0:

          break;

        case 'm':

          mapDataPath = [NSString stringWithUTF8String:optarg];

          break;

        case '?':

          fprintf (stderr, "Try `%s --help' for more information.\n", argv[0]);

          exit (EX_USAGE);
        }
    }

  if (print_help)
    {
      printf ("Usage: %s [OPTION]... <FILE>\n"
              "\n"
              "      --map-data=PATH        specify path map data (planet-latest.osm.pbf)\n"
              "      --help     display this help and exit\n"
              "      --version  display version information\n"
              "\n"
              "Report bugs to <morten.hustveit@gmail.com>\n", argv[0]);

      exit (EXIT_SUCCESS);
    }

  if (print_version)
    {
      fprintf (stdout, "%s\n", PACKAGE_STRING);

      exit (EXIT_SUCCESS);
    }
}

static void
OsmRenderLoadNeighborhoods (NSString *path)
{
  SWJSONStreamParser *parser;
  SWJSONStream *stream;
  NSDictionary *config;
  NSArray *areaBox;

  parser = [SWJSONStreamParser new];

  stream = [SWJSONStream new];
  stream.delegate = parser;

  [stream consumeData:[NSData dataWithContentsOfFile:path]];
  [stream consumeEnd];

  if (!parser.result)
    {
      NSLog (@"Failed to parse %@", path);

      exit (EXIT_FAILURE);
    }

  config = (NSDictionary *) parser.result;

  if (!([config isKindOfClass:[NSDictionary class]]))
    errx (EXIT_FAILURE, "%s does not contain an object at the root level",
          [path UTF8String]);

  if (!(areaBox = [config objectForKey:@"areaBox"]))
    errx (EXIT_FAILURE, "%s is missing an areaBox",
          [path UTF8String]);

  latMin = [[areaBox objectAtIndex:0] doubleValue];
  lonMin = [[areaBox objectAtIndex:1] doubleValue];
  latMax = [[areaBox objectAtIndex:2] doubleValue];
  lonMax = [[areaBox objectAtIndex:3] doubleValue];

  if (latMin > latMax)
    {
      double tmp;

      tmp = latMin;
      latMin = latMax;
      latMax = tmp;
    }

  if (lonMin > lonMax)
    {
      double tmp;

      tmp = lonMin;
      lonMin = lonMax;
      lonMax = tmp;
    }

#if 0
  double latCenter = (latMin + latMax) * 0.5, lonCenter = (lonMin + lonMax) * 0.5;
  double lat = (latMax - latMin) * 0.5, lon = (lonMax - lonMin) * 0.5;
  double scale = 1.5;

  lonMin = lonCenter - lon * scale;
  lonMax = lonCenter + lon * scale;
  latMin = latCenter - lat * scale;
  latMax = latCenter + lat * scale;
#endif

  NSLog (@"Box: %.5f %.5f %.5f %.5f", latMin, lonMin, latMax, lonMax);
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool;
  MapData *mapData;
  NSArray *ways;

  pool = [[NSAutoreleasePool alloc] init];

  OsmRenderParseOptions (argc, argv);

  if (optind + 1 != argc)
    errx (EX_USAGE, "Usage: %s [OPTION]... <FILE>", argv[0]);

  OsmRenderLoadNeighborhoods ([NSString stringWithUTF8String:argv[optind]]);

  if (!(mapData = [[MapData alloc] initWithPath:mapDataPath]))
    errx (EXIT_FAILURE, "Failed to load map data");

  ways = [mapData waysInRect:NSMakeRect (lonMin, latMin, lonMax - lonMin, latMax - latMin)];

  NSLog (@"Got %lu ways", [ways count]);

  osm_paint (ways);

  [pool release];

  return EXIT_SUCCESS;
}
