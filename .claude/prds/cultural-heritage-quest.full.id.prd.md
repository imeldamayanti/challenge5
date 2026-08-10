# Cultural Heritage Quest — Product Requirements Lengkap

**Jenis dokumen:** PRD lengkap — functional dan non-functional requirements
**Platform:** native iOS (Swift / SwiftUI)
**Status:** DRAFT
**Menggantikan:** tidak ada. Pendamping `cultural-heritage-quest.prd.md`, yang memuat framing masalah, hipotesis, metrik, dan roadmap. Dokumen ini tidak mengulanginya — dokumen ini mengubahnya jadi requirement.

*Versi Indonesia dari `cultural-heritage-quest.full.prd.md`. Kalau ada perbedaan, versi Inggris yang jadi acuan.*

**Cara membaca dokumen ini.** Requirement memakai kata kunci RFC 2119: **MUST** (wajib), **SHOULD** (default kuat, penyimpangan butuh alasan tertulis), **MAY** (opsional). Tiap requirement punya ID, prioritas (P0 = pemblokir MVP, P1 = MVP tapi bisa diturunkan, P2 = pasca-MVP), dan rilis target. ID bersifat permanen — jangan pernah dinomori ulang; requirement yang dibatalkan ditandai `WITHDRAWN` dan ID-nya tetap disimpan.

---

## 1. Glosarium

Penamaan yang presisi penting di sini karena kata yang sama berarti hal berbeda bagi tim desain, konten, dan engineering.

| Istilah | Arti |
|---|---|
| **Place** | Situs heritage nyata dengan lore-nya sendiri yang berdiri sendiri. Ada terlepas dari quest mana pun. Punya koordinat, radius, aturan kunjungan, dan catatan izin. |
| **Quest** | Urutan Checkpoint yang membentuk satu busur naratif. Mereferensikan Place; tidak memilikinya. |
| **Checkpoint** | Satu posisi dalam urutan sebuah Quest, terikat pada tepat satu Place, membawa segmen lore, clue, dan task-nya sendiri. Place yang sama BOLEH muncul di beberapa Quest dengan segmen lore berbeda. |
| **Run** | Satu percobaan seorang user pada satu Quest. Unit dari progress, draft, dan penyelesaian. User BOLEH punya maksimal satu Run aktif per Quest. |
| **Task** | Aktivitas yang ditawarkan di sebuah Checkpoint — foto, refleksi, atau pertanyaan. Tidak pernah menggerbangi progres. |
| **Side quest** | Saran opsional di sebuah Checkpoint. Tidak dilacak di v1. |
| **Stamp** | Penghargaan karena mencapai satu Checkpoint. |
| **Badge** | Penghargaan karena menyelesaikan satu Quest utuh, atau untuk pencapaian lintas Quest (v2). |
| **Arrival** | Konfirmasi sistem bahwa user secara fisik berada di sebuah Checkpoint. Entah terkonfirmasi GPS atau dinyatakan manual. |
| **Content version** | Penanda versi yang tidak berubah untuk teks, media, dan rute sebuah Quest. Dikunci ke sebuah Run saat mulai. |
| **Consent record** | Izin terdokumentasi dari komunitas pengelola sebuah Place untuk memasukkannya ke dalam Quest. |

---

## 2. Scope rilis

| | v1 (MVP) | v1.1 | v2 | v3 |
|---|---|---|---|---|
| Quest yang dirilis | 2 | +1 bersyarat | — | banyak |
| Pengiriman konten | di-bundle dalam app | bundled | bundled | CMS/API |
| Akun | tidak ada | tidak ada | Sign in with Apple | — |
| Butuh network | tidak pernah | tidak pernah | hanya sync | hanya refresh konten |
| Notifikasi | proximity quest (opt-in, mati) | — | + History Alert (opt-in, mati) | — |
| Background location | hanya region monitoring | — | + region History Alert | — |
| Apple Watch | hanya haptic teruskan | — | haptic arrival saat Run | — |
| Bahasa | ID + EN | ID + EN | ID + EN | +JA/ZH/KO |

---

## 3. Keputusan arsitektur kunci

Keputusan yang membatasi banyak requirement di bawah. Masing-masing punya alasan karena masing-masing akan dipertanyakan nanti.

### AD-1 — Penggunaan lokasi dipisah berdasarkan tujuan

Dua perilaku lokasi dengan izin berbeda, biaya berbeda, dan justifikasi berbeda. Keduanya tidak boleh dicampur.

**Deteksi arrival, saat Run berjalan — foreground saja.** Sampling berjalan selagi app terbuka, di layar checkpoint. Produk ini tidak boleh mendorong orang berjalan sambil menatap layar, jadi pelacakan terus-menerus selama berjalan tidak punya tujuan yang menghadap user: clue sudah memberi tahu user harus ke mana, dia kantongi HP-nya, dia jalan, dia buka app saat tiba. Ini menjaga pengalaman berjalan tetap aman dan tidak memakan apa pun di antara checkpoint.

**Quest proximity alert, di luar Run — background region monitoring, opt-in, default mati.** App memantau radius start dari quest yang belum diselesaikan user, dan memberi tahu saat user memasuki salah satunya, sehingga traveler yang kebetulan melewati Puri Agung Pemecutan jadi tahu bahwa ada quest yang dimulai di sana. Pada Apple Watch yang terpasang, ini muncul sebagai haptic. Lihat `FR-PROX`.

*Alasan menerima background location di v1.* Pola yang mahal dan diawasi ketat itu adalah background location update terus-menerus. Region monitoring bukan itu — dia berjalan di radio kasar dengan bantuan hardware dan biaya standby-nya dapat diabaikan. Justifikasi App Review-nya sempit dan mudah dibaca: *beri tahu user saat dia sedang berdiri dekat titik awal tur jalan kaki yang bisa dia ambil sekarang juga.* Itu kasus yang jauh lebih mudah dibanding History Alert yang ambient, yang menyala tanpa diminta soal tempat-tempat yang tidak pernah user tanyakan.

*Konsekuensi untuk History Alert (v2).* Dia kini mewarisi infrastruktur yang sudah jalan, tapi tetap fitur terpisah dengan opt-in sendiri dan percakapan izinnya sendiri. Berbagi mekanisme bukan berarti berbagi persetujuan.

*Konsekuensi untuk model berjalan.* Pengalamannya tetap "kantongi HP, jalan, buka saat tiba" selama Run berlangsung. Ini harus diajarkan di onboarding dan di peringatan keselamatan sebelum start, bukan dibiarkan ditemukan sendiri.

### AD-2 — Arrival digerbangi oleh posisi; task tidak pernah jadi gerbang

Progres hanya butuh Arrival. Setiap Task bisa di-skip tanpa penalti dan tanpa perubahan reward.

*Alasan.* App tidak bisa memverifikasi isi foto, jadi foto bukan bukti — dia suvenir. Menjadikannya gerbang menciptakan kegagalan yang tidak bisa app selesaikan: fotografi dilarang di sebagian area pura aktif, dan daftar validasi lapangan PRD ini sendiri menandai izin foto sebagai hal yang belum selesai per situs.

### AD-3 — Store lokal yang otoritatif; tidak ada percabangan koneksi

Semua baca dan tulis menuju store lokal. Tidak ada cabang `if online` di mana pun dalam loop inti. Sync (v2) dan refresh konten (v3) adalah proses oportunistik terpisah yang tidak pernah duduk di jalur yang menghadap user.

### AD-4 — Content version dikunci per Run

Sebuah Run memegang snapshot konten yang dia mulai, seumur hidupnya termasuk saat merangkum.

*Alasan.* Hotfix konten tidak boleh menulis ulang cerita di bawah kaki user yang sedang berdiri di Checkpoint 3, dan rekapnya harus cocok dengan yang benar-benar dia baca.

### AD-5 — Satu dependensi network yang dibenarkan: kill-switch situs

Konten v1 di-bundle, jadi situs yang komunitasnya menarik izin tidak bisa dihapus tanpa rilis App Store (review 24–48 jam, plus jeda update user — realistis berhari-hari). Ini tidak bisa diterima untuk satu-satunya risiko yang berperingkat Kritis.

