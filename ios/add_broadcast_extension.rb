#!/usr/bin/env ruby
# 向 Runner.xcodeproj 注入 iOS 屏幕共享 Broadcast Upload Extension（BroadcastExtension）。
# 幂等：已存在同名 target 时跳过创建，仅校正构建设置。
require "xcodeproj"

PROJECT   = "Runner.xcodeproj"
EXT_NAME  = "BroadcastExtension"
EXT_GROUP = "BroadcastExtension"
APP_TEAM  = "3CDAMA869Z"
EXT_BUNDLE_ID = "com.beidou.aichat.broadcast"
DEPLOY_TARGET = "14.0"

SRC_FILES  = %w[SampleHandler.swift SampleUploader.swift SocketConnection.swift Atomic.swift DarwinNotificationCenter.swift]
INFO_PLIST = "#{EXT_GROUP}/Info.plist"
ENTITLEMENTS = "#{EXT_GROUP}/#{EXT_NAME}.entitlements"

project = Xcodeproj::Project.open(PROJECT)
runner  = project.targets.find { |t| t.name == "Runner" } or abort("找不到 Runner target")

# ---- 1. 创建/复用扩展 target ----
ext = project.targets.find { |t| t.name == EXT_NAME }
if ext.nil?
  ext = project.new_target(:app_extension, EXT_NAME, :ios, DEPLOY_TARGET)
  puts "✓ 已创建 app_extension target: #{EXT_NAME}"
else
  puts "• target #{EXT_NAME} 已存在，复用"
end

# ---- 2. 文件分组与源文件 ----
group = project.main_group[EXT_GROUP] || project.main_group.new_group(EXT_GROUP, EXT_GROUP)

# 清空该 target 现有 source build phase，避免重复
ext.source_build_phase.files_references.dup.each { |r| ext.source_build_phase.remove_file_reference(r) }

SRC_FILES.each do |fname|
  ref = group.files.find { |f| f.display_name == fname } || group.new_reference(fname)
  ext.add_file_references([ref])
end
# Info.plist 仅引用，不编译
unless group.files.any? { |f| f.display_name == "Info.plist" }
  group.new_reference("Info.plist")
end
unless group.files.any? { |f| f.display_name == "#{EXT_NAME}.entitlements" }
  group.new_reference("#{EXT_NAME}.entitlements")
end

# ---- 3. 扩展构建设置（三套配置）----
ext.build_configurations.each do |config|
  bs = config.build_settings
  bs["PRODUCT_BUNDLE_IDENTIFIER"] = EXT_BUNDLE_ID
  bs["PRODUCT_NAME"]              = "$(TARGET_NAME)"
  bs["INFOPLIST_FILE"]           = INFO_PLIST
  bs["CODE_SIGN_ENTITLEMENTS"]   = ENTITLEMENTS
  bs["CODE_SIGN_STYLE"]          = "Manual"
  bs["DEVELOPMENT_TEAM"]         = APP_TEAM
  bs["SWIFT_VERSION"]            = "5.0"
  bs["IPHONEOS_DEPLOYMENT_TARGET"] = DEPLOY_TARGET
  bs["TARGETED_DEVICE_FAMILY"]   = "1,2"
  bs["MARKETING_VERSION"]        = "1.0.5"
  bs["CURRENT_PROJECT_VERSION"]  = "19"
  bs["SKIP_INSTALL"]             = "YES"
  bs["GENERATE_INFOPLIST_FILE"]  = "NO"
  bs["LD_RUNPATH_SEARCH_PATHS"]  = ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
  bs["PROVISIONING_PROFILE_SPECIFIER"] ||= ""
end

# ---- 4. Runner 启用 App Group entitlements ----
runner.build_configurations.each do |config|
  config.build_settings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements"
end
unless project.main_group["Runner"]&.files&.any? { |f| f.display_name == "Runner.entitlements" }
  (project.main_group["Runner"] || project.main_group).new_reference("Runner/Runner.entitlements")
end

# ---- 5. Runner 依赖扩展 + 嵌入 PlugIns ----
runner.add_dependency(ext) unless runner.dependencies.any? { |d| d.target == ext }

embed = runner.copy_files_build_phases.find { |p| p.name == "Embed App Extensions" }
if embed.nil?
  embed = runner.new_copy_files_build_phase("Embed App Extensions")
  embed.symbol_dst_subfolder_spec = :plug_ins
  puts "✓ 已新增 Embed App Extensions 阶段"
end
unless embed.files_references.include?(ext.product_reference)
  bf = embed.add_file_reference(ext.product_reference)
  bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
end

project.save
puts "✓ 工程已保存。targets: #{project.targets.map(&:name).join(', ')}"
