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

def ensure_framework_privacy_manifest(installer, pod_name)
  src = File.join(__dir__, 'PrivacyManifests', "#{pod_name}.xcprivacy")
  return unless File.exist?(src)

  target = installer.pods_project.targets.find { |t| t.name == pod_name }
  return unless target

  dest_dir = File.join(installer.sandbox.root.to_s, pod_name)
  FileUtils.mkdir_p(dest_dir)
  FileUtils.cp(src, File.join(dest_dir, 'PrivacyInfo.xcprivacy'))

  phase = target.resources_build_phase
  return if phase.files_references.any? { |ref| ref.path.to_s.end_with?('PrivacyInfo.xcprivacy') }

  group = installer.pods_project.main_group.children.find { |child| child.display_name == pod_name || child.path == pod_name }
  group = installer.pods_project.main_group.new_group(pod_name, pod_name) if group.nil?
  file_ref = group.new_file('PrivacyInfo.xcprivacy')
  phase.add_file_reference(file_ref, true)
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

  %w[AFNetworking MBProgressHUD].each do |pod_name|
    ensure_framework_privacy_manifest(installer, pod_name)
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
    end
  end
end