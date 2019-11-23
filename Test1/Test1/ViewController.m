//
//  ViewController.m
//  Test1
//
//  Created by Wicky on 2019/10/28.
//  Copyright © 2019 Wicky. All rights reserved.
//

#import "ViewController.h"
#import <DWDatabase/DWDatabaseHeader.h>
#import "Ex.h"
#import "Ax.h"

@interface ViewController ()

@property (nonatomic ,strong) DWDatabase * db;

@property (nonatomic ,strong) DWDatabaseConfiguration * tblConf;

@end

@implementation ViewController

#define dbPath @"/Users/momo/Desktop/test.sqlite3"
#define touchMode 2

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    NSLog(@"Finish did load");
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    switch (touchMode) {
        case 0:
        {
            static int i = 0;
            static NSArray * names = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                names = @[@"zhangsan",@"lisi",@"wangwu",@"zhaoliu"];
            });
            Ex * model = [Ex new];
            model.num = i;
            model.name = names[i];
            model.obj = [Ex new];
            model.obj.num = 100;
            Ax * obj = [Ax new];
            obj.obj = model.obj;
            obj.name = @"zdw";
            model.aObj = obj;
            NSLog(@"start");
            DWDatabaseResult * result = [self.db insertTableWithModel:model keys:nil configuration:self.tblConf];
            NSLog(@"end %@",result);
            i++;
        }
            break;
        case 1:
        {
            NSArray * values = @[@"zhangsan",@"lisi"];
            NSArray <Ex *>* rets = [self.db queryTableWithClass:nil keys:nil configuration:self.tblConf error:nil condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                maker.dw_loadClass(Ex);
                maker.dw_conditionWith(num).equalTo(1024);
            }];
            [rets enumerateObjectsUsingBlock:^(Ex * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSLog(@"%d",obj.num);
            }];
        }
            break;
        case 2:
        {
            DWDatabaseResult * result = [self.db deleteTableWithConfiguration:self.tblConf condition:^(DWDatabaseConditionMaker * _Nonnull maker) {
                maker.dw_loadClass(Ex);
                maker.dw_conditionWith(num).equalTo(1024);
            }];
            NSLog(@"%@",result);
        }
            break;
        default:
            break;
    }
    
    
    
}

-(DWDatabase *)db {
    if (!_db) {
        _db = [DWDatabase shareDB];
        self.tblConf = [_db fetchDBConfigurationAutomaticallyWithClass:[Ex class] name:@"test" tableName:@"test" path:dbPath error:nil];
    }
    return _db;
}

@end
