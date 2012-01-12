#import <ctype.h>
#import <err.h>
#import <stdlib.h>
#import <string.h>

#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Swanston/NSMutableArray+SWJSONStreamDelegate.h>
#import <Swanston/NSMutableDictionary+SWJSONStreamDelegate.h>
#import <Swanston/SWJSONStream.h>

enum StackItem
{
  Object,
  Array
};

static size_t
decodeString (char **result, const char *input, const char *end)
{
  unsigned int ch;
  const char *c, *string_end;
  unsigned char *o;

  c = input;

  if (*c != '"')
    return 0;

  string_end = ++c;

  while (string_end != end && *string_end != '"')
    {
      if (*string_end == '\\' && string_end + 1 != end)
        string_end += 2;
      else
        ++string_end;
    }

  if (string_end == end)
    return 0;

  *result = malloc (string_end - c + 1);

  if (!*result)
    return 0;

  o = (unsigned char *) *result;

  while (c != string_end)
    {
      switch (*c)
        {
        case '\\':

          ++c;

          switch (*c++)
            {
            case '0': ch = strtol (c, (char **) &c, 8); break;
            case '"': ch = '"'; break;
            case '/': ch = '/'; break;
            case 'a': ch = '\a'; break;
            case 'b': ch = '\b'; break;
            case 't': ch = '\t'; break;
            case 'n': ch = '\n'; break;
            case 'v': ch = '\v'; break;
            case 'f': ch = '\f'; break;
            case 'r': ch = '\r'; break;
            case 'u': sscanf (c, "%04x", &ch); c += 4; break;
            case '\\': ch = '\\'; break;
            default:
              break;
            }

          if (ch < 0x80)
            *o++ = ch;
          else if (ch < 0x800)
            {
              *o++ = (0xc0 | (ch >> 6));
              *o++ = (0x80 | (ch & 0x3f));
            }
          else if (ch < 0x10000)
            {
              *o++ = (0xe0 | (ch >> 12));
              *o++ = (0x80 | ((ch >> 6) & 0x3f));
              *o++ = (0x80 | (ch & 0x3f));
            }
          else if (ch < 0x200000)
            {
              *o++ = (0xf0 | (ch >> 18));
              *o++ = (0x80 | ((ch >> 12) & 0x3f));
              *o++ = (0x80 | ((ch >> 6) & 0x3f));
              *o++ = (0x80 | (ch & 0x3f));
            }
          else if (ch < 0x4000000)
            {
              *o++ = (0xf8 | (ch >> 24));
              *o++ = (0x80 | ((ch >> 18) & 0x3f));
              *o++ = (0x80 | ((ch >> 12) & 0x3f));
              *o++ = (0x80 | ((ch >> 6) & 0x3f));
              *o++ = (0x80 | (ch & 0x3f));
            }
          else
            {
              *o++ = (0xfc | (ch >> 30));
              *o++ = (0x80 | ((ch >> 24) & 0x3f));
              *o++ = (0x80 | ((ch >> 18) & 0x3f));
              *o++ = (0x80 | ((ch >> 12) & 0x3f));
              *o++ = (0x80 | ((ch >> 6) & 0x3f));
              *o++ = (0x80 | (ch & 0x3f));
            }

          break;

        default:

          *o++ = *c++;
        }
    }

  *o = 0;

  return string_end - input + 1;
}

@implementation NSObject (SWJSONStreamDelegate)
- (id)parseObjectWithName:(const char *)name
{
  return nil;
}

- (id)parseArrayWithName:(const char *)name
{
  return nil;
}

- (void)parseStringWithName:(const char *)name value:(const char *)value
{
}

- (void)parseNumberWithName:(const char *)name value:(double)value
{
}

- (void)parseBooleanWithName:(const char *)name value:(BOOL)value
{
}

- (void)parseNullWithName:(const char *)name
{
}

- (void)parseEnd
{
}
@end

@implementation SWJSONStream
- (id)init
{
  if (!(self = [super init]))
    return nil;

  buffer = [[NSMutableData alloc] init];

  return self;
}

- (id)delegate
{
  return delegateStack[0];
}

- (void)setDelegate:(id)delegate
{
  [delegateStack[0] release];
  delegateStack[0] = [delegate retain];
}

