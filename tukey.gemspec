# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tukey/version'

Gem::Specification.new do |spec|
  spec.name          = "tukey"
  spec.version       = Tukey::VERSION
  spec.authors       = ["Achilleas Buisman"]
  spec.email         = ["tukey@abuisman.nl"]

  spec.summary       = "DataSets for putting data in a tree of sets"
  spec.description   = "Tukey provides DataSets which can be put in a tree. This way you can store partial results of calculations or other data and, for example, create charts, tables or other presentations."
  spec.homepage      = "https://github.com/abuisman/tukey"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16.4"
  spec.add_development_dependency "rake", "~> 12.3.2"
  spec.add_development_dependency "rspec", "~> 3.8.0"
end
