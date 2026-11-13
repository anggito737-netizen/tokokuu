<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$email = strtolower(trim((string) (getenv('TOKOKU_ADMIN_EMAIL') ?: '')));
$password = (string) (getenv('TOKOKU_ADMIN_PASSWORD') ?: '');

if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 190 || strlen($password) < 12) {
    fwrite(STDERR, "Atur TOKOKU_ADMIN_EMAIL dan TOKOKU_ADMIN_PASSWORD (minimal 12 karakter) di environment, lalu jalankan ulang.\n");
    exit(1);
}

try {
    /** @var PDO $pdo */
    $pdo = require __DIR__ . '/../config/database.php';
    if ((int) $pdo->query("SELECT COUNT(*) FROM tbl_akun WHERE role = 'admin'")->fetchColumn() > 0) {
        fwrite(STDERR, "Akun admin sudah tersedia; provisioning awal ditolak.\n");
        exit(1);
    }

    $stmt = $pdo->prepare(
        "INSERT INTO tbl_akun (email, password_hash, role, id_pelanggan) VALUES (?, ?, 'admin', NULL)"
    );
    $stmt->execute([$email, password_hash($password, PASSWORD_DEFAULT)]);
    fwrite(STDOUT, "Akun admin berhasil dibuat untuk {$email}.\n");
} catch (Throwable $error) {
    fwrite(STDERR, "Provisioning admin gagal: {$error->getMessage()}\n");
    exit(1);
}
