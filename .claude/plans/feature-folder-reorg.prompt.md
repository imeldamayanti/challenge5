# Prompt untuk menjalankan plan di chat baru

Salin blok di bawah ini ke chat Claude Code yang baru, di dalam repo `/Users/imelda/Documents/Swift/5. Challenge 5/challenge5`.

---

Jalankan plan di `.claude/plans/feature-folder-reorg.plan.md`.

Baca plannya lengkap dulu sebelum menjalankan apa pun, lalu pakai skill
`superpowers:subagent-driven-development` — satu subagent baru per task, dan
berhenti untuk aku review di antara task.

Konteks yang tidak akan kamu temukan dari `git status` saja:

- Branch `master` lokalku TERTINGGAL 94 commit dari `origin/master`. JANGAN
  pakai isi working tree sekarang sebagai acuan. Task 0 sudah menyuruh
  `git fetch` lalu bikin branch `rapihin-struktur` dari `origin/master`.
  Jangan pull atau reset `master` lokalku.
- Ini repo tim, 3+ kontributor, 8 branch belum merge. Karena itu tiap task
  wajib commit sendiri-sendiri — jangan gabung jadi satu commit besar.
- `xcode-select` menunjuk ke CommandLineTools, jadi `swift test` polos gagal
  dengan `no such module 'Testing'`. Selalu pakai
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Aturan yang tidak boleh dilanggar:

1. Ini tugas MEMINDAHKAN FILE. Nol perubahan isi file `.swift`. Gate di tiap
   task mensyaratkan `git diff` menunjukkan `0 insertions(+), 0 deletions(-)`.
   Kalau ada satu baris kode berubah, berhenti dan lapor.
2. Jangan rename type, fungsi, property, atau enum case. Jangan pecah atau
   gabung file. Jangan hapus file APA PUN — termasuk dua file tak terpakai
   yang sudah tercatat di bagian Findings.
3. Jangan pernah mengedit `project.pbxproj` dengan tangan. Project ini pakai
   synchronized folder Xcode 16, jadi `git mv` sudah cukup. Kalau build gagal
   karena "Build input file cannot be found", asumsi itu salah — BERHENTI
   dan lapor, jangan tambal pbxproj.
4. Cuma app target (`challange-5/challange-5/`). Jangan sentuh `Packages/`,
   `hisplora Watch App/`, `challange-5Tests/`, `challange-5UITests/`.
5. Pakai daftar `git mv` PERSIS seperti yang tertulis di plan. Daftar itu
   sudah diverifikasi 116 file berbanding 116 file di disk, nol duplikat,
   nol yang terlewat. Jangan menurunkan ulang pemetaannya sendiri.
6. Kalau kamu menemukan sesuatu yang layak diperbaiki di tengah jalan —
   kode mati, nama aneh, file kegedean — CATAT saja di bagian Findings
   pada plan. Jangan perbaiki. Rapi dan benar itu dua pekerjaan berbeda.

Kalau ada langkah yang hasilnya tidak sesuai "Expected" di plan, berhenti dan
tanya aku. Jangan improvisasi supaya tetap jalan.

Mulai dari Task 0 dan tunggu approval-ku sebelum lanjut ke Task 1.
