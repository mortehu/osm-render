#include <assert.h>
#include <math.h>
#include <stdlib.h>

#include "osm.h"

struct vertex
{
  double x, y;
};

static double
ray_ray_angle (double x1, double y1, double x2, double y2)
{
  double result;

  result = atan2 (y2, x2) - atan2 (y1, x1);

  if (result > M_PI)
    result = fmod (result + M_PI, 2 * M_PI) - M_PI;

  if (result < -M_PI)
    result = -fmod (-result + M_PI, 2 * M_PI) + M_PI;

  assert (result >= -M_PI);
  assert (result <= M_PI);
  
  return result;
}

static int
point_inside_polygon (double x, double y, const struct vertex *polygon, size_t count)
{
  double angle = 0;
  size_t i;

  for (i = 0; i < count; ++i)
    {
      angle += ray_ray_angle (polygon[i].x - x,
                              polygon[i].y - y,
                              polygon[(i + 1) % count].x - x,
                              polygon[(i + 1) % count].y - y);
    }

  return (fabs (angle) >= M_PI);
}

size_t
osm_intersect (double lat, double lon, uint32_t *result, size_t count)
{
  size_t hit_count = 0;
  const struct osm_way *way;
  struct vertex *polygon;
  size_t i, j;

  for (i = 0; i < way_count; ++i)
    {
      way = &ways[i];

      if (node_refs[way->first_node] != node_refs[way->first_node + way->node_count - 1])
        continue;

      polygon = calloc (way->node_count, sizeof (*polygon));

      for (j = 0; j < way->node_count; ++j)
        {
          polygon[j].x = (double) nodes[node_refs[way->first_node + j]].lon / 0x7fffffff * 180.0;
          polygon[j].y = (double) nodes[node_refs[way->first_node + j]].lat / 0x7fffffff * 90.0;
        }

      if (point_inside_polygon (lat, lon, polygon, way->node_count))
        {
          if (hit_count < count)
            result[hit_count] = i;

          ++hit_count;
        }

      free (polygon);
    }

  return hit_count;
}
