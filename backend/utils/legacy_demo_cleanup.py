import argparse
import os
import sys
from typing import Iterable


BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from utils.db_seeder import ACTIVE_RESET_COLLECTIONS, LEGACY_COLLECTIONS, SEED_TAG
from utils.firebase_config import db


ACTIVE_COLLECTIONS = ACTIVE_RESET_COLLECTIONS
DEFAULT_LEGACY_COLLECTIONS = LEGACY_COLLECTIONS


def _stream_docs(collection_name: str):
    return db.collection(collection_name).stream()


def _count_docs(collection_name: str) -> int:
    return sum(1 for _ in _stream_docs(collection_name))


def _count_untagged_docs(collection_name: str) -> int:
    count = 0
    for doc in _stream_docs(collection_name):
        data = doc.to_dict() or {}
        if data.get("seed_source") != SEED_TAG:
            count += 1
    return count


def _delete_collection_docs(collection_name: str) -> int:
    deleted = 0
    for doc in _stream_docs(collection_name):
        doc.reference.delete()
        deleted += 1
    return deleted


def print_report(legacy_collections: Iterable[str]) -> None:
    print("=" * 64)
    print("SMART SHUTTLE LEGACY CLEANUP REPORT")
    print("=" * 64)
    print(f"Current tagged demo seed source: {SEED_TAG}")
    print("\nActive collections with untagged records:")
    for collection_name in ACTIVE_COLLECTIONS:
        total = _count_docs(collection_name)
        untagged = _count_untagged_docs(collection_name)
        print(f"  - {collection_name}: total={total}, untagged={untagged}")

    print("\nLegacy candidate collections:")
    for collection_name in legacy_collections:
        total = _count_docs(collection_name)
        print(f"  - {collection_name}: total={total}")

    print(
        "\nNothing is deleted in report mode. "
        "Use --delete-legacy to remove only the legacy candidate collections."
    )


def delete_legacy_collections(legacy_collections: Iterable[str]) -> None:
    print("\nDeleting legacy candidate collections...")
    total_deleted = 0
    for collection_name in legacy_collections:
        deleted = _delete_collection_docs(collection_name)
        total_deleted += deleted
        print(f"  - {collection_name}: deleted {deleted} document(s)")

    print(f"\nLegacy cleanup complete. Deleted {total_deleted} document(s) in total.")
    print(
        "Untagged records in active collections were intentionally left untouched "
        "for manual review."
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Report legacy Smart Shuttle demo data and optionally remove only "
            "legacy candidate collections."
        )
    )
    parser.add_argument(
        "--delete-legacy",
        action="store_true",
        help="Delete all documents inside the legacy candidate collections.",
    )
    parser.add_argument(
        "--legacy-collection",
        action="append",
        default=[],
        help=(
            "Add an extra collection name to the legacy cleanup list. "
            "Can be provided multiple times."
        ),
    )
    args = parser.parse_args()

    if db is None:
        raise RuntimeError("Firestore could not be initialized.")

    legacy_collections = [
        *DEFAULT_LEGACY_COLLECTIONS,
        *[name.strip() for name in args.legacy_collection if name.strip()],
    ]

    print_report(legacy_collections)
    if args.delete_legacy:
        delete_legacy_collections(legacy_collections)


if __name__ == "__main__":
    main()
