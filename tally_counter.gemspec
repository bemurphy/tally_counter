# -*- encoding: utf-8 -*-
require File.expand_path('../lib/tally_counter/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Brendon Murphy"]
  gem.email         = ["xternal1+github@gmail.com"]
  gem.summary       = %q{Tally web application hits with Rack & Redis sorted sets}
  gem.description   = gem.summary
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^test/})
  gem.name          = "tally_counter"
  gem.require_paths = ["lib"]
  gem.version       = TallyCounter::VERSION

  gem.add_dependency "redis"
  gem.add_development_dependency "rack-test"
end
