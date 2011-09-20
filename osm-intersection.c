#include "osm.h"

size_t
osm_intersection (double lat, double lon)
{
  int32_t ilat, ilon;

  ilat = lat / 90.0 * 0x7fffffff;
  ilon = lon / 180.0 * 0x7fffffff;

}
