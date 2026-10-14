"""Run with: python -m hello_python [name]."""

import argparse

from hello_python import greeting


def main() -> None:
    parser = argparse.ArgumentParser(description="A first Python command-line program")
    parser.add_argument("name", nargs="?", default="world", help="person to greet")
    args = parser.parse_args()
    print(greeting(args.name))


if __name__ == "__main__":
    main()
