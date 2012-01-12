#import <Foundation/Foundation.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWPath.h>

#import <assert.h>
#import <err.h>
#import <fcntl.h>
#import <math.h>
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>

#import <cairo/cairo.h>

#import <MapData.h>

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
      if ([discardedPaths containsIndex:i])
        continue;

      pathA = [paths objectAtIndex:i];

      for (j = 0; j < count; ++j)
        {
          if (j == i || [discardedPaths containsIndex:j])
            continue;

          pathB = [paths objectAtIndex:j];

          if (NSEqualPoints (pathA.points[pathA.length - 1], pathB.points[0]))
            {
              [pathA addPointsFromPath:pathB];

              [discardedPaths addIndex:j];
            }
        }
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

  /* Add ponds and such */

  for (way in ways)
    {
      NSString *natural;

      natural = [way.tags objectForKey:@"natural"];

      if (!natural || ![natural isEqualToString:@"water"])
        continue;

      [way.path translate:NSMakePoint (-lonMin, -latMax)];
      [way.path scale:NSMakePoint (imageWidth / (lonMax - lonMin), imageHeight / (latMin - latMax))];

      [cairo addPath:way.path];
    }

  [cairo setColor:0xffafbfdd];
  [cairo fill];

  [cairo writeToPNG:@"output.png"];
  [cairo release];
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool;
  MapData *mapData;
  NSArray *ways;

  pool = [[NSAutoreleasePool alloc] init];

#if 1
  lonMin = -74.0475082397461;
  lonMax = -73.927001953125;
  latMin = 40.693134153308094;
  latMax = 40.80809251416925;
#else
  latMin = 40.7037000;
  lonMin = -74.0520000;
  latMax = 40.7668000;
  lonMax = -73.9046000;
#endif

  if (!(mapData = [[MapData alloc] init]))
    errx (EXIT_FAILURE, "Failed to load map data");

  ways = [mapData waysInRect:NSMakeRect (lonMin, latMin, lonMax - lonMin, latMax - latMin)];

  NSLog (@"Got %lu ways", [ways count]);

  osm_paint (ways);

  [pool release];

  return EXIT_SUCCESS;
}
