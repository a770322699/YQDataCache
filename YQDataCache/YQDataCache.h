//
//  YQDataCache.h
//  Demo
//
//  Created by maygolf on 17/1/6.
//  Copyright © 2017年 yiquan. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^YQDataWriteCompletion)(BOOL success, NSError *error);
typedef void(^YQDataReadCompletion)(NSData *data, NSError *error);

/**
 缓存对象，基本路径为Docments下的YQDataCache文件夹,初始化指定的文件夹名称会设置为YQDataCache的子目录
 */
@interface YQDataCache : NSObject

@property (nonatomic, readonly) NSString *basePath;                   // 基目录

#pragma mark - init
/**
 根据缓存空间初始化一个缓存对象

 @param cacheSpace 缓存空间，文件夹名称（非完整路径），以后获取文件或者缓存文件都存储在此文件夹下, 当其为nil时，文件直接存在YQDataCache下
 @return 返回一个缓存实例
 */
- (instancetype)initWithCacheSpace:(NSString *)cacheSpace NS_DESIGNATED_INITIALIZER;
// 创建一个以@"Default"为缓存空间的单一缓存实例
+ (instancetype)sharedInstance;

#pragma mark - path and key
// 从一个key得到一个文件名
- (NSString *)fileNameFromKey:(NSString *)key;
// 从一个key得到一个文件目录
- (NSString *)filePathFromKey:(NSString *)key;
// 从文件名得到文件路径
- (NSString *)filePathFromFileName:(NSString *)fileName;

#pragma mark - cache and fetch
// 同步缓存数据
- (BOOL)storeData:(NSData *)data forKey:(NSString *)key storeMemory:(BOOL)storeMemory;
// 异步缓存数据
- (void)storeData:(NSData *)data
           forKey:(NSString *)key
      storeMemory:(BOOL)storeMemory
       completion:(YQDataWriteCompletion)completion;

// 同步删除数据
- (BOOL)removeDataForKey:(NSString *)key;
// 异步删除数据
- (void)removeDataForKey:(NSString *)key completion:(YQDataWriteCompletion)completion;

// 同步清除所有数据（basePath下的所有文件）
- (BOOL)clearData;
// 异步清除所有文件
- (void)clearData:(YQDataWriteCompletion)completion;

// 同步获取数据
- (NSData *)dataForKey:(NSString *)key;
// 异步获取数据
- (void)dataForKey:(NSString *)key completion:(YQDataReadCompletion)completion;

// 获取缓存大小
- (NSUInteger)cacheSize;
// 异步获取缓存大小
- (void)cacheSizeCompletion:(void(^)(NSUInteger size, NSError *error))completion;

@end
