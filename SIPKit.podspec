#
# Be sure to run `pod lib lint SIPKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SIPKit'
  s.version          = '0.1.2'
  s.summary          = 'Framework for dealing with SIP, AMFI and Library Validation on macOS.'
  s.description      = 'A small framework for handling System Integirty Protection, Apple Mobile File Integirty and Library Validation on macOS.'
  s.homepage         = 'https://github.com/macenhance/SIPKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'macEnhance' => 'support@macenhance.com' }
  s.source           = { :git => 'https://github.com/macenhance/SIPKit.git', :tag => s.version.to_s }
  s.platform         = :osx
  s.source_files     = 'SIPKit/**/*.{h,m}'
  s.frameworks       = 'AppKit', 'AVFoundation', 'AVKit'
  s.osx.deployment_target = "10.10"

  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  # s.resource_bundles = {
  #   'SIPKit' => ['SIPKit/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.dependency 'AFNetworking', '~> 2.3'
end
