<?php
// Idempotent additive schema migration; no seed accounts or existing data updates.
if(PHP_SAPI!=='cli') { http_response_code(404); exit; }
require __DIR__.'/config.php';
$pdo->exec(file_get_contents(__DIR__.'/schema_v2.sql'));
echo "Tabel pengajuan lokasi siap. Data lama dipertahankan.\n";
