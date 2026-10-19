<?php
// Uses a separate disposable database, never writes activities to real accounts.
if(PHP_SAPI!=='cli') exit;
$db='pklify_verify_20261013';
$pdo=new PDO('mysql:host=127.0.0.1;port=3307;charset=utf8mb4','root','',[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
if($pdo->query("SHOW DATABASES LIKE '$db'")->fetch()) throw new Exception('Test database already exists; refusing to overwrite.');
$pdo->exec("CREATE DATABASE $db CHARACTER SET utf8mb4");
$pdo->exec("USE $db");
$pdo->exec(file_get_contents('D:/xampp/htdocs/pklify_api/schema_v2.sql'));
date_default_timezone_set('Asia/Jakarta');
$base='http://127.0.0.1:8097/v2.php?action=';
$passed=0;
function check($condition,$name) { global $passed; if(!$condition) throw new Exception('FAIL: '.$name); $passed++;echo "PASS: $name\n"; }
function call2($action,$data=[],$token=null,$file=null) {
 global $base;
 $h=curl_init($base.$action);$headers=[];
 if($token)$headers[]='Authorization: Bearer '.$token;
 if($file){$data['file']=new CURLFile($file,'image/png','proof.png');$payload=$data;}else{$headers[]='Content-Type: application/json';$payload=json_encode($data);}
 curl_setopt_array($h,[CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>$payload,CURLOPT_HTTPHEADER=>$headers,CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>15]);
 $text=curl_exec($h);$status=curl_getinfo($h,CURLINFO_RESPONSE_CODE);curl_close($h);
 $out=json_decode($text,true);if(!is_array($out))throw new Exception('Not JSON: '.$text);$out['_status']=$status;return $out;
}
$file=tempnam(sys_get_temp_dir(),'pklify-proof-');
file_put_contents($file,base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));
$uploaded=[];
try {
 foreach([['Admin','admin','admin'],['Teacher','guru','teacher'],['Student','siswa','student'],['Other','siswa','other'],['Other teacher','guru','otherteacher']] as $u){
  $q=$pdo->prepare('INSERT INTO p2_users(nama,role,identity,password) VALUES(?,?,?,?)');$q->execute([...$u,password_hash('TestPass123!',PASSWORD_DEFAULT)]);
 }
 $today=date('Y-m-d');$tomorrow=date('Y-m-d',strtotime('+1 day'));$yesterday=date('Y-m-d',strtotime('-1 day'));
 $q=$pdo->prepare("INSERT INTO p2_placements(siswa_id,guru_id,tempat,latitude,longitude,start_date,end_date,work_days,start_time,end_time,holidays) VALUES(3,2,'Test place',-6.2,106.8,?,?,'1,2,3,4,5,6,7','00:00','23:59','')");$q->execute([$yesterday,$tomorrow]);
 check(call2('login',['identity'=>'student','password'=>'wrong','role'=>'siswa'])['_status']===401,'wrong password rejected');
 $s=call2('login',['identity'=>'student','password'=>'TestPass123!','role'=>'siswa'])['token'];
 $t=call2('login',['identity'=>'teacher','password'=>'TestPass123!','role'=>'guru'])['token'];
 $o=call2('login',['identity'=>'other','password'=>'TestPass123!','role'=>'siswa'])['token'];
 $ot=call2('login',['identity'=>'otherteacher','password'=>'TestPass123!','role'=>'guru'])['token'];
 $admin=call2('login',['identity'=>'admin','password'=>'TestPass123!','role'=>'admin'])['token'];
 check(call2('overview')['_status']===401,'unauthenticated overview denied');
 $overview=call2('overview',[],$s);
 check(count($overview['students'])===1 && count($overview['students'][0]['activities'])===0 && $overview['students'][0]['grade']===null,'new student empty and ungraded');
 check(count(call2('overview',[],$t)['students'])===1,'teacher sees assigned student');
 check(count(call2('overview',[],$ot)['students'])===0,'unassigned teacher sees no students');
 $place=['siswa_id'=>3,'guru_id'=>2,'tempat'=>'Test place','latitude'=>'-6.2','longitude'=>'106.8','radius'=>40,'start_date'=>$yesterday,'end_date'=>$tomorrow,'work_days'=>'1,2,3,4,5,6,7','start_time'=>'00:00','end_time'=>'23:59','holidays'=>$yesterday];
 check(call2('placement',$place,$admin)['success'],'admin configures actual placement');
 $calendar=call2('overview',[],$s)['students'][0]['calendar'];
 check(count($calendar)===1 && $calendar[0]['tanggal']===$today,'holiday excluded from absence calendar');
 check(call2('placement',array_merge($place,['holidays'=>'']),$admin)['success'],'admin updates schedule');
 check(call2('create_user',['role'=>'guru','nama'=>'Unauthorized','identity'=>'bad','password'=>'TestPass123!'],$s)['_status']===403,'student cannot create account');
 check(call2('create_user',['role'=>'siswa','nama'=>'New Student','identity'=>'new','password'=>'TestPass123!'],$admin)['success'],'admin creates real account');
 // Location workflow uses only this disposable database and test identities.
 $loc=['tempat'=>'Kantor baru','alamat'=>'Alamat kantor pengujian','latitude'=>-6.21,'longitude'=>106.81,'reason'=>'Pengajuan penempatan','base_version'=>0,'siswa_id'=>4];
 check(call2('location_request',array_merge($loc,['latitude'=>91]),$s)['_status']===422,'invalid location rejected');
 check(call2('location_request',$loc,$o)['_status']===422,'student without assigned placement cannot request location');
 check(call2('location_set',$loc,$s)['_status']===403,'student cannot activate own location');
 $request=call2('location_request',$loc,$s);
 check($request['success'],'student proposes location'); $rid=$request['id'];
 $snapshot=call2('overview',[],$s)['students'][0];
 check((float)$snapshot['placement']['latitude']===-6.2 && (int)$snapshot['locations'][0]['siswa_id']===3,'request preserves active point and ignores spoofed student id');
 check(call2('location_request',$loc,$s)['_status']===409,'duplicate pending location rejected');
 check(call2('location_review',['id'=>$rid,'status'=>'disetujui','feedback'=>'OK'],$ot)['_status']===403,'unassigned teacher cannot approve location');
 check(call2('location_review',['id'=>$rid,'status'=>'disetujui','feedback'=>'OK'],$s)['_status']===403,'student cannot approve location');
 check(call2('location_review',['id'=>$rid,'status'=>'disetujui','feedback'=>''],$t)['_status']===422,'review requires explanation');
 check(call2('location_review',['id'=>$rid,'status'=>'perlu_revisi','feedback'=>'Perbaiki titik kantor'],$t)['success'],'teacher requests location correction');
 check((float)call2('overview',[],$s)['students'][0]['placement']['latitude']===-6.2,'correction keeps active point');
 $rid=call2('location_request',$loc,$s)['id'];
 check(call2('location_review',['id'=>$rid,'status'=>'disetujui','feedback'=>'Penempatan sesuai'],$t)['success'],'teacher approves revised location');
 $snapshot=call2('overview',[],$s)['students'][0];
 check((float)$snapshot['placement']['latitude']===-6.21 && (int)$snapshot['placement']['radius']===40,'approved point becomes active at 40m');
 check(count($snapshot['locations'])===2 && $snapshot['locations'][0]['pemeriksa']==='Teacher','student sees location history and reviewer');
 check(call2('location_review',['id'=>$rid,'status'=>'perlu_revisi','feedback'=>'Again'],$t)['_status']===409,'processed request cannot be reviewed twice');
 check(call2('location_set',array_merge($loc,['siswa_id'=>3]),$t)['_status']===409,'stale direct update rejected');
 $pending=call2('location_request',array_merge($loc,['base_version'=>$rid]),$s)['id'];
 $direct=call2('location_set',array_merge($loc,['siswa_id'=>3,'base_version'=>$rid,'latitude'=>-6.22,'reason'=>'Koreksi oleh admin']),$admin);
 check($direct['success'],'admin corrects active location with reason');
 check(call2('location_review',['id'=>$pending,'status'=>'disetujui','feedback'=>'Old'],$t)['_status']===409,'superseded proposal cannot overwrite corrected point');
 $snap=call2('overview',[],$s)['students'][0];
 check($snap['locations'][1]['status']==='digantikan','superseded request retained in history');
 check(call2('location_set',array_merge($loc,['siswa_id'=>3,'base_version'=>$direct['id'],'reason'=>'']),$admin)['_status']===422,'admin correction requires reason');
 check(call2('location_set',array_merge($loc,['siswa_id'=>3,'base_version'=>$direct['id']]),$ot)['_status']===403,'other teacher cannot directly assign location');
 check(call2('placement',array_merge($place,['latitude'=>-6.25]),$admin)['_status']===422,'old placement endpoint cannot bypass location history');
 $restored=call2('location_set',array_merge($loc,['siswa_id'=>3,'base_version'=>$direct['id'],'latitude'=>-6.2,'longitude'=>106.8,'reason'=>'Tetapkan lokasi untuk pengujian presensi']),$t);
 check($restored['success'],'assigned teacher directly sets school placement');
 check(count(call2('overview',[],$ot)['students'])===0,'other teacher cannot read location history');
 $pending=call2('location_request',array_merge($loc,['base_version'=>$restored['id']]),$s)['id'];
 check(call2('placement',array_merge($place,['guru_id'=>5]),$admin)['_status']===422,'teacher reassignment requires reason');
 check(call2('placement',array_merge($place,['guru_id'=>5,'reason'=>'Pergantian pembimbing']),$admin)['success'],'admin reassigns teacher with reason');
 check(call2('location_review',['id'=>$pending,'status'=>'disetujui','feedback'=>'OK'],$t)['_status']===403,'former teacher loses review access');
 check(call2('location_review',['id'=>$pending,'status'=>'disetujui','feedback'=>'OK'],$ot)['_status']===409,'teacher reassignment supersedes pending request');
 check(call2('placement',array_merge($place,['reason'=>'Kembalikan pembimbing uji','holidays'=>'']),$admin)['success'],'restore test teacher without changing active coordinates');
 $journal=['kind'=>'jurnal','title'=>'Journal test','body'=>'Actual test activity','tanggal'=>$today,'learned'=>'Lesson','obstacles'=>'None'];
 check(call2('activity',$journal,$s,$file)['success'],'journal upload saved');
 $a=call2('overview',[],$s)['students'][0]['activities'][0];$jid=$a['id'];
 check($a['has_file'] && $a['status']==='menunggu','journal and attachment returned in history');
 check(call2('attachment',['id'=>$jid],$o)['_status']===403,'another student cannot read attachment');
 check(call2('review',['id'=>$jid,'status'=>'disetujui','feedback'=>'OK'],$ot)['_status']===403,'unassigned teacher cannot review');
 check(call2('review',['id'=>$jid,'status'=>'perlu_revisi','feedback'=>'Add detail'],$t)['success'],'teacher requests revision');
 check(call2('revise',['id'=>$jid,'title'=>'Revised journal','body'=>'More details'],$s)['success'],'student resubmits revision');
 check(call2('review',['id'=>$jid,'status'=>'disetujui','feedback'=>'Complete'],$t)['success'],'teacher approves journal');
 $permit=['kind'=>'izin','title'=>'Sakit','body'=>'Medical reason','tanggal'=>$tomorrow,'end_date'=>$tomorrow];
 check(call2('activity',$permit,$s)['_status']===422,'permission requires photo');
 check(call2('activity',$permit,$s,$file)['success'],'permission photo and record saved');
 $pa=call2('overview',[],$s)['students'][0]['activities'][0];
 check(call2('review',['id'=>$pa['id'],'status'=>'disetujui','feedback'=>'Bukti sesuai'],$t)['success'],'permission approved');
 $attendance=['kind'=>'masuk','title'=>'Presensi masuk','body'=>'','latitude'=>'-6.2','longitude'=>'106.8','accuracy'=>'5','captured_at'=>date(DATE_ATOM),'mocked'=>'false'];
 check(call2('activity',$attendance,$s)['_status']===422,'attendance requires camera photo');
 check(call2('activity',array_merge($attendance,['latitude'=>'-6.21']),$s,$file)['_status']===422,'outside radius rejected');
 check(call2('activity',array_merge($attendance,['accuracy'=>'100']),$s,$file)['_status']===422,'inaccurate location rejected');
 check(call2('activity',array_merge($attendance,['captured_at'=>date(DATE_ATOM,strtotime('-10 minutes'))]),$s,$file)['_status']===422,'stale location rejected');
 check(call2('activity',array_merge($attendance,['latitude'=>(string)(-6.2+41/111194.9266)]),$s,$file)['_status']===422,'41 meters rejected at 40 meter radius');
 check(call2('activity',array_merge($attendance,['latitude'=>(string)(-6.2+39/111194.9266)]),$s,$file)['success'],'39 meters accepted at 40 meter radius');
 check(call2('activity',$attendance,$s,$file)['_status']===422,'duplicate attendance rejected');
 check(call2('activity',array_merge($attendance,['kind'=>'pulang','title'=>'Pulang','latitude'=>'-6.21','exception'=>'1','body'=>'Tugas di luar kantor']),$s,$file)['success'],'exception saved pending review');
 $detail=call2('overview',[],$s)['students'][0];
 check($detail['activities'][0]['status']==='menunggu','exception not automatically present');
 check(call2('review',['id'=>$detail['activities'][0]['id'],'status'=>'disetujui','feedback'=>'Tugas dikonfirmasi'],$t)['success'],'teacher verifies exception');
 check(call2('activity',['kind'=>'dokumentasi','title'=>'Documentation','body'=>'Work photo','tanggal'=>$today],$s,$file)['success'],'documentation saved');
 check(call2('grade',['siswa_id'=>3,'journal_score'=>80,'performance_score'=>90,'note'=>'Good work','publish'=>false],$t)['success'],'grade draft saved');
 check(call2('overview',[],$s)['students'][0]['grade']===null,'draft grade hidden from student');
 check(call2('grade',['siswa_id'=>3,'journal_score'=>80,'performance_score'=>90,'publish'=>true],$t)['_status']===422,'cannot publish before placement ends');
 // Isolated fixture only: close test placement and move test records to completed day.
 $pdo->prepare('UPDATE p2_placements SET end_date=? WHERE siswa_id=3')->execute([$yesterday]);
 $pdo->prepare("UPDATE p2_activities SET tanggal=?,attendance_date=IF(attendance_date IS NULL,NULL,?) WHERE siswa_id=3 AND kind IN ('masuk','pulang')")->execute([$yesterday,$yesterday]);
 check(call2('grade',['siswa_id'=>3,'journal_score'=>80,'performance_score'=>90,'note'=>'Final','publish'=>true],$t)['success'],'publish final grade after period');
 $grade=call2('overview',[],$s)['students'][0]['grade'];
 check((float)$grade['final_score']===89.0,'weighted final grade equals 89');
 check(call2('review',['id'=>$jid,'status'=>'perlu_revisi','feedback'=>'Final correction'],$t)['success'],'review can be corrected with reason');
 check(call2('overview',[],$s)['students'][0]['grade']===null,'correction withdraws stale published grade');
 $ticket=call2('attachment',['id'=>$jid],$t)['ticket'];
 $download=file_get_contents($base.'download&ticket='.$ticket);check($download===file_get_contents($file),'authorized attachment bytes round trip');
 check(call2('logout',[],$s)['success'] && call2('overview',[],$s)['_status']===401,'logout revokes token');
 echo "ALL $passed CHECKS PASSED\n";
} finally {
 $uploaded=$pdo->query('SELECT file_name FROM p2_activities WHERE file_name IS NOT NULL')->fetchAll(PDO::FETCH_COLUMN);
 foreach($uploaded as $name){$path='D:/xampp/htdocs/pklify_api/private_uploads/'.$name;if(preg_match('/^[a-f0-9]{48}\.(png|jpg|jpeg|webp|pdf|doc|docx)$/',$name)&&is_file($path))unlink($path);}
 unlink($file);
 $pdo->exec("DROP DATABASE pklify_verify_20261013");
}
