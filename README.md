# PKLify

Aplikasi pengelolaan Praktik Kerja Lapangan dengan Flutter, API PHP, dan MySQL.

## Fitur

- Login siswa (NIS), guru (NIP), dan admin melalui database.
- Dashboard dan riwayat mengikuti akun, tanpa progres contoh.
- Presensi kamera langsung dan lokasi; radius bawaan 40 meter diperiksa server.
- Jurnal beserta lampiran, revisi jurnal, izin dengan foto bukti, dan dokumentasi.
- Guru hanya memantau siswa bimbingannya dan menerbitkan nilai akhir.
- Admin mengelola akun, penempatan, jadwal kerja, dan hari libur.

## Menjalankan

1. Instal Flutter dan XAMPP/PHP + MySQL.
2. Salin isi `backend/` ke `htdocs/pklify_api/`, termasuk `private_uploads/.htaccess`.
3. Buat database `pklify_db`; sesuaikan host, port (bawaan 3307), dan kredensial di `backend/config.php` serta salinan API aktif.
4. Jalankan `php setup_v2.php` dari folder API untuk menyiapkan tabel dan akun percobaan.
5. Dari root proyek, jalankan `flutter pub get`, lalu `flutter run -d chrome`.

Panduan akun percobaan dan pengaturan lokasi tersedia di [PANDUAN_PKLIFY.md](PANDUAN_PKLIFY.md). Akun contoh hanya untuk pengembangan lokal; tidak berisi identitas siswa/guru asli.

## Struktur

- `lib/`: kode Flutter aktif, mulai dari `lib/main.dart`.
- `backend/`: source API, skema database, dan setup.
- `test/` dan `backend_tests/`: pemeriksaan Flutter dan API.
- `lib/legacy_demo.dart`: arsip UI demo lama, tidak dijalankan aplikasi.

File `main.dart` yang dahulu berada di root sudah digantikan struktur Flutter lengkap. Riwayat commit sebelumnya tetap tersedia.

## Status verifikasi

Pada pengembangan sebelumnya, 40 pemeriksaan API dan 5 tes Flutter lolos, analyzer bersih, dan build web berhasil. Build Android masih terkendala sertifikat Java/Gradle; kamera dan GPS HP belum diuji langsung. Lokasi PKL harus diisi admin sebelum presensi normal dapat digunakan.

Database aktif, dokumen siswa, konfigurasi SDK lokal, dan hasil build tidak disertakan dalam repository.
