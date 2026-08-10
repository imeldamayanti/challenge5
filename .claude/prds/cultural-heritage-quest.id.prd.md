# Cultural Heritage Quest — Quest Jalan Kaki Berbasis Cerita untuk Traveler

*Judul kerja. Platform: native iOS (Swift). Status: DRAFT — baru tahap requirement.*

*Versi Indonesia dari `cultural-heritage-quest.prd.md`. Kalau ada perbedaan, versi Inggris yang jadi acuan.*

---

## Masalah

Traveler yang baru pertama datang berdiri di depan situs bersejarah yang benar-benar penting dan tidak merasakan apa-apa, karena tidak ada yang menceritakan apa yang pernah terjadi di sana. Plakat minim, sumber online generik dan kurang dipercaya, sementara pemandu manusia tidak selalu tersedia atau memang tidak cocok untuk traveler yang lebih suka eksplorasi mandiri. Kunjungannya menyusut jadi checklist foto.

Biaya kalau ini dibiarkan: situs heritage terus dikonsumsi sebagai latar belakang, bukan sebagai tempat; traveler pulang membawa foto tanpa ingatan; dan konteks intangible yang justru memberi makna pada situs-situs itu — ceritanya, garis keturunannya, peristiwanya — tetap terkunci di pengetahuan lokal yang tidak pernah sampai ke pengunjung.

## Bukti

- Riset design-thinking: wawancara dengan turis domestik dan internasional, plus storyteller dari Kultara (Sanur) dan satu tur budaya berpemandu.
- Dua masalah muncul konsisten di seluruh wawancara:
  1. "Saya tahu ini bersejarah, tapi saya tidak tahu ceritanya" — kunjungan terasa datar.
  2. Informasi terpisah-pisah dan kurang dipercaya — plakat minim, sumber web generik, pemandu tidak selalu ada atau tidak selalu diinginkan.
- Kelayakan rute untuk kandidat Denpasar sudah tervalidasi oleh preseden nyata: urutan checkpoint yang sama pernah ditempuh komunitas tur budaya lokal (B-PART, 2025).
- **Asumsi — perlu divalidasi lewat prototype:** bahwa narasi yang *saling terhubung* antar checkpoint menghasilkan ingatan dan penyelesaian yang lebih baik dibanding lore yang sama disajikan sebagai entri situs berdiri sendiri. Ini taruhan inti produk dan sampai sekarang belum diuji.

## Pengguna

**Utama — The Cultural Explorer.** Traveler (domestik maupun internasional) yang mengunjungi suatu daerah untuk pertama kali, punya minat aktif pada budaya dan sejarah, nyaman eksplorasi mandiri dengan HP alih-alih bergantung pada pemandu manusia. Terpicu saat mereka punya waktu luang setengah hari dan sedang berada di dalam atau dekat kawasan heritage.

**Bukan untuk:**
- Peserta paket tur yang sudah punya pemandu (kebutuhannya sudah terpenuhi)
- Transit traveler dengan waktu kurang dari satu hari (tidak cukup untuk jalan 1,5–2 jam)
- Penduduk lokal (motivasinya beda — ini produk kunjungan pertama)
- Traveler dengan keterbatasan mobilitas, untuk format jalan kaki 2–3 km (lihat Aksesibilitas di bagian Risiko)
- Turis kasual tanpa minat sejarah — paparan heritage bagi mereka bersifat insidental, dan biaya produk ini adalah perhatian

## Hipotesis

Kami percaya bahwa **quest jalan kaki linear yang ceritanya saling terhubung — di mana tiap checkpoint adalah satu lapisan waktu yang menuju satu klimaks historis** — akan membuat pengunjung pertama kali **menyelesaikan kunjungannya dan mengingat apa yang terjadi di sana**, untuk **traveler mandiri yang penasaran secara kultural**.

Kami akan tahu ini benar kalau **minimal 40% quest yang dimulai mencapai checkpoint terakhir, dan minimal 70% penyelesai bisa menceritakan ulang alur naratif quest tanpa dipancing, lewat survei satu pertanyaan pasca-quest.**

Angka kedua itu yang benar-benar menguji diferensiasi. Completion bisa dibeli dengan gamifikasi; ingatan tidak bisa.

## Metrik Keberhasilan

