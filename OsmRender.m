#import <Foundation/Foundation.h>
#import <MapData.h>
#import <Swanston/NSFileManager+SWOperations.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWHash.h>
#import <Swanston/SWImage.h>
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
#import <pango/pangocairo.h>

static int print_version;
static int print_help;

static NSString *mapDataPath = @".";
static NSString *prefix = @"output";
static unsigned int imageWidth = 396, imageHeight = 396;
static NSString *inactiveAreaLabelFontName = @"Arial Bold 8";
static NSString *activeAreaLabelFontName = @"Arial Bold 8";
static NSString *landmarkLabelFontName = @"Arial 8";
static int fontSize = 11;
static uint32_t landColor = 0xfff6f5f2;
static uint32_t parkColor = 0xffe2eed4;
static uint32_t inactiveAreaColor = 0xffdee9f1;
static uint32_t activeAreaColor = 0xfffec801;
static uint32_t hoverAreaColor = ((0xffaec6e1 >> 1) & 0x7f7f7f7f) + ((0xffdee9f1 >> 1) & 0x7f7f7f7f);
static uint32_t hoverParkColor = ((0xffaec6e1 >> 1) & 0x7f7f7f7f) + ((0xffe2eed4 >> 1) & 0x7f7f7f7f);
static uint32_t waterColor = 0xffaec6e1;
static uint32_t inactiveAreaLabelColor = 0xff4c4c4c;
static uint32_t activeAreaLabelColor = 0xffffffff;
static uint32_t activeAreaLabelBackgroundColor = 0x7f000000;
static uint32_t landmarkLabelColor = 0xff7c126a;
static uint32_t landmarkBulletSize = 6;
static uint32_t landmarkBulletColor = 0xff7c126a;
static int dummyRun = 0;
static int verbose = 0;
static int noCache = 0;
static int waterInFront = 1;

static SWCairo *treeIcon;

static struct option long_options[] =
{
    { "active-area-font",      required_argument, 0, 'A' },
    { "active-area-font-color", required_argument, 0, 'a' },
    { "active-area-font-bgcolor",   required_argument, 0, 'C' },
    { "active-area-color",     required_argument, 0, 'B' },
    { "inactive-area-font",    required_argument, 0, 'D' },
    { "inactive-area-font-color",    required_argument, 0, 'd' },
    { "inactive-area-color",   required_argument, 0, 'E' },
    { "landmark-font",         required_argument, 0, 'F' },
    { "landmark-color",        required_argument, 0, 'G' },
    { "landmark-bullet-color", required_argument, 0, 'H' },
    { "land-color",            required_argument, 0, 'I' },
    { "water-color",           required_argument, 0, 'J' },
    { "park-color",            required_argument, 0, 'K' },
    { "hover-area-color",      required_argument, 0, 'L' },
    { "hover-park-color",      required_argument, 0, 'M' },
    { "size",      required_argument, 0, 's' },
    { "prefix",    required_argument, 0, 'p' },
    { "map-directory",  required_argument, 0, 'm' },
    { "map-file",  required_argument, 0, 'n' },
    { "dummy-run",     no_argument, &dummyRun, 1 },
    { "verbose",     no_argument, &verbose, 1 },
    { "no-cache",     no_argument, &noCache, 1 },
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

static SWCairo *
OsmRenderLoadImage (NSString *path)
{
  NSFileHandle *file;
  NSData *data;
  SWImageDecoder *imageDecoder;
  SWImage *image;
  SWCairo *result;

  file = [NSFileHandle fileHandleForReadingAtPath:path];
  data = [file readDataToEndOfFile];
  [file closeFile];

  image = [SWImage new];

  if (!(imageDecoder = [[SWImageDecoder alloc] initWithDelegate:image]))
    goto fail;

  [imageDecoder consumeData:data];
  [imageDecoder consumeEnd];
  [imageDecoder release];

  result = [[SWCairo alloc] initWithImage:image];

  [image release];

  return result;

fail:

  [imageDecoder release];
  [image release];

  return NULL;
}

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

SWCairo *
OsmRenderMap (NSArray *ways)
{
  NSRect bounds;
  NSMutableArray *coastPaths;
  NSMutableArray *bridgePaths;
  SWCairo *cairo;
  SWPath *path;
  MapWay *way;
  NSPoint scale;

  scale = NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax));

  coastPaths = [NSMutableArray new];
  bridgePaths = [NSMutableArray new];

  cairo = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                 format:CAIRO_FORMAT_ARGB32];

  bounds = NSMakeRect (0, 0, imageWidth, imageHeight);

  /* Find coastline and bridge segments */

  for (way in ways)
    {
      SWPath *scaledPath;
      NSString *natural;
      NSArray *clippedPaths;

      if ([way.tags objectForKey:@"bridge"])
        {
          scaledPath = [[SWPath alloc] initWithPath:way.path];
          [scaledPath scale:scale];

          [bridgePaths addObject:scaledPath];

          [scaledPath release];

          continue;
        }

      natural = [way.tags objectForKey:@"natural"];

      if (natural && [natural isEqualToString:@"coastline"])
        {
          scaledPath = [[SWPath alloc] initWithPath:way.path];
          [scaledPath scale:scale];

          clippedPaths = [scaledPath clipToRect:bounds];

          if (clippedPaths)
            [coastPaths addObjectsFromArray:clippedPaths];

          [scaledPath release];

          continue;
        }
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
               withScale:scale
                  closed:YES];
          [cairo fill];
        }
    }

  /* Remove bridges */

  cairo.color = 0xffffffff;
  cairo.lineWidth = 2.0f;
  cairo.operator = CAIRO_OPERATOR_DEST_OUT;

  for (path in bridgePaths)
    {
      [cairo addPath:path];
      [cairo stroke];
    }

  cairo.operator = CAIRO_OPERATOR_OVER;

  [coastPaths release];
  [bridgePaths release];

  return [cairo autorelease];
}

