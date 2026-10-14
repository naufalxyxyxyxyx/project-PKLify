<?php
// Pure attendance calculations. No database connection required.
function workday2($p,$date) { return $p && $date >= $p['start_date'] && $date <= $p['end_date'] && in_array(date('N',strtotime($date)),explode(',',$p['work_days']),true) && !in_array($date,preg_split('/[\\s,]+/',trim($p['holidays'])),true); }
function calendar2($id,$p,$activities) {
 if(!$p) return [];
 $today=date('Y-m-d'); $time=date('H:i:s'); $last=min($today,$p['end_date']);
 $days=array_fill_keys(explode(',',$p['work_days']),true);
 $holidays=array_fill_keys(preg_split('/[\\s,]+/',trim($p['holidays'])),true);
 $present=[]; $leave=[]; $pending=[];
 // Index once instead of scanning all journals and photos for every day.
 foreach($activities as $a) {
  if(!in_array($a['status'],['disetujui','menunggu'],true)) continue;
  if($a['kind']==='masuk') {
   if($a['status']==='disetujui') $present[$a['tanggal']]=true;
   else $pending[$a['tanggal']]=true;
  } elseif($a['kind']==='izin') {
   $end=min($last,$a['end_date']);
   for($day=max($p['start_date'],$a['tanggal']);$day<=$end;$day=date('Y-m-d',strtotime($day.' +1 day'))) {
    if($a['status']==='disetujui') $leave[$day]=true;
    else $pending[$day]=true;
   }
  }
 }
 $out=[];
 for($day=$p['start_date'];$day<=$last;$day=date('Y-m-d',strtotime($day.' +1 day'))) {
  if(!isset($days[date('N',strtotime($day))]) || isset($holidays[$day])) continue;
  $closed=$day<$today || $time >= $p['end_time'];
  $status=isset($present[$day])?'hadir':(isset($leave[$day])?'izin':(isset($pending[$day])?'menunggu verifikasi':($closed?'alpa':'belum presensi')));
  $out[]=['tanggal'=>$day,'status'=>$status,'closed'=>$closed];
 }
 return array_reverse($out);
}
function attendanceScore2($cal) {
 $total=0;$present=0;
 foreach($cal as $d) { if(!$d['closed']) continue; if($d['status']==='menunggu verifikasi') return null; if($d['status']==='izin') continue; $total++; if($d['status']==='hadir') $present++; }
 return $total ? round(100*$present/$total,2) : null;
}