| Metrik | Target (v1) | Cara ukur |
|---|---|---|
| **Quest completion rate** (start → checkpoint terakhir) | ≥ 40% | Event in-app: quest_started → quest_completed |
| **Narrative recall** (uji hipotesis utama) | ≥ 70% penyelesai memberi penceritaan ulang yang koheren | Survei teks bebas 1 pertanyaan di completion screen, dikoding manual |
| Drop-off per checkpoint | Tidak ada satu checkpoint pun kehilangan > 25% dari yang tiba | Event arrival vs departure per checkpoint |
| Median waktu di checkpoint | ≥ 90 detik | Dwell time layar lore (proksi untuk "benar-benar dibaca") |
| Share rate | ≥ 25% dari completion | share_sheet_presented / quest_completed |
| Tingkat kegagalan GPS gate | ≤ 10% kedatangan checkpoint butuh override manual | manual_override_used / checkpoint_arrival |
| Draft resume rate | ≥ 30% quest yang ditinggal dilanjutkan dalam 7 hari | quest_resumed / quest_abandoned |

Semua target ini tebakan awal, bukan komitmen. Tujuannya memaksa keputusan di akhir v1, bukan untuk dikejar persis.

---

## Prinsip

Kendala permanen yang berlaku melewati rilis mana pun. Milestone berikutnya tidak boleh diam-diam melanggar ini.

**Offline-first, selamanya.** Perangkat adalah sumber kebenaran. Setiap pengalaman inti — browsing, preview, memulai, berjalan, menyelesaikan, dan merangkum quest — harus berfungsi dengan radio dimatikan. Network adalah tambahan yang membawa sync, konten baru, dan sharing; dia tidak pernah jadi syarat untuk berjalan.

Di v1 ini otomatis benar, karena memang tidak ada backend sama sekali: konten di-bundle, storage lokal, tidak ada akun. Prinsip ini ada untuk yang datang sesudahnya:

- **v2 (akun + sync)**: tulisan mendarat di lokal dulu dan direkonsiliasi belakangan. Entri jurnal yang ditulis di area tanpa sinyal bukan "pending" — dia *tersimpan*. Sync adalah rekonsiliasi latar belakang, dan konflik diselesaikan dengan memenangkan perangkat yang menulis konten itu.
- **v3 (CMS / content API)**: di sinilah offline-first paling mungkin hilang tanpa sengaja. Konten quest yang di-fetch harus di-cache secara durable dan ber-versi, tetap bisa dipakai walau basi, dan disegarkan secara oportunistik. Quest yang sudah diunduh user tetap bisa dimainkan selamanya, terlepas dari kondisi backend. **Jangan pernah memblokir start quest dengan panggilan network.**

Tidak ada percabangan berdasarkan koneksi. App tidak bertanya apakah dia online lalu memilih jalur — dia selalu menulis ke lokal, dan proses terpisah yang oportunistik melakukan sync kapan pun bisa. Reachability tidak bisa dipercaya (captive portal melaporkan sukses, satu bar melaporkan terhubung), dan bercabang berdasarkan koneksi berarti dua jalur kode di mana jalur offline-nya adalah yang paling jarang dites.

**Versi konten dikunci saat quest dimulai.** Quest yang sedang berjalan memegang snapshot konten yang dia mulai. Kalau tim konten mengoreksi satu bagian lore sementara ada user yang sedang berdiri di checkpoint 3, ceritanya tidak boleh berubah di bawah kakinya, dan rekap akhirnya harus cocok dengan yang benar-benar dia baca. Update konten berlaku di quest berikutnya, tidak pernah di quest yang sedang berjalan.

Dua konsekuensi yang gampang terlewat:

- **Telemetri antre di lokal.** Event analytics dan survei recall pasca-quest ditangkap di perangkat dan dikirim saat konektivitas kembali. Survei recall dijawab di checkpoint terakhir — sering kali momen dengan sinyal terburuk sepanjang quest — dan itu instrumen utama untuk hipotesis inti. Kehilangannya karena POST gagal akan diam-diam menghancurkan satu-satunya hal yang jadi alasan v1 ada.
- **Share card dikomposisi di perangkat.** Gambar summary dibuat secara lokal dari foto lokal, dan bisa disimpan ke Photos tanpa network. Hanya tindakan posting yang butuh konektivitas, dan itu urusan share sheet bawaan OS.

