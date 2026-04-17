require_relative "lib/bloom_fit/version"

Gem::Specification.new do |spec|
  authors = {
    "Ryan McGeary"        => "ryan@mcgeary.org",
    "Beshad Talayeminaei" => "btalayeminaei@gmail.com",
    "Ilya Grigorik"       => "ilya@grigorik.com",
    "Tatsuya Mori"        => "valdzone@gmail.com",
  }
  username      = "rmm5t"

  spec.name     = "bloom_fit"
  spec.version  = BloomFit::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.authors  = authors.keys
  spec.email    = authors.values
  spec.homepage = "https://github.com/#{username}/#{spec.name}"
  spec.summary  = "Bloom filters for Ruby with automatic sizing and a fast native in-memory core, with a small, Set-like API."

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "source_code_uri"       => spec.homepage,
    "funding_uri"           => "https://github.com/sponsors/#{username}",
    "rubygems_mfa_required" => "true",
  }

  spec.files = Dir.glob("{app,exe,ext,lib,test,spec}/**/*") + Dir.glob("{LICENSE,README}*")
  spec.require_paths = ["lib"]

  spec.add_dependency "msgpack", "~> 1.0"

  spec.required_ruby_version = ">= 3.2.0"

  spec.extensions = ["ext/cbloomfilter/extconf.rb"]
end
