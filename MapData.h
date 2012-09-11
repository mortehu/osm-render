#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@class NSDictionary;
@class NSMutableArray;
@class SWPath;

@interface MapWay : NSObject
{
  SWPath *path;
  NSMutableDictionary *tags;
}

@property (nonatomic,readonly) SWPath *path;
@property (nonatomic,readonly) NSMutableDictionary *tags;

- (id)initWithPath:(SWPath *)path
              tags:(NSMutableDictionary *)tags;
@end

@interface MapData : NSObject
{
  NSData *fileData;
  NSMutableDictionary *nodes;
}

- (id)initWithPath:(NSString *)path;

- (NSRect)bounds;

- (NSArray *)waysInRect:(NSRect)rect
         matchingFilter:(BOOL (^)(NSMutableDictionary *tags))filter;
@end
