//
//  DWDatabaseResult.m
//  DWDatabase
//
//  Created by Wicky on 2019/11/25.
//

#import "DWDatabaseResult.h"

@implementation DWDatabaseResult

+(DWDatabaseResult *)failResultWithError:(NSError *)error {
    DWDatabaseResult * result = [DWDatabaseResult new];
    result.error = error;
    return result;
}

+(DWDatabaseResult *)successResultWithResult:(id)result {
    DWDatabaseResult * res = [DWDatabaseResult new];
    res.result = result;
    res.success = YES;
    return res;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>%@ with: %@",NSStringFromClass([self class]),self,self.success?@"Success":@"Fail",self.success?self.result:self.error];
}

-(NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@: %p>%@ with: %@",NSStringFromClass([self class]),self,self.success?@"Success":@"Fail",self.success?self.result:self.error];
}

@end