**Situs sakral bukan konten.** Izin dari komunitas pengelola adalah prasyarat untuk merilis sebuah situs, bukan basa-basi. Mekanik di dalam tempat ibadah aktif tetap tenang dan kontemplatif. Kendala ini mengalahkan metrik engagement.

**Setiap klaim membawa status epistemiknya.** Sejarah tercatat dan tradisi lisan dua-duanya layak diceritakan, dan tidak pernah disajikan sebagai jenis hal yang sama.

---

## Scope

### MVP (v1) — minimum untuk menguji hipotesis

**Konten**
- **2 rute quest**, keduanya tervalidasi lapangan penuh dan sudah dapat izin komunitas. Rute spesifik masih TBD — draft Denpasar ("Jejak Terakhir Badung") dan Ubud ("Siklus Ubud") adalah kandidat terkuat tapi belum dikunci.
- Tiap quest: 5 checkpoint, 2–3 km, 1 start / 3 tengah / 1 finish.
- **Dwibahasa (Indonesia + Inggris)** — persona utama secara eksplisit mencakup traveler internasional; app heritage Bali tanpa bahasa Inggris gagal melayani separuh penggunanya. Menambah ~30% waktu produksi konten; diterima.
- Setiap klaim lore membawa label akurasi: `[Tercatat]` vs `[Babad/Cerita rakyat]`, dengan atribusi sumber yang terlihat.

**Loop inti**
- Browsing dan preview quest lengkap **dari mana saja** — termasuk dari kamar hotel, sebelum berangkat. Lokasi adalah gerbang untuk *memulai*, tidak pernah untuk *menemukan*.
- Preview quest menampilkan: lore pembuka, peta rute dengan pin checkpoint, jarak total, waktu jalan kaki murni, durasi total realistis, **perkiraan biaya dari kantong sendiri** (tiket masuk, dll.), catatan medan/tangga, jendela waktu mulai yang disarankan, dan peringatan keselamatan pejalan kaki.
- **Gerbang start**: radius GPS di checkpoint 1, dengan **override manual "saya sudah di sini"** yang tersedia setelah timeout 60 detik, ditandai low-confidence.
- **Prefetch offline saat Start**: seluruh teks lore dan gambar sudah ada di perangkat sebelum quest dimulai. Kawasan heritage sinyalnya tidak bisa diandalkan — ini requirement, bukan opsi. Lihat open question soal rendering peta: MapKit tidak menyediakan cache tile offline publik, jadi tampilan rute tidak boleh bergantung pada tile live.
- **Loop checkpoint**: tiba → konfirmasi GPS (dengan fallback manual) → lore terbuka → task → clue ke checkpoint berikutnya. Urutan tetap, tidak bisa dilompat.
- **Task adalah kenang-kenangan, bukan bukti.** Radius GPS adalah gerbangnya; foto adalah suvenir. Setiap task foto **bisa di-skip** tanpa penalti — beberapa checkpoint melarang fotografi, dan user bisa saja kehabisan baterai, kehujanan, atau kena keramaian.
- Progress tracking, save-as-draft, dan resume.
- Side quest muncul sebagai saran opsional (teks saja, tanpa state yang dilacak di v1).

**Penyelesaian**
- 5 stamp checkpoint + 1 badge gabungan quest.
- Trip summary: rekap cerita linear + foto user, dalam urutan checkpoint.
- Satu kolom refleksi pribadi, dipicu oleh task checkpoint terakhir.
- Share card auto-compose + share sheet bawaan.
- Survei recall pasca-quest (1 pertanyaan) — ini instrumen pengukuran untuk hipotesis inti, bukan pelengkap.

**Platform**
- **Tidak ada akun di v1.** Semua disimpan lokal di perangkat. Login/register dihapus sepenuhnya dari flow — traveler yang mengunduh app di jalan dengan baterai 30% tidak boleh menabrak dinding autentikasi. Akun datang di v2, saat sync lintas perangkat memang jadi kebutuhan nyata.
- SwiftUI, MVVM, CoreLocation (foreground saja), MapKit, persistensi lokal.
- Konten quest di-bundle bersama app di v1. CMS adalah v3 — dengan hanya dua quest, membangun backend duluan itu prematur.

