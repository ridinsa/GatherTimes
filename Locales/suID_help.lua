-- suID_help.lua : téks panél Pitulung dina Basa Sunda (hiji blok per topik, tingali UI/Panels/PanelHelp.lua)
local ADDON, GT = ...
GT.locales = GT.locales or {}
GT.locales.suID = GT.locales.suID or {}
GT.helpText = GT.helpText or {}

-- topic tab captions (the buttons are ~54 px wide: keep them short)
GT.locales.suID["Start"] = "Mimiti"
GT.locales.suID["Panels"] = "Panél"
GT.locales.suID["Tips"] = "Tip"
GT.locales.suID["HUD"] = "HUD"
GT.locales.suID["Cmds"] = "Paréntah"
GT.locales.suID["Credits"] = "Nu nyieun"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "HUD minimap" .. E .. [[

Ngarobah minimap asli jadi peta gedé transparan nu nutupan layar, kalawan pilihan cingcin, hurup kompas, arah, bacaan nu ngutamakeun node siap jeung kamajuan rute. Pin ngumpulkeun tetep katémbong.

]] .. H .. "Hurungkeun / pareuman" .. E .. [[

- Klik kenca tombol HUD Minimap dina jandéla utama.
- Ketik /gt hud (atawa /gthud).
- Paké tombol keyboard: setélan HUD > tab Peta > Tombol pintas (klik tombolna tuluy pencét tombol; Esc ngabatalkeun, Hapus mupus). Aya ogé dina Ikatan Tombol > AddOns > GatherTimes.
- Pilihan: hurungkeun otomatis waktu tracking ngumpulkeun keur aktip (setélan HUD > Pilihan).

]] .. H .. "Setélan HUD (klik katuhu tombol HUD)" .. E .. [[

- Peta: ukuran HUD, opasitas peta (0% = peta kosong, ngan pin nu katingali; 100% = pinuh opak; 10 léngkah), zoom minimap, offset X / Y, tombol pintas.
- Cingcin: radius, cingcin kadua, kandel, lemesna garis, gaya cingcin (garis, belang atawa titik: tombolna muterkeun pilihan), kapadetan, warna cingcin (Warna cingcin... muka pamilih: slider keur unggal cingcin jeung tombol Warna acak keur tab nu keur dibuka), hurup kompas (N E S W), bacaan arah, bacaan ngumpulkeun nu ngutamakeun Siap (node siap pangdeukeutna, atawa respawn pangdeukeutna), jeung bacaan kamajuan rute (léngkah rute ayeuna). Unggal bacaan bisa dihurungkeun atawa dipareuman.
- Tracking: tombol tracking waktu HUD hurung (ukuran 20-80 px jeung posisi) jeung nu dipigawéna waktu HUD pareum (otomatis, sorangan atawa baku).
- Pilihan: puter peta nuturkeun pamaén, panah pamaén, nyumputkeun HUD waktu naék, hurungkeun otomatis bareng tracking ngumpulkeun, balikkeun HUD sanggeus /reload atawa login, nyumputkeun kulit minimap addon, diagnostik.
- Profil: simpen sababaraha tampilan, pindah atawa hapus. Profil dipaké bareng ku sakabéh karakter; unggal karakter nyimpen pilihanana sorangan.
- Buka konci / sered (handap): pindahkeun HUD maké beurit, pencét deui keur ngonci. Reset profil mulangkeun setélan baku.]]

T.credits = H .. "GatherTimes 0.23.0" .. E .. [[

Nu nyieun: miRidinsa
Website: https://github.com/ridinsa/
Lisénsi: GNU GPL v3 atawa leuwih anyar (tingali file LICENSE dina folder addon).

]] .. H .. "Library" .. E .. [[

- HereBeDragons-2.0 jeung HereBeDragons-Pins-2.0 ku Nevcairiel: posisi pin dina minimap jeung peta dunya.
- LibStub jeung CallbackHandler-1.0 (library WoW Ace): muat library jeung callback.

]] .. H .. "Ngaran Acak" .. E .. [[

Salinan modul HideUnitNames nu diselapkeun (addon misah nu ngaranna sarua ogé dirojong: lamun dimuat, salinan ieu mundur).

]] .. H .. "Addon pangbantu" .. E .. [[

- HereBeDragons: diperlukeun keur pin.
- GatherMate2: data node-na bisa diimpor.
- TomTom: waypoint keur panah jeung rute.

]] .. H .. "Tarjamahan" .. E .. [[

File basa aya dina folder Locales. Hatur nuhun ka sakur nu mantuan narjamahkeun jeung nu ngirim laporan debug.]]

