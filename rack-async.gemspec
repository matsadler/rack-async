Gem::Specification.new do |s|
  s.name = "rack-async"
  s.version = "0.0.1"
  s.summary = "An asynchronous Rack API for everyone."
  s.description = "Thin's asynchronous API available to any Rack server."
  s.files = Dir["lib/**/*.rb"] << "README.rdoc"
  s.require_path = "lib"
  s.rdoc_options << "--main" << "README.rdoc" << "--charset" << "utf-8"
  s.extra_rdoc_files = ["README.rdoc"]
  s.author = "Matthew Sadler"
  s.email = "mat@sourcetagsandcodes.com"
  s.homepage = "http://github.com/matsadler/rack-async"
end