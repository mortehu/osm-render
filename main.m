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

#import "osm.h"

static double lonMin, lonMax;
static double latMin, latMax;
static unsigned int imageWidth = 1024, imageHeight = 1024;

static double lonScale, lonOffset;
static double latScale, latOffset;

double
ClockwiseBoxDistance (NSPoint from, NSPoint to, NSRect bounds)
{
  return 0.0;
}

void
MergeCoastPaths (NSMutableArray *paths, NSRect bounds)
{
  SWPath *pathA, *pathB;
  NSMutableIndexSet *discardedPaths;
  NSUInteger i, j, count;

  NSLog (@"Before: %lu", [paths count]);

  discardedPaths = [NSMutableIndexSet indexSet];

  count = [paths count];

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

      if ((begin.x > bounds.origin.x && begin.y > bounds.origin.y
           && begin.x < bounds.origin.x + bounds.size.width
           && begin.y < bounds.origin.y + bounds.size.height)
          || (end.x > bounds.origin.x && end.y > bounds.origin.y
              && end.x < bounds.origin.x + bounds.size.width
              && end.y < bounds.origin.y + bounds.size.height))
        {
          [discardedPaths addIndex:i];
        }
    }

  [paths removeObjectsAtIndexes:discardedPaths];
  count = [paths count];

  for (i = 0; i < count; ++i)
    {
      pathA = [paths objectAtIndex:i];

      if (NSEqualPoints (pathA.points[0], pathA.points[pathA.length - 1]))
        {
          NSLog (@"Hepp");

          continue;
        }

      NSLog (@"%.2f %.2f   %.2f %.2f",
             pathA.points[0].x, pathA.points[0].y,
             pathA.points[1].x, pathA.points[1].y);
    }
}

void
osm_paint (void)
{
  NSRect bounds;
  NSMutableArray *coastPaths;
  SWCairo *cairo;
  SWPath *path;
  size_t j;

  coastPaths = [[NSMutableArray alloc] init];

  cairo = [[SWCairo alloc] initWithSize:NSMakeSize (imageWidth, imageHeight)
                                 format:CAIRO_FORMAT_RGB24];

  bounds = NSMakeRect (342, 342, 342, 342);

  for (j = 0; j < way_count; ++j)
    {
      NSPoint *points;
      NSArray *clippedPaths;

      const struct osm_way *way;
      size_t i;

      way = &ways[j];

      if (way->natural != OSM_NATURAL_COASTLINE
          /*&& way->natural != OSM_NATURAL_WATER*/)
        continue;

      points = calloc (way->node_count, sizeof (*points));

      for (i = 0; i < way->node_count; ++i)
        {
          points[i].x = imageWidth / 2 + (nodes[node_refs[way->first_node + i]].lon + lonOffset) * lonScale;
          points[i].y = imageHeight / 2 - (nodes[node_refs[way->first_node + i]].lat + latOffset) * latScale;
        }

      path = [[SWPath alloc] initWithPointsNoCopy:points
                                           length:way->node_count];

      clippedPaths = [path clipToRect:bounds];

      if (clippedPaths)
        [coastPaths addObjectsFromArray:clippedPaths];

      [path release];

    }

  MergeCoastPaths (coastPaths, bounds);

  for (path in coastPaths)
    {
      [cairo addPath:path];
      [cairo setColor:0xffafbfdd ^ (rand () & 0xffffff)];
      [cairo setLineWidth:2.0f];
      [cairo stroke];
    }
#if 0
      if (node_refs[way->first_node] == node_refs[way->first_node + way->node_count - 1])
        {
          cairo_move_to (cr,
                         imageWidth / 2 + (nodes[node_refs[way->first_node]].lon + lonOffset) * lonScale,
                         imageHeight / 2 - (nodes[node_refs[way->first_node]].lat + latOffset) * latScale);

          for (i = 1; i < way->node_count; ++i)
            {
              cairo_line_to (cr,
                             imageWidth / 2 + (nodes[node_refs[way->first_node + i]].lon + lonOffset) * lonScale,
                             imageHeight / 2 - (nodes[node_refs[way->first_node + i]].lat + latOffset) * latScale);
            }

          cairo_close_path (cr);
          cairo_set_source_rgb (cr, 0xaf / 255.0f, 0xbf / 255.0f, 0xdd / 255.0f);
          cairo_fill_preserve (cr);
          /*
          cairo_set_line_width (cr, 2.0f);
          cairo_stroke (cr);
          */
        }
      else
        {
          cairo_move_to (cr,
                         imageWidth / 2 + (nodes[node_refs[way->first_node]].lon + lonOffset) * lonScale,
                         imageHeight / 2 - (nodes[node_refs[way->first_node]].lat + latOffset) * latScale);

          for (i = 1; i < way->node_count; ++i)
            {
              cairo_line_to (cr,
                             imageWidth / 2 + (nodes[node_refs[way->first_node + i]].lon + lonOffset) * lonScale,
                             imageHeight / 2 - (nodes[node_refs[way->first_node + i]].lat + latOffset) * latScale);
            }

          cairo_set_source_rgb (cr, 1.0f, 0.0f, 0.0f);
          cairo_set_line_width (cr, 2.0f);
          cairo_stroke (cr);
        }
#endif

  [cairo writeToPNG:@"output.png"];
  [cairo release];
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool;
  int fd;

  pool = [[NSAutoreleasePool alloc] init];

  if (-1 == (fd = open ("new-york.osm", O_RDONLY)))
    err (EXIT_FAILURE, "Failed to open 'new-york.osm' for reading");

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

  latOffset = -(latMin + latMax) * 0.5;
  lonOffset = -(lonMin + lonMax) * 0.5;

  latScale = imageHeight / (latMax - latMin);
  lonScale = imageWidth / (lonMax - lonMin);

  latScale *= 0.3;
  lonScale *= 0.3;

  osm_parse (fd);

  close (fd);

  osm_paint ();

  [pool release];

  return EXIT_SUCCESS;
}