T.start = H .. "Wilujeng sumping di GatherTimes" .. E .. [[

Ngalacak iraha suket jeung bijih muncul deui di zona anu anjeun asup, ngeling dimana titik spawn-na, sarta mintonkeun dina jandela utama, minimap jeung peta dunya.

]] .. H .. "Mimitian gancang" .. E .. [[

1. Buka jandela ku /gt.
2. Klik Node (handap) jeung centang suket / bijih anu anjeun kumpulkeun.
3. Kumpulkeun. Timer mimiti pas anjeun nyokot jarahan tina hiji titik.
4. Tingali tabel dina jandela utama. Lamun titik geus siap, anjeun meunang peringatan dina layar, sora, jeung sora lonceng lamun anjeun deukeut.

]] .. H .. "Jandela utama" .. E .. [[

- Dropdown (luhur): tembongkeun unggal titik anu dicentang, atawa ngan hiji.
- Jumlah inventaris némbongan katuhu dina dropdown barang anu dibuka; dina barang anu ditutup jeung kapilih, jumlahna disumputkeun.
- Tabel: hiji baris per grup titik anu deukeut. G1, G2... nyaéta nomer grup anu ogé anjeun tingali dina peta.
- Status: Waiting = sakabéh titik keur ngitung mundur. 2/3 up = sababaraha geus balik deui. Ready = sakabéh geus balik. Idle = teu aya timer anu jalan.
- Titik tetep Ready sakedap sanggeus muncul deui, teras janten Idle (anjeun milih sabaraha lila di Setélan > Umum > Status Ready lasts).
- Peringatan dikirim ngan sakali per timer. Jarak diatur di Setélan > Umum; Node > Alert pikeun ngahurungkeun atawa nyeurikeun peringatan per sumber daya.
- Tombol Minimap HUD On/Off: klik kenca pikeun ngahurungkeun atawa mareuman HUD, klik katuhu pikeun muka setélan HUD. Téksna héjo lamun HUD hurung, kulawu lamun paeh.
- Labél server jeung mode kaulinan némbongan di handapeun tabel timer.
- Lima tombol di handap muka panél. Pencét tombol anu sarua deui pikeun nutup panélna.
- Séred bar judul pikeun mindahkeun jandela. Judulna mintonkeun zona anu anjeun asup.
- Tombol ? dina bar judul muka pitulung ieu.
- Tombol - dina bar judul ngaleutikan jandela jadi bar ipis di sapanjang luhur layar. Klik katuhu pikeun setélan leutikan. Dina bar: dropdown barang, hiji chip per grup, emas sési, sarta tombol "+" pikeun balikeun jandela. Klik katuhu dua kali kana emas pikeun ngareset sési (ringkesan dicitak heula ka obrolan).

]]

