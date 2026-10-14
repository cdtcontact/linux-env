#ifndef GREETING_HPP
#define GREETING_HPP

#include <string>
#include <string_view>

namespace learning {

// An empty name falls back to "world". The returned string owns its contents.
std::string greeting(std::string_view name);

} // namespace learning

#endif
