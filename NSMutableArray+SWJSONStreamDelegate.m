#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Swanston/NSMutableArray+SWJSONStreamDelegate.h>
#import <Swanston/NSMutableDictionary+SWJSONStreamDelegate.h>

@implementation NSMutableArray (SWJSONStreamDelegate)
- (id)parseObjectWithName:(const char *)name
{
  NSMutableDictionary *newDictionary;

  newDictionary = [[NSMutableDictionary alloc] init];

  [self addObject:newDictionary];

  return [newDictionary autorelease];
}

- (id)parseArrayWithName:(const char *)name
{
  NSMutableArray *newArray;

  newArray = [[NSMutableArray alloc] init];

  [self addObject:newArray];

  return [newArray autorelease];
}

/* XXX: Add autorelease */

- (void)parseStringWithName:(const char *)name value:(const char *)value
{
  [self addObject:[NSString stringWithUTF8String:value]];
}

- (void)parseNumberWithName:(const char *)name value:(double)value
{
  [self addObject:[NSNumber numberWithDouble:value]];
}

- (void)parseBooleanWithName:(const char *)name value:(BOOL)value
{
  [self addObject:[NSNumber numberWithBool:value]];
}

- (void)parseNullWithName:(const char *)name
{
  [self addObject:[NSNull null]];
}
@end