T.panels = H .. "Timer" .. E .. [[

Unggal timer anu keur jalan, anu siap heula (Grp, Node, Time), ditambah total sési anjeun. Clear waypoint miceun panah. Show summary muka ringkesan sési (barang, nilai emas, jeung emas per jam) dina kotak anu bisa disalin. Reset session nyitak ringkesan heula, lajeng ngamimitian deui timer sési sarta ngabersihan itungan.

]] .. H .. "Node" .. E .. [[

Pilih naon anu dilacak jeung kumaha.
- On: centang pikeun ngalacak suket / bijih.
- Min: waktu muncul deui dina menit. Ketik angka anyar terus pencét Enter.
- Col: warna titik dina peta jeung dina daptar. Klik kenca = warna salajengna, klik katuhu = warna saméméhna.
- Alert: hurungkeun atawa pareuman peringatan siap pikeun sumber daya ieu. Pamariksaan ieu henteu gumantung kana naha sumber daya éta ditémbongkeun dina dropdown utama.
- Sound: sora peringatan. Klik = salajengna (diputer sakali), klik katuhu = saméméhna.
- Dropdown: Sadaya / Suket / Bijih. List all: tembongkeun unggal titik, lain ngan titik zona ayeuna.
- Nodes per group: sabaraha titik deukeut anu ngabentuk hiji grup (G1, G2...).
- Nodes up per group: sabaraha titik kudu geus balik sangkan grup dianggap siap.
- Select All, Select None, Reset (balik ka waktu standar).
- Dropdown barang anu dibuka dina jandela utama ogé mintonkeun sabaraha sumber daya éta aya dina kantong; tombol anu kapilih henteu mintonkeun jumlah.

]] .. H .. "Navi" .. E .. [[

- Rute: pilih hiji suket / bijih anu aktif atawa sakabéh sumber daya anu aktif, teras Build route ngarencanakeun jalur ngaliwatan timer anu aktif. Next step ngalih ka léngkah salajengna, Clear route miceun rute. Pilihanana kaasup ngan titik anu siap, ngagambar rute dina peta, panah otomatis, jumlah titik maksimum, jeung rentang waktu. Pikeun ngutamakeun sumber daya anu stokna saeutik, pilih sumber daya stok handap (ngan kantong).
- Tanda: tembongkeun pin spawn dina peta jeung minimap, tembongkeun label grup (G1, G2...), titik pikeun barang séjén, nyumputkeun titik anu dikumpulkeun dina sési ieu, klik katuhu titik pikeun ménu grup, offset titik nalika ngumpulkeun, jeung Refresh pins. Saringan titik anu dikumpulkeun dihapus lamun sési direset.
- Panah: integrasi TomTom, panah ka titik pangdeukeutna, otomatis ngalih ka titik salajengna dina rute, jarak panah, Waypoint to nearest. Butuh addon TomTom.

]] .. H .. "Waktu" .. E .. [[

Per titik: Now = waktu muncul deui anu keur dipake. Learned (n) = rentang anu diukur tina kunjungan sorangan, nilai khas anu gancang (contona 10.5-12.0), n = jumlah sampel (oranyé handap 5, konéng 5-9, héjo 10 atawa leuwih; waktu learned héjo hartina nilai khasna leuwih gancang ti Now; * = nilai sakabéh barang anu ditémbongkeun dina mode Per zone). Waktu muncul deui bisa béda-béda, jadi ekspektasi nilai dina rentang éta. Apply / auto-apply make nilai khas (katuhu). Taken = sabaraha kali titik kapanggih kosong.
- Learned times: Per item (hiji waktu learned per suket / bijih, standar) atawa Per zone (zona anu anjeun asup, sanggeus aya 5 sampel).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (bisa leuwih pondok atawa leuwih panjang, tapi teu leuwih ti dua kali waktu pabrik). Saklar zona aya di Setélan > Umum.
- Apply all faster nyalin waktu learned ka Now. Reset learned timings miceun eta.

]] .. H .. "Setélan" .. E .. [[

- Umum: peringatan dina layar jeung Alert time, jarak minimum jeung maksimum pikeun peringatan siap (0 hartina teu aya wates éta), peringatan lamun obrolan ngumumkeun pangropéa (warna kedip 1-7), peringatan darah handap (Hardcore), Ready status lasts, jeung Ngan tembongkeun timer jeung pin zona anu kuring asup.
- Tampilan: ukuran téks peta, ukuran jandela, transparan nalika dipindahkeun, tetep tembongkeun jandela (ESC teu nutupna), jeung tooltip barang nalika disorot. Dropdown basa aya di Look; éta mangaruhan sanggeus UI dimuat ulang (ditémbongkeun salaku "w/reload").
- Look: Basa, Frame skin (téma warna pikeun jandela jeung tooltip; Pastel Pink jeung Sakura maké téks poék kalawan garis ipis), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, atawa Friends lamun klien aya), jeung Font size (80% dugi ka 130%). Koréa, Cina, Jepang jeung Rusia tetep maké font sorangan, jadi pilihan font diganti ku catetan pikeun maranéhna.
- Parabot: status addon jeung para pembantuna, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (babagi titik jeung babaturan), Copy debug report (blok téks pikeun laporan bug), Reset timers, Start a new session at login, jeung log kasalahan.

]] .. H .. "Inventaris jeung ringkesan sési" .. E .. [[

Dropdown barang anu dibuka mintonkeun jumlah dina kantong di gigireun unggal barang; tombol barang anu kapilih nyumputkeun jumlahna. Panél Timer mintonkeun total sési. Show summary muka ringkesan anu sarua; Reset session nyitak eta heula, lajeng ngabersihan itungan jeung ngamimitian deui jam sési. Ngan jarahan kumpulan anu dikenal anu diitung. Reset session ogé mupus saringan titik anu dikumpulkeun, khusus sési ieu.

]] .. H .. "Ngaran acak" .. E .. [[

Klik katuhu tombol Setélan dina jandela utama pikeun muka (klik katuhu deui pikeun nutup). Ieu nyumputkeun ngaran anjeun dina layar anjeun, pikeun streaming atawa screenshot. Pamaén séjén tetep ningali ngaran anu sabenerna.
- Disguise names: hurungkeun atawa pareuman samaran. Lamun hurung, ngaran pamaén séjén ogé disumputkeun (ngaliwatan setélan ngaran kaulinan, dibalikeun nalika dipareuman).
- Hide party / raid names: nyumputkeun label ngaran party jeung raid sacara misah dina layar anjeun.
- Fake player name / Fake pet name: ngaran anu dipintonkeun gantina. Ketik ngaran terus pencét Enter atawa Apply. Dugi ka 12 karakter.
- Randomize Names: milih ngaran acak anyar jeung tingkat palsu. Slider Random level range nangtukeun tingkat maksimum. Opacity ngajantenkeun latar jandela leuwih transparan sedengkeun téksna tetep kabaca.
- Dipintonkeun dina: frame unit anjeun (ogé nalika anjeun nyasar diri sorangan atawa sato peliharaan), tooltip unit, judul jandela karakter, jeung obrolan. Nalika samaran hurung, ngaran karakter anu cocog ogé disumputkeun dina tooltip barang.
- Paréntah: /hun (hurungkeun atawa pareuman samaran), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Lamun addon HideUnitNames mandiri dimuat, Ngaran acak di dieu dipareuman. Pake addon éta.

]]

