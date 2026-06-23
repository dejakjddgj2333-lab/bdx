#!/usr/bin/env ruby
# 为 Runner 与 BroadcastExtension 配置 Manual 分发签名（App Store distribution）。
require "xcodeproj"

IDENTITY = "iPhone Distribution: Chongqing Junxianzhi Technology Co., Ltd"
TEAM = "3CDAMA869Z"
MAP = { "Runner" => "beidou", "BroadcastExtension" => "broadcast" }

project = Xcodeproj::Project.open("Runner.xcodeproj")
MAP.each do |target_name, profile_name|
  t = project.targets.find { |t| t.name == target_name } or abort("缺少 target #{target_name}")
  t.build_configurations.each do |config|
    bs = config.build_settings
    bs["CODE_SIGN_STYLE"] = "Manual"
    bs["DEVELOPMENT_TEAM"] = TEAM
    bs["CODE_SIGN_IDENTITY"] = IDENTITY
    bs["CODE_SIGN_IDENTITY[sdk=iphoneos*]"] = IDENTITY
    bs["PROVISIONING_PROFILE_SPECIFIER"] = profile_name
    bs.delete("PROVISIONING_PROFILE") # 旧式 UUID 键清掉，避免冲突
  end
  puts "✓ #{target_name} → profile '#{profile_name}'，identity '#{IDENTITY}'"
end
project.save
puts "✓ 已保存签名配置"
