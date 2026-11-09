-- idID_help.lua : Bahasa Indonesia text of the Help panel (one block per topic id, see UI/Panels/PanelHelp.lua)
local _, GT = ...
GT.locales = GT.locales or {}
GT.locales.idID = GT.locales.idID or {}
GT.helpText = GT.helpText or {}

-- topic tab captions
GT.locales.idID["Start"] = "Mulai"
GT.locales.idID["Panels"] = "Panel"
GT.locales.idID["Tips"] = "Tips"
GT.locales.idID["HUD"] = "HUD"
GT.locales.idID["Cmds"] = "Perintah"
GT.locales.idID["Credits"] = "Kredit"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "HUD Minimap" .. E .. [[

Mengubah minimap sungguhan menjadi peta besar tembus pandang yang membentang di layar, dengan opsi lingkaran, huruf kompas, arah hadap, tampilan status siap terlebih dahulu dan progres rute. Pin pengumpulan tetap ditampilkan.

]] .. H .. "Aktifkan / nonaktifkan" .. E .. [[

- Klik kiri tombol HUD Minimap di jendela utama.
- Ketik /gt hud (atau /gthud).
- Gunakan tombol: Kontrol HUD > tab Peta > Pintasan tombol (klik tombol kunci, tekan tombol; Esc membatalkan, Hapus menghapusnya). Kontrol ini juga ada di Ikatan Tombol > AddOns > GatherTimes.
- Opsional: aktifkan agar HUD menyala otomatis saat pelacakan pengumpulan aktif (Kontrol HUD > Opsi).

]] .. H .. "Kontrol HUD (klik kanan tombol HUD)" .. E .. [[

- Peta: ukuran HUD, opasitas peta (0% = peta kosong dan hanya pin yang terlihat, 100% = buram; 10 tingkat), zoom minimap, pintasan tombol.
- Lingkaran: radius lingkaran, lingkaran kedua, ketebalan, kehalusan, gaya lingkaran (garis, garis-garis, atau titik: tombol menggilir pilihannya), kepadatan lingkaran, warna lingkaran (Warna lingkaran... membuka pemilih: penggeser untuk setiap lingkaran dan tombol Warna acak untuk tab lingkaran yang terbuka), huruf kompas (N E S W), tampilan arah hadap, tampilan pengumpulan siap-terlebih-dahulu (node siap terdekat, atau respawn terdekat), serta tampilan progres rute (langkah rute terencana saat ini). Setiap tampilan dapat diaktifkan atau dinonaktifkan.
- Pelacakan: tombol pelacakan saat HUD aktif (ukuran 20-80 px dan posisi) dan fungsinya saat HUD nonaktif (auto, own, atau stock).
- Opsi: putar peta bersama pemain, panah pemain, sembunyikan HUD saat sedang menunggang, aktifkan otomatis bersama pelacakan pengumpulan, pulihkan HUD setelah /reload atau login, sembunyikan skin addon minimap, diagnostik.
- Profil: simpan beberapa tampilan, beralih atau hapus. Profil digunakan bersama semua karakter; setiap karakter mengingat profilnya sendiri.
- Atur ulang profil memulihkan nilai default.]]

T.credits = H .. "GatherTimes 0.24.2" .. E .. [[

Penulis: miRidinsa
Situs web: https://github.com/ridinsa/
Lisensi: GNU GPL v3 atau lebih baru (lihat file LICENSE di folder addon).

]] .. H .. "Pustaka" .. E .. [[

- HereBeDragons-2.0 dan HereBeDragons-Pins-2.0 oleh Nevcairiel: posisi pin di minimap dan peta dunia.
- LibStub dan CallbackHandler-1.0 (pustaka WoW Ace): pemuatan pustaka dan callback.

]] .. H .. "Nama Acak" .. E .. [[

Salinan modul HideUnitNames yang disertakan (addon mandiri dengan nama yang sama juga didukung: saat dimuat, salinan ini menonaktifkan diri).

]] .. H .. "Addon pendukung" .. E .. [[

- HereBeDragons: diperlukan untuk pin.
- GatherMate2: data node-nya dapat diimpor.
- TomTom: waypoint untuk panah dan rute.

]] .. H .. "Terjemahan" .. E .. [[

File bahasa di folder Locales. Terima kasih kepada semua yang membantu menerjemahkannya dan kepada semua yang mengirim laporan debug.]]

