//
//  TConfig.m
//  MicroTransfer
//
//  Created by jacksonpan on 13-1-21.
//  Copyright (c) 2013年 weichuan. All rights reserved.
//

#import "TConfig.h"
#import "FMDatabase.h"

#define TConfig_DATABASE_NAME                      @"TConfig.db"
#define TConfig_V2_TABLE_NAME                      @"configV2"

#define TConfig_VALUE_TYPE_INT                     @"int"
#define TConfig_VALUE_TYPE_BOOL                    @"bool"
#define TConfig_VALUE_TYPE_FLOAT                   @"float"
#define TConfig_VALUE_TYPE_STRING                  @"string"

typedef enum _ENUM_TConfig_TYPE
{
    ENUM_TConfig_TYPE_NONE = 0,
    ENUM_TConfig_TYPE_INT = 2,
    ENUM_TConfig_TYPE_BOOL = 3,
    ENUM_TConfig_TYPE_FLOAT = 4,
    ENUM_TConfig_TYPE_STRING = 5,
}ENUM_TConfig_TYPE;

@interface TConfig ()
{
    __strong FMDatabase* dbPointer;
    __strong NSDictionary* defaultValue;
}
@end

@implementation TConfig
static TConfig* static_config = nil;
+ (TConfig*)current
{
    @synchronized(self)
    {
        if(static_config == nil)
        {
            static_config = [[TConfig alloc] init];
        }
        return static_config;
    }
}

- (void)initForDB
{
    //	NSLog(@"%@",NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES));
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSArray* rs = [TConfig_DATABASE_NAME componentsSeparatedByString:@"."];
    NSString *realPath = [documentPath stringByAppendingPathComponent:TConfig_DATABASE_NAME];
    
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:[rs objectAtIndex:0] ofType:[rs objectAtIndex:1]];
    
    //NSLog(@"realPath:%@",realPath);
    //NSLog(@"sourcePath:%@", sourcePath);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:realPath])
        //	[fileManager removeItemAtPath:realPath error:nil];
    {
        NSError *error;
        if (![fileManager copyItemAtPath:sourcePath toPath:realPath error:&error]) {
            NSLog(@"%@",[error localizedDescription]);
        }
    }
    
    //NSLog(@"复制sqlite到路径：%@成功。",realPath);
    
    dbPointer = [FMDatabase databaseWithPath:realPath];
    //dbPointer.traceExecution = YES;
}

- (void)open
{
    [dbPointer open];
}

- (void)close
{
    [dbPointer close];
}

- (id)init
{
    self = [super init];
    if(self)
    {
        [self initForDB];
    }
    return self;
}

- (void)clear
{
    [self open];
    [dbPointer executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@", TConfig_V2_TABLE_NAME]];
    [self close];
}

- (void)cpDBToDesktop
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *realPath = [documentPath stringByAppendingPathComponent:TConfig_DATABASE_NAME];
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError* er = nil;
    NSString* dst = [NSString stringWithFormat:@"/Users/jacksonpan/Desktop/%@", TConfig_DATABASE_NAME];
    if([fm fileExistsAtPath:dst])
    {
        [fm removeItemAtPath:dst error:&er];
        if(er)
        {
            NSLog(@"err:%@", er);
        }
    }
    [fm copyItemAtPath:realPath toPath:dst error:&er];
}

- (BOOL)existObjectForKey:(NSString*)defaultName
{
    return [self objectForKey:defaultName]?YES:NO;
}

- (id)objectForKey:(NSString *)defaultName
{
    [self open];
    id object = nil;
    NSString* sql = [NSString stringWithFormat:@"select * from %@ where key = '%@'", TConfig_V2_TABLE_NAME, defaultName];
    FMResultSet* rs = [dbPointer executeQuery:sql];
    while ([rs next])
    {
        NSString* type = [rs objectForColumnIndex:1];
        object = [rs objectForColumnName:[NSString stringWithFormat:@"value_%@", type]];
    }
    [rs close];
    [self close];
    
    return object;
}

