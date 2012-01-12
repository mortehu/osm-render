#import <Foundation/NSData.h>

@interface NSData (SWZlib)
+ (id)dataWithZlibBytes:(const void *)bytes
                 length:(NSUInteger)length;

+ (id)dataWithZlibData:(NSData *)data;

- (id)initWithZlibBytes:(const void *)bytes
                 length:(NSUInteger)length;

- (id)initWithZlibData:(NSData *)data;
@end