T.start = H .. "Selamat datang di GatherTimes" .. E .. [[

Melacak kapan herbal dan bijih muncul kembali di zona tempat kamu berada, mengingat tempat node muncul, dan menampilkannya di jendela utama, minimap, dan peta dunia.

]] .. H .. "Mulai cepat" .. E .. [[

1. Buka jendela dengan /gt.
2. Klik Node (di bawah) dan centang herbal / bijih yang kamu kumpulkan.
3. Kumpulkan. Timer mulai begitu kamu mengambil loot dari sebuah node.
4. Lihat tabel di jendela utama. Saat node siap, kamu mendapat peringatan di layar, suara, dan bunyi lonceng saat kamu dekat.

]] .. H .. "Jendela utama" .. E .. [[

- Dropdown (atas): tampilkan setiap node yang dicentang, atau hanya satu.
- Jumlah inventaris tampil rata kanan di dropdown item yang terbuka; jumlah disembunyikan pada item yang tertutup dan dipilih.
- Tabel: satu baris per grup node yang berdekatan. G1, G2... adalah nomor grup yang juga kamu lihat di peta.
- Status: Waiting = semua node masih menghitung mundur. 2/3 up = sebagian sudah muncul. Ready = semua sudah muncul. Idle = tidak ada timer yang berjalan.
- Node tetap Ready untuk beberapa saat setelah muncul kembali, lalu menjadi Idle (kamu memilih berapa lama di Kontrol > Umum > Status Ready bertahan).
- Peringatan hanya dikirim sekali per timer. Gunakan Kontrol > Umum untuk jarak minimum / maksimum, dan Node > Alert untuk mengaktifkan atau membisukan peringatan tiap sumber daya.
- Tombol Minimap HUD On/Off: klik kiri untuk menyalakan / mematikan HUD, klik kanan untuk membuka pengaturan HUD. Teksnya hijau saat HUD menyala dan abu-abu saat mati.
- Label server dan mode permainan muncul di bawah tabel timer.
- Lima tombol di bawah membuka panel. Klik tombol yang sama lagi untuk menutup panelnya.
- Seret bilah judul untuk memindahkan jendela. Judulnya menampilkan zona tempat kamu berada.
- Tombol ? di bilah judul membuka bantuan ini.
- Tombol - di bilah judul memperkecil jendela menjadi bilah tipis di sepanjang bagian atas layar. Klik kanan untuk pengaturan Minimize. Di dalam bilah: dropdown item, satu chip per grup, emas sesi, dan tombol "+" untuk mengembalikan jendela. Klik kanan dua kali pada emas untuk mereset sesi (ringkasannya dicetak ke chat terlebih dahulu).

]]

