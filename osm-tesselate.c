#include <math.h>
#include <string.h>
#include <stdio.h>

#include <GL/glu.h>

#include <celsius/vector.h>

#include "array.h"
#include "osm.h"

enum polygon_layer
{
  /* Sorted by painting order */
  LAYER_GRASS,
  LAYER_CEMETERY,
  LAYER_WATER,
  LAYER_PEDESTRIAN_ZONE,
  LAYER_PATH,
  LAYER_SMALL_ROAD,
  LAYER_BIG_ROAD,
  LAYER_BUILDING,

  LAYER_INVALID
};

struct triangle
{
  enum polygon_layer layer;

  uint32_t v[3];
};

static GLUtesselator* tess;
static GLUtesselator* tess_contour;

static ARRAY (struct triangle)   triangles;
static ARRAY (uint32_t)          line_loop;

static ARRAY (uint32_t)          lines;

static enum polygon_layer        polygon_layer;
static int                       polygon_mode;
static ARRAY (struct osm_node *) polygon;

static void
contour_begin (int mode)
{
  assert (mode == GL_LINE_LOOP);
}

static void
contour_end ()
{
  size_t i;

  for (i = 0; i + 1 < ARRAY_COUNT (&line_loop); ++i)
    {
      ARRAY_ADD (&lines, ARRAY_GET (&line_loop, i));
      ARRAY_ADD (&lines, ARRAY_GET (&line_loop, i + 1));
    }

  ARRAY_ADD (&lines, ARRAY_GET (&line_loop, i));
  ARRAY_ADD (&lines, ARRAY_GET (&line_loop, 0));

  ARRAY_RESET (&line_loop);
}

static void
contour_vertex (struct osm_node *node)
{
  ARRAY_ADD (&line_loop, node - nodes);
}

static void
triangle_add (uint32_t i0, uint32_t i1, uint32_t i2)
{
  struct triangle new_triangle;

  new_triangle.layer = polygon_layer;
  new_triangle.v[0] = i0;
  new_triangle.v[1] = i1;
  new_triangle.v[2] = i2;

  ARRAY_ADD (&triangles, new_triangle);
}

static void
polygon_begin (int mode)
{
  polygon_mode = mode;
}

static void
polygon_end ()
{
  size_t i;

  switch (polygon_mode)
    {
    case GL_TRIANGLES:

      for (i = 0; i < ARRAY_COUNT (&polygon); i += 3)
        {
          triangle_add (ARRAY_GET (&polygon, i) - nodes,
                        ARRAY_GET (&polygon, i + 1) - nodes,
                        ARRAY_GET (&polygon, i + 2) - nodes);
        }

      break;

    case GL_TRIANGLE_STRIP:

      for (i = 2; i < ARRAY_COUNT (&polygon); ++i)
        {
          triangle_add (ARRAY_GET (&polygon, i - 2) - nodes,
                        ARRAY_GET (&polygon, i - 1) - nodes,
                        ARRAY_GET (&polygon, i) - nodes);
        }

      break;

    case GL_TRIANGLE_FAN:

      for (i = 2; i < ARRAY_COUNT (&polygon); ++i)
        {
          triangle_add (ARRAY_GET (&polygon, 0) - nodes,
                        ARRAY_GET (&polygon, i - 1) - nodes,
                        ARRAY_GET (&polygon, i) - nodes);
        }

      break;

    default:

      assert (!"Unhandled polygon mode");
    }

  ARRAY_RESET (&polygon);
}

static void
polygon_vertex (struct osm_node *node)
{
  ARRAY_ADD (&polygon, node);
}

static void tess_combine(GLdouble coords[3], void *d[4], GLfloat w[4], struct osm_node **result, void *user)
{
  struct osm_node *new_node;

  new_node = &nodes[node_count++];
  new_node->lon = coords[0];
  new_node->lat = coords[1];

  *result = new_node;
}

static void
add_vertex (int do_contour, double lon, double lat)
{
  struct osm_node *new_node;
  double coords[3];

  new_node = &nodes[node_count++];
  new_node->lon = lon;
  new_node->lat = lat;

  coords[0] = lon;
  coords[1] = lat;
  coords[2] = 0;

  gluTessVertex(tess, coords, (void *) new_node);

  if (do_contour)
    gluTessVertex(tess_contour, coords, (void *) new_node);
}

