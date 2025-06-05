import pymysql
from pymysql.cursors import DictCursor

# DB config
conn = pymysql.connect(
    host="localhost",
    user="root",
    password="Master36!",
    database="ix_monitor",
    port=3306,
    cursorclass=DictCursor,
    autocommit=False,
    charset="utf8mb4",
)

try:
    with conn.cursor() as cursor:
        # Step 1: Select all defects with a photo
        cursor.execute("SELECT id, photo FROM object_defects WHERE photo IS NOT NULL")
        defects_with_photos = cursor.fetchall()

        print(f"Found {len(defects_with_photos)} defects with photos...")

        for defect in defects_with_photos:
            defect_id = defect["id"]
            photo_blob = defect["photo"]

            # Step 2: Insert photo into defect_photos
            cursor.execute("INSERT INTO defect_photos (photo) VALUES (%s)", (photo_blob,))
            photo_id = cursor.lastrowid

            # Step 3: Update object_defects with new photo_id
            cursor.execute("UPDATE object_defects SET photo_id = %s WHERE id = %s", (photo_id, defect_id))

        # Step 4: Commit all changes
        conn.commit()
        print("Migration completed successfully.")

except Exception as e:
    print("Error during migration:", e)
    conn.rollback()

finally:
    conn.close()
