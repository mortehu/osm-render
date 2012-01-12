#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>
#import <Foundation/NSValue.h>
#import <Swanston/SWIndexSet.h>

static const uint8_t SWIndexSetBitsSetLUT[256] = 
{
#   define B2(n) n,     n+1,     n+1,     n+2
#   define B4(n) B2(n), B2(n+1), B2(n+1), B2(n+2)
#   define B6(n) B4(n), B4(n+1), B4(n+1), B4(n+2)
      B6(0), B6(1), B6(1), B6(2)
};

@implementation SWIndexSet
+ (id)indexSet
{
  return [[[self alloc] init] autorelease];
}

- (id)init
{
  if (!(self = [super init]))
    return nil;

  if (!(data = [NSMutableDictionary new]))
    {
      [self release];

      return nil;
    }

  return self;
}

- (void)addIndex:(NSUInteger)index
{
  NSUInteger groupIndex, groupOffset;
  NSNumber *groupKey;
  NSMutableData *group;
  uint8_t *bytes;

  groupIndex = (index >> 16);
  groupOffset = index & 0xffff;

  groupKey = [NSNumber numberWithUnsignedInteger:groupIndex];

  if (!(group = [data objectForKey:groupKey]))
    {
      group = [NSMutableData dataWithLength:(65536 / CHAR_BIT)];

      [data setObject:group
               forKey:groupKey];
    }

  bytes = [group mutableBytes];

  if (bytes[groupOffset >> 3] & (1 << (groupOffset & 7)))
    return;

  bytes[groupOffset >> 3] |= 1 << (groupOffset & 7);
  count++;
}

- (void)addIndexes:(SWIndexSet *)indexSet
{
  NSArray *groupKeys;
  NSNumber *groupKey;
  NSMutableData *myGroup, *otherGroup;
  uint8_t *myBytes;
  const uint8_t *otherBytes;
  NSUInteger i;

  groupKeys = [indexSet->data allKeys];

  for (groupKey in groupKeys)
    {
      otherGroup = [indexSet->data objectForKey:groupKey];

      if (!(myGroup = [data objectForKey:groupKey]))
        {
          myGroup = [NSMutableData dataWithLength:(65536 / CHAR_BIT)];

          [data setObject:myGroup
                   forKey:groupKey];
        }

      myBytes = [myGroup mutableBytes];
      otherBytes = [otherGroup bytes];

      for (i = 0; i < 65536 / CHAR_BIT; ++i)
        {
          count += SWIndexSetBitsSetLUT[(myBytes[i] ^ otherBytes[i]) & otherBytes[i]];

          myBytes[i] |= otherBytes[i];
        }
    }
}

- (BOOL)containsIndex:(NSUInteger)index
{
  NSUInteger groupIndex, groupOffset;
  NSNumber *groupKey;
  NSMutableData *group;
  uint8_t *bytes;

  groupIndex = (index >> 16);
  groupOffset = index & 0xffff;

  groupKey = [NSNumber numberWithUnsignedInteger:groupIndex];

  if (!(group = [data objectForKey:groupKey]))
    return NO;

  bytes = [group mutableBytes];

  return (bytes[groupOffset >> 3] & (1 << (groupOffset & 7)));
}

- (NSUInteger)count
{
  return count;
#if 0
  NSMutableData *group;
  NSUInteger result = 0;

  for (group in data)
    {
      const uint8_t *bytes;
      NSUInteger i;

      bytes = [group bytes];

      for (i = 0; i < 65536 / CHAR_BIT; ++i)
        result += SWIndexSetBitsSetLUT[bytes[i]];
    }

  return result;
#endif
}
@end
