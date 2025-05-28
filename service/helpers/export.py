from datetime import datetime
import os
import time
from typing import Optional, Set
from openpyxl.utils import get_column_letter
from openpyxl import Workbook
from openpyxl.styles import Alignment
from openpyxl.worksheet.worksheet import Worksheet
from openpyxl.styles import PatternFill
import pandas as pd
from collections import defaultdict

EXPORT_DIR = "./exports"
os.makedirs(EXPORT_DIR, exist_ok=True)

EXCEL_DEFECT_COLUMNS = {
    "NG Generali": "Generali",
    "NG Disall. Stringa": "Disallineamento",  # specific to stringa
    "NG Disall. Ribbon": "Disallineamento",   # specific to ribbon
    "NG Saldatura": "Saldatura",
    "NG Mancanza I_Ribbon": "Mancanza Ribbon",
    "NG I_Ribbon Leadwire": "I_Ribbon Leadwire",
    "NG Macchie ECA": "Macchie ECA",
    "NG Celle Rotte": "Celle Rotte",
    "NG Altro": "Altro",
    "NG Graffio su Cella": "Graffio su Cella",
    "NG Bad Soldering": "Bad Soldering",
}

SHEET_NAMES = [
    "Metadata", "Risolutivo", "NG Generali", "NG Saldature", "NG Disall. Ribbon",
    "NG Disall. Stringa", "NG Mancanza Ribbon", "NG I_Ribbon Leadwire", "NG Macchie ECA", "NG Celle Rotte", "NG Lunghezza String Ribbon", "NG Graffio su Cella", "NG Bad Soldering", "NG Altro"
]

def clean_old_exports(max_age_hours: int = 2):
    now = time.time()
    for filename in os.listdir(EXPORT_DIR):
        path = os.path.join(EXPORT_DIR, filename)
        if os.path.isfile(path):
            age = now - os.path.getmtime(path)
            if age > max_age_hours * 3600:
                print(f"🗑️ Deleting old file: {filename}")
                os.remove(path)

def export_full_excel(data: dict) -> str:
    filename = f"Esportazione_PMS_{datetime.now().strftime('%d-%m-%Y.%H-%M')}.xlsx"
    filepath = os.path.join(EXPORT_DIR, filename)

    wb = Workbook()

    # --- Remove default sheet if present
    default_sheet = wb.active
    if isinstance(default_sheet, Worksheet):
        wb.remove(default_sheet)

    for sheet_name in SHEET_NAMES:
        func = SHEET_FUNCTIONS.get(sheet_name)
        assert func is not None, f"Sheet function not found for sheet '{sheet_name}'"

        ws = wb.create_sheet(title=sheet_name)
        result = func(ws, data)

        # Only keep sheet if result is True or function is not boolean-returning (e.g., Metadata)
        if result is False:
            wb.remove(ws)

    wb.save(filepath)
    return filename

def autofit_columns(ws, align_center_for: Optional[Set[str]] = None):
    """
    Adjust column widths based on header and cell values, and apply alignment.

    :param ws: The worksheet to modify.
    :param align_center_for: Optional set of column headers that should be center-aligned.
    """
    if align_center_for is None:
        align_center_for = set()

    for col_idx, column_cells in enumerate(ws.iter_cols(min_row=1, max_row=ws.max_row), start=1):
        col_letter = get_column_letter(col_idx)
        header = ws[f"{col_letter}1"].value
        max_len = len(str(header)) if header else 0

        for cell in column_cells[1:]:  # Skip header
            val_len = len(str(cell.value)) if cell.value else 0
            max_len = max(max_len, val_len)

            if header in align_center_for:
                cell.alignment = Alignment(horizontal="center", vertical="center")
            else:
                cell.alignment = Alignment(horizontal="left", vertical="center")

        ws.column_dimensions[col_letter].width = max_len + 2