static void
add_line (float width, int do_contour, float x0, float y0, float x1, float y1)
{
  static const size_t count = 7;

  size_t i;

  double c, s;
  double dx, dy, m;
  double nx, ny;

  dx = x1 - x0;
  dy = y1 - y0;
  m = width / sqrt(dx * dx + dy * dy);

  dx *= m;
  dy *= m;

  nx = dy;
  ny = -dx;

  for(i = 0; i <= count; ++i)
  {
    c = cosf(M_PI * i / count);
    s = sinf(M_PI * i / count);

    add_vertex (do_contour, x0 - c * nx + s * ny, y0 - c * ny - s * nx);
  }

  for(i = 0; i <= count; ++i)
  {
    c = cosf(M_PI * i / count);
    s = sinf(M_PI * i / count);

    add_vertex (do_contour, x1 + c * nx - s * ny, y1 + c * ny + s * nx);
  }
}

static void
OSM_TESSELATE_percolate_down (struct triangle *triangles, size_t start, size_t count)
{
  struct triangle tmp;
  size_t root, child;

  root = start;
  child = root * 2 + 1;

  while (child < count)
    {
      if (child + 1 < count && triangles[child].layer < triangles[child + 1].layer)
        ++child;

      if (triangles[root].layer >= triangles[child].layer)
        break;

      tmp = triangles[root];
      triangles[root] = triangles[child];
      triangles[child] = tmp;

      root = child;

      child = root * 2 + 1;
    }
}

static void
OSM_TESSELATE_sort (struct triangle *triangles, size_t count)
{
  struct triangle tmp;
  size_t i;

  for (i = count / 2; i--; )
    OSM_TESSELATE_percolate_down (triangles, i, count);

  for (i = count; i--; )
    {
      tmp = triangles[0];
      triangles[0] = triangles[i];
      triangles[i] = tmp;

      OSM_TESSELATE_percolate_down (triangles, 0, i);
    }
}

static int
int_line_line (int a0x, int a0y, int a1x, int a1y,
               int b0x, int b0y, int b1x, int b1y)
{
  float ua, ub;

  ua = (float) ((b1x - b0x) * (a0y - b0y) - (b1y - b0y) * (a0x - b0x)) / ((b1y - b0y) * (a1x - a0x) - (b1x - b0x) * (a1y - a0y));
  ub = (float) ((a1x - a0x) * (a0y - b0y) - (a1y - a0y) * (a0x - b0x)) / ((b1y - b0y) * (a1x - a0x) - (b1x - b0x) * (a1y - a0y));

  return ua >= 0 && ua <= 1.0f && ub >= 0 && ub <= 1.0f;
}

static size_t
add_labeled_way (uint32_t first_node_ref, uint32_t node_count,
                 const struct osm_label *labels, size_t label_count,
                 const uint32_t *label_indices)
{
  size_t i, j, k;
  const struct osm_label *label;
  uint32_t a0, a1, b0, b1;
  int32_t a0x, a0y, a1x, a1y;
  int32_t b0x, b0y, b1x, b1y;

  size_t length = node_count;

  for (i = 0; i < label_count; ++i)
    {
      label = &labels[i];

      for (j = 0; j < length; ++j)
        {
          a0 = node_refs[first_node_ref + j];

          for (k = 1; k + 1 < label->index_count; ++k)
            {
              b0 = label_indices[label->first_index + k];

              if (a0 == b0)
                {
                  length = j;

                  break;
                }
            }
        }

      for (j = 0; j + 1 < length; ++j)
        {
          a0 = node_refs[first_node_ref + j];
          a1 = node_refs[first_node_ref + j + 1];

          a0x = nodes[a0].lon;
          a0y = nodes[a0].lat;

          a1x = nodes[a1].lon;
          a1y = nodes[a1].lat;

          for (k = 1; k + 2 < label->index_count; ++k)
            {
              b0 = label_indices[label->first_index + k];
              b1 = label_indices[label->first_index + k + 1];

              b0x = nodes[b0].lon;
              b0y = nodes[b0].lat;

              b1x = nodes[b1].lon;
              b1y = nodes[b1].lat;

              if (int_line_line (a0x, a0y, a1x, a1y, b0x, b0y, b1x, b1y))
                {
                  length = j;

                  break;
                }
            }
        }
    }

  return length;
}

