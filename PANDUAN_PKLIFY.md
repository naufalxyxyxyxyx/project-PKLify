# PKLify — Flutter + PHP + MySQL

Proyek aktif: `D:\CODING\mobileprograming\pklify`.
API aktif: `D:\xampp\htdocs\pklify_api\v2.php`.
Database: `pklify_db`, MySQL port **3307**. Tabel baru memakai awalan `p2_`.
Tabel lama tetap ada; aplikasi baru memakai data `p2_` saja. UI demo lama diarsipkan di `lib/legacy_demo.dart`.

## Menjalankan di Chrome

Nyalakan Apache dan MySQL XAMPP, lalu di terminal VS Code:

```powershell
cd D:\CODING\mobileprograming\pklify
flutter pub get
flutter run -d chrome
```

Jika aplikasi lama masih berjalan, hentikan dengan Ctrl+C lalu jalankan lagi karena dependensi berubah.
Chrome menggunakan `http://localhost/pklify_api`. Izinkan kamera dan lokasi saat diminta.
Kamera/lokasi web membutuhkan konteks aman: localhost untuk pengujian lokal, HTTPS untuk hosting.
GPS laptop mungkin kurang akurat untuk radius 40 meter; kondisi itu menjadi pengajuan kendala, bukan otomatis hadir.

## Akun percobaan (database nyata, tanpa aktivitas buatan)

| Peran | Identitas | Kata sandi |
|---|---|---|
| Siswa | 2026101301 | SiswaPkl!2026 |
| Guru | 198701012026101301 | GuruPkl!2026 |
| Admin | admin | AdminPkl!2026 |

Pilih peran yang sesuai saat login. Password salah ditolak.
Siswa percobaan dihubungkan ke guru percobaan. Jumlah siswa bimbingan guru adalah 1, aktivitas 0, nilai belum tersedia.
Identitas ini untuk pengujian, bukan identitas siswa/guru sungguhan.
Periode awal adalah tanggal setup sampai 90 hari berikutnya; jadwal Senin–Jumat, 08:00–16:00 WIB.
Tempat dan koordinat belum ditentukan. Login admin > Kelola > siswa > atur titik PKL sebenarnya dan periode.

## Alur penggunaan

1. Admin membuat akun dan mengatur penempatan, guru pembimbing, jadwal, hari libur, dan radius (bawaan 40 m).
2. Siswa mengambil foto kamera dan lokasi untuk masuk/pulang. Galeri tidak tersedia untuk presensi.
3. Server memeriksa jarak <= radius, akurasi <= min(radius, 40 m), lokasi maksimal berumur 120 detik, hari kerja, dan presensi ganda.
4. Jika titik belum diatur, posisi di luar radius, atau akurasi kurang, siswa memilih pengajuan kendala dan menulis alasan. Foto dan lokasi tetap wajib. Guru memeriksanya.
5. Siswa mengirim jurnal (lampiran opsional), izin (foto bukti wajib), dan dokumentasi (foto kamera wajib).
6. Riwayat dibaca dari server dan dapat dibuka lagi setelah logout/login. Tombol muat ulang mengambil pembaruan guru.
7. Guru hanya melihat siswa bimbingannya, membaca lampiran, memeriksa izin/jurnal/presensi, meminta revisi, serta mengisi nilai.
8. Siswa dapat memperbaiki jurnal berstatus perlu_revisi; lampiran lama dipertahankan bila tidak diganti.

Jika akses lokasi ditolak atau tidak tersedia, presensi tidak dikirim sampai lokasi diperoleh. Aplikasi tidak mengarang koordinat.
Foto/GPS adalah bukti pendukung; implementasi ini tidak menjamin deteksi segala pemalsuan perangkat atau permintaan API.

## Rekap dan nilai

