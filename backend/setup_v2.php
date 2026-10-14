<?php
// Run only with PHP CLI. Existing tables and accounts are never deleted.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require __DIR__ . '/config.php';
$pdo->exec(file_get_contents(__DIR__ . '/schema_v2.sql'));
$accounts = [
 ['Admin PKLify','admin','admin','AdminPkl!2026'],
 ['Guru Percobaan','guru','198701012026101301','GuruPkl!2026'],
 ['Siswa Percobaan','siswa','2026101301','SiswaPkl!2026'],
];
foreach ($accounts as $a) {
 $q=$pdo->prepare('INSERT IGNORE INTO p2_users(nama,role,identity,password) VALUES(?,?,?,?)');
 $q->execute([$a[0],$a[1],$a[2],password_hash($a[3],PASSWORD_DEFAULT)]);
}
$guru=$pdo->query("SELECT id FROM p2_users WHERE identity='198701012026101301'")->fetchColumn();
$siswa=$pdo->query("SELECT id FROM p2_users WHERE identity='2026101301'")->fetchColumn();
$q=$pdo->prepare('INSERT IGNORE INTO p2_placements(siswa_id,guru_id,tempat,start_date,end_date,holidays) VALUES(?,?,?,?,?,?)');
$q->execute([$siswa,$guru,'Belum ditentukan',date('Y-m-d'),date('Y-m-d',strtotime('+90 days')),'']);
echo "Setup selesai. Akun lama dan aktivitas lama dipertahankan.\n";
