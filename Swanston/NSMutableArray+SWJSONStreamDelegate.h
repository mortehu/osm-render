#import <Foundation/NSArray.h>
#import <Swanston/SWJSONStream.h>

@interface NSMutableArray (SWJSONStreamDelegate)
- (id)parseObjectWithName:(const char *)name;

- (id)parseArrayWithName:(const char *)name;

- (void)parseStringWithName:(const char *)name value:(const char *)value;

- (void)parseNumberWithName:(const char *)name value:(double)value;

- (void)parseBooleanWithName:(const char *)name value:(BOOL)value;

- (void)parseNullWithName:(const char *)name;
@end
