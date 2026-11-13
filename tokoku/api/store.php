<?php
declare(strict_types=1);

function ensureCustomerWallet(PDO $pdo, int $customerId, bool $lock = false): array
{
    $insert = $pdo->prepare('INSERT IGNORE INTO tbl_wallet (id_pelanggan, saldo) VALUES (?, 0.00)');
    $insert->execute([$customerId]);
    $stmt = $pdo->prepare(
        'SELECT id_wallet, saldo FROM tbl_wallet WHERE id_pelanggan = ?' . ($lock ? ' FOR UPDATE' : '')
    );
    $stmt->execute([$customerId]);
    $wallet = $stmt->fetch();
    if (!$wallet) {
        throw new RuntimeException('Dompet pelanggan tidak dapat diakses.');
    }
    return $wallet;
}

function handleStoreRoute(PDO $pdo, string $method, string $route, array $user): void
{
    $role = (string) $user['role'];

    if ($method === 'GET' && $route === 'wallet') {
        if ($role !== 'customer') {
            respond(['error' => 'Fitur dompet hanya tersedia untuk pelanggan.'], 403);
        }
        $wallet = ensureCustomerWallet($pdo, (int) $user['id_pelanggan']);
        $topupsStmt = $pdo->prepare(
            'SELECT id_topup, nominal, metode_pembayaran, status, created_at, reviewed_at
             FROM tbl_wallet_topup WHERE id_wallet = ? ORDER BY created_at DESC LIMIT 10'
        );
        $topupsStmt->execute([$wallet['id_wallet']]);
        respond(['data' => [
            'saldo' => (float) $wallet['saldo'],
            'topups' => $topupsStmt->fetchAll(),
        ]]);
    }

    if ($method === 'POST' && $route === 'wallet-topups') {
        if ($role !== 'customer') {
            respond(['error' => 'Hanya pelanggan yang dapat mengajukan top up.'], 403);
        }
        $input = readInput();
        $amount = filter_var($input['nominal'] ?? null, FILTER_VALIDATE_INT);
        $payment = (string) ($input['metode_pembayaran'] ?? '');
        if ($amount === false || $amount < 10000 || $amount > 10000000) {
            respond(['error' => 'Nominal top up harus antara Rp 10.000 dan Rp 10.000.000.'], 422);
        }
        if (!in_array($payment, ['bank', 'qris', 'debit', 'ovo', 'dana', 'gopay'], true)) {
            respond(['error' => 'Pilih metode pembayaran top up yang tersedia.'], 422);
        }

        $pdo->beginTransaction();
        try {
            $wallet = ensureCustomerWallet($pdo, (int) $user['id_pelanggan'], true);
            $stmt = $pdo->prepare(
                'INSERT INTO tbl_wallet_topup (id_wallet, nominal, metode_pembayaran)
                 VALUES (?, ?, ?)'
            );
            $stmt->execute([$wallet['id_wallet'], $amount, $payment]);
            $topupId = (int) $pdo->lastInsertId();
            $pdo->commit();
            respond([
                'message' => 'Permintaan top up tercatat dan menunggu verifikasi admin.',
                'data' => ['id_topup' => $topupId, 'status' => 'pending'],
            ], 201);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    if ($method === 'GET' && $route === 'wallet-admin') {
        if ($role !== 'admin') {
            respond(['error' => 'Hanya admin yang dapat memantau top up dan saldo pelanggan.'], 403);
        }
        $balance = (float) $pdo->query(
            'SELECT COALESCE(SUM(saldo), 0) FROM tbl_wallet'
        )->fetchColumn();
        $walletSales = (float) $pdo->query(
            "SELECT COALESCE(SUM(t.total_belanja), 0)
             FROM tbl_transaksi t JOIN tbl_pesanan o ON o.id_transaksi = t.id_transaksi
             WHERE o.sumber = 'online' AND o.metode_pembayaran = 'wallet'
               AND o.status <> 'cancelled'"
        )->fetchColumn();
        $pending = (int) $pdo->query(
            "SELECT COUNT(*) FROM tbl_wallet_topup WHERE status = 'pending'"
        )->fetchColumn();
        $requestsStmt = $pdo->prepare(
            'SELECT t.id_topup, t.nominal, t.metode_pembayaran, t.status, t.created_at,
                    p.nama_pelanggan, a.email
             FROM tbl_wallet_topup t
             JOIN tbl_wallet w ON w.id_wallet = t.id_wallet
             JOIN tbl_pelanggan p ON p.id_pelanggan = w.id_pelanggan
             JOIN tbl_akun a ON a.id_pelanggan = p.id_pelanggan AND a.role = ?
             ORDER BY (t.status = ?) DESC, t.created_at DESC
             LIMIT 300'
        );
        $requestsStmt->execute(['customer', 'pending']);
        $requests = $requestsStmt->fetchAll();
        respond(['data' => [
            'summary' => [
                'total_saldo' => $balance,
                'penjualan_wallet' => $walletSales,
                'pending_topup' => $pending,
            ],
            'topups' => $requests,
        ]]);
    }

    if ($method === 'PUT' && $route === 'wallet-topups') {
        if ($role !== 'admin') {
            respond(['error' => 'Hanya admin yang dapat menyetujui atau menolak top up.'], 403);
        }
        $topupId = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        $input = readInput();
        $decision = (string) ($input['status'] ?? '');
        if (!$topupId || !in_array($decision, ['approved', 'rejected'], true)) {
            respond(['error' => 'ID top up atau keputusan tidak valid.'], 422);
        }
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare(
                'SELECT t.id_topup, t.id_wallet, t.nominal, t.status, w.saldo
                 FROM tbl_wallet_topup t
                 JOIN tbl_wallet w ON w.id_wallet = t.id_wallet
                 WHERE t.id_topup = ? FOR UPDATE'
            );
            $stmt->execute([$topupId]);
            $topup = $stmt->fetch();
            if (!$topup || $topup['status'] !== 'pending') {
                throw new DomainException('Permintaan top up tidak ditemukan atau sudah diproses.');
            }

            if ($decision === 'approved') {
                $newBalance = (float) $topup['saldo'] + (float) $topup['nominal'];
                $updateWallet = $pdo->prepare('UPDATE tbl_wallet SET saldo = saldo + ? WHERE id_wallet = ?');
                $updateWallet->execute([$topup['nominal'], $topup['id_wallet']]);
                $ledger = $pdo->prepare(
                    "INSERT INTO tbl_wallet_ledger
                     (id_wallet, jenis, id_referensi, debit, kredit, saldo_setelah, keterangan)
                     VALUES (?, 'topup', ?, 0, ?, ?, ?)"
                );
                $ledger->execute([
                    $topup['id_wallet'], $topupId, $topup['nominal'], $newBalance, "Top up #{$topupId}",
                ]);
            }

            $updateTopup = $pdo->prepare(
                'UPDATE tbl_wallet_topup
                 SET status = ?, reviewed_by = ?, reviewed_at = CURRENT_TIMESTAMP
                 WHERE id_topup = ? AND status = ?'
            );
            $updateTopup->execute([$decision, $user['id_akun'], $topupId, 'pending']);
            if ($updateTopup->rowCount() !== 1) {
                throw new DomainException('Permintaan top up sudah diproses.');
            }
            $pdo->commit();
            respond(['message' => $decision === 'approved'
                ? 'Top up disetujui dan saldo pelanggan bertambah.'
                : 'Permintaan top up ditolak.']);
        } catch (DomainException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            respond(['error' => $error->getMessage()], 409);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    if ($method === 'POST' && $route === 'product-image') {
        if ($role !== 'admin') {
            respond(['error' => 'Hanya admin yang dapat mengunggah gambar produk.'], 403);
        }
        if (!isset($_FILES['gambar']) || !is_array($_FILES['gambar'])) {
            respond(['error' => 'Pilih file gambar produk terlebih dahulu.'], 422);
        }
        $upload = $_FILES['gambar'];
        if (($upload['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            $message = match ((int) $upload['error']) {
                UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE => 'Ukuran gambar melebihi batas upload server.',
                UPLOAD_ERR_PARTIAL => 'Gambar hanya terunggah sebagian. Coba lagi.',
                UPLOAD_ERR_NO_FILE => 'Pilih file gambar produk terlebih dahulu.',
                default => 'Gambar gagal diunggah. Coba lagi.',
            };
            respond(['error' => $message], 422);
        }
        if ((int) ($upload['size'] ?? 0) < 1 || (int) $upload['size'] > 5 * 1024 * 1024
            || !is_uploaded_file((string) $upload['tmp_name'])) {
            respond(['error' => 'Gambar harus berukuran maksimal 5 MB.'], 422);
        }
        $imageInfo = @getimagesize((string) $upload['tmp_name']);
        $mime = (new finfo(FILEINFO_MIME_TYPE))->file((string) $upload['tmp_name']);
        $extensions = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
        if (!$imageInfo || !isset($extensions[$mime])
            || $imageInfo[0] < 1 || $imageInfo[1] < 1
            || $imageInfo[0] * $imageInfo[1] > 20000000) {
            respond(['error' => 'Gunakan gambar JPG, PNG, atau WebP yang valid (maks. 20 megapiksel).'], 422);
        }

        $uploadDirectory = __DIR__ . '/../public/uploads/products';
        if (!is_dir($uploadDirectory) && !mkdir($uploadDirectory, 0755, true) && !is_dir($uploadDirectory)) {
            throw new RuntimeException('Direktori gambar produk tidak dapat dibuat.');
        }
        $filename = bin2hex(random_bytes(16)) . '.' . $extensions[$mime];
        if (!move_uploaded_file((string) $upload['tmp_name'], $uploadDirectory . '/' . $filename)) {
            throw new RuntimeException('Gambar produk tidak dapat disimpan.');
        }
        respond(['message' => 'Gambar produk berhasil diunggah.', 'gambar_url' => 'uploads/products/' . $filename], 201);
    }

    if ($method === 'GET' && $route === 'calculate-cart') {
        $items = json_decode((string) ($_GET['items'] ?? ''), true);
        if (!is_array($items) || !$items || count($items) > 100) {
            respond(['error' => 'Keranjang kosong atau jumlah item tidak valid.'], 422);
        }
        $subtotal = 0.0;
        $discount = 0.0;
        $lines = [];
        $discountStmt = $pdo->prepare('SELECT HitungDiskon(?, ?)');
        $productStmt = $pdo->prepare(
            'SELECT variant.id_produk, master.nama_produk, variant.ukuran, master.harga,
                    variant.stok, master.diskon_persen, master.diskon_aktif
             FROM tbl_produk variant
             JOIN tbl_produk_master master ON master.id_produk_master = variant.id_produk_master
             WHERE variant.id_produk = ? AND variant.aktif = 1 AND master.aktif = 1'
        );
        foreach ($items as $item) {
            $id = filter_var($item['id_produk'] ?? null, FILTER_VALIDATE_INT);
            $quantity = filter_var($item['jumlah'] ?? null, FILTER_VALIDATE_INT);
            if (!$id || !$quantity || $quantity > 999) {
                respond(['error' => 'Produk atau jumlah barang tidak valid.'], 422);
            }
            $productStmt->execute([$id]);
            $product = $productStmt->fetch();
            if (!$product || (int) $product['stok'] < $quantity) {
                respond(['error' => 'Produk tidak tersedia atau stok tidak mencukupi.'], 422);
            }
            $rate = (int) $product['diskon_aktif'] ? (float) $product['diskon_persen'] : 0.0;
            $discountStmt->execute([(float) $product['harga'], $rate]);
            $lineDiscount = (float) $discountStmt->fetchColumn() * $quantity;
            $lineSubtotal = ((float) $product['harga'] * $quantity) - $lineDiscount;
            $subtotal += (float) $product['harga'] * $quantity;
            $discount += $lineDiscount;
            $lines[] = [
                'id_produk' => (int) $id,
                'jumlah' => (int) $quantity,
                'nama_produk' => $product['nama_produk'] . ($product['ukuran'] !== null ? ' · ' . $product['ukuran'] : ''),
                'ukuran' => $product['ukuran'],
                'harga_satuan' => (float) $product['harga'],
                'diskon' => $lineDiscount,
                'subtotal' => $lineSubtotal,
            ];
        }
        $taxStmt = $pdo->prepare('SELECT HitungPajak(?)');
        $taxStmt->execute([$subtotal - $discount]);
        $tax = (float) $taxStmt->fetchColumn();
        $totalStmt = $pdo->prepare('SELECT HitungTotal(?, 1)');
        $totalStmt->execute([$subtotal - $discount + $tax]);
        respond(['data' => [
            'items' => $lines,
            'subtotal' => $subtotal,
            'diskon' => $discount,
            'pajak' => $tax,
            'total_belanja' => (float) $totalStmt->fetchColumn(),
        ]]);
    }

    if ($method === 'GET' && $route === 'products') {
        $admin = $role === 'admin';
        $includeArchived = $admin && (string) ($_GET['include_archived'] ?? '') === '1';
        $search = trim((string) ($_GET['q'] ?? ''));
        $category = trim((string) ($_GET['category'] ?? ''));
        $conditions = $includeArchived ? [] : ['aktif = 1'];
        $params = [];
        if ($search !== '') {
            $conditions[] = '(nama_produk LIKE :search OR kategori LIKE :search)';
            $params['search'] = '%' . $search . '%';
        }
        if ($category !== '') {
            $conditions[] = 'kategori = :category';
            $params['category'] = $category;
        }
        $where = $conditions ? ' WHERE ' . implode(' AND ', $conditions) : '';
        $stmt = $pdo->prepare(
            'SELECT id_produk_master AS id_produk, nama_produk, kategori, harga, gambar_url,
                    diskon_persen, diskon_aktif, aktif
             FROM tbl_produk_master' . $where . ' ORDER BY nama_produk'
        );
        $stmt->execute($params);
        $products = $stmt->fetchAll();
        $variantStmt = $pdo->prepare(
            'SELECT id_produk, ukuran, stok, aktif
             FROM tbl_produk
             WHERE id_produk_master = ?' . ($includeArchived ? '' : ' AND aktif = 1') . '
             ORDER BY ukuran'
        );
        foreach ($products as &$product) {
            $variantStmt->execute([$product['id_produk']]);
            $product['variants'] = $variantStmt->fetchAll();
            $product['stok'] = array_sum(array_map(
                static fn(array $variant): int => (int) $variant['stok'],
                $product['variants']
            ));
        }
        unset($product);
        $categories = $pdo->query(
            'SELECT DISTINCT kategori FROM tbl_produk_master WHERE aktif = 1 ORDER BY kategori'
        )->fetchAll(PDO::FETCH_COLUMN);
        respond(['data' => $products, 'categories' => $categories]);
    }

    if ($method === 'POST' && $route === 'checkout') {
        if (!in_array($role, ['customer', 'cashier', 'admin'], true)) {
            respond(['error' => 'Anda tidak memiliki akses membuat pesanan.'], 403);
        }
        $input = readInput();
        $source = $role === 'customer' ? 'online' : (string) ($input['source'] ?? 'pos');
        if (!in_array($source, ['online', 'pos'], true) || ($source === 'online' && $role !== 'customer')) {
            respond(['error' => 'Jenis pesanan tidak valid.'], 422);
        }
        $payment = (string) ($input['metode_pembayaran'] ?? '');
        $payments = ['cod', 'bank', 'debit', 'ovo', 'dana', 'gopay', 'qris', 'wallet'];
        if (!in_array($payment, $payments, true)) {
            respond(['error' => 'Pilih metode pembayaran yang tersedia.'], 422);
        }
        if ($payment === 'wallet' && ($role !== 'customer' || $source !== 'online')) {
            respond(['error' => 'Saldo akun hanya dapat digunakan pelanggan untuk checkout online.'], 422);
        }
        $items = $input['items'] ?? null;
        if (!is_array($items) || !$items || count($items) > 100) {
            respond(['error' => 'Keranjang kosong atau jumlah item tidak valid.'], 422);
        }
        $quantities = [];
        foreach ($items as $item) {
            $id = filter_var($item['id_produk'] ?? null, FILTER_VALIDATE_INT);
            $quantity = filter_var($item['jumlah'] ?? null, FILTER_VALIDATE_INT);
            if (!$id || !$quantity || $quantity > 999) {
                respond(['error' => 'Produk atau jumlah barang tidak valid.'], 422);
            }
            $quantities[$id] = ($quantities[$id] ?? 0) + $quantity;
        }
        if (count($quantities) > 100) {
            respond(['error' => 'Keranjang berisi terlalu banyak produk.'], 422);
        }
        ksort($quantities, SORT_NUMERIC);

        $customerId = null;
        if ($role === 'customer') {
            $customerId = (int) $user['id_pelanggan'];
        } elseif (isset($input['id_pelanggan']) && $input['id_pelanggan'] !== '') {
            $customerId = filter_var($input['id_pelanggan'], FILTER_VALIDATE_INT);
            if (!$customerId || $customerId < 1) {
                respond(['error' => 'ID pelanggan tidak valid.'], 422);
            }
        }
        $pdo->beginTransaction();
        try {
            if ($customerId !== null) {
                $customerStmt = $pdo->prepare('SELECT id_pelanggan FROM tbl_pelanggan WHERE id_pelanggan = ? FOR UPDATE');
                $customerStmt->execute([$customerId]);
                if (!$customerStmt->fetchColumn()) {
                    throw new DomainException('Pelanggan tidak ditemukan.');
                }
            }
            $productStmt = $pdo->prepare(
                'SELECT variant.id_produk, variant.ukuran, variant.stok, variant.aktif AS variant_aktif,
                        master.nama_produk, master.harga, master.diskon_persen, master.diskon_aktif,
                        master.aktif AS master_aktif
                 FROM tbl_produk variant
                 JOIN tbl_produk_master master ON master.id_produk_master = variant.id_produk_master
                 WHERE variant.id_produk = ? FOR UPDATE'
            );
            $products = [];
            foreach ($quantities as $id => $quantity) {
                $productStmt->execute([$id]);
                $product = $productStmt->fetch();
                if (!$product || !(int) $product['variant_aktif'] || !(int) $product['master_aktif']) {
                    throw new DomainException("Produk #{$id} tidak tersedia.");
                }
                if ((int) $product['stok'] < $quantity) {
                    throw new DomainException("Stok varian {$product['nama_produk']} · {$product['ukuran']} tidak mencukupi.");
                }
                $product['nama_varian'] = $product['nama_produk'] . ($product['ukuran'] !== null ? ' · ' . $product['ukuran'] : '');
                $products[$id] = $product;
            }

            $subtotal = 0.0;
            $discount = 0.0;
            $lines = [];
            $discountQuery = $pdo->prepare('SELECT HitungDiskon(?, ?)'); 
            foreach ($quantities as $id => $quantity) {
                $product = $products[$id];
                $rate = (int) $product['diskon_aktif'] ? (float) $product['diskon_persen'] : 0.0;
                $discountQuery->execute([(float) $product['harga'], $rate]);
                $unitDiscount = (float) $discountQuery->fetchColumn();
                $lineSubtotal = ((float) $product['harga'] - $unitDiscount) * $quantity;
                $subtotal += (float) $product['harga'] * $quantity;
                $discount += $unitDiscount * $quantity;
                $lines[] = [
                    'product' => $product,
                    'quantity' => $quantity,
                    'rate' => $rate,
                    'discount' => $unitDiscount * $quantity,
                    'subtotal' => $lineSubtotal,
                ];
            }

            $taxable = $subtotal - $discount;
            $taxStmt = $pdo->prepare('SELECT HitungPajak(?)');
            $taxStmt->execute([$taxable]);
            $tax = (float) $taxStmt->fetchColumn();
            $totalStmt = $pdo->prepare('SELECT HitungTotal(?, 1)');
            $totalStmt->execute([$taxable + $tax]);
            $total = (float) $totalStmt->fetchColumn();
            if ($total < 0) {
                throw new DomainException('Total belanja tidak boleh bernilai negatif.');
            }

            $wallet = null;
            if ($payment === 'wallet') {
                if ($customerId === null) {
                    throw new DomainException('Akun pelanggan tidak terhubung ke dompet.');
                }
                $wallet = ensureCustomerWallet($pdo, $customerId, true);
                if ((float) $wallet['saldo'] < $total) {
                    throw new DomainException('Saldo akun tidak mencukupi untuk menyelesaikan checkout.');
                }
            }

            $transactionStmt = $pdo->prepare(
                'INSERT INTO tbl_transaksi (id_pelanggan, tanggal, total_belanja)
                 VALUES (?, CURDATE(), ?)'
            );
            $transactionStmt->execute([$customerId, $total]);
            $transactionId = (int) $pdo->lastInsertId();
            $status = $payment === 'wallet' ? 'processing' : ($source === 'online' ? 'pending' : 'completed');
            $orderStmt = $pdo->prepare(
                'INSERT INTO tbl_pesanan (id_transaksi, sumber, metode_pembayaran, status, id_kasir)
                 VALUES (?, ?, ?, ?, ?)'
            );
            $orderStmt->execute([
                $transactionId,
                $source,
                $payment,
                $status,
                $source === 'pos' ? (int) $user['id_akun'] : null,
            ]);
            $orderId = (int) $pdo->lastInsertId();
            $detailStmt = $pdo->prepare(
                'INSERT INTO tbl_detail_pesanan
                 (id_pesanan, id_produk, nama_produk, jumlah, harga_satuan, diskon_persen, diskon_nominal, subtotal)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
            );
            $stockStmt = $pdo->prepare('UPDATE tbl_produk SET stok = stok - ? WHERE id_produk = ? AND stok >= ?');
            foreach ($lines as $line) {
                $product = $line['product'];
                $detailStmt->execute([
                    $orderId,
                    $product['id_produk'],
                    $product['nama_varian'],
                    $line['quantity'],
                    $product['harga'],
                    $line['rate'],
                    $line['discount'],
                    $line['subtotal'],
                ]);
                $stockStmt->execute([$line['quantity'], $product['id_produk'], $line['quantity']]);
                if ($stockStmt->rowCount() !== 1) {
                    throw new DomainException("Stok {$product['nama_produk']} berubah. Muat ulang keranjang.");
                }
            }
            $remainingBalance = null;
            if ($wallet !== null && $total > 0) {
                $walletUpdate = $pdo->prepare(
                    'UPDATE tbl_wallet SET saldo = saldo - ? WHERE id_wallet = ? AND saldo >= ?'
                );
                $walletUpdate->execute([$total, $wallet['id_wallet'], $total]);
                if ($walletUpdate->rowCount() !== 1) {
                    throw new DomainException('Saldo berubah atau tidak mencukupi. Muat ulang halaman dan coba lagi.');
                }
                $balanceStmt = $pdo->prepare('SELECT saldo FROM tbl_wallet WHERE id_wallet = ?');
                $balanceStmt->execute([$wallet['id_wallet']]);
                $remainingBalance = (float) $balanceStmt->fetchColumn();
                $ledger = $pdo->prepare(
                    "INSERT INTO tbl_wallet_ledger
                     (id_wallet, jenis, id_referensi, debit, kredit, saldo_setelah, keterangan)
                     VALUES (?, 'purchase', ?, ?, 0, ?, ?)"
                );
                $ledger->execute([
                    $wallet['id_wallet'], $orderId, $total, $remainingBalance, "Pembelian online #{$orderId}",
                ]);
            } elseif ($wallet !== null) {
                $remainingBalance = (float) $wallet['saldo'];
            }
            $pdo->commit();
            respond(['message' => $source === 'online' ? 'Pesanan berhasil dibuat.' : 'Transaksi kasir berhasil disimpan.', 'data' => [
                'id_pesanan' => $orderId,
                'id_transaksi' => $transactionId,
                'status' => $status,
                'metode_pembayaran' => $payment,
                'subtotal' => $subtotal,
                'diskon' => $discount,
                'pajak' => $tax,
                'total_belanja' => $total,
                'saldo_tersisa' => $remainingBalance,
                'items' => array_map(static fn(array $line): array => [
                    'nama_produk' => $line['product']['nama_varian'],
                    'jumlah' => $line['quantity'],
                    'subtotal' => $line['subtotal'],
                ], $lines),
            ]], 201);
        } catch (DomainException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            respond(['error' => $error->getMessage()], 422);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }

    if (($method === 'POST' || $method === 'PUT') && $route === 'products') {
        if ($role !== 'admin') {
            respond(['error' => 'Hanya admin yang dapat mengelola produk.'], 403);
        }
        $input = readInput();
        $name = trim((string) ($input['nama_produk'] ?? ''));
        $category = trim((string) ($input['kategori'] ?? ''));
        $price = filter_var($input['harga'] ?? null, FILTER_VALIDATE_FLOAT);
        $rate = filter_var($input['diskon_persen'] ?? 0, FILTER_VALIDATE_FLOAT);
        $image = trim((string) ($input['gambar_url'] ?? ''));
        $discountActive = !empty($input['diskon_aktif']) ? 1 : 0;
        $active = !isset($input['aktif']) || !empty($input['aktif']) ? 1 : 0;
        $variants = $input['variants'] ?? null;
        if ($name === '') {
            respond(['error' => 'Nama produk wajib diisi.'], 422);
        }
        if (mb_strlen($name) > 150) {
            respond(['error' => 'Nama produk maksimal 150 karakter.'], 422);
        }
        if ($category === '') {
            respond(['error' => 'Kategori wajib diisi. Kategori boleh ditulis bebas oleh Admin.'], 422);
        }
        if (mb_strlen($category) > 80) {
            respond(['error' => 'Nama kategori maksimal 80 karakter.'], 422);
        }
        if ($price === false || $price < 0) {
            respond(['error' => 'Harga harus berupa angka nol atau lebih.'], 422);
        }
        if ($rate === false || $rate < 0 || $rate > 100) {
            respond(['error' => 'Diskon harus diisi antara 0 sampai 100 persen.'], 422);
        }
        if (mb_strlen($image) > 500
            || ($image !== '' && !preg_match('~^(https?://|/|uploads/products/)[^\s]*$~i', $image))) {
            respond(['error' => 'URL gambar tidak valid atau melebihi 500 karakter.'], 422);
        }
        if (!is_array($variants) || !$variants) {
            respond(['error' => 'Tambahkan minimal satu varian beserta nama dan stok sebelum menyimpan produk.'], 422);
        }
        if (count($variants) > 100) {
            respond(['error' => 'Maksimal 100 varian untuk satu produk.'], 422);
        }
        $validatedVariants = [];
        $seenSizes = [];
        foreach ($variants as $variant) {
            if (!is_array($variant)) {
                respond(['error' => 'Data varian produk tidak valid.'], 422);
            }
            $size = trim((string) ($variant['ukuran'] ?? ''));
            $quantity = filter_var($variant['stok'] ?? null, FILTER_VALIDATE_INT);
            $variantId = isset($variant['id_produk']) && $variant['id_produk'] !== ''
                ? filter_var($variant['id_produk'], FILTER_VALIDATE_INT)
                : null;
            if ($size === '' || mb_strlen($size) > 30 || $quantity === false || $quantity < 0
                || ($variantId !== null && (!$variantId || $variantId < 1))) {
                respond(['error' => 'Setiap varian harus memiliki nama (maksimal 30 karakter) dan stok valid.'], 422);
            }
            $sizeKey = mb_strtolower($size);
            if (isset($seenSizes[$sizeKey])) {
                respond(['error' => "Nama varian {$size} ditulis lebih dari satu kali."], 422);
            }
            $seenSizes[$sizeKey] = true;
            $validatedVariants[] = [
                'id_produk' => $variantId,
                'ukuran' => $size,
                'stok' => $quantity,
                'aktif' => !isset($variant['aktif']) || !empty($variant['aktif']) ? 1 : 0,
            ];
        }
        $id = null;
        if ($method === 'PUT') {
            $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
            if (!$id) {
                respond(['error' => 'ID produk tidak valid.'], 422);
            }
            foreach ($validatedVariants as $variant) {
                if ($variant['id_produk'] === null) {
                    continue;
                }
                $belongs = $pdo->prepare('SELECT COUNT(*) FROM tbl_produk WHERE id_produk = ? AND id_produk_master = ?');
                $belongs->execute([$variant['id_produk'], $id]);
                if (!(int) $belongs->fetchColumn()) {
                    respond(['error' => 'Varian tidak termasuk dalam produk ini. Muat ulang lalu coba lagi.'], 422);
                }
            }
        } elseif (count(array_filter($validatedVariants, static fn(array $variant): bool => $variant['id_produk'] !== null)) > 0) {
            respond(['error' => 'ID varian tidak boleh dikirim saat membuat produk baru.'], 422);
        }

        $pdo->beginTransaction();
        try {
            if ($method === 'POST') {
                $masterStmt = $pdo->prepare(
                    'INSERT INTO tbl_produk_master
                     (nama_produk, kategori, harga, gambar_url, diskon_persen, diskon_aktif, aktif)
                     VALUES (?, ?, ?, ?, ?, ?, ?)'
                );
                $masterStmt->execute([$name, $category, $price, $image ?: null, $rate, $discountActive, $active]);
                $id = (int) $pdo->lastInsertId();
            } else {
                $masterStmt = $pdo->prepare(
                    'UPDATE tbl_produk_master
                     SET nama_produk = ?, kategori = ?, harga = ?, gambar_url = ?,
                         diskon_persen = ?, diskon_aktif = ?, aktif = ?
                     WHERE id_produk_master = ?'
                );
                $masterStmt->execute([$name, $category, $price, $image ?: null, $rate, $discountActive, $active, $id]);
                if ($masterStmt->rowCount() === 0) {
                    $exists = $pdo->prepare('SELECT COUNT(*) FROM tbl_produk_master WHERE id_produk_master = ?');
                    $exists->execute([$id]);
                    if (!(int) $exists->fetchColumn()) {
                        throw new DomainException('Produk tidak ditemukan.');
                    }
                }
            }
            $insertVariant = $pdo->prepare(
                'INSERT INTO tbl_produk
                 (id_produk_master, nama_produk, kategori, harga, stok, ukuran, gambar_url,
                  diskon_persen, diskon_aktif, aktif)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            );
            $updateVariant = $pdo->prepare(
                'UPDATE tbl_produk
                 SET nama_produk = ?, kategori = ?, harga = ?, stok = ?, ukuran = ?, gambar_url = ?,
                     diskon_persen = ?, diskon_aktif = ?, aktif = ?
                 WHERE id_produk = ? AND id_produk_master = ?'
            );
            foreach ($validatedVariants as $variant) {
                $variantName = $name . ' - ' . $variant['ukuran'];
                if ($variant['id_produk'] === null) {
                    $insertVariant->execute([
                        $id, $variantName, $category, $price, $variant['stok'], $variant['ukuran'],
                        $image ?: null, $rate, $discountActive, $active && $variant['aktif'],
                    ]);
                } else {
                    $updateVariant->execute([
                        $variantName, $category, $price, $variant['stok'], $variant['ukuran'],
                        $image ?: null, $rate, $discountActive, $active && $variant['aktif'],
                        $variant['id_produk'], $id,
                    ]);
                }
            }
            $pdo->commit();
        } catch (DomainException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            respond(['error' => $error->getMessage()], 404);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
        respond([
            'message' => $method === 'POST' ? 'Produk dan variannya berhasil ditambahkan.' : 'Produk dan stok variannya berhasil diperbarui.',
            'id_produk' => $id,
        ], $method === 'POST' ? 201 : 200);
    }

    if ($method === 'PUT' && $route === 'product-discount') {
        if ($role !== 'admin') {
            respond(['error' => 'Hanya admin yang dapat mengubah diskon.'], 403);
        }
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        $input = readInput();
        $enabled = $input['aktif'] ?? null;
        if (!$id || !is_bool($enabled)) {
            respond(['error' => 'ID produk atau status diskon tidak valid.'], 422);
        }
        $stmt = $pdo->prepare('UPDATE tbl_produk_master SET diskon_aktif = ? WHERE id_produk_master = ?');
        $stmt->execute([$enabled ? 1 : 0, $id]);
        respond(['message' => 'Status diskon diperbarui.']);
    }

    if ($method === 'DELETE' && $route === 'products') {
        if ($role !== 'admin') {
            respond(['error' => 'Hanya admin yang dapat mengarsipkan produk.'], 403);
        }
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) {
            respond(['error' => 'ID produk tidak valid.'], 422);
        }
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('UPDATE tbl_produk_master SET aktif = 0 WHERE id_produk_master = ?');
            $stmt->execute([$id]);
            $pdo->prepare('UPDATE tbl_produk SET aktif = 0 WHERE id_produk_master = ?')->execute([$id]);
            $pdo->commit();
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
        respond(['message' => 'Produk diarsipkan dari katalog.']);
    }

    if ($method === 'GET' && $route === 'orders') {
        $params = [];
        $where = '';
        if ($role === 'customer') {
            $where = ' WHERE t.id_pelanggan = ?';
            $params[] = (int) $user['id_pelanggan'];
        } elseif (!in_array($role, ['admin', 'cashier'], true)) {
            respond(['error' => 'Anda tidak memiliki akses ke pesanan.'], 403);
        } else {
            $where = ' WHERE o.sumber = ?';
            $params[] = 'online';
        }
        if (isset($_GET['status']) && in_array($_GET['status'], ['pending', 'paying', 'processing', 'completed', 'cancelled'], true)) {
            $where .= ($where ? ' AND' : ' WHERE') . ' o.status = ?';
            $params[] = $_GET['status'];
        }
        $stmt = $pdo->prepare(
            "SELECT o.id_pesanan, t.id_transaksi, COALESCE(o.sumber, 'legacy') AS sumber,
                    o.metode_pembayaran, COALESCE(o.status, 'completed') AS status,
                    o.created_at, t.id_pelanggan, t.tanggal, t.total_belanja,
                    p.nama_pelanggan,
                    COALESCE((SELECT COUNT(*) FROM tbl_detail_pesanan d WHERE d.id_pesanan = o.id_pesanan), 0) AS jumlah_item,
                    (SELECT GROUP_CONCAT(CONCAT(d.nama_produk, ' ×', d.jumlah) SEPARATOR ', ')
                     FROM tbl_detail_pesanan d WHERE d.id_pesanan = o.id_pesanan) AS ringkasan_item
             FROM tbl_transaksi t LEFT JOIN tbl_pesanan o ON o.id_transaksi = t.id_transaksi
             LEFT JOIN tbl_pelanggan p ON p.id_pelanggan = t.id_pelanggan" . $where .
             ' ORDER BY COALESCE(o.created_at, t.tanggal) DESC, t.id_transaksi DESC LIMIT 200'
        );
        $stmt->execute($params);
        respond(['data' => $stmt->fetchAll()]);
    }

    if ($method === 'GET' && $route === 'order-detail') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) {
            respond(['error' => 'ID pesanan tidak valid.'], 422);
        }
        $sql = 'SELECT o.id_pesanan, o.id_transaksi, o.sumber, o.metode_pembayaran, o.status,
                       o.created_at, t.id_pelanggan, t.total_belanja, p.nama_pelanggan
                FROM tbl_pesanan o JOIN tbl_transaksi t ON t.id_transaksi = o.id_transaksi
                LEFT JOIN tbl_pelanggan p ON p.id_pelanggan = t.id_pelanggan
                WHERE o.id_pesanan = ?';
        $params = [$id];
        if ($role === 'customer') {
            $sql .= ' AND t.id_pelanggan = ?';
            $params[] = (int) $user['id_pelanggan'];
        } elseif (!in_array($role, ['admin', 'cashier'], true)) {
            respond(['error' => 'Anda tidak memiliki akses ke pesanan.'], 403);
        }
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $order = $stmt->fetch();
        if (!$order) {
            respond(['error' => 'Pesanan tidak ditemukan.'], 404);
        }
        $lines = $pdo->prepare(
            'SELECT id_produk, nama_produk, jumlah, harga_satuan, diskon_persen, diskon_nominal, subtotal
             FROM tbl_detail_pesanan WHERE id_pesanan = ? ORDER BY id_detail'
        );
        $lines->execute([$id]);
        respond(['data' => ['order' => $order, 'items' => $lines->fetchAll()]]);
    }

    if ($method === 'PUT' && $route === 'order-status') {
        if (!in_array($role, ['admin', 'cashier'], true)) {
            respond(['error' => 'Hanya admin atau kasir yang dapat memproses pesanan.'], 403);
        }
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        $input = readInput();
        $next = (string) ($input['status'] ?? '');
        if (!$id || !in_array($next, ['paying', 'processing', 'completed', 'cancelled'], true)) {
            respond(['error' => 'ID pesanan atau status tujuan tidak valid.'], 422);
        }
        $pdo->beginTransaction();
        try {
            $orderStmt = $pdo->prepare(
                'SELECT o.status, o.metode_pembayaran, t.id_pelanggan, t.total_belanja
                 FROM tbl_pesanan o
                 JOIN tbl_transaksi t ON t.id_transaksi = o.id_transaksi
                 WHERE o.id_pesanan = ? FOR UPDATE'
            );
            $orderStmt->execute([$id]);
            $order = $orderStmt->fetch();
            $transitions = [
                'pending' => ['paying', 'processing', 'cancelled'],
                'paying' => ['processing', 'cancelled'],
                'processing' => ['completed', 'cancelled'],
                'completed' => [],
                'cancelled' => [],
            ];
            if (!$order || !in_array($next, $transitions[$order['status']], true)) {
                throw new DomainException('Perubahan status pesanan tidak diizinkan.');
            }
            if ($next === 'cancelled') {
                $items = $pdo->prepare('SELECT id_produk, jumlah FROM tbl_detail_pesanan WHERE id_pesanan = ?');
                $items->execute([$id]);
                $restore = $pdo->prepare('UPDATE tbl_produk SET stok = stok + ? WHERE id_produk = ?');
                foreach ($items->fetchAll() as $item) {
                    $restore->execute([$item['jumlah'], $item['id_produk']]);
                }
                if ($order['metode_pembayaran'] === 'wallet' && (float) $order['total_belanja'] > 0) {
                    if ($order['id_pelanggan'] === null) {
                        throw new DomainException('Pesanan saldo tidak terhubung ke akun pelanggan.');
                    }
                    $wallet = ensureCustomerWallet($pdo, (int) $order['id_pelanggan'], true);
                    $refund = (float) $order['total_belanja'];
                    $walletUpdate = $pdo->prepare('UPDATE tbl_wallet SET saldo = saldo + ? WHERE id_wallet = ?');
                    $walletUpdate->execute([$refund, $wallet['id_wallet']]);
                    $balanceStmt = $pdo->prepare('SELECT saldo FROM tbl_wallet WHERE id_wallet = ?');
                    $balanceStmt->execute([$wallet['id_wallet']]);
                    $newBalance = (float) $balanceStmt->fetchColumn();
                    $ledger = $pdo->prepare(
                        "INSERT INTO tbl_wallet_ledger
                         (id_wallet, jenis, id_referensi, debit, kredit, saldo_setelah, keterangan)
                         VALUES (?, 'refund', ?, 0, ?, ?, ?)"
                    );
                    $ledger->execute([
                        $wallet['id_wallet'], $id, $refund, $newBalance, "Pengembalian pesanan #{$id}",
                    ]);
                }
            }
            $update = $pdo->prepare('UPDATE tbl_pesanan SET status = ? WHERE id_pesanan = ?');
            $update->execute([$next, $id]);
            $pdo->commit();
            respond(['message' => 'Status pesanan diperbarui.']);
        } catch (DomainException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            respond(['error' => $error->getMessage()], 409);
        } catch (Throwable $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $error;
        }
    }
}
