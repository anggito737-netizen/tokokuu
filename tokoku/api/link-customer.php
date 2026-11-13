<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$customerId = filter_var(getenv('TOKOKU_CUSTOMER_ID') ?: null, FILTER_VALIDATE_INT);
$email = strtolower(trim((string) (getenv('TOKOKU_CUSTOMER_EMAIL') ?: '')));
$password = (string) (getenv('TOKOKU_CUSTOMER_PASSWORD') ?: '');

if (!$customerId || !filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 190 || strlen($password) < 12) {
    fwrite(STDERR, "Atur TOKOKU_CUSTOMER_ID, TOKOKU_CUSTOMER_EMAIL, dan TOKOKU_CUSTOMER_PASSWORD (minimal 12 karakter).\n");
    exit(1);
}

try {
    /** @var PDO $pdo */
    $pdo = require __DIR__ . '/../config/database.php';
    $customer = $pdo->prepare('SELECT nama_pelanggan FROM tbl_pelanggan WHERE id_pelanggan = ?');
    $customer->execute([$customerId]);
    $name = $customer->fetchColumn();
    if ($name === false) {
        fwrite(STDERR, "Pelanggan #{$customerId} tidak ditemukan.\n");
        exit(1);
    }

    $existing = $pdo->prepare('SELECT id_akun FROM tbl_akun WHERE id_pelanggan = ? OR email = ?');
    $existing->execute([$customerId, $email]);
    if ($existing->fetchColumn() !== false) {
        fwrite(STDERR, "Pelanggan sudah memiliki akun atau email sudah digunakan.\n");
        exit(1);
    }

    $account = $pdo->prepare(
        "INSERT INTO tbl_akun (email, password_hash, role, id_pelanggan) VALUES (?, ?, 'customer', ?)"
    );
    $account->execute([$email, password_hash($password, PASSWORD_DEFAULT), $customerId]);
    fwrite(STDOUT, "Akun pelanggan #{$customerId} ({$name}) berhasil ditautkan ke {$email}.\n");
} catch (Throwable $error) {
    fwrite(STDERR, "Penautan akun pelanggan gagal: {$error->getMessage()}\n");
    exit(1);
}