Karena itu app **MUST** mengambil daftar suppression kecil dari remote saat launch bila ada konektivitas, menyimpan hasilnya secara durable, dan menerapkannya pada semua launch berikutnya. Dia **MUST** gagal ke state cache terakhir, tidak pernah memblokir launch, dan tidak pernah menunda start quest.

*Ini satu-satunya tempat network menyentuh produk inti, dan dia ada untuk menepati janji kepada komunitas yang situsnya kita rilis.*

---

## 4. Data model

Daftar field adalah requirement, bukan schema. Tipe bersifat indikatif.

### 4.1 Entitas konten (ditulis tim konten, read-only di perangkat)

**Place**
| Field | Catatan |
|---|---|
| `id` | permanen, tidak pernah dipakai ulang |
| `name_official` | terlokalisasi; bentuk yang dipakai badan pengelola |
| `name_variants[]` | ejaan alternatif yang ditemui di sumber (mis. Maospahit / Maospait) |
| `coordinate` | lat/lon, divalidasi di lapangan, bukan dari pencarian peta |
| `arrival_radius_m` | per-place, dituning; default 75 m |
| `type` | puri / pura / pasar / monumen / museum / ruang publik |
| `is_sacred` | menentukan pembatasan mekanik — lihat FR-TASK-05 |
| `visiting_hours` | termasuk pola penutupan musiman yang diketahui |
| `dress_code` | teks bebas, terlokalisasi |
| `photo_policy` | boleh / area-terbatas / dilarang, plus catatan |
| `entry_cost` | jumlah + mata uang, atau gratis |
| `accessibility_notes` | tangga, permukaan, lebar |
| `lore_standalone` | terlokalisasi; dipakai History Alert di v2, ditulis sejak v1 |
| `sources[]` | sitasi + jenis (tercatat / lisan / wawancara) |
| `consent_record_id` | wajib tidak null untuk publish |

**Quest**
| Field | Catatan |
|---|---|
| `id`, `slug` | |
| `content_version` | tidak berubah per revisi yang dipublikasikan |
| `title`, `hook_lore`, `description` | terlokalisasi |
| `region`, `city` | |
| `checkpoints[]` | berurut, 1..n |
| `total_distance_m` | dari walking directions asli, bukan haversine |
| `walking_time_min`, `total_duration_min` | angka terpisah; keduanya ditampilkan |
| `estimated_cost` | jumlah biaya masuk Place + catatan |
| `terrain_summary` | diturunkan dari Place, bisa disunting |
| `proximity_radius_m` | radius untuk alert pra-kedatangan (FR-PROX); lebih besar dari `arrival_radius_m` checkpoint start, default 200 m |
| `recommended_start_window` | mis. 08:00–14:00 waktu setempat |
| `hard_latest_start` | diturunkan dari jam tutup Place paling awal dikurangi durasi |
| `safety_notes` | terlokalisasi |
| `languages[]` | |
| `badge_id` | |

**Checkpoint**
| Field | Catatan |
|---|---|
| `id`, `quest_id`, `order_index` | |
| `place_id` | |
| `role` | start / tengah / finish |
| `lore_segment` | terlokalisasi, dengan label akurasi per klaim |
| `clue_to_next` | terlokalisasi; null untuk checkpoint terakhir |
| `tasks[]` | |
| `side_quests[]` | |
| `stamp_id` | |

**Task**
| Field | Catatan |
|---|---|
| `id`, `checkpoint_id`, `type` | foto / refleksi / pertanyaan |
| `prompt` | terlokalisasi |
| `blocks_progression` | **MUST false untuk semua konten v1**; field-nya ada supaya aturannya eksplisit dan bisa diaudit |

**ConsentRecord**
| Field | Catatan |
|---|---|
| `place_id`, `granting_body`, `granted_by_name`, `granted_by_role` | |
| `granted_at`, `expires_at` | |
| `scope[]` | pencantuman / fotografi / penamaan / citra |
| `document_ref` | penunjuk ke artefak yang ditandatangani |
| `status` | granted / withdrawn / expired |

### 4.2 Entitas user (ditulis perangkat, terikat sync di v2)

Semua record user **MUST** membawa UUID yang digenerate perangkat, `created_at`, dan `updated_at` sejak v1, walaupun tidak ada yang disinkronkan di v1. Memasang identitas ke baris yang sudah ada setelah launch jauh lebih sulit daripada membawanya sejak awal.

**Run** — `id`, `quest_id`, `content_version`, `language`, `state`, `started_at`, `updated_at`, `completed_at`, `abandoned_at`, `current_checkpoint_index`

**CheckpointResult** — `run_id`, `checkpoint_id`, `arrived_at`, `arrival_method` (gps / manual), `gps_accuracy_m`, `lore_first_opened_at`, `lore_dwell_ms`, `stamp_awarded_at`

**TaskResult** — `checkpoint_result_id`, `task_id`, `type`, `photo_local_id` | `text`, `skipped`, `completed_at`

**Award** — `type` (stamp / badge), `source_id`, `run_id`, `awarded_at`

**SurveyResponse** — `run_id`, `question_id`, `text`, `created_at`, `sync_state`

**AnalyticsEvent** — `id`, `name`, `params`, `created_at`, `sync_state`

---

## 5. Functional requirements

### 5.1 Onboarding dan first run — `FR-ONB`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-ONB-01 | App **MUST** sepenuhnya bisa dipakai saat pertama dibuka tanpa akun, tanpa sign-in, tanpa email. | P0 | v1 |
| FR-ONB-02 | Onboarding **MUST** maksimal 4 layar dan **MUST** bisa dilewati dari layar pertama. | P0 | v1 |
| FR-ONB-03 | Onboarding **MUST** menjelaskan model berjalan kantongi-HP (AD-1): app dibuka di checkpoint, tidak dibawa terbuka sambil berjalan. | P0 | v1 |
| FR-ONB-04 | App **MUST NOT** meminta izin lokasi selama onboarding. Izin **MUST** diminta secara kontekstual, saat percobaan start quest pertama, didahului layar penjelasan. | P0 | v1 |
| FR-ONB-05 | Bahasa **MUST** default ke bahasa perangkat bila Indonesia atau Inggris, dan ke Inggris bila selain itu, dan **MUST** bisa diubah di Settings. | P0 | v1 |
| FR-ONB-06 | App **MUST NOT** menampilkan prompt App Tracking Transparency, karena app **MUST NOT** mengumpulkan data yang dipakai untuk tracking. | P0 | v1 |

### 5.2 Discovery dan preview — `FR-DISC`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-DISC-01 | Browsing dan preview penuh quest **MUST** berfungsi di lokasi mana pun di bumi, tanpa network, dan dengan izin lokasi ditolak. | P0 | v1 |
| FR-DISC-02 | Daftar quest **MUST** menampilkan per quest: judul, wilayah, jarak, waktu jalan, durasi total, dan perkiraan biaya. | P0 | v1 |
| FR-DISC-03 | Preview quest **MUST** menampilkan semua dari: lore pembuka, deskripsi, daftar checkpoint berurut dengan nama Place, peta rute (lihat FR-MAP), jarak total, waktu jalan, durasi total, perkiraan biaya dari kantong sendiri beserta rinciannya, ringkasan medan dan tangga, jendela waktu mulai yang disarankan, dan peringatan keselamatan. | P0 | v1 |
| FR-DISC-04 | Preview **MUST NOT** membuka segmen lore checkpoint atau clue. Nama Place dan peta ditampilkan; ceritanya tidak. | P0 | v1 |
| FR-DISC-05 | Bila sebuah quest diperkirakan memakan biaya, totalnya **MUST** terlihat di kartu quest pada daftar, bukan hanya di dalam preview. | P0 | v1 |
| FR-DISC-06 | Bila waktu setempat sudah lewat dari `hard_latest_start`, preview **MUST** menampilkan peringatan non-blocking yang menyebut situs mana yang tutup dan jam tutupnya. | P1 | v1 |
| FR-DISC-07 | Preview quest **MUST** bisa dicapai dengan satu ketukan dari daftar quest. | P1 | v1 |
| FR-DISC-08 | Quest yang ditekan oleh kill-switch (AD-5) **MUST NOT** muncul di daftar, dan Run yang sedang berjalan dari quest tertekan **MUST** ditutup dengan anggun beserta penjelasan. | P0 | v1 |

