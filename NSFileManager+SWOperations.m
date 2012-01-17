#import <errno.h>

#import <Foundation/NSError.h>
#import <Foundation/NSFileManager.h>
#import <Swanston/NSFileManager+SWOperations.h>

@implementation SWDirectoryEnumerator
- (id)initWithPath:(NSString *)path
{
  if (!(self = [super init]))
    return nil;

  dir = opendir ([[NSFileManager defaultManager] fileSystemRepresentationWithPath:path]);

  if (!dir)
    {
      NSLog(@"Failed to open directory '%@' - %s", path,
            strerror (errno));

      return self;
    }

  base = [path retain];

  return self;
}

- (void)dealloc
{
  closedir (dir);
  [currentName release];
  [base release];
  [super dealloc];
}

- (id)nextObject
{
  struct dirent *ent;

  if (!dir)
    return nil;

  [currentName release];
  currentName = nil;

  do
    ent = readdir (dir);
  while (ent
         && (ent->d_name[0] == '.'
             && (!ent->d_name[1]
                 || (ent->d_name[1] == '.' && !ent->d_name[2]))));

  if (!ent)
    return nil;

  currentName = [[[NSFileManager defaultManager] stringWithFileSystemRepresentation:ent->d_name
                                                                             length:strlen(ent->d_name)] retain];

  return currentName;
}

- (NSDictionary *)directoryAttributes
{
  return [[NSFileManager defaultManager] attributesOfItemAtPath:base error:0];
}

- (NSDictionary *)fileAttributes
{
  return [[NSFileManager defaultManager] attributesOfItemAtPath:[base stringByAppendingPathComponent:currentName] error:0];
}

- (void)skipDescendents
{
}
@end

@implementation NSFileManager (SWOperations)
- (SWDirectoryEnumerator *)nonRecursiveEnumeratorAtPath:(NSString *)path
{
  return [[[SWDirectoryEnumerator alloc] initWithPath:path] autorelease];
}
@end
