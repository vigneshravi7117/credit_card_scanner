Pod::Spec.new do |s|
  s.name             = 'credit_card_scanner'
  s.version          = '1.0.2'
  s.summary          = 'Credit card scanner plugin'
  s.description      = 'A Flutter plugin for scanning credit cards'
  s.homepage         = 'https://github.com/vigneshravi7117/credit_card_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'GoogleMLKit/TextRecognition', '~> 7.0'
  s.platform         = :ios, '15.5'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
  s.static_framework = true
end
