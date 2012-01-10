#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@interface SWPath : NSObject
{
  NSPoint *points;
  NSUInteger length;
}

- (id)initWithPoints:(NSPoint *)points
              length:(NSUInteger)length;

- (id)initWithPointsNoCopy:(NSPoint *)points
                    length:(NSUInteger)length;

- (void)addPoint:(NSPoint)point;
- (void)addPointsFromPath:(SWPath *)path;
- (void)removeAllPoints;

- (NSPoint *)points;
- (NSUInteger)length;

- (NSArray *)clipToRect:(NSRect)bounds;
@end
