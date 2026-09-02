-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               8.0.30 - MySQL Community Server - GPL
-- Server OS:                    Win64
-- HeidiSQL Version:             12.1.0.6537
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for disc_test
CREATE DATABASE IF NOT EXISTS `disc_test` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `disc_test`;

-- Dumping structure for table disc_test.answers
CREATE TABLE IF NOT EXISTS `answers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `attempt_id` int NOT NULL,
  `question_id` int NOT NULL,
  `most_option_id` int NOT NULL,
  `least_option_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `attempt_id` (`attempt_id`),
  KEY `question_id` (`question_id`),
  KEY `most_option_id` (`most_option_id`),
  KEY `least_option_id` (`least_option_id`),
  CONSTRAINT `answers_ibfk_1` FOREIGN KEY (`attempt_id`) REFERENCES `attempts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `answers_ibfk_2` FOREIGN KEY (`question_id`) REFERENCES `questions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `answers_ibfk_3` FOREIGN KEY (`most_option_id`) REFERENCES `options` (`id`),
  CONSTRAINT `answers_ibfk_4` FOREIGN KEY (`least_option_id`) REFERENCES `options` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Data exporting was unselected.

-- Dumping structure for table disc_test.attempts
CREATE TABLE IF NOT EXISTS `attempts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `started_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `completed_at` datetime DEFAULT NULL,
  `status` enum('in_progress','completed') DEFAULT 'in_progress',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `attempts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Data exporting was unselected.

-- Dumping structure for procedure disc_test.CalculateDiscScores
DELIMITER //
CREATE PROCEDURE `CalculateDiscScores`(IN p_attempt_id INT)
BEGIN
    -- Semua DECLARE wajib berada di paling atas
    DECLARE m_d, m_i, m_s, m_c INT DEFAULT 0;
    DECLARE l_d, l_i, l_s, l_c INT DEFAULT 0;
    DECLARE d_d, d_i, d_s, d_c INT DEFAULT 0;
    DECLARE dom_type VARCHAR(10) DEFAULT 'D';
    DECLARE max_score INT DEFAULT -999;

    -- 1. Hitung total Most (mengabaikan '*')
    SELECT 
        COALESCE(SUM(CASE WHEN o_m.tipe_most = 'D' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN o_m.tipe_most = 'I' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN o_m.tipe_most = 'S' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN o_m.tipe_most = 'C' THEN 1 ELSE 0 END), 0)
    INTO m_d, m_i, m_s, m_c
    FROM answers a
    JOIN options o_m ON a.most_option_id = o_m.id
    WHERE a.attempt_id = p_attempt_id;

    -- 2. Hitung total Least (mengabaikan '*')
    SELECT 
        COALESCE(SUM(CASE WHEN o_l.tipe_least = 'D' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN o_l.tipe_least = 'I' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN o_l.tipe_least = 'S' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN o_l.tipe_least = 'C' THEN 1 ELSE 0 END), 0)
    INTO l_d, l_i, l_s, l_c
    FROM answers a
    JOIN options o_l ON a.least_option_id = o_l.id
    WHERE a.attempt_id = p_attempt_id;

    -- 3. Hitung Selisih (Graph 3: Most - Least)
    SET d_d = m_d - l_d;
    SET d_i = m_i - l_i;
    SET d_s = m_s - l_s;
    SET d_c = m_c - l_c;

    -- 4. Tentukan tipe dominan berdasarkan selisih tertinggi
    SET max_score = d_d;
    SET dom_type = 'D';

    IF d_i > max_score THEN
        SET max_score = d_i;
        SET dom_type = 'I';
    END IF;

    IF d_s > max_score THEN
        SET max_score = d_s;
        SET dom_type = 'S';
    END IF;

    IF d_c > max_score THEN
        SET max_score = d_c;
        SET dom_type = 'C';
    END IF;

    -- 5. Simpan / Perbarui ke tabel results
    INSERT INTO results (
        attempt_id,
        raw_most_d, raw_most_i, raw_most_s, raw_most_c,
        raw_least_d, raw_least_i, raw_least_s, raw_least_c,
        diff_d, diff_i, diff_s, diff_c,
        dominant_type
    ) VALUES (
        p_attempt_id,
        m_d, m_i, m_s, m_c,
        l_d, l_i, l_s, l_c,
        d_d, d_i, d_s, d_c,
        dom_type
    )
    ON DUPLICATE KEY UPDATE
        raw_most_d = VALUES(raw_most_d),
        raw_most_i = VALUES(raw_most_i),
        raw_most_s = VALUES(raw_most_s),
        raw_most_c = VALUES(raw_most_c),
        raw_least_d = VALUES(raw_least_d),
        raw_least_i = VALUES(raw_least_i),
        raw_least_s = VALUES(raw_least_s),
        raw_least_c = VALUES(raw_least_c),
        diff_d = VALUES(diff_d),
        diff_i = VALUES(diff_i),
        diff_s = VALUES(diff_s),
        diff_c = VALUES(diff_c),
        dominant_type = VALUES(dominant_type);

    -- 6. Ubah status attempt menjadi selesai
    UPDATE attempts 
    SET status = 'completed', completed_at = NOW() 
    WHERE id = p_attempt_id;
END//
DELIMITER ;

-- Dumping structure for table disc_test.options
CREATE TABLE IF NOT EXISTS `options` (
  `id` int NOT NULL AUTO_INCREMENT,
  `question_id` int NOT NULL,
  `option_order` int NOT NULL,
  `teks` text NOT NULL,
  `tipe_most` enum('D','I','S','C','*') NOT NULL,
  `tipe_least` enum('D','I','S','C','*') NOT NULL,
  `most_type` enum('D','I','S','C') NOT NULL,
  `least_type` enum('D','I','S','C') NOT NULL,
  PRIMARY KEY (`id`),
  KEY `question_id` (`question_id`),
  CONSTRAINT `options_ibfk_1` FOREIGN KEY (`question_id`) REFERENCES `questions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=97 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Data exporting was unselected.

-- Dumping structure for table disc_test.questions
CREATE TABLE IF NOT EXISTS `questions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nomor` int NOT NULL,
  `pertanyaan` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Data exporting was unselected.

-- Dumping structure for table disc_test.results
CREATE TABLE IF NOT EXISTS `results` (
  `id` int NOT NULL AUTO_INCREMENT,
  `attempt_id` int NOT NULL,
  `score_d` int DEFAULT '0',
  `score_i` int DEFAULT '0',
  `score_s` int DEFAULT '0',
  `score_c` int DEFAULT '0',
  `dominant_type` enum('D','I','S','C') DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `attempt_id` (`attempt_id`),
  CONSTRAINT `results_ibfk_1` FOREIGN KEY (`attempt_id`) REFERENCES `attempts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Data exporting was unselected.

-- Dumping structure for table disc_test.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nama_lengkap` varchar(100) NOT NULL,
  `umur` int DEFAULT NULL,
  `pendidikan_terakhir` varchar(100) DEFAULT NULL,
  `pekerjaan` varchar(100) DEFAULT NULL,
  `jenis_kelamin` enum('Laki-laki','Perempuan') DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Data exporting was unselected.

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