- (void)consumeData:(NSData *)newData
{
  size_t skip;
  const char *c, *end;

  [buffer appendData:newData];

  c = [buffer bytes];
  end = c + [buffer length];

  while (c != end)
    {
      if (isspace (*c))
        {
          ++c;

          continue;
        }

      switch (*c)
        {
        case '}':

          if (!sp || stack[sp - 1] != Object
              || key)
            {
              errx (EXIT_FAILURE, "Unexpected '}'");

              return;
            }

          [delegateStack[sp] parseEnd];
          [delegateStack[sp] release];
          --sp;
          ++c;
          expectedDelimiter = ',';

          continue;

        case ']':

          if (!sp || stack[sp - 1] != Array)
            {
              errx (EXIT_FAILURE, "Unexpected ']'");

              return;
            }

          [delegateStack[sp] parseEnd];
          [delegateStack[sp] release];
          --sp;
          ++c;
          expectedDelimiter = ',';

          continue;
        }

      if (expectedDelimiter)
        {
          if (*c != expectedDelimiter)
            {
              errx (EXIT_FAILURE, "Incorrect delimiter");

              return;
            }

          expectedDelimiter = 0;
          ++c;

          continue;
        }

      if (sp
          && stack[sp - 1] == Object
          && !key)
        {
          skip = decodeString (&key, c, end);

          if (!skip)
            break;

          c += skip;
          expectedDelimiter = ':';

          continue;
        }

      switch (*c)
        {
        case '{':

          if (sp == sizeof (stack) / sizeof (stack[0]))
            {
              errx (EXIT_FAILURE, "Stack exhausted");

              return;
            }

          stack[sp++] = Object;
          delegateStack[sp] = [[delegateStack[sp - 1] parseObjectWithName:key] retain];

          expectedDelimiter = 0;

          ++c;

          break;

        case '[':

          if (sp == sizeof (stack) / sizeof (stack[0]))
            {
              errx (EXIT_FAILURE, "Stack exhausted");

              return;
            }

          stack[sp++] = Array;
          delegateStack[sp] = [[delegateStack[sp - 1] parseArrayWithName:key] retain];

          expectedDelimiter = 0;

          ++c;

          break;

        case 't':

          if (c + 4 > end)
            goto done;

          if (memcmp (c, "true", 4))
            {
              errx (EXIT_FAILURE, "Unrecognized value");

              return;
            }

          [delegateStack[sp] parseBooleanWithName:key value:1];

          c += 4;

          expectedDelimiter = ',';

          break;

        case 'f':

          if (c + 5 > end)
            goto done;

          if (memcmp (c, "false", 5))
            {
              errx (EXIT_FAILURE, "Unrecognized value");

              return;
            }

          [delegateStack[sp] parseBooleanWithName:key value:0];

          c += 5;

          expectedDelimiter = ',';

          break;

        case 'n':

          if (c + 4 > end)
            goto done;

          if (memcmp (c, "null", 4))
            {
              errx (EXIT_FAILURE, "Unrecognized value");

              return;
            }

          [delegateStack[sp] parseNullWithName:key];

          c += 4;

          expectedDelimiter = ',';

          break;

        case '\"':

          {
            char *string;
            skip = decodeString (&string, c, end);

            if (!skip)
              goto done;

            c += skip;

            [delegateStack[sp] parseStringWithName:key value:string];

            free (string);

            expectedDelimiter = ',';
          }

          break;

        case '-': case '0': case '1': case '2': case '3': case '4': case '5':
        case '6': case '7': case '8': case '9':

          /* XXX: Doesn't work if entire response is a number */

          if (memchr (c, ',', end - c) || memchr (c, '}', end - c) || memchr (c, ']', end - c))
            [delegateStack[sp] parseNumberWithName:key value:strtod (c, (char **) &c)];
          else
            goto done;

          expectedDelimiter = ',';

          break;

        default:

          errx (EXIT_FAILURE, "Unrecognized value");

          return;
        }

      free (key);
      key = 0;
    }

done:

  memmove ([buffer mutableBytes], c, end - c);
  [buffer setLength:end - c];
}

- (void)consumeError:(const char*)message
{
}

- (void)consumeEnd
{
  while (sp)
    {
      [delegateStack[sp] release];
      [delegateStack[sp--] parseEnd];
    }

  free (key);
  key = 0;
}

- (void)dealloc
{
  [buffer release];
  [delegateStack[0] release];
  free (key);
  [super dealloc];
}
@end

@implementation SWJSONStreamParser
@synthesize result;

- (id)parseObjectWithName:(const char *)name
{
  NSMutableDictionary *newDictionary;

  newDictionary = [[NSMutableDictionary alloc] init];

  result = newDictionary;

  return newDictionary;
}

- (id)parseArrayWithName:(const char *)name
{
  NSMutableArray *newArray;

  newArray = [[NSMutableArray alloc] init];

  result = newArray;

  return newArray;
}

- (void)parseStringWithName:(const char *)name value:(const char *)value
{
  result = [NSString stringWithUTF8String:value];
}

- (void)parseNumberWithName:(const char *)name value:(double)value
{
  result = [NSNumber numberWithDouble:value];
}

- (void)parseBooleanWithName:(const char *)name value:(BOOL)value
{
  result = [NSNumber numberWithBool:value];
}

- (void)parseNullWithName:(const char *)name
{
  result = [NSNull null];
}
@end
