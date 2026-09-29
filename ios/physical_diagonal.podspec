Pod::Spec.new do |s|
  s.name             = 'physical_diagonal'
  s.version          = '2.0.0'
  s.summary          = 'Screen diagonal and physical metrics detection plugin.'
  s.description      = <<-DESC
Device and current-window physical diagonal detection (inches), plus a
tablet-layout heuristic driven by a configurable threshold.
                       DESC
  s.homepage         = 'https://github.com/DmytroIvanitsky/physical_diagonal'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dmytro Ivanitsky' => 'di.flutter@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'physical_diagonal/Sources/physical_diagonal/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
