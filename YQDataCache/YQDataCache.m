//
//  YQDataCache.m
//  Demo
//
//  Created by maygolf on 17/1/6.
//  Copyright © 2017年 yiquan. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonCryptor.h>

#import "YQDataCache.h"

static NSString * const kYQDataCacheRootDirectory = @"YQDataCache";
static NSString * const kYQDataCacheSpaceDefault = @"default";

@interface YQDataCache ()

@property (nonatomic, strong) NSString *basePath;                   // 基目录
@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) dispatch_queue_t cacheQuery;          // 存储队列
@property (nonatomic, strong) NSFileManager *asynFileManager;

@end

@implementation YQDataCache

#pragma mark - init

- (instancetype)init{
    return [self initWithCacheSpace:kYQDataCacheSpaceDefault];
}

/**
 根据缓存空间初始化一个缓存对象
 
 @param cacheSpace 缓存空间，文件夹名称（非完整路径），以后获取文件或者缓存文件都存储在此文件夹下, 当其为nil时，文件直接存在YQDataCache下
 @return 返回一个缓存实例
 */
- (instancetype)initWithCacheSpace:(NSString *)cacheSpace{
    if (self = [super init]) {
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        self.basePath = [documentsPath stringByAppendingPathComponent:kYQDataCacheRootDirectory];
        if (cacheSpace.length) {
            self.basePath = [self.basePath stringByAppendingPathComponent:cacheSpace];
        }
        
        self.memoryCache = [[NSCache alloc] init];
        self.cacheQuery = dispatch_queue_create("com.YQDataCache.YQDataCache", DISPATCH_QUEUE_SERIAL);
        dispatch_async(self.cacheQuery, ^{
            self.asynFileManager = [[NSFileManager alloc] init];
        });
    }
    return self;
}
// 创建一个以@"Default"为缓存空间的单一缓存实例
+ (instancetype)sharedInstance{
    static YQDataCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

#pragma mark - private
// fileManager的创建线程必须和该方法的调用线程相同
- (BOOL)storeData:(NSData *)data forKey:(NSString *)key storeMemory:(BOOL)storeMemory withManager:(NSFileManager *)fileManager error:(NSError **)error{
    if (data.length <= 0) {
        *error = [NSError errorWithDomain:@"data为空" code:0 userInfo:nil];
        return NO;
    }
    
    NSString *fileName = [self fileNameFromKey:key];
    if (fileName.length <= 0) {
        *error = [NSError errorWithDomain:@"key错误" code:0 userInfo:nil];
        return NO;
    }
    
    if (storeMemory) {
        [self.memoryCache setObject:data forKey:fileName];
    }
    
    if (fileManager == nil) {
        fileManager = [NSFileManager defaultManager];
    }
    
    if (![fileManager fileExistsAtPath:self.basePath]) {
        [fileManager createDirectoryAtPath:self.basePath withIntermediateDirectories:YES attributes:nil error:error];
    }
    
    NSString *filePath = [self filePathFromFileName:fileName];
    return [fileManager createFileAtPath:filePath contents:data attributes:nil];
}

- (BOOL)removeDataForKey:(NSString *)key withManager:(NSFileManager *)fileManager error:(NSError **)error{
    
    NSString *fileName = [self fileNameFromKey:key];
    if (fileName.length <= 0) {
        *error = [NSError errorWithDomain:@"key错误" code:0 userInfo:nil];
        return NO;
    }
    
    [self.memoryCache removeObjectForKey:fileName];
    
    if (fileManager == nil) {
        fileManager = [NSFileManager defaultManager];
    }
    
    NSString *filePath = [self filePathFromFileName:fileName];
    if (![fileManager fileExistsAtPath:filePath]) {
        return YES;
    }
    return [fileManager removeItemAtPath:filePath error:error];
}

- (BOOL)clearDataWithManager:(NSFileManager *)fileManager error:(NSError **)error{
    
    [self.memoryCache removeAllObjects];
    
    if (fileManager == nil) {
        fileManager = [NSFileManager defaultManager];
    }
    
    if (![fileManager fileExistsAtPath:self.basePath]) {
        return YES;
    }
    return [fileManager removeItemAtPath:self.basePath error:error];
}

- (NSData *)dataForKey:(NSString *)key withManager:(NSFileManager *)fileManager error:(NSError **)error{
    
    NSData *resultData = nil;
    
    NSString *fileName = [self fileNameFromKey:key];
    if (fileName.length <= 0) {
        *error = [NSError errorWithDomain:@"key错误" code:0 userInfo:nil];
        return nil;
    }
    
    resultData = [self.memoryCache objectForKey:fileName];
    if (resultData) {
        return resultData;
    }
    
    if (fileManager == nil) {
        fileManager = [NSFileManager defaultManager];
    }
    
    NSString *filePath = [self filePathFromFileName:fileName];
    if (![fileManager fileExistsAtPath:filePath]) {
        *error = [NSError errorWithDomain:@"文件不存在" code:0 userInfo:nil];
    }
    
    resultData = [NSData dataWithContentsOfFile:filePath];
    if (resultData == nil) {
        *error = [NSError errorWithDomain:@"获取数据失败" code:0 userInfo:nil];
    }
    
    return resultData;
}

- (NSUInteger)fileSize:(NSString *)filePath withManager:(NSFileManager *)fileManager error:(NSError **)error{
    
    if (filePath.length <= 0) {
        *error = [NSError errorWithDomain:@"文件目录错误" code:0 userInfo:nil];
        return 0;
    }
    
    if (!fileManager) {
        fileManager = [NSFileManager defaultManager];
    }
    
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:filePath isDirectory:&isDirectory]) {
        *error = [NSError errorWithDomain:@"文件不存在" code:0 userInfo:nil];
        return 0;
    }
    
    if (!isDirectory) {
        NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error:error];
        return [attrs fileSize];
    }
    
    NSUInteger resultSize = 0;
    NSDirectoryEnumerator *fileEnumerator = [fileManager enumeratorAtPath:filePath];
    for (NSString *fileName in fileEnumerator) {
        NSString *subFilePath = [filePath stringByAppendingPathComponent:fileName];
        resultSize += [self fileSize:subFilePath withManager:fileManager error:error];
    }
    
    return resultSize;
}

