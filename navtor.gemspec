$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'navtor/version'

Gem::Specification.new do |spec|
  spec.name = 'navtor'
  spec.version = Navtor::VERSION
  spec.date = Navtor::DATE
  spec.description = 'Vi-like file manager'
  spec.summary = spec.description

  spec.authors = ['Thanh Dinh Khac']
  spec.email = 'thanhdk@gmail.com'

  spec.homepage = 'http://rubygems.org/gems/navtor'
  spec.license = 'MIT'

  spec.files = %w[navtor.gemspec] + Dir['*.md', 'bin/*', 'lib/*', 'lib/**/*.rb']
  spec.require_paths <<  'lib'
  spec.executables = ['navtor']

  spec.required_ruby_version = '>= 2.0'

  spec.add_development_dependency "bundler", "~> 1.0"

  spec.add_dependency 'curses', '~> 1.2'
end
