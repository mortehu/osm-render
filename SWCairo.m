#import <Foundation/NSString.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWPath.h>

@implementation SWCairo
- (id)initWithSize:(NSSize)size
            format:(cairo_format_t)format
{
  if (!(self = [super init]))
    return nil;

  surface = cairo_image_surface_create (format, size.width, size.height);
  cairo = cairo_create (surface);

  return self;
}

- (void)dealloc
{
  if (cairo)
    cairo_destroy (cairo);
  cairo_surface_destroy (surface);

  [super dealloc];
}

- (void)addPath:(SWPath *)path
{
  NSUInteger length, i;
  const NSPoint *points;

  length = path.length;

  if (!length)
    return;

  points = path.points;

  cairo_move_to (cairo, points[0].x, points[0].y);

  for (i = 1; i < length; ++i)
    cairo_line_to (cairo, points[i].x, points[i].y);
}

- (void)setColor:(uint32_t)argb
{
  cairo_set_source_rgb (cairo,
                        ((argb >> 16) & 0xff) / 255.0f,
                        ((argb >> 8) & 0xff) / 255.0f,
                        (argb & 0xff) / 255.0f);
}

- (void)setLineWidth:(float)width
{
  assert (width >= 0);

  cairo_set_line_width (cairo, width);
}

- (void)stroke
{
  cairo_stroke (cairo);
}

- (void)writeToPNG:(NSString *)path
{
  cairo_destroy (cairo);
  cairo = 0;
  cairo_surface_write_to_png (surface, [path fileSystemRepresentation]);
}
@end
