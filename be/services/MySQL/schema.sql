DB_SCHEMA = """
Il database contiene le seguenti tabelle:

1 `objects`
- id (PK)
- id_modulo (VARCHAR, UNIQUE)
- creator_station_id (FK to stations.id)
- created_at (DATETIME)

2 `stations`
- id (PK)
- line_id (FK to production_lines.id)
- name (VARCHAR)
- display_name (VARCHAR)
- type (ENUM: 'creator', 'qc', 'rework', 'other')
- config (JSON)
- created_at (DATETIME)

3 `production_lines`
- id (PK)
- name (VARCHAR)
- display_name (VARCHAR)
- description (TEXT)

4 `productions`
- id (PK)
- object_id (FK to objects.id)
- station_id (FK to stations.id)
- start_time (DATETIME)
- end_time (DATETIME)
- esito (INT) -- 1 = OK, 6 = KO, 2 = In Progress ( No Esito )
- operator_id (VARCHAR)
- cycle_time (TIME) -- calcolato come differenza tra end_time e start_time
- last_station_id (FK to stations.id, NULLABLE)

5 `defects`
- id (PK)
- category (ENUM: 'Generali', 'Saldatura', 'Disallineamento', 'Mancanza Ribbon', 'Macchie ECA', 'Celle Rotte', 'Lunghezza String Ribbon', 'Altro')

6 `object_defects`
- id (PK)
- production_id (FK to productions.id)
- defect_id (FK to defects.id)
- defect_type (VARCHAR, NULLABLE) -- usato solo per i "Generali"
- i_ribbon (INT, NULLABLE)
- stringa (INT, NULLABLE)
- ribbon_lato (ENUM: 'F', 'M', 'B', NULLABLE)
- s_ribbon (INT, NULLABLE)
- extra_data (VARCHAR, NULLABLE)

7 `station_defects`
- station_id (FK to stations.id)
- defect_id (FK to defects.id)
(Chiave primaria composta: station_id + defect_id)

"""""