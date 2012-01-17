#include <arpa/inet.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <err.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSArchiver.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSValue.h>
#import <Swanston/NSData+SWZlib.h>
#import <Swanston/SWIndexSet.h>
#import <Swanston/SWPath.h>
#import <MapData.h>

#import <Osm/fileformat.pb-c.h>
#import <Osm/osmformat.pb-c.h>

typedef struct MapDataBounds MapDataBounds;

struct MapDataBounds
{
  /* In nanodegrees */
  int64_t minLat, minLon, maxLat, maxLon;
};

struct MapDataNode
{
  double latitude, longitude;
};

struct MapDataWay
{
  uint64_t nodeRefStart;
  uint64_t tagStart;
};

@implementation MapData
- (id)init
{
  assert (!"not implemented");
}

- (id)initWithPath:(NSString *)path
{
  if (!(self = [super init]))
    return nil;

  if (!(fileData = [[NSData dataWithContentsOfMappedFile:path] retain]))
    {
      [self release];

      return nil;
    }

  return self;
}

- (void)dealloc
{
  [fileData release];
  [super dealloc];
}

- (void)_findMatchingNodesInPrimitiveBlock:(OSMPBF__PrimitiveBlock *)primitiveBlock
                                    bounds:(MapDataBounds *)bounds
                             matchingNodes:(SWIndexSet *)matchingNodes
                              matchingWays:(SWIndexSet *)matchingWays
                                extraNodes:(SWIndexSet *)extraNodes
{
  size_t i, j, k;

  for (i = 0; i < primitiveBlock->n_primitivegroup; ++i)
    {
      OSMPBF__PrimitiveGroup *primitiveGroup;
      int64_t id = 0, lat, lon;
      unsigned int granularity;

      primitiveGroup = primitiveBlock->primitivegroup[i];

      lat = primitiveBlock->has_lat_offset ? primitiveBlock->lat_offset : 0;
      lon = primitiveBlock->has_lon_offset ? primitiveBlock->lon_offset : 0;
      granularity = primitiveBlock->has_granularity ? primitiveBlock->granularity : 100;

      assert (!primitiveGroup->n_nodes);

      if (primitiveGroup->dense)
        {
          for (j = 0; j < primitiveGroup->dense->n_id; ++j)
            {
              id += primitiveGroup->dense->id[j];
              lat += primitiveGroup->dense->lat[j] * 100;
              lon += primitiveGroup->dense->lon[j] * 100;

              if (lat >= bounds->minLat && lat <= bounds->maxLat
                  && lon >= bounds->minLon && lon <= bounds->maxLon)
                {
                  [matchingNodes addIndex:id];
                }
            }
        }

      for (j = 0; j < primitiveGroup->n_ways; ++j)
        {
          OSMPBF__Way *way;
          int32_t node = 0;

          way = primitiveGroup->ways[j];

          for (k = 0; k < way->n_refs; ++k)
            {
              node += way->refs[k];

              if ([matchingNodes containsIndex:node])
                break;
            }

          if (k != way->n_refs)
            {
              [matchingWays addIndex:way->id];

              node = 0;

              for (k = 0; k < way->n_refs; ++k)
                {
                  node += way->refs[k];

                  [extraNodes addIndex:node];
                }
            }
        }
    }
}

