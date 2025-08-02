import logging
import asyncio
from xml.etree import ElementTree as ET
from datetime import datetime, timedelta
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import (
    check_existing_production,
    get_last_station_id_from_productions,
    get_mysql_write_connection,
    insert_initial_production_data,
    update_production_final,
)

def wait_until_file_is_ready(file_path: str, timeout: int = 10) -> bool:
    """Wait until file is readable and not locked."""
    import time
    start = time.time()
    while time.time() - start < timeout:
        try:
            with open(file_path, 'r'):
                return True
        except PermissionError:
            time.sleep(0.5)
    return False

def handle_new_xml_file(file_path: str):
    print(f"📦 Handling new XML: {file_path}")

    if not wait_until_file_is_ready(file_path):
        logging.warning(f"❌ File is still locked after timeout: {file_path}")
        return

    try:
        tree = ET.parse(file_path)
        root = tree.getroot()

        # Extract fields
        id_modulo = root.findtext(".//ModuleId")
        judgement_text = root.findtext(".//FinalJudgement")
        inspection_time_text = root.findtext(".//InspectionTime")

        raw_esito = int(judgement_text) if judgement_text and judgement_text.isdigit() else 10
        data_inizio = (
            datetime.fromisoformat(inspection_time_text.replace("Z", "+00:00"))
            if inspection_time_text else datetime.now()
        )

        # Fixed mapping (adjust if dynamic per file in future)
        line =  [False, True, False, False, False]
        station_name = 'ELL01'

        # Determine outcome
        esito = 1 if raw_esito == 0 else 6 if raw_esito == 4 else 10
        fine_buona = (esito == 1)
        fine_scarto = (esito == 6)

        with get_mysql_write_connection() as conn:
            #print(id_modulo, station_name, data_inizio, esito)
            # Check if this event already exists
            if check_existing_production(id_modulo, station_name, data_inizio, conn):
                logging.info(f"⚠️ Skipping duplicate production for {id_modulo} at {station_name}")
                return
            else:
                last_station_id = get_last_station_id_from_productions(id_modulo, conn)

    except Exception as e:
        logging.warning(f"⚠️ Failed to parse XML file {file_path}: {e}")
        return

    try:
        # Prepare data and insert initial production
        initial_data = {
            "Id_Modulo": id_modulo,
            "DataInizio": data_inizio.strftime("%Y-%m-%d %H:%M:%S"),  # Matches MySQL schema
            "Id_Utente": "MBJ",
            "Linea_in_Lavorazione": line,
            "Last_Station": last_station_id,
        }

        with get_mysql_write_connection() as conn:
            production_id = insert_initial_production_data(initial_data, station_name, conn, esito=2)

        if not production_id:
            logging.warning(f"❌ insert_initial_production_data failed for {id_modulo}")
            return

        print(f"✅ Inserted initial production for {id_modulo} as ID {production_id}")

        # Compute Data_Fine 30 seconds after InspectionTime
        result = {
            "Id_Modulo": id_modulo,
            "DataFine": (data_inizio + timedelta(seconds=30)).strftime("%Y-%m-%d %H:%M:%S")
        }

        update_production_final(production_id, result, station_name, conn, fine_buona, fine_scarto)
        print(f"✅ Updated final production for {id_modulo} with esito {esito}")

    except Exception as e:
        logging.error(f"❌ MySQL operation failed for XML {file_path}: {e}")