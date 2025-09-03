import time

def verify_username(username: str) -> tuple[bool, str | None]:
    if len(username) < 3 or len(username) > 30:
        return False, "Username must be between 3 and 30 characters"

    if not username.isalnum():
        return False, "Username must be alphanumeric"

    return True, None


def make_jwt_message(username: str) -> dict[str, str | int]:
    return {
        "iss": "intoxicode-packages",
        "sub": username,
        "iat": int(time.time())
    }
