#import "include/CSyphon.h"

#import "SyphonCompatibility.h"
#import <Syphon/SyphonMetalClient.h>
#import <Syphon/SyphonServerDirectory.h>

@interface SSYSource ()

@property(nonatomic, readwrite, copy) NSString *uuid;
@property(nonatomic, readwrite, copy) NSString *name;
@property(nonatomic, readwrite, copy) NSString *applicationName;
@property(nonatomic, readwrite, copy) NSDictionary<NSString *, id> *serverDescription;

@end


@implementation SSYSource
@end

NSArray<SSYSource *> *SSYDiscoverSources(void)
{
    NSMutableArray<SSYSource *> *result = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *description in
         [SyphonServerDirectory sharedDirectory].servers) {
        SSYSource *source = [[SSYSource alloc] init];
        source.uuid = description[SyphonServerDescriptionUUIDKey] ?: @"";
        source.name = description[SyphonServerDescriptionNameKey] ?: @"";
        source.applicationName =
            description[SyphonServerDescriptionAppNameKey] ?: @"";
        source.serverDescription = description;
        [result addObject:source];
    }
    return result;
}

@interface SSYClient ()

@property(nonatomic, strong) SyphonMetalClient *client;

@end


@implementation SSYClient

- (instancetype)initWithSource:(SSYSource *)source device:(id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        _client = [[SyphonMetalClient alloc]
            initWithServerDescription:source.serverDescription
                               device:device
                              options:nil
                      newFrameHandler:^(__unused SyphonMetalClient *client) {
                      }];
        if (_client == nil) {
            return nil;
        }
    }
    return self;
}

- (BOOL)isValid
{
    return self.client.isValid;
}

- (BOOL)hasNewFrame
{
    return self.client.hasNewFrame;
}

- (id<MTLTexture>)currentTexture
{
    return [self.client newFrameImage];
}

- (void)stop
{
    [self.client stop];
}

- (void)dealloc
{
    [self stop];
}

@end
