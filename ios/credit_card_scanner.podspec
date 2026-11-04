Pod::Spec.new do |s|
  s.name             = 'credit_card_scanner'
  s.version          = '2.2.1'
  s.summary          = 'Credit card scanner plugin'
  s.description      = 'A Flutter plugin for scanning credit cards'
  s.homepage         = 'https://github.com/vigneshravi7117/credit_card_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  # The scan line image. In its own bundle so it can't clash with the app's images.
  s.resource_bundles = { 'credit_card_scanner_assets' => ['Assets/blueScanLine.png'] }
  s.dependency 'Flutter'
  s.frameworks       = 'Vision'
  s.platform         = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
  s.static_framework = true
end
