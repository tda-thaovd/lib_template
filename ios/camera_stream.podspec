#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint camera_stream.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name = "camera_stream"
  s.version = "0.0.1"
  s.summary = "Camera Stream plugin for record video funtion."
  s.description = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage = "http://example.com"
  s.license = { :file => "../LICENSE" }
  s.author = { "Your Company" => "email@example.com" }
  s.source = { :path => "." }
  s.source_files = "Classes/**/*"
  s.dependency "Flutter"

  s.platform = :ios, "11.0"
  s.resource_bundles = {
    "Resources" => ["Images/*.{png}"],
  }

  s.frameworks = "AVKit"
  s.frameworks = "Vision"

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { "DEFINES_MODULE" => "YES", "EXCLUDED_ARCHS[sdk=iphonesimulator*]" => "i386" }
  s.swift_version = "5.0"
end
