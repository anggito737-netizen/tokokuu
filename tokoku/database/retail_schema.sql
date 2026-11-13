-- Additive retail catalog and order schema for db_tokoku.
-- No sample products or orders are inserted.

ALTER TABLE tbl_akun
    MODIFY role ENUM('admin', 'cashier', 'customer') NOT NULL;

ALTER TABLE tbl_akun DROP CONSTRAINT chk_tbl_akun_customer_role;
ALTER TABLE tbl_akun
    ADD CONSTRAINT chk_tbl_akun_customer_role
    CHECK ((role = 'customer' AND id_pelanggan IS NOT NULL)
        OR (role IN ('admin', 'cashier') AND id_pelanggan IS NULL));

CREATE TABLE IF NOT EXISTS tbl_produk (
    id_produk INT NOT NULL AUTO_INCREMENT,
    nama_produk VARCHAR(150) NOT NULL,
    kategori VARCHAR(80) NOT NULL,
    harga DECIMAL(12,2) NOT NULL,
    stok INT NOT NULL DEFAULT 0,
    gambar_url VARCHAR(500) NULL,
    diskon_persen DECIMAL(5,2) NOT NULL DEFAULT 0,
    diskon_aktif TINYINT(1) NOT NULL DEFAULT 0,
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_produk),
    KEY idx_produk_aktif_kategori (aktif, kategori),
    CONSTRAINT chk_produk_harga CHECK (harga >= 0),
    CONSTRAINT chk_produk_stok CHECK (stok >= 0),
    CONSTRAINT chk_produk_diskon CHECK (diskon_persen >= 0 AND diskon_persen <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tbl_pesanan (
    id_pesanan BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_transaksi INT NOT NULL,
    sumber ENUM('online', 'pos') NOT NULL,
    metode_pembayaran ENUM('cod', 'bank', 'debit', 'ovo', 'dana', 'gopay', 'qris') NOT NULL,
    status ENUM('pending', 'paying', 'processing', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
    id_kasir BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_pesanan),
    UNIQUE KEY uq_pesanan_transaksi (id_transaksi),
    KEY idx_pesanan_status (status, created_at),
    CONSTRAINT fk_pesanan_transaksi FOREIGN KEY (id_transaksi)
        REFERENCES tbl_transaksi (id_transaksi),
    CONSTRAINT fk_pesanan_kasir FOREIGN KEY (id_kasir)
        REFERENCES tbl_akun (id_akun) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tbl_detail_pesanan (
    id_detail BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_pesanan BIGINT UNSIGNED NOT NULL,
    id_produk INT NOT NULL,
    nama_produk VARCHAR(150) NOT NULL,
    jumlah INT NOT NULL,
    harga_satuan DECIMAL(12,2) NOT NULL,
    diskon_persen DECIMAL(5,2) NOT NULL DEFAULT 0,
    diskon_nominal DECIMAL(12,2) NOT NULL DEFAULT 0,
    subtotal DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id_detail),
    KEY idx_detail_pesanan (id_pesanan),
    KEY idx_detail_produk (id_produk),
    CONSTRAINT fk_detail_pesanan FOREIGN KEY (id_pesanan)
        REFERENCES tbl_pesanan (id_pesanan),
    CONSTRAINT fk_detail_produk FOREIGN KEY (id_produk)
        REFERENCES tbl_produk (id_produk),
    CONSTRAINT chk_detail_jumlah CHECK (jumlah > 0),
    CONSTRAINT chk_detail_harga CHECK (harga_satuan >= 0 AND subtotal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
