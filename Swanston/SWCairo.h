#import <Foundation/NSGeometry.h>
#import <Foundation/NSObject.h>
#import <cairo/cairo.h>

@class SWPath;

@interface SWCairo : NSObject
{
  cairo_t *cairo;
  cairo_surface_t *surface;
}

@property (nonatomic,readonly) cairo_t *cairo;
@property (nonatomic,readonly) cairo_surface_t *surface;

- (id)initWithSize:(NSSize)size
            format:(cairo_format_t)format;

- (void)translateX:(double)x y:(double)y;
- (void)scaleX:(double)x y:(double)y;

- (void)addPath:(SWPath *)path;
- (void)addPath:(SWPath *)path
         closed:(BOOL)closed;
- (void)addRectangle:(NSRect)rect;

- (void)setColor:(uint32_t)argb;

- (void)setLineWidth:(float)width;

- (void)stroke;
- (void)fill;

- (void)writeToPNG:(NSString *)path;
@end
