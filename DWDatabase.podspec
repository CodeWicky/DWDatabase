Pod::Spec.new do |s|
s.name = 'DWDatabase'
s.version = '1.1.1.3'
s.license = { :type => 'MIT', :file => 'LICENSE' }
s.summary = '无入侵模型自动落库。Automaticly save model to database.'
s.homepage = 'https://github.com/CodeWicky/DWDatabase'
s.authors = { 'codeWicky' => 'codewicky@163.com' }
s.source = { :git => 'https://github.com/CodeWicky/DWDatabase.git', :tag => s.version.to_s }
s.requires_arc = true
s.ios.deployment_target = '8.0'
s.source_files = 'DWDatabase/**/*.{h,m}'
s.public_header_files = 'DWDatabase/**/{DWDatabase,DWDatabaseConfiguration,DWDatabaseResult,DWDatabaseConditionMaker,DWDatabaseMacro,DWDatabaseHeader}.h'
s.frameworks = 'UIKit'

s.dependency 'FMDB', '~> 2.7.2'
s.dependency 'DWKit/DWCategory/DWObjectUtils', '~> 0.0.0.18'

end