T.panels = H .. "Timer" .. E .. [[

Setiap timer yang berjalan, yang sudah siap di urutan pertama (Grp, Node, Time), ditambah total sesi kamu. Clear waypoint menghapus panah. Show summary membuka ringkasan sesi (item, nilai emas, dan emas per jam) dalam kotak yang bisa kamu salin. Reset session mencetak ringkasan terlebih dahulu, lalu memulai ulang timer sesi dan menghapus hitungannya.

]] .. H .. "Node" .. E .. [[

Pilih apa yang dilacak dan bagaimana.
- On: centang untuk melacak sebuah herbal / bijih.
- Min: waktu muncul kembali dalam menit. Ketik angka baru lalu tekan Enter.
- Col: warna node di peta dan daftar. Klik kiri = warna berikutnya, klik kanan = warna sebelumnya.
- Alert: aktifkan atau bisukan peringatan siap untuk sumber daya ini. Pengecekan ini tidak bergantung pada apakah sumber daya tersebut sedang ditampilkan di dropdown utama.
- Sound: suara peringatan. Klik = berikutnya (memutar pratinjau), klik kanan = sebelumnya.
- Dropdown: Semua / Herbal / Ore. List all: tampilkan setiap node, bukan hanya yang ada di zona saat ini.
- Nodes per group: berapa node berdekatan yang membentuk satu grup (G1, G2...).
- Nodes up per group: berapa node yang harus sudah muncul sebelum grup dihitung siap.
- Select All, Select None, Reset (kembali ke waktu bawaan).
- Dropdown item yang terbuka di jendela utama juga menampilkan jumlah sumber daya itu di tasmu; tombol yang dipilih tidak menampilkan jumlah.

]] .. H .. "Navigasi" .. E .. [[

- Rute: pilih satu herbal / bijih yang aktif atau semua sumber daya yang aktif, lalu Build route untuk membuat jalur melalui timer yang berjalan. Next step berpindah ke langkah berikutnya, Clear route menghapus jalur. Opsinya meliputi hanya node yang siap, menggambar di peta, panah otomatis, jumlah node maksimum, dan rentang waktu. Prioritaskan sumber daya dengan stok rendah untuk mengutamakan sumber daya di bawah target stok (hanya tas).
- Penanda: tampilkan pin spawn di peta dan minimap, tampilkan label grup (G1, G2...), titik untuk item lain, sembunyikan titik yang sudah dikumpulkan dalam sesi ini, klik kanan titik untuk menu grup, offset node saat mengumpulkan, dan Refresh pins. Filter titik yang sudah dikumpulkan direset saat kamu mereset sesi.
- Panah: integrasi TomTom, panah ke node terdekat, pindah otomatis ke node berikutnya dalam route, jarak panah, Waypoint to nearest. Membutuhkan addon TomTom.

]] .. H .. "Waktu" .. E .. [[

Per node: Now = waktu muncul kembali yang sedang dipakai. Learned (n) = rentang yang diukur dari kunjunganmu sendiri, yang tercepat-tipikal (misalnya 10.5-12.0), n = jumlah sampel (oranye di bawah 5, kuning 5-9, hijau 10+; waktu learned hijau berarti nilai tipikalnya lebih cepat dari Now; * = nilai satu item yang ditampilkan dalam mode Per zone). Waktu muncul kembali bervariasi, jadi perkirakan berada dalam rentang itu. Apply / auto-apply memakai nilai tipikal (sebelah kanan). Taken = seberapa sering sebuah titik ditemukan kosong.
- Learned times: Per item (satu waktu learned per herbal / bijih, bawaan) atau Per zone (zona tempatmu berada setelah memiliki 5 sampel).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (lebih pendek atau lebih panjang, tidak lebih dari dua kali waktu bawaan). Sakelar zona ada di Kontrol > Umum.
- Apply all faster menyalin waktu learned ke Now. Reset learned timings menghapusnya.

]] .. H .. "Kontrol" .. E .. [[

- Umum: peringatan di layar dan Alert time, jarak peringatan siap minimum dan maksimum (0 menonaktifkan batas itu), peringatan saat chat mengumumkan pemeliharaan (warna kedip 1-7), peringatan kesehatan rendah (Hardcore), Status Ready bertahan, dan Hanya tampilkan timer dan pin di zona tempatku berada.
- Tampilan: ukuran teks peta, ukuran jendela, transparan saat digerakkan, jaga jendela tetap terlihat (ESC tidak menutupnya), dan tooltip item saat disorot. Dropdown bahasa ada di Tampilan > Look; berlaku setelah UI dimuat ulang (ditampilkan sebagai "w/reload").
- Look: Bahasa, Frame skin (tema warna untuk jendela dan tooltip; Pastel Pink dan Sakura memakai teks gelap dengan garis tipis), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, atau Friends jika klien memilikinya) dan Font size (80% sampai 130%). Korea, Tiongkok, Jepang dan Rusia memakai font sendiri, jadi pilihan font digantikan catatan untuk mereka.
- Alat: status addon dan pembantunya, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (berbagi titik dengan teman), Copy debug report (satu blok teks untuk laporan bug), Reset timers, Start a new session at login, dan log error.

]] .. H .. "Inventaris dan ringkasan sesi" .. E .. [[

Dropdown sumber daya yang terbuka menampilkan jumlah tas di samping setiap item; tombol item yang dipilih menyembunyikan jumlahnya. Panel Timer menampilkan total sesi. Show summary membuka ringkasan yang sama; Reset session mencetaknya terlebih dahulu, lalu menghapus hitungan dan memulai ulang jam sesi. Hanya loot pengumpulan yang dikenali yang dihitung. Reset session juga menghapus filter titik yang sudah dikumpulkan khusus sesi ini.

]] .. H .. "Nama Acak" .. E .. [[

Klik kanan tombol Kontrol di jendela utama untuk membukanya (klik kanan lagi untuk menutup). Fitur ini menyamarkan namamu sendiri di layarmu, untuk streaming atau screenshot. Pemain lain tetap melihat nama aslimu.
- Disguise names: menyalakan atau mematikan penyamaran. Saat aktif, nama pemain lain juga disembunyikan (lewat pengaturan nama permainan, dikembalikan saat kamu mematikannya).
- Hide party / raid names: menyembunyikan label nama party dan raid di layarmu secara terpisah.
- Fake player name / Fake pet name: nama yang ditampilkan sebagai gantinya. Ketik nama lalu tekan Enter atau Apply. Maksimal 12 karakter.
- Randomize Names: memilih nama acak baru dan level palsu. Penggeser Random level range menentukan level maksimum. Opacity memudarkan latar jendela sambil menjaga teksnya tetap terbaca.
- Ditampilkan pada: bingkai unitmu (juga saat kamu menargetkan dirimu sendiri atau pet), tooltip unit, judul jendela karakter, dan chat. Saat penyamaran aktif, nama karakter yang cocok juga disembunyikan di tooltip item.
- Perintah: /hun (mengaktifkan atau mematikan penyamaran), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Jika addon HideUnitNames mandiri dimuat, Nama Acak di sini dimatikan. Gunakan addon itu saja.

]]

