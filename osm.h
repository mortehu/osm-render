#ifndef OSM_H_
#define OSM_H_ 1

#include <stdint.h>
#include <stdlib.h>

struct osm_node
{
  uint64_t id;
  int32_t lat;
  int32_t lon;
};

#define OSM_WAY_BUILDING           0x0001
#define OSM_WAY_ONEWAY             0x0002
#define OSM_WAY_PARK               0x0004
#define OSM_WAY_RESIDENTIAL        0x0008
#define OSM_WAY_CEMETERY           0x0010
#define OSM_WAY_CROSSING           0x0020
#define OSM_WAY_SIDEWALK           0x0040

#define OSM_HIGHWAY_BUS_STOP            1
#define OSM_HIGHWAY_CONSTRUCTION        2
#define OSM_HIGHWAY_CROSSING            3
#define OSM_HIGHWAY_CYCLEWAY            4
#define OSM_HIGHWAY_FOOTWAY             5
#define OSM_HIGHWAY_LIVING_STREET       6
#define OSM_HIGHWAY_MINI_ROUNDABOUT     7
#define OSM_HIGHWAY_MOTORWAY            8
#define OSM_HIGHWAY_MOTORWAY_JUNCTION   9
#define OSM_HIGHWAY_MOTORWAY_LINK      10
#define OSM_HIGHWAY_PATH               12
#define OSM_HIGHWAY_PEDESTRIAN         13
#define OSM_HIGHWAY_PRIMARY            14
#define OSM_HIGHWAY_RESIDENTIAL        15
#define OSM_HIGHWAY_ROAD               16
#define OSM_HIGHWAY_SECONDARY          17
#define OSM_HIGHWAY_SERVICE            18
#define OSM_HIGHWAY_STEPS              19
#define OSM_HIGHWAY_TERTIARY           20
#define OSM_HIGHWAY_TRAFFIC_SIGNALS    21
#define OSM_HIGHWAY_TRUNK              22
#define OSM_HIGHWAY_TRUNK_LINK         23
#define OSM_HIGHWAY_TURNING_CIRCLE     24
#define OSM_HIGHWAY_UNCLASSIFIED       25

#define OSM_NATURAL_BAY                 1
#define OSM_NATURAL_CLIFF               2
#define OSM_NATURAL_COASTLINE           3
#define OSM_NATURAL_LAND                4
#define OSM_NATURAL_TREE                5
#define OSM_NATURAL_WATER               6
#define OSM_NATURAL_WOOD                7

struct osm_way
{
  uint32_t first_node;
  uint32_t node_count;
  uint32_t name;
  uint16_t flags;
  uint8_t  highway;
  uint8_t  natural;
};

extern int32_t min_lat, min_lon;
extern int32_t max_lat, max_lon;

extern struct osm_node nodes[];
extern size_t node_count;

extern uint32_t node_refs[];
extern size_t node_ref_count;

extern struct osm_way ways[];
extern size_t way_count;

extern char strings[];
extern size_t strings_length;

void
osm_node_sort (struct osm_node *nodes, size_t count);

int
osm_node_find (uint64_t id, const struct osm_node *nodes, size_t count);

void
osm_parse (int fd);

/***********************************************************************/

struct osm_vertex
{
  int32_t x, y;
};

struct osm_batch
{
  float color[4];
  uint32_t first_index;
  uint32_t index_count;
};

struct osm_label
{
  char *text;
  uint32_t first_index;
  uint32_t index_count;
};

struct osm_tesselation
{
  struct osm_vertex *vertices;
  size_t vertex_count;

  uint32_t *indices;
  size_t index_count;

  struct osm_batch *batches;
  size_t batch_count;

  uint32_t *line_indices;
  size_t line_index_count;

  uint32_t *label_indices;
  size_t label_index_count;

  struct osm_label *labels;
  size_t label_count;

  int32_t lat_offset, lon_offset;
};

struct osm_tesselation *
osm_tesselate ();

/***********************************************************************/

struct osm_tag
{
  uint32_t way;
  const char *tag;
};

void
osm_tag_add (uint32_t way, const char *key, const char *value);

size_t
osm_tags_get (uint32_t way, struct osm_tag *result, size_t count);

/***********************************************************************/

size_t
osm_intersect (double lat, double lon, uint32_t *result, size_t count);

#endif /* !OSM_H_ */