def metadata_sheet(ws, data: dict):
    from datetime import datetime

    current_time = datetime.now().strftime('%d/%m/%Y %H:%M:%S')
    productions = data.get("productions", [])
    id_moduli = data.get("id_moduli", [])
    filters = data.get("filters", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    ws.append(["📝 METADATI ESPORTAZIONE"])
    ws.append([])
    ws.append(["Data e ora esportazione:", current_time])
    ws.append(["Numero totale moduli esportati:", len(id_moduli)])
    ws.append(["Numero totale produzioni esportate:", len(productions)])

    # ➕ Breakdown by adjusted esito logic
    good = 0
    no_good = 0
    ok_op = 0
    not_checked = 0
    escluso = 0
    in_production = 0

    for p in productions:
        raw_esito = p.get("esito")
        cycle_time_obj = p.get("cycle_time")

        # Convert to seconds if possible
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except:
                pass

        # Classification logic (similar to map_esito)
        if raw_esito == 6:
            no_good += 1
        elif raw_esito == 1:
            if cycle_seconds is not None and cycle_seconds < min_cycle_threshold:
                not_checked += 1
            else:
                good += 1
        elif raw_esito == 5:
            if cycle_seconds is not None and cycle_seconds < min_cycle_threshold:
                not_checked += 1
            else:
                ok_op += 1
        elif raw_esito == 2:
            in_production += 1
        elif raw_esito == 4:
            escluso += 1

    # Add to sheet
    ws.append(["Good:", good])
    ws.append(["Good Operatore (ReWork):", ok_op])
    ws.append(["No Good:", no_good])
    ws.append(["Not Controllati QG2:", not_checked])
    ws.append(["Escluso:", escluso])
    ws.append(["In Produzione:", in_production])

    # Threshold info
    ws.append(["Soglia Minima Tempo Ciclo (sec):", f"{min_cycle_threshold:.1f}"])
    ws.append([])

    ws.append(["Filtri Attivi"])
    if filters:
        for f in filters:
            raw_value = f.get("value", "")
            segments = [seg.strip() for seg in raw_value.split(">") if seg.strip()]
            cleaned_value = " > ".join(segments)
            ws.append([f.get("type", "Filtro"), cleaned_value])
    else:
        ws.append(["Nessun filtro applicato"])
    ws.append([])

    # Autofit
    left_align = Alignment(horizontal="left", vertical="center")
    for col_idx, col_cells in enumerate(ws.columns, start=1):
        max_len = 0
        for cell in col_cells:
            cell.alignment = left_align
            val = str(cell.value) if cell.value else ""
            max_len = max(max_len, len(val))
        col_letter = get_column_letter(col_idx)
        ws.column_dimensions[col_letter].width = max_len + 4

def risolutivo_sheet(ws, data: dict):
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)
    fill_blue = PatternFill(start_color="CCE5FF", end_color="CCE5FF", fill_type="solid")
    fill_white = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    production_lines_by_id = {line["id"]: line for line in production_lines}

    # (modulo_id, station_id) → count
    modulo_station_counts = defaultdict(int)
    for prod in productions:
        obj = objects_by_id.get(prod.get("object_id"))
        if not obj:
            continue
        id_modulo = obj.get("id_modulo")
        station_id = prod.get("station_id")
        if id_modulo and station_id:
            modulo_station_counts[(id_modulo, station_id)] += 1

    rows = []
    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")
        modulo_event_count = modulo_station_counts.get((id_modulo, prod.get("station_id")), 0)

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"
        line_display_name = production_lines_by_id.get(station["line_id"], {}).get("display_name", "Unknown") if station else "Unknown"

        last_station_id = prod.get("last_station_id")
        last_station_name = stations_by_id.get(last_station_id, {}).get("display_name", "N/A") if last_station_id else "N/A"

        prod_defects = [d for d in object_defects if d.get("production_id") == production_id]
        ng_labels = set()
        for d in prod_defects:
            cat = d.get("category")
            if cat == "Disallineamento":
                if d.get("stringa") is not None:
                    ng_labels.add("NG Disall. Stringa")
                elif d.get("i_ribbon") is not None:
                    ng_labels.add("NG Disall. Ribbon")
            elif cat == "Generali":
                ng_labels.add("NG Generali")
            elif cat == "Saldatura":
                ng_labels.add("NG Saldatura")
            elif cat == "Mancanza Ribbon":
                ng_labels.add("NG Mancanza I_Ribbon")
            elif cat == "I_Ribbon Leadwire":
                ng_labels.add("NG I_Ribbon Leadwire")                
            elif cat == "Macchie ECA":
                ng_labels.add("NG Macchie ECA")
            elif cat == "Celle Rotte":
                ng_labels.add("NG Celle Rotte")
            elif cat == "Lunghezza String Ribbon":
                ng_labels.add("NG Lunghezza String Ribbon")
            elif cat == "Graffio su Cella":
                ng_labels.add("NG Graffio su Cella")
            elif cat == "Bad Soldering":
                ng_labels.add("NG Bad Soldering")
            elif cat == "Altro":
                ng_labels.add("NG Altro")

        row = {
            "Linea": line_display_name,
            "Stazione": station_name,
            "Stringatrice": last_station_name,
            "ID Modulo": id_modulo,
            "Data Ingresso": start_time,
            "Data Uscita": end_time,
            "Esito": esito,
            "Tempo Ciclo": cycle_time_str,
            "NG Causale": ";".join(sorted(ng_labels)) if ng_labels else "",
            "Numero Eventi": modulo_event_count
        }
        rows.append(row)

    df = pd.DataFrame(rows, columns=[
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo", "NG Causale", "Numero Eventi"
    ])

    # Track current modulo and fill toggle
    current_modulo = None
    current_fill = fill_white  # Start with white

    ws.append(df.columns.tolist())
    
    for idx, row in df.iterrows():
        id_modulo = row["ID Modulo"]
        if id_modulo != current_modulo:
            # Toggle fill color
            current_fill = fill_blue if current_fill == fill_white else fill_white
            current_modulo = id_modulo

        row_values = []
        for col in df.columns:
            val = row[col]
            if col in ["Data Ingresso", "Data Uscita"] and val:
                try:
                    row_values.append(val.strftime('%Y-%m-%d %H:%M:%S'))
                except Exception:
                    row_values.append(val)
            else:
                row_values.append(val)

        ws.append(row_values)
        row_idx = ws.max_row
        for col_idx, _ in enumerate(row_values, start=1):
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.fill = current_fill
    autofit_columns(ws, align_center_for={"Esito", "Numer Eventi"})

