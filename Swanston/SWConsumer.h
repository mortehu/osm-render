#import <Foundation/NSData.h>
#import <Foundation/NSError.h>
#import <Foundation/NSFileHandle.h>

@protocol SWConsumer
- (void)consumeData:(NSData *)data;
- (void)consumeError:(NSError *)error;
- (void)consumeEnd;
@end

@protocol SWChokable
- (BOOL)choked;

- (NSUInteger)maxPayload;
@end

@interface NSFileHandle (SWConsumerAddons)
- (void)readToConsumer:(id<SWConsumer>)consumer;
@end
