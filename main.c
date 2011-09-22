#if defined(GLES)
#  include <GLES2/gl2.h>
#else
#  include <GL/glew.h>
#  include <GL/gl.h>
#endif

#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <celsius/draw.h>
#include <celsius/error.h>
#include <celsius/font.h>
#include <celsius/input.h>
#include <celsius/texture.h>
#include <celsius/vector.h>
#include <celsius/var.h>

#include "osm.h"

static device_state *keyboard;
static device_state *mouse;

static int map_shader;

static int background;
static int black;

static int arial;

static struct osm_tesselation *mesh;

static var* window_width = 0;
static var* window_height = 0;

/*static double pan[2] = { 1.42949e+09, 1.27794e+08 };*/
static double pan[2] = { 40.73 / 90.0 * 0x7fffffff, -74.0 / 180.0 * 0x7fffffff };
static double zoom = 1.74891e-06;

static char message[4096];

void
game_init (int argc, char **argv)
{
  const char *map_shader_attributes[] =
    {
      "position", "color", 0
    };

  osm_parse (0);
  mesh = osm_tesselate ();

  /*
  pan[0] = mesh->lat_offset;
  pan[1] = mesh->lon_offset;
  */

  map_shader = draw_load_shader ("map", map_shader_attributes);
  background = texture_load ("color:fff0f3f4");
  black = texture_load ("color:ff000000");

  arial = font_load ("gfx/arial");

  glEnable (GL_TEXTURE_2D);
  glEnable (GL_BLEND);
  glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glDisable (GL_DEPTH_TEST);
  glDisable (GL_CULL_FACE);

  window_width = var_find ("width");
  window_height = var_find ("height");
}

void
osm_tesselation_draw (struct osm_tesselation *mesh)
{
  size_t i, j;
  const struct osm_batch *batch;

  float color[4];
  float window_size[2];
  float pan_transf[2];
  float zoom_transf;

  int32_t min_lat, max_lat;
  int32_t min_lon, max_lon;

  min_lat = pan[0];
  min_lon = pan[1];
  max_lat = (window_height->vfloat / (window_width->vfloat * zoom) + pan[0]);
  max_lon = 1.0 / zoom + pan[1];

  draw_bind_shader (map_shader);

  glVertexAttribPointer (0, 2, GL_INT, GL_FALSE, sizeof (*mesh->vertices), mesh->vertices);
  glEnableVertexAttribArray (0);

  zoom_transf = zoom * window_width->vfloat;
  draw_set_uniformf (map_shader, "zoom", &zoom_transf, 1);

  pan_transf[0] = pan[0] - mesh->lat_offset;
  pan_transf[1] = pan[1] - mesh->lon_offset;
  draw_set_uniformf (map_shader, "pan", pan_transf, 2);

  window_size[0] = 1.0f / window_width->vfloat;
  window_size[1] = 1.0f / window_height->vfloat;
  draw_set_uniformf (map_shader, "window_size", window_size, 2);

  for (i = 0; i < mesh->batch_count; ++i)
    {
      batch = &mesh->batches[i];

      draw_set_uniformf (map_shader, "color", batch->color, 4);

      glDrawElements (GL_TRIANGLES, batch->index_count, GL_UNSIGNED_INT, mesh->indices + batch->first_index);
    }

  color[0] = 0xcc / 255.0f;
  color[1] = 0xc5 / 255.0f;
  color[2] = 0xbd / 255.0f;
  color[3] = 1.0f;

  draw_set_uniformf (map_shader, "color", color, 4);

  glDrawElements (GL_LINES, mesh->line_index_count, GL_UNSIGNED_INT, mesh->line_indices);

  draw_set_color (0xff000000);
  font_draw(arial, 13, message, 11.0f, 16.0f, 0);
  draw_set_color (0xffffffff);
  font_draw(arial, 13, message, 10.0f, 15.0f, 0);

    {
      draw_set_color (0xff000000);

      for (i = 0; i < mesh->label_count; ++i)
        {
          const struct osm_label *label;
          const struct osm_vertex *vertex;

          vec2 *line;

          label = &mesh->labels[i];

          if (label->min_lat > max_lat
              || label->max_lat < min_lat
              || label->min_lon > max_lon
              || label->max_lon < min_lon)
            continue;

          line = calloc (label->index_count, sizeof (*line));

          for (j = 0; j < label->index_count; ++j)
            {
              assert (mesh->label_indices[label->first_index + j] < mesh->vertex_count);

              vertex = &mesh->vertices[mesh->label_indices[label->first_index + j]];

              vec2_set2f(&line[j],
                         (vertex->x - pan_transf[1]) * zoom_transf,
                         window_height->vfloat - ((vertex->y - pan_transf[0])) * zoom_transf);
            }

          font_path_draw (arial, 20, label->text, line, label->index_count);

          free (line);
        }

      draw_flush ();
    }
}