def ng_generali_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Generali' sheet using pre-fetched data.
    One row per production that has at least one 'Generali' defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo",
        "Poe Scaduto", "No Good da Bussing",
        "Materiale Esterno su Celle", "Passthrough al Bussing", 
        "Poe in Eccesso", "Solo Poe", "Solo Vetro", "Matrice Incompleta", 
        "Molteplici Bus Bar","Test"
    ]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue
        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"
        line_display_name = lines_by_id.get(station.get("line_id"), {}).get("display_name", "Unknown") if station else "Unknown"

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Generali"
        ]
        if not prod_defects:
            continue

        rows_written += 1

        general_defects = {d.get("defect_type") for d in prod_defects}
        flag_poe = "NG" if "Non Lavorato Poe Scaduto" in general_defects else ""
        flag_bus = "NG" if "No Good da Bussing" in general_defects else ""
        flag_materiale = "NG" if "Materiale Esterno su Celle" in general_defects else ""
        flag_passthrough = "NG" if "Passthrough al Bussing" in general_defects else ""
        flag_poe_in_eccesso = "NG" if "Poe in Eccesso" in general_defects else ""
        flag_solo_poe = "NG" if "Solo Poe" in general_defects else ""
        flag_solo_vetro = "NG" if "Solo Vetro" in general_defects else ""
        flag_matrice_incompleta = "NG" if "Matrice Incompleta" in general_defects else ""
        flag_molteplici_bus_bar = "NG" if "Molteplici Bus Bar" in general_defects else ""
        flag_test = "NG" if "Test" in general_defects else ""

        row = [
            line_display_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str,
            flag_poe,
            flag_bus,
            flag_materiale,
            flag_passthrough,
            flag_poe_in_eccesso,
            flag_solo_poe,
            flag_solo_vetro,
            flag_matrice_incompleta,
            flag_molteplici_bus_bar,
            flag_test
        ]
        ws.append(row)

    if rows_written > 0:
        autofit_columns(ws, align_center_for={
            "Esito", "Poe Scaduto", "No Good da Bussing",
            "Materiale Esterno su Celle", "Passthrough al Bussing", "Poe in Eccesso","Solo Poe", "Solo Vetro", "Matrice Incompleta", "Molteplici Bus Bar", "Test"
        })
        return True
    else:
        return False

