from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from openai import OpenAI
from openai.types.chat import (
    ChatCompletionMessageParam,
    ChatCompletionSystemMessageParam,
    ChatCompletionUserMessageParam,
    ChatCompletionAssistantMessageParam,
)
from typing import List, Optional, Literal

import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.connections.mysql import get_mysql_connection

# Initialize OpenAI client
client = OpenAI(api_key="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")

router = APIRouter()

# ------------------ MODELS ------------------

class ChatMessage(BaseModel):
    role: Literal['user', 'assistant']
    content: str

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []

class ChatResponse(BaseModel):
    response: str


# --------------------- System Prompt & Schema ---------------------

DB_SCHEMA = """
Hai accesso a un database MySQL per il monitoraggio della produzione.

-- -----------------------------------------------------
-- Schema ix_monitor
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ix_monitor DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci ;
USE ix_monitor ;

-- -----------------------------------------------------
-- Table ix_monitor.defects
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.defects (
  id INT NOT NULL AUTO_INCREMENT,
  category VARCHAR(50) NULL DEFAULT 'Altro',
  PRIMARY KEY (id))
ENGINE = InnoDB
AUTO_INCREMENT = 100
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.production_lines
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.production_lines (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  display_name VARCHAR(45) NULL DEFAULT NULL,
  description TEXT NULL DEFAULT NULL,
  PRIMARY KEY (id))
ENGINE = InnoDB
AUTO_INCREMENT = 4
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.stations
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.stations (
  id INT NOT NULL AUTO_INCREMENT,
  line_id INT NOT NULL,
  name VARCHAR(50) NOT NULL,
  display_name VARCHAR(50) NULL DEFAULT NULL,
  type ENUM('creator', 'qc', 'rework', 'other') NULL DEFAULT 'other',
  config JSON NULL DEFAULT NULL,
  created_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX line_id (line_id ASC) INVISIBLE,
  CONSTRAINT stations_ibfk_1
    FOREIGN KEY (line_id)
    REFERENCES ix_monitor.production_lines (id))
ENGINE = InnoDB
AUTO_INCREMENT = 17
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.objects
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.objects (
  id INT NOT NULL AUTO_INCREMENT,
  id_modulo VARCHAR(50) NOT NULL,
  creator_station_id INT NOT NULL,
  created_at DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE INDEX id_modulo (id_modulo ASC) VISIBLE,
  UNIQUE INDEX id_UNIQUE (id ASC) VISIBLE,
  INDEX creator_station_id (creator_station_id ASC) VISIBLE,
  CONSTRAINT objects_ibfk_1
    FOREIGN KEY (creator_station_id)
    REFERENCES ix_monitor.stations (id))
ENGINE = InnoDB
AUTO_INCREMENT = 4753
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.productions
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.productions (
  id INT NOT NULL AUTO_INCREMENT,
  object_id INT NOT NULL,
  station_id INT NOT NULL,
  start_time DATETIME NULL DEFAULT NULL,
  end_time DATETIME NULL DEFAULT NULL,
  esito INT NULL DEFAULT NULL,
  operator_id VARCHAR(50) NULL DEFAULT NULL,
  cycle_time TIME GENERATED ALWAYS AS (timediff(end_time,start_time)) STORED,
  last_station_id INT NULL DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX id_UNIQUE (id ASC) INVISIBLE,
  INDEX object_id (object_id ASC) VISIBLE,
  INDEX station_id (station_id ASC) VISIBLE,
  CONSTRAINT productions_ibfk_1
    FOREIGN KEY (object_id)
    REFERENCES ix_monitor.objects (id),
  CONSTRAINT productions_ibfk_2
    FOREIGN KEY (station_id)
    REFERENCES ix_monitor.stations (id))
ENGINE = InnoDB
AUTO_INCREMENT = 4701
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.object_defects
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.object_defects (
  id INT NOT NULL AUTO_INCREMENT,
  production_id INT NOT NULL,
  defect_id INT NOT NULL,
  defect_type VARCHAR(45) NULL DEFAULT NULL,
  i_ribbon INT NULL DEFAULT NULL,
  stringa INT NULL DEFAULT NULL,
  ribbon_lato ENUM('F', 'M', 'B') NULL DEFAULT NULL,
  s_ribbon INT NULL DEFAULT NULL,
  extra_data VARCHAR(45) NULL DEFAULT NULL,
  photo LONGBLOB NULL DEFAULT NULL,
  PRIMARY KEY (id),
  INDEX production_id (production_id ASC) VISIBLE,
  INDEX defect_id (defect_id ASC) VISIBLE,
  CONSTRAINT object_defects_ibfk_1
    FOREIGN KEY (production_id)
    REFERENCES ix_monitor.productions (id),
  CONSTRAINT object_defects_ibfk_2
    FOREIGN KEY (defect_id)
    REFERENCES ix_monitor.defects (id))
ENGINE = InnoDB
AUTO_INCREMENT = 322
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.station_defects
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.station_defects (
  station_id INT NOT NULL,
  defect_id INT NOT NULL,
  PRIMARY KEY (station_id, defect_id),
  INDEX defect_id (defect_id ASC) VISIBLE,
  CONSTRAINT station_defects_ibfk_1
    FOREIGN KEY (station_id)
    REFERENCES ix_monitor.stations (id),
  CONSTRAINT station_defects_ibfk_2
    FOREIGN KEY (defect_id)
    REFERENCES ix_monitor.defects (id))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table ix_monitor.stringatrice_warnings
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ix_monitor.stringatrice_warnings (
  id INT NOT NULL AUTO_INCREMENT,
  line_name VARCHAR(50) NULL DEFAULT NULL,
  station_name VARCHAR(50) NULL DEFAULT NULL,
  station_display VARCHAR(100) NULL DEFAULT NULL,
  defect VARCHAR(100) NULL DEFAULT NULL,
  type ENUM('threshold', 'consecutive') NULL DEFAULT NULL,
  value INT NULL DEFAULT NULL,
  limit_value INT NULL DEFAULT NULL,
  timestamp DATETIME NULL DEFAULT NULL,
  acknowledged TINYINT(1) NULL DEFAULT '0',
  source_station VARCHAR(50) NULL DEFAULT NULL,
  suppress_on_source TINYINT(1) NULL DEFAULT '0',
  photo LONGBLOB NULL DEFAULT NULL,
  PRIMARY KEY (id))
"""

