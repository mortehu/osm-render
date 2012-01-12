#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Swanston/SWPath.h>

static void
ClipLineToHorizontalLine (const NSPoint *inside, NSPoint *outside, double y)
{
  if (inside->y < y)
    {
      if (outside->y <= y)
        return;
    }
  else if (inside->y > y)
    {
      if (outside->y >= y)
        return;
    }

  outside->x += ((y - outside->y) / (inside->y - outside->y)) * (inside->x - outside->x);
  outside->y = y;
}

static void
ClipLineToVerticalLine (const NSPoint *inside, NSPoint *outside, double x)
{
  if (inside->x < x)
    {
      if (outside->x <= x)
        return;
    }
  else if (inside->x > x)
    {
      if (outside->x >= x)
        return;
    }

  outside->y += ((x - outside->x) / (inside->x - outside->x)) * (inside->y - outside->y);
  outside->x = x;
}

static void
ClipLineToRect (const NSPoint* inside, NSPoint* outside, NSRect rect)
{
  assert (NSPointInRect (*inside, rect));
  assert (!NSPointInRect (*outside, rect));
  ClipLineToHorizontalLine (inside, outside, rect.origin.y);
  ClipLineToHorizontalLine (inside, outside, rect.origin.y + rect.size.height);
  ClipLineToVerticalLine (inside, outside, rect.origin.x);
  ClipLineToVerticalLine (inside, outside, rect.origin.x + rect.size.width);
}

@implementation SWPath : NSObject
- (id)initWithPoints:(NSPoint *)points_
              length:(NSUInteger)length_
{
  if (!(self = [super init]))
    return nil;

  length = length_;

  if (!(points_ = calloc (length, sizeof (*points))))
    {
      [self release];

      return nil;
    }

  return self;
}

- (id)initWithPointsNoCopy:(NSPoint *)points_
                    length:(NSUInteger)length_
{
  if (!(self = [super init]))
    return nil;

  points = points_;
  length = length_;

  return self;
}

- (void)addPoint:(NSPoint)point
{
  NSPoint *newPoints;

  if (!(newPoints = realloc (points, sizeof (*points) * (length + 1))))
    {
      [NSException raise:NSMallocException
                  format:@"Failed to allocate memory for new point: %s", strerror (errno)];
    }

  points = newPoints;

  points[length++] = point;
}

- (void)addPointsFromPath:(SWPath *)path
{
  NSPoint *newPoints;

  if (!(newPoints = realloc (points, sizeof (*points) * (length + path.length))))
    {
      [NSException raise:NSMallocException
                  format:@"Failed to allocate memory for new point: %s", strerror (errno)];
    }

  points = newPoints;

  memcpy (points + length, path.points, path.length * sizeof (*points));

  length += path.length;
}

- (void)removeAllPoints
{
  length = 0;
}

- (NSPoint *)points
{
  return points;
}

- (NSUInteger)length
{
  return length;
}

- (NSPoint)firstPoint
{
  return points[0];
}

- (NSPoint)lastPoint
{
  return points[length - 1];
}

- (BOOL)isCyclic
{
  return NSEqualPoints (points[0], points[length - 1]);
}

- (void)translate:(NSPoint)offset
{
  NSUInteger i;

  for (i = 0; i < length; ++i)
    {
      points[i].x += offset.x;
      points[i].y += offset.y;
    }
}

- (void)scale:(NSPoint)scale
{
  NSUInteger i;

  for (i = 0; i < length; ++i)
    {
      points[i].x *= scale.x;
      points[i].y *= scale.y;
    }
}


- (NSArray *)clipToRect:(NSRect)bounds
{
  NSPoint clippedPoint;
  NSMutableArray *result;
  SWPath *output;
  BOOL *inside, allInside = YES, allOutside = YES;
  NSUInteger i;

  inside = calloc (length, sizeof (*inside));

  for (i = 0; i < length; ++i)
    {
      inside[i] = NSPointInRect (points[i], bounds);

      allInside = (allInside && inside[i]);
      allOutside = (allOutside && !inside[i]);
    }

  if (allInside)
    return [NSArray arrayWithObject:self];

  if (allOutside)
    return [NSArray array];

  result = [[[NSMutableArray alloc] init] autorelease];
  output = nil;

  for (i = 0; i < length; ++i)
    {
      if (!inside[i])
        {
          if (!output)
            continue;

          clippedPoint = points[i];

          ClipLineToRect (&points[i - 1], &clippedPoint, bounds);

          [output addPoint:clippedPoint];

          if (output.length > 1)
            {
              [result addObject:output];

              output = nil;
            }
          else
            [output removeAllPoints];

          continue;
        }

      /* Current point inside */

      if (!output)
        {
          output = [[[SWPath alloc] init] autorelease];

          if (i > 0)
            {
              clippedPoint = points[i - 1];

              ClipLineToRect (&points[i], &clippedPoint, bounds);

              [output addPoint:clippedPoint];
            }
        }

      [output addPoint:points[i]];
    }

  if (output && output.length > 1)
    [result addObject:output];

  return result;
}
@end
