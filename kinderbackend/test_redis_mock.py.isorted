"""Mock Redis client for testing rate limiting and device binding."""


class MockRedis:
    """A simple in-memory mock Redis client for testing.

    This implements only the methods used by rate limiting and device binding:
    - get(key) -> str | None
    - set(key, value) -> None
    - setex(key, seconds, value) -> None
    - incr(key) -> int
    - expire(key, seconds, nx=False) -> None
    - delete(*keys) -> None
    - pipeline() -> MockPipeline
    """

    def __init__(self):
        self._data: dict[str, str] = {}
        self._ttl: dict[str, float] = {}
        self._initial_values: dict[str, int] = {}  # Track initial values for incr

    def get(self, key: str) -> str | None:
        return self._data.get(key)

    def set(self, key: str, value: str) -> None:
        self._data[key] = value

    def setex(self, key: str, seconds: int, value: str) -> None:
        self._data[key] = value
        # Note: We don't implement TTL expiration for simplicity in tests

    def incr(self, key: str) -> int:
        if key not in self._data:
            self._data[key] = "0"
        current = int(self._data[key])
        new_value = current + 1
        self._data[key] = str(new_value)
        return new_value

    def expire(self, key: str, seconds: int, nx: bool = False) -> None:
        # Note: We don't implement TTL expiration for simplicity in tests
        pass

    def delete(self, *keys: str) -> None:
        for key in keys:
            self._data.pop(key, None)
            self._ttl.pop(key, None)

    def pipeline(self):
        return MockPipeline(self)

    def ping(self):
        return True

    def clear(self):
        """Clear all data - useful for test isolation."""
        self._data.clear()
        self._ttl.clear()
        self._initial_values.clear()


class MockPipeline:
    """Mock Redis pipeline for testing."""

    def __init__(self, redis: MockRedis):
        self._redis = redis
        self._commands: list[tuple[str, tuple]] = []

    def incr(self, key: str):
        self._commands.append(("incr", (key,)))
        return self

    def expire(self, key: str, seconds: int, nx: bool = False):
        self._commands.append(("expire", (key, seconds, nx)))
        return self

    def execute(self):
        """Execute all queued commands and return results."""
        results = []
        for cmd, args in self._commands:
            if cmd == "incr":
                results.append(self._redis.incr(*args))
            elif cmd == "expire":
                results.append(True)  # expire returns True/False
        self._commands.clear()
        return results


# Global mock Redis instance for tests
_mock_redis: MockRedis | None = None


def get_mock_redis() -> MockRedis:
    """Get or create the global mock Redis instance."""
    global _mock_redis
    if _mock_redis is None:
        _mock_redis = MockRedis()
    return _mock_redis


def reset_mock_redis():
    """Reset the global mock Redis instance - useful for test isolation."""
    global _mock_redis
    if _mock_redis is not None:
        _mock_redis.clear()