def ng_saldature_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Saldature' sheet using pre-fetched data.
    One row per production that has at least one 'Saldatura' defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ]
    for i in range(1, 13):
        header.append(f"Stringa {i}")
        header.append(f"Stringa {i}M")
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        # Only include productions with at least one "Saldatura" defect
        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Saldatura"
        ]
        if not prod_defects:
            continue

        # Map of (stringa, lato) → list of s_ribbon
        pin_map = {}
        for defect in prod_defects:
            stringa = defect.get("stringa")
            lato = defect.get("ribbon_lato")
            s_ribbon = defect.get("s_ribbon")

            if stringa is None or lato is None or s_ribbon is None:
                continue

            try:
                key = (int(stringa), str(lato))
                pin_map.setdefault(key, []).append(str(s_ribbon))
            except (ValueError, TypeError):
                continue

        # Build saldatura cells: 24 columns (Stringa 1, 1M, ..., 12, 12M)
        saldatura_cols = [""] * 24
        for (stringa_num, lato), pins in pin_map.items():
            if not (1 <= stringa_num <= 12):
                continue
            formatted = f"NG: {';'.join(pins)};"
            col_index = (stringa_num - 1) * 2
            if lato == "M":
                col_index += 1
            saldatura_cols[col_index] = formatted

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + saldatura_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_disall_ribbon_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Disallineamento Ribbon' sheet using pre-fetched data.
    One row per production with at least one Disallineamento Ribbon defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo",
        "Ribbon 1 F", "Ribbon 2 F", "Ribbon 3 F",
        "Ribbon 1 M", "Ribbon 2 M", "Ribbon 3 M", "Ribbon 4 M",
        "Ribbon 1 B", "Ribbon 2 B", "Ribbon 3 B"
    ]
    ws.append(header)

    ribbon_map = {
        ("F", 1): 0, ("F", 2): 1, ("F", 3): 2,
        ("M", 1): 3, ("M", 2): 4, ("M", 3): 5, ("M", 4): 6,
        ("B", 1): 7, ("B", 2): 8, ("B", 3): 9,
    }

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        # Filter defects with category = 'Disallineamento' and valid ribbon data
        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and
               d.get("category") == "Disallineamento" and
               d.get("i_ribbon") is not None and
               d.get("ribbon_lato") in ["F", "M", "B"]
        ]
        if not prod_defects:
            continue

        ribbon_cols = [""] * 10
        for defect in prod_defects:
            lato = defect.get("ribbon_lato")
            i_ribbon = defect.get("i_ribbon")
            try:
                idx = ribbon_map.get((str(lato), int(i_ribbon))) # type: ignore
                if idx is not None:
                    ribbon_cols[idx] = "NG"
            except (ValueError, TypeError):
                continue

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + ribbon_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_disall_stringa_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Disallineamento Stringa' sheet using pre-fetched data.
    One row per production with at least one Disallineamento Stringa defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + [f"Stringa {i}" for i in range(1, 13)]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and
               d.get("category") == "Disallineamento" and
               d.get("stringa") is not None
        ]
        if not prod_defects:
            continue

        stringa_cols = [""] * 12
        for defect in prod_defects:
            stringa_num = defect.get("stringa")
            try:
                index = int(stringa_num)
                if 1 <= index <= 12:
                    stringa_cols[index - 1] = "NG"
            except (ValueError, TypeError):
                continue

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + stringa_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_mancanza_ribbon_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Mancanza Ribbon' sheet using pre-fetched data.
    One row per production with at least one Mancanza Ribbon defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo",
        "Ribbon 1 F", "Ribbon 2 F", "Ribbon 3 F",
        "Ribbon 1 M", "Ribbon 2 M", "Ribbon 3 M", "Ribbon 4 M",
        "Ribbon 1 B", "Ribbon 2 B", "Ribbon 3 B"
    ]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Mancanza Ribbon"
        ]
        if not prod_defects:
            continue

        ribbon_cols = [""] * 10
        ribbon_map = {
            ("F", 1): 0, ("F", 2): 1, ("F", 3): 2,
            ("M", 1): 3, ("M", 2): 4, ("M", 3): 5, ("M", 4): 6,
            ("B", 1): 7, ("B", 2): 8, ("B", 3): 9,
        }

        for defect in prod_defects:
            lato = defect.get("ribbon_lato")
            i_ribbon = defect.get("i_ribbon")
            try:
                idx = ribbon_map.get((str(lato), int(i_ribbon))) # type: ignore
                if idx is not None:
                    ribbon_cols[idx] = "NG"
            except (ValueError, TypeError):
                continue

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + ribbon_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False
    
