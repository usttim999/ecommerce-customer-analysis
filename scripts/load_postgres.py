from getpass import getpass
from pathlib import Path
from time import perf_counter

import psycopg
from psycopg import sql


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"

CONNECTION_SETTINGS = {
    "host": "localhost",
    "port": 5432,
    "dbname": "ecommerce_analysis",
    "user": "postgres",
}


def load_csv(
    table_name,
    file_path,
    columns,
    expected_rows,
    password,
):
    """Load one CSV file using PostgreSQL COPY."""

    started_at = perf_counter()

    with psycopg.connect(
        **CONNECTION_SETTINGS,
        password=password,
    ) as connection:

        with connection.cursor() as cursor:
            table_identifier = sql.Identifier(
                "raw",
                table_name,
            )

            cursor.execute(
                sql.SQL(
                    "SELECT COUNT(*) FROM {};"
                ).format(table_identifier)
            )

            existing_rows = cursor.fetchone()[0]

            if existing_rows == expected_rows:
                print(
                    f"raw.{table_name}: "
                    f"{existing_rows:,} rows already loaded"
                )
                return

            if existing_rows != 0:
                raise RuntimeError(
                    f"raw.{table_name} contains "
                    f"{existing_rows:,} rows; "
                    f"expected either 0 or "
                    f"{expected_rows:,}."
                )

            column_identifiers = sql.SQL(", ").join(
                sql.Identifier(column)
                for column in columns
            )

            copy_query = sql.SQL(
                """
                COPY {} ({})
                FROM STDIN
                WITH (
                    FORMAT CSV,
                    HEADER TRUE,
                    NULL ''
                );
                """
            ).format(
                table_identifier,
                column_identifiers,
            )

            with cursor.copy(copy_query) as copy:
                with file_path.open(
                    mode="r",
                    encoding="utf-8",
                    newline="",
                ) as csv_file:

                    while data := csv_file.read(
                        1024 * 1024
                    ):
                        copy.write(data)

            cursor.execute(
                sql.SQL(
                    "SELECT COUNT(*) FROM {};"
                ).format(table_identifier)
            )

            loaded_rows = cursor.fetchone()[0]

            if loaded_rows != expected_rows:
                raise RuntimeError(
                    f"raw.{table_name}: loaded "
                    f"{loaded_rows:,} rows instead of "
                    f"{expected_rows:,}."
                )

    elapsed_seconds = perf_counter() - started_at

    print(
        f"raw.{table_name}: "
        f"{expected_rows:,} rows loaded "
        f"in {elapsed_seconds:.1f} seconds"
    )


def main():
    password = getpass(
        "Введите пароль пользователя postgres: "
    )

    load_csv(
        table_name="categories",
        file_path=(
            PROCESSED_DIR / "sql_categories.csv"
        ),
        columns=[
            "category_id",
            "parent_id",
        ],
        expected_rows=1_669,
        password=password,
    )

    load_csv(
        table_name="item_category_history",
        file_path=(
            PROCESSED_DIR
            / "sql_item_category_history.csv"
        ),
        columns=[
            "change_timestamp_ms",
            "item_id",
            "category_id",
            "changed_at",
            "category_in_tree",
        ],
        expected_rows=442_672,
        password=password,
    )

    load_csv(
        table_name="events",
        file_path=(
            PROCESSED_DIR / "sql_events.csv"
        ),
        columns=[
            "event_timestamp_ms",
            "visitor_id",
            "event_type",
            "item_id",
            "transaction_id",
            "event_time",
        ],
        expected_rows=2_755_641,
        password=password,
    )

    print("\nAll PostgreSQL tables are ready.")


if __name__ == "__main__":
    main()