### 5.3 Prefetch dan kesiapan offline — `FR-OFF`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-OFF-01 | Di v1 seluruh konten quest **MUST** dikirim di dalam bundle app. Tidak ada unduhan yang dibutuhkan untuk memulai quest. | P0 | v1 |
| FR-OFF-02 | Setiap alur inti — browse, preview, start, progres, selesai, rangkum, komposisi share card, simpan ke Photos — **MUST** berfungsi dengan perangkat dalam mode pesawat. Ini gerbang rilis, dan diuji sebagai gerbang. | P0 | v1 |
| FR-OFF-03 | Peta rute **MUST** ter-render offline. Lihat FR-MAP-01. | P0 | v1 |
| FR-OFF-04 | Sejak v3, konten yang di-fetch **MUST** di-cache durable dan ber-versi, tetap bisa dipakai walau basi, dan disegarkan oportunistik. Start quest **MUST NOT** menunggu panggilan network apa pun. | P0 | v3 |
| FR-OFF-05 | Sejak v3, quest yang sudah ada di perangkat **MUST** tetap bisa dimainkan tanpa batas waktu terlepas dari ketersediaan backend. | P0 | v3 |

### 5.4 Peta rute — `FR-MAP`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-MAP-01 | Tampilan rute **MUST NOT** bergantung pada tile peta live. MapKit tidak menyediakan cache tile offline publik, jadi view MapKit live bukan implementasi yang bisa diterima untuk pemakaian di dalam quest. | P0 | v1 |
| FR-MAP-02 | Selama Run aktif, peta **MUST** menampilkan minimal: urutan checkpoint, posisi user relatif terhadap checkpoint berikutnya, dan sisa jarak garis lurus. | P0 | v1 |
| FR-MAP-03 | Peta **MUST NOT** menyediakan navigasi turn-by-turn. | P0 | v1 |
| FR-MAP-04 | App **MAY** menawarkan serah-terima satu ketukan ke walking directions Apple Maps, disajikan sebagai meninggalkan app, untuk user yang menginginkan navigasi. | P2 | v1.1 |
| FR-MAP-05 | Badge yang sudah didapat ditampilkan di peta regional adalah fitur v2 dan **MUST NOT** dibangun ke dalam peta v1. | P2 | v2 |

### 5.5 Memulai sebuah Run — `FR-START`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-START-01 | Memulai Run **MUST** membutuhkan Arrival di checkpoint pertama, ditetapkan sesuai FR-ARR. | P0 | v1 |
| FR-START-02 | Sebelum prompt izin lokasi, app **MUST** menampilkan penjelasan berbahasa sederhana mengapa lokasi dibutuhkan dan bahwa dia hanya dipakai selagi app terbuka. | P0 | v1 |
| FR-START-03 | Bila izin lokasi ditolak, preview quest **MUST** tetap tersedia penuh dan kontrol start **MUST** menjelaskan apa yang terblokir serta menawarkan jalan ke Settings. | P0 | v1 |
| FR-START-04 | User **MUST** mengonfirmasi peringatan keselamatan sebelum Run pertama sebuah quest. | P0 | v1 |
| FR-START-05 | Memulai Run **MUST** mengunci `content_version` dan `language` ke Run tersebut. | P0 | v1 |
| FR-START-06 | Maksimal satu Run per quest **MAY** aktif. Memulai quest yang sudah punya draft **MUST** menawarkan lanjut atau ulang, dan mengulang **MUST** memperingatkan bahwa foto dan refleksi Run tersebut akan dibuang. | P0 | v1 |
| FR-START-07 | Beberapa Run dari quest *berbeda* **MAY** berstatus draft bersamaan. | P1 | v1 |
| FR-START-08 | Quest **MUST NOT** bisa dimulai dari luar radius start lewat jalur mana pun. Bila arrival tidak bisa dikonfirmasi, satu-satunya aksi yang tersedia adalah preview. | P0 | v1 |
| FR-START-09 | Override manual di checkpoint *start* **MUST** membutuhkan konfirmasi eksplisit yang menyebut nama Place — misalnya, "Kamu sedang berdiri di gerbang utama Puri Agung Pemecutan?" — sebelum Run dimulai. Override ada untuk kegagalan GPS, bukan untuk memulai dari jarak jauh, dan kalimatnya harus membuat itu jelas tanpa menuduh user. | P0 | v1 |
| FR-START-10 | Override manual **MUST** tetap tersedia di checkpoint start. Menghapusnya akan membuat seluruh produk tidak bisa dipakai di mana pun GPS gagal di gerbang pertama, dan justru di situlah situs padat perkotaan paling buruk. | P0 | v1 |

### 5.6 Deteksi arrival — `FR-ARR`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-ARR-01 | Arrival ditetapkan saat satu fix lokasi menempatkan user di dalam `arrival_radius_m` checkpoint dengan akurasi horizontal tidak lebih buruk dari radius tersebut. | P0 | v1 |
| FR-ARR-02 | Sampling lokasi **MUST** berjalan hanya selagi app di foreground. | P0 | v1 |
| FR-ARR-03 | Kontrol override manual **MUST** muncul setelah 60 detik deteksi gagal selagi layar arrival terbuka. Menggunakannya **MUST** mencatat `arrival_method = manual` dan akurasi terakhir yang diketahui. | P0 | v1 |
| FR-ARR-04 | Override manual **MUST NOT** mengurangi reward apa pun, menandai Run sebagai lebih rendah, atau dihukum secara visual. Itu jalur yang sah, bukan kecurangan. | P0 | v1 |
| FR-ARR-05 | Layar arrival **MUST** menampilkan umpan balik langsung — perkiraan sisa jarak dan apakah ada fix yang layak — alih-alih spinner tanpa batas. | P0 | v1 |
| FR-ARR-06 | Arrival di checkpoint di luar urutan **MUST NOT** memajukan Run. App **MUST** menyatakan checkpoint mana yang diharapkan. | P0 | v1 |
| FR-ARR-07 | `arrival_radius_m` **MUST** bisa disesuaikan per checkpoint lewat konten, bukan lewat kode. | P0 | v1 |

### 5.7 Progres checkpoint dan lore — `FR-CP`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-CP-01 | Checkpoint **MUST** diselesaikan berurut sesuai `order_index`. Melompat ke depan **MUST NOT** dimungkinkan. | P0 | v1 |
| FR-CP-02 | Saat Arrival, app **MUST** menyajikan, berurutan: segmen lore checkpoint, task-nya, lalu clue ke checkpoint berikutnya. | P0 | v1 |
| FR-CP-03 | Clue ke checkpoint berikutnya **MUST** bisa dibaca ulang kapan saja selama Run tanpa memicu ulang arrival. | P0 | v1 |
| FR-CP-04 | Lore yang sudah dibaca **MUST** tetap bisa diakses selama sisa Run dan di dalam summary. | P0 | v1 |
| FR-CP-05 | Setiap klaim faktual di lore **MUST** dirender bersama label akurasinya — sejarah tercatat versus tradisi lisan — memakai konvensi visual yang konsisten dan terbaca. Labelnya **MUST NOT** disembunyikan di balik ketukan. | P0 | v1 |
| FR-CP-06 | Sumber untuk lore sebuah checkpoint **MUST** bisa dicapai dalam satu ketukan dari layar lore. | P0 | v1 |
| FR-CP-07 | Stamp **MUST** diberikan saat Arrival, terlepas dari penyelesaian task. | P0 | v1 |
| FR-CP-08 | App **MUST** menampilkan progres quest sebagai jumlah checkpoint tercapai dari total. Progres berbasis jarak **MUST NOT** dipakai, karena jarak jalan riil tidak diukur. | P1 | v1 |

