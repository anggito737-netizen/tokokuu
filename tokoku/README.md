# Tokoku — Retail Intelligence

Sistem penjualan berbasis PHP 8+, MySQL/MariaDB, HTML, CSS, dan JavaScript. Aplikasi menambahkan lapisan akun, katalog, dan pesanan pada `db_tokoku` tanpa mengganti objek bisnis lama.

## Menjalankan di XAMPP

1. Pastikan Apache, MySQL/MariaDB, dan ekstensi PHP `pdo_mysql` aktif.
2. Pastikan database `db_tokoku` serta objek yang digunakan aplikasi sudah tersedia.
3. Jalankan sekali `database/auth_schema.sql`, `database/retail_schema.sql`, `database/product_variants.sql`, lalu `database/wallet_schema.sql` pada `db_tokoku`. Migrasi varian mengelompokkan produk katalog yang sudah ada ke master tanpa mengubah foreign key maupun snapshot detail pesanan. Migrasi dompet menambahkan saldo, ledger, top up, dan metode pembayaran saldo tanpa menghapus data lama.
4. Jika kredensial database berbeda dari nilai default XAMPP, atur `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, dan `DB_PASS` untuk Apache/PHP dan CLI.
5. Buat akun admin pertama dari CLI. Atur `TOKOKU_ADMIN_EMAIL` dan `TOKOKU_ADMIN_PASSWORD` (minimal 12 karakter) pada environment proses PHP, lalu jalankan `php api/setup-admin.php`.
6. Untuk membuat akun kasir, atur `TOKOKU_CASHIER_EMAIL` dan `TOKOKU_CASHIER_PASSWORD` (minimal 12 karakter), lalu jalankan `php api/setup-cashier.php`. Admin harus tersedia lebih dahulu.
7. Buka `http://localhost/tokoku/public/`. Admin dapat menambah produk; katalog storefront dan POS akan tetap kosong sampai ada produk aktif.

Default koneksi: `127.0.0.1:3306`, database `db_tokoku`, user `root`, password kosong. File `database/db_tokoku.sql` hanya berisi query inspeksi metadata yang read-only; file itu bukan skrip instalasi dan aman dijalankan untuk memeriksa objek. Jangan jalankan skrip yang menghapus/membuat ulang routine pada database produksi.

## Integrasi dan batasan skema

- Login admin dan kasir memakai akun yang dibuat lewat CLI; registrasi publik hanya membuat akun pelanggan.
- Registrasi pelanggan membuat catatan pada `tbl_pelanggan` dan akun ber-password hash pada `tbl_akun`. Sesi server, cookie `HttpOnly`/`SameSite`, dan token CSRF melindungi API.
- Admin mengelola produk, stok, diskon, pelanggan, laporan, dan audit. Kasir mengakses POS katalog dan antrean pesanan online; harga dan diskon selalu ditentukan server/database. Pelanggan hanya dapat membaca profil serta pesanan sendiri dan membuat pesanan yang otomatis ditautkan ke ID mereka.
- Untuk pelanggan lama yang sudah memiliki histori transaksi, admin perlu memverifikasi identitas lalu menautkan akunnya lewat CLI dengan `TOKOKU_CUSTOMER_ID`, `TOKOKU_CUSTOMER_EMAIL`, dan `TOKOKU_CUSTOMER_PASSWORD` (minimal 12 karakter), kemudian menjalankan `php api/link-customer.php`. Ini menghindari pendaftaran publik yang dapat mengklaim histori pelanggan lain.
- Pelanggan memakai kolom `tbl_pelanggan.nama_pelanggan` dan `kota`; daftar menggunakan `view_total_belanja_pelanggan`.
- Transaksi/report memakai `tbl_transaksi.tanggal` dan `total_belanja`, serta `view_laporan_transaksi`.
- Dashboard memanggil `HitungPelanggan()`. Tambah pelanggan memakai `TambahPelanggan()`, detail memakai `CariPelanggan(id)`, dan endpoint tambahan menyediakan `TampilPelanggan()` serta `LaporanTransaksi(id)`.
- Katalog, stok, diskon per produk, dan detail pesanan tersimpan di tabel tambahan `tbl_produk`, `tbl_pesanan`, dan `tbl_detail_pesanan`. Checkout mengunci stok, membaca ulang harga/diskon dari database, memanggil `HitungDiskon()`, `HitungPajak()`, `HitungTotal()`, kemudian memperbarui stok dan `tbl_transaksi` secara atomik.
- Dompet pelanggan disimpan di `tbl_wallet`; setiap top up yang disetujui, pembelian dengan saldo, dan pengembalian pesanan dicatat di ledger `tbl_wallet_ledger`. Top up berstatus menunggu sampai admin memverifikasi pembayaran dan menyetujuinya. Saldo baru ditambahkan setelah persetujuan, sedangkan checkout saldo mengurangi saldo dan menyimpan penjualan/pesanan secara atomik.
- Top up menyediakan transfer bank, QRIS, debit, OVO, DANA, dan GoPay. Aplikasi belum terhubung ke payment gateway atau notifikasi pembayaran otomatis: admin harus memeriksa pembayaran pada kanal terkait sebelum menyetujui permintaan. Pembelian saldo hanya untuk checkout online pelanggan; saldo yang digunakan langsung dihitung sebagai penjualan dan pengembalian pesanan yang dibatalkan dikreditkan kembali.
- Katalog memakai `tbl_produk_master` sebagai data nama/kategori/harga/gambar/diskon dan `tbl_produk` sebagai varian dengan stok masing-masing. Satu produk induk dapat memiliki banyak pilihan seperti ukuran, warna, model, atau isi; nama pilihan disimpan di kolom `ukuran` yang sudah ada. Checkout dan detail penjualan tetap mengacu ke ID varian untuk menjaga stok dan histori. Form admin dapat membuat beberapa varian sekaligus; pelanggan dan kasir memilih varian sebelum menambahkan ke keranjang.
- Admin dapat mengunggah gambar produk JPG, PNG, atau WebP hingga 5 MB melalui form produk. File disimpan di `public/uploads/products` dengan nama acak dan URL relatif disimpan pada produk. Pastikan Apache/PHP dapat menulis ke direktori `public` (aplikasi membuat subdirektori upload saat gambar pertama diunggah); SVG dan gambar lebih dari 20 megapiksel ditolak. URL gambar eksternal yang valid tetap dapat digunakan.
- Preview keranjang juga dihitung lewat stored functions di database. Stok katalog di-refresh berkala; pesanan online dapat dikonfirmasi, diproses, diselesaikan, atau dibatalkan. Pembatalan mengembalikan stok dalam transaksi database.
- Metode COD, transfer, debit, OVO, DANA, GoPay, dan QRIS dicatat pada pesanan. Aplikasi belum terhubung ke payment gateway, sehingga status pembayaran dikonfirmasi oleh kasir/admin; pemilihan metode bukan bukti pembayaran elektronik.
- Struk kasir membuka dialog cetak browser yang dapat disimpan sebagai PDF.
- Kategori memakai `KategoriBelanja()` yang sudah ada (label Gold mulai Rp1.000.000 dan Silver mulai Rp500.000 pada database saat ini).
- `KonversiNilai(nilai)` pada database saat ini mengubah nilai 0–100 menjadi grade A–E; API mempertahankannya pada endpoint `convert-grade`, bukan menggunakannya sebagai kategori belanja.
- Transaksi lama tetap tampil sebagai histori berstatus selesai; kolom item/metode bayar yang memang belum tercatat pada skema lama ditandai sebagai data lama.
- Penghapusan pelanggan dengan histori transaksi ditolak karena constraint database; transaksi dan audit tetap utuh. Penghapusan pelanggan tanpa histori dicatat oleh API ke kedua tabel log.
- Trigger database yang ada mencatat insert/update dan menolak total transaksi negatif. Audit log diperbarui otomatis di UI setiap 30 detik saat halaman audit terbuka.

