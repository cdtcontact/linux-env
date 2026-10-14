#include "greeting.hpp"

#include <array>
#include <iostream>
#include <string_view>

int main()
{
    struct TestCase {
        std::string_view name;
        std::string_view expected;
    };
    const std::array<TestCase, 4> cases = {{
        {"C++", "Hello, C++!"},
        {"", "Hello, world!"},
        {"Ada Lovelace", "Hello, Ada Lovelace!"},
        {"%s", "Hello, %s!"},
    }};

    for (const auto& test : cases) {
        const auto actual = learning::greeting(test.name);
        if (actual != test.expected) {
            std::cerr << "Expected: " << test.expected << "; got: " << actual << '\n';
            return 1;
        }
    }
    return 0;
}