void
game_process_frame (unsigned int width, unsigned int height, double delta_time)
{
  device_state *device_states;
  int device_count;

  double mouse_lat, mouse_lon;

  device_states = input_get_device_states (&device_count);

  keyboard = &device_states[0];
  mouse = &device_states[1];

  if (keyboard->button_states[common_keys.escape] & button_pressed)
    exit (EXIT_SUCCESS);

  if (keyboard->button_states[common_keys.space] & button_pressed)
    {
      info ("%g %g %g", pan[0], pan[1], zoom);
    }

  mouse_lat = ((height - mouse->position_states[1]) / (width * zoom) + pan[0]) / 0x7fffffff * 90.0;
  mouse_lon = (mouse->position_states[0] / (width * zoom) + pan[1]) / 0x7fffffff * 180.0;

  if (mouse->button_states[1] & button_pressed)
    {
      size_t hit_way_count, i, j;
      uint32_t hit_ways[16];

      hit_way_count = osm_intersect (mouse_lon, mouse_lat, hit_ways, sizeof (hit_ways) / sizeof (hit_ways[0]));

      sprintf (message, "%.4f %.4f: ", mouse_lat, mouse_lon);

      for (i = 0; i < hit_way_count; ++i)
        {
          size_t tag_count;
          struct osm_tag hit_tags[16];

          tag_count = osm_tags_get (hit_ways[i], hit_tags, sizeof (hit_tags) / sizeof (hit_tags[0]));

          for (j = 0; j < tag_count; ++j)
            {
              strcat (message, hit_tags[j].tag);
              strcat (message, "  ");
            }
        }
    }

  if (mouse->button_states[0] & button_force_mask)
    {
      double new_zoom;

      new_zoom = zoom * pow (4.0, delta_time);

      if (new_zoom > 1.10944e-05)
        new_zoom = 1.10944e-05;

      pan[1] = mouse->position_states[0] * (1.0 / zoom - 1.0 / new_zoom) / width + pan[1];
      pan[0] = (height - mouse->position_states[1]) * (1.0 / zoom - 1.0 / new_zoom) / width + pan[0];

      zoom = new_zoom;
    }

  if (mouse->button_states[2] & button_force_mask)
    {
      double new_zoom;

      new_zoom = zoom * pow (1.0 / 4.0, delta_time);

      pan[1] = mouse->position_states[0] * (1.0 / zoom - 1.0 / new_zoom) / width + pan[1];
      pan[0] = (height - mouse->position_states[1]) * (1.0 / zoom - 1.0 / new_zoom) / width + pan[0];

      zoom = new_zoom;
    }

  glClearColor (0xf4 / 255.0f, 0xf3 / 255.0f, 0xf0 / 255.0f, 1.0f);
  glClear (GL_COLOR_BUFFER_BIT);

  osm_tesselation_draw (mesh);

  draw_set_color (0x1fffffff);
  draw_quad (black, width * 0.5 - 160, height * 0.5 - 240, 320, 480);
  draw_flush ();
}