**Non-fitur yang tetap wajib**
- Izin komunitas didapat tertulis dari pengempon/badan pengelola tiap situs sakral sebelum situs itu dirilis.
- Atribusi ke sumber komunitas (Kultara, B-PART, juru kunci, pemangku) terlihat di dalam app.
- Pola keselamatan pejalan kaki: clue dan lore muncul **saat berhenti di checkpoint**, tidak pernah sebagai instruksi turn-by-turn sambil berjalan.

### Di luar scope MVP

| Item | Alasan ditunda |
|---|---|
| **History Alert / notifikasi geofence background** | Butuh background location — pengawasan App Store, biaya baterai, dan tidak menguji hipotesis inti. Pindah ke v2. |
| **Akun, login, register** | Tidak ada kebutuhan lintas perangkat dengan data lokal. Murni friksi di momen paling buruk. |
| **CMS / backend konten** | Dua quest yang di-bundle tidak sepadan dengan sebuah backend. Bangun saat kecepatan konten jadi bottleneck, bukan sebelumnya. |
| **Map Area penuh dengan koleksi badge** | v1 butuh peta rute, bukan peta koleksi. |
| **Browsing journal, riwayat visited places** | Dengan dua quest tidak ada yang bisa dijelajahi. |
| **Achievement lintas quest** (mis. tautan Lempad "Karya Sang Maestro") | Baru bermakna setelah user menyelesaikan beberapa quest. |
| **State tracking dan reward side quest** | Saran opsional tidak memakan biaya; melacaknya memakan banyak. |
| **Narasi audio** | Biaya konten tinggi. Kandidat kuat untuk v3 — dia langsung menyelesaikan masalah keselamatan lihat-HP-sambil-jalan. |
| **Monetisasi** | Gratis di v1. Keputusan harga butuh data completion dan retensi dulu. |
| **Bahasa tambahan di luar ID/EN** | v3, setelah pipeline lokalisasi ada. |

---

## Roadmap

Tiap rilis digerbangi oleh bukti dari rilis sebelumnya. Kalau gerbangnya gagal, rilis berikutnya direncanakan ulang, bukan dimulai.

### v1 — MVP: buktikan loop ceritanya
*Tujuan: apakah quest jalan kaki linear yang ceritanya terhubung membuat orang menyelesaikan dan mengingat?*

Seperti scope di atas. Dua rute, dwibahasa, sanggup offline, tanpa akun, tanpa notifikasi, tanpa backend.

**Gerbang ke v2:** completion ≥ 40% DAN recall ≥ 70%. Kalau recall gagal tapi completion lolos, klaim diferensiasinya salah — perbaiki model naratifnya sebelum menambah luas permukaan. Kalau completion gagal, benahi checkpoint drop-off dulu.

### v1.1 — Fast follow (2–6 minggu pasca-launch, ikut data)
*Tujuan: perbaiki yang datanya tunjukkan. Tanpa pilar baru.*

- Tuning ulang radius GPS per checkpoint pakai tingkat override sebenarnya
- Tulis ulang clue dan task di checkpoint drop-off terburuk
- Sesuaikan estimasi durasi dan kesulitan dengan kenyataan yang teramati
- Perbaikan copy dan pacing pada lore yang dwell time-nya rendah
- Tambah rute ketiga **hanya kalau** waktu produksi konten per quest ternyata lebih rendah dari perkiraan

### v2 — Ambient discovery dan memori
*Tujuan: bawa user kembali di antara quest, dan biarkan cerita menemukan mereka.*

- **History Alert** — notifikasi geofence background saat melewati situs heritage di luar quest aktif. Opt-in, **default mati**, dengan penjelasan nilai yang jelas sebelum permission prompt. Dibatasi rate-nya (maks 1–2 per hari) dan hanya aktif di kota tempat user pernah membuka app.
- **Halaman Place berdiri sendiri** — entitas `Place` akhirnya dipakai di luar quest. Di sinilah separuh "standalone by default" dari model konten jadi nyata.
- **Journal** — jelajahi trip lampau, visited places, edit refleksi, riwayat share.
- **Map Area penuh** — badge yang sudah didapat muncul di peta, ikhtisar kawasan, rekomendasi sepanjang rute.
- **Akun (Sign in with Apple) + cloud sync** — diperkenalkan sekarang, saat alasannya akhirnya ada: tidak kehilangan jurnal waktu ganti HP.
- **Achievement lintas quest** — mis. menyelesaikan quest Denpasar dan Ubud membuka tautan I Gusti Nyoman Lempad (Catur Muka 1973 / Pura Taman Saraswati 1951–52).
- **Side quest ber-state** dengan stamp bonus.

