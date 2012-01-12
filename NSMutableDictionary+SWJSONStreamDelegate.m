#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Swanston/NSMutableArray+SWJSONStreamDelegate.h>
#import <Swanston/NSMutableDictionary+SWJSONStreamDelegate.h>

@implementation NSMutableDictionary (SWJSONStreamDelegate)
- (id)parseObjectWithName:(const char *)name
{
  NSMutableDictionary *newDictionary;

  newDictionary = [[NSMutableDictionary alloc] init];

  [self setValue:newDictionary forKey:[NSString stringWithUTF8String:name]];

  return [newDictionary autorelease];
}

- (id)parseArrayWithName:(const char *)name
{
  NSMutableArray *newArray;

  newArray = [[NSMutableArray alloc] init];

  [self setValue:newArray forKey:[NSString stringWithUTF8String:name]];

  return [newArray autorelease];
}

- (void)parseStringWithName:(const char *)name value:(const char *)value
{
  [self setValue:[NSString stringWithUTF8String:value]
          forKey:[NSString stringWithUTF8String:name]];
}

- (void)parseNumberWithName:(const char *)name value:(double)value
{
  [self setValue:[NSNumber numberWithDouble:value] forKey:[NSString stringWithUTF8String:name]];
}

- (void)parseBooleanWithName:(const char *)name value:(BOOL)value
{
  [self setValue:[NSNumber numberWithBool:value] forKey:[NSString stringWithUTF8String:name]];
}

- (void)parseNullWithName:(const char *)name
{
  [self setValue:[NSNull null] forKey:[NSString stringWithUTF8String:name]];
}
@end
