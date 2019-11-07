//
//  ViewController.m
//  DWDatabase
//
//  Created by Wicky on 2018/6/9.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "ViewController.h"
#import "DWDatabase.h"
#import "V.h"
#import "C.h"

#import <DWDatabase/DWDatabaseHeader.h>
//#define dbPath @"/Users/momo/Desktop/a.sqlite3"
//#define dbPath [defaultSavePath() stringByAppendingPathComponent:@"a.sqlite3"]
#define dbPath @"/Users/wicky/Desktop/a.sqlite3"
@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic ,strong) UITableView * mainTab;

@property (nonatomic ,strong) NSMutableArray * dataArr;

@property (nonatomic ,strong) DWDatabaseConfiguration * tblConf;

@property (nonatomic ,strong) DWDatabase * db;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self configDB];
}
- (void)insert {
    
    if (self.tblConf) {
        NSError * error;
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
        
        BOOL success = [self.db insertTableWithModel:v keys:nil configuration:self.tblConf error:&error];
        if (success) {
            NSLog(@"Insert Success:%@",[self.db queryTableWithClass:[v class] keys:nil configuration:self.tblConf error:&error condition:nil]);
        } else {
            NSLog(@"%@",error);
        }
    }
}

- (void)delete {
    NSError * error;
    V * v = [V new];
    v.unsignedLongLongNum = 20020200202;
    v.intNum = -100;
    BOOL success = [self.db deleteTableAutomaticallyWithModel:v name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" byDw_id:NO keys:@[keyPathString(v, intNum),keyPathString(v, unsignedLongLongNum)] error:&error];
    if (success) {
        NSLog(@"Delete Success:%@",[self.db queryTableAutomaticallyWithModel:v name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" keys:nil error:&error condition:nil]);
    } else {
        NSLog(@"%@",error);
    }
}

- (void)update {
    
    if (self.tblConf) {
        NSError * error;
        NSArray <V *>* ret = [self.db queryTableWithClass:nil keys:nil configuration:self.tblConf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(unsignedLongLongNum).equalTo(20020200202);
            maker.dw_conditionWith(floatNum).between(DWBetweenMakeIntegerValue(3.09999, 4));
        }];
        
        if (ret.count) {
            V * newV = ret.lastObject;
            newV.intNum = 256;
            newV.floatNum = 3.1f;
            BOOL success = [self.db updateTableWithModel:newV keys:@[keyPathString(newV, intNum),keyPathString(newV, floatNum)] configuration:self.tblConf error:&error];
            if (success) {
                NSLog(@"Update Success:%@",[self.db queryTableWithClass:nil keys:nil configuration:self.tblConf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
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
    }
}

- (void)query {
    if (self.tblConf) {
        NSError * error;
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        v.array = @[@1,@2,@3];
        
        [self.db queryTableWithClass:nil keys:@[keyPathString(v, intNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(array).equalTo(v.array);
        } completion:^(NSArray<__kindof NSObject *> * _Nonnull results, NSError * _Nonnull error) {
            if (results.count) {
                NSLog(@"Async Query Success:%@",results);
            } else {
                NSLog(@"Async %@",error);
            }
        }];
        
        
        NSArray <V *>* ret = [self.db queryTableWithClass:nil keys:@[keyPathString(v, floatNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:self.tblConf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass([V class]);
            maker.conditionWith(kUniqueID).greaterThanOrEqualTo(@"2");
        }];
        if (ret.count) {
            NSLog(@"Query Success:%@",ret);
        } else {
            NSLog(@"%@",error);
        }
    }
}
- (void)queryCount {
    if (self.tblConf) {
        NSError * error;
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        NSInteger count = [self.db queryTableForCountWithClass:nil configuration:self.tblConf error:&error condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(intNum).equalTo(-100);
        }];
        if (count >= 0) {
            NSLog(@"Query Count Success:%ld",count);
        } else {
            NSLog(@"%@",error);
        }
    }
}
- (void)queryField {
    if (self.tblConf) {
        NSError * error;
        NSArray * ret = [self.db queryAllFieldInTable:NO class:Nil configuration:self.tblConf error:&error];
        if (ret) {
            NSLog(@"Query Field Success:%@",ret);
        } else {
            NSLog(@"%@",error);
        }
    }
}
- (void)queryID {
    if (self.tblConf) {
        NSError * error;
        V * ret = [self.db queryTableWithClass:[V class] Dw_id:@(7) keys:nil configuration:self.tblConf error:&error];
        if (ret) {
            NSLog(@"Query ID Success:%@",[self.db fetchDw_idForModel:ret]);
        } else {
            NSLog(@"%@",error);
        }
    }
}
- (void)clear {
    if (self.tblConf) {
        NSError * error;
        if ([self.db clearTableWithConfiguration:self.tblConf error:&error]) {
            NSLog(@"Clear Success:%@",[self.db queryTableWithClass:[V class] keys:nil configuration:self.tblConf error:&error condition:nil]);
        } else {
            NSLog(@"%@",error);
        }
    }
}
- (void)drop {
    if (self.tblConf) {
        NSError * error;
        if ([self.db deleteTableWithConfiguration:self.tblConf error:&error]) {
            NSLog(@"Drop success:%d",[self.db isTableExistWithTableName:@"V_SQL" configuration:self.tblConf error:&error]);
        } else {
            NSLog(@"%@",error);
        }
    }
}

-(void)transformToDictionary {
    C * classC = [C new];
    classC.a = @"hello";
    classC.aNum = 1.f;
    B * classB = [B new];
    classB.b = 100;
    classB.str = [B class];
    classC.classB = classB;
    A * classA = [A new];
    classA.a = @[@1,@2,@3];
    classB.classA = classA;
    
    
    NSDictionary * dic = [classC dw_transformToDictionaryForKeys:@[@"a",@"classB"]];
    NSLog(@"%@",dic);
}

-(void)transformToModel {
    C * model = [C dw_modelFromDictionary:@{@"a":@"hello",@"aNum":@(1.f),@"classB":@{@"b":@"100",@"str":@"B",@"classA":@{@"a":@[@1,@2,@3]}},@"array":@[@{@"a":@[@1,@2,@3]},@{@"a":@[@1,@2,@3,@4]}],@"dic":@{@"a":@[@1]},@"modelDic":@{@"a":@{@"a":@[@1,@2,@3,@4]},@"b":@1,@"c":@[@{@"a":@[@1,@2,@3,@4]},@2,@{@"a":@[@1,@2,@3,@4]}]},@"dicFromArray":@[@{@"a":@[@1,@2,@3,@4]},@{@"a":@[@1,@2,@3,@4]},@{@"a":@[@1,@2,@3,@4]}]}];
    
    DWDatabaseConfiguration * CTblConf = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_SQL" tableName:@"C_Tbl" path:dbPath error:nil];
    if (CTblConf) {
        BOOL success = [self.db insertTableWithModel:model keys:nil configuration:CTblConf error:nil];
        NSLog(@"Insert Success:%d",success);
    }
    
    
    NSLog(@"%@",model);
}

#pragma mark --- tool method ---
-(void)setupUI {
    self.view.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.mainTab];
}

-(void)configDB {
    NSError * err;
    if ([self.db initializeDBWithError:nil]) {
        NSLog(@"%@",self.db.allDBs);
    } else {
        NSLog(@"%@",err);
    }
    NSLog(@"%@",defaultSavePath());
    
    self.tblConf = [self.db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:dbPath error:&err];
    if (!self.tblConf) {
        NSLog(@"%@",err);
    }
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
        case 9:
        {
            [self transformToDictionary];
        }
            break;
        case 10:
        {
            [self transformToModel];
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
            @"模型转字典",
            @"字典转模型",
                     
        ].mutableCopy;
    }
    return _dataArr;
}

-(DWDatabase *)db {
    if (!_db) {
        _db = [DWDatabase shareDB];
    }
    return _db;
}

@end