**Gerbang ke v3:** tingkat kembali 7 hari dan tingkat memulai quest kedua membenarkan investasi pada volume konten. Kalau user menyelesaikan satu quest lalu tidak pernah kembali, menambah quest adalah jawaban yang salah.

### v3 — Skala konten
*Tujuan: buat quest baru cukup murah untuk dirilis terus-menerus.*

- **CMS / backend konten** — data quest di-fetch dari API; tim konten merilis quest baru dan koreksi tanpa rilis App Store.
- **Tooling pipeline produksi konten** — validasi walking directions asli (bukan haversine + buffer), checklist validasi lapangan per checkpoint, dan **tracker izin komunitas** per situs sebagai gerbang keras sebelum publish.
- **Gating temporal** — kalender piodalan/upacara, jam tutup situs, kesadaran jam pasar. Quest yang mulai jam 16:00 tidak boleh mengirim orang ke situs yang tutup jam 18:00.
- **Ekspansi multi-kota** di luar dua kawasan pertama — Singaraja, Klungkung/Semarapura, Karangasem, lalu ke luar pulau.
- **Versioning konten dan hotfix** — mengoreksi satu klaim sejarah harusnya makan waktu jam, bukan siklus rilis.
- **Pipeline lokalisasi** — Jepang, Mandarin, Korea (pasar inbound Bali terbesar setelah domestik).
- **Narasi audio** — ditarik ke sini dari horizon panjang karena dia langsung memperbaiki masalah keselamatan membaca-sambil-berjalan, bukan sekadar fitur premium.

### v4 — Komunitas dan sosial
*Tujuan: biarkan orang-orang yang memiliki cerita ini yang menceritakannya, dan mereka dibayar untuk itu.*

- **Program partnership storyteller** — Kultara, B-PART, juru kunci, pemangku sebagai kontributor yang dikreditkan, dengan model atribusi dan bagi hasil yang terdefinisi.
- **Quest kontribusi komunitas** — alur submission termoderasi dengan gerbang izin dan akurasi yang sama seperti konten first-party.
- **Group quest** — jalan bersama, progress tersinkron di rombongan kecil. Sengaja **bukan** leaderboard: peringkat kompetitif di situs sakral adalah insentif yang salah.
- **Preview web publik untuk quest yang di-share** — kartu yang dibagikan harusnya membuka sesuatu, bukan kosong.
- **Galeri foto user termoderasi** per tempat, dengan aturan eksplisit melarang pembingkaian situs sakral secara tidak hormat.

### v5 dan seterusnya — horizon panjang
*Hanya dikejar kalau taruhan sebelumnya terbayar. Didaftar sebagai arah, bukan komitmen.*

- **Monetisasi** — quest premium, city pass, sponsor badan pariwisata atau badan heritage, lisensi ke pemerintah daerah. Model berbayar apa pun harus tetap menyediakan akses gratis ke minimal satu quest per kota.
- **AR di checkpoint** — Puri Pemecutan direkonstruksi seperti berdirinya sebelum 20 September 1906, dilihat dari titik tempat dia jatuh.
- **B2B / white-label** — museum, badan heritage, dinas pariwisata daerah menjalankan quest mereka sendiri di atas platform ini.
- **Varian rute aksesibel** — versi lebih pendek, bebas tangga, atau berbantuan kendaraan dari quest yang sudah ada.
- **Pendamping Apple Watch** — kedatangan checkpoint dan penyampaian clue di pergelangan tangan, HP tetap di kantong.
- **Paket peta offline penuh** untuk kawasan berkonektivitas rendah.

---

## Milestone Delivery

Outcome bisnis, bukan tugas engineering. `/plan` mengubah tiap milestone jadi rencana implementasi.

