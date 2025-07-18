# service/helpers/ell_buffer.py
from typing import Optional, Sequence

ELL_STATIONS = (3, 9)  # RMI01 = 3, ELL01 = 9

def mirror_ell_production(row: dict, connection) -> None:
    """
    Copy one productions row into ell_productions_buffer.
    If row['object_id'] is a string (id_modulo), resolve to INT object_id first.
    """
    with connection.cursor() as c:
        # If object_id is a string, resolve it to int via objects table
        if isinstance(row["object_id"], str):
            c.execute(
                "SELECT id FROM objects WHERE id_modulo = %s",
                (row["object_id"],)
            )
            res = c.fetchone()
            if not res:
                raise ValueError(f"Invalid id_modulo: {row['object_id']} not found in objects table")
            row["object_id"] = res["id"]

        # Insert with upsert — cycle_time is now computed in MySQL, not passed
        c.execute(
            """INSERT INTO ell_productions_buffer
               (id, object_id, station_id, start_time, end_time, esito)
               VALUES (%s, %s, %s, %s, %s, %s)
               ON DUPLICATE KEY UPDATE
                   end_time = VALUES(end_time),
                   esito = VALUES(esito)
            """,
            (
                row["id"], row["object_id"], row["station_id"],
                row["start_time"], row["end_time"], row["esito"]
            ),
        )
    connection.commit()


def mirror_defects(rows: Sequence[dict], connection) -> None:
    """
    Bulk-copy several object_defects rows into ell_defects_buffer.
    Each row must include all necessary fields, or defaults will be NULL.
    """
    if not rows:
        return

    payload = [
        (
            r["id"],
            r["production_id"],
            r["station_id"],
            r["object_id"],
            r["defect_id"],
            r.get("defect_type"),
            r.get("i_ribbon"),
            r.get("stringa"),
            r.get("ribbon_lato"),
            r.get("s_ribbon"),
            r.get("extra_data"),
            r.get("photo_id"),
            r.get("category"),
        )
        for r in rows
    ]

    with connection.cursor() as c:
        c.executemany(
            """INSERT IGNORE INTO ell_defects_buffer (
                   id, production_id, station_id, object_id,
                   defect_id, defect_type, i_ribbon, stringa,
                   ribbon_lato, s_ribbon, extra_data, photo_id, category
               ) VALUES (%s, %s, %s, %s,
                         %s, %s, %s, %s,
                         %s, %s, %s, %s, %s)
            """,
            payload,
        )
    connection.commit()