### 5.8 Task — `FR-TASK`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-TASK-01 | Tidak ada task yang **MUST** memblokir progres, reward, atau penyelesaian. | P0 | v1 |
| FR-TASK-02 | Setiap task **MUST** menawarkan kontrol skip yang eksplisit dan tidak minta maaf. | P0 | v1 |
| FR-TASK-03 | Task foto **MUST** mendukung memotret baru maupun memilih dari yang sudah ada. | P0 | v1 |
| FR-TASK-04 | Foto yang diambil untuk task **MUST** disimpan di storage lokal app dan **MUST NOT** diunggah ke mana pun di v1. | P0 | v1 |
| FR-TASK-05 | Di Place dengan `is_sacred = true`, app **MUST** menampilkan aturan berpakaian dan kebijakan foto Place tersebut sebelum menawarkan task apa pun, dan **MUST NOT** menawarkan mekanik puzzle, scavenger, atau berbatas waktu. Mekanik yang diizinkan terbatas pada foto, membaca, refleksi, dan satu pertanyaan ringan. | P0 | v1 |
| FR-TASK-06 | Di Place dengan `photo_policy = prohibited`, task foto **MUST NOT** ditawarkan sama sekali. | P0 | v1 |
| FR-TASK-07 | Task checkpoint terakhir **MUST** mencakup prompt refleksi teks bebas, dan jawabannya **MUST** mengalir ke trip summary. | P0 | v1 |
| FR-TASK-08 | Side quest **MUST** disajikan sebagai jelas opsional dan **MUST NOT** dilacak, dinilai, atau diberi reward di v1. | P1 | v1 |
| FR-TASK-09 | Pelacakan side quest dengan stamp bonus. | P2 | v2 |

### 5.9 State Run, draft, gangguan — `FR-RUN`

State Run: `not_started → active → (completed | abandoned)`, dengan `active` bertahan tanpa batas sebagai draft.

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-RUN-01 | Setiap transisi state dan setiap hasil task **MUST** disimpan durable dalam 500 ms sejak aksi user. | P0 | v1 |
| FR-RUN-02 | Sebuah Run **MUST** bertahan melewati app di-background, force-quit, terminasi oleh iOS, dan restart perangkat tanpa kehilangan arrival, foto, atau teks. | P0 | v1 |
| FR-RUN-03 | Run aktif **MUST** bisa dilanjutkan dari layar home lewat titik masuk terlihat yang menampilkan nama quest dan progres. | P0 | v1 |
| FR-RUN-04 | User **MUST** bisa meninggalkan Run secara eksplisit, dengan konfirmasi yang menyebut apa yang disimpan dan apa yang hilang. | P0 | v1 |
| FR-RUN-05 | Run berstatus draft **MUST NOT** kedaluwarsa otomatis di v1. Kebijakan retensi masih pertanyaan terbuka; sampai itu terjawab, tidak ada yang dihapus. | P0 | v1 |
| FR-RUN-06 | Bila Place sebuah checkpoint jadi tertekan (AD-5) di tengah Run, Run **MUST** berakhir dengan anggun dan summary tetap disimpan untuk checkpoint yang sudah tercapai. | P0 | v1 |

### 5.10 Penyelesaian, penghargaan, summary — `FR-DONE`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-DONE-01 | Run selesai saat Arrival di checkpoint terakhir, terlepas dari penyelesaian task. | P0 | v1 |
| FR-DONE-02 | Saat selesai, app **MUST** memberikan semua stamp checkpoint yang didapat plus badge quest. | P0 | v1 |
| FR-DONE-03 | Trip summary **MUST** menyajikan checkpoint dalam urutan naratif, masing-masing dengan rekap segmen lore-nya, foto user bila ada, dan refleksi user. | P0 | v1 |
| FR-DONE-04 | Summary **MUST** dibangun dari `content_version` yang dikunci ke Run, tidak pernah dari konten terkini. | P0 | v1 |
| FR-DONE-05 | Summary **MUST** bisa dilihat offline, selamanya, setelah penyelesaian. | P0 | v1 |
| FR-DONE-06 | Summary dari Run yang sudah selesai **MUST** terdaftar dan bisa dibuka ulang dari layar home di v1, bahkan sebelum Journal penuh ada. | P1 | v1 |
| FR-DONE-07 | Journal penuh — jelajahi semua trip, Place yang dikunjungi, sunting refleksi, riwayat share. | P2 | v2 |

### 5.11 Share — `FR-SHARE`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-SHARE-01 | Share card **MUST** dikomposisi sepenuhnya di perangkat dari aset lokal. | P0 | v1 |
| FR-SHARE-02 | Share card **MUST** bisa disimpan ke Photos tanpa network. | P0 | v1 |
| FR-SHARE-03 | Sharing **MUST** memakai share sheet sistem. | P0 | v1 |
| FR-SHARE-04 | User **MUST** bisa mengeluarkan foto tertentu dari share card sebelum membagikan. | P0 | v1 |
| FR-SHARE-05 | Untuk Place sakral, share card **MUST** membawa nama resmi Place dan **MUST NOT** menerapkan bingkai lucu-lucuan, stiker, atau overlay. | P0 | v1 |
| FR-SHARE-06 | Share card **MUST NOT** menyematkan koordinat presisi, dan metadata lokasi pada foto yang disertakan **MUST** dibersihkan dari gambar hasil komposisi. | P0 | v1 |
| FR-SHARE-07 | Sharing **MUST** sepenuhnya opsional dan **MUST NOT** jadi prasyarat penghargaan apa pun. | P0 | v1 |

### 5.12 Survei recall — `FR-SURV`

Ini alat ukur untuk hipotesis inti produk. Dia bukan pelengkap.

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-SURV-01 | Saat selesai, app **MUST** menyajikan satu pertanyaan teks bebas yang meminta user menceritakan ulang kisah quest dengan kata-katanya sendiri. | P0 | v1 |
| FR-SURV-02 | Survei **MUST** bisa dilewati. | P0 | v1 |
| FR-SURV-03 | Respons **MUST** disimpan lokal sebelum pengiriman apa pun dicoba, dan **MUST** diantrekan untuk pengiriman nanti bila offline. | P0 | v1 |
| FR-SURV-04 | Survei **MUST** disajikan sebelum langkah share, supaya membatalkan share tidak menghilangkan responsnya. | P1 | v1 |
| FR-SURV-05 | User **MUST** diberi tahu respons ini dipakai untuk apa dan bahwa dia anonim. | P0 | v1 |

### 5.13 Settings — `FR-SET`

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-SET-01 | Settings **MUST** menampilkan: bahasa, status izin lokasi dengan tautan ke pengaturan sistem, storage terpakai, dan kontrol untuk menghapus semua data lokal. | P0 | v1 |
| FR-SET-02 | Menghapus semua data lokal **MUST** membuang Run, foto, refleksi, penghargaan, dan telemetri yang mengantre, dan **MUST** butuh konfirmasi. | P0 | v1 |
| FR-SET-03 | Settings **MUST** menampilkan atribusi ke sumber komunitas dan kontributor konten. | P0 | v1 |
| FR-SET-04 | Settings **MUST** menyediakan cara melaporkan kesalahan faktual atau keberatan tentang sebuah Place. | P0 | v1 |

### 5.14 Quest proximity alert dan Apple Watch — `FR-PROX`, `FR-WATCH`

User melewati Puri Agung Pemecutan tanpa tahu ada quest yang dimulai di sana. HP tetap di kantong; jam tangan bergetar; dia melihat dan jadi tahu. Ini jalur penemuan untuk traveler yang tidak merencanakan jalan-jalannya dari awal — kebalikan dari jalur preview-dari-hotel, dan dia menjangkau orang yang tidak akan pernah dijangkau daftar quest.