| # | Milestone | Outcome | Status | Plan |
|---|---|---|---|---|
| 1 | Model konten dikunci | `Place` (lore berdiri sendiri) dan `Quest` (referensi berurut ke Place) terdefinisi sebagai entitas berbeda; konvensi label akurasi ditetapkan | pending | — |
| 2 | Izin komunitas didapat | Izin tertulis dari badan pengelola tiap situs di kedua rute v1; situs tanpa izin dicoret | pending | — |
| 3 | Rute tervalidasi lapangan | Kedua rute dijalani ujung ke ujung; jarak jalan riil, waktu, jam buka, aturan foto, dan biaya dicatat | pending | — |
| 4 | Konten quest ditulis | Kedua quest ditulis dan direview dalam bahasa Indonesia dan Inggris, tiap klaim berlabel dan bersumber | pending | — |
| 5 | Discovery dan preview | User di mana pun di dunia bisa menjelajah kedua quest dan melihat rute, durasi, biaya, medan, dan waktu | pending | — |
| 6 | Loop eksekusi quest | User di lokasi bisa memulai, melewati 5 checkpoint, skip foto, kehilangan sinyal, meninggalkan, dan melanjutkan | pending | — |
| 7 | Penyelesaian dan share | Badge, trip summary, refleksi, share card, dan survei recall | pending | — |
| 8 | Instrumentasi | Setiap metrik di tabel Metrik Keberhasilan benar-benar terkumpul | pending | — |
| 9 | Vonis v1 | Cukup data untuk menerima atau menolak hipotesis dan memutuskan apakah v2 lanjut sesuai scope | pending | — |

Milestone 1–4 adalah kerja konten dan relasi, bukan engineering, dan itulah jalur kritisnya. Milestone 2 khususnya bisa membatalkan satu rute sepenuhnya.

---

## Pertanyaan Terbuka

- [ ] **Dua rute mana yang dirilis di v1?** Denpasar dan Ubud adalah kandidatnya; keputusannya tergantung hasil milestone 2 (izin) dan 3 (validasi lapangan), bukan pada kualitas naratif.
- [ ] **Nama app dan branding.** Sejauh ini yang ada baru nama quest ("Bandana Negara", "Puputan: Kisah Terakhir Sang Raja", "Dari Puri ke Catur Muka"). Dibutuhkan sebelum submit ke App Store.
- [ ] **Berapa jam sebenarnya biaya produksi satu quest** (riset + validasi lapangan + izin + penulisan dwibahasa + fotografi)? Perkiraan 30–50 jam. Angka ini menentukan apakah taruhan skala konten di v3 layak sama sekali, dan hanya bisa dijawab dengan memproduksi dua quest pertama.
- [ ] **Siapa yang memiliki produksi konten jangka panjang?** Penulis internal, sejarawan lokal yang dikontrak, atau model partnership komunitas yang diformalkan di v4?
- [ ] **Bagaimana survei recall dikoding?** Koding manual tidak berskala melewati beberapa ratus respons; butuh rubrik sebelum launch.
- [ ] **Diferensiasi terhadap Questo secara spesifik.** Questo adalah kompetitor langsung yang menjalankan model story-walk berbasis lokasi yang sama secara global. "Lebih baik dari peta wisata" bukan pernyataan positioning saat Questo ada. Jawaban yang paling mungkin adalah kedalaman sumber lokal, izin komunitas, dan kualitas naratif — tapi itu harus dinyatakan dan dipertahankan.
- [ ] **Bagaimana peta rute di-render offline?** MapKit tidak punya API tile offline publik, jadi tampilan MapKit live akan kosong tepat di tempat produk paling membutuhkannya — di dalam Pasar Badung, di gang sempit, di bawah kanopi Monkey Forest. Tiga kandidat: (a) gambar rute statis yang di-render duluan untuk preview, (b) kanvas kustom yang menggambar garis rute dan pin checkpoint tanpa basemap, (c) MapLibre dengan vector tile yang di-cache. Rekomendasi terkuat: (b) selama quest berjalan dan (a) untuk preview — basemap detail bukan yang dibutuhkan user di tengah jalan, arah dan sisa jarak yang dibutuhkan. Opsi (c) satu-satunya peta offline berfidelitas penuh dan paling mahal diintegrasikan.
- [ ] **Apa kebijakan kedaluwarsa draft?** Berapa lama quest yang ditinggalkan menyimpan foto dan progresnya, dan apa yang terjadi pada datanya saat kedaluwarsa?
- [ ] **Versi iOS minimum dan batas perangkat** — memengaruhi pilihan CoreLocation dan SwiftData.

---

