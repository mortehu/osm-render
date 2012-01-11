#import <Foundation/NSObject.h>

@class SWXMLParser;

@protocol SWXMLParserDelegate
@optional

- (void)        xmlParser:(SWXMLParser *)parser
  didStartElementWithName:(const char *)name
                   length:(unsigned int)length;

- (void)xmlParserDidLeaveElement:(SWXMLParser *)parser;

- (void)       xmlParser:(SWXMLParser *)parser
  foundAttributeWithName:(const char *)name
              nameLength:(unsigned int)nameLength
                   value:(const char *)value
             valueLength:(unsigned int)valueLength;

- (void)xmlParser:(SWXMLParser *)parser
  foundCharacters:(const char *)characters
           length:(unsigned int)length;

- (void)xmlParser:(SWXMLParser *)parser
     foundComment:(const char *)comment
           length:(unsigned int)length;
@end

@interface SWXMLParser : NSObject
{
  NSObject<SWXMLParserDelegate> *delegate;
}

- (id)initWithDelegate:(NSObject<SWXMLParserDelegate> *)delegate;

- (void)parseBytes:(const void *)bytes
            length:(NSUInteger)length;
@end
