<?php
require __DIR__ . '/config.php';
$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
$pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
$pdo->exec("SET time_zone = '+07:00'");
function query2($sql,$args=[]) { global $pdo; $q=$pdo->prepare($sql); $q->execute($args); return $q; }
function fail2($message,$code=422) { reply(['success'=>false,'message'=>$message],$code); }
function ok2($data=[]) { reply(['success'=>true]+$data); }
function required2($d,$key,$max=10000) {
 $v=trim((string)($d[$key]??'')); if($v==='' || strlen($v)>$max) fail2("Isi $key dengan benar."); return $v;
}
function date2($v) { $d=DateTime::createFromFormat('!Y-m-d',(string)$v); if(!$d || $d->format('Y-m-d')!==$v) fail2('Tanggal tidak valid.'); return $v; }
function audit2($u,$student,$action,$detail) { query2('INSERT INTO p2_audit(actor_id,siswa_id,action,detail,created_at) VALUES(?,?,?,?,NOW())',[$u['id'],$student,$action,$detail]); }
function scope2($u,$id) {
 if($u['role']==='admin') return;
 if($u['role']==='siswa' && (int)$u['id']===(int)$id) return;
 if($u['role']==='guru' && query2('SELECT siswa_id FROM p2_placements WHERE siswa_id=? AND guru_id=?',[$id,$u['id']])->fetch()) return;
 fail2('Anda tidak memiliki akses ke siswa ini.',403);
}
function role2($u,$roles) { if(!in_array($u['role'],$roles,true)) fail2('Akses ditolak.',403); }
function placement2($id) { return query2('SELECT p.*,u.nama AS guru FROM p2_placements p JOIN p2_users u ON u.id=p.guru_id WHERE siswa_id=?',[$id])->fetch() ?: null; }
require_once __DIR__ . '/calendar.php';
function file2($photos=false,$required=false) {
 if(!isset($_FILES['file']) || $_FILES['file']['error']===UPLOAD_ERR_NO_FILE) { if($required) fail2('Foto atau lampiran wajib diunggah.'); return [null,null,null]; }
 $f=$_FILES['file']; if($f['error']!==UPLOAD_ERR_OK) fail2('Unggah gagal. Batas server mungkin terlampaui.');
 if($f['size']>5*1024*1024 || $f['size']<1) fail2('Ukuran file harus 1 byte sampai 5 MB.');
 $mime=(new finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);
 $ext=strtolower(pathinfo($f['name'],PATHINFO_EXTENSION));
 $allowed=['jpg'=>['image/jpeg'],'jpeg'=>['image/jpeg'],'png'=>['image/png'],'webp'=>['image/webp']];
 if(!$photos) $allowed+=['pdf'=>['application/pdf'],'doc'=>['application/msword','application/x-ole-storage','application/CDFV2'],'docx'=>['application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/zip']];
 if(!isset($allowed[$ext]) || !in_array($mime,$allowed[$ext],true)) fail2('Jenis file tidak didukung atau isi file tidak sesuai.');
 if(strpos($mime,'image/')===0 && !@getimagesize($f['tmp_name'])) fail2('Foto rusak.');
 $name=bin2hex(random_bytes(24)).'.'.$ext;
 if(!move_uploaded_file($f['tmp_name'],__DIR__.'/private_uploads/'.$name)) fail2('File gagal disimpan.',500);
 return [$name,basename($f['name']),$mime];
}
function distance2($a,$b,$c,$d) { $r=sin(deg2rad($c-$a)/2)**2+cos(deg2rad($a))*cos(deg2rad($c))*sin(deg2rad($d-$b)/2)**2; return 6371000*2*atan2(sqrt($r),sqrt(max(0,1-$r))); }
$savedFile=null;
try {
 $action=$_GET['action']??''; $d=body();
 if($action==='download') {
  $a=query2('SELECT a.* FROM p2_downloads t JOIN p2_activities a ON a.id=t.activity_id WHERE t.ticket=? AND t.expires_at>NOW()',[$_GET['ticket']??''])->fetch();
  if(!$a || !$a['file_name']) fail2('Tautan kedaluwarsa.',403);
  header('Content-Type: '.$a['mime']); header('X-Content-Type-Options: nosniff');
  header("Content-Disposition: attachment; filename*=UTF-8''".rawurlencode($a['original_name'])); readfile(__DIR__.'/private_uploads/'.$a['file_name']); exit;
 }
 if(($_SERVER['REQUEST_METHOD']??'')!=='POST') fail2('Gunakan POST.',405);
 if($action==='login') {
  $u=query2('SELECT * FROM p2_users WHERE identity=? AND role=?',[trim($d['identity']??''),$d['role']??''])->fetch();
  if(!$u || !password_verify($d['password']??'',$u['password'])) fail2('NIS/NIP atau kata sandi salah.',401);
  $token=bin2hex(random_bytes(32)); query2('INSERT INTO p2_sessions VALUES(?,?,DATE_ADD(NOW(),INTERVAL 12 HOUR))',[hash('sha256',$token),$u['id']]);
  unset($u['password']); ok2(['user'=>$u,'token'=>$token]);
 }
 $headers=array_change_key_case(function_exists('getallheaders')?getallheaders():[],CASE_LOWER);
 $auth=$_SERVER['HTTP_AUTHORIZATION']??($headers['authorization']??'');
 $token=preg_replace('/^Bearer /','',$auth);
 $u=query2('SELECT u.id,u.nama,u.role,u.identity FROM p2_sessions s JOIN p2_users u ON u.id=s.user_id WHERE s.token=? AND s.expires_at>NOW()',[hash('sha256',$token)])->fetch();
 if(!$u) fail2('Sesi berakhir. Silakan login kembali.',401);
 if($action==='logout') { query2('DELETE FROM p2_sessions WHERE token=?',[hash('sha256',$token)]); ok2(); }
 if($action==='overview') {
  $students=$u['role']==='siswa'?[$u]:query2('SELECT u.id,u.nama,u.identity,u.role FROM p2_users u '.($u['role']==='guru'?'JOIN p2_placements p ON p.siswa_id=u.id WHERE p.guru_id=?':"WHERE u.role='siswa'").' ORDER BY u.nama',$u['role']==='guru'?[$u['id']]:[])->fetchAll();
  $result=[]; $placements=[]; $activityGroups=[]; $grades=[];
  $ids=array_column($students,'id');
  if($ids) {
   // IDs come only from the authenticated user's allowed student list.
   $marks=implode(',',array_fill(0,count($ids),'?'));
   foreach(query2("SELECT p.*,u.nama AS guru FROM p2_placements p JOIN p2_users u ON u.id=p.guru_id WHERE siswa_id IN ($marks)",$ids) as $p) $placements[$p['siswa_id']]=$p;
   foreach(query2("SELECT * FROM p2_activities WHERE siswa_id IN ($marks) ORDER BY created_at DESC,id DESC",$ids) as $a) {
    $a['has_file']=$a['file_name']!==null; unset($a['file_name']);
    $activityGroups[$a['siswa_id']][]=$a;
   }
   foreach(query2("SELECT * FROM p2_grades WHERE siswa_id IN ($marks)",$ids) as $g) $grades[$g['siswa_id']]=$g;
  }
  foreach($students as $s) {
   $p=$placements[$s['id']]??null;
   $acts=$activityGroups[$s['id']]??[];
   $cal=calendar2($s['id'],$p,$acts);
   $grade=$grades[$s['id']]??null;
   if($u['role']==='siswa' && $grade && !$grade['published_at']) $grade=null;
   $result[]=['user'=>$s,'placement'=>$p,'activities'=>$acts,'calendar'=>$cal,'attendance_score'=>attendanceScore2($cal),'grade'=>$grade,'audit'=>query2('SELECT a.action,a.detail,a.created_at,u.nama FROM p2_audit a JOIN p2_users u ON u.id=a.actor_id WHERE siswa_id=? ORDER BY a.id DESC LIMIT 100',[$s['id']])->fetchAll()];
  }
  ok2(['user'=>$u,'students'=>$result,'teachers'=>$u['role']==='admin'?query2("SELECT id,nama,identity FROM p2_users WHERE role='guru'")->fetchAll():[],'server_time'=>date(DATE_ATOM)]);
 }
 if($action==='create_user') {
  role2($u,['admin']); $role=$d['role']??''; if(!in_array($role,['siswa','guru'],true)) fail2('Peran tidak valid.');
  $pw=required2($d,'password',128); if(strlen($pw)<8) fail2('Kata sandi minimal 8 karakter.');
  query2('INSERT INTO p2_users(nama,role,identity,password) VALUES(?,?,?,?)',[required2($d,'nama',100),$role,required2($d,'identity',40),password_hash($pw,PASSWORD_DEFAULT)]);
  audit2($u,null,'akun_dibuat',$role.' '.$d['identity']); ok2();
 }
 if($action==='placement') {
  role2($u,['admin']); $id=(int)($d['siswa_id']??0); $guru=(int)($d['guru_id']??0);
  if(!query2("SELECT id FROM p2_users WHERE id=? AND role='siswa'",[$id])->fetch() || !query2("SELECT id FROM p2_users WHERE id=? AND role='guru'",[$guru])->fetch()) fail2('Siswa atau guru tidak valid.');
  $start=date2($d['start_date']??''); $end=date2($d['end_date']??'');
  if($end<$start || strtotime($end)-strtotime($start)>366*86400*2) fail2('Periode harus berurutan dan maksimal dua tahun.');
  $days=required2($d,'work_days',20); if(!preg_match('/^[1-7](,[1-7])*$/',$days)) fail2('Hari kerja: 1=Senin sampai 7=Minggu, pisahkan koma.');
  $st=$d['start_time']??''; $et=$d['end_time']??'';
  if(!preg_match('/^([01]\d|2[0-3]):[0-5]\d$/',$st) || !preg_match('/^([01]\d|2[0-3]):[0-5]\d$/',$et) || $st>=$et) fail2('Jam masuk/pulang tidak valid.');
  $lat=($d['latitude']??'')===''?null:filter_var($d['latitude'],FILTER_VALIDATE_FLOAT);
  $lng=($d['longitude']??'')===''?null:filter_var($d['longitude'],FILTER_VALIDATE_FLOAT);
  if(($lat===null)!==($lng===null) || $lat===false || $lng===false || ($lat!==null && (abs($lat)>90 || abs($lng)>180))) fail2('Koordinat tidak valid.');
  $radius=filter_var($d['radius']??40,FILTER_VALIDATE_INT); if($radius<1 || $radius>1000) fail2('Radius harus 1–1000 meter.');
  $holidays=trim($d['holidays']??''); if($holidays!=='') foreach(preg_split('/[\s,]+/',$holidays) as $h) date2($h);
  $pdo->beginTransaction();
  query2('INSERT INTO p2_placements VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE guru_id=VALUES(guru_id),tempat=VALUES(tempat),latitude=VALUES(latitude),longitude=VALUES(longitude),radius=VALUES(radius),start_date=VALUES(start_date),end_date=VALUES(end_date),work_days=VALUES(work_days),start_time=VALUES(start_time),end_time=VALUES(end_time),holidays=VALUES(holidays)',[$id,$guru,required2($d,'tempat',150),$lat,$lng,$radius,$start,$end,$days,$st,$et,$holidays]);
  query2('UPDATE p2_grades SET published_at=NULL WHERE siswa_id=?',[$id]);
  audit2($u,$id,'penempatan_diubah',json_encode($d)); $pdo->commit(); ok2();
 }
 if($action==='activity') {
  role2($u,['siswa']); $id=$u['id']; $kind=$d['kind']??'';
  if(!in_array($kind,['jurnal','izin','masuk','pulang','dokumentasi'],true)) fail2('Jenis aktivitas salah.');
  $p=placement2($id); if(!$p) fail2('Admin belum mengatur penempatan PKL Anda.');
  $date=date2($d['tanggal']??date('Y-m-d')); $end=null; $lat=null;$lng=null;$acc=null;$dist=null; $status='menunggu';
  $title=required2($d,'title',150); $body=trim($d['body']??'');
  if(strlen($body)>10000) fail2('Keterangan terlalu panjang.');
  $attendance=in_array($kind,['masuk','pulang'],true);
  if($attendance) {
   $date=date('Y-m-d'); if(!workday2($p,$date)) fail2('Hari ini bukan jadwal PKL Anda.');
   foreach(['latitude','longitude','accuracy'] as $key) if(!isset($d[$key]) || !is_numeric($d[$key]) || !is_finite((float)$d[$key])) fail2('Lokasi dan akurasi wajib tersedia.');
   $lat=(float)$d['latitude'];$lng=(float)$d['longitude'];$acc=(float)$d['accuracy'];
   if(abs($lat)>90 || abs($lng)>180 || $acc<=0) fail2('Lokasi tidak valid.');
   $ts=strtotime($d['captured_at']??''); if(!$ts || abs(time()-$ts)>120) fail2('Lokasi/foto sudah kedaluwarsa. Ambil ulang.');
   if(($d['mocked']??'false')==='true') fail2('Lokasi simulasi tidak diterima.');
   if($p['latitude']!==null) $dist=distance2($p['latitude'],$p['longitude'],$lat,$lng);
   $valid=$dist!==null && $dist<=$p['radius'] && $acc<=min(40,$p['radius']);
   if(!$valid && empty($d['exception'])) fail2($dist===null?'Titik PKL belum diatur. Kirim sebagai pengajuan kendala.':'Lokasi di luar radius atau kurang akurat. Perbarui lokasi atau ajukan kendala.');
   if(!$valid && strlen($body)<5) fail2('Tuliskan alasan pengajuan kendala.');
   $status=$valid?'disetujui':'menunggu';
  } else {
   if($date<$p['start_date'] || $date>$p['end_date']) fail2('Tanggal di luar periode PKL.');
   if($body==='') fail2('Keterangan wajib diisi.');
   if($kind==='izin') { $end=date2($d['end_date']??''); if($end<$date || $end>$p['end_date']) fail2('Rentang izin tidak valid.'); }
   elseif($date>date('Y-m-d')) fail2('Aktivitas belum terjadi.');
   if($kind==='dokumentasi') $status='tersimpan';
  }
  $pdo->beginTransaction();
  // Serialize per student, including duplicate attendance and leave checks.
  query2('SELECT id FROM p2_users WHERE id=? FOR UPDATE',[$id]);
  if($attendance) {
   if(query2('SELECT id FROM p2_activities WHERE siswa_id=? AND kind=? AND attendance_date=?',[$id,$kind,$date])->fetch()) fail2('Presensi ini sudah tercatat. Lihat riwayat.');
   if(query2("SELECT id FROM p2_activities WHERE siswa_id=? AND kind='izin' AND status='disetujui' AND tanggal<=? AND end_date>=?",[$id,$date,$date])->fetch()) fail2('Tanggal ini memiliki izin yang disetujui.');
   if($kind==='pulang' && !query2("SELECT id FROM p2_activities WHERE siswa_id=? AND kind='masuk' AND tanggal=? AND status IN ('disetujui','menunggu')",[$id,$date])->fetch()) fail2('Presensi masuk harus tercatat lebih dulu.');
  }
  if($kind==='izin' && query2("SELECT id FROM p2_activities WHERE siswa_id=? AND kind='izin' AND status IN ('menunggu','disetujui') AND tanggal<=? AND end_date>=?",[$id,$end,$date])->fetch()) fail2('Ada pengajuan izin dengan tanggal yang bertumpuk.');
  [$savedFile,$original,$mime]=file2($attendance || $kind==='izin' || $kind==='dokumentasi',$attendance || $kind==='izin' || $kind==='dokumentasi');
  query2('INSERT INTO p2_activities(siswa_id,kind,tanggal,end_date,title,body,learned,obstacles,status,feedback,latitude,longitude,accuracy,distance,file_name,original_name,mime,created_at,updated_at,attendance_date) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW(),?)',[$id,$kind,$date,$end,$title,$body,$d['learned']??'',$d['obstacles']??'',$status,'',$lat,$lng,$acc,$dist,$savedFile,$original,$mime,$attendance?$date:null]);
  $activityId=$pdo->lastInsertId();
  if($kind!=='dokumentasi') query2('UPDATE p2_grades SET published_at=NULL WHERE siswa_id=?',[$id]);
  audit2($u,$id,'aktivitas_dikirim',$kind.' #'.$activityId); $pdo->commit(); $savedFile=null; ok2(['message'=>$status==='menunggu'?'Tersimpan, menunggu pemeriksaan guru.':'Aktivitas berhasil tersimpan.']);
 }
 if($action==='revise') {
  role2($u,['siswa']); $pdo->beginTransaction();
  $a=query2('SELECT * FROM p2_activities WHERE id=? FOR UPDATE',[$d['id']??0])->fetch();
  if(!$a || (int)$a['siswa_id']!==(int)$u['id'] || $a['kind']!=='jurnal' || $a['status']!=='perlu_revisi') fail2('Jurnal tidak dapat direvisi.',403);
  [$savedFile,$original,$mime]=file2();
  query2("UPDATE p2_activities SET title=?,body=?,learned=?,obstacles=?,status='menunggu',file_name=COALESCE(?,file_name),original_name=COALESCE(?,original_name),mime=COALESCE(?,mime),updated_at=NOW() WHERE id=?",[required2($d,'title',150),required2($d,'body'),$d['learned']??'',$d['obstacles']??'',$savedFile,$original,$mime,$a['id']]);
  query2('UPDATE p2_grades SET published_at=NULL WHERE siswa_id=?',[$u['id']]);
  audit2($u,$u['id'],'jurnal_direvisi','#'.$a['id']); $pdo->commit(); $savedFile=null; ok2();
 }
 if($action==='review') {
  role2($u,['guru']); $pdo->beginTransaction();
  $a=query2('SELECT * FROM p2_activities WHERE id=? FOR UPDATE',[$d['id']??0])->fetch(); if(!$a) fail2('Data tidak ditemukan.',404); scope2($u,$a['siswa_id']);
  $status=$d['status']??''; $allowed=$a['kind']==='jurnal'?['disetujui','perlu_revisi']:['disetujui','ditolak'];
  if($a['kind']==='dokumentasi' || !in_array($status,$allowed,true)) fail2('Keputusan tidak valid.');
  $feedback=required2($d,'feedback');
  if(in_array($a['kind'],['masuk','pulang'],true) && $status==='disetujui' && query2("SELECT id FROM p2_activities WHERE siswa_id=? AND kind='izin' AND status='disetujui' AND tanggal<=? AND end_date>=?",[$a['siswa_id'],$a['tanggal'],$a['tanggal']])->fetch()) fail2('Tanggal ini memiliki izin yang disetujui. Koreksi izin terlebih dahulu.');
  if($a['kind']==='izin' && $status==='disetujui' && query2("SELECT id FROM p2_activities WHERE siswa_id=? AND kind='masuk' AND status='disetujui' AND tanggal BETWEEN ? AND ?",[$a['siswa_id'],$a['tanggal'],$a['end_date']])->fetch()) fail2('Ada presensi hadir pada tanggal izin. Koreksi presensi terlebih dahulu.');
  query2('UPDATE p2_activities SET status=?,feedback=?,updated_at=NOW() WHERE id=?',[$status,$feedback,$a['id']]);
  query2('UPDATE p2_grades SET published_at=NULL WHERE siswa_id=?',[$a['siswa_id']]);
  audit2($u,$a['siswa_id'],'pemeriksaan','#'.$a['id'].' '.$a['status'].' -> '.$status.': '.$feedback); $pdo->commit(); ok2();
 }
 if($action==='grade') {
  role2($u,['guru']); $id=(int)($d['siswa_id']??0); scope2($u,$id);
  foreach(['journal_score','performance_score'] as $key) if(!isset($d[$key]) || !is_numeric($d[$key]) || $d[$key]<0 || $d[$key]>100) fail2('Nilai harus 0–100.');
  $p=placement2($id); $acts=query2('SELECT * FROM p2_activities WHERE siswa_id=?',[$id])->fetchAll();
  $attendance=attendanceScore2(calendar2($id,$p,$acts)); $publish=!empty($d['publish']);
  if($publish && (!$p || date('Y-m-d')<$p['end_date'] || (date('Y-m-d')===$p['end_date'] && date('H:i:s')<$p['end_time']))) fail2('Nilai akhir dapat diterbitkan setelah periode PKL selesai. Simpan draf dahulu.');
  if($publish && $attendance===null) fail2('Kehadiran belum dapat dihitung atau ada presensi/izin yang belum diperiksa.');
  if($publish) foreach($acts as $a) if(in_array($a['status'],['menunggu','perlu_revisi'],true) && $a['kind']!=='dokumentasi') fail2('Selesaikan pemeriksaan dan revisi aktivitas sebelum menerbitkan nilai.');
  $final=$attendance===null?null:round($attendance*.2+(float)$d['journal_score']*.3+(float)$d['performance_score']*.5,2);
  $pdo->beginTransaction();
  query2('INSERT INTO p2_grades VALUES(?,?,?,?,?,?,?,NOW()) ON DUPLICATE KEY UPDATE journal_score=VALUES(journal_score),performance_score=VALUES(performance_score),attendance_score=VALUES(attendance_score),final_score=VALUES(final_score),note=VALUES(note),published_at=VALUES(published_at),updated_at=NOW()',[$id,$d['journal_score'],$d['performance_score'],$attendance,$final,trim($d['note']??''),$publish?date('Y-m-d H:i:s'):null]);
  audit2($u,$id,$publish?'nilai_diterbitkan':'draf_nilai_disimpan',json_encode(['jurnal'=>$d['journal_score'],'kinerja'=>$d['performance_score'],'kehadiran'=>$attendance,'akhir'=>$final])); $pdo->commit(); ok2();
 }
 if($action==='attachment') {
  $a=query2('SELECT * FROM p2_activities WHERE id=?',[$d['id']??0])->fetch(); if(!$a || !$a['file_name']) fail2('Lampiran tidak ditemukan.',404); scope2($u,$a['siswa_id']);
  $ticket=bin2hex(random_bytes(32)); query2('INSERT INTO p2_downloads VALUES(?,?,DATE_ADD(NOW(),INTERVAL 5 MINUTE))',[$ticket,$a['id']]); ok2(['ticket'=>$ticket]);
 }
 fail2('Endpoint tidak ditemukan.',404);
} catch(Throwable $e) {
 if($pdo->inTransaction()) $pdo->rollBack();
 if($savedFile && is_file(__DIR__.'/private_uploads/'.$savedFile)) unlink(__DIR__.'/private_uploads/'.$savedFile);
 error_log('PKLify: '.$e->getMessage());
 if($e instanceof PDOException && $e->getCode()==='23000') fail2('Data sudah tercatat atau identitas sudah digunakan.',409);
 fail2('Permintaan gagal diproses server. Data belum dikonfirmasi tersimpan.',500);
}
