//
//  ViewController.m
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "ViewController.h"
#import "B.h"
#import "DWDatabase.h"
#import "V.h"
#import "C.h"

#import <DWDatabase/DWDatabaseHeader.h>
#import <DWDatabaseMacro.h>
@interface ViewController ()

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    DWDatabase * db = [DWDatabase shareDB];
    NSError * err;
    if ([db initializeDBWithError:nil]) {
        NSLog(@"%@",db.allDBs);
    } else {
        NSLog(@"%@",err);
    }
    
    NSLog(@"%@",defaultSavePath());
}
- (IBAction)insert:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/momo/Desktop/a.sqlite3" error:&error];
    if (conf) {
        V * v = [V new];
        v.shortNum = -1;
        v.unsignedShortNum = 1;
        v.intNum = -100;
        v.floatNum = 0.5;
        v.doubleNum = -2002020200202;
        v.longlongNum = 1111;
        v.unsignedIntNum = 100;
        v.longDoubleNum = -1010004001001;
        v.unsignedLongLongNum = 20020200202;
        v.chr = -'a';
        v.uChr = 'a';
        v.charString = "hello\0";
        v.nsNum = @"1";
        v.string = @[@1];
        v.mString = [@"hello" mutableCopy];
        v.data = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
        v.mData = [v.data mutableCopy];
        v.date = @"1";
        v.url = [NSURL URLWithString:@"www.baidu.com"];
        v.array = @"[1,2,3]";
        v.mArray = @[@4,@5,@6].mutableCopy;
        v.dictionary = @{@"a":@"b"};
        v.mDictionary = @{@"c":v.array}.mutableCopy;
        v.aSet = [NSSet setWithObjects:@7,@8,@9, nil];
        v.mSet = [NSMutableSet setWithObjects:@10,@11,@12, nil];
        v.cls = [v class];
        v.sel = @selector(viewDidLoad);
        
        BOOL success = [db insertTableWithModel:v keys:nil configuration:conf error:&error];
        if (success) {
            NSLog(@"Insert Success:%@",[db queryTableWithClass:[v class] keys:nil configuration:conf error:&error condition:nil]);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}

- (IBAction)delete:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    V * v = [V new];
    v.unsignedLongLongNum = 20020200202;
    v.intNum = -100;
    BOOL success = [db deleteTableAutomaticallyWithModel:v name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" byDw_id:NO keys:@[keyPathString(v, intNum),keyPathString(v, unsignedLongLongNum)] error:&error];
    if (success) {
        NSLog(@"Delete Success:%@",[db queryTableAutomaticallyWithModel:v name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" keys:nil error:&error condition:nil]);
    } else {
        NSLog(@"%@",error);
    }
}

- (IBAction)update:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        NSArray <V *>* ret = [db queryTableWithClass:nil keys:nil configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass(V);
            maker.conditionWith(unsignedLongLongNum).equalTo(20020200202);
            maker.conditionWith(intNum).equalTo(-100);
        }];
        
        if (ret.count) {
            V * newV = ret.lastObject;
            newV.intNum = 256;
            newV.floatNum = 3.14;
            BOOL success = [db updateTableWithModel:newV keys:@[keyPathString(newV, intNum),keyPathString(newV, floatNum)] configuration:conf error:&error];
            if (success) {
                NSLog(@"Update Success:%@",[db queryTableWithClass:nil keys:nil configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                    maker.loadClass(V);
                    maker.conditionWith(intNum).equalTo(256);
                    maker.conditionWith(unsignedLongLongNum).equalTo(3.14);
                }]);
            } else {
                NSLog(@"%@",error);
            }
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}

- (IBAction)query:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        v.array = @[@1,@2,@3];
        
        [db queryTableWithClass:nil keys:@[keyPathString(v, intNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass(V);
            maker.conditionWith(array).equalTo(v.array);
        } completion:^(NSArray<__kindof NSObject *> * _Nonnull results, NSError * _Nonnull error) {
            if (results.count) {
                NSLog(@"Async Query Success:%@",results);
            } else {
                NSLog(@"Async %@",error);
            }
        }];
        
        
        NSArray <V *>* ret = [db queryTableWithClass:nil keys:@[keyPathString(v, floatNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass(V);
            maker.conditionWith(intNum).greaterThan(0);
        }];
        if (ret.count) {
            NSLog(@"Query Success:%@",ret);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}
- (IBAction)queryCount:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        NSInteger count = [db queryTableForCountWithClass:nil configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass(V);
            maker.conditionWith(intNum).equalTo(-100);
        }];
        if (count >= 0) {
            NSLog(@"Query Count Success:%ld",count);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}
- (IBAction)queryField:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        NSArray * ret = [db queryAllFieldInTable:NO class:Nil configuration:conf error:&error];
        if (ret) {
            NSLog(@"Query Field Success:%@",ret);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}
- (IBAction)queryID:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        V * ret = [db queryTableWithClass:[V class] Dw_id:@(7) keys:nil configuration:conf error:&error];
        if (ret) {
            NSLog(@"Query ID Success:%@",[db fetchDw_idForModel:ret]);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}
- (IBAction)clear:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        if ([db clearTableWithConfiguration:conf error:&error]) {
            NSLog(@"Clear Success:%@",[db queryTableWithClass:[V class] keys:nil configuration:conf error:&error condition:nil]);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}
- (IBAction)drop:(id)sender {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    ///此处使用表名数据库句柄
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationWithName:@"V_SQL" tabelName:@"V_tbl" error:&error];
    if (conf) {
        if ([db deleteTableWithConfiguration:conf error:&error]) {
            NSLog(@"Drop success:%d",[db isTableExistWithTableName:@"V_SQL" configuration:conf error:&error]);
        } else {
            NSLog(@"%@",error);
        }
    } else {
        NSLog(@"%@",error);
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