SWCairo *
OsmRenderMapCached (NSArray *ways)
{
  SWCairo *result;
  SWSHA256 *hash;
  NSString *path;
  BOOL isDirectory;
  unsigned char byte;

  hash = [SWSHA256 new];

  [hash addBytes:&latMin length:sizeof (latMin)];
  [hash addBytes:&lonMin length:sizeof (lonMin)];
  [hash addBytes:&latMax length:sizeof (latMax)];
  [hash addBytes:&lonMax length:sizeof (lonMax)];
  [hash addBytes:&imageWidth length:sizeof (imageWidth)];
  [hash addBytes:&imageHeight length:sizeof (imageHeight)];
  [hash addBytes:&waterColor length:sizeof (waterColor)];
  [hash addBytes:&landColor length:sizeof (landColor)];
  [hash addBytes:&parkColor length:sizeof (parkColor)];

  if (waterInFront)
    {
      byte = 1;

      [hash addBytes:&byte length:1];
    }

  [hash finish];

  path = [@"/var/lib/osm/cached-images" stringByAppendingPathComponent:hash.stringForBase16Hash];

  if (!noCache
      && [[NSFileManager defaultManager] fileExistsAtPath:path
                                              isDirectory:&isDirectory]
      && !isDirectory)
    {
      return OsmRenderLoadImage (path);
    }

  if (!ways)
    return nil;

  result = OsmRenderMap (ways);

  if (!dummyRun)
    [result writeToPNG:path];

  [hash release];

  return result;
}

enum OsmRenderMode
{
  OSM_RENDER_BASE,
  OSM_RENDER_HOVER,
  OSM_RENDER_ACTIVE,
  OSM_RENDER_CALLOUT
};

