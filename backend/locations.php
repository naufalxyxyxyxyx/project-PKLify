<?php
// All location writes serialize on the student row, alongside attendance writes.
function locationVersion2($id) {
 return (int)(query2("SELECT MAX(id) FROM p2_location_requests WHERE siswa_id=? AND status='disetujui'",[$id])->fetchColumn()?:0);
}
function locationLock2($u,$id) {
 global $pdo;
 $pdo->beginTransaction();
 if(!query2("SELECT id FROM p2_users WHERE id=? AND role='siswa' FOR UPDATE",[$id])->fetch()) fail2('Siswa tidak ditemukan.',404);
 scope2($u,$id);
 $p=placement2($id);
 if(!$p) fail2('Admin perlu menetapkan guru pembimbing dan jadwal PKL terlebih dahulu.');
 return $p;
}
function locationPoint2($d) {
 $name=required2($d,'tempat',150); $address=required2($d,'alamat',500);
 foreach(['latitude','longitude'] as $key) {
  if(!isset($d[$key]) || !is_numeric($d[$key]) || !is_finite((float)$d[$key])) fail2('Isi koordinat berupa angka yang valid.');
 }
 $lat=(float)$d['latitude']; $lng=(float)$d['longitude'];
 if(abs($lat)>90 || abs($lng)>180) fail2('Koordinat di luar rentang yang valid.');
 return [$name,$address,$lat,$lng];
}
function locationSupersede2($id,$actor,$reason) {
 query2("UPDATE p2_location_requests SET status='digantikan',feedback=?,reviewed_by=?,reviewed_at=NOW() WHERE siswa_id=? AND status='menunggu'",[$reason,$actor,$id]);
}
function locationActivate2($u,$id,$r,$old) {
 query2('UPDATE p2_placements SET tempat=?,latitude=?,longitude=?,radius=40 WHERE siswa_id=?',[$r['tempat'],$r['latitude'],$r['longitude'],$id]);
 audit2($u,$id,'lokasi_diaktifkan',json_encode(['sebelum'=>['tempat'=>$old['tempat'],'latitude'=>$old['latitude'],'longitude'=>$old['longitude'],'radius'=>$old['radius']], 'sesudah'=>$r],JSON_UNESCAPED_UNICODE));
}
function handleLocation2($action,$d,$u) {
 global $pdo;
 if(!in_array($action,['location_request','location_review','location_set'],true)) return;
 if($action==='location_review') {
  role2($u,['guru']);
  $r=query2('SELECT * FROM p2_location_requests WHERE id=?',[$d['id']??0])->fetch();
  if(!$r) fail2('Pengajuan tidak ditemukan.',404);
  $p=locationLock2($u,$r['siswa_id']);
  $r=query2('SELECT * FROM p2_location_requests WHERE id=? FOR UPDATE',[$r['id']])->fetch();
  if($r['status']!=='menunggu') fail2('Pengajuan sudah diproses. Muat ulang.',409);
  if((int)$r['base_version']!==locationVersion2($r['siswa_id'])) fail2('Lokasi aktif sudah berubah. Muat ulang.',409);
  $status=$d['status']??'';
  if(!in_array($status,['disetujui','perlu_revisi'],true)) fail2('Keputusan lokasi tidak valid.');
  $feedback=required2($d,'feedback',2000);
  query2('UPDATE p2_location_requests SET status=?,feedback=?,reviewed_by=?,reviewed_at=NOW() WHERE id=?',[$status,$feedback,$u['id'],$r['id']]);
  if($status==='disetujui') locationActivate2($u,$r['siswa_id'],$r,$p);
  audit2($u,$r['siswa_id'],'pengajuan_lokasi_diperiksa','#'.$r['id'].' '.$status.': '.$feedback);
  $pdo->commit(); ok2();
 }
 role2($u,$action==='location_request'?['siswa']:['guru','admin']);
 $id=$action==='location_request'?(int)$u['id']:(int)($d['siswa_id']??0);
 [$name,$address,$lat,$lng]=locationPoint2($d);
 $reason=required2($d,'reason',2000);
 $p=locationLock2($u,$id);
 $version=locationVersion2($id);
 if(!isset($d['base_version']) || (string)$d['base_version']!==(string)$version) fail2('Data lokasi berubah. Muat ulang sebelum menyimpan.',409);
 if($action==='location_request' && query2("SELECT id FROM p2_location_requests WHERE siswa_id=? AND status='menunggu'",[$id])->fetch()) fail2('Masih ada pengajuan yang menunggu pemeriksaan guru.',409);
 $direct=$action==='location_set';
 if($direct) locationSupersede2($id,$u['id'],'Digantikan oleh penetapan lokasi baru: '.$reason);
 query2('INSERT INTO p2_location_requests(siswa_id,actor_id,tempat,alamat,latitude,longitude,reason,status,feedback,reviewed_by,created_at,reviewed_at,base_version) VALUES(?,?,?,?,?,?,?,?,?,?,NOW(),?,?)',[$id,$u['id'],$name,$address,$lat,$lng,$reason,$direct?'disetujui':'menunggu',$direct?$reason:'',$direct?$u['id']:null,$direct?date('Y-m-d H:i:s'):null,$version]);
 $requestId=(int)$pdo->lastInsertId();
 if($direct) locationActivate2($u,$id,['id'=>$requestId,'tempat'=>$name,'alamat'=>$address,'latitude'=>$lat,'longitude'=>$lng,'reason'=>$reason],$p);
 audit2($u,$id,$direct?'lokasi_ditetapkan':'lokasi_diajukan','#'.$requestId.': '.$name.' — '.$reason);
 $pdo->commit(); ok2(['id'=>$requestId]);
}
