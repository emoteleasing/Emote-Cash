platform :ios, '15.0'
source 'https://cdn.cocoapods.org/'

target 'HQITwoFncesd' do
  use_frameworks!

  pod 'SDWebImage'
  pod 'MBProgressHUD'
  pod 'AFNetworking'
  pod 'Masonry'
  pod 'Adjust', '~> 5.4.4'
  pod 'IQKeyboardManager'
end

post_install do |installer|
  [
    'Pods/AFNetworking/AFNetworking/AFNetworkReachabilityManager.m',
    'Pods/AFNetworking/AFNetworking/AFHTTPSessionManager.m'
  ].each do |path|
    next unless File.exist?(path)
    content = File.read(path)
    next unless content.include?('netinet6/in6.h')
    File.chmod(0644, path)
    File.write(path, content.gsub("#import <netinet6/in6.h>\n", ''))
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
    end
  end
end