Di v1 dibatasi pada **titik start quest saja**, bukan checkpoint tengah. Selama Run aktif user sudah terlibat dan memang membuka app di tiap checkpoint sesuai desain (AD-1).

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-PROX-01 | App **MUST** memberi tahu user saat dia memasuki `proximity_radius_m` dari titik start sebuah quest yang belum dia selesaikan, selagi app tidak terbuka. | P0 | v1 |
| FR-PROX-02 | Pemantauan proximity **MUST** mencakup titik start quest saja. Checkpoint tengah **MUST NOT** dipantau di v1. | P0 | v1 |
| FR-PROX-03 | Fitur ini **MUST** opt-in dengan default mati, dan **MUST** menyajikan penjelasan berbahasa sederhana tentang apa yang dia lakukan dan izin apa yang dia butuhkan sebelum prompt sistem mana pun. | P0 | v1 |
| FR-PROX-04 | Implementasi **MUST** memakai region monitoring. Background location update terus-menerus **MUST NOT** dipakai. | P0 | v1 |
| FR-PROX-05 | Bila iOS hanya memberi `When In Use` alih-alih `Always`, fitur ini **MUST** mematikan dirinya sendiri, mengatakannya terus terang, dan menawarkan jalan ke Settings. Setiap fitur lain **MUST** tidak terpengaruh. | P0 | v1 |
| FR-PROX-06 | Alert **MUST** dikirim sebagai local notification, supaya sistem meneruskannya ke Apple Watch yang terpasang sebagai haptic. Dia **MUST NOT** mensyaratkan aplikasi watch terpasang, berjalan, atau terjangkau. | P0 | v1 |
| FR-PROX-07 | Notifikasi **MUST** menyebut nama quest dan Place, dan mengetuknya **MUST** membuka preview quest tersebut. | P0 | v1 |
| FR-PROX-08 | Proximity alert **MUST NOT** menyala untuk quest yang sudah user selesaikan, dan **MUST NOT** menyala sama sekali selagi ada Run yang aktif. | P0 | v1 |
| FR-PROX-09 | Alert **MUST** dibatasi rate-nya: maksimal sekali per quest per 24 jam, dan maksimal 3 total per hari. | P0 | v1 |
| FR-PROX-10 | Alert **MUST NOT** menyala antara pukul 22:00 dan 07:00 waktu setempat. | P0 | v1 |
| FR-PROX-11 | `proximity_radius_m` **MUST** lebih besar dari `arrival_radius_m` checkpoint start — intinya peringatan saat mendekat, bukan konfirmasi di gerbang — dan **MUST** bisa dituning per quest lewat konten. | P0 | v1 |
| FR-PROX-12 | Region untuk quest yang tertekan (AD-5) **MUST** dicabut pendaftarannya pada launch berikutnya. | P0 | v1 |
| FR-PROX-13 | Mematikan fitur ini **MUST** langsung mencabut pendaftaran semua region yang dipantau. | P0 | v1 |
| FR-PROX-14 | iOS membatasi satu app pada 20 region yang dipantau. Sejak rilis di mana jumlah quest bisa melampaui itu, app **MUST** mendaftarkan hanya region terdekat, dihitung ulang dari lokasi kasar, alih-alih gagal diam-diam di batas tersebut. | P0 | v3 |
| FR-PROX-15 | Masuknya region **MUST** ditangani sepenuhnya di perangkat. Proximity alert **MUST NOT** dipicu oleh server atau dikirim sebagai remote push. | P0 | v1 |
| FR-WATCH-01 | Dukungan watch di v1 **MUST** dibatasi pada menerima notifikasi yang diteruskan beserta haptic-nya. Aplikasi watchOS mandiri **MUST NOT** disyaratkan. | P0 | v1 |
| FR-WATCH-02 | App **MUST** berfungsi penuh untuk user tanpa Apple Watch. Jam tangan adalah tambahan, tidak pernah ketergantungan. | P0 | v1 |
| FR-WATCH-03 | Pendamping watchOS yang mengirim haptic kedatangan checkpoint selama Run aktif, supaya HP bisa tetap di kantong sepanjang perjalanan. | P2 | v2 |

### 5.15 Area fungsional pasca-MVP

Dinyatakan di level requirement supaya v1 tidak menutup jalannya, bukan dispesifikasikan penuh.

| ID | Requirement | Pri | Rel |
|---|---|---|---|
| FR-ALERT-01 | History Alert **MUST** opt-in dengan default mati, dan **MUST** menyajikan nilainya sebelum prompt izin apa pun. | P0 | v2 |
| FR-ALERT-02 | History Alert **MUST** dibatasi maksimal 2 notifikasi per hari dan **MUST NOT** menyala selama Run aktif. | P0 | v2 |
| FR-ALERT-03 | History Alert **MUST** berfungsi hanya di wilayah tempat user pernah membuka app. | P0 | v2 |
| FR-ALERT-04 | Menolak background location **MUST NOT** menurunkan fitur lain mana pun. | P0 | v2 |
| FR-ACC-01 | Sign in with Apple **MUST** opsional; app **MUST** tetap berfungsi penuh tanpa akun. | P0 | v2 |
| FR-SYNC-01 | Sync **MUST** berupa rekonsiliasi latar belakang di atas store lokal, tidak pernah aksi simpan yang menghadap user. | P0 | v2 |
| FR-SYNC-02 | Konflik **MUST** diselesaikan dengan memenangkan perangkat yang menulis konten tersebut. | P0 | v2 |
| FR-SYNC-03 | Apakah foto ikut disinkronkan, dan lewat jenis jaringan mana, **MUST** jadi pilihan eksplisit user, dengan default hanya Wi-Fi. | P0 | v2 |
| FR-CMS-01 | Mempublikasikan Place **MUST** diblokir oleh CMS kecuali ada ConsentRecord dengan `status = granted` dan `expires_at` yang belum lewat. | P0 | v3 |
| FR-CMS-02 | Mempublikasikan Quest **MUST** diblokir kecuali jarak totalnya diturunkan dari walking directions asli dan checklist validasi lapangan sudah lengkap. | P0 | v3 |
| FR-CMS-03 | Konten **MUST** ber-versi sedemikian rupa sehingga koreksi bisa dipublikasikan dan sampai ke perangkat tanpa rilis app. | P0 | v3 |

---

## 6. Perilaku error, edge, dan kegagalan

Board alur yang asli hanya mencakup jalur bahagia. Ini requirement, bukan saran.

| ID | Kondisi | Perilaku yang diwajibkan | Pri |
|---|---|---|---|
| FR-ERR-01 | Tidak ada fix GPS yang layak di checkpoint | Status langsung plus override manual setelah 60 detik (FR-ARR-03). Tidak pernah spinner tanpa batas. | P0 |
| FR-ERR-02 | Izin lokasi ditolak di tengah Run | Jelaskan, tawarkan Settings, dan biarkan Run lanjut lewat override manual. Run **MUST NOT** dihancurkan. | P0 |
| FR-ERR-03 | Izin kamera ditolak | Task jatuh ke pemilihan dari galeri, lalu ke skip. | P0 |
| FR-ERR-04 | Storage penuh saat menyimpan foto | Simpan arrival dan teks lebih dulu, laporkan kegagalan foto secara spesifik, jaga Run tetap utuh. | P0 |
| FR-ERR-05 | Baterai perangkat kritis | Tidak butuh penanganan khusus, karena state disimpan terus-menerus (FR-RUN-01). | P1 |
| FR-ERR-06 | Situs tutup atau sedang dipakai upacara saat tiba | App tidak bisa mendeteksi ini. Dia **MUST** menyediakan jalur "situs tidak tersedia" yang tetap memberi stamp, menampilkan lore, melewati task yang bergantung tempat, dan melanjutkan Run. | P0 |
| FR-ERR-07 | User tiba di luar urutan | Nyatakan checkpoint mana yang diharapkan; jangan majukan (FR-ARR-06). | P0 |
| FR-ERR-08 | User memulai quest jauh dari wilayahnya | Preview tetap tersedia; start tetap digerbangi arrival. Tidak ada error khusus. | P1 |
| FR-ERR-09 | Pengambilan kill-switch gagal | Diam-diam pertahankan state cache terakhir. Jangan pernah blokir launch. | P0 |
| FR-ERR-10 | Antrean telemetri melewati batas | Buang event analytics tertua lebih dulu; respons survei dan konten user **MUST** tidak pernah dibuang. | P0 |

---

## 7. Non-functional requirements

