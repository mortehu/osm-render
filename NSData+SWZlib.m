#import <zlib.h>

#import <Swanston/NSData+SWZlib.h>

@implementation NSData (SWZlib)
+ (id)dataWithZlibBytes:(const void *)bytes
                 length:(NSUInteger)length
{
  return [[[self alloc] initWithZlibBytes:bytes
                                   length:length] autorelease];
}

+ (id)dataWithZlibData:(NSData *)data
{
  return [[[self alloc] initWithZlibData:data] autorelease];
}

- (id)initWithZlibBytes:(const void *)bytes
                 length:(NSUInteger)length
{
  z_stream z;
  unsigned char *buffer;
  NSUInteger capacity;
  int err;

  memset (&z, 0, sizeof (z));

  z.next_in = (Bytef *) bytes;
  z.avail_in = length;

  capacity = z.avail_in;

  if (!(buffer = malloc (capacity)))
    return nil;

  z.next_out  = (Bytef *) buffer;
  z.avail_out = capacity;

  if (inflateInit(&z) != Z_OK)
    goto fail;

  for (;;)
    {
      unsigned char *newBuffer;
      NSUInteger newCapacity;

      err = inflate(&z, Z_FULL_FLUSH);

      if (err == Z_STREAM_END)
        break;

      if (err != Z_OK)
        goto fail;

      newCapacity = (capacity * 3 / 2 + 0x1000) & ~0xfff;
      newBuffer = realloc (buffer, newCapacity);

      if (!newBuffer)
        goto fail;

      capacity = newCapacity;
      buffer = newBuffer;

      z.next_out = buffer + z.total_out;
      z.avail_out = capacity - z.total_out;
    }

  if (inflateEnd(&z) != Z_OK)
    goto fail;

  if (!(self = [self initWithBytesNoCopy:buffer
                                  length:z.total_out
                            freeWhenDone:YES]))
    return nil;

  return self;

fail:

  NSLog (@"Failed! err = %d", err);

  free (buffer);

  return nil;
}

- (id)initWithZlibData:(NSData *)data
{
  return [self initWithBytes:data.bytes
                      length:data.length];
}

@end
