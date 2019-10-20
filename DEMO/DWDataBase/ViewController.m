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
#define dbPath @"/Users/momo/Desktop/a.sqlite3"
//#define dbPath [defaultSavePath() stringByAppendingPathComponent:@"a.sqlite3"]
@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic ,strong) UITableView * mainTab;

@property (nonatomic ,strong) NSMutableArray * dataArr;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self configDB];
}
- (void)insert {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:dbPath error:&error];
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

- (void)delete {
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

- (void)update {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        NSArray <V *>* ret = [db queryTableWithClass:nil keys:nil configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(unsignedLongLongNum).equalTo(20020200202);
            maker.dw_conditionWith(floatNum).between(DWBetweenMakeIntegerValue(3.09999, 4));
        }];
        
        if (ret.count) {
            V * newV = ret.lastObject;
            newV.intNum = 256;
            newV.floatNum = 3.1f;
            BOOL success = [db updateTableWithModel:newV keys:@[keyPathString(newV, intNum),keyPathString(newV, floatNum)] configuration:conf error:&error];
            if (success) {
                NSLog(@"Update Success:%@",[db queryTableWithClass:nil keys:nil configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                    maker.loadClass([V class]);
                    maker.conditionWith(@"intNum").equalTo(256);
                    maker.conditionWith(@"floatNum").between(DWApproximateFloatValue(3.1));
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

- (void)query {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        v.array = @[@1,@2,@3];
        
        [db queryTableWithClass:nil keys:@[keyPathString(v, intNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(array).equalTo(v.array);
        } completion:^(NSArray<__kindof NSObject *> * _Nonnull results, NSError * _Nonnull error) {
            if (results.count) {
                NSLog(@"Async Query Success:%@",results);
            } else {
                NSLog(@"Async %@",error);
            }
        }];
        
        
        NSArray <V *>* ret = [db queryTableWithClass:nil keys:@[keyPathString(v, floatNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass([V class]);
            maker.conditionWith(kUniqueID).greaterThanOrEqualTo(@"2");
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
- (void)queryCount {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * error;
    DWDatabaseConfiguration * conf = [db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" error:&error];
    if (conf) {
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        NSInteger count = [db queryTableForCountWithClass:nil configuration:conf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(intNum).equalTo(-100);
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
- (void)queryField {
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
- (void)queryID {
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
- (void)clear {
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
- (void)drop {
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

#pragma mark --- tool method ---
-(void)setupUI {
    self.view.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.mainTab];
}

-(void)configDB {
    DWDatabase * db = [DWDatabase shareDB];
    NSError * err;
    if ([db initializeDBWithError:nil]) {
        NSLog(@"%@",db.allDBs);
    } else {
        NSLog(@"%@",err);
    }
    NSLog(@"%@",defaultSavePath());
}

#pragma mark --- tableView delegate ---
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSString * title = self.dataArr[indexPath.row];
    cell.textLabel.text = title;
    return cell;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArr.count;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
        {
            [self insert];
        }
            break;
        case 1:
        {
            [self delete];
        }
            break;
        case 2:
        {
            [self update];
        }
            break;
        case 3:
        {
            [self query];
        }
            break;
        case 4:
        {
            [self queryCount];
        }
            break;
        case 5:
        {
            [self queryField];
        }
            break;
        case 6:
        {
            [self queryID];
        }
            break;
        case 7:
        {
            [self clear];
        }
            break;
        case 8:
        {
            [self drop];
        }
            break;
        default:
            break;
    }
}


#pragma mark --- setter/getter ---
-(UITableView *)mainTab {
    if (!_mainTab) {
        _mainTab = [[UITableView alloc] initWithFrame:self.view.bounds style:(UITableViewStylePlain)];
        _mainTab.delegate = self;
        _mainTab.dataSource = self;
        [_mainTab registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    }
    return _mainTab;
}

-(NSMutableArray *)dataArr {
    if (!_dataArr) {
        _dataArr = @[
            @"增",
            @"删",
            @"改",
            @"查",
            @"查个数",
            @"查字段",
            @"查ID",
            @"清表",
            @"删表",
                     
                     
                     
        ].mutableCopy;
    }
    return _dataArr;
}

@end
