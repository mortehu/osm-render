/************************************************************************

   json-stream.h: Stream-parser for JSON -- uses O(1) memory

                  Similar to SAX for XML

   Copyright (C) 2011  Morten Hustveit <morten.hustveit@gmail.com>

 ************************************************************************/

#import <stdio.h>

#import <Foundation/NSObject.h>
#import <Swanston/SWConsumer.h>

@interface NSObject (SWJSONStreamDelegate)
- (id)parseObjectWithName:(const char *)name;

- (id)parseArrayWithName:(const char *)name;

- (void)parseStringWithName:(const char *)name
                      value:(const char *)value;

- (void)parseNumberWithName:(const char *)name
                      value:(double)value;

- (void)parseBooleanWithName:(const char *)name
                       value:(BOOL)value;

- (void)parseNullWithName:(const char *)name;

- (void)parseEnd;
@end

@interface SWJSONStream : NSObject <SWConsumer>
{
  NSMutableData *buffer;

  char *key;

  unsigned int sp;
  unsigned int stack[16];
  id delegateStack[16];

  int expectedDelimiter;
}

@property (nonatomic,assign) id delegate;

- (void)consumeData:(NSData *)data;
- (void)consumeError:(const char*)message;
- (void)consumeEnd;
@end

@interface SWJSONStreamParser : NSObject
{
  NSObject *result;
}

@property (retain) NSObject *result;

- (id)parseObjectWithName:(const char *)name;

- (id)parseArrayWithName:(const char *)name;

- (void)parseStringWithName:(const char *)name
                      value:(const char *)value;

- (void)parseNumberWithName:(const char *)name
                      value:(double)value;

- (void)parseBooleanWithName:(const char *)name
                       value:(BOOL)value;

- (void)parseNullWithName:(const char *)name;
@end
