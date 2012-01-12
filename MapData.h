#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@class NSDictionary;
@class NSMutableArray;
@class SWPath;

@interface MapWay : NSObject
{
  SWPath *path;
  NSDictionary *tags;
}

@property (nonatomic,readonly) SWPath *path;
@property (nonatomic,readonly) NSDictionary *tags;

- (id)initWithPath:(SWPath *)path
              tags:(NSDictionary *)tags;
@end

@interface MapData : NSObject
{
  NSData *fileData;
  NSMutableDictionary *nodes;
}

- (NSArray *)waysInRect:(NSRect)rect;
@end
