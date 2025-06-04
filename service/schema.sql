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
  plc JSON NULL DEFAULT NULL,
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