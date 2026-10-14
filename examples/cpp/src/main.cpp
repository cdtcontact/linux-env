#include "greeting.hpp"

#include <iostream>
#include <string_view>

int main(int argc, char* argv[])
{
    const std::string_view name = argc > 1 ? argv[1] : "C++";
    std::cout << learning::greeting(name) << '\n';
    return 0;
}
