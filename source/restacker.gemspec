require_relative 'lib/restacker'

Gem::Specification.new do |s|
  s.name    = 'restacker'
  s.version = VERSION
  s.date    = Time.now.utc.strftime("%Y-%m-%d")
  s.summary = 'A tool to help you deploy and restack your Cloud environment'
  s.bindir  = 'bin'
  s.executables << 'restacker'
  s.description = 'Restacker is a DevSecOps tool to help keep your Cloud deployment fresh and secure. There are many like it (maybe) but this one is mine.'
  s.authors = ['Javier Godinez', 'Peter Benjamin']
  s.email   = 'godinezj@gmail.com'
  s.files   = `git ls-files -z`.split("\x0")
  s.require_paths = ["lib"]
  s.add_runtime_dependency 'aws-sdk', '~> 2'
  s.add_runtime_dependency 'rainbow', '~> 2'
  s.homepage = 'https://github.com/devsecops/restacker'
  s.license = 'Apache-2.0'
end
