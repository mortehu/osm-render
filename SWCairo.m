#import <Foundation/NSString.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWPath.h>

@implementation SWCairo
@synthesize cairo, surface;

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

- (void)translateX:(double)x
                 y:(double)y
{
  cairo_translate (cairo, x, y);
}

- (void)scaleX:(double)x
             y:(double)y
{
  cairo_scale (cairo, x, y);
}

- (void)addPath:(SWPath *)path
{
  [self addPath:path
         closed:NO];
}

- (void)addPath:(SWPath *)path
         closed:(BOOL)closed
{
  NSUInteger length, i;
  const NSPoint *points;

  length = path.length;

  if (!length)
    return;

  points = path.points;

  cairo_move_to (cairo, points[0].x, points[0].y);

  for (i = 1; i + 1 < length; ++i)
    cairo_line_to (cairo, points[i].x, points[i].y);

  if (NSEqualPoints (points[0], points[i]))
    cairo_close_path (cairo);
  else
    {
      cairo_line_to (cairo, points[i].x, points[i].y);

      if (closed)
        cairo_close_path (cairo);
    }
}

- (void)addRectangle:(NSRect)rect
{
  cairo_rectangle (cairo, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

- (void)addRectangle:(NSRect)rect
              radius:(double)radius
{
  double x, y;
  double width, height;

  x = rect.origin.x;
  y = rect.origin.y;
  width = rect.size.width;
  height = rect.size.height;

  cairo_move_to  (cairo, x + radius, y);
  cairo_line_to  (cairo, x + width - radius, y);
  cairo_curve_to (cairo, x + width, y, x + width, y, x + width, y + radius);
  cairo_line_to  (cairo, x + width, y + height - radius);
  cairo_curve_to (cairo, x + width, y + height, x + width, y + height, x + width - radius, y + height);
  cairo_line_to  (cairo, x + radius, y + height);
  cairo_curve_to (cairo, x, y + height, x, y + height, x, y + height - radius);
  cairo_line_to  (cairo, x, y + radius);
  cairo_curve_to (cairo, x, y, x, y, x + radius, y);
  cairo_close_path (cairo);
}

- (void)setColor:(uint32_t)argb
{
  cairo_set_source_rgba (cairo,
                        ((argb >> 16) & 0xff) / 255.0f,
                        ((argb >> 8) & 0xff) / 255.0f,
                        (argb & 0xff) / 255.0f,
                        (argb >> 24) / 255.0f);
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

- (void)fill
{
  cairo_fill (cairo);
}

- (void)writeToPNG:(NSString *)path
{
  cairo_destroy (cairo);
  cairo = 0;
  cairo_surface_write_to_png (surface, [path fileSystemRepresentation]);
}
@end
