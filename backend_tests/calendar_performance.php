<?php
if(PHP_SAPI!=='cli') exit;
date_default_timezone_set('Asia/Jakarta');
require __DIR__.'/../backend/calendar.php';
function baselineWorkday($p,$date) { return $p && $date >= $p['start_date'] && $date <= $p['end_date'] && in_array(date('N',strtotime($date)),explode(',',$p['work_days']),true) && !in_array($date,preg_split('/[\s,]+/',trim($p['holidays'])),true); }
function baselineCalendar($id,$p,$activities) {
 if(!$p) return [];
 $out=[]; $today=date('Y-m-d'); $last=min($today,$p['end_date']);
 for($day=$p['start_date'];$day<=$last;$day=date('Y-m-d',strtotime($day.' +1 day'))) {
  if(!baselineWorkday($p,$day)) continue;
  $in=false;$leave=false;$pending=false;
  foreach($activities as $a) {
   if($a['kind']==='masuk' && $a['tanggal']===$day) { if($a['status']==='disetujui') $in=true; if($a['status']==='menunggu') $pending=true; }
   if($a['kind']==='izin' && $a['tanggal']<=$day && $a['end_date']>=$day) { if($a['status']==='disetujui') $leave=true; if($a['status']==='menunggu') $pending=true; }
  }
  $closed=$day<$today || date('H:i:s') >= $p['end_time'];
  $status=$in?'hadir':($leave?'izin':($pending?'menunggu verifikasi':($closed?'alpa':'belum presensi')));
  $out[]=['tanggal'=>$day,'status'=>$status,'closed'=>$closed];
 }
 return array_reverse($out);
}
function baselineScore($cal) {
 $total=0;$present=0;
 foreach($cal as $d) { if(!$d['closed']) continue; if($d['status']==='menunggu verifikasi') return null; if($d['status']==='izin') continue; $total++; if($d['status']==='hadir') $present++; }
 return $total ? round(100*$present/$total,2) : null;
}

$today=date('Y-m-d');
$p=['start_date'=>date('Y-m-d',strtotime('-300 days')),'end_date'=>$today,
 'work_days'=>'1,2,3,4,5','holidays'=>date('Y-m-d',strtotime('-7 days')),
 'end_time'=>'23:59:59'];
$activities=[];
for($i=0;$i<20000;$i++) $activities[]=['kind'=>'jurnal','tanggal'=>$today,'status'=>'disetujui','end_date'=>null];
for($i=1;$i<=290;$i+=2) $activities[]=['kind'=>'masuk','tanggal'=>date('Y-m-d',strtotime("-$i days")),'status'=>$i%3?'disetujui':'menunggu','end_date'=>null];
$activities[]=['kind'=>'izin','tanggal'=>date('Y-m-d',strtotime('-10 days')),'end_date'=>date('Y-m-d',strtotime('-2 days')),'status'=>'disetujui'];
$activities[]=['kind'=>'izin','tanggal'=>date('Y-m-d',strtotime('-60 days')),'end_date'=>date('Y-m-d',strtotime('-40 days')),'status'=>'menunggu'];
$activities[]=['kind'=>'izin','tanggal'=>$p['start_date'],'end_date'=>$today,'status'=>'ditolak'];
foreach([null,$p,array_merge($p,['work_days'=>'6,7']),array_merge($p,['start_date'=>date('Y-m-d',strtotime('+2 days'))]),array_merge($p,['end_time'=>'00:00:00'])] as $case) {
 $old=baselineCalendar(3,$case,$activities); $new=calendar2(3,$case,$activities);
 if($old!==$new || baselineScore($old)!==attendanceScore2($new)) throw new Exception('Calendar behavior changed.');
}
$start=hrtime(true); for($i=0;$i<3;$i++) baselineCalendar(3,$p,$activities); $oldMs=(hrtime(true)-$start)/3e6;
$start=hrtime(true); for($i=0;$i<3;$i++) calendar2(3,$p,$activities); $newMs=(hrtime(true)-$start)/3e6;
echo json_encode(['checks'=>'5 equivalence scenarios passed','activities'=>count($activities),'period_days'=>301,'baseline_ms'=>round($oldMs,2),'optimized_ms'=>round($newMs,2),'speedup'=>round($oldMs/max(.001,$newMs),1)],JSON_PRETTY_PRINT).PHP_EOL;
