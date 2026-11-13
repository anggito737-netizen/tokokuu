-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Waktu pembuatan: 13 Nov 2026 pada 04.21
-- Versi server: 10.4.32-MariaDB
-- Versi PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db_tokoku`
--

DELIMITER $$
--
-- Prosedur
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `CariPelanggan` (IN `p_id` INT)   BEGIN
    SELECT * 
    FROM tbl_pelanggan 
    WHERE id_pelanggan = p_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `HitungPelanggan` (OUT `jumlah` INT)   BEGIN
    SELECT COUNT(*) 
    INTO jumlah 
    FROM tbl_pelanggan;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `LaporanTransaksi` (IN `p_id_pelanggan` INT)   BEGIN
    SELECT 
        t.id_transaksi,
        t.tanggal,
        p.nama_pelanggan,
        p.kota,
        t.total_belanja
    FROM tbl_transaksi t
    JOIN tbl_pelanggan p ON t.id_pelanggan = p.id_pelanggan
    WHERE t.id_pelanggan = p_id_pelanggan;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `TambahPelanggan` (IN `p_nama` VARCHAR(100), IN `p_kota` VARCHAR(50))   BEGIN
    INSERT INTO tbl_pelanggan (nama_pelanggan, kota)
    VALUES (p_nama, p_kota);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `TampilPelanggan` ()   BEGIN
    SELECT * FROM tbl_pelanggan;
END$$

--
-- Fungsi
--
CREATE DEFINER=`root`@`localhost` FUNCTION `HitungDiskon` (`harga` DECIMAL(12,2), `diskon` DECIMAL(5,2)) RETURNS DECIMAL(12,2) DETERMINISTIC NO SQL BEGIN
    RETURN harga * (diskon / 100);
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `HitungPajak` (`harga` DECIMAL(12,2)) RETURNS DECIMAL(12,2) DETERMINISTIC NO SQL BEGIN
    RETURN harga * 0.11;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `HitungTotal` (`harga` DECIMAL(12,2), `jumlah` INT) RETURNS DECIMAL(12,2) DETERMINISTIC NO SQL BEGIN
    RETURN harga * jumlah;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `KategoriBelanja` (`total` DECIMAL(12,2)) RETURNS VARCHAR(30) CHARSET utf8mb4 COLLATE utf8mb4_general_ci DETERMINISTIC NO SQL BEGIN
    RETURN CASE
        WHEN total >= 1000000 THEN 'Pelanggan Gold'
        WHEN total >= 500000 THEN 'Pelanggan Silver'
        ELSE 'Pelanggan Reguler'
    END;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `KonversiNilai` (`nilai` INT) RETURNS VARCHAR(5) CHARSET utf8mb4 COLLATE utf8mb4_general_ci DETERMINISTIC NO SQL BEGIN
    RETURN CASE
        WHEN nilai >= 85 THEN 'A'
        WHEN nilai >= 75 THEN 'B'
        WHEN nilai >= 65 THEN 'C'
        WHEN nilai >= 50 THEN 'D'
        ELSE 'E'
    END;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `log_pelanggan`
--

CREATE TABLE `log_pelanggan` (
  `id_log` int(11) NOT NULL,
  `aktivitas` varchar(50) DEFAULT NULL,
  `id_pelanggan` int(11) DEFAULT NULL,
  `waktu` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `log_pelanggan`
--

INSERT INTO `log_pelanggan` (`id_log`, `aktivitas`, `id_pelanggan`, `waktu`) VALUES
(1, 'INSERT PELANGGAN BARU', 25, '2026-11-09 06:20:00'),
(3, 'INSERT PELANGGAN BARU', 27, '2026-11-11 02:17:40'),
(6, 'INSERT PELANGGAN BARU', 30, '2026-11-13 02:48:28');

-- --------------------------------------------------------

--
-- Struktur dari tabel `log_perubahan_pelanggan`
--

CREATE TABLE `log_perubahan_pelanggan` (
  `id_log` int(11) NOT NULL,
  `id_pelanggan` int(11) DEFAULT NULL,
  `nama_lama` varchar(100) DEFAULT NULL,
  `nama_baru` varchar(100) DEFAULT NULL,
  `waktu` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `log_perubahan_pelanggan`
--

INSERT INTO `log_perubahan_pelanggan` (`id_log`, `id_pelanggan`, `nama_lama`, `nama_baru`, `waktu`) VALUES
(1, 25, 'Rina', 'Rina Wijaya', '2026-11-09 06:20:38');

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_akun`
--

