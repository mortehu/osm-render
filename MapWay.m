#import <Foundation/NSDictionary.h>
#import <Swanston/SWPath.h>
#import <MapData.h>

@implementation MapWay
@synthesize path, tags;

- (id)initWithPath:(SWPath *)path_
              tags:(NSDictionary *)tags_
{
  if (!(self = [super init]))
    return nil;

  path = [path_ retain];
  tags = [tags_ retain];

  return self;
}

- (void)dealloc
{
  [tags release];
  [path release];
  [super dealloc];
}
@end
