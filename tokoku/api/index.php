<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

ini_set('session.use_strict_mode', '1');
session_set_cookie_params([
    'httponly' => true,
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'samesite' => 'Lax',
    'path' => '/',
]);
session_start();

function respond(array $data, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function readInput(): array
{
    $data = json_decode((string) file_get_contents('php://input'), true);
    return is_array($data) ? $data : [];
}

function csrfToken(): string
{
    if (!isset($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function requireRole(array|null $user, string $role): void
{
    if (!$user) {
        respond(['error' => 'Silakan masuk terlebih dahulu.'], 401);
    }
    if ($user['role'] !== $role) {
        respond(['error' => 'Anda tidak memiliki akses ke fitur ini.'], 403);
    }
}

function drain(PDOStatement $statement): void
{
    do {
        $statement->fetchAll();
    } while ($statement->nextRowset());
    $statement->closeCursor();
}

try {
    /** @var PDO $pdo */
    $pdo = require __DIR__ . '/../config/database.php';
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $route = trim((string) ($_GET['route'] ?? ''), '/');
    $user = $_SESSION['user'] ?? null;

    if (in_array($method, ['POST', 'PUT', 'DELETE'], true)) {
        $token = (string) ($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
        if ($token === '' || !hash_equals(csrfToken(), $token)) {
            respond(['error' => 'Sesi keamanan tidak valid. Muat ulang halaman dan coba lagi.'], 419);
        }
    }

    if ($method === 'GET' && $route === 'auth/session') {
        $profile = null;
        if ($user && $user['role'] === 'customer') {
            $stmt = $pdo->prepare(
                'SELECT nama_pelanggan, kota FROM tbl_pelanggan WHERE id_pelanggan = ?'
            );
            $stmt->execute([$user['id_pelanggan']]);
            $profile = $stmt->fetch();
            if (!$profile) {
                $_SESSION = [];
                session_regenerate_id(true);
                $user = null;
            }
        }
        respond(['authenticated' => (bool) $user, 'user' => $user ? [
            'email' => $user['email'],
            'role' => $user['role'],
            'id_pelanggan' => $user['id_pelanggan'] ?? null,
            'nama' => $profile['nama_pelanggan'] ?? $user['email'],
        ] : null, 'csrf_token' => csrfToken()]);
    }

    if ($method === 'POST' && $route === 'auth/login') {
        $input = readInput();
        $email = mb_strtolower(trim((string) ($input['email'] ?? '')));
        $password = (string) ($input['password'] ?? '');
        $role = (string) ($input['role'] ?? '');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !in_array($role, ['admin', 'cashier', 'customer'], true)) {
            respond(['error' => 'Email, kata sandi, atau jenis akun tidak sesuai.'], 422);
        }
        $stmt = $pdo->prepare('SELECT id_akun, email, password_hash, role, id_pelanggan FROM tbl_akun WHERE email = ?');
        $stmt->execute([$email]);
        $account = $stmt->fetch();
        if (!$account || $account['role'] !== $role || !password_verify($password, $account['password_hash'])) {
            respond(['error' => 'Email, kata sandi, atau jenis akun tidak sesuai.'], 401);
        }
        session_regenerate_id(true);
        $_SESSION['user'] = [
            'id_akun' => (int) $account['id_akun'],
            'email' => $account['email'],
            'role' => $account['role'],
            'id_pelanggan' => $account['id_pelanggan'] !== null ? (int) $account['id_pelanggan'] : null,
        ];
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        respond(['message' => 'Berhasil masuk.', 'user' => $_SESSION['user'], 'csrf_token' => $_SESSION['csrf_token']]);
    }

    if ($method === 'POST' && $route === 'auth/register') {
        $input = readInput();
        $name = trim((string) ($input['nama'] ?? ''));
        $city = trim((string) ($input['kota'] ?? ''));
        $email = mb_strtolower(trim((string) ($input['email'] ?? '')));
        $password = (string) ($input['password'] ?? '');
        if ($name === '' || mb_strlen($name) > 100 || mb_strlen($city) > 50
            || !filter_var($email, FILTER_VALIDATE_EMAIL) || mb_strlen($email) > 190
            || strlen($password) < 10 || strlen($password) > 4096) {
            respond(['error' => 'Isi nama, email valid, kota (maks. 50 karakter), dan kata sandi minimal 10 karakter.'], 422);
        }
        try {
            $pdo->beginTransaction();
            $customerStmt = $pdo->prepare('INSERT INTO tbl_pelanggan (nama_pelanggan, kota) VALUES (?, ?)');
            $customerStmt->execute([$name, $city]);
            $customerId = (int) $pdo->lastInsertId();
            $accountStmt = $pdo->prepare(
                'INSERT INTO tbl_akun (email, password_hash, role, id_pelanggan) VALUES (?, ?, ?, ?)'
            );
            $accountStmt->execute([$email, password_hash($password, PASSWORD_DEFAULT), 'customer', $customerId]);
            $accountId = (int) $pdo->lastInsertId();
            $pdo->commit();
        } catch (PDOException $error) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if ($error->getCode() === '23000') {
                respond(['error' => 'Email tersebut sudah terdaftar. Silakan masuk atau gunakan email lain.'], 409);
            }
            throw $error;
        }
        session_regenerate_id(true);
        $_SESSION['user'] = [
            'id_akun' => $accountId,
            'email' => $email,
            'role' => 'customer',
            'id_pelanggan' => $customerId,
        ];
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        respond(['message' => 'Akun pelanggan berhasil dibuat.', 'user' => $_SESSION['user'], 'csrf_token' => $_SESSION['csrf_token']], 201);
    }

    if ($method === 'POST' && $route === 'auth/logout') {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', [
                'expires' => time() - 42000,
                'path' => $params['path'],
                'domain' => $params['domain'],
                'secure' => $params['secure'],
                'httponly' => $params['httponly'],
                'samesite' => $params['samesite'] ?? 'Lax',
            ]);
        }
        session_destroy();
        respond(['message' => 'Anda berhasil keluar.']);
    }

    if (!$user) {
        respond(['error' => 'Silakan masuk terlebih dahulu.'], 401);
    }

    require __DIR__ . '/store.php';
    handleStoreRoute($pdo, $method, $route, $user);

    if ($user['role'] === 'cashier' && !in_array($route, ['products', 'calculate-cart', 'checkout', 'orders', 'order-detail', 'order-status'], true)) {
        respond(['error' => 'Anda tidak memiliki akses ke fitur ini.'], 403);
    }

    if ($user['role'] === 'customer') {
        if ($method === 'GET' && $route === 'my-profile') {
            $stmt = $pdo->prepare(
                'SELECT p.id_pelanggan, p.nama_pelanggan AS nama, p.kota, a.email,
                        KategoriBelanja(COALESCE(v.total_keseluruhan_belanja, 0)) AS kategori
                 FROM tbl_akun a JOIN tbl_pelanggan p ON p.id_pelanggan = a.id_pelanggan
                 LEFT JOIN view_total_belanja_pelanggan v ON v.id_pelanggan = p.id_pelanggan
                 WHERE a.id_akun = ?'
            );
            $stmt->execute([$user['id_akun']]);
            $profile = $stmt->fetch();
            if (!$profile) {
                respond(['error' => 'Profil pelanggan tidak ditemukan.'], 404);
            }
            respond(['data' => $profile]);
        } else {
            respond(['error' => 'Anda tidak memiliki akses ke fitur ini.'], 403);
        }
    } elseif ($user['role'] === 'admin') {
        requireRole($user, 'admin');
    }

    if ($method === 'GET' && $route === 'dashboard') {
        $stmt = $pdo->query('CALL HitungPelanggan(@jumlah)');
        drain($stmt);
        $customerCount = (int) $pdo->query('SELECT @jumlah')->fetchColumn();
        $metrics = $pdo->query(
            'SELECT COUNT(*) AS total_transaksi, COALESCE(SUM(total_belanja), 0) AS total_belanja
             FROM tbl_transaksi'
        )->fetch();
        $sales = $pdo->query(
            'SELECT tanggal, SUM(total_belanja) AS total
             FROM tbl_transaksi
             WHERE tanggal >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
             GROUP BY tanggal
             ORDER BY tanggal'
        )->fetchAll();
        respond([
            'metrics' => [
                'total_transaksi' => (int) $metrics['total_transaksi'],
                'total_pelanggan' => $customerCount,
                'total_belanja' => (float) $metrics['total_belanja'],
            ],
            'sales' => $sales,
        ]);
    }

    if ($method === 'GET' && $route === 'customers') {
        $search = trim((string) ($_GET['q'] ?? ''));
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $limit = min(50, max(5, (int) ($_GET['limit'] ?? 10)));
        $where = $search === '' ? '' : ' WHERE v.nama_pelanggan LIKE :q_name OR p.kota LIKE :q_city';
        $from = ' FROM view_total_belanja_pelanggan v
                  LEFT JOIN tbl_pelanggan p ON p.id_pelanggan = v.id_pelanggan';
        $countStmt = $pdo->prepare('SELECT COUNT(*)' . $from . $where);
        if ($search !== '') {
            $countStmt->bindValue(':q_name', '%' . $search . '%');
            $countStmt->bindValue(':q_city', '%' . $search . '%');
        }
        $countStmt->execute();
        $total = (int) $countStmt->fetchColumn();

        $sql = 'SELECT v.id_pelanggan, v.nama_pelanggan AS nama, p.kota,
                       v.total_keseluruhan_belanja AS total_belanja, v.jumlah_transaksi,
                       KategoriBelanja(v.total_keseluruhan_belanja) AS kategori' .
                $from . $where . '
                ORDER BY v.id_pelanggan DESC LIMIT :limit OFFSET :offset';
        $stmt = $pdo->prepare($sql);
        if ($search !== '') {
            $stmt->bindValue(':q_name', '%' . $search . '%');
            $stmt->bindValue(':q_city', '%' . $search . '%');
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', ($page - 1) * $limit, PDO::PARAM_INT);
        $stmt->execute();
        respond(['data' => $stmt->fetchAll(), 'pagination' => [
            'page' => $page, 'limit' => $limit, 'total' => $total,
            'pages' => max(1, (int) ceil($total / $limit)),
        ]]);
    }

    if ($method === 'GET' && $route === 'customer-detail') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) {
            respond(['error' => 'ID pelanggan tidak valid.'], 422);
        }
        $stmt = $pdo->prepare('CALL CariPelanggan(?)');
        $stmt->execute([$id]);
        $customer = $stmt->fetch();
        drain($stmt);
        if (!$customer) {
            respond(['error' => 'Pelanggan tidak ditemukan.'], 404);
        }
        respond(['data' => $customer]);
    }

    if ($method === 'GET' && $route === 'customers-all') {
        $stmt = $pdo->query('CALL TampilPelanggan()');
        $rows = $stmt->fetchAll();
        drain($stmt);
        respond(['data' => $rows]);
    }

    if ($route === 'customers' && $method === 'POST') {
        $input = readInput();
        $name = trim((string) ($input['nama'] ?? ''));
        $city = trim((string) ($input['kota'] ?? ''));
        if ($name === '' || mb_strlen($name) > 100 || mb_strlen($city) > 50) {
            respond(['error' => 'Nama wajib diisi (maks. 100 karakter); kota maks. 50 karakter.'], 422);
        }
        $stmt = $pdo->prepare('CALL TambahPelanggan(:nama, :kota)');
        $stmt->execute(['nama' => $name, 'kota' => $city]);
        drain($stmt);
        $id = (int) $pdo->query('SELECT LAST_INSERT_ID()')->fetchColumn();
        respond(['message' => 'Pelanggan berhasil ditambahkan.', 'id_pelanggan' => $id], 201);
    }

    if ($route === 'customers' && $method === 'PUT') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        $input = readInput();
        $name = trim((string) ($input['nama'] ?? ''));
        $city = trim((string) ($input['kota'] ?? ''));
        if (!$id || $name === '' || mb_strlen($name) > 100 || mb_strlen($city) > 50) {
            respond(['error' => 'ID dan nama pelanggan valid wajib diisi; kota maks. 50 karakter.'], 422);
        }
        $stmt = $pdo->prepare('UPDATE tbl_pelanggan SET nama_pelanggan = :nama, kota = :kota WHERE id_pelanggan = :id');
        $stmt->execute(['nama' => $name, 'kota' => $city, 'id' => $id]);
        if ($stmt->rowCount() === 0 && !$pdo->query('SELECT 1 FROM tbl_pelanggan WHERE id_pelanggan = ' . (int) $id)->fetchColumn()) {
            respond(['error' => 'Pelanggan tidak ditemukan.'], 404);
        }
        respond(['message' => 'Data pelanggan berhasil diperbarui.']);
    }

    if ($route === 'customers' && $method === 'DELETE') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) {
            respond(['error' => 'ID pelanggan tidak valid.'], 422);
        }
        $pdo->beginTransaction();
        $customerStmt = $pdo->prepare('SELECT nama_pelanggan, kota FROM tbl_pelanggan WHERE id_pelanggan = ? FOR UPDATE');
        $customerStmt->execute([$id]);
        $customer = $customerStmt->fetch();
        if (!$customer) {
            $pdo->rollBack();
            respond(['error' => 'Pelanggan tidak ditemukan.'], 404);
        }
        $historyStmt = $pdo->prepare('SELECT COUNT(*) FROM tbl_transaksi WHERE id_pelanggan = ?');
        $historyStmt->execute([$id]);
        if ((int) $historyStmt->fetchColumn() > 0) {
            $pdo->rollBack();
            respond(['error' => 'Pelanggan memiliki histori transaksi dan tidak dapat dihapus. Ubah data pelanggan jika diperlukan.'], 409);
        }
        $walletHistoryStmt = $pdo->prepare(
            'SELECT (w.saldo > 0) OR EXISTS (
                       SELECT 1 FROM tbl_wallet_topup t WHERE t.id_wallet = w.id_wallet
                   )
             FROM tbl_wallet w WHERE w.id_pelanggan = ?'
        );
        $walletHistoryStmt->execute([$id]);
        if ((int) $walletHistoryStmt->fetchColumn() === 1) {
            $pdo->rollBack();
            respond(['error' => 'Pelanggan memiliki saldo atau histori top up dan tidak dapat dihapus.'], 409);
        }
        $stmt = $pdo->prepare('DELETE FROM tbl_pelanggan WHERE id_pelanggan = ?');
        $stmt->execute([$id]);
        $log = $pdo->prepare('INSERT INTO log_pelanggan (aktivitas, id_pelanggan) VALUES (?, ?)');
        $log->execute(['DELETE PELANGGAN', $id]);
        $changeLog = $pdo->prepare(
            'INSERT INTO log_perubahan_pelanggan (id_pelanggan, nama_lama, nama_baru) VALUES (?, ?, NULL)'
        );
        $changeLog->execute([$id, $customer['nama_pelanggan']]);
        $pdo->commit();
        respond(['message' => 'Pelanggan berhasil dihapus.']);
    }

    if ($method === 'GET' && $route === 'transactions') {
        $from = trim((string) ($_GET['from'] ?? ''));
        $to = trim((string) ($_GET['to'] ?? ''));
        $page = max(1, (int) ($_GET['page'] ?? 1));
        $limit = min(100, max(5, (int) ($_GET['limit'] ?? 10)));
        $conditions = [];
        $params = [];
        if ($from !== '') {
            $conditions[] = 'tanggal >= :from_date';
            $params['from_date'] = $from . ' 00:00:00';
        }
        if ($to !== '') {
            $conditions[] = 'tanggal < DATE_ADD(:to_date, INTERVAL 1 DAY)';
            $params['to_date'] = $to;
        }
        $where = $conditions ? ' WHERE ' . implode(' AND ', $conditions) : '';
        $source = '(SELECT id_transaksi, tanggal, nama_pelanggan, kota, total_belanja
                    FROM view_laporan_transaksi
                    UNION ALL
                    SELECT t.id_transaksi, t.tanggal, NULL AS nama_pelanggan,
                           NULL AS kota, t.total_belanja
                    FROM tbl_transaksi t
                    WHERE t.id_pelanggan IS NULL) laporan';
        $count = $pdo->prepare('SELECT COUNT(*) FROM ' . $source . $where);
        $count->execute($params);
        $total = (int) $count->fetchColumn();
        $aggregate = $pdo->prepare(
            'SELECT COALESCE(SUM(total_belanja), 0) AS total_belanja,
                    COALESCE(AVG(total_belanja), 0) AS rata_rata
             FROM ' . $source . $where
        );
        $aggregate->execute($params);
        $summary = $aggregate->fetch();
        $stmt = $pdo->prepare('SELECT * FROM ' . $source . $where .
            ' ORDER BY tanggal DESC LIMIT :limit OFFSET :offset');
        foreach ($params as $key => $value) {
            $stmt->bindValue(':' . $key, $value);
        }
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', ($page - 1) * $limit, PDO::PARAM_INT);
        $stmt->execute();
        respond(['data' => $stmt->fetchAll(), 'summary' => [
            'total_belanja' => (float) $summary['total_belanja'],
            'rata_rata' => (float) $summary['rata_rata'],
        ], 'pagination' => [
            'page' => $page, 'limit' => $limit, 'total' => $total,
            'pages' => max(1, (int) ceil($total / $limit)),
        ]]);
    }

    if ($method === 'GET' && $route === 'customer-transactions') {
        $id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
        if (!$id) {
            respond(['error' => 'ID pelanggan tidak valid.'], 422);
        }
        $stmt = $pdo->prepare('CALL LaporanTransaksi(?)');
        $stmt->execute([$id]);
        $rows = $stmt->fetchAll();
        drain($stmt);
        respond(['data' => $rows]);
    }

    if ($method === 'GET' && $route === 'convert-grade') {
        $value = filter_var($_GET['nilai'] ?? null, FILTER_VALIDATE_INT);
        if ($value === false || $value < 0 || $value > 100) {
            respond(['error' => 'Nilai harus berupa angka 0–100.'], 422);
        }
        $stmt = $pdo->prepare('SELECT KonversiNilai(?)');
        $stmt->execute([$value]);
        respond(['nilai' => $value, 'konversi' => $stmt->fetchColumn()]);
    }

    if ($method === 'GET' && $route === 'logs') {
        $limit = min(100, max(10, (int) ($_GET['limit'] ?? 30)));
        $stmt = $pdo->prepare(
            "SELECT id_log, id_pelanggan,
                    CASE WHEN aktivitas LIKE 'INSERT%' THEN 'INSERT'
                         WHEN aktivitas LIKE 'UPDATE%' THEN 'UPDATE'
                         WHEN aktivitas LIKE 'DELETE%' THEN 'DELETE'
                         ELSE aktivitas END AS aksi,
                    NULL AS nama_lama, NULL AS nama_baru,
                    waktu AS waktu_log, 'pelanggan' AS sumber
             FROM log_pelanggan
             UNION ALL
             SELECT id_log, id_pelanggan, 'UPDATE' AS aksi, nama_lama, nama_baru,
                    waktu AS waktu_log, 'perubahan' AS sumber
             FROM log_perubahan_pelanggan
             ORDER BY waktu_log DESC LIMIT :limit"
        );
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        respond(['data' => $stmt->fetchAll()]);
    }

    respond(['error' => 'Endpoint tidak ditemukan.'], 404);
} catch (PDOException $error) {
    $message = $error->getMessage();
    error_log('Tokoku database error: ' . $message);
    $isValidation = str_contains($message, 'tidak boleh bernilai negatif')
        || str_contains($message, 'tidak boleh negatif');
    respond(['error' => $isValidation ? $message : 'Terjadi kesalahan database. Periksa koneksi dan struktur db_tokoku.'], $isValidation ? 422 : 500);
} catch (Throwable $error) {
    error_log('Tokoku API error: ' . $error->getMessage());
    respond(['error' => 'Permintaan gagal diproses.'], 500);
}
