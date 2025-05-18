#
# Be sure to run `pod lib lint MobilyflowSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MobilyflowSDK'
  s.module_name      = 'MobilyflowSDK'
  s.version          =        '0.1.1-alpha.10'
  s.summary          = 'MobilyFlow SDK for iOS'
  s.description      = 'Mobilyflow SDK for iOS'

  s.homepage         = 'https://www.mobilyflow.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MobilyFlow' => 'contact@mobilyflow.com' }
  s.source           = { :git => 'https://github.com/MobilyFlow/mobilyflow-ios-sdk.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_versions = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.source_files = 'Sources/MobilyflowSDK/**/*'
end
