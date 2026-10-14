<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Cache-Control: no-store');
date_default_timezone_set('Asia/Jakarta');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }

$host = 'localhost';
$port = '3307';
$db = getenv('PKLIFY_DB') ?: 'pklify_db';
$user = 'root';
$pass = '';

try {
  $pdo = new PDO("mysql:host=$host;port=$port;dbname=$db;charset=utf8mb4", $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
  http_response_code(500);
  echo json_encode(['success' => false, 'message' => 'Koneksi database gagal. Pastikan MySQL aktif dan database pklify_db sudah diimpor.']);
  exit;
}

function body() { return json_decode(file_get_contents('php://input'), true) ?? $_POST; }
function reply($data, $code = 200) { http_response_code($code); echo json_encode($data); exit; }