#pragma mark - path and key
// 从一个key得到一个文件名
- (NSString *)fileNameFromKey:(NSString *)key{
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [key.pathExtension isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", key.pathExtension]];
    
    return filename;
}

// 从一个key得到一个文件目录
- (NSString *)filePathFromKey:(NSString *)key{
    return [self filePathFromFileName:[self filePathFromKey:key]];
}
// 从文件名得到文件路径
- (NSString *)filePathFromFileName:(NSString *)fileName{
    return [self.basePath stringByAppendingPathComponent:fileName];
}

#pragma mark - cache and fetch
// 同步缓存数据
- (BOOL)storeData:(NSData *)data forKey:(NSString *)key storeMemory:(BOOL)storeMemory{
    return [self storeData:data forKey:key storeMemory:storeMemory withManager:nil error:NULL];
}
// 异步缓存数据
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
      storeMemory:(BOOL)storeMemory
       completion:(YQDataWriteCompletion)completion{
    dispatch_async(self.cacheQuery, ^{
        NSError *error = nil;
        BOOL success = [self storeData:data forKey:key storeMemory:storeMemory withManager:self.asynFileManager error:&error];
        
        if (completion) {
            completion(success, error);
        }
    });
}

// 同步删除数据
- (BOOL)removeDataForKey:(NSString *)key{
    return [self removeDataForKey:key withManager:nil error:NULL];
}
// 异步删除数据
- (void)removeDataForKey:(NSString *)key completion:(YQDataWriteCompletion)completion{
    dispatch_async(self.cacheQuery, ^{
        NSError *error = nil;
        BOOL success = [self removeDataForKey:key withManager:self.asynFileManager error:&error];
        if (completion) {
            completion(success, error);
        }
    });
}

// 同步清除所有数据（basePath下的所有文件）
- (BOOL)clearData{
    return [self clearDataWithManager:nil error:NULL];
}
// 异步清除所有文件
- (void)clearData:(YQDataWriteCompletion)completion{
    dispatch_async(self.cacheQuery, ^{
        NSError *error = nil;
        BOOL success = [self clearDataWithManager:self.asynFileManager error:&error];
        if (completion) {
            completion(success, error);
        }
    });
}

// 同步获取数据
- (NSData *)dataForKey:(NSString *)key{
    return [self dataForKey:key withManager:nil error:NULL];
}
// 异步获取数据
- (void)dataForKey:(NSString *)key completion:(YQDataReadCompletion)completion{
    dispatch_async(self.cacheQuery, ^{
        NSError *error = nil;
        NSData *resultData = [self dataForKey:key withManager:self.asynFileManager error:&error];
        if (completion) {
            completion(resultData, error);
        }
    });
}

// 获取缓存大小
- (NSUInteger)cacheSize{
    return [self fileSize:self.basePath withManager:nil error:NULL];
}
- (void)cacheSizeCompletion:(void(^)(NSUInteger size, NSError *error))completion{
    dispatch_async(self.cacheQuery, ^{
        NSError *error = nil;
        NSUInteger size = [self fileSize:self.basePath withManager:self.asynFileManager error:&error];
        if (completion) {
            completion(size, error);
        }
    });
}

@end
