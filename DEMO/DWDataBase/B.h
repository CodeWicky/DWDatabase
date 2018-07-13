//
//  B.h
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "A.h"
#import "DWDatabase.h"

@interface B : A<DWDatabaseSaveProtocol>
{
    float d;
}

@property (nonatomic ,assign) int b;

@property (nonatomic ,assign) Class str;

@end
