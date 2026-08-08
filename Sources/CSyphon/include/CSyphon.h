#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSYSource : NSObject

@property(nonatomic, readonly, copy) NSString *uuid;
@property(nonatomic, readonly, copy) NSString *name;
@property(nonatomic, readonly, copy) NSString *applicationName;

@end

FOUNDATION_EXPORT NSArray<SSYSource *> *SSYDiscoverSources(void);

@interface SSYClient : NSObject

- (nullable instancetype)initWithSource:(SSYSource *)source
                                 device:(id<MTLDevice>)device;

@property(nonatomic, readonly, getter=isValid) BOOL valid;
@property(nonatomic, readonly) BOOL hasNewFrame;

- (nullable id<MTLTexture>)currentTexture;
- (void)stop;

@end


NS_ASSUME_NONNULL_END
