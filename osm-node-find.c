#include "osm.h"

int
osm_node_find (uint64_t id, const struct osm_node *nodes, size_t count)
{
  size_t first = 0, half, middle;

  while (count > 0)
    {
      half = count / 2;
      middle = first + half;

      if (nodes[middle].id == id)
        return middle;

      if (nodes[middle].id < id)
        {
          first = middle + 1;
          count -= half + 1;
        }
      else
        count = half;
    }

  return -1;
}