- (void)_collectNodesAndWays:(OSMPBF__PrimitiveBlock *)primitiveBlock
               matchingNodes:(SWIndexSet *)matchingNodes
                matchingWays:(SWIndexSet *)matchingWays
                      result:(NSMutableDictionary *)result
{
  size_t i, j, k;

  for (i = 0; i < primitiveBlock->n_primitivegroup; ++i)
    {
      NSAutoreleasePool *pool;

      OSMPBF__PrimitiveGroup *primitiveGroup;
      int64_t id = 0, lat, lon;
      unsigned int granularity;

      pool = [NSAutoreleasePool new];

      primitiveGroup = primitiveBlock->primitivegroup[i];

      lat = primitiveBlock->has_lat_offset ? primitiveBlock->lat_offset : 0;
      lon = primitiveBlock->has_lon_offset ? primitiveBlock->lon_offset : 0;
      granularity = primitiveBlock->has_granularity ? primitiveBlock->granularity : 100;

      assert (!primitiveGroup->n_nodes);

      if (primitiveGroup->dense)
        {
          for (j = 0; j < primitiveGroup->dense->n_id; ++j)
            {
              id += primitiveGroup->dense->id[j];
              lat += primitiveGroup->dense->lat[j] * 100;
              lon += primitiveGroup->dense->lon[j] * 100;

              if ([matchingNodes containsIndex:id])
                {
                  [nodes setObject:[NSValue valueWithPoint:NSMakePoint (lon * 1.0e-9, lat * 1.0e-9)]
                            forKey:[NSNumber numberWithUnsignedInteger:id]];
                }
            }
        }

      for (j = 0; j < primitiveGroup->n_ways; ++j)
        {
          NSMutableDictionary *tags;
          OSMPBF__Way *way;
          int32_t node = 0;
          SWPath *path;
          NSPoint *pathPoints;
          MapWay *resultWay;

          way = primitiveGroup->ways[j];

          if (![matchingWays containsIndex:way->id])
            continue;

          tags = [NSMutableDictionary dictionaryWithCapacity:way->n_keys];

          pathPoints = malloc (way->n_refs * sizeof (*pathPoints));

          for (k = 0; k < way->n_refs; ++k)
            {
              NSValue *value;
              NSPoint point;

              node += way->refs[k];

              value = [nodes objectForKey:[NSNumber numberWithUnsignedInteger:node]];

              assert ([matchingNodes containsIndex:node]);
              assert (value);

              point = [value pointValue];

              pathPoints[k] = point;
            }

          assert (way->n_keys == way->n_vals);

          for (k = 0; k < way->n_keys; ++k)
            {
              ProtobufCBinaryData key, value;

              key = primitiveBlock->stringtable->s[way->keys[k]];
              value = primitiveBlock->stringtable->s[way->vals[k]];

              [tags setObject:[[[NSString alloc] initWithBytes:value.data length:value.len encoding:NSUTF8StringEncoding] autorelease]
                       forKey:[[[NSString alloc] initWithBytes:key.data length:key.len encoding:NSUTF8StringEncoding] autorelease]];
            }

          assert ([tags count] == way->n_keys);

          path = [[SWPath alloc] initWithPointsNoCopy:pathPoints
                                               length:way->n_refs];

          resultWay = [[MapWay alloc] initWithPath:path
                                              tags:tags];
          [path release];

          [result setObject:resultWay
                     forKey:[NSNumber numberWithUnsignedInt:way->id]];
          [resultWay release];
        }

      for (j = 0; j < primitiveGroup->n_relations; ++j)
        {
          OSMPBF__Relation *relation;
          NSMutableDictionary *tags;
          int32_t memid = 0;

          relation = primitiveGroup->relations[j];

          tags = [NSMutableDictionary dictionaryWithCapacity:relation->n_keys];

          for (k = 0; k < relation->n_keys; ++k)
            {
              ProtobufCBinaryData key, value;

              key = primitiveBlock->stringtable->s[relation->keys[k]];
              value = primitiveBlock->stringtable->s[relation->vals[k]];

              [tags setObject:[[[NSString alloc] initWithBytes:value.data length:value.len encoding:NSUTF8StringEncoding] autorelease]
                       forKey:[[[NSString alloc] initWithBytes:key.data length:key.len encoding:NSUTF8StringEncoding] autorelease]];
            }

          for (k = 0; k < relation->n_types; ++k)
            {
              MapWay *way;

              memid += relation->memids[k];

              if (relation->types[k] != OSMPBF__RELATION__MEMBER_TYPE__WAY)
                continue;

              if (!(way = [result objectForKey:[NSNumber numberWithUnsignedInt:memid]]))
                continue;

              [way.tags addEntriesFromDictionary:tags];
            }
        }

      [pool release];
    }
}

- (NSRect)bounds
{
  OSMPBF__BlobHeader *blobHeader = NULL;
  const uint8_t *bytes;
  NSUInteger length, offset = 0;
  NSRect result;
  int32_t headerSize;

  result = NSMakeRect(0.0, 0.0, 0.0, 0.0);

  bytes = [fileData bytes];
  length = [fileData length];

  headerSize = ntohl (*(int32_t *) (bytes + offset));
  offset += 4;

  if (offset + headerSize > length)
    return result;

  blobHeader = osmpbf__blob_header__unpack (0, headerSize, bytes + offset);
  offset += headerSize;

  if (offset + blobHeader->datasize > length)
    {
      osmpbf__blob_header__free_unpacked (blobHeader, 0);

      return result;
    }

  if (!strcmp (blobHeader->type, "OSMHeader"))
    {
      OSMPBF__Blob *blob;
      OSMPBF__HeaderBlock *headerBlock;
      NSData *payloadData;

      blob = osmpbf__blob__unpack (0, blobHeader->datasize, bytes + offset);

      if (blob->has_raw)
        {
          payloadData = [NSData dataWithBytesNoCopy:blob->raw.data
                                             length:blob->raw.len
                                       freeWhenDone:NO];
        }
      else if (blob->has_zlib_data)
        {
          payloadData = [NSData dataWithZlibBytes:blob->zlib_data.data
                                           length:blob->zlib_data.len];
        }
      else
        {
          assert (!"unsupported compression scheme");
        }

      assert (payloadData.length == blob->raw_size);

      headerBlock = osmpbf__header_block__unpack (0, payloadData.length, payloadData.bytes);

      result = NSMakeRect (headerBlock->bbox->left * 1.0e-9,
                           headerBlock->bbox->bottom * 1.0e-9,
                           (headerBlock->bbox->right - headerBlock->bbox->left) * 1.0e-9,
                           (headerBlock->bbox->top - headerBlock->bbox->bottom) * 1.0e-9);

      osmpbf__header_block__free_unpacked (headerBlock, 0);
      osmpbf__blob__free_unpacked (blob, 0);
    }

  osmpbf__blob_header__free_unpacked (blobHeader, 0);

  return result;
}

