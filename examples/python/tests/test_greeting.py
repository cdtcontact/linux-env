"""Run from the project root: python -m unittest discover -s tests -v."""

import unittest

from hello_python import greeting


class GreetingTests(unittest.TestCase):
    def test_default_name(self) -> None:
        self.assertEqual(greeting(), "Hello, world!")

    def test_name(self) -> None:
        self.assertEqual(greeting("Python"), "Hello, Python!")

    def test_whitespace_is_trimmed(self) -> None:
        self.assertEqual(greeting("  Ada Lovelace  "), "Hello, Ada Lovelace!")

    def test_blank_name(self) -> None:
        for name in ("", " ", "\t\n"):
            with self.subTest(name=name):
                self.assertEqual(greeting(name), "Hello, world!")


if __name__ == "__main__":
    unittest.main()
