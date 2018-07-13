Pod::Spec.new do |s|
s.name = 'DWDatabase'
s.version = '1.0.0'
s.license = { :type => 'MIT', :file => 'LICENSE' }
s.summary = '无入侵模型自动落库。Automaticly save model to database.'
s.homepage = 'https://github.com/CodeWicky/DWDatabase'
s.authors = { 'codeWicky' => 'codewicky@163.com' }
s.source = { :git => 'https://github.com/CodeWicky/DWDatabase.git', :tag => s.version.to_s }
s.requires_arc = true
s.ios.deployment_target = '7.0'
s.source_files = 'DWDatabase/**/{DWDatabase}.{h,m}'
s.frameworks = 'UIKit'

s.dependency 'FMDB', '~> 2.7.2'

end