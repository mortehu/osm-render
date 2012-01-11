#import <assert.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <ctype.h>

#import <Swanston/SWXMLParser.h>

const char* TAGSOUP_NODE_ROOT = "#<ROOT>#";
const char* TAGSOUP_NODE_CONTENT = "#<CONTENT>#";
const char* TAGSOUP_NODE_COMMENT = "#<COMMENT>#";

enum parse_state
{
  s_tag_name,
  s_attrib_delim,
  s_attrib_name,
  s_attrib_value,
  s_content
};

static const struct
{
  int len;
  const char* name;
  int value;
} entities[] =
{
  { 2, "gt", '>' },
  { 2, "lt", '<' },

  { 3, "amp", '&' },

  { 4, "apos", L'\'' },
  { 4, "quot", L'\"' },
};

@implementation SWXMLParser
- (id)init
{
  assert (!"not implemented");
}

- (id)initWithDelegate:(NSObject<SWXMLParserDelegate> *)delegate_
{
  if (!(self = [super init]))
    return nil;

  delegate = delegate_;

  return self;
}

- (void)parseBytes:(const void *)bytes
            length:(NSUInteger)length
{
  BOOL wantsStartElement, wantsLeaveElement, wantsAttributes, wantsCharacters, wantsComments;

  const char* end = (const char *)bytes + length;

  enum parse_state s = s_content;
  const char* i;
  const char* val_begin = bytes;
  const char* val_end = val_begin;
  int quote_char = 0;
  BOOL isClosed = NO;
  int in_cdata = 0;

  const char *attributeName = 0;
  unsigned int attributeNameLength = 0;

  wantsStartElement = [delegate respondsToSelector:@selector (xmlParser:didStartElementWithName:length:)];
  wantsLeaveElement = [delegate respondsToSelector:@selector (xmlParserDidLeaveElement:)];
  wantsAttributes =   [delegate respondsToSelector:@selector (xmlParser:foundAttributeWithName:nameLength:value:valueLength:)];
  wantsCharacters =   [delegate respondsToSelector:@selector (xmlParser:foundCharacters:length:)];
  wantsComments =     [delegate respondsToSelector:@selector (xmlParser:foundComment:length:)];

  i = bytes;

  while(i != end)
    {
      switch(s)
        {
        case s_tag_name:

          /* We have seen a '<'
           * `val_begin' points to the following char
           */

          if((isspace(*i) && i != val_begin) || *i == '>' || (i > val_begin && *i == '/'))
            {
              val_end = i;

              if(val_end != val_begin)
                {
                  unsigned int val_len = val_end - val_begin;

                  if(!isalpha(*val_begin))
                    {
                      if(*val_begin == '/')
                        {
                          ++val_begin;
                          --val_len;

                          if (wantsLeaveElement)
                            [delegate xmlParserDidLeaveElement:self];
                        }
                      else if(*val_begin == '!' && end - val_begin > 3 && val_begin[1] == '-' && val_begin[2] == '-')
                        {
                          const char* comment_end = 0;

                          i = val_begin + 6;

                          if(i >= end)
                            i = end;
                          else
                            {
                              while(i != end && (i[-1] != '-' || i[-2] != '-'))
                                ++i;

                              comment_end = i - 2;

                              while(i != end && i[-1] != '>')
                                ++i;
                            }

                          if(!comment_end)
                            comment_end = i;

                          if (wantsComments)
                            {
                              [delegate xmlParser:self
                                     foundComment:val_begin + 3
                                           length:comment_end - val_begin - 3];
                            }

                          val_begin = i;
                          s = s_content;

                          break;
                        }

                      while (*i != '>' && i != end)
                        ++i;

                      if(i != end)
                        ++i;

                      val_begin = i;
                      s = s_content;

                      break;
                    }

                  if (wantsStartElement)
                    [delegate xmlParser:self didStartElementWithName:val_begin length:(val_end - val_begin)];
                }

              if(*i == '>')
                s = s_content;
              else
                s = s_attrib_delim;

              ++i;
              val_begin = i;
            }
          else
            {
              ++i;
              ++val_end;
            }

          break;

        case s_attrib_delim:

          /* We are inside a '<>' pair, but not in an element name or attribute
           * `val_begin' is undefined
           */

          if(*i == '>')
            {
              if(isClosed && wantsLeaveElement)
                [delegate xmlParserDidLeaveElement:self];

              s = s_content;
              ++i;
              val_begin = i;
            }
          else if(*i == '/')
            {
              isClosed = 1;

              ++i;
            }
          else if(!isspace(*i))
            {
              val_begin = i;
              s = s_attrib_name;
              ++i;
            }
          else
            ++i;

          break;

        case s_attrib_name:

          if(isspace(*i) || *i == '=' || *i == '>' || *i == '/' || *i == '>')
            {
              val_end = i;

              while(i + 1 != end && isspace(*i))
                ++i;

              attributeName = val_begin;
              attributeNameLength = val_end - val_begin;

              if(*i == '/')
                isClosed = 1;

              if(*i == '=')
                {
                  s = s_attrib_value;
                  ++i;
                  while(i != end && isspace(*i))
                    ++i;
                }
              else
                {
                  if(*i == '>')
                    s = s_content;
                  else
                    s = s_attrib_delim;
                  ++i;
                }
              val_begin = i;
            }
          else
            ++i;

          break;

        case s_attrib_value:

          if(i == val_begin)
            {
              if(*i == '"' || *i == '\'')
                {
                  quote_char = *i;
                  ++i;
                  break;
                }
              else
                quote_char = 0;
            }

          if((!quote_char && isspace(*i)) || (quote_char && *i == quote_char) || *i == '>')
            {
              val_end = i;

              if(quote_char && *i != '>')
                ++val_begin;

              if (wantsAttributes)
                {
                  [delegate     xmlParser:self
                   foundAttributeWithName:attributeName
                               nameLength:attributeNameLength
                                    value:val_begin
                              valueLength:(val_end - val_begin)];
                }

              if(*i == '>')
                s = s_content;
              else
                s = s_attrib_delim;
              ++i;
              val_begin = i;
            }
          else
            ++i;

          break;

        case s_content:

          if (in_cdata)
            {
              if(!strncmp(i, "]]>", 3))
                {
                  in_cdata = 0;
                  i += 3;
                }
              else
                ++i;
            }
          else if(*i == '<')
            {
              if(!strncmp(i + 1, "![CDATA[", 8))
                {
                  in_cdata = 1;
                  i += 9;
                }
              else
                {
                  val_end = i;

                  if(val_end != val_begin)
                    {
                      if (wantsCharacters)
                        {
                          [delegate xmlParser:self
                              foundCharacters:val_begin
                                       length:(val_end - val_begin)];
                        }
                    }

                  s = s_tag_name;
                  isClosed = NO;
                  ++i;
                  val_begin = i;
                }
            }
          else
            ++i;

          break;
        }
    }

#if 0
  if(s == s_content && i != val_begin)
    add_content(doc, current_node, val_begin, i, TAGSOUP_NODE_CONTENT);
#endif
}
@end
