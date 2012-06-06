# -*- encoding: utf-8 -*-
require File.expand_path('../lib/edison_tools/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["omar@omarqureshi.net"]
  gem.email         = ["omar@omarqureshi.net"]
  gem.description   = %q{A few startup scripts and tools that are used for deployment and provisioning of servers}
  gem.summary       = %q{Edison Nations Rails Tools}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "edison_tools"
  gem.require_paths = ["lib"]
  gem.version       = EdisonTools::VERSION
end
