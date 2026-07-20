Pod::Spec.new do |s|
  s.name             = 'qa_native'
  s.version          = '0.0.1'
  s.summary          = 'QuickAnimaker native core (FFI).'
  s.description      = 'The portable C hot loops, compiled into the app.'
  s.homepage         = 'https://github.com/myoun99/quick_animaker_v2'
  s.license          = { :file => '../../../LICENSE' }
  s.author           = { 'PARK GUNWOO' => 'noreply@example.com' }
  s.source           = { :path => '.' }

  # Classes/ holds only a forwarder that includes ../src — see the note
  # in that file. The engine is STATICALLY linked into the app: iOS does
  # not allow loading a standalone dylib from the bundle, so Dart resolves
  # its symbols with DynamicLibrary.process().
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_OPTIMIZATION_LEVEL' => '3',
  }
  s.swift_version = '5.0'
end