def ng_iribbon_leadwire_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG I_Ribbon Leadwire' sheet using pre-fetched data.
    One row per production with at least one I_Ribbon Leadwire defect (only side M ribbons 1–4).
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo",
        "Ribbon 1 M", "Ribbon 2 M", "Ribbon 3 M", "Ribbon 4 M"
    ]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "I_Ribbon Leadwire"
        ]
        if not prod_defects:
            continue

        ribbon_cols = [""] * 4  # Only 4 ribbons on M side
        ribbon_map = {
            1: 0,
            2: 1,
            3: 2,
            4: 3,
        }

        for defect in prod_defects:
            lato = defect.get("ribbon_lato")
            i_ribbon = defect.get("i_ribbon")
            if lato == "M":
                try:
                    idx = ribbon_map.get(int(i_ribbon))  # type: ignore
                    if idx is not None:
                        ribbon_cols[idx] = "NG"
                except (ValueError, TypeError):
                    continue

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + ribbon_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_macchie_eca_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Macchie ECA' sheet using pre-fetched data.
    One row per production with at least one Macchie ECA defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + [f"Stringa {i}" for i in range(1, 13)]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Macchie ECA"
        ]
        if not prod_defects:
            continue

        stringa_cols = [""] * 12
        for defect in prod_defects:
            stringa_num = defect.get("stringa")
            if isinstance(stringa_num, int) and 1 <= stringa_num <= 12:
                stringa_cols[stringa_num - 1] = "NG"
            elif isinstance(stringa_num, str) and stringa_num.isdigit():
                index = int(stringa_num)
                if 1 <= index <= 12:
                    stringa_cols[index - 1] = "NG"

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + stringa_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_bad_soldering_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Bad Soldering' sheet using pre-fetched data.
    One row per production with at least one Bad Soldering defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + [f"Stringa {i}" for i in range(1, 13)]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Bad Soldering"
        ]
        if not prod_defects:
            continue

        stringa_cols = [""] * 12
        for defect in prod_defects:
            stringa_num = defect.get("stringa")
            if isinstance(stringa_num, int) and 1 <= stringa_num <= 12:
                stringa_cols[stringa_num - 1] = "NG"
            elif isinstance(stringa_num, str) and stringa_num.isdigit():
                index = int(stringa_num)
                if 1 <= index <= 12:
                    stringa_cols[index - 1] = "NG"

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + stringa_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_celle_rotte_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Celle Rotte' sheet using pre-fetched data.
    One row per production with at least one Celle Rotte defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + [f"Stringa {i}" for i in range(1, 13)]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Celle Rotte"
        ]
        if not prod_defects:
            continue

        stringa_cols = [""] * 12
        for defect in prod_defects:
            stringa_num = defect.get("stringa")
            if isinstance(stringa_num, int) and 1 <= stringa_num <= 12:
                stringa_cols[stringa_num - 1] = "NG"
            elif isinstance(stringa_num, str) and stringa_num.isdigit():
                index = int(stringa_num)
                if 1 <= index <= 12:
                    stringa_cols[index - 1] = "NG"

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + stringa_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_lunghezza_string_ribbon_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Lunghezza String Ribbon' sheet using pre-fetched data.
    One row per production with at least one relevant defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + [f"Stringa {i}" for i in range(1, 13)]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Lunghezza String Ribbon"
        ]
        if not prod_defects:
            continue

        stringa_cols = [""] * 12
        for defect in prod_defects:
            stringa_num = defect.get("stringa")
            if isinstance(stringa_num, int) and 1 <= stringa_num <= 12:
                stringa_cols[stringa_num - 1] = "NG"
            elif isinstance(stringa_num, str) and stringa_num.isdigit():
                index = int(stringa_num)
                if 1 <= index <= 12:
                    stringa_cols[index - 1] = "NG"

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + stringa_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

def ng_graffio_su_cella_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Graffio su Cella' sheet using pre-fetched data.
    One row per production with at least one 'Graffio su Cella' defect.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + [f"Stringa {i}" for i in range(1, 13)]
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        # ✅ This is the key change!
        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Graffio su Cella"
        ]
        if not prod_defects:
            continue

        stringa_cols = [""] * 12
        for defect in prod_defects:
            stringa_num = defect.get("stringa")
            if isinstance(stringa_num, int) and 1 <= stringa_num <= 12:
                stringa_cols[stringa_num - 1] = "NG"
            elif isinstance(stringa_num, str) and stringa_num.isdigit():
                index = int(stringa_num)
                if 1 <= index <= 12:
                    stringa_cols[index - 1] = "NG"

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + stringa_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False
    