### 7.1 Performa — `NFR-PERF`

Perangkat acuan untuk semua target: iPhone 12, iOS pada versi minimum yang didukung, kondisi cold.

| ID | Requirement | Pri |
|---|---|---|
| NFR-PERF-01 | Cold launch sampai daftar quest interaktif **MUST** selesai dalam ≤ 2,0 detik. | P0 |
| NFR-PERF-02 | Preview quest **MUST** ter-render dalam ≤ 500 ms sejak ketukan. | P0 |
| NFR-PERF-03 | Layar lore **MUST** ter-render dalam ≤ 300 ms. | P0 |
| NFR-PERF-04 | Arrival **MUST** terdeteksi dalam 15 detik sejak memasuki radius dengan layar arrival terbuka dan langit terbuka. | P1 |
| NFR-PERF-05 | Komposisi share card **MUST** selesai dalam ≤ 3 detik untuk kartu 5 foto. | P1 |
| NFR-PERF-06 | Scroll di lore dan summary **MUST** menahan 60 fps di perangkat acuan. | P1 |
| NFR-PERF-07 | Ukuran terpasang dengan 2 quest ter-bundle **MUST** ≤ 250 MB. Konten di luar anggaran itu **MUST** dikompres atau dipotong, bukan dikirim. | P0 |

### 7.2 Keandalan dan integritas data — `NFR-REL`

| ID | Requirement | Pri |
|---|---|---|
| NFR-REL-01 | Nol kehilangan data saat force-quit atau crash untuk aksi apa pun yang sudah user selesaikan. | P0 |
| NFR-REL-02 | Tingkat sesi bebas crash **MUST** ≥ 99,5% sebelum peluncuran dianggap layak. | P0 |
| NFR-REL-03 | Menelusuri seluruh loop inti dalam mode pesawat **MUST** jadi bagian dari test suite rilis, dijalankan di perangkat fisik. | P0 |
| NFR-REL-04 | Record lokal yang korup atau tertulis separuh **MUST NOT** mencegah app diluncurkan; app **MUST** mengisolasi dan melaporkannya sambil tetap bisa dipakai. | P1 |
| NFR-REL-05 | Foto **MUST** disimpan di luar database app dan dirujuk, supaya kegagalan migrasi database tidak bisa menghancurkan foto user. | P0 |

### 7.3 Baterai dan penggunaan sumber daya — `NFR-BAT`

| ID | Requirement | Pri |
|---|---|---|
| NFR-BAT-01 | App **MUST NOT** memakai background location update terus-menerus di rilis mana pun. Background location dibatasi pada region monitoring untuk `FR-PROX`. | P0 |
| NFR-BAT-02 | Selama Run aktif dengan app di foreground, konsumsi baterai **MUST** ≤ 12% per jam di perangkat acuan. | P1 |
| NFR-BAT-03 | Akurasi lokasi **MUST** diturunkan saat user lebih dari 300 m dari checkpoint berikutnya, dan dinaikkan saat mendekat. | P1 |
| NFR-BAT-04 | Sampling lokasi **MUST** berhenti sepenuhnya saat layar arrival tidak terlihat. | P0 |
| NFR-BAT-05 | Region monitoring **MUST NOT** menghasilkan kenaikan konsumsi baterai standby yang terukur. Ini **MUST** diverifikasi lewat pengukuran selama 24 jam idle sebelum peluncuran, bukan diasumsikan. | P0 |
| NFR-BAT-06 | App **MUST NOT** melakukan kerja CPU atau network di background saat masuk region, di luar menjadwalkan local notification. | P0 |

### 7.4 Privasi dan perlindungan data — `NFR-PRIV`

Rezim yang berlaku adalah UU PDP No. 27/2022 Indonesia dan, untuk pengunjung Uni Eropa, GDPR. Postur lokal-saja v1 menjaga paparan tetap minimal; v2 mengubah ini secara material dan butuh tinjauannya sendiri.

| ID | Requirement | Pri |
|---|---|---|
| NFR-PRIV-01 | Di v1 app **MUST NOT** mengirim data lokasi, foto, atau teks refleksi keluar dari perangkat. | P0 |
| NFR-PRIV-02 | Analytics **MUST NOT** menyertakan koordinat mentah. Kedatangan checkpoint dilaporkan sebagai penanda checkpoint, tidak pernah sebagai posisi. | P0 |
| NFR-PRIV-03 | App **MUST NOT** memakai advertising identifier, cross-app tracking, atau SDK mana pun yang melakukannya. | P0 |
| NFR-PRIV-04 | App **MUST NOT** mengumpulkan nama, alamat email, nomor telepon, atau kontak di v1. | P0 |
| NFR-PRIV-05 | Respons survei **MUST** anonim dan **MUST NOT** bisa ditautkan ke seseorang, hanya ke sebuah Run anonim. | P0 |
| NFR-PRIV-06 | Satu kontrol tunggal **MUST** menghapus semua data user lokal (FR-SET-02). | P0 |
| NFR-PRIV-07 | Kebijakan privasi dan label privasi App Store **MUST** mencerminkan hal di atas secara akurat, dan **MUST** ditinjau ulang di v2 saat akun dan sync diperkenalkan. | P0 |
| NFR-PRIV-08 | Sejak v2, data user yang dikirim **MUST** terenkripsi saat transit, dan penghapusan akun **MUST** menghapus data sisi server dalam 30 hari. | P0 |
| NFR-PRIV-09 | Region monitoring **MUST** tetap sepenuhnya di perangkat. Masuknya region **MUST NOT** dicatat beserta koordinat, dikirim, atau dipakai membangun riwayat pergerakan. Satu-satunya catatan yang diizinkan adalah bahwa proximity alert untuk suatu quest pernah ditampilkan. | P0 |
| NFR-PRIV-10 | Kalimat tujuan izin `Always` **MUST** menjelaskan satu penggunaan yang sebenarnya — memberi tahu user saat dekat titik start quest — dan **MUST NOT** mengklaim tujuan yang lebih luas. | P0 |

### 7.5 Keamanan — `NFR-SEC`

| ID | Requirement | Pri |
|---|---|---|
| NFR-SEC-01 | Endpoint kill-switch (AD-5) **MUST** diambil lewat TLS dan responsnya **MUST** divalidasi terhadap schema sebelum dipakai. | P0 |
| NFR-SEC-02 | Respons kill-switch yang cacat atau berniat jahat **MUST** dibuang demi state baik terakhir yang diketahui. | P0 |
| NFR-SEC-03 | App **MUST NOT** mengirim secret, API key, atau kredensial di dalam bundle. | P0 |
| NFR-SEC-04 | Sejak v2, autentikasi **MUST** memakai Sign in with Apple; app **MUST NOT** menangani kata sandi. | P0 |

### 7.6 Aksesibilitas — `NFR-A11Y`

| ID | Requirement | Pri |
|---|---|---|
| NFR-A11Y-01 | Semua teks **MUST** mendukung Dynamic Type sampai ukuran aksesibilitas terbesar tanpa terpotong atau tumpang tindih. Lore adalah bacaan panjang; ini bukan opsional. | P0 |
| NFR-A11Y-02 | Semua elemen interaktif **MUST** membawa label VoiceOver, dan seluruh loop inti **MUST** bisa diselesaikan dengan VoiceOver. | P0 |
| NFR-A11Y-03 | Teks isi **MUST** memenuhi rasio kontras minimal 4,5:1, dan teks besar minimal 3:1. **Arah visual "surat kerajaan" berkertas tua berisiko langsung di sini** — teks sepia di atas perkamen sepia rutin gagal. Temanya **MUST** disesuaikan agar memenuhi kontras, bukan sebaliknya. | P0 |
| NFR-A11Y-04 | Reduce Motion **MUST** dihormati; tidak ada informasi esensial yang boleh disampaikan hanya lewat animasi. | P0 |
| NFR-A11Y-05 | Warna **MUST NOT** jadi satu-satunya pembawa makna, termasuk untuk label akurasi (FR-CP-05). | P0 |
| NFR-A11Y-06 | Target ketuk **MUST** minimal 44×44 pt. | P0 |
| NFR-A11Y-07 | Preview quest **MUST** mengungkap jarak, medan, tangga, dan permukaan cukup jujur agar user dengan keterbatasan mobilitas bisa menilai sendiri. Produk **MUST NOT** disajikan sebagai bisa diakses siapa saja. | P0 |
| NFR-A11Y-08 | Varian rute lebih pendek atau bebas tangga. | P2 (v5) |

