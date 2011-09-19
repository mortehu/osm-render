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
#include <celsius/var.h>

#include "osm.h"

static device_state *keyboard;
static device_state *mouse;

static int map_shader;

static int background;

static struct osm_tesselation *mesh;

static var* window_width = 0;
static var* window_height = 0;

static double pan[2] = { 1.42949e+09, 1.27794e+08 };
static double zoom = 1.74891e-06;

void
game_init (int argc, char **argv)
{
  const char *map_shader_attributes[] =
    {
      "position", "color", 0
    };

  osm_parse (0);
  mesh = osm_tesselate ();

  map_shader = draw_load_shader ("map", map_shader_attributes);
  background = texture_load ("color:ffefebef");

  glEnable (GL_TEXTURE_2D);
  glEnable (GL_BLEND);
  glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glDisable (GL_DEPTH_TEST);
  glDisable (GL_CULL_FACE);

  window_width = var_find ("width");
  window_height = var_find ("height");
}

void
flush_lines ()
{
#if 0
  size_t offset = 0;
  float window_size[2];

  if (!line_vertex_count)
    return;

  draw_bind_shader (map_shader);

  glVertexAttribPointer (0, 2, GL_FLOAT, GL_FALSE, sizeof (struct vertex), line_vertices);
  glEnableVertexAttribArray (0);
  offset += 2 * sizeof (float);

  glVertexAttribPointer (1, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof (struct vertex), (const char *) line_vertices + offset);
  glEnableVertexAttribArray (1);

  window_size[0] = 1.0f / window_width->vfloat;
  window_size[1] = 1.0f / window_height->vfloat;

  draw_set_uniformf (map_shader, "window_size", window_size, 2);

  glDrawArrays (GL_LINES, 0, line_vertex_count);

  line_vertex_count = 0;
#endif
}

void
osm_tesselation_draw (struct osm_tesselation *mesh)
{
  size_t i;
  const struct osm_batch *batch;

  float window_size[2];
  float zoom_product;

  draw_bind_shader (map_shader);

  glVertexAttribPointer (0, 2, GL_INT, GL_FALSE, sizeof (*mesh->vertices), mesh->vertices);
  glEnableVertexAttribArray (0);

  window_size[0] = 1.0f / window_width->vfloat;
  window_size[1] = 1.0f / window_height->vfloat;

  zoom_product = zoom * window_width->vfloat;
  draw_set_uniformf (map_shader, "zoom", &zoom_product, 1);

  draw_set_uniformd (map_shader, "pan", pan, 2);
  draw_set_uniformf (map_shader, "window_size", window_size, 2);

  for (i = 0; i < mesh->batch_count; ++i)
    {
      batch = &mesh->batches[i];

      draw_set_uniformf (map_shader, "color", batch->color, 4);

      glDrawElements (GL_TRIANGLES, batch->index_count, GL_UNSIGNED_INT, mesh->indices + batch->first_index);
    }

    {
      float color[4];

      color[0] = 0xdc / 255.0f;
      color[1] = 0xd5 / 255.0f;
      color[2] = 0xcd / 255.0f;
      color[3] = 1.0f;

      draw_set_uniformf (map_shader, "color", batch->color, 4);

      glDrawElements (GL_LINES, mesh->line_index_count, GL_UNSIGNED_INT, mesh->line_indices);
    }
}

void
game_process_frame (unsigned int width, unsigned int height, double delta_time)
{
  device_state *device_states;
  int device_count;

  device_states = input_get_device_states (&device_count);

  keyboard = &device_states[0];
  mouse = &device_states[1];

  if (keyboard->button_states[common_keys.escape] & button_pressed)
    exit (EXIT_SUCCESS);

  if (keyboard->button_states[common_keys.space] & button_pressed)
    {
      info ("%g %g %g", pan[0], pan[1], zoom);
    }

  if (mouse->button_states[0] & button_force_mask)
    {
      double new_zoom;

      new_zoom = zoom * pow (4.0, delta_time);

      pan[1] = mouse->position_states[0] * (1.0 / zoom - 1.0 / new_zoom) / width + pan[1];
      pan[0] = (height - mouse->position_states[1]) * (1.0 / zoom - 1.0 / new_zoom) / width + pan[0];

      zoom = new_zoom;
    }
  else if (mouse->button_states[2] & button_force_mask)
    {
      double new_zoom;

      new_zoom = zoom * pow (1.0 / 4.0, delta_time);

      pan[1] = mouse->position_states[0] * (1.0 / zoom - 1.0 / new_zoom) / width + pan[1];
      pan[0] = (height - mouse->position_states[1]) * (1.0 / zoom - 1.0 / new_zoom) / width + pan[0];

      zoom = new_zoom;
    }

  glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  osm_tesselation_draw (mesh);
}