T.tips = H .. "Grup" .. E .. [[

Titik anu deukeut diperlakukeun salaku hiji grup, jadi anjeun bisa ningali iraha sakabéh grup geus balik, lain unggal titik sorangan-sorangan. Kalawan One shared timer per group (panél Waktu), grup boga hiji timer.

]] .. H .. "Ngabenerkeun hiji titik (peta dunya)" .. E .. [[

Klik katuhu kana téks timer atawa pin titik dina peta dunya pikeun muka ménu leutik (hurungkeun dina Navi > Tanda):
- Titik ieu kosong: batur geus nyokotna.
- Grup dicokot batur: sakabéh grup geus dikumpulkeun samemeh kitu.
- Pindahkeun titik ieu ka grup: tempatkeun dina grup séjén (1, 2, 3... atawa New).
- Ketik catetan pondok terus klik Save note pikeun nempélkeun pangéling ka titik éta. Ngagantungkeun kursor kana titik pikeun ningali catetanna. Catetan disimpen babarengan jeung titik.
Minimap teu pernah muka ménu ieu. Anjeun bisa mareuman éta dina Navi > Tanda.

]] .. H .. "Kumaha waktu muncul deui diajar" .. E .. [[

Unggal kali titik geus balik jeung anjeun nyokot jarahanana, waktu ti jarahan anu jadi asal muncul deuina disimpen (dina grup anu sababaraha titikna balik bareng, eta jarahan pangkolotna tina anu panganyarna, lain anu pangpanganyarna). Addon teu malire jarak anu pondok pisan jeung panjang pisan, teras nembongkeun dina Waktu nilai ti saparapat anu paling gancang nepi ka median (khas) tina sampel anjeun, dibulatkeun ka 15 detik. Apply jeung auto-apply maké median. Butuh 3 sampel pikeun mintonkeun nilai jeung 5 pikeun nerapkeun sacara otomatis.

]] .. H .. "Babagi titik jeung babaturan" .. E .. [[

Setélan > Parabot > Export my spots (atawa /gt export) mintonkeun titik anjeun salaku hiji baris téks. Klik kotakna, pencét Ctrl+C, terus kirimkeun ka babaturan. Babaturan anjeun maké Import spots (atawa /gt import), nempelkeunana ku Ctrl+V, terus klik Import. Ngan barang, zona jeung posisi anu dibagikeun, teu aya timer atawa itungan. Titik anu geus dimilikina ditinggalkeun, jeung téks anu kapotong di jalan ditolak tinimbang diimpor satengah.

]] .. H .. "Addon pembantu" .. E .. [[

- HereBeDragons: diperlukeun pikeun pin dina peta jeung minimap. Pasang.
- GatherMate2: Setélan > Parabot > Import GatherMate2 nambahkeun lokasi titik anu dipikanyaho.
- TomTom: ngamungkinkeun panah jeung waypoint rute ditémbongkeun.

]] .. H .. "Aya masalah?" .. E .. [[

- Teu aya pin: pasang HereBeDragons. Setélan > Parabot mintonkeun naon anu kapanggih.
- Timer henteu mimiti: ketik /gt debug terus nyokot jarahan titik; addon nyitak naon anu ditingalina.
- Kasalahan didaptarkeun di Setélan > Parabot > Error log (klik, Ctrl+A, Ctrl+C pikeun nyalin).
- Pikeun ngalaporkeun masalah atawa konflik jeung addon séjén: Setélan > Parabot > Copy debug report (atawa /gt report), salin téksna terus tempelkeun dina laporan.
- Titik atawa grup salah: klik katuhu kana éta dina peta dunya.]]

