Pod::Spec.new do |s|
  s.name         = "LYPScreenRecord"
  s.version      = "0.0.1"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.summary      = "LYPScreenRecord"
  s.homepage     = "https://github.com/liyingpeng/LYPScreenRecord"
  s.source       = { :git => "https://github.com/liyingpeng/LYPScreenRecord.git", :tag => "0.0.1" }
  s.source_files = "LYPScreenRecord/Classes/*.{h,m}"
  s.requires_arc = true
  s.platform     = :ios, "7.0"
  s.author       = { "李应鹏" => "a1045021949a@hotmail.com" } # 作者信息
end