SWCairo *
OsmRenderAreas (SWCairo *map, NSUInteger activeArea, enum OsmRenderMode renderMode)
{
  NSRect bounds;
  SWCairo *cairo;
  OsmRenderNeighborhood *neighborhood;
  NSUInteger i;
  NSPoint scale;

  SWFont *inactiveAreaLabelFont;
  SWFont *activeAreaLabelFont;
  SWFont *landmarkLabelFont;

  if (fontSize >= 11)
    {
      inactiveAreaLabelFont = [SWFont fontWithName:@"Arial" size:fontSize style:SWFontStyleBold];
      activeAreaLabelFont = [SWFont fontWithName:@"Arial" size:fontSize style:SWFontStyleBold];
      landmarkLabelFont = [SWFont fontWithName:@"Arial" size:fontSize style:SWFontStyleNormal];
    }
  else
    {
      inactiveAreaLabelFont = [SWFont fontWithName:@"Arial" size:fontSize style:SWFontStyleBold hintingStyle:SWHintingStyleLight];
      activeAreaLabelFont = [SWFont fontWithName:@"Arial" size:fontSize style:SWFontStyleBold hintingStyle:SWHintingStyleLight];
      landmarkLabelFont = [SWFont fontWithName:@"Arial" size:fontSize style:SWFontStyleNormal hintingStyle:SWHintingStyleLight];
    }

  scale = NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax));

  cairo = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                 format:CAIRO_FORMAT_RGB24];

  bounds = NSMakeRect (0, 0, imageWidth, imageHeight);

  [cairo setColor:landColor];
  [cairo addRectangle:bounds];
  [cairo fill];

  if (!waterInFront)
    {
      [cairo setSurface:map
                     at:NSMakePoint (0, 0)];
      [cairo paint];
    }

    {
      SWCairo *mask, *source;

      mask = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                    format:CAIRO_FORMAT_A8];
      source = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                      format:CAIRO_FORMAT_RGB24];

      for (neighborhood in neighborhoods)
        {
          [mask addPath:neighborhood->path
              withScale:scale
                 closed:YES];
        }

      [mask fill];

      cairo_set_operator ([mask cairo], CAIRO_OPERATOR_DEST_OUT);
      [mask setLineWidth:3.0f];

      i = 0;

      for (neighborhood in neighborhoods)
        {
          [mask addPath:neighborhood->path
              withScale:scale
                 closed:YES];
          [source addPath:neighborhood->path
                withScale:scale
                   closed:YES];

          switch (neighborhood->type)
            {
            case 2:  [source setColor:parkColor]; break;
            default: [source setColor:inactiveAreaColor];
            }

          switch (renderMode)
            {
            case OSM_RENDER_BASE:

              break;

            case OSM_RENDER_HOVER:

              if (i == activeArea)
                {
                  switch (neighborhood->type)
                    {
                    case 2:  [source setColor:hoverParkColor]; break;
                    default: [source setColor:hoverAreaColor]; break;
                    }
                }

              break;

            case OSM_RENDER_ACTIVE:
            case OSM_RENDER_CALLOUT:

              if (i == activeArea)
                [source setColor:activeAreaColor];

              break;

            default:

              ;
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

  if (waterInFront)
    {
      [cairo setSurface:map
                     at:NSMakePoint (0, 0)];
      [cairo paint];
    }

    {
      i = 0;

      for (neighborhood in neighborhoods)
        {
          SWFont *font;
          SWFontGlyph *glyph;
          SWCairo *textSurface;
          NSPoint textCenter;
          NSRect textRect;

          textCenter = neighborhood->center;
          OsmRenderTransformPoint (&textCenter);

          if (neighborhood->type == 2)
            {
              [cairo setSurface:treeIcon
                             at:NSMakePoint (textCenter.x - round (treeIcon.size.width * 0.5),
                                             textCenter.y - round (treeIcon.size.height * 0.5))];
              [cairo paint];

              i++;

              continue;
            }

          if (i == activeArea)
            font = activeAreaLabelFont;
          else
            font = inactiveAreaLabelFont;

          glyph = [font glyphForLines:[neighborhood->name componentsSeparatedByString:@"\n"]];

          textSurface = [[SWCairo alloc] initWithFontGlyph:glyph];

          textRect = NSMakeRect (textCenter.x - glyph->width * 0.5,
                                 textCenter.y - glyph->height * 0.5,
                                 glyph->width, glyph->height);

          if (textRect.origin.x < 2)
            textRect.origin.x = 2;

          if (textRect.origin.y < 2)
            textRect.origin.y = 2;

          if (NSMaxX (textRect) > imageWidth - 2)
            textRect.origin.x = imageWidth - textRect.size.width - 2;

          if (NSMaxY (textRect) > imageHeight - 2)
            textRect.origin.y = imageHeight - textRect.size.height - 2;

          textRect = NSIntegralRect (textRect);

          if (i == activeArea && renderMode == OSM_RENDER_HOVER)
            {
              NSRect backgroundRect;

              backgroundRect = NSInsetRect (textRect, -3.0, -3.0);

              [cairo addRectangle:backgroundRect
                           radius:4];
              [cairo setColor:activeAreaLabelBackgroundColor];
              [cairo fill];

              [cairo setColor:activeAreaLabelColor];
              [cairo maskSurface:textSurface
                              at:textRect.origin];
            }
          else
            {
              [cairo setColor:inactiveAreaLabelColor];
              [cairo maskSurface:textSurface
                              at:textRect.origin];
            }


          [textSurface release];

          i++;
        }

      /* Add landmarks */

      for (NSDictionary *landmark in landmarks)
        {
          SWFontGlyph *glyph;
          SWCairo *textSurface;
          NSPoint position;

          if (![[landmark objectForKey:@"display"] boolValue])
            continue;

          position.x = [[landmark objectForKey:@"lon"] doubleValue];
          position.y = [[landmark objectForKey:@"lat"] doubleValue];

          OsmRenderTransformPoint (&position);

          glyph = [landmarkLabelFont glyphForLines:[[landmark objectForKey:@"label"] componentsSeparatedByString:@"\n"]];

          textSurface = [[SWCairo alloc] initWithFontGlyph:glyph];

          [cairo setColor:landmarkLabelColor];
          cairo_mask_surface (cairo.cairo, textSurface.surface,
                              position.x + landmarkBulletSize, position.y - glyph->height / 2);

          [textSurface release];


          [cairo addRectangle:NSMakeRect (position.x - landmarkBulletSize / 2,
                                          position.y - landmarkBulletSize / 2,
                                          landmarkBulletSize, landmarkBulletSize)];
          [cairo setColor:landmarkBulletColor];
          [cairo fill];
        }
    }

  return [cairo autorelease];
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

  if (areaBox.count != 4)
    errx (EXIT_FAILURE, "%s: areaBox is not exactly 4 elements",
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
      NSArray *center;

      neighborhood = [OsmRenderNeighborhood new];
      neighborhood->path = [SWPath new];

      for (vertex in [(NSString *)[area objectForKey:@"polygon"] componentsSeparatedByString:@","])
        {
          sscanf ([vertex UTF8String], "%lf %lf", &point.y, &point.x);

          [neighborhood->path addPoint:point];
        }

      [neighborhood->path translate:NSMakePoint (-lonMin, -latMax)];

      neighborhood->name = [[area objectForKey:@"label"] retain];

      center = [area objectForKey:@"center"];

      if (center.count != 2)
        errx (EXIT_FAILURE, "%s: area \"%s\" center point is %ld elements instead of 2", [path UTF8String], [neighborhood->name UTF8String], center.count);

      neighborhood->center.x = [[center objectAtIndex:1] doubleValue];
      neighborhood->center.y = [[center objectAtIndex:0] doubleValue];

      neighborhood->type = [[area objectForKey:@"type"] intValue];

      [neighborhoods addObject:neighborhood];
      [neighborhood release];
    }

  landmarks = [[config objectForKey:@"landmarks"] retain];
}

NSMutableArray *
OsmRenderFindMapFiles (NSRect geoBounds)
{
  NSAutoreleasePool *pool;
  NSMutableArray *result;
  SWDirectoryEnumerator *direnum;
  NSString *path;

  result = [NSMutableArray array];

  pool = [NSAutoreleasePool new];

  direnum = [[NSFileManager defaultManager] nonRecursiveEnumeratorAtPath:mapDataPath];

  while (0 != (path = [direnum nextObject]))
    {
      NSString *fullPath;
      MapData *mapData;
      NSRect mapBounds;
      NSRange range;

      if (path.length < 8)
        continue;

      range = [path rangeOfString:@".osm.pbf"
                          options:NSLiteralSearch
			    range:NSMakeRange (path.length - 8, 8)];

      if (range.location == NSNotFound)
        continue;

      fullPath = [mapDataPath stringByAppendingPathComponent:path];

      mapData = [[MapData alloc] initWithPath:fullPath];

      mapBounds = mapData.bounds;

      [mapData release];

      if (NSContainsRect (mapBounds, geoBounds))
        {
          [result addObject:fullPath];
        }
    }

  [pool release];

  return result;
}

static NSMutableArray *mapFilePaths;

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

          activeAreaLabelFontName = [NSString stringWithUTF8String:optarg];

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

          inactiveAreaLabelFontName = [NSString stringWithUTF8String:optarg];

          break;

        case 'd':

          inactiveAreaLabelColor = strtol (optarg, 0, 0);

          break;

        case 'E':

          inactiveAreaColor = strtol (optarg, 0, 0);

          break;

        case 'F':

          landmarkLabelFontName = [NSString stringWithUTF8String:optarg];

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

        case 'L':

          hoverAreaColor = strtol (optarg, 0, 0);

          break;

        case 'M':

          hoverParkColor = strtol (optarg, 0, 0);

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

        case 'n':

          mapFilePaths = [NSMutableArray arrayWithObject:[NSString stringWithUTF8String:optarg]];

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
              "      --dummy-run            do not render the map backdrop\n"
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

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool;
  MapData *mapData;
  SWCairo *mapSurface;
  SWCairo *baseSurface;
  NSArray *ways = nil;
  NSRect geoBounds;
  NSUInteger i;

  NSMutableArray *images;

  pool = [[NSAutoreleasePool alloc] init];

  OsmRenderParseOptions (argc, argv);

  if (optind + 1 != argc)
    errx (EX_USAGE, "Usage: %s [OPTION]... <FILE>", argv[0]);

  treeIcon = OsmRenderLoadImage (@"park.png");

  OsmRenderLoadNeighborhoods ([NSString stringWithUTF8String:argv[optind]]);

  geoBounds = NSMakeRect (lonMin, latMin, lonMax - lonMin, latMax - latMin);

  mapSurface = OsmRenderMapCached (nil);

  if (!mapSurface)
    {
      if (!mapFilePaths)
        mapFilePaths = OsmRenderFindMapFiles (geoBounds);

      if (verbose)
        NSLog (@"Map file paths: %@", mapFilePaths);

      for (NSString *mapFilePath in mapFilePaths)
        {
          if (!(mapData = [[MapData alloc] initWithPath:mapFilePath]))
            errx (EXIT_FAILURE, "Failed to load map data");

          if (!dummyRun)
            {
              if (verbose)
                NSLog (@"Looking for ways");

              ways = [mapData waysInRect:geoBounds];

              if (verbose)
                NSLog (@"Got %lu ways", ways.count);

              if (!ways.count)
                {
                  [mapData release];

                  continue;
                }
            }
          else
            ways = [NSArray array];

          for (MapWay *way in ways)
            [way.path translate:NSMakePoint (-lonMin, -latMax)];

          mapSurface = OsmRenderMapCached (ways);

          break;
        }
    }

  images = [[NSMutableArray alloc] init];

  baseSurface = OsmRenderAreas (mapSurface, 0, OSM_RENDER_BASE);
  [images addObject:baseSurface];

  for (i = 0; i < [neighborhoods count]; ++i)
    {
      [images addObject:[OsmRenderAreas (mapSurface, i, OSM_RENDER_HOVER) surfaceWithDifferencesFromSurface:baseSurface]];
      [images addObject:[OsmRenderAreas (mapSurface, i, OSM_RENDER_ACTIVE) surfaceWithDifferencesFromSurface:baseSurface]];
    }

  [[SWCairo atlasFromSurfaces:images] writeToPNG:[NSString stringWithFormat:@"%@.png", prefix]];

  imageWidth = 290, imageHeight = 290;
  fontSize = 10;
  landmarkBulletSize = 5;

  mapSurface = OsmRenderMapCached (ways);

  if (!mapSurface)
    {
      if (!dummyRun)
        ways = [mapData waysInRect:geoBounds];
      else
        ways = [NSArray array];

      for (MapWay *way in ways)
        [way.path translate:NSMakePoint (-lonMin, -latMax)];

      mapSurface = OsmRenderMapCached (ways);
    }

  for (i = 0; i < [neighborhoods count]; ++i)
    {
      NSString *pathCallout;
      SWCairo *areaSurface;

      pathCallout = [NSString stringWithFormat:@"%@-%02lu-callout.png", prefix, (unsigned long) i];

      areaSurface = OsmRenderAreas (mapSurface, i, OSM_RENDER_CALLOUT);

      [areaSurface writeToPNG:[NSString stringWithFormat:@"%@-%02lu-callout.png", prefix, (unsigned long) i]];
    }

  [pool release];

  return EXIT_SUCCESS;
}