struct osm_tesselation *
osm_tesselate ()
{
  ARRAY (uint32_t) label_indices;
  ARRAY (struct osm_label) labels;

  ARRAY (struct osm_batch) batches;
  enum polygon_layer prev_layer = LAYER_INVALID;
  struct osm_batch batch;

  struct osm_tesselation *result;

  const struct osm_way *way;
  const struct osm_node *prev_node, *node;
  size_t i, j, k;

  double polygon[16384][3];

  ARRAY_INIT (&label_indices);
  ARRAY_INIT (&labels);

  ARRAY_INIT (&batches);

  result = calloc (1, sizeof (*result));

  tess_contour = gluNewTess();

  gluTessNormal(tess_contour, 0, 0, 1);

  gluTessCallback(tess_contour, GLU_BEGIN, (_GLUfuncptr) contour_begin);
  gluTessCallback(tess_contour, GLU_END, (_GLUfuncptr) contour_end);
  gluTessCallback(tess_contour, GLU_TESS_COMBINE, (_GLUfuncptr) tess_combine);
  gluTessProperty(tess_contour, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_NONZERO);
  gluTessProperty(tess_contour, GLU_TESS_BOUNDARY_ONLY, GL_TRUE);
  gluTessCallback(tess_contour, GLU_VERTEX, (_GLUfuncptr) contour_vertex);

  gluTessBeginPolygon(tess_contour, 0);

  for (j = 0; j < way_count; ++j)
    {
      enum
        {
          LINE, POLYGON, NONE
        } mode = NONE;

      int do_contour = 0;
      double line_thickness = 0;

      tess = gluNewTess();

      gluTessNormal(tess, 0, 0, 1);

      gluTessCallback(tess, GLU_BEGIN, (_GLUfuncptr) polygon_begin);
      gluTessCallback(tess, GLU_END, (_GLUfuncptr) polygon_end);
      gluTessCallback(tess, GLU_TESS_COMBINE, (_GLUfuncptr) tess_combine);
      gluTessProperty(tess, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_NONZERO);
      gluTessCallback(tess, GLU_VERTEX, (_GLUfuncptr) polygon_vertex);

      way = &ways[j];

      if (node_refs[way->first_node] == node_refs[way->first_node + way->node_count - 1])
        {
          if (way->flags & OSM_WAY_PARK)
            {
              polygon_layer = LAYER_GRASS;
              mode = POLYGON;
            }
          else if (way->flags & OSM_WAY_CEMETERY)
            {
              polygon_layer = LAYER_CEMETERY;
              mode = POLYGON;
            }
          else if (way->flags & OSM_WAY_BUILDING)
            {
              polygon_layer = LAYER_BUILDING;
              do_contour = 1;
              mode = POLYGON;
            }
          else if (way->natural)
            {
              switch (way->natural)
                {
                case OSM_NATURAL_COASTLINE:
                case OSM_NATURAL_WATER:

                  polygon_layer = LAYER_WATER;
                  mode = POLYGON;

                  break;
                }
            }
          else if (way->highway)
            {
              switch (way->highway)
                {
                case OSM_HIGHWAY_CYCLEWAY:
                case OSM_HIGHWAY_PEDESTRIAN:
                case OSM_HIGHWAY_PATH:
                case OSM_HIGHWAY_FOOTWAY:

                  if (way->flags & (OSM_WAY_CROSSING | OSM_WAY_SIDEWALK))
                    break;

                  polygon_layer = LAYER_PEDESTRIAN_ZONE;
                  mode = POLYGON;

                  break;
                }
            }
        }

      if (mode == NONE)
        {
          if (way->highway)
            {
              switch (way->highway)
                {
                case OSM_HIGHWAY_TERTIARY:
                case OSM_HIGHWAY_LIVING_STREET:
                case OSM_HIGHWAY_RESIDENTIAL:
                case OSM_HIGHWAY_ROAD:
                case OSM_HIGHWAY_SERVICE:
                case OSM_HIGHWAY_UNCLASSIFIED:

                  polygon_layer = LAYER_SMALL_ROAD;
                  line_thickness = 0.8e3;
                  do_contour = 1;
                  mode = LINE;

                  break;

                case OSM_HIGHWAY_CYCLEWAY:
                case OSM_HIGHWAY_PEDESTRIAN:
                case OSM_HIGHWAY_PATH:
                case OSM_HIGHWAY_FOOTWAY:

                  if (way->flags & (OSM_WAY_CROSSING | OSM_WAY_SIDEWALK))
                    break;

                  polygon_layer = LAYER_PATH;
                  line_thickness = 0.3e3;

                  mode = LINE;

                  break;

                case OSM_HIGHWAY_TRUNK:
                case OSM_HIGHWAY_TRUNK_LINK:
                case OSM_HIGHWAY_TURNING_CIRCLE:
                case OSM_HIGHWAY_MOTORWAY:
                case OSM_HIGHWAY_MOTORWAY_JUNCTION:
                case OSM_HIGHWAY_MOTORWAY_LINK:
                case OSM_HIGHWAY_PRIMARY:
                case OSM_HIGHWAY_SECONDARY:

                  polygon_layer = LAYER_BIG_ROAD;
                  line_thickness = 1.0e3;
                  do_contour = 1;
                  mode = LINE;

                  break;

                default:

                  continue;
                }

              if (way->name)
                {
                  struct osm_label new_label;
                  size_t length = 0;

                  for (i = 0; i + 1 < way->node_count; i += length + 1)
                    {
                      length
                        = add_labeled_way (way->first_node + i, way->node_count - i,
                                           &ARRAY_GET (&labels, 0), ARRAY_COUNT (&labels),
                                           &ARRAY_GET (&label_indices, 0));

                      if (length)
                        {
                          new_label.text = strings + way->name;
                          new_label.first_index = ARRAY_COUNT (&label_indices);
                          new_label.index_count = length;

                          ARRAY_ADD (&labels, new_label);

                          for (k = 0; k < length; ++k)
                            ARRAY_ADD (&label_indices, node_refs[way->first_node + i + k]);
                        }
                    }
                }
            }
        }

      switch (mode)
        {
        case POLYGON:

          if (node_refs[way->first_node] != node_refs[way->first_node + way->node_count - 1])
            break;

          assert (way->node_count <= sizeof (polygon) / sizeof (polygon[0]));

          gluTessBeginPolygon(tess, 0);
          gluTessBeginContour(tess);

          for (i = 0; i + 1 < way->node_count; ++i)
            {
              double coords[3];

              node = &nodes[node_refs[way->first_node + i]];

              coords[0] = node->lon;
              coords[1] = node->lat;
              coords[2] = 0;

              gluTessVertex(tess, coords, (void *) node);
            }

          if (do_contour)
            {
              contour_begin (GL_LINE_LOOP);

              for (i = 0; i + 1 < way->node_count; ++i)
                contour_vertex (&nodes[node_refs[way->first_node + i]]);

              contour_end ();
            }

          gluTessEndContour (tess);
          gluTessEndPolygon (tess);

          break;

        case LINE:

          if (line_thickness && way->node_count >= 2)
            {
              prev_node = 0;

              gluTessBeginPolygon(tess, 0);

              for (i = 0; i < way->node_count; ++i)
                {
                  node = &nodes[node_refs[way->first_node + i]];

                  if (prev_node)
                    {
                      gluTessBeginContour (tess);
                      gluTessBeginContour (tess_contour);

                      add_line (line_thickness, do_contour,
                                prev_node->lon, prev_node->lat,
                                node->lon, node->lat);

                      gluTessEndContour (tess_contour);
                      gluTessEndContour (tess);
                    }

                  prev_node = node;
                }

              gluTessEndPolygon (tess);
            }

          break;

        case NONE:

          break;
        }

      gluDeleteTess (tess);
    }

  gluTessEndPolygon (tess_contour);
  gluDeleteTess (tess_contour);

  OSM_TESSELATE_sort (&ARRAY_GET (&triangles, 0), ARRAY_COUNT (&triangles));

  result->vertex_count = node_count;
  result->vertices = calloc (result->vertex_count, sizeof (*result->vertices));

  int32_t min_lat, max_lat;
  int32_t min_lon, max_lon;

  min_lat = max_lat = nodes[0].lat;
  min_lon = max_lon = nodes[0].lon;

  for (i = 1; i < result->vertex_count; ++i)
    {
      if (nodes[i].lat < min_lat)
        min_lat = nodes[i].lat;
      else if (nodes[i].lat > max_lat)
        max_lat = nodes[i].lat;

      if (nodes[i].lon < min_lon)
        min_lon = nodes[i].lon;
      else if (nodes[i].lon > max_lon)
        max_lon = nodes[i].lon;
    }

  result->lat_offset = (max_lat - min_lat) / 2;
  result->lon_offset = (max_lon - min_lon) / 2;

  for (i = 0; i < result->vertex_count; ++i)
    {
      result->vertices[i].x = nodes[i].lon - result->lon_offset;
      result->vertices[i].y = nodes[i].lat - result->lat_offset;
    }

  result->index_count = ARRAY_COUNT (&triangles) * 3;
  result->indices = calloc (result->index_count, sizeof (*result->indices));

  for (i = 0, j = 0; i < ARRAY_COUNT (&triangles); ++i)
    {
      struct triangle *t;

      t = &ARRAY_GET (&triangles, i);

      if (t->layer != prev_layer)
        {
          if (prev_layer != LAYER_INVALID)
            {
              batch.index_count = j - batch.first_index;
              ARRAY_ADD (&batches, batch);
            }

          batch.first_index = j;

          switch (t->layer)
            {
            case LAYER_GRASS:

              batch.color[0] = 0xc9 / 255.0f;
              batch.color[1] = 0xdf / 255.0f;
              batch.color[2] = 0xaf / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_CEMETERY:

              batch.color[0] = 0xdf / 255.0f;
              batch.color[1] = 0xdb / 255.0f;
              batch.color[2] = 0xd4 / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_WATER:

              batch.color[0] = 0xa5 / 255.0f;
              batch.color[1] = 0xbf / 255.0f;
              batch.color[2] = 0xdd / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_PEDESTRIAN_ZONE:

              batch.color[0] = 0xdf / 255.0f;
              batch.color[1] = 0xdb / 255.0f;
              batch.color[2] = 0xd4 / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_PATH:

              batch.color[0] = 0xcc / 255.0f;
              batch.color[1] = 0xc5 / 255.0f;
              batch.color[2] = 0xcd / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_BIG_ROAD:

              batch.color[0] = 0xff / 255.0f;
              batch.color[1] = 0xfd / 255.0f;
              batch.color[2] = 0x8b / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_SMALL_ROAD:

              batch.color[0] = 0xff / 255.0f;
              batch.color[1] = 0xff / 255.0f;
              batch.color[2] = 0xff / 255.0f;
              batch.color[3] = 1.0f;

              break;

            case LAYER_BUILDING:

              batch.color[0] = 0xec / 255.0f;
              batch.color[1] = 0xeb / 255.0f;
              batch.color[2] = 0xe8 / 255.0f;
              batch.color[3] = 1.0f;

              break;

            default:

              assert (!"Unknown layer");
            }

          prev_layer = t->layer;
        }

      result->indices[j++] = t->v[0];
      result->indices[j++] = t->v[1];
      result->indices[j++] = t->v[2];
    }

  if (prev_layer != LAYER_INVALID)
    {
      batch.index_count = j - batch.first_index;
      ARRAY_ADD (&batches, batch);
    }

  result->batch_count = ARRAY_COUNT (&batches);
  result->batches = &ARRAY_GET (&batches, 0);

  result->line_index_count = ARRAY_COUNT (&lines);
  result->line_indices = &ARRAY_GET (&lines, 0);

  result->label_index_count = ARRAY_COUNT (&label_indices);
  result->label_indices = &ARRAY_GET (&label_indices, 0);

  result->label_count = ARRAY_COUNT (&labels);
  result->labels = &ARRAY_GET (&labels, 0);

  fprintf (stderr, "Batches: %u  Indices: %u  Vertices: %u  Labels: %u\n",
           (unsigned int) result->batch_count,
           (unsigned int) result->index_count,
           (unsigned int) result->vertex_count,
           (unsigned int) result->label_count);

  return result;
}