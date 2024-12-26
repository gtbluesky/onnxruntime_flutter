#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint onnxruntime.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'onnxruntime'
  s.version          = '0.0.1'
  s.summary          = 'OnnxRuntime plugin for Flutter apps.'
  s.description      = <<-DESC
OnnxRuntime plugin for Flutter apps.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  # s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'onnxruntime-objc', '1.20.0'
  s.dependency 'onnxruntime-extensions-c', '0.13.0'
  s.platform = :ios, '13.3'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
