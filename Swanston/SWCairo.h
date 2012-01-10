#import <Foundation/NSGeometry.h>
#import <Foundation/NSObject.h>
#import <cairo/cairo.h>

@class SWPath;

@interface SWCairo : NSObject
{
  cairo_t *cairo;
  cairo_surface_t *surface;
}

- (id)initWithSize:(NSSize)size
            format:(cairo_format_t)format;

- (void)addPath:(SWPath *)path;

- (void)setColor:(uint32_t)argb;

- (void)setLineWidth:(float)width;

- (void)stroke;

- (void)writeToPNG:(NSString *)path;
@end
