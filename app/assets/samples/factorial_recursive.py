def factorial(n):
    """Recursive factorial. Base case: factorial(0) == 1."""
    if n == 0:
        return 1
    return n * factorial(n - 1)
