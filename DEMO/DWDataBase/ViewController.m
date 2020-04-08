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

-(void)insertAutomatically {
    V * model = [V new];
    model.intNum = -100;
    model.floatNum = 3.14;
    model.string = @"123";
    DWDatabaseResult * result = [self.db insertTableAutomaticallyWithModel:model name:@"Auto" tableName:@"Auto_V_Tbl" path:nil keys:@[keyPathString(model, intNum),keyPathString(model, floatNum)]];
    if (result.success) {
        NSLog(@"%@",[DWDatabase fetchDw_idForModel:model]);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)updateAutomatically {
    V * model = [V new];
    model.intNum = 100;
    model.string = @"456";
    DWDatabaseResult * result = [self.db updateTableAutomaticallyWithModel:model name:@"Auto" tableName:@"Auto_V_Tbl" path:nil keys:@[keyPathString(model, intNum),keyPathString(model, string)] condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(floatNum).between(DWApproximateFloatValue(3.14));
    }];
    if (result.success) {
        result = [self.db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"Auto" tableName:@"Auto_V_Tbl" path:nil];
        if (result.success) {
            DWDatabaseConfiguration * tblConf = result.result;
            result = [self.db queryTableForCountWithClass:NULL configuration:tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                maker.dw_loadClass(V);
                maker.dw_conditionWith(intNum).equalTo(100);
            }];
            if (result.success) {
                NSLog(@"%@",result.result);
            } else {
                NSLog(@"%@",result.error);
            }
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryAutomatically {
    DWDatabaseResult * result = [self.db queryTableAutomaticallyWithClass:NULL name:@"Auto" tableName:@"Auto_V_Tbl" path:nil keys:@[@"string"] condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(string).equalTo(@"456");
    }];
    
    if (result.success) {
        NSArray <V *>* results = result.result;
        NSLog(@"%@",results.firstObject.string);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)deleteAutomatically {
    DWDatabaseResult * result = [self.db deleteTableAutomaticallyWithModel:nil name:@"Auto" tableName:@"Auto_V_Tbl" path:nil condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.loadClass([V class]);
        maker.conditionWith(@"intNum").greaterThanOrEqualTo(50);
    }];
    if (result.success) {
        result = [self.db fetchDBConfigurationAutomaticallyWithClass:[V class] name:@"Auto" tableName:@"Auto_V_Tbl" path:nil];
        if (result.success) {
            DWDatabaseConfiguration * tblConf = result.result;
            result = [self.db queryTableForCountWithClass:NULL configuration:tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                maker.loadClass([V class]);
            }];
            if (result.success) {
                NSLog(@"%@",result.result);
            } else {
                NSLog(@"%@",result.error);
            }
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryAllTblInDB {
    DWDatabaseResult * result = [self.db queryAllTableNamesInDBWithConfiguration:self.tblConf];
    if (result.success) {
        NSLog(@"%@",result.result);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryAllFieldInDB {
    DWDatabaseResult * result = [self.db queryAllFieldInTable:YES class:[V class] configuration:self.tblConf];
    if (result.success) {
        NSLog(@"%@",result.result);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)clearRowsInTbl {
    DWDatabaseResult * result = [self.db clearTableWithConfiguration:self.tblConf];
    if (result.success) {
        [self queryCountInTbl];
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)dropTblInDB {
    DWDatabaseResult * result = [self.db dropTableWithConfiguration:self.tblConf];
    if (result.success) {
        NSLog(@"%d",[self.db isTableExistWithTableName:@"V_SQL" configuration:self.tblConf].success);
    } else {
        NSLog(@"%@",result.error);
    }
}

- (void)insertModel {
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
    
    DWDatabaseResult * result = [self.db insertTableWithModel:v keys:nil recursive:YES configuration:self.tblConf];
    if (result.success) {
        [self queryCountInTbl];
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)batchInsertModels {
    V * m1 = [V new];
    m1.intNum = 2;
    V * m2 = [V new];
    m2.intNum = 4;
    [self.db insertTableWithModels:@[m1,m2] keys:nil recursive:NO rollbackOnFailure:YES configuration:self.tblConf completion:^(DWDatabaseResult * _Nonnull result) {
        if (result.success) {
            [self queryCountInTbl];
        } else {
            NSLog(@"%@",result.error);
        }
    }];
}

-(void)deleteRowsInTblWithCondition {
    DWDatabaseResult * result = [self.db deleteTableWithConfiguration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(intNum).equalTo(4);
    }];
    
    if (result.success) {
        [self queryCountInTbl];
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)deleteRowsInTblWithModel {
    V * model = [V new];
    model.intNum = 255;
    DWDatabaseResult * result = [self.db insertTableWithModel:model keys:nil recursive:NO configuration:self.tblConf];
    if (result.success) {
        result = [self.db deleteTableWithModel:model recursive:NO configuration:self.tblConf];
        if (result.success) {
            [self queryCountInTbl];
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
}

- (void)updateModel {
    
    V * newV = [V new];
    newV.unsignedLongLongNum = 333;
    newV.intNum = 129;
    newV.floatNum = 3.5;
    DWDatabaseResult * result = [self.db updateTableWithModel:newV keys:@[keyPathString(newV, intNum),keyPathString(newV, floatNum)] recursive:YES configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(intNum).equalTo(2);
    }];
    
    if (result.success) {
        result = [self.db queryTableForCountWithClass:nil configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(V);
            maker.dw_conditionWith(intNum).equalTo(129);
        }];
        if (result.success) {
            NSLog(@"%@",result.result);
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryTblWithParam {
    DWDatabaseResult * result = [self.db queryTableWithClass:NULL keys:nil limit:3 offset:8 orderKey:nil ascending:NO recursive:NO configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(intNum).equalTo(129);
    }];
    
    if (result.success) {
        NSArray <V *>* results = result.result;
        [results enumerateObjectsUsingBlock:^(V * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSLog(@"%@",[DWDatabase fetchDw_idForModel:obj]);
        }];
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryModel {
    DWDatabaseResult * result = [self.db queryTableWithClass:NULL keys:nil recursive:NO configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
        maker.dw_conditionWith(intNum).equalTo(129);
    }];
    
    if (result.success) {
        NSArray <V *>* results = result.result;
        [results enumerateObjectsUsingBlock:^(V * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSLog(@"%@",[DWDatabase fetchDw_idForModel:obj]);
        }];
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryCountInTbl {
    DWDatabaseResult * result = [self.db queryTableForCountWithClass:nil configuration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
        maker.dw_loadClass(V);
    }];
    if (result.success) {
        NSLog(@"%@",result.result);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)queryModelByID {
    DWDatabaseResult * result = [self.db queryTableWithClass:[V class] Dw_id:@(3) keys:nil recursive:NO configuration:self.tblConf];
    if (result.success) {
        V * model = result.result;
        NSLog(@"%@,%@,%@",[DWDatabase fetchDw_idForModel:model],[DWDatabase fetchDBNameForModel:model],[DWDatabase fetchTblNameForModel:model]);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)querySavePropertyInfos {
    NSArray <DWPrefix_YYClassPropertyInfo *>* saveProps = [DWDatabase propertysToSaveWithClass:[V class]];
    NSLog(@"%@",saveProps);
}

-(void)queryPropertyInfosWithKeys {
    NSDictionary <NSString *,DWPrefix_YYClassPropertyInfo *> * props = [DWDatabase propertyInfosWithClass:[V class] keys:@[@"intNum"]];
    NSLog(@"%@",props);
}

-(void)insertModelRecursiveLy {
    C * cModel = [C new];
    cModel.dic = @{@"key":@"value"};
    cModel.classC = cModel;
    cModel.aNum = 12;
    
    B * bModel = [B new];
    bModel.b = 100;
    cModel.classB = bModel;
    
    A * aModel = [A new];
    aModel.a = @[@1,@2];
    aModel.classC = cModel;
    bModel.classA = aModel;
    
    DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
    if (result.success) {
        DWDatabaseConfiguration * conf = result.result;
        result = [self.db insertTableWithModel:cModel keys:nil recursive:YES configuration:conf];
        if (result.success) {
            NSLog(@"%@",[DWDatabase fetchDw_idForModel:cModel]);
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)deleteModelRecursively {
    NSArray <C *>* result = [self queryModelRecursively];
    if (result.count) {
        C * cModel = result.firstObject;
        DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
        if (result.success) {
            DWDatabaseConfiguration * conf = result.result;
            result = [self.db deleteTableWithModel:cModel recursive:YES configuration:conf];
            if (result.success) {
                NSLog(@"%@",result.result);
            } else {
                NSLog(@"%@",result.error);
            }
        } else {
            NSLog(@"%@",result.error);
        }
    }
}

-(void)updateModelRecursively {
    NSArray <C *>* result = [self queryModelRecursively];
    if (result.count) {
        C * cModel = result.firstObject;
        cModel.classB.classA.classC = nil;
        C * newCModel = [C new];
//        newCModel.a = @"newCModel";
        cModel.classC = newCModel;
        DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
        if (result.success) {
            DWDatabaseConfiguration * conf = result.result;
            result = [self.db updateTableWithModel:cModel keys:nil recursive:YES configuration:conf condition:nil];
            if (result.success) {
                cModel = [self queryModelRecursively].firstObject;
                NSLog(@"%@",cModel);
            } else {
                NSLog(@"%@",result.error);
            }
        } else {
            NSLog(@"%@",result.error);
        }
    }
}

-(void)updateModelRecursivelyWithCondition {
    DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
    if (result.success) {
        C * cModel = [self queryModelRecursively].firstObject;
        cModel.classC = cModel;
        result = [self.db updateTableWithModel:cModel keys:@[keyPathString(cModel, classC)] recursive:YES configuration:result.result condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.conditionWith(@"classC").equalTo(2);
        }];
        
        if (result.success) {
            NSLog(@"%@",result.result);
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
    
}

-(NSArray <C *>*)queryModelRecursively {
    DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
    if (result.success) {
        DWDatabaseConfiguration * conf = result.result;
        result = [self.db queryTableWithClass:NULL keys:nil recursive:YES configuration:conf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
            maker.dw_loadClass(C);
            maker.dw_conditionWith(aNum).equalTo(12);
        }];
        
        if (result.success) {
            NSArray <C *>* models = result.result;
            [models enumerateObjectsUsingBlock:^(C * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSLog(@"%@",[DWDatabase fetchDw_idForModel:obj]);
            }];
            return models;
        } else {
            NSLog(@"%@",result.error);
            return nil;
        }
        
    } else {
        NSLog(@"%@",result.error);
        return nil;
    }
}

-(void)fetchDBInlineVersion {
    DWDatabaseResult * result = [self.db fetchDBVersionWithConfiguration:self.tblConf];
    if (result.success) {
        NSLog(@"%@",result.result);
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)upgradeDBInlineVersion {
    __block DWDatabaseResult * result = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_Recursive" tableName:@"C_Recursive" path:dbPath];
    if (result.success) {
        result = [self.db upgradeDBVersion:1 configuration:result.result handler:^NSInteger(DWDatabase * _Nonnull db, NSInteger currentVersion, NSInteger targetVersion) {
            switch (currentVersion) {
                case 0:
                {
                    ///这里写0升级至1的代码
                    result = [db addFieldsToTableWithClass:[C class] keys:@[@"a"] configuration:result.result];
                    if (!result.success) {
                        NSLog(@"%@",result.error);
                        return 0;
                    }
                }
                case 1:
                {
                    NSLog(@"升级至2级");
                }
                case 2:
                {
                    NSLog(@"升级至3级");
                }
                default:
                {
                    return targetVersion;
                }
            }
        }];
        
        if (result.success) {
            NSLog(@"%@",result.result);
        } else {
            NSLog(@"%@",result.error);
        }
    } else {
        NSLog(@"%@",result.error);
    }
}

-(void)transformToModel {
    C * model = [C dw_modelFromDictionary:@{@"a":@"hello",@"aNum":@(1.f),@"classB":@{@"b":@"100",@"str":@"B",@"classA":@{@"a":@[@1,@2,@3]}},@"array":@[@{@"a":@[@1,@2,@3]},@{@"a":@[@1,@2,@3,@4]}],@"dic":@{@"a":@[@1]},@"modelDic":@{@"a":@{@"a":@[@1,@2,@3,@4]},@"b":@1,@"c":@[@{@"a":@[@1,@2,@3,@4]},@2,@{@"a":@[@1,@2,@3,@4]}]},@"dicFromArray":@[@{@"a":@[@1,@2,@3,@4]},@{@"a":@[@1,@2,@3,@4]},@{@"a":@[@1,@2,@3,@4]}]}];
    
    DWDatabaseConfiguration * CTblConf = [self.db fetchDBConfigurationAutomaticallyWithClass:[C class] name:@"C_SQL" tableName:@"C_Tbl" path:dbPath].result;
    if (CTblConf) {
        BOOL success = [self.db insertTableWithModel:model keys:nil recursive:YES configuration:CTblConf];
        NSLog(@"Insert Success:%d",success);
    }
    
    
    NSLog(@"%@",model);
}

-(void)transformToDictionary {
    C * classC = [C new];
//    classC.a = @"hello";
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

-(void)test {
    DWDatabaseConditionMaker * maker = [DWDatabaseConditionMaker new];
    maker.dw_loadClass(C);
    maker.dw_conditionWith(classB.classA.classC).equalTo(1);
    Class cls = [maker fetchQueryClass];
    NSArray * saveKeys = [DWDatabase propertysToSaveWithClass:cls];
    NSDictionary * propertyInfos = [DWDatabase propertyInfosWithClass:cls keys:saveKeys];
    [maker configWithPropertyInfos:propertyInfos databaseMap:nil];
    [maker make];
    NSLog(@"%@",[maker fetchConditions]);
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
            [self insertAutomatically];
        }
            break;
        case 1:
        {
            [self updateAutomatically];
        }
            break;
        case 2:
        {
            [self queryAutomatically];
        }
            break;
        case 3:
        {
            [self deleteAutomatically];
        }
            break;
        case 4:
        {
            [self queryAllTblInDB];
        }
            break;
        case 5:
        {
            [self queryAllFieldInDB];
        }
            break;
        case 6:
        {
            [self clearRowsInTbl];
        }
            break;
        case 7:
        {
            [self dropTblInDB];
        }
            break;
        case 8:
        {
            [self insertModel];
        }
            break;
        case 9:
        {
            [self batchInsertModels];
        }
            break;
        case 10:
        {
            [self deleteRowsInTblWithCondition];
        }
            break;
        case 11:
        {
            [self deleteRowsInTblWithModel];
        }
            break;
        case 12:
        {
            [self updateModel];
        }
            break;
        case 13:
        {
            [self queryTblWithParam];
        }
            break;
        case 14:
        {
            [self queryModel];
        }
            break;
        case 15:
        {
            [self queryCountInTbl];
        }
            break;
        case 16:
        {
            [self queryModelByID];
        }
            break;
        case 17:
        {
            [self querySavePropertyInfos];
        }
            break;
        case 18:
        {
            [self queryPropertyInfosWithKeys];
        }
            break;
        case 19:
        {
            [self insertModelRecursiveLy];
        }
            break;
        case 20:
        {
            [self deleteModelRecursively];
        }
            break;
        case 21:
        {
            [self updateModelRecursively];
        }
            break;
        case 22:
        {
            [self updateModelRecursivelyWithCondition];
        }
            break;
        case 23:
        {
            [self queryModelRecursively];
        }
            break;
        case 24:
        {
            [self fetchDBInlineVersion];
        }
            break;
        case 25:
        {
            [self upgradeDBInlineVersion];
        }
            break;
        case 26:
        {
            [self transformToModel];
        }
            break;
        case 27:
        {
            [self transformToDictionary];
        }
            break;
        default:
        {
            [self test];
        }
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
            @"全自动插入",
            @"全自动更新",
            @"全自动查询",
            @"全自动删除",
            @"获取库中的所有表名",
            @"获取表中的所有字段",
            @"清除表中的所有数据",
            @"删除库中的指定表",
            @"插入模型",
            @"批量插入模型",
            @"以条件删除表中的数据",
            @"删除表中的指定模型",
            @"更新模型",
            @"定制不同参数查询模型",
            @"查询模型",
            @"查询符合条件的模型的个数",
            @"以Dw_id进行查询模型",
            @"查询指定类需要落库的属性信息",
            @"查询指定类指定的属性信息",
            @"递归插入模型",
            @"递归删除模型",
            @"递归更新模型",
            @"以条件递归更新模型",
            @"递归查询模型",
            @"获取数据库内部版本",
            @"更新数据库内部版本",
            @"字典转模型",
            @"模型转字典",
            @"测试",
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