### 7.7 Lokalisasi — `NFR-I18N`

| ID | Requirement | Pri |
|---|---|---|
| NFR-I18N-01 | Semua string yang menghadap user **MUST** dieksternalkan; tidak ada yang di-hardcode. | P0 |
| NFR-I18N-02 | Bahasa Indonesia dan Inggris **MUST** setara penuh. Sebuah quest **MUST NOT** dirilis dengan satu bahasa lengkap dan yang lain sebagian. | P0 |
| NFR-I18N-03 | App **MUST NOT** mencampur bahasa di dalam satu bagian lore dalam kondisi fallback apa pun. | P0 |
| NFR-I18N-04 | Nama Place **MUST** selalu dirender dalam bentuk lokal resminya terlepas dari bahasa antarmuka. Penerjemahan berlaku untuk narasi, tidak pernah untuk nama sebuah tempat. | P0 |
| NFR-I18N-05 | Jarak **MUST** memakai satuan metrik. Waktu **MUST** memakai konvensi 12/24 jam perangkat. | P1 |
| NFR-I18N-06 | Konten dan string antarmuka **MUST** diberi versi bersamaan, supaya pembaruan konten tidak bisa lepas sinkron dari antarmukanya. | P1 |

### 7.8 Standar konten dan editorial — `NFR-CONT`

Ini requirement produk karena melanggarnya merusak klaim utama produk: bahwa informasinya bisa dipercaya.

| ID | Requirement | Pri |
|---|---|---|
| NFR-CONT-01 | Setiap klaim faktual **MUST** diklasifikasikan sebagai sejarah tercatat atau tradisi lisan, dan dirender dengan klasifikasi itu terlihat (FR-CP-05). | P0 |
| NFR-CONT-02 | Lore tiap checkpoint **MUST** mengutip minimal satu sumber, yang bisa dicapai di dalam app. | P0 |
| NFR-CONT-03 | Klaim yang butuh verifikasi lapangan — jam buka, aturan berpakaian, aturan fotografi, detail arsitektur spesifik yang dipakai dalam task, ejaan resmi — **MUST NOT** dirilis sebelum diverifikasi di lokasi. Riset meja saja tidak cukup. | P0 |
| NFR-CONT-04 | Bila sumber berbeda soal ejaan sebuah nama, bentuk yang dipakai badan pengelola **MUST** jadi acuan; varian **MAY** dicatat. | P1 |
| NFR-CONT-05 | Jarak rute **MUST** diturunkan dari walking directions asli, bukan haversine dengan buffer. | P0 |
| NFR-CONT-06 | Estimasi durasi **MUST** menyatakan waktu jalan dan waktu quest total sebagai angka terpisah. | P0 |
| NFR-CONT-07 | Proses koreksi faktual **MUST** ada sebelum peluncuran, dengan pemilik yang jelas dan target waktu penyelesaian. Di v1 ini mau tidak mau melibatkan rilis app; targetnya **MUST** dinyatakan jujur kepada user yang melaporkan kesalahan. | P0 |

### 7.9 Tata kelola budaya — `NFR-GOV`

Risiko berdampak tertinggi pada produk ini bukan risiko teknis.

| ID | Requirement | Pri |
|---|---|---|
| NFR-GOV-01 | Tidak ada Place yang **MUST** dirilis dalam Quest mana pun tanpa ConsentRecord dengan `status = granted`. | P0 |
| NFR-GOV-02 | ConsentRecord **MUST** menyebut badan yang memberi izin, individu yang memberikannya, jabatannya, tanggalnya, dan cakupan apa yang diizinkan. | P0 |
| NFR-GOV-03 | Izin **MUST** dikonfirmasi ulang minimal setahun sekali, dan masa berlakunya **MUST** dilacak. | P0 |
| NFR-GOV-04 | Penarikan izin **MUST** bisa ditindaklanjuti dalam 24 jam lewat kill-switch (AD-5), tanpa rilis app. | P0 |
| NFR-GOV-05 | Sumber komunitas — organisasi, juru kunci, pemangku, storyteller — **MUST** dikreditkan di dalam app. | P0 |
| NFR-GOV-06 | Di Place dengan `is_sacred = true`, mekanik ala permainan **MUST NOT** dipakai (FR-TASK-05). Kendala ini mengalahkan metrik engagement dan **MUST NOT** dilonggarkan atas dasar hasil A/B. | P0 |
| NFR-GOV-07 | Satu individu bernama **MUST** memiliki hubungan komunitas untuk tiap wilayah, dan kepemilikan ini **MUST** didokumentasikan alih-alih tersirat. | P0 |
| NFR-GOV-08 | Sejak v4, konten kontribusi **MUST** melewati gerbang izin dan akurasi yang sama dengan konten first-party. | P0 (v4) |

### 7.10 Keselamatan fisik — `NFR-SAFE`

| ID | Requirement | Pri |
|---|---|---|
| NFR-SAFE-01 | App **MUST NOT** mengirim instruksi turn-by-turn selagi user sedang berjalan (FR-MAP-03). | P0 |
| NFR-SAFE-02 | Clue **MUST** ditulis untuk dibaca sekali, saat berhenti, lalu diingat — cukup pendek untuk diikuti tanpa dibaca ulang di tengah jalan. | P0 |
| NFR-SAFE-03 | Peringatan keselamatan **MUST** dikonfirmasi sebelum Run pertama tiap quest, mencakup lalu lintas, trotoar sempit, dan model kantongi-HP. | P0 |
| NFR-SAFE-04 | Posisi checkpoint **MUST** dipilih saat validasi lapangan sebagai tempat di mana orang bisa berdiri diam dan membaca dengan aman. | P0 |
| NFR-SAFE-05 | Tidak ada task yang **MUST** mengharuskan user berdiri di badan jalan, menghalangi jalur pejalan kaki, atau memasuki area terlarang. | P0 |

### 7.11 Observabilitas — `NFR-OBS`

| ID | Requirement | Pri |
|---|---|---|
| NFR-OBS-01 | Setiap metrik di tabel Metrik Keberhasilan **MUST** punya event terinstrumentasi yang bersesuaian sebelum peluncuran. Metrik yang tidak terinstrumentasi bukan metrik. | P0 |
| NFR-OBS-02 | Event **MUST** disimpan lokal dan dikirim oportunistik; tidak ada event yang boleh hilang karena request gagal. | P0 |
| NFR-OBS-03 | Antrean lokal **MUST** dibatasi — 30 hari atau 10.000 event — membuang analytics tertua lebih dulu dan tidak pernah membuang respons survei atau konten user. | P0 |
| NFR-OBS-04 | Schema event **MUST** diberi versi. | P1 |
| NFR-OBS-05 | Laporan crash **MUST** ditangkap offline dan dikirim belakangan. | P0 |
| NFR-OBS-06 | Kedatangan, kepergian, dwell time, dan penggunaan override manual per checkpoint **MUST** diinstrumentasi, karena drop-off di level checkpoint adalah cara v1 didiagnosis. | P0 |

### 7.12 Platform dan kompatibilitas — `NFR-PLAT`

