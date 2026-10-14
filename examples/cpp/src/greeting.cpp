#include "greeting.hpp"

namespace learning {

std::string greeting(std::string_view name)
{
    if (name.empty()) {
        name = "world";
    }
    return "Hello, " + std::string(name) + "!";
}

} // namespace learning