T.tips = H .. "Grup" .. E .. [[

Node yang berdekatan diperlakukan sebagai satu grup, jadi kamu melihat kapan seluruh grup kembali, bukan setiap node satu per satu. Dengan One shared timer per group (panel Waktu), grup memiliki satu timer.

]] .. H .. "Memperbaiki sebuah titik (peta dunia)" .. E .. [[

Klik kanan teks timer atau pin titik di peta dunia untuk menu kecil (aktifkan di Navigasi > Penanda):
- Titik ini kosong: sudah diambil orang lain.
- Grup diambil orang lain: seluruh grup sudah dikumpulkan sebelumnya.
- Pindahkan titik ini ke grup: masukkan ke grup lain (1, 2, 3... atau New).
- Ketik catatan singkat dan klik Save note untuk menambahkan pengingat ke titik itu. Arahkan kursor ke titik untuk melihat catatannya. Catatan disimpan bersama titik.
Minimap tidak pernah membuka menu ini. Kamu bisa mematikannya di Navigasi > Penanda.

]] .. H .. "Cara respawn dipelajari" .. E .. [[

Setiap kali sebuah node sudah muncul kembali dan kamu mengambil lootnya, waktu sejak loot yang menjadi respawn-nya disimpan (dalam grup dengan beberapa node muncul bersamaan, itu adalah loot tertua dari yang terbaru, bukan yang paling baru). Addon mengabaikan jeda yang sangat pendek dan sangat panjang, lalu menampilkan nilai seperempat tercepat sampai median (tipikal) dari sampelmu, dibulatkan ke 15 detik, di Waktu. Apply dan auto-apply memakai median. Dibutuhkan 3 sampel untuk menampilkan nilai dan 5 untuk menerapkannya secara otomatis.

]] .. H .. "Berbagi titik dengan teman" .. E .. [[

Kontrol > Alat > Export my spots (atau /gt export) menampilkan titikmu sendiri sebagai satu baris teks. Klik kotaknya, tekan Ctrl+C, lalu kirim ke temanmu. Temanmu memakai Import spots (atau /gt import), menempelkannya dengan Ctrl+V, lalu klik Import. Hanya item, zona, dan posisi yang dibagikan, tanpa timer atau hitungan. Titik yang sudah kamu miliki dibiarkan, dan teks yang terpotong di tengah jalan ditolak daripada diimpor setengah-setengah.

]] .. H .. "Addon pembantu" .. E .. [[

- HereBeDragons: diperlukan untuk pin di peta dan minimap. Pasang addon ini.
- GatherMate2: Kontrol > Alat > Import GatherMate2 menambahkan lokasi node yang dikenalnya.
- TomTom: membuat panah dan waypoint jalur tampil.

]] .. H .. "Ada yang salah?" .. E .. [[

- Tidak ada pin: pasang HereBeDragons. Kontrol > Alat menampilkan apa yang ditemukan.
- Timer tidak mulai: ketik /gt debug lalu ambil loot dari sebuah node, addon akan mencetak apa yang dilihatnya.
- Error tercantum di Kontrol > Alat > Error log (klik, Ctrl+A, Ctrl+C untuk menyalin).
- Melaporkan masalah atau konflik dengan addon lain: Kontrol > Alat > Copy debug report (atau /gt report), salin teksnya dan tempel ke laporan.
- Titik atau grup salah: klik kanan di peta dunia.]]

