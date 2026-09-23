# SFX: nama file yang ditunggu game

Taruh file di folder ini dengan nama **persis** seperti di bawah (.ogg / .wav / .mp3).
Tidak perlu mengubah kode. Kalau file belum ada, game tetap jalan tanpa suara.
Atur volume/variasi pitch per suara di `Scenes/sfx.gd` → `SOUNDS`.

| Nama file | Kapan bunyi |
|---|---|
| file_pickup | Dokumen diangkat (hold) |
| file_return | Dokumen dilepas di luar tray, balik ke meja |
| tray_hover | Dokumen yang dipegang masuk area tray |
| file_archive | Masuk tray Public Archive |
| file_truth | Masuk tray Department of Truth |
| file_incinerate | Masuk tray Incinerator |
| doc_open / doc_close | Dokumen dibuka / ditutup |
| marker_down | Spidol menyentuh kertas |
| marker_loop | Suara coretan, diulang selama menggambar (bergantian **highlighter** / **highlighter-2**) |
| shift_begin | Tombol BEGIN SHIFT |
| ending_reveal | Stinger ending (cadangan untuk semua ending) |
| ending_loyalist / _liability / _paranoid / _zealot | Stinger khusus per ending (opsional) |
| clock_out | Tombol CLOCK OUT |
| ui_hover / ui_click | Hover / klik tombol main menu |
| slot_select | Klik slot di Record of Outcomes |
| page_flip | Buka/tutup Records (memakai FlippingPages.ogg) |

## Sudah tersambung ke file yang ada

| Id | File | Kapan |
|---|---|---|
| ambience_crickets | night-cricket-ambience.mp3 | Loop sepanjang shift, berhenti saat ending |
| door_knock | door-knocking.mp3 | Acak tiap 35–75 detik di ingame (atur `knock_min_sec`/`knock_max_sec` di node Main) |
| whisper | whisper.mp3 | Acak tiap 60–120 detik (`whisper_min_sec`/`whisper_max_sec`). Jarak minimal antar suara acak 10 detik (`ambient_min_gap_sec`) |
| case_arrive | paper-slide.mp3 | Case baru muncul di meja |
| slot_locked | error-sound.mp3 | Klik outcome yang belum unlock di Record of Outcomes |
| printer | printer.mp3 | Belum dipakai: panggil `SFX.play(&"printer")` saat mesin cetak dibuat |

Belum dipakai: thunder.mp3.

## Music (`Scenes/music.gd`)
menu → (main menu) The Lobotomy · ingame → (ingame) Art Of A Dead Man · ending → (ending 1) MELANCHOLIA (sementara untuk keempat ending). Pindah lagu otomatis dengan crossfade.
