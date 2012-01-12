#import <Foundation/NSObject.h>

@class NSMutableDictionary;

@interface SWIndexSet : NSObject
{
  NSMutableDictionary *data;
  NSUInteger count;
}

+ (id)indexSet;

- (id)init;

- (void)addIndex:(NSUInteger)index;
- (void)addIndexes:(SWIndexSet *)indexSet;

- (BOOL)containsIndex:(NSUInteger)index;
- (NSUInteger)count;
@end