- (NSString*)getTypeStringWithType:(ENUM_TConfig_TYPE)type
{
    NSString* ret = nil;
    switch (type) {
        case ENUM_TConfig_TYPE_INT:
            ret = TConfig_VALUE_TYPE_INT;
            break;
        case ENUM_TConfig_TYPE_BOOL:
            ret = TConfig_VALUE_TYPE_BOOL;
            break;
        case ENUM_TConfig_TYPE_FLOAT:
            ret = TConfig_VALUE_TYPE_FLOAT;
            break;
        case ENUM_TConfig_TYPE_STRING:
            ret = TConfig_VALUE_TYPE_STRING;
            break;
        default:
            break;
    }
    return ret;
}

- (NSString*)objectTypeWithTypeString:(NSString*)typeString
{
    if(typeString == nil)
    {
        return nil;
    }
    return [NSString stringWithFormat:@"value_%@", typeString];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
    ENUM_TConfig_TYPE type = ENUM_TConfig_TYPE_NONE;
    if([value isKindOfClass:[NSNumber class]])
    {
        const char* t = [value objCType];
        NSString* tt = [NSString stringWithCString:t encoding:NSUTF8StringEncoding];
        //NSLog(@"%@", tt);
        if([tt isEqualToString:@"c"])
        {
            type = ENUM_TConfig_TYPE_BOOL;
        }
        else if([tt isEqualToString:@"f"])
        {
            type = ENUM_TConfig_TYPE_FLOAT;
        }
        else if([tt isEqualToString:@"i"])
        {
            type = ENUM_TConfig_TYPE_INT;
        }
    }
    else if([value isKindOfClass:[NSString class]])
    {
        type = ENUM_TConfig_TYPE_STRING;
    }
    else if([value isKindOfClass:[NSNull class]])
    {
        type = ENUM_TConfig_TYPE_STRING;
    }
    
    NSString* sql = nil;
    if([self existObjectForKey:defaultName])
    {
        sql = [NSString stringWithFormat:@"update %@ set %@ = ? WHERE key = '%@'", TConfig_V2_TABLE_NAME, [self objectTypeWithTypeString:[self getTypeStringWithType:type]], defaultName];
    }
    else
    {
        sql = [NSString stringWithFormat:@"insert into %@ (key, objectType, %@) VALUES ('%@','%@',?)", TConfig_V2_TABLE_NAME, [self objectTypeWithTypeString:[self getTypeStringWithType:type]], defaultName, [self getTypeStringWithType:type]];
    }
    //NSLog(@"sql:%@",sql);
    [self open];
    /*BOOL ret = *///[dbPointer executeUpdate:sql];
    [dbPointer executeUpdate:sql, value];
    //NSLog(@"setObject:%d", ret);
    [self close];
}

- (void)removeObjectForKey:(NSString *)defaultName
{
    NSString* sql = [NSString stringWithFormat:@"delete from %@ where key = '%@'", TConfig_V2_TABLE_NAME, defaultName];
    [self open];
    /*BOOL ret = */[dbPointer executeUpdate:sql];
    //NSLog(@"removeObjectForKey:%d", ret);
    [self close];
}

- (NSString *)stringForKey:(NSString *)defaultName
{
    id object = [self objectForKey:defaultName];
    return object;
}

- (NSInteger)integerForKey:(NSString *)defaultName
{
    id object = [self objectForKey:defaultName];
    return [object integerValue];
}

- (int)intForKey:(NSString *)defaultName
{
    return [self integerForKey:defaultName];
}

- (float)floatForKey:(NSString *)defaultName
{
    id object = [self objectForKey:defaultName];
    return [object floatValue];
}

- (BOOL)boolForKey:(NSString *)defaultName
{
    id object = [self objectForKey:defaultName];
    return [object boolValue];
}

- (void)setString:(NSString*)value forKey:(NSString *)defaultName
{
    [self setObject:value forKey:defaultName];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName
{
    [self setObject:[NSNumber numberWithInt:value] forKey:defaultName];
}

- (void)setInt:(int)value forKey:(NSString *)defaultName
{
    [self setInteger:value forKey:defaultName];
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName
{
    [self setObject:[NSNumber numberWithFloat:value] forKey:defaultName];
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
    [self setObject:[NSNumber numberWithBool:value] forKey:defaultName];
}
@end
