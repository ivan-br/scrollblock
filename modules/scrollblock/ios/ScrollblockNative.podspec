Pod::Spec.new do |s|
  s.name           = 'ScrollblockNative'
  s.version        = '1.0.0'
  s.summary        = 'Scrollblock VPN controller'
  s.description    = 'Controls the native Scrollblock test extension and reports actual OS state.'
  s.author         = ''
  s.homepage       = 'https://docs.expo.dev/modules/'
  s.platforms      = {
    :ios => '18.0'
  }
  s.source         = { git: '' }
  s.static_framework = true
  s.swift_version = '5.0'
  s.frameworks = 'NetworkExtension'

  s.dependency 'ExpoModulesCore'

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
