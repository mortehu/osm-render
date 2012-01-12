#import <Foundation/NSData.h>

@interface NSData (SWZlib)
+ (id)dataWithZlibData:(NSData *)data;
- (id)initWithZlibData:(NSData *)data;
@end