- (NSArray *)waysInRect:(NSRect)realBounds
{
  NSAutoreleasePool *pool;

  NSMutableDictionary *result;
  NSUInteger offset;
  MapDataBounds bounds;

  SWIndexSet *matchingNodes;
  SWIndexSet *matchingWays;
  SWIndexSet *extraNodes;
  const uint8_t *bytes;
  NSUInteger length;
  NSUInteger pass;

  bounds.minLon = (int64_t) (NSMinX (realBounds) * 1.0e9);
  bounds.maxLon = (int64_t) (NSMaxX (realBounds) * 1.0e9);
  bounds.minLat = (int64_t) (NSMinY (realBounds) * 1.0e9);
  bounds.maxLat = (int64_t) (NSMaxY (realBounds) * 1.0e9);

  result = [NSMutableDictionary dictionary];

  pool = [NSAutoreleasePool new];

  bytes = [fileData bytes];
  length = [fileData length];

  matchingNodes = [SWIndexSet indexSet];
  matchingWays = [SWIndexSet indexSet];
  extraNodes = [SWIndexSet indexSet];

  for (pass = 0; pass < 2; ++pass)
    {
      for (offset = 0; offset < length; )
        {
          NSAutoreleasePool *pool;
          int32_t headerSize;

          OSMPBF__BlobHeader *blobHeader;

          pool = [NSAutoreleasePool new];

          headerSize = ntohl (*(int32_t *) (bytes + offset));
          offset += 4;

          assert (offset + headerSize <= length);

          blobHeader = osmpbf__blob_header__unpack (0, headerSize, bytes + offset);
          offset += headerSize;

          assert (offset + blobHeader->datasize <= length);

          if (!strcmp (blobHeader->type, "OSMData"))
            {
              OSMPBF__Blob *blob;
              OSMPBF__PrimitiveBlock *primitiveBlock;
              NSData *payloadData;

              blob = osmpbf__blob__unpack (0, blobHeader->datasize, bytes + offset);

              if (blob->has_raw)
                {
                  payloadData = [NSData dataWithBytesNoCopy:blob->raw.data
                                                     length:blob->raw.len
                                               freeWhenDone:NO];
                }
              else if (blob->has_zlib_data)
                {
                  payloadData = [NSData dataWithZlibBytes:blob->zlib_data.data
                                                   length:blob->zlib_data.len];
                }
              else
                {
                  assert (!"unsupported compression scheme");
                }

              assert (payloadData.length == blob->raw_size);

              primitiveBlock = osmpbf__primitive_block__unpack (0, payloadData.length, payloadData.bytes);

              if (pass == 0)
                {
                  [self _findMatchingNodesInPrimitiveBlock:primitiveBlock
                                                    bounds:&bounds
                                             matchingNodes:matchingNodes
                                              matchingWays:matchingWays
                                                extraNodes:extraNodes];
                }
              else /* pass == 1 */
                {
                  [self _collectNodesAndWays:primitiveBlock
                               matchingNodes:matchingNodes
                                matchingWays:matchingWays
                                      result:result];
                }

              osmpbf__primitive_block__free_unpacked (primitiveBlock, 0);
              osmpbf__blob__free_unpacked (blob, 0);
            }

          offset += blobHeader->datasize;

          osmpbf__blob_header__free_unpacked (blobHeader, 0);

          [pool release];
        }

      if (pass == 0)
        {
          [matchingNodes addIndexes:extraNodes];

          if (!nodes)
            nodes = [NSMutableDictionary dictionaryWithCapacity:matchingNodes.count];
        }
    }

  [pool release];

  return [result allValues];
}
@end
