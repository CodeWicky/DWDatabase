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
#define dbPath @"/Users/momo/Desktop/a.sqlite3"
//#define dbPath [defaultSavePath() stringByAppendingPathComponent:@"a.sqlite3"]
//#define dbPath @"/Users/wicky/Desktop/a.sqlite3"
@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic ,strong) UITableView * mainTab;

@property (nonatomic ,strong) NSMutableArray * dataArr;

@property (nonatomic ,strong) DWDatabaseConfiguration * tblConf;

@property (nonatomic ,strong) DWDatabase * db;

@property (nonatomic ,strong) DWDatabaseConfiguration * cTblConf;

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
        
        DWDatabaseResult * result = [self.db insertTableWithModel:v keys:nil configuration:self.tblConf];
        if (result.success) {
            NSLog(@"Insert Success:%@",[self.db queryTableWithClass:nil keys:nil configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                maker.dw_loadClass(V);
                maker.dw_conditionWith(nsNum).equalTo(1);
            }]);
        } else {
            NSLog(@"%@",error);
        }
    }
}

- (void)delete {
    DWDatabaseResult * result = [self.db deleteTableAutomaticallyWithModel:nil name:@"V_SQL" tableName:@"V_tbl" path:@"/Users/Wicky/Desktop/a.sqlite3" condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(intNum).equalTo(-100);
        maker.dw_conditionWith(unsignedLongLongNum).equalTo(20020200202);
    }];
    if (result.success) {
        NSLog(@"Delete Success:%@",[self.db queryTableAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:dbPath keys:nil condition:nil]);
    } else {
        NSLog(@"%@",result.error);
    }
}

- (void)update {
    
    if (self.tblConf) {
        V * newV = [V new];
        newV.unsignedLongLongNum = 333;
        newV.intNum = 129;
        newV.floatNum = 3.5;
        DWDatabaseResult * result = [self.db updateTableWithModel:newV keys:@[keyPathString(newV, intNum),keyPathString(newV, floatNum)] configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(unsignedLongLongNum).equalTo(222);
        }];
        
        NSLog(@"%@",result);
    }
}

