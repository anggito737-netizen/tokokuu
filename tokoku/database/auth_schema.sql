-- Additive authentication schema for the existing db_tokoku database.
-- Run this once after selecting db_tokoku. Existing business tables are unchanged.

CREATE TABLE IF NOT EXISTS tbl_akun (
    id_akun BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(190) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'cashier', 'customer') NOT NULL,
    id_pelanggan INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_akun),
    UNIQUE KEY uq_tbl_akun_email (email),
    UNIQUE KEY uq_tbl_akun_customer (id_pelanggan),
    CONSTRAINT chk_tbl_akun_customer_role
        CHECK ((role = 'customer' AND id_pelanggan IS NOT NULL) OR (role IN ('admin', 'cashier') AND id_pelanggan IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
