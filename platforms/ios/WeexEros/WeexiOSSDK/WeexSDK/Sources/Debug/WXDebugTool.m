/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXDebugTool.h"
//#import "WXFPSLabel.h"
#import "WXHandlerFactory.h"
#import "WXNetworkProtocol.h"
#import "WXUtility.h"
#import "WXSDKManager.h"
#import "WXSDKEngine.h"
#import "WXResourceRequest.h"
#import "WXResourceResponse.h"
#import "WXResourceLoader.h"

static BOOL WXIsDebug;
static BOOL WXIsDevToolDebug;
static BOOL WXIsRemoteTracing;
static NSString* WXDebugrepBundleJS;
static NSString* WXDebugrepJSFramework;


@interface WXDebugTool ()
// store service
@property (nonatomic, strong) NSMutableDictionary *jsServiceDic;

@end

@implementation WXDebugTool

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    if(self = [super init]){
        _jsServiceDic = [NSMutableDictionary dictionary];
    }
    return self;
}

//+ (void)showFPS
//{
//    UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
//    WXFPSLabel *label = [[WXFPSLabel alloc] initWithFrame:CGRectMake(window.frame.size.width-135, window.frame.size.height-35, 120, 20)];
//    label.layer.zPosition = MAXFLOAT;
//    [window addSubview:label];
//}

+ (void)setDebug:(BOOL)isDebug
{
    WXIsDebug = isDebug;
}

+ (BOOL)isDebug
{
    return WXIsDebug;
}

+ (void)setDevToolDebug:(BOOL)isDevToolDebug {
    WXIsDevToolDebug = isDevToolDebug;
}

+ (BOOL)isRemoteTracing
{
    return WXIsRemoteTracing;
}

+ (void)setRemoteTracing:(BOOL)isRemoteTracing {
    WXIsRemoteTracing = isRemoteTracing;
}

+ (BOOL)isDevToolDebug {
    return WXIsDevToolDebug;
}

+ (void)setReplacedBundleJS:(NSURL*)url{
    [self getData:url key:@"bundlejs"];
}

+ (NSString*)getReplacedBundleJS{
    return WXDebugrepBundleJS;
}

+ (void)setReplacedJSFramework:(NSURL*)url{
    [self getData:url key:@"jsframework"];
}

+ (NSString*)getReplacedJSFramework{
    
    return WXDebugrepJSFramework;
}

+ (void)getData:(NSURL*)url key:(NSString*)key{
    void(^scriptLoadFinish)(NSString*, NSString*) = ^(NSString* key, NSString* script){
        if ([key isEqualToString:@"jsframework"]) {
            WXDebugrepJSFramework = script;
            [WXSDKEngine restartWithScript:script];
        }else {
            WXDebugrepBundleJS = script;
        }
    };
    if ([url isFileURL]) {
        // File URL
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *path = [url path];
            NSData *scriptData = [[NSFileManager defaultManager] contentsAtPath:path];
            NSString *script = [[NSString alloc] initWithData:scriptData encoding:NSUTF8StringEncoding];
            if (!script || script.length <= 0) {
                NSString *errorDesc = [NSString stringWithFormat:@"File read error at url: %@", url];
                WXLogError(@"%@", errorDesc);
            }
            scriptLoadFinish(key, script);
        });
    } else {
        // HTTP/HTTPS URL
        WXResourceRequest *request = [WXResourceRequest requestWithURL:url resourceType:WXResourceTypeMainBundle referrer:nil cachePolicy:NSURLRequestUseProtocolCachePolicy];
        request.userAgent = [WXUtility userAgent];
        WXResourceLoader *loader = [[WXResourceLoader alloc] initWithRequest:request];
        
        loader.onFinished = ^(const WXResourceResponse * response, NSData *data) {
            if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode != 200) {
                __unused NSError *error = [NSError errorWithDomain:WX_ERROR_DOMAIN
                                                              code:((NSHTTPURLResponse *)response).statusCode
                                                          userInfo:@{@"message":@"status code error."}];
                
                return ;
            }
            
            NSString * script = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            scriptLoadFinish(key, script);
        };
        
        [loader start];
    }
}

+ (BOOL) cacheJsService: (NSString *)name withScript: (NSString *)script withOptions: (NSDictionary *) options
{
    if(WXIsDebug) {
        [[[self sharedInstance] jsServiceDic] setObject:@{ @"name": name, @"script": script, @"options": options } forKey:name];
        return YES;
    }else {
        return NO;
    }
}

+ (BOOL) removeCacheJsService: (NSString *)name
{
    if(WXIsDebug) {
        [[[self sharedInstance] jsServiceDic] removeObjectForKey:name];
        return YES;
    }else {
        return NO;
    }
}

+ (NSDictionary *) jsServiceCache
{
    return [NSDictionary dictionaryWithDictionary:[[self sharedInstance] jsServiceDic]];
}

@end