T.cmds = H .. "Paréntah slash" .. E .. [[

/gt - muka atawa nutup jandela utama
/gt list - timer aktif dina obrolan
/gt stats - total sési dina obrolan
/gt yield - hasil anu disimpen per zona jeung barang (10 zona luhur)
/gt yield current - total hasil pikeun zona ayeuna
/gt debug - pesan deteksi jarahan hurung / pareum
/gt profile start | stop | report - profilkeun loop timer
/gt hud - minimap HUD (tingali handap)
/gt min - leutikan jadi bar, atawa balikeun jandela
/gt dock - bar nyorong frame luhur kaulinan ka handap (hurung) atawa ngan nutupan (pareum)
/gt export - tembongkeun titik anjeun salaku téks pikeun dibagikeun
/gt import - impor titik tina téks babaturan
/gt report - laporan debug pikeun disalin kana laporan bug
/gthud - sarua jeung /gt hud
/hun - Ngaran acak (tingali Panél > Setélan > Ngaran acak)

]] .. H .. "Paréntah HUD" .. E .. [[

/gthud - hurungkeun atawa pareuman HUD
/gthud on | off
/gthud config - buka setélan HUD
/gthud unlock | lock - pindahkeun HUD ku mouse
/gthud size 800 - ukuran HUD (150 nepi ka 1400)
/gthud alpha 0.5 - opacity peta (0 nepi ka 1)
/gthud zoom 3 - zoom minimap (0 nepi ka 5)
/gthud offset 0 0 - posisi
/gthud rotate - muter nuturkeun pamaén hurung / pareum
/gthud ring 150 - radius cingcin dina px (0 = pareum)
/gthud ring2 300 - cingcin kadua
/gthud ringthick 2 - kandelan cingcin (1 nepi ka 10)
/gthud ringseg 96 - kahalusan cingcin (8 nepi ka 256)
/gthud ringstyle solid | stripes | dots - gaya cingcin
/gthud ringdensity 24 - jumlah garis atawa titik di sabudeureun cingcin (4 nepi ka 128)
/gthud ringcolor 1 1 1 0.8 - beureum héjo biru opacity
/gthud ringcolor2 1 1 1 0.8 - warna cingcin kadua
/gthud dirs - hurup kompas hurung / pareum
/gthud heading - tembongan arah hurung / pareum
/gthud tracking - tombol tracking hurung / pareum
/gthud tracksize 50 - ukuran tombol tracking (20 nepi ka 80)
/gthud trackpos 0 0 - offset tombol tracking pikeun kaayaan HUD ayeuna
/gthud trackmode auto | own | stock - tombol tracking nalika HUD pareum
/gthud arrow - panah pamaén hurung / pareum
/gthud addons - sumputkeun skin / tombol addon minimap hurung / pareum
/gthud scan - scan jero addon minimap hurung / pareum
/gthud mountfade - sumputkeun HUD nalika numpak hurung / pareum
/gthud autogather - hurungkeun otomatis jeung tracking kumpulan hurung / pareum
/gthud restore - balikeun HUD sanggeus /reload atawa login hurung / pareum
/gthud profile - daptar profil; /gthud profile <n> ganti atawa nyieun
/gthud profile delete <n> - hapus profil (Default jeung profil aktif teu bisa dihapus)
/gthud status | info | frames | debug - status, diagnostik, atawa pesan debug
/gthud reset - reset profil ayeuna
/gthud help - tembongkeun pitulung paréntah]]

GT.helpText.suID = T
