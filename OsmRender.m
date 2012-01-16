#import <Foundation/Foundation.h>
#import <MapData.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWJSONStream.h>
#import <Swanston/SWPango.h>
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
#import <pango/pangocairo.h>

static int print_version;
static int print_help;

static NSString *mapDataPath = @".";
static NSString *prefix = @"output";
static unsigned int imageWidth = 396, imageHeight = 396;
static NSString *inactiveAreaLabelFont = @"Arial Bold 8";
static NSString *activeAreaLabelFont = @"Arial Bold 8";
static NSString *landmarkLabelFont = @"Arial 8";
static uint32_t landColor = 0xfff6f5f2;
static uint32_t parkColor = 0xffc9dfaf;
static uint32_t inactiveAreaColor = 0xffdee9f1;
static uint32_t activeAreaColor = 0xfffec801;
static uint32_t waterColor = 0xffaec6e1;
static uint32_t inactiveAreaLabelColor = 0xff4c4c4c;
static uint32_t activeAreaLabelColor = 0xffffffff;
static uint32_t activeAreaLabelBackgroundColor = 0x7f000000;
static uint32_t landmarkLabelColor = 0xff7c126a;
static uint32_t landmarkBulletSize = 6;
static uint32_t landmarkBulletColor = 0xff7c126a;

static struct option long_options[] =
{
    { "active-area-font",      required_argument, 0, 'A' },
    { "active-area-font-color", required_argument, 0, 'a' },
    { "active-area-color",     required_argument, 0, 'B' },
    { "active-area-bgcolor",   required_argument, 0, 'C' },
    { "inactive-area-font",    required_argument, 0, 'D' },
    { "inactive-area-font-color",    required_argument, 0, 'd' },
    { "inactive-area-color",   required_argument, 0, 'E' },
    { "landmark-font",         required_argument, 0, 'F' },
    { "landmark-color",        required_argument, 0, 'G' },
    { "landmark-bullet-color", required_argument, 0, 'H' },
    { "land-color",            required_argument, 0, 'I' },
    { "water-color",           required_argument, 0, 'J' },
    { "park-color",            required_argument, 0, 'K' },
    { "size",      required_argument, 0, 's' },
    { "prefix",    required_argument, 0, 'p' },
    { "map-path",  required_argument, 0, 'm' },
    { "version",   no_argument, &print_version, 1 },
    { "help",      no_argument, &print_help,    1 },
    { 0, 0, 0, 0 }
};

@interface OsmRenderNeighborhood : NSObject
{
@public

  SWPath *path;
  NSString *name;
  NSPoint center;
  int type;
}
@end

@implementation OsmRenderNeighborhood
@end

static double lonMin, lonMax;
static double latMin, latMax;
static NSMutableArray *neighborhoods;
static NSArray *landmarks;

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
          [discardedPaths addIndex:i];
        }
    }

  [paths removeObjectsAtIndexes:discardedPaths];

  ConnectEdgePaths (paths, bounds);
}

void
OsmRenderTransformPoint (NSPoint *point)
{
  point->x = round ((point->x - lonMin) * imageWidth / (lonMax - lonMin));
  point->y = round ((point->y - latMax) * imageHeight / (latMin - latMax));
}

