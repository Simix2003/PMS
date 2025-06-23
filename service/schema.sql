CREATE DATABASE  IF NOT EXISTS `ix_monitor` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `ix_monitor`;
-- MySQL dump 10.13  Distrib 8.0.32, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: ix_monitor
-- ------------------------------------------------------
-- Server version	8.0.32

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `defects`
--

DROP TABLE IF EXISTS `defects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `defects` (
  `id` int NOT NULL AUTO_INCREMENT,
  `category` varchar(50) DEFAULT 'Altro',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=100 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `object_defects`
--

DROP TABLE IF EXISTS `object_defects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `object_defects` (
  `id` int NOT NULL AUTO_INCREMENT,
  `production_id` int NOT NULL,
  `defect_id` int NOT NULL,
  `defect_type` varchar(45) DEFAULT NULL,
  `i_ribbon` int DEFAULT NULL,
  `stringa` int DEFAULT NULL,
  `ribbon_lato` enum('F','M','B') DEFAULT NULL,
  `s_ribbon` int DEFAULT NULL,
  `extra_data` varchar(45) DEFAULT NULL,
  `photo_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `production_id` (`production_id`),
  KEY `defect_id` (`defect_id`),
  KEY `fk_object_photos` (`photo_id`),
  CONSTRAINT `fk_object_photos` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE SET NULL,
  CONSTRAINT `object_defects_ibfk_1` FOREIGN KEY (`production_id`) REFERENCES `productions` (`id`),
  CONSTRAINT `object_defects_ibfk_2` FOREIGN KEY (`defect_id`) REFERENCES `defects` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7876 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `objects`
--

DROP TABLE IF EXISTS `objects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `objects` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_modulo` varchar(50) NOT NULL,
  `creator_station_id` int NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_modulo` (`id_modulo`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  KEY `fk_objects_creator_station` (`creator_station_id`),
  CONSTRAINT `fk_objects_creator_station` FOREIGN KEY (`creator_station_id`) REFERENCES `stations` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=56967 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `photos`
--

DROP TABLE IF EXISTS `photos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `photos` (
  `id` int NOT NULL AUTO_INCREMENT,
  `photo` longblob NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=100 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `production_lines`
--

DROP TABLE IF EXISTS `production_lines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `production_lines` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `display_name` varchar(45) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `productions`
--

DROP TABLE IF EXISTS `productions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `productions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `object_id` int NOT NULL,
  `station_id` int NOT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `esito` int DEFAULT NULL,
  `operator_id` varchar(50) DEFAULT NULL,
  `cycle_time` time GENERATED ALWAYS AS (timediff(`end_time`,`start_time`)) STORED,
  `last_station_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`) /*!80000 INVISIBLE */,
  KEY `object_id` (`object_id`),
  KEY `idx_prod_time` (`start_time`,`end_time`),
  KEY `idx_prod_obj_last` (`object_id`,`last_station_id`),
  KEY `fk_productions_station` (`station_id`),
  CONSTRAINT `fk_productions_station` FOREIGN KEY (`station_id`) REFERENCES `stations` (`id`),
  CONSTRAINT `productions_ibfk_1` FOREIGN KEY (`object_id`) REFERENCES `objects` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=56916 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `station_defects`
--

DROP TABLE IF EXISTS `station_defects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `station_defects` (
  `station_id` int NOT NULL,
  `defect_id` int NOT NULL,
  PRIMARY KEY (`station_id`,`defect_id`),
  KEY `defect_id` (`defect_id`),
  CONSTRAINT `fk_station_defects_station` FOREIGN KEY (`station_id`) REFERENCES `stations` (`id`),
  CONSTRAINT `station_defects_ibfk_2` FOREIGN KEY (`defect_id`) REFERENCES `defects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stations`
--

DROP TABLE IF EXISTS `stations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `line_id` int NOT NULL,
  `name` varchar(50) NOT NULL,
  `display_name` varchar(50) DEFAULT NULL,
  `type` enum('creator','qc','rework','mbj','other') DEFAULT 'other',
  `config` json DEFAULT NULL,
  `plc` json DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `line_id` (`line_id`) /*!80000 INVISIBLE */,
  CONSTRAINT `stations_ibfk_1` FOREIGN KEY (`line_id`) REFERENCES `production_lines` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=93 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stop_status_changes`
--

DROP TABLE IF EXISTS `stop_status_changes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stop_status_changes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `stop_id` int NOT NULL,
  `status` enum('OPEN','SHIFT_MANAGER','HEAD_OF_PRODUCTION','MAINTENANCE_TEAM','CLOSED') NOT NULL,
  `changed_at` datetime NOT NULL,
  `operator_id` varchar(64) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_stop_changed_at` (`stop_id`,`changed_at`),
  KEY `idx_status` (`status`),
  CONSTRAINT `stop_status_changes_ibfk_1` FOREIGN KEY (`stop_id`) REFERENCES `stops` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7036 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stops`
--

DROP TABLE IF EXISTS `stops`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stops` (
  `id` int NOT NULL AUTO_INCREMENT,
  `station_id` int NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime DEFAULT NULL,
  `stop_time` int GENERATED ALWAYS AS (timestampdiff(SECOND,`start_time`,`end_time`)) STORED,
  `operator_id` varchar(64) DEFAULT NULL,
  `type` enum('ESCALATION','STOP','MAINTENANCE','QUALITY') NOT NULL,
  `reason` varchar(256) DEFAULT NULL,
  `status` enum('OPEN','SHIFT_MANAGER','HEAD_OF_PRODUCTION','MAINTENANCE_TEAM','CLOSED') NOT NULL,
  `linked_production_id` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_station_time` (`station_id`,`start_time`),
  KEY `idx_type` (`type`),
  KEY `idx_operator` (`operator_id`),
  KEY `idx_production` (`linked_production_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB AUTO_INCREMENT=7027 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stringatrice_warnings`
--

DROP TABLE IF EXISTS `stringatrice_warnings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stringatrice_warnings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `line_name` varchar(50) DEFAULT NULL,
  `station_name` varchar(50) DEFAULT NULL,
  `station_display` varchar(100) DEFAULT NULL,
  `defect` varchar(100) DEFAULT NULL,
  `type` enum('threshold','consecutive') DEFAULT NULL,
  `value` int DEFAULT NULL,
  `limit_value` int DEFAULT NULL,
  `timestamp` datetime DEFAULT NULL,
  `acknowledged` tinyint(1) DEFAULT '0',
  `source_station` varchar(50) DEFAULT NULL,
  `suppress_on_source` tinyint(1) DEFAULT '0',
  `photo_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_warning_photo` (`photo_id`),
  CONSTRAINT `fk_warning_photo` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=228 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-06-23 20:08:13
