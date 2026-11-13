-- Run once after retail_schema.sql to group existing catalog rows into master products.
-- tbl_produk remains the stock-bearing variant table so order detail foreign keys stay valid.

CREATE TABLE tbl_produk_master (
    id_produk_master INT NOT NULL AUTO_INCREMENT,
    nama_produk VARCHAR(150) NOT NULL,
    kategori VARCHAR(80) NOT NULL,
    harga DECIMAL(12,2) NOT NULL,
    gambar_url VARCHAR(500) NULL,
    diskon_persen DECIMAL(5,2) NOT NULL DEFAULT 0,
    diskon_aktif TINYINT(1) NOT NULL DEFAULT 0,
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_produk_master),
    KEY idx_produk_master_aktif_kategori (aktif, kategori),
    CONSTRAINT chk_produk_master_harga CHECK (harga >= 0),
    CONSTRAINT chk_produk_master_diskon CHECK (diskon_persen >= 0 AND diskon_persen <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE tbl_produk
    ADD COLUMN id_produk_master INT NULL AFTER id_produk,
    ADD COLUMN ukuran VARCHAR(30) NULL AFTER stok,
    ADD KEY idx_produk_master_variant (id_produk_master, ukuran),
    ADD CONSTRAINT fk_produk_variant_master FOREIGN KEY (id_produk_master)
        REFERENCES tbl_produk_master (id_produk_master);

INSERT INTO tbl_produk_master
    (nama_produk, kategori, harga, gambar_url, diskon_persen, diskon_aktif, aktif)
SELECT
    CASE
        WHEN kategori = 'Sepatu Nike' AND LOCATE(' - Ukuran ', nama_produk) > 0
        THEN LEFT(nama_produk, LOCATE(' - Ukuran ', nama_produk) - 1)
        ELSE nama_produk
    END,
    kategori,
    MAX(harga),
    MAX(gambar_url),
    MAX(diskon_persen),
    MAX(diskon_aktif),
    MAX(aktif)
FROM tbl_produk
GROUP BY kategori,
    CASE
        WHEN kategori = 'Sepatu Nike' AND LOCATE(' - Ukuran ', nama_produk) > 0
        THEN LEFT(nama_produk, LOCATE(' - Ukuran ', nama_produk) - 1)
        ELSE nama_produk
    END;

UPDATE tbl_produk AS variant
JOIN tbl_produk_master AS master
  ON master.kategori = variant.kategori
 AND master.nama_produk = CASE
    WHEN variant.kategori = 'Sepatu Nike' AND LOCATE(' - Ukuran ', variant.nama_produk) > 0
    THEN LEFT(variant.nama_produk, LOCATE(' - Ukuran ', variant.nama_produk) - 1)
    ELSE variant.nama_produk
 END
SET variant.id_produk_master = master.id_produk_master,
    variant.ukuran = CASE
        WHEN variant.kategori = 'Sepatu Nike' AND LOCATE(' - Ukuran ', variant.nama_produk) > 0
        THEN TRIM(SUBSTRING(variant.nama_produk, LOCATE(' - Ukuran ', variant.nama_produk) + 10))
        ELSE NULL
    END;

ALTER TABLE tbl_produk
    MODIFY COLUMN id_produk_master INT NOT NULL;
