<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$email = strtolower(trim((string) (getenv('TOKOKU_CASHIER_EMAIL') ?: '')));
$password = (string) (getenv('TOKOKU_CASHIER_PASSWORD') ?: '');
if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 190 || strlen($password) < 12) {
    fwrite(STDERR, "Atur TOKOKU_CASHIER_EMAIL dan TOKOKU_CASHIER_PASSWORD (minimal 12 karakter).\n");
    exit(1);
}

try {
    /** @var PDO $pdo */
    $pdo = require __DIR__ . '/../config/database.php';
    if ((int) $pdo->query("SELECT COUNT(*) FROM tbl_akun WHERE role = 'admin'")->fetchColumn() === 0) {
        fwrite(STDERR, "Buat akun admin terlebih dahulu.\n");
        exit(1);
    }
    $stmt = $pdo->prepare(
        "INSERT INTO tbl_akun (email, password_hash, role, id_pelanggan) VALUES (?, ?, 'cashier', NULL)"
    );
    $stmt->execute([$email, password_hash($password, PASSWORD_DEFAULT)]);
    fwrite(STDOUT, "Akun kasir berhasil dibuat untuk {$email}.\n");
} catch (Throwable $error) {
    fwrite(STDERR, "Pembuatan akun kasir gagal: {$error->getMessage()}\n");
    exit(1);
}
