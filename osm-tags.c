#include <stdio.h>

#include "array.h"
#include "osm.h"
#include "string-pool.h"

static ARRAY (struct osm_tag) tags;
static struct string_pool *tag_strings;

void
osm_tag_add (uint32_t way, const char *key, const char *value)
{
  char buffer[64];
  struct osm_tag new_tag;

  if (!tag_strings)
    tag_strings = string_pool_create (2047);

  snprintf (buffer, sizeof (buffer), "%s=%s", key, value);
  buffer[sizeof (buffer) - 1] = 0;

  new_tag.way = way;
  new_tag.tag = string_pool_get (tag_strings, buffer);
  
  ARRAY_ADD (&tags, new_tag);
}

size_t
osm_tags_get (uint32_t way, struct osm_tag *result, size_t count)
{
  size_t hit_count = 0;
  size_t i;

  for (i = 0; i < ARRAY_COUNT (&tags); ++i)
    {
      if (ARRAY_GET (&tags, i).way != way)
        continue;

      if (hit_count < count)
        result[hit_count] = ARRAY_GET (&tags, i);

      ++hit_count;
    }

  return hit_count;
}