- Rekap dihitung berdasarkan periode/jadwal penempatan; hari libur tidak menjadi alpa.
- Hari kerja belum selesai: belum presensi. Setelah jam pulang: alpa bila tidak hadir atau izin.
- Izin atau kendala presensi masuk menunggu keputusan: menunggu verifikasi, belum diputuskan alpa.
- Kehadiran dihitung per hari dari presensi masuk yang disetujui. Presensi pulang tercatat terpisah untuk pemantauan.
- Skor kehadiran = hari hadir / hari kerja selesai tanpa izin disetujui × 100.
- Izin disetujui dikeluarkan dari pembagi; belum ada pembagi atau pengajuan masuk/izin belum diperiksa berarti skor belum tersedia.
- Nilai akhir = kehadiran 20% + kualitas jurnal 30% + kinerja/sikap 50%.
- Guru dapat menyimpan draf. Siswa hanya melihat nilai yang diterbitkan.
- Penerbitan menunggu periode selesai, skor kehadiran tersedia, dan seluruh pemeriksaan/revisi selesai.
- Perubahan penempatan, pemeriksaan, jurnal, izin, atau presensi mengembalikan nilai terbit ke draf. Guru menerbitkan ulang setelah memeriksa.
- Alasan koreksi dan tindakan guru tersimpan di `p2_audit`.

Bobot dan perlakuan izin ini adalah aturan awal proyek, perlu disesuaikan jika sekolah menetapkan rubrik berbeda.

## Menjalankan di Android

Manifest sudah memuat izin kamera, internet, dan lokasi; minimum Android SDK 24.
Emulator Android memakai alamat bawaan `http://10.0.2.2/pklify_api`.
Untuk HP asli, sambungkan laptop dan HP ke jaringan yang sama dan gunakan alamat IPv4 laptop:

```powershell
flutter run -d ID_HP --dart-define=API_BASE_URL=http://IP_LAPTOP/pklify_api
```

Ganti `ID_HP` dan `IP_LAPTOP` sesuai hasil `flutter devices` dan `ipconfig`.
Apache harus dapat dijangkau dari HP. Port **3307 adalah port MySQL untuk PHP**, bukan port URL aplikasi.
Kamera/GPS/izin Android perlu pengujian langsung dengan HP pengguna.

Status build Android saat pengembangan: NDK 28.2.13676358 yang sebelumnya tidak lengkap sudah dipasang. Build APK masih gagal saat Gradle mengunduh dependensi karena verifikasi sertifikat Java (`PKIX path building failed` pada Google Maven/Maven Central). Percobaan memakai trust store Windows juga belum berhasil. Verifikasi TLS tidak dinonaktifkan dan opsi percobaan hanya berlaku pada proses build. Masalah lingkungan sertifikat ini perlu diselesaikan sebelum pengujian APK; build Chrome berhasil.

## Backend dan setup ulang

Salinan backend tersedia di folder `backend` untuk disimpan bersama proyek.
Saat memindah komputer, letakkan isinya di `htdocs/pklify_api`, sesuaikan `config.php`, buat database `pklify_db`, lalu jalankan:

```powershell
cd D:\xampp
.\php\php.exe .\htdocs\pklify_api\setup_v2.php
```

Setup hanya dijalankan lewat CLI dan tidak menghapus tabel/data lama. Akun yang sudah ada tidak direset.
Foto/lampiran disimpan di `private_uploads`; database menyimpan nama file, pemilik, dan metadata.
Folder ini ditutup oleh Apache melalui `.htaccess`. Akses lampiran melalui tiket server berumur 5 menit setelah memeriksa hak akses.
Sesi login berlaku 12 jam. Logout mencabut token di server; refresh browser meminta login kembali.
Konfigurasi HTTP dan akun contoh ini ditujukan untuk pengembangan lokal.

## Memeriksa penyimpanan

Buka phpMyAdmin > pklify_db:

- `p2_users`: akun.
- `p2_placements`: penempatan dan jadwal.
- `p2_activities`: jurnal, izin, masuk/pulang, dokumentasi.
- `p2_grades`: draf/nilai terbit.
- `p2_audit`: riwayat perubahan.

Pengujian API otomatis berada di `backend_tests/integration.php`. Menggunakan database khusus `pklify_verify_20261013`, tidak memakai aktivitas akun pengguna. Jalankan dengan server PHP uji pada port 8097 dan environment `PKLIFY_DB=pklify_verify_20261013`. Skrip menolak database uji yang sudah ada, lalu membersihkan database/file yang dibuatnya sendiri.

Hasil pemeriksaan implementasi: 40 skenario integrasi API lolos, 5 tes Flutter lolos, analyzer bersih, dan build web berhasil. Pengujian API menggunakan data/foto buatan pada database uji; pengambilan foto dan ketepatan GPS di perangkat fisik tetap perlu dicoba langsung.

Referensi integrasi: [camera resmi Flutter](https://pub.dev/packages/camera), [Geolocator](https://pub.dev/packages/geolocator), dan [file_picker](https://pub.dev/packages/file_picker).
