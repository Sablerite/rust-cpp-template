// C++ side of the cpp-example bridge. Declarations here must match the
// `unsafe extern "C++"` block in src/bridge.rs; cxx checks this at build time.
#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>

#include "rust/cxx.h"

namespace cpp_example {

// Running mean of a stream of values. Owned by Rust through a UniquePtr.
class Accumulator {
 public:
  void add(double value);
  [[nodiscard]] std::size_t count() const;
  [[nodiscard]] double mean() const;

 private:
  double sum_ = 0.0;
  std::size_t count_ = 0;
};

std::unique_ptr<Accumulator> new_accumulator();

rust::String format_greeting(rust::Str name, std::uint32_t times);

// Throws std::invalid_argument unless `text` is a positive base-10 integer.
std::uint32_t parse_positive(rust::Str text);

}  // namespace cpp_example
