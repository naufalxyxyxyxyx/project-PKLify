CREATE TABLE IF NOT EXISTS p2_users (
 id INT AUTO_INCREMENT PRIMARY KEY, nama VARCHAR(100) NOT NULL,
 role ENUM('admin','guru','siswa') NOT NULL, identity VARCHAR(40) NOT NULL UNIQUE,
 password VARCHAR(255) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_placements (
 siswa_id INT PRIMARY KEY, guru_id INT NOT NULL, tempat VARCHAR(150) NOT NULL DEFAULT '',
 latitude DOUBLE NULL, longitude DOUBLE NULL, radius INT NOT NULL DEFAULT 40,
 start_date DATE NOT NULL, end_date DATE NOT NULL, work_days VARCHAR(20) NOT NULL DEFAULT '1,2,3,4,5',
 start_time TIME NOT NULL DEFAULT '08:00:00', end_time TIME NOT NULL DEFAULT '16:00:00',
 holidays TEXT NOT NULL,
 FOREIGN KEY(siswa_id) REFERENCES p2_users(id), FOREIGN KEY(guru_id) REFERENCES p2_users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_sessions (
 token CHAR(64) PRIMARY KEY, user_id INT NOT NULL, expires_at DATETIME NOT NULL,
 FOREIGN KEY(user_id) REFERENCES p2_users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_activities (
 id INT AUTO_INCREMENT PRIMARY KEY, siswa_id INT NOT NULL,
 kind ENUM('jurnal','izin','masuk','pulang','dokumentasi') NOT NULL,
 tanggal DATE NOT NULL, end_date DATE NULL, title VARCHAR(150) NOT NULL,
 body TEXT NOT NULL, learned TEXT NOT NULL, obstacles TEXT NOT NULL,
 status VARCHAR(30) NOT NULL DEFAULT 'menunggu', feedback TEXT NOT NULL,
 latitude DOUBLE NULL, longitude DOUBLE NULL, accuracy DOUBLE NULL, distance DOUBLE NULL,
 file_name VARCHAR(255) NULL, original_name VARCHAR(255) NULL, mime VARCHAR(100) NULL,
 created_at DATETIME NOT NULL, updated_at DATETIME NOT NULL,
 UNIQUE KEY one_attendance(siswa_id, kind, attendance_date),
 attendance_date DATE NULL,
 FOREIGN KEY(siswa_id) REFERENCES p2_users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_grades (
 siswa_id INT PRIMARY KEY, journal_score DECIMAL(5,2) NOT NULL,
 performance_score DECIMAL(5,2) NOT NULL, attendance_score DECIMAL(5,2) NULL,
 final_score DECIMAL(5,2) NULL, note TEXT NOT NULL, published_at DATETIME NULL,
 updated_at DATETIME NOT NULL, FOREIGN KEY(siswa_id) REFERENCES p2_users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_audit (
 id INT AUTO_INCREMENT PRIMARY KEY, actor_id INT NOT NULL, siswa_id INT NULL,
 action VARCHAR(100) NOT NULL, detail TEXT NOT NULL, created_at DATETIME NOT NULL,
 FOREIGN KEY(actor_id) REFERENCES p2_users(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_downloads (
 ticket CHAR(64) PRIMARY KEY, activity_id INT NOT NULL, expires_at DATETIME NOT NULL,
 FOREIGN KEY(activity_id) REFERENCES p2_activities(id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS p2_location_requests (
 id INT AUTO_INCREMENT PRIMARY KEY, siswa_id INT NOT NULL, actor_id INT NOT NULL,
 tempat VARCHAR(150) NOT NULL, alamat VARCHAR(500) NOT NULL,
 latitude DOUBLE NOT NULL, longitude DOUBLE NOT NULL,
 reason TEXT NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'menunggu',
 feedback TEXT NOT NULL, reviewed_by INT NULL, created_at DATETIME NOT NULL,
 reviewed_at DATETIME NULL, base_version INT NOT NULL DEFAULT 0,
 INDEX location_history(siswa_id,id),
 FOREIGN KEY(siswa_id) REFERENCES p2_users(id),
 FOREIGN KEY(actor_id) REFERENCES p2_users(id),
 FOREIGN KEY(reviewed_by) REFERENCES p2_users(id)
) ENGINE=InnoDB;