T.cmds = H .. "Perintah slash" .. E .. [[

/gt - buka atau tutup jendela utama
/gt list - timer aktif di chat
/gt stats - total sesi di chat
/gt yield - hasil zona dan item yang tersimpan (10 zona teratas)
/gt yield current - total hasil untuk zona saat ini
/gt debug - pesan deteksi loot aktif / nonaktif
/gt profile start | stop | report - profil loop timer
/gt hud - minimap HUD (lihat di bawah)
/gt min - kecilkan ke bilah, atau kembalikan jendela
/gt dock - bilah mendorong frame atas game ke bawah (aktif) atau hanya menutupinya (nonaktif)
/gt export - tampilkan titikmu sendiri sebagai teks untuk dibagikan
/gt import - impor titik dari teks teman
/gt report - laporan debug untuk disalin ke laporan bug
/gthud - sama dengan /gt hud
/hun - Nama Acak (lihat Panel > Kontrol > Nama Acak)

]] .. H .. "Perintah HUD" .. E .. [[

/gthud - aktifkan / nonaktifkan HUD
/gthud on | off
/gthud config - buka pengaturan HUD
/gthud size 800 - ukuran HUD (150 sampai 1400)
/gthud alpha 0.5 - opasitas peta (0 sampai 1)
/gthud zoom 3 - zoom minimap (0 sampai 5)
/gthud rotate - putar mengikuti pemain aktif / nonaktif
/gthud ring 150 - jari-jari cincin dalam px (0 = mati)
/gthud ring2 300 - cincin kedua
/gthud ringthick 2 - ketebalan cincin (1 sampai 10)
/gthud ringseg 96 - kehalusan cincin (8 sampai 256)
/gthud ringstyle solid | stripes | dots - gaya cincin
/gthud ringdensity 24 - garis atau titik di sekeliling cincin (4 sampai 128)
/gthud ringcolor 1 1 1 0.8 - merah hijau biru opasitas
/gthud ringcolor2 1 1 1 0.8 - warna cincin kedua
/gthud dirs - huruf kompas aktif / nonaktif
/gthud heading - pembacaan arah aktif / nonaktif
/gthud tracking - tombol pelacakan aktif / nonaktif
/gthud tracksize 50 - ukuran tombol pelacakan (20 sampai 80)
/gthud trackpos 0 0 - offset tombol pelacakan untuk kondisi HUD saat ini
/gthud trackmode auto | own | stock - tombol pelacakan saat HUD mati
/gthud arrow - panah pemain aktif / nonaktif
/gthud addons - sembunyikan skin / tombol addon minimap aktif / nonaktif
/gthud scan - pemindaian mendalam addon minimap aktif / nonaktif
/gthud mountfade - sembunyikan HUD saat menunggang aktif / nonaktif
/gthud autogather - aktifkan otomatis saat pelacakan pengumpulan aktif / nonaktif
/gthud restore - pulihkan HUD setelah /reload atau login aktif / nonaktif
/gthud profile - daftar profil; /gthud profile <n> berpindah atau membuat profil
/gthud profile delete <n> - hapus profil (Default dan profil aktif tidak bisa dihapus)
/gthud status | info | frames | debug - status, diagnostik, atau pesan debug
/gthud reset - reset profil saat ini
/gthud help - tampilkan bantuan perintah]]

GT.helpText.idID = T