## Risiko

| Risiko | Kemungkinan | Dampak | Mitigasi |
|---|---|---|---|
| **Situs sakral keberatan digamifikasi** — seorang pemangku atau desa adat menentang app ini secara publik | Sedang | Kritis | Izin tertulis sebagai gerbang keras sebelum publish (milestone 2); mekanik kontemplatif dan non-game di dalam tempat ibadah aktif; jalur takedown cepat untuk situs yang komunitasnya menarik izin |
| **Klaim sejarah dibantah akademisi atau tokoh budaya** | Sedang | Tinggi | Pelabelan `[Tercatat]` / `[Babad]` wajib; sumber terlihat; versioning konten agar koreksi terkirim dalam hitungan jam (v3), dengan proses patch manual sampai itu ada |
| **GPS tidak andal di checkpoint riil** — pasar indoor, gang sempit, kanopi rapat | Tinggi | Tinggi | Override manual "saya sudah di sini" setelah 60 detik, ditandai low-confidence; tuning radius per checkpoint di v1.1; radius default dibuat longgar |
| **Taruhan narasi terhubung ternyata salah** — user suka jalannya tapi ingatannya tidak lebih baik dari panduan biasa | Sedang | Kritis | Survei recall dibangun ke dalam v1 khusus untuk mendeteksi ini lebih awal, sebelum volume konten diperbesar |
| **Produksi konten terlalu lambat untuk menopang katalog** | Tinggi | Tinggi | Ukur jujur pada dua quest pertama; kalau angkanya buruk, strategi ekspansi v3 berubah jadi partnership-first alih-alih in-house |
| **Peta kosong saat offline** — MapKit tidak menyediakan cache tile offline, sehingga tampilan rute gagal tepat di tempat bersinyal lemah yang dikunjungi quest | Tinggi | Tinggi | Jangan bergantung pada tile live: gambar rute statis yang di-render duluan untuk preview, kanvas rute-dan-pin kustom selama quest berjalan (lihat pertanyaan terbuka) |
| **Offline-first hilang saat migrasi CMS v3** — data quest pindah ke belakang API dan app diam-diam jadi bergantung network | Sedang | Tinggi | Offline-first ditulis sebagai prinsip permanen, bukan properti v1; cache konten durable dan ber-versi; quest yang sudah diunduh tetap bisa dimainkan apa pun kondisi backend; start quest tidak pernah menunggu panggilan network |
| **Survei recall hilang karena sinyal buruk** — instrumen hipotesis utama gagal terkirim di checkpoint terakhir | Tinggi | Tinggi | Respons survei dan event analytics disimpan lokal dan dikirim saat tersambung; jangan pernah menggantungkan pengiriman pada request live |
| **Cedera pejalan kaki** — user tertabrak saat membaca app di Jalan Gajah Mada atau Jalan Monkey Forest | Rendah | Kritis | Tidak ada instruksi turn-by-turn sambil berjalan; konten muncul saat berhenti di checkpoint; peringatan keselamatan eksplisit sebelum start; checkpoint ditempatkan di titik berdiri yang aman saat validasi lapangan |
| **User tiba di situs yang tutup atau sedang upacara di tengah quest** | Tinggi | Sedang | Jendela waktu mulai yang disarankan dan jam tutup ditampilkan di preview (v1); gating sadar kalender (v3); fallback yang anggun berupa "situs tidak tersedia, ini ceritanya" |
| **Penolakan App Store soal background location** (v2) | Sedang | Sedang | Opt-in, default mati, penjelasan nilai yang jelas sebelum permission, dan fitur yang tetap anggun saat ditolak |
| **Eksklusi aksesibilitas** — format jalan 2–3 km mengecualikan user dengan keterbatasan mobilitas | Tinggi | Sedang | Pengungkapan jujur soal medan, jarak, dan tangga di v1; varian rute di v5; jangan pernah menyajikan format ini sebagai bisa diakses siapa saja |
| **Biaya tak terduga dari kantong user bikin kesal** — mis. tiket masuk Monkey Forest dan Museum Puri Lukisan di rute Ubud | Tinggi | Sedang | `estimated_cost` sebagai field metadata quest yang wajib, ditampilkan di preview sebelum start |

---

*Status: DRAFT — baru requirement. Perencanaan implementasi menyusul lewat `/plan`.*
