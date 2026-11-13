-- Additive customer wallet and top-up schema for db_tokoku.
-- Run after auth_schema.sql, retail_schema.sql, and product_variants.sql.

ALTER TABLE tbl_pesanan
    MODIFY metode_pembayaran
    ENUM('cod', 'bank', 'debit', 'ovo', 'dana', 'gopay', 'qris', 'wallet') NOT NULL;

CREATE TABLE IF NOT EXISTS tbl_wallet (
    id_wallet BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_pelanggan INT NOT NULL,
    saldo DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_wallet),
    UNIQUE KEY uq_tbl_wallet_pelanggan (id_pelanggan),
    CONSTRAINT fk_tbl_wallet_pelanggan FOREIGN KEY (id_pelanggan)
        REFERENCES tbl_pelanggan (id_pelanggan) ON DELETE CASCADE,
    CONSTRAINT chk_tbl_wallet_saldo CHECK (saldo >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tbl_wallet_topup (
    id_topup BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_wallet BIGINT UNSIGNED NOT NULL,
    nominal DECIMAL(14,2) NOT NULL,
    metode_pembayaran ENUM('bank', 'qris', 'debit', 'ovo', 'dana', 'gopay') NOT NULL,
    status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
    reviewed_by BIGINT UNSIGNED NULL,
    reviewed_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_topup),
    KEY idx_tbl_wallet_topup_status (status, created_at),
    KEY idx_tbl_wallet_topup_wallet (id_wallet, created_at),
    CONSTRAINT fk_tbl_wallet_topup_wallet FOREIGN KEY (id_wallet)
        REFERENCES tbl_wallet (id_wallet),
    CONSTRAINT fk_tbl_wallet_topup_reviewer FOREIGN KEY (reviewed_by)
        REFERENCES tbl_akun (id_akun) ON DELETE SET NULL,
    CONSTRAINT chk_tbl_wallet_topup_nominal CHECK (nominal >= 10000 AND nominal <= 10000000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tbl_wallet_ledger (
    id_mutasi BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_wallet BIGINT UNSIGNED NOT NULL,
    jenis ENUM('topup', 'purchase', 'refund') NOT NULL,
    id_referensi BIGINT UNSIGNED NOT NULL,
    debit DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    kredit DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    saldo_setelah DECIMAL(14,2) NOT NULL,
    keterangan VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_mutasi),
    UNIQUE KEY uq_tbl_wallet_ledger_reference (jenis, id_referensi),
    KEY idx_tbl_wallet_ledger_wallet (id_wallet, created_at),
    CONSTRAINT fk_tbl_wallet_ledger_wallet FOREIGN KEY (id_wallet)
        REFERENCES tbl_wallet (id_wallet),
    CONSTRAINT chk_tbl_wallet_ledger_amount
        CHECK ((debit > 0 AND kredit = 0) OR (debit = 0 AND kredit > 0)),
    CONSTRAINT chk_tbl_wallet_ledger_balance CHECK (saldo_setelah >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO tbl_wallet (id_pelanggan, saldo)
SELECT id_pelanggan, 0.00
FROM tbl_pelanggan;
