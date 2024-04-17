//
//  TEProperty.h
//  xmagickit
//
//  Created by tao yue on 2024/2/2.
//  Copyright (c) 2020 Tencent. All rights reserved.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TEProperty : NSObject

@property(nonatomic, copy)NSString *propertyType;

@property(nonatomic, copy)NSString *propertyName;

@property(nonatomic, copy)NSString *propertyValue;

@property(nonatomic, strong)id extraInfo;


@end

NS_ASSUME_NONNULL_END
