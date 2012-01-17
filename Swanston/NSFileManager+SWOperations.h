#import <sys/types.h>
#import <dirent.h>

#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>

@interface SWDirectoryEnumerator : NSEnumerator
{
  DIR *dir;
  NSString *base;
  NSString *currentName;
}

- (id)nextObject;

- (NSDictionary *)directoryAttributes;

- (NSDictionary *)fileAttributes;

/**
 * Does nothing
 */
- (void)skipDescendents;
@end

@interface NSFileManager (SWOperations)
- (SWDirectoryEnumerator *)nonRecursiveEnumeratorAtPath:(NSString *)path;
@end
