# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com//), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased] - TBD

-

## [1.0.0] - 2026-04-04

- Add tests for CBloomFilter ([#15])
- Update readme ([#16])
- Add support for capacity and false_positive_rate ([#17])

## [0.3.1] - 2026-04-04

- Add rdoc comments ([#14])

## [0.3.0] - 2026-04-04

- Switch from rspec to minitest ([#7])
- Rename #insert to #add to be more conventional ([#8])
- Change #include? to only accept one key arg ([#9])
- Refactor using Forwardable delegators ([#10])
- Refactored the interface and methods to behave more like a Set ([#11])
- Remove counting feature of CBloomFilter ([#12])
- Code maintenance and cleanup ([#13])

## [0.2.0] - 2026-04-03

- Bug Fixes
- Fix all compiler warnings
- Simplify and fix dbj2 implementation
- Code maintenance and cleanup

## [0.1.1] - 2026-04-02

- General cleanup and maintenance

## [0.1.0] - 2026-04-02

- Initial release based on [bloomfilter-rb](https://github.com/igrigorik/bloomfilter-rb)

[Unreleased]: https://github.com/rmm5t/bloom_fit/compare/v1.0.0..HEAD
[1.0.0]: https://github.com/rmm5t/bloom_fit/compare/v0.3.1..v1.0.0
[0.3.1]: https://github.com/rmm5t/bloom_fit/compare/v0.3.0..v0.3.1
[0.3.0]: https://github.com/rmm5t/bloom_fit/compare/v0.2.0..v0.3.0
[0.2.0]: https://github.com/rmm5t/bloom_fit/compare/v0.1.1..v0.2.0
[0.1.1]: https://github.com/rmm5t/bloom_fit/compare/v0.1.0..v0.1.1
[0.1.0]: https://github.com/rmm5t/bloom_fit/compare/fork..v0.1.0

[#7]: https://github.com/rmm5t/bloom_fit/pull/7
[#8]: https://github.com/rmm5t/bloom_fit/pull/8
[#9]: https://github.com/rmm5t/bloom_fit/pull/9
[#10]: https://github.com/rmm5t/bloom_fit/pull/10
[#11]: https://github.com/rmm5t/bloom_fit/pull/11
[#12]: https://github.com/rmm5t/bloom_fit/pull/12
[#13]: https://github.com/rmm5t/bloom_fit/pull/13
[#14]: https://github.com/rmm5t/bloom_fit/pull/14
[#15]: https://github.com/rmm5t/bloom_fit/pull/15
[#16]: https://github.com/rmm5t/bloom_fit/pull/16
[#17]: https://github.com/rmm5t/bloom_fit/pull/17
