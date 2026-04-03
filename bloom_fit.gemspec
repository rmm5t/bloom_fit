require_relative "lib/bloom_fit/version"

Gem::Specification.new do |spec|
  authors = {
    "Ilya Grigorik"       => "ilya@grigorik.com",
    "Tatsuya Mori"        => "valdzone@gmail.com",
    "Ryan McGeary"        => "ryan@mcgeary.org",
    "Beshad Talayeminaei" => "btalayeminaei@gmail.com ",
  }
  username      = "rmm5t"

  spec.name     = "bloom_fit"
  spec.version  = BloomFit::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.authors  = authors.keys
  spec.email    = authors.values
  spec.homepage = "https://github.com/#{username}/#{spec.name}"
  spec.summary  = "BloomFit helps you build correctly sized Bloom filters from expected set size and target false positive rate."

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

  spec.required_ruby_version = ">= 3.2.0"

  spec.extensions = ["ext/cbloomfilter/extconf.rb"]
end