| ID | Requirement | Pri |
|---|---|---|
| NFR-PLAT-01 | Versi iOS minimum — **TBD, butuh keputusan.** Ditentukan oleh ketersediaan SwiftData (iOS 17+) versus jangkauan. | P0 |
| NFR-PLAT-02 | App **MUST** mendukung iPhone dalam potret. iPad dan lanskap tidak diwajibkan di v1. | P0 |
| NFR-PLAT-03 | App **MUST** berfungsi di layar terkecil yang didukung tanpa pemotongan. | P0 |
| NFR-PLAT-04 | Mode gelap **MUST** didukung, termasuk tema kertas tua, tanpa melanggar NFR-A11Y-03. | P1 |
| NFR-PLAT-05 | Dukungan Apple Watch di v1 tidak butuh target watchOS — penerusan notifikasi adalah perilaku sistem. Karena itu versi watchOS minimum **MUST NOT** dideklarasikan di v1. | P0 |
| NFR-PLAT-06 | Penerusan notifikasi ke jam tangan hanya terjadi saat iPhone terkunci dan jam tangan dipakai serta tidak terkunci. Fitur ini **MUST** dijelaskan ke user dalam istilah itu, bukan sebagai jaminan. | P0 |

### 7.13 Kemudahan pemeliharaan dan operasi konten — `NFR-MAINT`

| ID | Requirement | Pri |
|---|---|---|
| NFR-MAINT-01 | Menambah quest **MUST NOT** butuh perubahan kode. Konten adalah data sejak v1, bahkan selagi masih di-bundle. | P0 |
| NFR-MAINT-02 | Konten **MUST** divalidasi saat build terhadap schema, dan build **MUST** gagal bila ada referensi izin yang hilang, sumber yang hilang, label akurasi yang hilang, atau bahasa yang bolong. | P0 |
| NFR-MAINT-03 | Jam produksi riil per quest **MUST** dicatat, karena angka itulah yang menentukan apakah strategi skala konten v3 layak. | P0 |
| NFR-MAINT-04 | Schema lokal v1 **MUST** membawa UUID yang digenerate perangkat dan timestamp di semua record user, supaya sync v2 tidak butuh migrasi identitas. | P0 |

---

## 8. Kriteria penerimaan rilis

v1 belum layak dirilis sampai semua hal berikut terpenuhi. Ini gerbang, bukan cita-cita.

1. Kedua quest punya ConsentRecord lengkap untuk tiap Place, dengan nama pemberi izin. *(NFR-GOV-01, 02)*
2. Kedua rute sudah ditempuh ujung ke ujung, dengan jarak dari walking directions asli dan semua klaim yang bisa diverifikasi lapangan sudah dikonfirmasi di lokasi. *(NFR-CONT-03, 05)*
3. Konten lolos validasi schema saat build tanpa satu pun sumber, label akurasi, atau terjemahan yang hilang. *(NFR-MAINT-02, NFR-I18N-02)*
4. Loop inti lengkap sudah ditelusuri dalam mode pesawat di perangkat fisik. *(NFR-REL-03)*
5. Loop inti lengkap sudah ditelusuri dengan VoiceOver dan pada ukuran Dynamic Type terbesar. *(NFR-A11Y-01, 02)*
6. Kontras sudah diukur pada tema visual final dan memenuhi 4,5:1 untuk teks isi. *(NFR-A11Y-03)*
7. Setiap Metrik Keberhasilan punya event yang menyala dan terverifikasi. *(NFR-OBS-01)*
8. Kill-switch sudah diuji ujung ke ujung: tekan satu Place, konfirmasi penghapusannya pada launch berikutnya, konfirmasi kegagalan yang anggun saat endpoint tidak terjangkau. *(AD-5, FR-ERR-09)*
9. Force-quit di setiap transisi state tidak menghilangkan apa pun. *(NFR-REL-01)*
10. Label privasi dan kebijakan cocok dengan perilaku sebenarnya. *(NFR-PRIV-07, NFR-PRIV-10)*
11. Proximity alert terverifikasi di lapangan: menyala saat memasuki radius start quest asli dengan app tertutup dan HP terkunci, menghasilkan haptic di jam tangan yang terpasang, membuka preview yang benar saat diketuk, menghormati jam tenang dan batas rate, mematikan diri dengan bersih saat `Always` ditolak, dan mencabut semua region saat dimatikan. *(FR-PROX-01…13)*
12. Baterai standby diukur selama 24 jam dengan pemantauan proximity menyala tidak menunjukkan kemunduran berarti dibanding saat dimatikan. *(NFR-BAT-05)*
13. Memulai quest dari luar radius start terbukti tidak mungkin lewat setiap jalur yang diuji, termasuk override manual, yang membutuhkan konfirmasi keberadaan. *(FR-START-08, 09)*

---

## 9. Traceability

Setiap area fungsional P0 ada untuk melayani hipotesis atau melindungi dari risiko yang disebutkan. Requirement yang tidak melayani keduanya adalah kandidat untuk dipotong.

| Grup requirement | Melayani |
|---|---|
| FR-DISC, FR-CP, FR-TASK, FR-DONE | Hipotesis inti: apakah narasi terhubung menghasilkan penyelesaian dan ingatan |
| FR-PROX, FR-WATCH | Penemuan untuk traveler yang tidak merencanakan jalannya — menjangkau user yang tidak akan pernah dijangkau daftar quest, sambil menjaga HP tetap di kantong |
| FR-SURV, NFR-OBS | Mengukur hipotesis — tanpa ini, v1 tidak menghasilkan vonis |
| FR-ARR, FR-ERR, FR-MAP, FR-OFF | Risiko: GPS tidak andal, peta kosong offline, sinyal tidak ada di checkpoint riil |
| FR-RUN, NFR-REL | Risiko: kehilangan perjalanan user karena crash atau baterai habis |
| NFR-GOV, FR-TASK-05, FR-SHARE-05, AD-5 | Risiko: situs sakral keberatan digamifikasi — berperingkat Kritis |
| NFR-CONT, FR-CP-05, FR-CP-06 | Risiko: klaim sejarah dibantah; dan klaim produk sendiri untuk bisa dipercaya |
| NFR-SAFE, AD-1, FR-MAP-03 | Risiko: cedera pejalan kaki — berperingkat Kritis |
| NFR-A11Y | Risiko: eksklusi aksesibilitas |
| FR-DISC-05, FR-DISC-06, FR-ERR-06 | Risiko: biaya tak terduga, situs tutup di tengah quest |
| AD-3, AD-4, NFR-MAINT-04, FR-OFF-04 | Risiko: offline-first hilang saat migrasi CMS v3 |

---

## 10. Pertanyaan terbuka yang dibawa ke implementasi

Tidak berubah dari PRD ramping kecuali dicatat. Ini memblokir requirement tertentu, bukan dokumen secara keseluruhan.

- Dua rute mana yang dirilis — memblokir persetujuan NFR-GOV-01 dan seluruh kerja konten.
- Versi iOS minimum — memblokir NFR-PLAT-01 dan keputusan SwiftData.
- Pendekatan rendering peta offline — memblokir FR-MAP-01. Kandidat: gambar rute statis yang di-render duluan untuk preview, kanvas rute-dan-pin kustom selama Run, atau MapLibre dengan vector tile yang di-cache.
- Kebijakan retensi draft — memblokir FR-RUN-05, sementara diselesaikan secara konservatif sebagai "jangan pernah menghapus".
- Rubrik koding survei recall — memblokir separuh analisis dari FR-SURV, dibutuhkan sebelum peluncuran, bukan sesudahnya.
- Hosting dan kepemilikan kill-switch — memblokir AD-5. Ukurannya kecil, tapi dia butuh pemilik dan ekspektasi uptime.
- Nama app dan branding — memblokir pengiriman ke App Store.
- Jam produksi riil per quest — memblokir keputusan v3, hanya bisa dijawab dengan memproduksi dua quest pertama.
- Nilai default `proximity_radius_m` — memblokir FR-PROX-11. 200 m adalah placeholder. Nilai yang tepat tergantung bagaimana pendekatannya benar-benar terasa di lapangan di tiap titik start, dan seberapa jauh traveler yang berjalan ingin diperingatkan; itu harus keluar dari validasi lapangan, bukan dari spreadsheet.
- Apakah proximity alert harus menyala untuk quest yang sudah user preview tapi belum mulai, secara lebih menonjol dibanding quest yang belum pernah dia lihat — tidak memblokir apa pun, tapi itulah beda antara pengingat dan penemuan.

---

*Status: DRAFT. Hanya functional dan non-functional requirements. Perencanaan implementasi berjalan lewat `/plan`.*
