# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-play/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Yamashita Yuu"]
  gem.email         = ["yamashita@geishatokyo.com"]
  gem.description   = %q{a capistrano recipe to deploy Play! apps.}
  gem.summary       = %q{a capistrano recipe to deploy Play! apps.}
  gem.homepage      = "https://github.com/yyuu/capistrano-play"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capistrano-play"
  gem.require_paths = ["lib"]
  gem.version       = Capistrano::Play::VERSION

  gem.add_dependency("capistrano")
end
