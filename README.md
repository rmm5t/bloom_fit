# BloomFit

[![Gem Version](https://img.shields.io/gem/v/bloom_fit.svg)](https://rubygems.org/gems/bloom_fit)
[![CI](https://github.com/rmm5t/bloom_fit/actions/workflows/ci.yml/badge.svg)](https://github.com/rmm5t/bloom_fit/actions/workflows/ci.yml)
[![Gem Downloads](https://img.shields.io/gem/dt/bloom_fit.svg)](https://rubygems.org/gems/bloom_fit)

BloomFit is an in-memory, non-counting Bloom filter for Ruby backed by a small C extension.

It gives you a compact, Set-like API for probabilistic membership checks:

- false positives are possible
- false negatives are not, as long as a value was added to the same filter
- individual values cannot be deleted safely because the filter is non-counting

BloomFit is heavily inspired by [bloomfilter-rb]'s native implementation and the original C implementation by Tatsuya Mori. This version uses a DJB2 hash with salts from the CRC table and wraps the native filter in a Ruby-friendly API. The most common way to use it is to pass an expected `capacity` and optional `false_positive_rate`, then let BloomFit calculate `size` and `hashes` for you.

Compared with bloomfilter-rb, BloomFit:

- uses DJB2 over CRC32 yielding better hash distribution
- improves performance for very large datasets
- avoids the need to supply a seed
- automatically calculates the filter size (`m`) and hash count (`k`) from capacity and false-positive rate

## Features

- native `CBloomFilter` implementation for MRI Ruby
- automatic sizing from `capacity` and `false_positive_rate`
- small Ruby API with familiar methods like `add`, `include?`, `merge`, `|`, and `&`
- supports strings, symbols, integers, booleans, and other values that can be converted with `to_s`
- manual `size` / `hashes` overrides when you want control
- serialize filters with msgpack via `to_msgpack`, `BloomFit.unpack`, `save`, and `BloomFit.load`
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

filter = BloomFit.new(capacity: 250, false_positive_rate: 0.001)

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

filter.size            # => 3595
filter.hashes          # => 10

filter.clear
filter.empty?          # => true
```

`#include?`, `#key?`, and `#[]` are aliases. `#add` and `#<<` are also aliases.

## Automatic Sizing

BloomFit now calculates `size` and `hashes` for you when you initialize it with an expected capacity:

```ruby
filter = BloomFit.new(capacity: 10_000, false_positive_rate: 0.01)

filter.size   # => 95851
filter.hashes # => 7
```

The defaults are a good starting point for many small filters:

```ruby
filter = BloomFit.new

filter.size   # => 1438
filter.hashes # => 10
```

That is equivalent to:

```ruby
filter = BloomFit.new(capacity: 100, false_positive_rate: 0.001)
```

Internally BloomFit uses the standard Bloom filter formulas:

```text
m = -(n * ln(p)) / (ln(2)^2)
k = (m / n) * ln(2)
```

- `n`: expected number of inserted values
- `p`: target false-positive rate
- `m`: number of filter buckets (`size`)
- `k`: number of hash functions (`hashes`)

For example, if you expect about `10_000` inserts and can tolerate a `1%` false-positive rate, BloomFit will calculate `size: 95_851` and `hashes: 7` for you.

If you prefer a calculator, see [Bloom Filter Calculator](https://hur.st/bloomfilter/).

## Manual Sizing

If you already know the exact filter width and hash count you want, you can still pass them directly:

```ruby
filter = BloomFit.new(size: 95_851, hashes: 7)
```

This bypasses automatic sizing.

## Common Operations

### Add and check membership

```ruby
filter = BloomFit.new(capacity: 100)

filter << "cat"
filter << "dog"

filter.include?("cat")  # => true
filter.include?("bird") # => false
```

### Use hash-like syntax for truthy values

```ruby
filter = BloomFit.new(capacity: 64)

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
pets = BloomFit.new(capacity: 50)
pets << "cat" << "dog"

more_pets = BloomFit.new(capacity: 50)
more_pets << "dog" << "bird"

combined = pets | more_pets
overlap = pets & more_pets

combined.include?("bird") # => true
overlap.include?("dog")   # => true
overlap.include?("cat")   # => false
```

`#merge` also accepts arrays, sets, and other enumerables:

```ruby
filter = BloomFit.new(capacity: 100)
filter.merge(%w[cat dog bird])
```

Filters can only be combined when they have the same `size` and `hashes`. Otherwise BloomFit raises `ArgumentError`.

When you create filters with automatic sizing, use the same `capacity` and `false_positive_rate` for filters you plan to merge, union, or intersect.

### Save and load filters

```ruby
filter = BloomFit.new(capacity: 100)
filter << "cat" << "dog"
filter.save("pets.bloom")

reloaded = BloomFit.load("pets.bloom")
reloaded.include?("cat") # => true
reloaded.include?("dog") # => true
```

Persistence uses msgpack, not Ruby `Marshal`.

If you want the serialized bytes directly instead of writing a file:

```ruby
filter = BloomFit.new(capacity: 100)
filter << "cat"

payload = filter.to_msgpack
copy = BloomFit.unpack(payload)

copy.include?("cat") # => true
```

The msgpack payload stores the filter `size`, `hashes`, and raw bitmap.

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
| `BloomFit.new` or `BloomFit.new(capacity:, false_positive_rate:)` | Creates a filter and calculates `size` and `hashes` automatically. Defaults to `capacity: 100`, `false_positive_rate: 0.001`. |
| `BloomFit.new(size:, hashes:)` | Creates a filter with explicit sizing when you want fixed parameters. |
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
| `to_msgpack`, `BloomFit.unpack` | Serializes and restores a filter as msgpack bytes. |
| `save`, `BloomFit.load` | Persists and restores a filter using the same msgpack format. |

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
