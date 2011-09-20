#include <string.h>
#include <stdlib.h>

#include "string-pool.h"

#define HASHMAP_REBUILD_NOM 4
#define HASHMAP_REBUILD_DEN 3
#define HASHMAP_GROWTH_FUNCTION(n)  (((n) + 1) * 2 - 1)

struct data_t
{
  char *key;
};

struct string_pool
{
  struct data_t *nodes;
  size_t size;
  size_t capacity;
};

static size_t hash(const char *key)
{
  size_t v = *key++;

  while(*key)
    v = v * 31 + *key++;

  return v;
}

struct string_pool *
string_pool_create(size_t capacity)
{
  struct string_pool *result;

  result = malloc(sizeof(struct string_pool));

  if (!result)
    return 0;

  result->size = 0;
  result->capacity = capacity;

  if (capacity)
    {
      result->nodes = calloc(capacity, sizeof (*result->nodes));

      if (!result->nodes)
        {
          free(result);

          return 0;
        }
    }
  else
    result->nodes = 0;

  return result;
}

const char *
string_pool_get(struct string_pool *map, const char *string)
{
  size_t i, n;

  /* If map is starting to get full, grow it and rehash all elements */
  if(map->size * HASHMAP_REBUILD_NOM >= map->capacity * HASHMAP_REBUILD_DEN)
    {
      struct data_t *new_nodes;
      size_t new_capacity;

      if(!map->capacity)
        new_capacity = 15;
      else
        new_capacity = HASHMAP_GROWTH_FUNCTION(map->capacity);

      new_nodes = calloc(new_capacity, sizeof(*new_nodes));

      if(!new_nodes)
        return 0;

      for(i = 0; i < map->capacity; ++i)
        {
          if(!map->nodes[i].key)
            continue;

          n = hash(map->nodes[i].key) % new_capacity;

          while(new_nodes[n].key)
            n = (n + 1) % new_capacity;

          new_nodes[n] = map->nodes[i];
        }

      free(map->nodes);
      map->nodes = new_nodes;
      map->capacity = new_capacity;
    }

  n = hash(string) % map->capacity;

  while (map->nodes[n].key)
    {
      if(!strcmp(map->nodes[n].key, string))
        return map->nodes[n].key;

      n = (n + 1) % map->capacity;
    }

  map->nodes[n].key = strdup (string);
  ++map->size;

  return map->nodes[n].key;
}