void
OsmRender (NSArray *ways, NSUInteger activeArea, BOOL hover)
{
  NSRect bounds;
  NSMutableArray *coastPaths;
  SWCairo *cairo;
  SWPath *path;
  MapWay *way;
  OsmRenderNeighborhood *neighborhood;
  NSUInteger i;
  NSString *outputPath;

  coastPaths = [[NSMutableArray alloc] init];

  cairo = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                 format:CAIRO_FORMAT_RGB24];

  bounds = NSMakeRect (0, 0, imageWidth, imageHeight);

  [cairo setColor:landColor];
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

  [cairo setColor:waterColor];
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
          [cairo addPath:way.path
                  closed:YES];
          [cairo fill];
        }
    }

  /* Add neighborhoods */

    {
      SWCairo *mask, *source;

      mask = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                    format:CAIRO_FORMAT_A8];
      source = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                      format:CAIRO_FORMAT_RGB24];

      for (neighborhood in neighborhoods)
        [mask addPath:neighborhood->path closed:YES];
      [mask fill];

      cairo_set_operator ([mask cairo], CAIRO_OPERATOR_DEST_OUT);
      [mask setLineWidth:3.0f];

      i = 0;

      for (neighborhood in neighborhoods)
        {
          [mask addPath:neighborhood->path closed:YES];
          [source addPath:neighborhood->path closed:YES];

          if (i == activeArea && !hover)
            [source setColor:activeAreaColor];
          else
            {
              switch (neighborhood->type)
                {
                case 2:  [source setColor:parkColor]; break;
                default: [source setColor:inactiveAreaColor];
                }
            }

          [source fill];

          i++;
        }

      [mask stroke];

      cairo_set_source_surface (cairo.cairo, source.surface, 0.0, 0.0);
      cairo_mask_surface (cairo.cairo, mask.surface, 0.0, 0.0);

      [source release];
      [mask release];
    }

  i = 0;

  for (neighborhood in neighborhoods)
    {
      SWPangoLayout *text;
      NSRect textRect;
      NSSize textSize;

      text = [SWPangoLayout layoutWithCairo:cairo];

      [text setFontFromString:(i == activeArea) ? activeAreaLabelFont : inactiveAreaLabelFont];
      [text setAlignment:PANGO_ALIGN_CENTER];
      [text setText:neighborhood->name];

      textSize = text.size;
      textRect = NSMakeRect (neighborhood->center.x - textSize.width * 0.5,
                             neighborhood->center.y - textSize.height * 0.5,
                             textSize.width, textSize.height);

      if (textRect.origin.x < 2)
        textRect.origin.x = 2;

      if (textRect.origin.y < 2)
        textRect.origin.y = 2;

      if (NSMaxX (textRect) > imageWidth - 2)
        textRect.origin.x = imageWidth - textRect.size.width - 2;

      if (NSMaxY (textRect) > imageHeight - 2)
        textRect.origin.y = imageHeight - textRect.size.height - 2;

      textRect = NSIntegralRect (textRect);

      if (i == activeArea)
        {
          NSRect textBounds;

          textBounds = NSOffsetRect (textRect, -3.0, -3.0);
          textBounds.size.width += 5.0;
          textBounds.size.height += 5.0;

          [cairo addRectangle:textBounds
                       radius:4];
          [cairo setColor:activeAreaLabelBackgroundColor];
          [cairo fill];

          [cairo setColor:activeAreaLabelColor];
        }
      else
        [cairo setColor:inactiveAreaLabelColor];

      cairo_move_to (cairo.cairo, textRect.origin.x, textRect.origin.y);

      [text paint];

      i++;
    }

  /* Add landmarks */

  for (NSDictionary *landmark in landmarks)
    {
      SWPangoLayout *text;
      NSSize textSize;
      NSPoint position;

      if (![[landmark objectForKey:@"display"] boolValue])
        continue;

      text = [SWPangoLayout layoutWithCairo:cairo];

      [cairo setColor:inactiveAreaLabelColor];

      [text setFontFromString:landmarkLabelFont];
      [text setAlignment:PANGO_ALIGN_CENTER];
      [text setText:[landmark objectForKey:@"label"]];

      textSize = text.size;

      position.x = [[landmark objectForKey:@"lon"] doubleValue];
      position.y = [[landmark objectForKey:@"lat"] doubleValue];

      OsmRenderTransformPoint (&position);

      cairo_move_to (cairo.cairo,
                     position.x + landmarkBulletSize,
                     position.y - textSize.height * 0.5);

      [cairo setColor:landmarkLabelColor];
      [text paint];

      [cairo addRectangle:NSMakeRect (position.x - landmarkBulletSize / 2,
                                      position.y - landmarkBulletSize / 2,
                                      landmarkBulletSize, landmarkBulletSize)];
      [cairo setColor:landmarkBulletColor];
      [cairo fill];
    }

  if (activeArea < [neighborhoods count])
    outputPath = [NSString stringWithFormat:@"%@-%02lu%@.png", prefix, (unsigned long) activeArea, hover ? @"-hover" : @""];
  else
    outputPath = [NSString stringWithFormat:@"%@.png", prefix];

  [cairo writeToPNG:outputPath];
  [cairo release];
}

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

        case 'A':

          activeAreaLabelFont = [NSString stringWithUTF8String:optarg];

          break;

        case 'a':

          activeAreaLabelColor = strtol (optarg, 0, 0);

          break;

        case 'B':

          activeAreaColor = strtol (optarg, 0, 0);

          break;

        case 'C':

          activeAreaLabelBackgroundColor = strtol (optarg, 0, 0);

          break;

        case 'D':

          inactiveAreaLabelFont = [NSString stringWithUTF8String:optarg];

          break;

        case 'd':

          inactiveAreaLabelColor = strtol (optarg, 0, 0);

          break;

        case 'E':

          inactiveAreaColor = strtol (optarg, 0, 0);

          break;

        case 'F':

          landmarkLabelFont = [NSString stringWithUTF8String:optarg];

          break;

        case 'G':

          landmarkLabelColor = strtol (optarg, 0, 0);

          break;

        case 'H':

          landmarkBulletColor = strtol (optarg, 0, 0);

          break;

        case 'I':

          landColor = strtol (optarg, 0, 0);

          break;

        case 'J':

          waterColor = strtol (optarg, 0, 0);

          break;

        case 'K':

          parkColor = strtol (optarg, 0, 0);

          break;

        case 's':

          imageWidth = imageHeight = strtol (optarg, 0, 0);

          break;

        case 'p':

          prefix = [NSString stringWithUTF8String:optarg];

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
              "      --active-area-font=FONT\n"
              "      --active-area-font-color=COLOR\n"
              "      --active-area-color=COLOR\n"
              "      --active-area-bgcolor=COLOR\n"
              "      --inactive-area-font=FONT\n"
              "      --inactive-area-font-color=COLOR\n"
              "      --inactive-area-color=COLOR\n"
              "      --landmark-font=FONT\n"
              "      --landmark-color=COLOR\n"
              "      --landmark-bullet-color=COLOR\n"
              "      --land-color=COLOR\n"
              "      --water-color=COLOR\n"
              "      --size=PIXELS          width of output image\n"
              "      --prefix=STRING        prefix for output file names\n"
              "      --map-path=PATH        path containing .osm.pbf files\n"
              "      --help     display this help and exit\n"
              "      --version  display version information\n"
              "\n"
              "Example font:  Arial Bold 8\n"
              "Example color: 0xff553322 (Components are in ARGB order)\n"
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

  neighborhoods = [NSMutableArray new];

  for (NSDictionary *area in [config objectForKey:@"areas"])
    {
      NSPoint point;
      NSString *vertex;
      OsmRenderNeighborhood *neighborhood;

      neighborhood = [OsmRenderNeighborhood new];
      neighborhood->path = [SWPath new];

      for (vertex in [(NSString *)[area objectForKey:@"polygon"] componentsSeparatedByString:@","])
        {
          sscanf ([vertex UTF8String], "%lf %lf", &point.y, &point.x);

          [neighborhood->path addPoint:point];
        }

      [neighborhood->path translate:NSMakePoint (-lonMin, -latMax)];
      [neighborhood->path scale:NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax))];

      neighborhood->name = [[area objectForKey:@"label"] retain];

      neighborhood->center.x = [[[area objectForKey:@"center"] objectAtIndex:1] doubleValue];
      neighborhood->center.y = [[[area objectForKey:@"center"] objectAtIndex:0] doubleValue];
      OsmRenderTransformPoint (&neighborhood->center);

      neighborhood->type = [[area objectForKey:@"type"] intValue];

      [neighborhoods addObject:neighborhood];
      [neighborhood release];
    }

  landmarks = [[config objectForKey:@"landmarks"] retain];
}