SYSTEM_PROMPT = f"""
Sei un assistente AI esperto in SQL per il database di produzione descritto sotto.

─────────────────────────────  ISTRUZIONI OBBLIGATORIE  ─────────────────────────────

1. ❌ NESSUN TESTO EXTRA
   ❌ NON usare commenti, spiegazioni.
   ✅ Scrivi SOLO la query all'interno di blocchi **```sql ... ```**

2. ✅ JOIN obbligatorie (NO sotto-select!):

   FROM  ix_monitor.productions         p
   JOIN  ix_monitor.objects             o  ON o.id = p.object_id
   JOIN  ix_monitor.stations            s  ON s.id = p.station_id
   JOIN  ix_monitor.production_lines    l  ON l.id = s.line_id
   LEFT  JOIN ix_monitor.object_defects od ON od.production_id = p.id
   LEFT  JOIN ix_monitor.defects        d  ON d.id = od.defect_id

3. ✅ Filtri da usare:
   • Linea      → l.display_name           (es. 'Linea B')
   • Stazione   → s.name                   (es. 'M308')
   • Data       → DATE(p.end_time)         oppure intervallo su p.end_time
   • Esito      → p.esito con la mappa:    G=1, In Produzione=2, Escluso=4, G Operatore=5, NG=6
   • Difetti    → usa già le JOIN a object_defects e defects

4. ✅ Seleziona sempre almeno questi campi:

   SELECT
       p.id               AS production_id,
       o.id_modulo,
       p.esito,
       p.operator_id,
       p.cycle_time,
       p.start_time,
       p.end_time,
       s.name             AS station_name,
       l.display_name     AS line_display_name,
       GROUP_CONCAT(DISTINCT d.category) AS defect_categories

5. ✅ Clausole finali obbligatorie:
   • GROUP BY p.id
   • ORDER BY p.end_time DESC
   • LIMIT 1000

6. ❓ Se mancano Linea, Stazione o Data, chiedile PRIMA di scrivere la query.
   Esempio: *"Quale linea e stazione desideri filtrare?"*

7. ✅ FORMATO DI OUTPUT OBBLIGATORIO
   Tutta la query deve essere dentro un unico blocco:

```sql
SELECT ...
```

────────────────────────────────────────────────────────────  SCHEMA  ────────────────────────────────────────────────────────────

{DB_SCHEMA}
"""

# --------------------- Chat Endpoint ---------------------

@router.post("/api/chat_query", response_model=ChatResponse)
async def chat_query(req: ChatRequest):
    try:
        # Compose message list
        messages: List[ChatCompletionMessageParam] = [
            ChatCompletionSystemMessageParam(role="system", content=SYSTEM_PROMPT)
        ]

        # Convert history to strict types
        if req.history:
            for msg in req.history:
                if msg.role == "user":
                    messages.append(ChatCompletionUserMessageParam(role="user", content=msg.content))
                elif msg.role == "assistant":
                    messages.append(ChatCompletionAssistantMessageParam(role="assistant", content=msg.content))

        # Add current user message
        messages.append(ChatCompletionUserMessageParam(role="user", content=req.message))

        # OpenAI call
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            temperature=0,
        )

        result = response.choices[0].message.content or ""
        return ChatResponse(response=result)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore OpenAI: {e}")
    

class SQLQueryRequest(BaseModel):
    query: str

@router.post("/api/run_sql_query")
async def run_sql_query(req: SQLQueryRequest):
    try:
        conn = get_mysql_connection()
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
          cursor.execute(req.query)
          rows = cursor.fetchall()
          return rows
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore SQL: {e}")
