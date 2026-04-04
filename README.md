# BloomFit

[![Gem Version](https://img.shields.io/gem/v/bloom_fit.svg)](https://rubygems.org/gems/bloom_fit)
[![CI](https://github.com/rmm5t/bloom_fit/actions/workflows/ci.yml/badge.svg)](https://github.com/rmm5t/bloom_fit/actions/workflows/ci.yml)
[![Gem Downloads](https://img.shields.io/gem/dt/bloom_fit.svg)](https://rubygems.org/gems/bloom_fit)

BloomFit is an in-memory, non-counting Bloom filter for Ruby backed by a small C extension.

It gives you a compact, Set-like API for probabilistic membership checks:

- false positives are possible
- false negatives are not, as long as a value was added to the same filter
- individual values cannot be deleted safely because the filter is non-counting

BloomFit is heavily inspired by [bloomfilter-rb]'s native implementation and the original C implementation by Tatsuya Mori. This version uses a DJB2 hash with salts from the CRC table and wraps the native filter in a Ruby-friendly API. This is an improvement over bloomfilter-rb in the following ways:

- uses DJB2 over CRC32 yielding better hash distribution
- improves performance for very large datasets
- avoids the need to supply a seed
- automatically calculates the bit size (m) and the number of hashes (k) when given a capacity and false-positive-rate

## Features

- native `CBloomFilter` implementation for MRI Ruby
- small Ruby API with familiar methods like `add`, `include?`, `merge`, `|`, and `&`
- supports strings, symbols, integers, booleans, and other values that can be converted with `to_s`
- save and reload filters with Ruby `Marshal`
- inspect filter state with `stats`, `to_hex`, `to_binary`, and `bitmap`

## Requirements

- Ruby `>= 3.2.0`

## Installation

```bash
gem install bloom_fit
```

```ruby
require "bloom_fit"
```

## Quick Start

```ruby
require "bloom_fit"

filter = BloomFit.new(size: 10_000, hashes: 6)

filter.add("cat")
filter << :dog

filter.include?("cat") # => true
filter.key?("dog")     # => true
filter["bird"]         # => false

filter["owl"] = true
filter["ant"] = false

filter["owl"]          # => true
filter["ant"]          # => false

filter.empty?          # => false

filter.clear
filter.empty?          # => true
```

`#include?`, `#key?`, and `#[]` are aliases. `#add` and `#<<` are also aliases.

## Choosing `size` and `hashes`

BloomFit currently expects explicit `size` and `hashes` values when you create a filter:

```ruby
filter = BloomFit.new(size: 95_851, hashes: 7)
```

If you want to size a filter from an expected number of inserts and a target false-positive rate, use the standard Bloom filter formulas:

```text
m = -(n * ln(p)) / (ln(2)^2)
k = (m / n) * ln(2)
```

- `n`: expected number of inserted values
- `p`: target false-positive rate
- `m`: number of filter buckets (`size`)
- `k`: number of hash functions (`hashes`)

For example, if you expect about `10_000` inserts and can tolerate a `1%` false-positive rate, a good starting point is `size: 95_851` and `hashes: 7`.

If you prefer a calculator, see [Bloom Filter Calculator](https://hur.st/bloomfilter/).

## Common Operations

### Add and check membership

```ruby
filter = BloomFit.new(size: 1_000, hashes: 4)

filter << "cat"
filter << "dog"

filter.include?("cat")  # => true
filter.include?("bird") # => false
```

### Use hash-like syntax for truthy values

```ruby
filter = BloomFit.new(size: 256, hashes: 4)

filter[:cat] = true
filter[:dog] = false

filter[:cat] # => true
filter[:dog] # => false

filter.merge({ bird: true, ant: nil })

filter.include?(:bird) # => true
filter.include?(:ant)  # => false
```

When merging a hash, only keys with truthy values are added.

### Merge, union, and intersection

```ruby
pets = BloomFit.new(size: 64, hashes: 3)
pets << "cat" << "dog"

more_pets = BloomFit.new(size: 64, hashes: 3)
more_pets << "dog" << "bird"

combined = pets | more_pets
overlap = pets & more_pets

combined.include?("bird") # => true
overlap.include?("dog")   # => true
overlap.include?("cat")   # => false
```

`#merge` also accepts arrays, sets, and other enumerables:

```ruby
filter = BloomFit.new(size: 1_000, hashes: 4)
filter.merge(%w[cat dog bird])
```

Filters can only be combined when they have the same `size` and `hashes`. Otherwise BloomFit raises `BloomFit::ConfigurationMismatch`.

### Save and load filters

```ruby
filter = BloomFit.new(size: 1_000, hashes: 4)
filter << "cat" << "dog"
filter.save("pets.bloom")

reloaded = BloomFit.load("pets.bloom")
reloaded.include?("cat") # => true
reloaded.include?("dog") # => true
```

Persistence uses Ruby `Marshal`. Only load files you trust.

### Inspect the bitmap

```ruby
filter = BloomFit.new(size: 16, hashes: 4)
filter << "cool"

filter.to_hex    # => "1441"
filter.to_binary # => "0001010001000001"
filter.bitmap    # => raw bytes from the native filter
```

`#bitmap` returns the native byte representation, which may include padding bytes beyond the configured filter width. `#to_binary` trims the result to exactly `size` bits.

## API Overview

| Method | Notes |
| --- | --- |
| `BloomFit.new(size:, hashes:)` | Creates an empty filter. Defaults to `size: 1000`, `hashes: 4`. |
| `add`, `<<` | Adds a value and returns the filter. |
| `add?` | Adds only when the value does not already appear present. |
| `include?`, `key?`, `[]` | Probabilistic membership check. |
| `[]=` | Adds a key only when the assigned value is truthy. |
| `merge` | Merges another filter or an enumerable into the receiver. |
| `\|`, `union` | Returns a new filter containing the union. |
| `&`, `intersection` | Returns a new filter containing the intersection. |
| `clear` | Resets all bits to `0`. |
| `empty?` | Exact check for whether any bits are set. |
| `size`, `m` | Returns the configured filter width. |
| `hashes`, `k` | Returns the number of hash functions. |
| `set_bits`, `n` | Returns the number of bits currently set. |
| `stats` | Returns a human-readable summary including predicted false-positive rate. |
| `to_hex`, `to_binary`, `bitmap` | Returns the filter bitmap in different representations. |
| `save`, `BloomFit.load` | Serializes and restores a filter with Ruby `Marshal`. |

## Resources

- Background: [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter)
- Determining parameters: [Scalable Datasets: Bloom Filters in Ruby](http://www.igvita.com/2008/12/27/scalable-datasets-bloom-filters-in-ruby/)
- Applications and motivation: [Flow analysis: Time based bloom filter](http://www.igvita.com/2010/01/06/flow-analysis-time-based-bloom-filters/)
- Calculator: [Bloom Filter Calculator](https://hur.st/bloomfilter/)

## Credits

- Tatsuya Mori <valdzone@gmail.com> (Original C implementation)
- Ilya Grigorik [@igrigorik](https://github.com/igrigorik) ([bloomfilter-rb] gem)
- Bharanee Rathna [@deepfryed](https://github.com/deepfryed) ([bloom-filter](https://github.com/deepfryed/bloom-filter) gem)

## License

[MIT License](https://rmm5t.mit-license.org/)

[bloomfilter-rb]: https://github.com/igrigorik/bloomfilter-rb
