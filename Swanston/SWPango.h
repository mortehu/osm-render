#import <Foundation/NSObject.h>

#import <pango/pangocairo.h>

@class SWCairo;
@class NSString;

@interface SWPangoContext : NSObject
@end

@interface SWPangoLayout : NSObject
{
  PangoLayout *layout;
  SWCairo *cairo;
}

+ (id)layoutWithContext:(SWPangoContext *)context;
+ (id)layoutWithCairo:(SWCairo *)cairo;

- (id)initWithContext:(SWPangoContext *)context;
- (id)initWithCairo:(SWCairo *)cairo;

- (void)setFontFromString:(NSString *)text;

- (void)setText:(NSString *)text;

- (NSSize)size;

- (void)paint;
@end
