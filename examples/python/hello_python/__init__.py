"""Small, dependency-free functions for learning Python."""


def greeting(name: str = "world") -> str:
    """Greet a person, treating blank or whitespace-only names as 'world'."""
    clean_name = name.strip() or "world"
    return f"Hello, {clean_name}!"
