#!/usr/bin/env python3
"""Post-deploy smoke test: verify a deployed endpoint is healthy.

Exits 0 if the endpoint returns HTTP 200 with status "healthy",
non-zero otherwise — which fails the pipeline job.
"""
import json
import sys
import time
import urllib.error
import urllib.request


def check(url: str, retries: int = 5, delay: int = 5) -> bool:
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                body = json.loads(resp.read().decode())
                if resp.status == 200 and body.get("status") == "healthy":
                    print(f"✓ {url} is healthy (attempt {attempt})")
                    return True
                print(f"✗ Unexpected response: {resp.status} {body}")
        except (urllib.error.URLError, json.JSONDecodeError) as exc:
            print(f"… attempt {attempt}/{retries} failed: {exc}")
        if attempt < retries:
            time.sleep(delay)
    return False


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: smoke_test.py <health-url>")
        sys.exit(2)

    target = sys.argv[1]
    print(f"Smoke testing {target} ...")
    sys.exit(0 if check(target) else 1)