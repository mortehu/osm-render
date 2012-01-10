#include <assert.h>
#include <err.h>
#include <fcntl.h>
#include <math.h>
#include <stdlib.h>
#include <unistd.h>

#include <cairo/cairo.h>

#include "osm.h"

void
osm_paint (void)
{
  cairo_surface_t *surface;
  cairo_t* cr;

  surface = cairo_image_surface_create (CAIRO_FORMAT_RGB24, 400, 400);
  cr = cairo_create (surface);

#if 1
  cairo_set_line_width (cr, 6);

  cairo_rectangle (cr, 12, 12, 232, 70);
  cairo_new_sub_path (cr); cairo_arc (cr, 64, 64, 40, 0, 2*M_PI);
  cairo_new_sub_path (cr); cairo_arc_negative (cr, 192, 64, 40, 0, -2*M_PI);

  cairo_set_fill_rule (cr, CAIRO_FILL_RULE_EVEN_ODD);
  cairo_set_source_rgb (cr, 0, 0.7, 0); cairo_fill_preserve (cr);
  cairo_set_source_rgb (cr, 0, 0, 0); cairo_stroke (cr);

  cairo_translate (cr, 0, 128);
  cairo_rectangle (cr, 12, 12, 232, 70);
  cairo_new_sub_path (cr); cairo_arc (cr, 64, 64, 40, 0, 2*M_PI);
  cairo_new_sub_path (cr); cairo_arc_negative (cr, 192, 64, 40, 0, -2*M_PI);

  cairo_set_fill_rule (cr, CAIRO_FILL_RULE_WINDING);
  cairo_set_source_rgb (cr, 0, 0, 0.9); cairo_fill_preserve (cr);
  cairo_set_source_rgb (cr, 0, 0, 0); cairo_stroke (cr);
#endif

  cairo_destroy (cr);

  cairo_surface_write_to_png (surface, "output.png");
  cairo_surface_destroy (surface);
}

int
main (int argc, char **argv)
{
  int fd;

  if (-1 == (fd = open ("new-york.osm", O_RDONLY)))
    err (EXIT_FAILURE, "Failed to open 'new-york.osm' for reading");

  osm_parse (fd);

  close (fd);

  osm_paint ();

  return EXIT_SUCCESS;
}
