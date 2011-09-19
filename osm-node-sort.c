#include "osm.h"

static void
percolate_down(struct osm_node *nodes, size_t start, size_t count)
{
  struct osm_node tmp;
  size_t root, child;

  root = start;
  child = root * 2 + 1;

  while (child < count)
    {
      if (child + 1 < count && nodes[child].id < nodes[child + 1].id)
        ++child;

      if (nodes[root].id >= nodes[child].id)
        break;

      tmp = nodes[root];
      nodes[root] = nodes[child];
      nodes[child] = tmp;

      root = child;

      child = root * 2 + 1;
    }
}

void
osm_node_sort (struct osm_node *nodes, size_t count)
{
  struct osm_node tmp;
  size_t i;

  for (i = count / 2; i--; )
    percolate_down(nodes, i, count);

  for (i = count; i--; )
    {
      tmp = nodes[0];
      nodes[0] = nodes[i];
      nodes[i] = tmp;

      percolate_down(nodes, 0, i);
    }
}
