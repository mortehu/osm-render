#import <Foundation/NSString.h>
#import <Swanston/SWCairo.h>
#import <Swanston/SWPango.h>

@implementation SWPangoContext
@end

@implementation SWPangoLayout
+ (id)layoutWithContext:(SWPangoContext *)context
{
  return [[[self alloc] initWithContext:context] autorelease];
}

+ (id)layoutWithCairo:(SWCairo *)cairo
{
  return [[[self alloc] initWithCairo:cairo] autorelease];
}

- (id)init
{
  assert (!"not implemented");
}

- (id)initWithContext:(SWPangoContext *)context
{
  if (!(self = [super init]))
    return nil;

  /* XXX: Use `context.context' */
  layout = pango_layout_new (0);

  return self;
}

- (id)initWithCairo:(SWCairo *)cairo_
{
  if (!(self = [super init]))
    return nil;

  cairo = [cairo_ retain];
  layout = pango_cairo_create_layout (cairo.cairo);

  return self;
}

- (void)dealloc
{
  g_object_unref (layout);
  [cairo release];
  [super dealloc];
}

- (void)setFontFromString:(NSString *)text
{
  PangoFontDescription *fontDescription;

  fontDescription = pango_font_description_from_string ([text UTF8String]);
  pango_layout_set_font_description (layout, fontDescription);
  pango_font_description_free (fontDescription);
}

- (void)setText:(NSString *)text
{
  pango_layout_set_text (layout, [text UTF8String], [text length]);
}

- (NSSize)size
{
  int width, height;

  pango_layout_get_size (layout, &width, &height);

  return NSMakeSize ((double) width / PANGO_SCALE, (double) height / PANGO_SCALE);
}

- (void)paint
{
  pango_cairo_update_layout (cairo.cairo, layout);
  pango_cairo_show_layout (cairo.cairo, layout);
}
@end
