-- Translated labels for the herbs and ore shown by GatherTimes.
local _, GT = ...
GT.locales = GT.locales or {}

local codes = { "deDE", "frFR", "itIT", "koKR", "jaJP", "ruRU", "zhCN", "ptBR", "esES", "idID", "suID" }
local rows = {
    { "Peacebloom", "Friedensblume", "Pacifique", "Fiore pacifico", "평온초", "ピースブルーム", "Мироцвет", "宁神花", "Flor-da-paz", "Flor de paz", "Bunga damai", "Kembang tengtrem" },
    { "Silverleaf", "Silberblatt", "Feuillargent", "Foglia d'argento", "은엽수", "シルバーリーフ", "Сребролист", "银叶草", "Folha-prata", "Hojaplata", "Daun perak", "Daun pérak" },
    { "Earthroot", "Erdwurzel", "Terrestrine", "Radice della Terra", "뱀뿌리", "アースルート", "Земляной корень", "地根草", "Raiz-telúrica", "Raíz de tierra", "Akar bumi", "Akar taneuh" },
    { "Mageroyal", "Maguskönigskraut", "Mage royal", "Magareale", "마법초", "マージョラム", "Магороза", "魔皇草", "Magi-real", "Marregal", "Mageroyal", "Mageroyal" },
    { "Briarthorn", "Wilddornrose", "Églantine", "Cespica", "찔레가시", "ブライアソーン", "Остротерн", "石南草", "Espinheira", "Brezospina", "Duri semak", "Duri rungkun" },
    { "Swiftthistle", "Flitzdistel", "Chardonnier", "Cardo rapido", "신속의 엉겅퀴", "スウィフトシッスル", "Скорополох", "雨燕草", "Cardo-rápido", "Cardo veloz", "Duri cepat", "Duri gancang" },
    { "Bruiseweed", "Beulengras", "Doulourante", "Erbacieca", "생채기풀", "ブルーシーウィード", "Синячник", "跌打草", "Erva-murcha", "Hierba cardenal", "Rumput memar", "Jukut bareuh" },
    { "Stranglekelp", "Würgetang", "Varech", "Alga strangolante", "갈래물풀", "ストラングルケルプ", "Удавник", "荆棘藻", "Alga-estrangulante", "Alga estranguladora", "Ganggang pencekik", "Ganggang nyekek" },
    { "Wild Steelbloom", "Wildstahlblume", "Aciérite sauvage", "Fiordiferro selvatico", "야생 철쭉", "野生の鋼花", "Дикий сталецвет", "野钢花", "Açoiteira-selvagem", "Acérita salvaje", "Bunga baja liar", "Kembang waja liar" },
    { "Grave Moss", "Grabmoos", "Mousse de tombe", "Muschio tombale", "무덤이끼", "グレイブモス", "Могильный мох", "墓地苔", "Musgo-de-túmulo", "Musgo de tumba", "Lumut makam", "Lumut kuburan" },
    { "Kingsblood", "Königsblut", "Sang-royal", "Sanguesacro", "왕꽃잎풀", "キングスブラッド", "Королевская кровь", "皇血草", "Sangue-real", "Sangrerregia", "Darah raja", "Getih raja" },
    { "Liferoot", "Lebenswurz", "Racine de vie", "Erbalivida", "생명의 뿌리", "ライフルート", "Корень жизни", "活根草", "Raiz-da-vida", "Vidarraíz", "Akar hidup", "Akar hirup" },
    { "Fadeleaf", "Blassblatt", "Pâlerette", "Fogliafina", "미명초", "フェードリーフ", "Бледнолист", "枯叶草", "Folha-pálida", "Pálida", "Daun pudar", "Daun layu" },
    { "Goldthorn", "Golddorn", "Dorépine", "Spina d'oro", "황금가시", "ゴールドソーン", "Златошип", "金棘草", "Espinho-de-ouro", "Espina de oro", "Duri emas", "Duri emas" },
    { "Khadgar's Whisker", "Khadgars Schnurrbart", "Moustache de Khadgar", "Baffo di Khadgar", "카드가의 수염", "カードガーのひげ", "Ус Кадгара", "卡德加的胡须", "Bigode de Khadgar", "Bigote de Khadgar", "Kumis Khadgar", "Kumis Khadgar" },
    { "Wintersbite", "Winterbiss", "Hivernale", "Morso d'inverno", "겨울서리풀", "ウィンターズバイト", "Морозник", "冬刺草", "Mordida-de-inverno", "Ivernalia", "Gigitan musim dingin", "Gégélan usum tiris" },
    { "Firebloom", "Feuerblüte", "Fleur de feu", "Fiordifuoco", "화염초", "ファイアブルーム", "Огнецвет", "火焰花", "Flor-de-fogo", "Flor de fuego", "Bunga api", "Kembang seuneu" },
    { "Purple Lotus", "Lila Lotus", "Lotus pourpre", "Loto purpureo", "보라 연꽃", "パープルロータス", "Пурпурный лотос", "紫莲花", "Lótus-púrpura", "Loto cárdeno", "Teratai ungu", "Seroja wungu" },
    { "Arthas' Tears", "Arthas' Tränen", "Larmes d'Arthas", "Lacrime di Arthas", "아서스의 눈물", "アルサスの涙", "Слёзы Артаса", "阿尔萨斯之泪", "Lágrimas de Arthas", "Lágrimas de Arthas", "Air mata Arthas", "Cimata Arthas" },
    { "Sungrass", "Sonnengras", "Soleillet", "Erbasole", "태양풀", "サンブライト", "Солнечник", "太阳草", "Erva-sol", "Solea", "Rumput matahari", "Jukut panonpoé" },
    { "Blindweed", "Blindkraut", "Aveuglette", "Erbacieca", "실명초", "ブラインドウィード", "Слепоцвет", "盲目草", "Erva-cega", "Carolina", "Rumput buta", "Jukut lolong" },
    { "Ghost Mushroom", "Geisterpilz", "Champignon fantôme", "Fungo fantasma", "유령버섯", "ゴーストマッシュルーム", "Призрачная поганка", "幽灵菇", "Cogumelo-fantasma", "Champiñón fantasma", "Jamur hantu", "Jamur jurig" },
    { "Gromsblood", "Gromsblut", "Gromsang", "Sangue di Grom", "그롬의 피", "グロムの血", "Кровь Грома", "格罗姆之血", "Sangue-de-Grom", "Gromsanguina", "Darah Grom", "Getih Grom" },
    { "Golden Sansam", "Goldener Sansam", "Sansam doré", "Sansam dorato", "황금 산삼", "ゴールデンサンサム", "Золотой сансам", "黄金参", "Sansam-dourado", "Sansam dorado", "Sansam emas", "Sansam emas" },
    { "Dreamfoil", "Traumblatt", "Feuillerêve", "Foglia onirica", "꿈풀", "ドリームフォイル", "Снолист", "梦叶草", "Folha-de-sonho", "Hojasueño", "Daun mimpi", "Daun impian" },
    { "Mt. Silversage", "Bergsilbersalbei", "Sauge-argent des montagnes", "Salvia argentata montana", "산삼나무", "マウンテンシルバーセージ", "Горный серебряный шалфей", "山鼠草", "Sálvia-prata-da-montanha", "Salviargenta de montaña", "Sage perak gunung", "Sage pérak gunung" },
    { "Plaguebloom", "Pestblüte", "Fleur de peste", "Fiordipeste", "역병초", "ペストブルーム", "Чумоцвет", "瘟疫花", "Flor-da-peste", "Flor de peste", "Bunga wabah", "Kembang panyakit" },
    { "Icecap", "Eiskappe", "Calot de glace", "Calcap gelo", "얼음송이", "アイスキャップ", "Ледяной зев", "冰盖草", "Chapéu-de-gelo", "Setelo", "Topi es", "Topi és" },
    { "Black Lotus", "Schwarzer Lotus", "Lotus noir", "Loto nero", "검은 연꽃", "ブラックロータス", "Чёрный лотос", "黑莲花", "Lótus-negro", "Loto negro", "Teratai hitam", "Seroja hideung" },
    { "Copper Ore", "Kupfererz", "Minerai de cuivre", "Minerale di rame", "구리 광석", "銅鉱石", "Медная руда", "铜矿", "Minério de cobre", "Mena de cobre", "Bijih tembaga", "Bijih tambaga" },
    { "Tin Ore", "Zinnerz", "Minerai d'étain", "Minerale di stagno", "주석 광석", "スズ鉱石", "Оловянная руда", "锡矿", "Minério de estanho", "Mena de estaño", "Bijih timah", "Bijih timah" },
    { "Incendicite Ore", "Incendicit-Erz", "Minerai d'incendicite", "Minerale di incendicite", "인센디사이트 광석", "インセンディサイト鉱石", "Инцендитовая руда", "火岩矿", "Minério de incendicita", "Mena de incendicita", "Bijih incendicite", "Bijih incendicite" },
    { "Lesser Bloodstone Ore", "Erz mit geringem Blutstein", "Minerai de pierre de sang inférieur", "Minerale di pietra del sangue inferiore", "하급 혈석 광석", "下級ブラッドストーン鉱石", "Малая кровавая руда", "次级血石矿", "Minério de pedra de sangue inferior", "Mena de piedra de sangre inferior", "Bijih batu darah kecil", "Bijih batu getih leutik" },
    { "Silver Ore", "Silbererz", "Minerai d'argent", "Minerale d'argento", "은 광석", "銀鉱石", "Серебряная руда", "银矿", "Minério de prata", "Mena de plata", "Bijih perak", "Bijih pérak" },
    { "Iron Ore", "Eisenerz", "Minerai de fer", "Minerale di ferro", "철 광석", "鉄鉱石", "Железная руда", "铁矿", "Minério de ferro", "Mena de hierro", "Bijih besi", "Bijih beusi" },
    { "Indurium Ore", "Induriumerz", "Minerai d'indurium", "Minerale di indurium", "인듀리움 광석", "インデュリウム鉱石", "Индуриумовая руда", "精铁矿石", "Minério de indurium", "Mena de indurio", "Bijih indurium", "Bijih indurium" },
    { "Gold Ore", "Golderz", "Minerai d'or", "Minerale d'oro", "금 광석", "金鉱石", "Золотая руда", "金矿", "Minério de ouro", "Mena de oro", "Bijih emas", "Bijih emas" },
    { "Mithril Ore", "Mithrilerz", "Minerai de mithril", "Minerale di mithril", "미스릴 광석", "ミスリル鉱石", "Мифриловая руда", "秘银矿", "Minério de mithril", "Mena de mitril", "Bijih mithril", "Bijih mithril" },
    { "Truesilver Ore", "Echtsilbererz", "Minerai de vrai-argent", "Minerale di verargento", "진은 광석", "真銀鉱石", "Руда истинного серебра", "真银矿", "Minério de veraprata", "Mena de veraplata", "Bijih perak murni", "Bijih pérak asli" },
    { "Dark Iron Ore", "Dunkeleisenerz", "Minerai de sombrefer", "Minerale di ferro nero", "검은무쇠 광석", "黒鉄鉱石", "Руда черного железа", "黑铁矿", "Minério de ferro negro", "Mena de hierro negro", "Bijih besi hitam", "Bijih beusi hideung" },
    { "Thorium", "Thorium", "Thorium", "Torio", "토륨", "トリウム", "Торий", "瑟银", "Tório", "Torio", "Thorium", "Thorium" },
}

for _, row in ipairs(rows) do
    assert(#row == #codes + 1, "locale row has an incomplete node label: " .. row[1])
    for i, code in ipairs(codes) do
        GT.locales[code][row[1]] = row[i + 1]
    end
end