NSString *
OsmRenderFindMapFile (NSRect geoBounds)
{
  NSAutoreleasePool *pool;
  NSString *bestMatch = nil;
  double bestArea;

  pool = [NSAutoreleasePool new];
  
  for (NSString *path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mapDataPath error:NULL])
    {
      NSString *fullPath;
      MapData *mapData;
      NSRect mapBounds;
      NSRange range;

      range = [path rangeOfString:@"\\.osm\\.pbf$"
                          options:NSRegularExpressionSearch];

      if (range.location == NSNotFound)
        continue;

      fullPath = [mapDataPath stringByAppendingPathComponent:path];

      mapData = [[MapData alloc] initWithPath:fullPath];

      mapBounds = mapData.bounds;

      [mapData release];

      if (NSContainsRect (mapBounds, geoBounds))
        {
          double area;

          area = mapBounds.size.width * mapBounds.size.height;

          if (!bestMatch || area < bestArea)
            {
              bestMatch = fullPath;
              bestArea = area;
            }
        }
    }

  [bestMatch retain];
  [pool release];

  NSLog (@"%@", bestMatch);

  return [bestMatch autorelease];
}

int
main (int argc, char **argv)
{
  NSString *mapFilePath;
  NSAutoreleasePool *pool;
  MapData *mapData;
  NSArray *ways;
  NSRect geoBounds;
  NSUInteger i;

  pool = [[NSAutoreleasePool alloc] init];

  OsmRenderParseOptions (argc, argv);

  if (optind + 1 != argc)
    errx (EX_USAGE, "Usage: %s [OPTION]... <FILE>", argv[0]);

  OsmRenderLoadNeighborhoods ([NSString stringWithUTF8String:argv[optind]]);

  geoBounds = NSMakeRect (lonMin, latMin, lonMax - lonMin, latMax - latMin);

  mapFilePath = OsmRenderFindMapFile (geoBounds);

  if (!(mapData = [[MapData alloc] initWithPath:mapFilePath]))
    errx (EXIT_FAILURE, "Failed to load map data");

  ways = [mapData waysInRect:geoBounds];

  for (MapWay *way in ways)
    {
      [way.path translate:NSMakePoint (-lonMin, -latMax)];
      [way.path scale:NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax))];
    }

  NSLog (@"Got %lu ways", [ways count]);

  for (i = 0; i <= [neighborhoods count]; ++i)
    {
      OsmRender (ways, i, YES);
      OsmRender (ways, i, NO);
    }

  [pool release];

  return EXIT_SUCCESS;
}
