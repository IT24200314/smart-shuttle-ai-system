from __future__ import annotations

import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = PROJECT_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from utils.firebase_project_config import (  # noqa: E402
    FirebaseConsistencyError,
    build_firebase_consistency_report,
    format_firebase_consistency_report,
)


def main() -> int:
    try:
        report = build_firebase_consistency_report()
        print(format_firebase_consistency_report(report))
        return 1 if report["mismatches"] else 0
    except FirebaseConsistencyError as exc:
        print(str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
