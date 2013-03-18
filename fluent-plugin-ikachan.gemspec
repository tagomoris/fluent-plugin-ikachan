# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-ikachan"
  gem.version       = "0.2.1"
  gem.authors       = ["TAGOMORI Satoshi"]
  gem.email         = ["tagomoris@gmail.com"]
  gem.summary       = %q{output plugin for IRC-HTTP gateway 'ikachan'}
  gem.description   = %q{output plugin for IRC-HTTP gateway 'ikachan' (see: https://metacpan.org/module/ikachan and (jpn) http://blog.yappo.jp/yappo/archives/000760.html)}
  gem.homepage      = "https://github.com/tagomoris/fluent-plugin-ikachan"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "fluentd"
  gem.add_development_dependency "rake"
  gem.add_runtime_dependency "fluentd"
end
