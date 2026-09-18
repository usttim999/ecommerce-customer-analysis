from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"

EVENTS_SOURCE = PROCESSED_DIR / "clean_events.csv"
CATEGORIES_SOURCE = PROCESSED_DIR / "clean_categories.csv"
HISTORY_SOURCE = PROCESSED_DIR / "item_category_history.csv"

EVENTS_OUTPUT = PROCESSED_DIR / "sql_events.csv"
CATEGORIES_OUTPUT = PROCESSED_DIR / "sql_categories.csv"
HISTORY_OUTPUT = PROCESSED_DIR / "sql_item_category_history.csv"


def prepare_events():
    """Prepare the large events file in memory-safe chunks."""

    total_rows = 0
    first_chunk = True

    for chunk in pd.read_csv(
        EVENTS_SOURCE,
        usecols=[
            "timestamp",
            "visitorid",
            "event",
            "itemid",
            "transactionid",
            "datetime",
        ],
        chunksize=250_000,
    ):
        chunk["transactionid"] = (
            pd.to_numeric(
                chunk["transactionid"],
                errors="coerce",
            )
            .astype("Int64")
        )

        chunk = chunk.rename(columns={
            "timestamp": "event_timestamp_ms",
            "visitorid": "visitor_id",
            "event": "event_type",
            "itemid": "item_id",
            "transactionid": "transaction_id",
            "datetime": "event_time",
        })

        chunk.to_csv(
            EVENTS_OUTPUT,
            mode="w" if first_chunk else "a",
            header=first_chunk,
            index=False,
            na_rep="",
        )

        total_rows += len(chunk)
        first_chunk = False

    print(f"sql_events.csv: {total_rows:,} rows")


def prepare_categories():
    """Prepare the category tree."""

    categories = pd.read_csv(CATEGORIES_SOURCE)

    categories["categoryid"] = (
        pd.to_numeric(categories["categoryid"])
        .astype("Int64")
    )

    categories["parentid"] = (
        pd.to_numeric(
            categories["parentid"],
            errors="coerce",
        )
        .astype("Int64")
    )

    categories = categories.rename(columns={
        "categoryid": "category_id",
        "parentid": "parent_id",
    })

    categories.to_csv(
        CATEGORIES_OUTPUT,
        index=False,
        na_rep="",
    )

    print(
        f"sql_categories.csv: "
        f"{len(categories):,} rows"
    )


def prepare_history():
    """Prepare item-category assignment history."""

    history = pd.read_csv(
        HISTORY_SOURCE,
        usecols=[
            "timestamp",
            "itemid",
            "categoryid",
            "datetime",
            "category_in_tree",
        ],
    )

    history = history.rename(columns={
        "timestamp": "change_timestamp_ms",
        "itemid": "item_id",
        "categoryid": "category_id",
        "datetime": "changed_at",
    })

    history.to_csv(
        HISTORY_OUTPUT,
        index=False,
        na_rep="",
    )

    print(
        f"sql_item_category_history.csv: "
        f"{len(history):,} rows"
    )


if __name__ == "__main__":
    prepare_events()
    prepare_categories()
    prepare_history()

    print("\nSQL export files prepared successfully.")