## Endpoint

Semua endpoint memakai `api/index.php?route=...` dan mengembalikan JSON.

| Method | Route | Keterangan |
|---|---|---|
| GET | `auth/session` | Status login dan token CSRF |
| POST | `auth/login` | Login admin, kasir, atau pelanggan |
| POST | `auth/register` | Registrasi akun pelanggan |
| POST | `auth/logout` | Mengakhiri sesi |
| GET | `dashboard` | (Admin) Metrik, `HitungPelanggan()`, tren 7 hari |
| GET | `customers&q=&page=&limit=` | View pelanggan + `KategoriBelanja()` |
| POST | `customers` | Tambah melalui `TambahPelanggan()` |
| PUT / DELETE | `customers&id=` | Ubah/hapus dengan pencatatan audit |
| GET | `customer-detail&id=` | Detail melalui `CariPelanggan()` |
| GET | `customers-all` | Daftar melalui `TampilPelanggan()` |
| GET | `transactions&from=&to=&page=&limit=` | Filter laporan dari view |
| GET | `products&q=&category=` | Produk katalog aktif; admin melihat produk terarsip juga |
| POST / PUT / DELETE | `products&id=` | (Admin) Kelola produk, stok, diskon; delete mengarsipkan |
| PUT | `product-discount&id=` | (Admin) Sakelar diskon produk |
| GET | `calculate-cart&items=` | Preview keranjang melalui stored functions |
| POST | `checkout` | Checkout POS/storefront, reserve stok, simpan transaksi/detail/pembayaran |
| GET | `orders&status=` | Riwayat pribadi atau antrean pesanan online admin/kasir |
| GET | `order-detail&id=` | Detail pesanan sesuai hak akses |
| PUT | `order-status&id=` | (Admin/Kasir) Proses atau batalkan; pembatalan mengembalikan stok |
| GET | `customer-transactions&id=` | Riwayat melalui `LaporanTransaksi()` |
| GET | `convert-grade&nilai=` | Konversi nilai melalui `KonversiNilai()` |
| GET | `logs&limit=` | Gabungan dua tabel audit |
| GET | `my-profile` | (Pelanggan) Profil akun sendiri |
| GET | `wallet` | (Pelanggan) Saldo dan status top up terbaru |
| POST | `wallet-topups` | (Pelanggan) Ajukan top up Rp10.000–Rp10.000.000 |
| GET | `wallet-admin` | (Admin) Total saldo, penjualan via saldo, dan permintaan top up |
| PUT | `wallet-topups&id=` | (Admin) Setujui atau tolak top up; persetujuan menambah saldo |

Ekspor CSV kompatibel dengan Excel. Tombol PDF/Cetak menggunakan dialog cetak browser (“Save as PDF”).

## Catatan deployment

Gunakan HTTPS di production agar cookie sesi beratribut `Secure`, batasi akses database ke host aplikasi, serta simpan kredensial di environment rahasia. Tabel akun menggunakan `password_hash()` PHP dan kata sandi tidak disimpan dalam teks biasa. Tabel bisnis dan transaksi lama tetap menjadi sumber data; aplikasi tidak mengisi transaksi contoh.
