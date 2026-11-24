Pod::Spec.new do |s|
  s.name             = 'custom_media_picker'
  s.version          = '0.2.0'
  s.summary          = 'Native PhotoKit side of the custom_media_picker Flutter plugin.'
  s.description      = <<-DESC
Pick images and videos from the device gallery with a custom Flutter UI.
                       DESC
  s.homepage         = 'https://github.com/Adelmostafa31/media_picker_demo'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Adel Mostafa' => 'https://github.com/Adelmostafa31' }
  s.source           = { :path => '.' }
  s.source_files     = 'custom_media_picker/Sources/custom_media_picker/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'Photos', 'AVFoundation', 'UniformTypeIdentifiers'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {
    'custom_media_picker_privacy' => ['custom_media_picker/Sources/custom_media_picker/PrivacyInfo.xcprivacy']
  }
end