- (void)query {
    if (self.tblConf) {

        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        v.array = @[@1,@2,@3];
        
        [self.db queryTableWithClass:nil keys:nil limit:0 offset:0 orderKey:nil ascending:YES configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(floatNum).equalTo(0.5);
            maker.dw_conditionWith(chr).isNull();
            maker.dw_conditionWith(intNum).equalTo(1);
        } completion:^(NSArray<__kindof NSObject *> * _Nonnull results, NSError * _Nonnull error) {
            if (results.count) {
                NSLog(@"Async Query Success:%@",results);
            } else {
                NSLog(@"Async %@",error);
            }
        }];
        
    
        DWDatabaseResult * result = [self.db queryTableWithClass:nil keys:@[keyPathString(v, floatNum)] limit:0 offset:0 orderKey:nil ascending:YES configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.loadClass([V class]);
            maker.conditionWith(kUniqueID).greaterThanOrEqualTo(@"2");
        }];
        NSArray <V *>* ret = result.result;
        if (ret.count) {
            NSLog(@"Query Success:%@",ret);
        } else {
            NSLog(@"%@",result.error);
        }
    }
}
- (void)queryCount {
    if (self.tblConf) {
        V * v = [V new];
        v.unsignedLongLongNum = 20020200202;
        v.intNum = -100;
        DWDatabaseResult * result = [self.db queryTableForCountWithClass:nil configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(intNum).equalTo(-100);
        }];
        if (result.success) {
            NSLog(@"Query Count Success:%@",result.result);
        } else {
            NSLog(@"%@",result.error);
        }
    }
}
- (void)queryField {
    if (self.tblConf) {
        
        DWDatabaseResult * result = [self.db queryAllFieldInTable:NO class:Nil configuration:self.tblConf];
        NSArray * ret = result.result;
        if (ret) {
            NSLog(@"Query Field Success:%@",ret);
        } else {
            NSLog(@"%@",result.error);
        }
    }
}
- (void)queryID {
    if (self.tblConf) {
        DWDatabaseResult * result = [self.db queryTableWithClass:[V class] Dw_id:@(7) keys:nil configuration:self.tblConf];
        V * ret = result.result;
        if (result.success) {
            NSLog(@"Query ID Success:%@",[DWDatabase fetchDw_idForModel:ret]);
        } else {
            NSLog(@"%@",result.error);
        }
    }
}
- (void)clear {
    if (self.tblConf) {
        DWDatabaseResult * result = [self.db clearTableWithConfiguration:self.tblConf];
        if (result.success) {
            NSLog(@"Clear Success:%@",[self.db queryTableWithClass:[V class] keys:nil configuration:self.tblConf condition:nil]);
        } else {
            NSLog(@"%@",result.error);
        }
    }
}
- (void)drop {
    if (self.tblConf) {
        DWDatabaseResult * result = [self.db dropTableWithConfiguration:self.tblConf];
        if (result.success) {
            NSLog(@"Drop success:%d",[self.db isTableExistWithTableName:@"V_SQL" configuration:self.tblConf].success);
        } else {
            NSLog(@"%@",result.error);
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
    classC.obj = [NSObject new];
    classC.array = @[classB];
    NSDictionary * dic = [classC dw_transformToDictionary];
    NSLog(@"%@",dic);
}

-(void)transformToModel {
    C * model = [C dw_modelFromDictionary:@{@"a":@"hello",@"aNum":@(1.f),@"classB":@{@"b":@"100",@"str":@"B",@"classA":@{@"a":@[@1,@2,@3]}},@"array":@[@{@"a":@[@1,@2,@3]},@{@"a":@[@1,@2,@3,@4]}],@"dic":@{@"a":@[@1]},@"modelDic":@{@"a":@{@"a":@[@1,@2,@3,@4]},@"b":@1,@"c":@[@{@"a":@[@1,@2,@3,@4]},@2,@{@"a":@[@1,@2,@3,@4]}]},@"dicFromArray":@[@{@"a":@[@1,@2,@3,@4]},@{@"a":@[@1,@2,@3,@4]},@{@"a":@[@1,@2,@3,@4]}]}];
    
    DWDatabaseConfiguration * CTblConf = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_SQL" tableName:@"C_Tbl" path:dbPath].result;
    if (CTblConf) {
        BOOL success = [self.db insertTableWithModel:model keys:nil configuration:CTblConf];
        NSLog(@"Insert Success:%d",success);
    }
    
    
    NSLog(@"%@",model);
}

-(void)insertCModel {
    C * model = [C new];
    model.classB = [B new];
    model.classB.b = 10;
    model.array = @[[A new]];
    
    DWDatabaseResult * result = [self.db insertTableWithModel:model keys:@[keyPathString(model, array)] configuration:self.cTblConf];
    if (!result.success) {
        NSLog(@"error = %@",result.error);
    } else {
        NSLog(@"success = %@",result.result);
    }
}

-(void)queryCModel {
    DWDatabaseResult * result = [self.db queryTableWithClass:NULL keys:nil configuration:self.cTblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(C);
        maker.dw_conditionWith(a).equalTo(@"aaa");
    }];
    
    NSLog(@"%@",result.result);
}

#pragma mark --- tool method ---
-(void)setupUI {
    self.view.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.mainTab];
}

-(void)configDB {
    DWDatabaseResult * result = [self.db initializeDB];
    if (result.success) {
        NSLog(@"%@",self.db.allDBs);
    } else {
        NSLog(@"%@",result.error);
    }
    NSLog(@"%@",defaultSavePath());
    
    result = [self.db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"V_SQL" tableName:@"V_tbl" path:dbPath];
    self.tblConf = result.result;
    if (!self.tblConf) {
        NSLog(@"%@",result.error);
    }
    
    result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"V_SQL" tableName:@"C_tbl" path:dbPath];
    self.cTblConf = result.result;
    if (!self.cTblConf) {
        NSLog(@"%@",result.error);
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
        case 11:
        {
            [self insertCModel];
        }
            break;
        case 12:
        {
            [self queryCModel];
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
            @"模型嵌套插入",
            @"模型嵌套查询",
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