def ng_altro_sheet(ws, data: dict) -> bool:
    """
    Generate the 'NG Altro' sheet using pre-fetched data.
    One row per production. Columns are dynamically created from unique 'extra_data' descriptions.
    """
    rows_written = 0
    objects = data.get("objects", [])
    productions = data.get("productions", [])
    stations = data.get("stations", [])
    production_lines = data.get("production_lines", [])
    object_defects = data.get("object_defects", [])
    min_cycle_threshold = data.get("min_cycle_threshold", 3.0)

    objects_by_id = {obj["id"]: obj for obj in objects}
    stations_by_id = {station["id"]: station for station in stations}
    lines_by_id = {line["id"]: line for line in production_lines}

    # Step 1: gather all unique "Altro" extra_data values
    unique_altro_descriptions = sorted({
        d.get("extra_data", "").strip()
        for d in object_defects
        if d.get("category") == "Altro" and d.get("extra_data")
    })

    # Step 2: build header
    header = [
        "Linea", "Stazione", "Stringatrice", "ID Modulo",
        "Data Ingresso", "Data Uscita", "Esito", "Tempo Ciclo"
    ] + unique_altro_descriptions
    ws.append(header)

    for prod in productions:
        object_id = prod.get("object_id")
        obj = objects_by_id.get(object_id)
        if not obj:
            continue

        id_modulo = obj.get("id_modulo")
        if not id_modulo:
            continue

        production_id = prod.get("id")
        start_time = prod.get("start_time")
        end_time = prod.get("end_time")
        cycle_time_obj = prod.get("cycle_time")
        cycle_time_str = str(cycle_time_obj or "")

        # ✅ Convert cycle time to seconds
        cycle_seconds = None
        if cycle_time_obj:
            try:
                h, m, s = map(float, str(cycle_time_obj).split(":"))
                cycle_seconds = h * 3600 + m * 60 + s
            except Exception:
                pass

        esito = map_esito(prod.get("esito"), cycle_seconds, min_cycle_threshold)

        station = stations_by_id.get(prod.get("station_id"))
        station_name = station.get("display_name", "Unknown") if station else "Unknown"

        line_name = "Unknown"
        if station and station.get("line_id"):
            line = lines_by_id.get(station["line_id"])
            if line:
                line_name = line.get("display_name", "Unknown")

        last_station_name = "N/A"
        last_station_id = prod.get("last_station_id")
        if last_station_id:
            last_station = stations_by_id.get(last_station_id)
            if last_station:
                last_station_name = last_station.get("display_name", "N/A")

        prod_defects = [
            d for d in object_defects
            if d.get("production_id") == production_id and d.get("category") == "Altro"
        ]
        if not prod_defects:
            continue

        altro_found = {d.get("extra_data", "").strip() for d in prod_defects}

        altro_cols = ["NG" if desc in altro_found else "" for desc in unique_altro_descriptions]

        row = [
            line_name,
            station_name,
            last_station_name,
            id_modulo,
            start_time.strftime('%Y-%m-%d %H:%M:%S') if start_time else "",
            end_time.strftime('%Y-%m-%d %H:%M:%S') if end_time else "",
            esito,
            cycle_time_str
        ] + altro_cols

        ws.append(row)
        rows_written += 1

    if rows_written > 0:
        autofit_columns(ws, align_center_for=set(header))
        return True
    else:
        return False

# --- Mapping sheet names to functions ---
SHEET_FUNCTIONS = {
    "Metadata": metadata_sheet,
    "Risolutivo": risolutivo_sheet,
    "NG Generali": ng_generali_sheet,
    "NG Saldature": ng_saldature_sheet,
    "NG Disall. Ribbon": ng_disall_ribbon_sheet,
    "NG Disall. Stringa": ng_disall_stringa_sheet,
    "NG Mancanza Ribbon": ng_mancanza_ribbon_sheet,
    "NG I_Ribbon Leadwire": ng_iribbon_leadwire_sheet,
    "NG Macchie ECA": ng_macchie_eca_sheet,
    "NG Celle Rotte": ng_celle_rotte_sheet,
    "NG Lunghezza String Ribbon": ng_lunghezza_string_ribbon_sheet,
    "NG Graffio su Cella": ng_graffio_su_cella_sheet,
    "NG Bad Soldering": ng_bad_soldering_sheet,
    "NG Altro": ng_altro_sheet,
}

def map_esito(value: Optional[int], cycle_seconds: Optional[float] = None, threshold: float = 3.0) -> str:
    if value == 1:  # G
        if cycle_seconds is not None and cycle_seconds < threshold:
            return "NC"
        return "G"
    elif value == 2:
        return "In Produzione"
    elif value == 4:
        return "Escluso"
    elif value == 5:
        return "G Operatore"
    elif value == 6:
        return "NG"
    return "N/A"
