Pod::Spec.new do |s|
  s.name               = "PCStackNavigationController"
  s.version            = "0.0.1"
  s.summary            = "Stack based (z-axis), tactile, card-style navigation controller."
  s.homepage           = "https://github.com/gilesvangruisen/PCStackNavigationController"
  s.license            = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Giles Van Gruisen " => "giles@gilesvangruisen.com" }
  s.social_media_url   = "http://twitter.com/gilesvangruisen"
  s.platform           = :ios, "6.0"
  s.source             = { :git => "https://github.com/gilesvangruisen/PCStackNavigationController.git", :tag => "0.0.1" }
  s.source_files       = "PCStackNavigationController/**/*.{h,m}"
  s.requires_arc       = true
  s.dependency "pop", "~> 1.0.6"
end