CREATE TABLE `tbl_akun` (
  `id_akun` bigint(20) UNSIGNED NOT NULL,
  `email` varchar(190) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('admin','cashier','customer') NOT NULL,
  `id_pelanggan` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

--
-- Dumping data untuk tabel `tbl_akun`
--

INSERT INTO `tbl_akun` (`id_akun`, `email`, `password_hash`, `role`, `id_pelanggan`, `created_at`) VALUES
(1, 'demo@tokoku.local', '$2y$10$OK4sYLGzR4s8JY5hL8Q0TODYuR/8dnD2O1/PVTKkQxLW8QYxpFE.e', 'admin', NULL, '2026-11-11 00:39:35'),
(5, 'anggitobimbim@gmail.com', '$2y$10$xY022w6f0ZfT1qL9N3mM..xhaSTUjaQ5kcIzoJzE.mr4loDpK6.ZG', 'customer', 27, '2026-11-11 02:17:40'),
(6, 'kasir@tokoku.local', '$2y$10$PP4MAtMFbR9hXevIEx73few2vEIVUujVtH4YK/RvVz9jgDlSFwyfK', 'cashier', NULL, '2026-11-11 03:25:04'),
(9, 'anggito737@gmail.com', '$2y$10$rTF4ZZZrkqyIo7fWgSMbAuGL3yBVTtMErkRkLbw3H./LEx4bi.qnq', 'customer', 30, '2026-11-13 02:48:29');

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_detail_pesanan`
--

CREATE TABLE `tbl_detail_pesanan` (
  `id_detail` bigint(20) UNSIGNED NOT NULL,
  `id_pesanan` bigint(20) UNSIGNED NOT NULL,
  `id_produk` int(11) NOT NULL,
  `nama_produk` varchar(150) NOT NULL,
  `jumlah` int(11) NOT NULL,
  `harga_satuan` decimal(12,2) NOT NULL,
  `diskon_persen` decimal(5,2) NOT NULL DEFAULT 0.00,
  `diskon_nominal` decimal(12,2) NOT NULL DEFAULT 0.00,
  `subtotal` decimal(12,2) NOT NULL
) ;

--
-- Dumping data untuk tabel `tbl_detail_pesanan`
--

INSERT INTO `tbl_detail_pesanan` (`id_detail`, `id_pesanan`, `id_produk`, `nama_produk`, `jumlah`, `harga_satuan`, `diskon_persen`, `diskon_nominal`, `subtotal`) VALUES
(1, 1, 2, 'Beras premium 5 kg', 1, 78000.00, 0.00, 0.00, 78000.00),
(2, 1, 4, 'Gula pasir 1 kg', 1, 17500.00, 0.00, 0.00, 17500.00),
(3, 1, 18, 'Biskuit cokelat', 1, 10000.00, 0.00, 0.00, 10000.00),
(4, 2, 2, 'Beras premium 5 kg', 1, 78000.00, 0.00, 0.00, 78000.00),
(5, 2, 4, 'Gula pasir 1 kg', 1, 17500.00, 0.00, 0.00, 17500.00),
(6, 2, 7, 'Buku tulis 38 lembar', 1, 4000.00, 0.00, 0.00, 4000.00),
(7, 2, 8, 'Pulpen tinta hitam', 1, 3500.00, 0.00, 0.00, 3500.00),
(8, 2, 13, 'Deterjen bubuk 1 kg', 1, 24500.00, 0.00, 0.00, 24500.00),
(9, 2, 15, 'Alat pel lantai', 1, 28000.00, 0.00, 0.00, 28000.00),
(10, 2, 18, 'Biskuit cokelat', 1, 10000.00, 0.00, 0.00, 10000.00),
(11, 2, 21, 'Kacang atom', 1, 9500.00, 0.00, 0.00, 9500.00),
(12, 3, 22, 'Nike Air Force 1 \'07 Black - Ukuran 36', 1, 1629000.00, 0.00, 0.00, 1629000.00),
(13, 4, 22, 'Nike Air Force 1 \'07 Black · 36', 2, 1629000.00, 0.00, 0.00, 3258000.00),
(14, 4, 40, 'nike p-6000 · 40', 1, 1563900.00, 0.00, 0.00, 1563900.00),
(15, 4, 44, 'nike shox tl mens · 44', 1, 1569600.00, 0.00, 0.00, 1569600.00),
(16, 5, 31, 'Nike Air Force 1 \'07 Black · 45', 2, 1629000.00, 0.00, 0.00, 3258000.00),
(17, 5, 42, 'nike p-6000 · 42', 1, 1563900.00, 0.00, 0.00, 1563900.00),
(18, 5, 44, 'nike shox tl mens · 44', 1, 1569600.00, 0.00, 0.00, 1569600.00),
(19, 5, 45, 'Walking shoes · 43', 2, 1000000.00, 0.00, 0.00, 2000000.00),
(20, 5, 50, 'nike vomero premium · 37', 1, 1000000.00, 0.00, 0.00, 1000000.00),
(21, 6, 22, 'Nike Air Force 1 \'07 Black · 36', 1, 1629000.00, 0.00, 0.00, 1629000.00),
(22, 6, 40, 'nike p-6000 · 40', 1, 1563900.00, 0.00, 0.00, 1563900.00),
(23, 6, 44, 'nike shox tl mens · 44', 1, 1569600.00, 0.00, 0.00, 1569600.00),
(24, 6, 45, 'Walking shoes · 43', 1, 1000000.00, 0.00, 0.00, 1000000.00),
(25, 6, 50, 'nike vomero premium · 37', 1, 1000000.00, 0.00, 0.00, 1000000.00),
(26, 7, 22, 'Nike Air Force 1 \'07 Black · 36', 1, 1629000.00, 0.00, 0.00, 1629000.00),
(27, 7, 40, 'nike p-6000 · 40', 1, 1563900.00, 0.00, 0.00, 1563900.00),
(28, 7, 44, 'nike shox tl mens · 44', 1, 1569600.00, 0.00, 0.00, 1569600.00),
(29, 7, 45, 'Walking shoes · 43', 1, 1000000.00, 0.00, 0.00, 1000000.00),
(30, 7, 50, 'nike vomero premium · 37', 1, 1000000.00, 0.00, 0.00, 1000000.00);

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_pelanggan`
--

CREATE TABLE `tbl_pelanggan` (
  `id_pelanggan` int(11) NOT NULL,
  `nama_pelanggan` varchar(100) DEFAULT NULL,
  `kota` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `tbl_pelanggan`
--

INSERT INTO `tbl_pelanggan` (`id_pelanggan`, `nama_pelanggan`, `kota`) VALUES
(1, 'Andi', 'Ponorogo'),
(2, 'Budi', 'Madiun'),
(3, 'Citra', 'Surabaya'),
(4, 'Andi', 'Ponorogo'),
(5, 'Budi', 'Madiun'),
(6, 'Citra', 'Surabaya'),
(7, 'Dewi', 'Ponorogo'),
(8, 'Eko', 'Jakarta'),
(9, 'Fajar', 'Malang'),
(10, 'Gita', 'Yogyakarta'),
(11, 'Hadi', 'Solo'),
(12, 'Indah', 'Bandung'),
(13, 'Joko', 'Semarang'),
(14, 'Dewi', 'Ponorogo'),
(15, 'Andi', 'Ponorogo'),
(16, 'Budi', 'Madiun'),
(17, 'Citra', 'Surabaya'),
(18, 'Dewi', 'Ponorogo'),
(19, 'Eko', 'Jakarta'),
(20, 'Fajar', 'Malang'),
(21, 'Gita', 'Yogyakarta'),
(22, 'Hadi', 'Solo'),
(23, 'Indah', 'Bandung'),
(24, 'Joko', 'Semarang'),
(25, 'Rina Wijaya', 'Ponorogo'),
(27, 'anggito bimbim', 'poonorogo'),
(30, '05. Anggito Abimanyu', 'KABUPATEN PONOROGO');

--
-- Trigger `tbl_pelanggan`
--
DELIMITER $$
CREATE TRIGGER `after_insert_pelanggan` AFTER INSERT ON `tbl_pelanggan` FOR EACH ROW BEGIN
    INSERT INTO log_pelanggan (aktivitas, id_pelanggan)
    VALUES ('INSERT PELANGGAN BARU', NEW.id_pelanggan);
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `after_update_pelanggan` AFTER UPDATE ON `tbl_pelanggan` FOR EACH ROW BEGIN
    INSERT INTO log_perubahan_pelanggan (id_pelanggan, nama_lama, nama_baru)
    VALUES (OLD.id_pelanggan, OLD.nama_pelanggan, NEW.nama_pelanggan);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_pesanan`
--

CREATE TABLE `tbl_pesanan` (
  `id_pesanan` bigint(20) UNSIGNED NOT NULL,
  `id_transaksi` int(11) NOT NULL,
  `sumber` enum('online','pos') NOT NULL,
  `metode_pembayaran` enum('cod','bank','debit','ovo','dana','gopay','qris','wallet') NOT NULL,
  `status` enum('pending','paying','processing','completed','cancelled') NOT NULL DEFAULT 'pending',
  `id_kasir` bigint(20) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data untuk tabel `tbl_pesanan`
--

INSERT INTO `tbl_pesanan` (`id_pesanan`, `id_transaksi`, `sumber`, `metode_pembayaran`, `status`, `id_kasir`, `created_at`, `updated_at`) VALUES
(1, 47, 'online', 'cod', 'completed', NULL, '2026-11-11 02:18:36', '2026-11-13 02:40:41'),
(2, 48, 'pos', 'cod', 'completed', 6, '2026-11-11 03:29:04', '2026-11-11 03:29:04'),
(3, 49, 'pos', 'cod', 'completed', 6, '2026-11-11 03:40:40', '2026-11-11 03:40:40'),
(4, 50, 'pos', 'cod', 'completed', 1, '2026-11-13 02:40:06', '2026-11-13 02:40:06'),
(5, 51, 'pos', 'cod', 'completed', 1, '2026-11-13 02:44:47', '2026-11-13 02:44:47'),
(6, 52, 'pos', 'cod', 'completed', 6, '2026-11-13 02:47:50', '2026-11-13 02:47:50'),
(7, 53, 'online', 'dana', 'pending', NULL, '2026-11-13 02:50:50', '2026-11-13 02:50:50');

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_produk`
--

CREATE TABLE `tbl_produk` (
  `id_produk` int(11) NOT NULL,
  `id_produk_master` int(11) NOT NULL,
  `nama_produk` varchar(150) NOT NULL,
  `kategori` varchar(80) NOT NULL,
  `harga` decimal(12,2) NOT NULL,
  `stok` int(11) NOT NULL DEFAULT 0,
  `ukuran` varchar(30) DEFAULT NULL,
  `gambar_url` varchar(500) DEFAULT NULL,
  `diskon_persen` decimal(5,2) NOT NULL DEFAULT 0.00,
  `diskon_aktif` tinyint(1) NOT NULL DEFAULT 0,
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data untuk tabel `tbl_produk`
--

INSERT INTO `tbl_produk` (`id_produk`, `id_produk_master`, `nama_produk`, `kategori`, `harga`, `stok`, `ukuran`, `gambar_url`, `diskon_persen`, `diskon_aktif`, `aktif`, `created_at`, `updated_at`) VALUES
(2, 7, 'Beras premium 5 kg', 'Sembako', 78000.00, 8, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(4, 8, 'Gula pasir 1 kg', 'Sembako', 17500.00, 8, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(7, 1, 'Buku tulis 38 lembar', 'Alat Tulis', 4000.00, 9, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(8, 2, 'Pulpen tinta hitam', 'Alat Tulis', 3500.00, 9, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(13, 6, 'Deterjen bubuk 1 kg', 'Peralatan Rumah Tangga', 24500.00, 9, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(15, 5, 'Alat pel lantai', 'Peralatan Rumah Tangga', 28000.00, 9, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(18, 3, 'Biskuit cokelat', 'Makanan Ringan', 10000.00, 8, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(21, 4, 'Kacang atom', 'Makanan Ringan', 9500.00, 9, NULL, NULL, 0.00, 0, 0, '2026-11-11 02:15:28', '2026-11-11 04:15:28'),
(22, 9, 'Nike Air Force 1 \'07 Black - Ukuran 36', 'Sepatu Nike', 1629000.00, 5, '36', 'https://atmos.co.id/cdn/shop/files/atmosnew-2025-10-09T003829.889_1360x.png?v=1759945180', 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-13 02:50:50'),
(23, 9, 'Nike Air Force 1 \'07 Black - Ukuran 37', 'Sepatu Nike', 1629000.00, 10, '37', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(24, 9, 'Nike Air Force 1 \'07 Black - Ukuran 38', 'Sepatu Nike', 1629000.00, 10, '38', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(25, 9, 'Nike Air Force 1 \'07 Black - Ukuran 39', 'Sepatu Nike', 1629000.00, 10, '39', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(26, 9, 'Nike Air Force 1 \'07 Black - Ukuran 40', 'Sepatu Nike', 1629000.00, 10, '40', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(27, 9, 'Nike Air Force 1 \'07 Black - Ukuran 41', 'Sepatu Nike', 1629000.00, 10, '41', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(28, 9, 'Nike Air Force 1 \'07 Black - Ukuran 42', 'Sepatu Nike', 1629000.00, 10, '42', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(29, 9, 'Nike Air Force 1 \'07 Black - Ukuran 43', 'Sepatu Nike', 1629000.00, 10, '43', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(30, 9, 'Nike Air Force 1 \'07 Black - Ukuran 44', 'Sepatu Nike', 1629000.00, 10, '44', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(31, 9, 'Nike Air Force 1 \'07 Black - Ukuran 45', 'Sepatu Nike', 1629000.00, 8, '45', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-13 02:44:47'),
(32, 9, 'Nike Air Force 1 \'07 Black - Ukuran 46', 'Sepatu Nike', 1629000.00, 10, '46', NULL, 0.00, 0, 1, '2026-11-11 03:37:41', '2026-11-11 04:15:28'),
(40, 18, 'nike p-6000 - 40', 'sepatu nike', 1563900.00, 7, '40', 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/48825cbe-e440-44a8-8988-1eb0ccb952ca/NIKE+P-6000.png', 0.00, 0, 1, '2026-11-13 02:27:57', '2026-11-13 02:50:50'),
(41, 18, 'nike p-6000 - 41', 'sepatu nike', 1563900.00, 10, '41', 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/48825cbe-e440-44a8-8988-1eb0ccb952ca/NIKE+P-6000.png', 0.00, 0, 1, '2026-11-13 02:27:57', '2026-11-13 02:28:26'),
(42, 18, 'nike p-6000 - 42', 'sepatu nike', 1563900.00, 9, '42', 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/48825cbe-e440-44a8-8988-1eb0ccb952ca/NIKE+P-6000.png', 0.00, 0, 1, '2026-11-13 02:27:57', '2026-11-13 02:44:47'),
(43, 18, 'nike p-6000 - 43', 'sepatu nike', 1563900.00, 10, '43', 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/48825cbe-e440-44a8-8988-1eb0ccb952ca/NIKE+P-6000.png', 0.00, 0, 1, '2026-11-13 02:27:57', '2026-11-13 02:28:26'),
(44, 19, 'nike shox tl mens - 44', 'sepatu nike', 1569600.00, 6, '44', 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/7da3faa8-b5d0-43a1-a70a-e6409d6b6999/NIKE+SHOX+TL.png', 0.00, 0, 1, '2026-11-13 02:31:04', '2026-11-13 02:50:50'),
(45, 20, 'Walking shoes - 43', 'sepatu nike', 1000000.00, 6, '43', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSTojyuzP5nqLNVmqhoS0C6pa-lgcFme3JWZv0zls3Jgg&s=10', 0.00, 0, 1, '2026-11-13 02:34:08', '2026-11-13 02:50:50'),
(46, 20, 'Walking shoes - 44', 'sepatu nike', 1000000.00, 10, '44', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSTojyuzP5nqLNVmqhoS0C6pa-lgcFme3JWZv0zls3Jgg&s=10', 0.00, 0, 1, '2026-11-13 02:34:08', '2026-11-13 02:34:28'),
(47, 21, 'nike vomero premium - 41', 'sepatu nike', 1000000.00, 10, '41', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRh7ongzh_fKv2NaSSYBdoY-5C404Q8K2qz7CgKXm7HwA&s=10', 0.00, 0, 1, '2026-11-13 02:38:55', '2026-11-13 02:39:27'),
(48, 21, 'nike vomero premium - 44', 'sepatu nike', 1000000.00, 10, '44', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRh7ongzh_fKv2NaSSYBdoY-5C404Q8K2qz7CgKXm7HwA&s=10', 0.00, 0, 1, '2026-11-13 02:38:55', '2026-11-13 02:39:27'),
(49, 21, 'nike vomero premium - 42', 'sepatu nike', 1000000.00, 10, '42', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRh7ongzh_fKv2NaSSYBdoY-5C404Q8K2qz7CgKXm7HwA&s=10', 0.00, 0, 1, '2026-11-13 02:38:55', '2026-11-13 02:39:27'),
(50, 21, 'nike vomero premium - 37', 'sepatu nike', 1000000.00, 7, '37', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRh7ongzh_fKv2NaSSYBdoY-5C404Q8K2qz7CgKXm7HwA&s=10', 0.00, 0, 1, '2026-11-13 02:38:55', '2026-11-13 02:50:50'),
(51, 21, 'nike vomero premium - 38', 'sepatu nike', 1000000.00, 10, '38', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRh7ongzh_fKv2NaSSYBdoY-5C404Q8K2qz7CgKXm7HwA&s=10', 0.00, 0, 1, '2026-11-13 02:38:55', '2026-11-13 02:39:27');

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_produk_master`
--

CREATE TABLE `tbl_produk_master` (
  `id_produk_master` int(11) NOT NULL,
  `nama_produk` varchar(150) NOT NULL,
  `kategori` varchar(80) NOT NULL,
  `harga` decimal(12,2) NOT NULL,
  `gambar_url` varchar(500) DEFAULT NULL,
  `diskon_persen` decimal(5,2) NOT NULL DEFAULT 0.00,
  `diskon_aktif` tinyint(1) NOT NULL DEFAULT 0,
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data untuk tabel `tbl_produk_master`
--

INSERT INTO `tbl_produk_master` (`id_produk_master`, `nama_produk`, `kategori`, `harga`, `gambar_url`, `diskon_persen`, `diskon_aktif`, `aktif`, `created_at`, `updated_at`) VALUES
(1, 'Buku tulis 38 lembar', 'Alat Tulis', 4000.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(2, 'Pulpen tinta hitam', 'Alat Tulis', 3500.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(3, 'Biskuit cokelat', 'Makanan Ringan', 10000.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(4, 'Kacang atom', 'Makanan Ringan', 9500.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(5, 'Alat pel lantai', 'Peralatan Rumah Tangga', 28000.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(6, 'Deterjen bubuk 1 kg', 'Peralatan Rumah Tangga', 24500.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(7, 'Beras premium 5 kg', 'Sembako', 78000.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(8, 'Gula pasir 1 kg', 'Sembako', 17500.00, NULL, 0.00, 0, 0, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(9, 'Nike Air Force 1 \'07 Black', 'Sepatu Nike', 1629000.00, 'https://atmos.co.id/cdn/shop/files/atmosnew-2025-10-09T003829.889_1360x.png?v=1759945180', 0.00, 0, 1, '2026-11-11 04:15:28', '2026-11-11 04:15:28'),
(18, 'nike p-6000', 'sepatu nike', 1563900.00, 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/48825cbe-e440-44a8-8988-1eb0ccb952ca/NIKE+P-6000.png', 0.00, 0, 1, '2026-11-13 02:27:57', '2026-11-13 02:28:26'),
(19, 'nike shox tl mens', 'sepatu nike', 1569600.00, 'https://static.nike.com/a/images/t_web_pdp_936_v2/f_auto,u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/7da3faa8-b5d0-43a1-a70a-e6409d6b6999/NIKE+SHOX+TL.png', 0.00, 0, 1, '2026-11-13 02:31:04', '2026-11-13 02:31:04'),
(20, 'Walking shoes', 'sepatu nike', 1000000.00, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSTojyuzP5nqLNVmqhoS0C6pa-lgcFme3JWZv0zls3Jgg&s=10', 0.00, 0, 1, '2026-11-13 02:34:08', '2026-11-13 02:34:28'),
(21, 'nike vomero premium', 'sepatu nike', 1000000.00, 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRh7ongzh_fKv2NaSSYBdoY-5C404Q8K2qz7CgKXm7HwA&s=10', 0.00, 0, 1, '2026-11-13 02:38:55', '2026-11-13 02:39:27');

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_transaksi`
--

CREATE TABLE `tbl_transaksi` (
  `id_transaksi` int(11) NOT NULL,
  `tanggal` date DEFAULT NULL,
  `id_pelanggan` int(11) DEFAULT NULL,
  `total_belanja` decimal(12,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `tbl_transaksi`
--

INSERT INTO `tbl_transaksi` (`id_transaksi`, `tanggal`, `id_pelanggan`, `total_belanja`) VALUES
(1, '2026-10-01', 1, 250000.00),
(2, '2026-10-02', 2, 350000.00),
(3, '2026-10-03', 1, 150000.00),
(4, '2026-10-04', 3, 500000.00),
(5, '2026-10-01', 1, 250000.00),
(6, '2026-10-02', 2, 350000.00),
(7, '2026-10-03', 1, 150000.00),
(8, '2026-10-04', 3, 500000.00),
(9, '2026-10-05', 4, 120000.00),
(10, '2026-10-06', 5, 750000.00),
(11, '2026-10-07', 6, 300000.00),
(12, '2026-10-08', 2, 450000.00),
(13, '2026-10-09', 7, 600000.00),
(14, '2026-10-10', 8, 150000.00),
(15, '2026-10-11', 9, 850000.00),
(16, '2026-10-12', 10, 950000.00),
(17, '2026-10-13', 1, 400000.00),
(18, '2026-10-14', 3, 200000.00),
(19, '2026-10-15', 4, 310000.00),
(20, '2026-10-16', 5, 520000.00),
(21, '2026-10-17', 6, 125000.00),
(22, '2026-10-18', 7, 330000.00),
(23, '2026-10-19', 9, 450000.00),
(24, '2026-10-20', 10, 670000.00),
(25, '2026-10-01', 1, 250000.00),
(26, '2026-10-02', 2, 350000.00),
(27, '2026-10-03', 1, 150000.00),
(28, '2026-10-04', 3, 500000.00),
(29, '2026-10-05', 4, 120000.00),
(30, '2026-10-06', 5, 750000.00),
(31, '2026-10-07', 6, 300000.00),
(32, '2026-10-08', 2, 450000.00),
(33, '2026-10-09', 7, 600000.00),
(34, '2026-10-10', 8, 150000.00),
(35, '2026-10-11', 9, 850000.00),
(36, '2026-10-12', 10, 950000.00),
(37, '2026-10-13', 1, 400000.00),
(38, '2026-10-14', 3, 200000.00),
(39, '2026-10-15', 4, 310000.00),
(40, '2026-10-16', 5, 520000.00),
(41, '2026-10-17', 6, 125000.00),
(42, '2026-10-18', 7, 330000.00),
(43, '2026-10-19', 9, 450000.00),
(44, '2026-10-20', 10, 670000.00),
(45, '2026-11-11', 25, 99900.00),
(46, '2026-11-11', 25, 99900.00),
(47, '2026-11-11', 27, 117105.00),
(48, '2026-11-11', NULL, 194250.00),
(49, '2026-11-11', NULL, 1808190.00),
(50, '2026-11-13', NULL, 7094565.00),
(51, '2026-11-13', NULL, 10424565.00),
(52, '2026-11-13', NULL, 7506375.00),
(53, '2026-11-13', 30, 7506375.00);

--
-- Trigger `tbl_transaksi`
--
DELIMITER $$
CREATE TRIGGER `before_insert_transaksi` BEFORE INSERT ON `tbl_transaksi` FOR EACH ROW BEGIN
    IF NEW.total_belanja < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Gagal: Total belanja tidak boleh bernilai negatif!';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_wallet`
--

CREATE TABLE `tbl_wallet` (
  `id_wallet` bigint(20) UNSIGNED NOT NULL,
  `id_pelanggan` int(11) NOT NULL,
  `saldo` decimal(14,2) NOT NULL DEFAULT 0.00,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Dumping data untuk tabel `tbl_wallet`
--

INSERT INTO `tbl_wallet` (`id_wallet`, `id_pelanggan`, `saldo`, `updated_at`) VALUES
(1, 1, 0.00, '2026-11-13 03:11:04'),
(2, 2, 0.00, '2026-11-13 03:11:04'),
(3, 3, 0.00, '2026-11-13 03:11:04'),
(4, 4, 0.00, '2026-11-13 03:11:04'),
(5, 5, 0.00, '2026-11-13 03:11:04'),
(6, 6, 0.00, '2026-11-13 03:11:04'),
(7, 7, 0.00, '2026-11-13 03:11:04'),
(8, 8, 0.00, '2026-11-13 03:11:04'),
(9, 9, 0.00, '2026-11-13 03:11:04'),
(10, 10, 0.00, '2026-11-13 03:11:04'),
(11, 11, 0.00, '2026-11-13 03:11:04'),
(12, 12, 0.00, '2026-11-13 03:11:04'),
(13, 13, 0.00, '2026-11-13 03:11:04'),
(14, 14, 0.00, '2026-11-13 03:11:04'),
(15, 15, 0.00, '2026-11-13 03:11:04'),
(16, 16, 0.00, '2026-11-13 03:11:04'),
(17, 17, 0.00, '2026-11-13 03:11:04'),
(18, 18, 0.00, '2026-11-13 03:11:04'),
(19, 19, 0.00, '2026-11-13 03:11:04'),
(20, 20, 0.00, '2026-11-13 03:11:04'),
(21, 21, 0.00, '2026-11-13 03:11:04'),
(22, 22, 0.00, '2026-11-13 03:11:04'),
(23, 23, 0.00, '2026-11-13 03:11:04'),
(24, 24, 0.00, '2026-11-13 03:11:04'),
(25, 25, 0.00, '2026-11-13 03:11:04'),
(26, 27, 0.00, '2026-11-13 03:11:04'),
(27, 30, 0.00, '2026-11-13 03:11:04');

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_wallet_ledger`
--

CREATE TABLE `tbl_wallet_ledger` (
  `id_mutasi` bigint(20) UNSIGNED NOT NULL,
  `id_wallet` bigint(20) UNSIGNED NOT NULL,
  `jenis` enum('topup','purchase','refund') NOT NULL,
  `id_referensi` bigint(20) UNSIGNED NOT NULL,
  `debit` decimal(14,2) NOT NULL DEFAULT 0.00,
  `kredit` decimal(14,2) NOT NULL DEFAULT 0.00,
  `saldo_setelah` decimal(14,2) NOT NULL,
  `keterangan` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `tbl_wallet_topup`
--

CREATE TABLE `tbl_wallet_topup` (
  `id_topup` bigint(20) UNSIGNED NOT NULL,
  `id_wallet` bigint(20) UNSIGNED NOT NULL,
  `nominal` decimal(14,2) NOT NULL,
  `metode_pembayaran` enum('bank','qris','debit','ovo','dana','gopay') NOT NULL,
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `reviewed_by` bigint(20) UNSIGNED DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ;

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_laporan_transaksi`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_laporan_transaksi` (
`id_transaksi` int(11)
,`tanggal` date
,`nama_pelanggan` varchar(100)
,`kota` varchar(50)
,`total_belanja` decimal(12,2)
);

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_pelanggan`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_pelanggan` (
`id_pelanggan` int(11)
,`nama_pelanggan` varchar(100)
,`kota` varchar(50)
);

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_total_belanja`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_total_belanja` (
`id_pelanggan` int(11)
,`nama_pelanggan` varchar(100)
,`total_transaksi` bigint(21)
,`total_belanja` decimal(34,2)
);

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_total_belanja_pelanggan`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_total_belanja_pelanggan` (
`id_pelanggan` int(11)
,`nama_pelanggan` varchar(100)
,`jumlah_transaksi` bigint(21)
,`total_keseluruhan_belanja` decimal(34,2)
);

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_transaksi_pelanggan`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_transaksi_pelanggan` (
`id_transaksi` int(11)
,`tanggal` date
,`nama_pelanggan` varchar(100)
,`kota` varchar(50)
,`total_belanja` decimal(12,2)
);

-- --------------------------------------------------------

--
-- Struktur untuk view `view_laporan_transaksi`
--
DROP TABLE IF EXISTS `view_laporan_transaksi`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_laporan_transaksi`  AS SELECT `t`.`id_transaksi` AS `id_transaksi`, `t`.`tanggal` AS `tanggal`, `p`.`nama_pelanggan` AS `nama_pelanggan`, `p`.`kota` AS `kota`, `t`.`total_belanja` AS `total_belanja` FROM (`tbl_transaksi` `t` join `tbl_pelanggan` `p` on(`t`.`id_pelanggan` = `p`.`id_pelanggan`)) ;

-- --------------------------------------------------------

--
-- Struktur untuk view `view_pelanggan`
--
DROP TABLE IF EXISTS `view_pelanggan`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_pelanggan`  AS SELECT `tbl_pelanggan`.`id_pelanggan` AS `id_pelanggan`, `tbl_pelanggan`.`nama_pelanggan` AS `nama_pelanggan`, `tbl_pelanggan`.`kota` AS `kota` FROM `tbl_pelanggan` ;

-- --------------------------------------------------------

--
-- Struktur untuk view `view_total_belanja`
--
DROP TABLE IF EXISTS `view_total_belanja`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_total_belanja`  AS SELECT `p`.`id_pelanggan` AS `id_pelanggan`, `p`.`nama_pelanggan` AS `nama_pelanggan`, count(`t`.`id_transaksi`) AS `total_transaksi`, coalesce(sum(`t`.`total_belanja`),0) AS `total_belanja` FROM (`tbl_pelanggan` `p` left join `tbl_transaksi` `t` on(`p`.`id_pelanggan` = `t`.`id_pelanggan`)) GROUP BY `p`.`id_pelanggan`, `p`.`nama_pelanggan` ;

-- --------------------------------------------------------

--
-- Struktur untuk view `view_total_belanja_pelanggan`
--
DROP TABLE IF EXISTS `view_total_belanja_pelanggan`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_total_belanja_pelanggan`  AS SELECT `p`.`id_pelanggan` AS `id_pelanggan`, `p`.`nama_pelanggan` AS `nama_pelanggan`, count(`t`.`id_transaksi`) AS `jumlah_transaksi`, coalesce(sum(`t`.`total_belanja`),0) AS `total_keseluruhan_belanja` FROM (`tbl_pelanggan` `p` left join `tbl_transaksi` `t` on(`p`.`id_pelanggan` = `t`.`id_pelanggan`)) GROUP BY `p`.`id_pelanggan`, `p`.`nama_pelanggan` ;

-- --------------------------------------------------------

--
-- Struktur untuk view `view_transaksi_pelanggan`
--
DROP TABLE IF EXISTS `view_transaksi_pelanggan`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_transaksi_pelanggan`  AS SELECT `t`.`id_transaksi` AS `id_transaksi`, `t`.`tanggal` AS `tanggal`, `p`.`nama_pelanggan` AS `nama_pelanggan`, `p`.`kota` AS `kota`, `t`.`total_belanja` AS `total_belanja` FROM (`tbl_transaksi` `t` join `tbl_pelanggan` `p` on(`t`.`id_pelanggan` = `p`.`id_pelanggan`)) ;

--
-- Indexes for dumped tables
--

--
-- Indeks untuk tabel `log_pelanggan`
--
ALTER TABLE `log_pelanggan`
  ADD PRIMARY KEY (`id_log`);

--
-- Indeks untuk tabel `log_perubahan_pelanggan`
--
ALTER TABLE `log_perubahan_pelanggan`
  ADD PRIMARY KEY (`id_log`);

--
-- Indeks untuk tabel `tbl_akun`
--
ALTER TABLE `tbl_akun`
  ADD PRIMARY KEY (`id_akun`),
  ADD UNIQUE KEY `uq_tbl_akun_email` (`email`),
  ADD UNIQUE KEY `uq_tbl_akun_customer` (`id_pelanggan`);

--
-- Indeks untuk tabel `tbl_detail_pesanan`
--
ALTER TABLE `tbl_detail_pesanan`
  ADD PRIMARY KEY (`id_detail`),
  ADD KEY `idx_detail_pesanan` (`id_pesanan`),
  ADD KEY `idx_detail_produk` (`id_produk`);

--
-- Indeks untuk tabel `tbl_pelanggan`
--
ALTER TABLE `tbl_pelanggan`
  ADD PRIMARY KEY (`id_pelanggan`);

--
-- Indeks untuk tabel `tbl_pesanan`
--
ALTER TABLE `tbl_pesanan`
  ADD PRIMARY KEY (`id_pesanan`),
  ADD UNIQUE KEY `uq_pesanan_transaksi` (`id_transaksi`),
  ADD KEY `idx_pesanan_status` (`status`,`created_at`),
  ADD KEY `fk_pesanan_kasir` (`id_kasir`);

--
-- Indeks untuk tabel `tbl_produk`
--
ALTER TABLE `tbl_produk`
  ADD PRIMARY KEY (`id_produk`),
  ADD KEY `idx_produk_aktif_kategori` (`aktif`,`kategori`),
  ADD KEY `idx_produk_master_variant` (`id_produk_master`,`ukuran`);

--
-- Indeks untuk tabel `tbl_produk_master`
--
ALTER TABLE `tbl_produk_master`
  ADD PRIMARY KEY (`id_produk_master`),
  ADD KEY `idx_produk_master_aktif_kategori` (`aktif`,`kategori`);

--
-- Indeks untuk tabel `tbl_transaksi`
--
ALTER TABLE `tbl_transaksi`
  ADD PRIMARY KEY (`id_transaksi`),
  ADD KEY `id_pelanggan` (`id_pelanggan`);

--
-- Indeks untuk tabel `tbl_wallet`
--
ALTER TABLE `tbl_wallet`
  ADD PRIMARY KEY (`id_wallet`),
  ADD UNIQUE KEY `uq_tbl_wallet_pelanggan` (`id_pelanggan`);

--
-- Indeks untuk tabel `tbl_wallet_ledger`
--
ALTER TABLE `tbl_wallet_ledger`
  ADD PRIMARY KEY (`id_mutasi`),
  ADD UNIQUE KEY `uq_tbl_wallet_ledger_reference` (`jenis`,`id_referensi`),
  ADD KEY `idx_tbl_wallet_ledger_wallet` (`id_wallet`,`created_at`);

--
-- Indeks untuk tabel `tbl_wallet_topup`
--
ALTER TABLE `tbl_wallet_topup`
  ADD PRIMARY KEY (`id_topup`),
  ADD KEY `idx_tbl_wallet_topup_status` (`status`,`created_at`),
  ADD KEY `idx_tbl_wallet_topup_wallet` (`id_wallet`,`created_at`),
  ADD KEY `fk_tbl_wallet_topup_reviewer` (`reviewed_by`);

--
-- AUTO_INCREMENT untuk tabel yang dibuang
--

--
-- AUTO_INCREMENT untuk tabel `log_pelanggan`
--
ALTER TABLE `log_pelanggan`
  MODIFY `id_log` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT untuk tabel `log_perubahan_pelanggan`
--
ALTER TABLE `log_perubahan_pelanggan`
  MODIFY `id_log` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT untuk tabel `tbl_akun`
--
ALTER TABLE `tbl_akun`
  MODIFY `id_akun` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `tbl_detail_pesanan`
--
ALTER TABLE `tbl_detail_pesanan`
  MODIFY `id_detail` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `tbl_pelanggan`
--
ALTER TABLE `tbl_pelanggan`
  MODIFY `id_pelanggan` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT untuk tabel `tbl_pesanan`
--
ALTER TABLE `tbl_pesanan`
  MODIFY `id_pesanan` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT untuk tabel `tbl_produk`
--
ALTER TABLE `tbl_produk`
  MODIFY `id_produk` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `tbl_produk_master`
--
ALTER TABLE `tbl_produk_master`
  MODIFY `id_produk_master` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `tbl_transaksi`
--
ALTER TABLE `tbl_transaksi`
  MODIFY `id_transaksi` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT untuk tabel `tbl_wallet`
--
ALTER TABLE `tbl_wallet`
  MODIFY `id_wallet` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `tbl_wallet_ledger`
--
ALTER TABLE `tbl_wallet_ledger`
  MODIFY `id_mutasi` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `tbl_wallet_topup`
--
ALTER TABLE `tbl_wallet_topup`
  MODIFY `id_topup` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- Ketidakleluasaan untuk tabel pelimpahan (Dumped Tables)
--

--
-- Ketidakleluasaan untuk tabel `tbl_detail_pesanan`
--
ALTER TABLE `tbl_detail_pesanan`
  ADD CONSTRAINT `fk_detail_pesanan` FOREIGN KEY (`id_pesanan`) REFERENCES `tbl_pesanan` (`id_pesanan`),
  ADD CONSTRAINT `fk_detail_produk` FOREIGN KEY (`id_produk`) REFERENCES `tbl_produk` (`id_produk`);

--
-- Ketidakleluasaan untuk tabel `tbl_pesanan`
--
ALTER TABLE `tbl_pesanan`
  ADD CONSTRAINT `fk_pesanan_kasir` FOREIGN KEY (`id_kasir`) REFERENCES `tbl_akun` (`id_akun`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_pesanan_transaksi` FOREIGN KEY (`id_transaksi`) REFERENCES `tbl_transaksi` (`id_transaksi`);

--
-- Ketidakleluasaan untuk tabel `tbl_produk`
--
ALTER TABLE `tbl_produk`
  ADD CONSTRAINT `fk_produk_variant_master` FOREIGN KEY (`id_produk_master`) REFERENCES `tbl_produk_master` (`id_produk_master`);

--
-- Ketidakleluasaan untuk tabel `tbl_transaksi`
--
ALTER TABLE `tbl_transaksi`
  ADD CONSTRAINT `tbl_transaksi_ibfk_1` FOREIGN KEY (`id_pelanggan`) REFERENCES `tbl_pelanggan` (`id_pelanggan`);

--
-- Ketidakleluasaan untuk tabel `tbl_wallet`
--
ALTER TABLE `tbl_wallet`
  ADD CONSTRAINT `fk_tbl_wallet_pelanggan` FOREIGN KEY (`id_pelanggan`) REFERENCES `tbl_pelanggan` (`id_pelanggan`) ON DELETE CASCADE;

--
-- Ketidakleluasaan untuk tabel `tbl_wallet_ledger`
--
ALTER TABLE `tbl_wallet_ledger`
  ADD CONSTRAINT `fk_tbl_wallet_ledger_wallet` FOREIGN KEY (`id_wallet`) REFERENCES `tbl_wallet` (`id_wallet`);

--
-- Ketidakleluasaan untuk tabel `tbl_wallet_topup`
--
ALTER TABLE `tbl_wallet_topup`
  ADD CONSTRAINT `fk_tbl_wallet_topup_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `tbl_akun` (`id_akun`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_tbl_wallet_topup_wallet` FOREIGN KEY (`id_wallet`) REFERENCES `tbl_wallet` (`id_wallet`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
