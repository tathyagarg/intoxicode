import re
import time
import gzip
import tarfile

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

def is_valid_tar_gz(file_path: str) -> bool:
    try:
        with gzip.open(file_path, 'rb') as f:
            f.read(1)

        with tarfile.open(file_path, 'r:gz') as tar:
            tar.getmembers()

        return True
    except (tarfile.TarError, OSError) as e:
        print(f"Error validating tar.gz file: {e}")
        return False

def is_valid_version(version: str) -> bool:
    return bool(re.match(r'v\d+\.\d+\.\d+', version))
