-- frFR_help.lua : texte français du panneau Aide (un bloc par sujet, voir UI/Panels/PanelHelp.lua)
local _, GT = ...
GT.locales = GT.locales or {}
GT.locales.frFR = GT.locales.frFR or {}
GT.helpText = GT.helpText or {}

-- topic tab captions
GT.locales.frFR["Start"] = "Début"
GT.locales.frFR["Panels"] = "Volets"
GT.locales.frFR["Tips"] = "Astuces"
GT.locales.frFR["HUD"] = "HUD"
GT.locales.frFR["Cmds"] = "Cmds"
GT.locales.frFR["Credits"] = "Crédits"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "HUD de la minicarte" .. E .. [[

Transforme la vraie minicarte en une grande carte translucide sur votre écran, avec des anneaux facultatifs, les lettres de la boussole, le cap et les indicateurs « prêts en premier » et progression de l’itinéraire. Vos repères de récolte restent affichés.

]] .. H .. "Activer / désactiver" .. E .. [[

- Faites un clic gauche sur le bouton HUD de la minicarte dans la fenêtre principale.
- Saisissez /gt hud (ou /gthud).
- Utilisez une touche : Réglages du HUD > Carte > Raccourci clavier (cliquez sur le bouton de touche puis appuyez sur une touche ; Échap annule, Effacer la supprime). Ce réglage se trouve aussi dans Raccourcis clavier > AddOns > GatherTimes.
- Facultatif : activation automatique lorsque le suivi de récolte est actif (Réglages du HUD > Options).

]] .. H .. "Réglages du HUD (clic droit sur le bouton HUD)" .. E .. [[

- Carte : taille du HUD, opacité de la carte (0 % = carte vide, seuls les repères sont visibles ; 100 % = opaque ; 10 niveaux), zoom de la minicarte, raccourci clavier.
- Anneaux : rayon, deuxième anneau, épaisseur, lissage, style (ligne, rayures ou points : le bouton les fait défiler), densité, couleurs des anneaux (Couleur de l’anneau... ouvre le sélecteur : curseurs pour chaque anneau et bouton Couleur aléatoire pour l’onglet d’anneau ouvert), lettres de la boussole (N E S O), indicateur de cap, indicateur de récolte « prêts en premier » (point prêt le plus proche, sinon prochaine réapparition) et indicateur de progression de l’itinéraire (étape planifiée actuelle). Chaque indicateur peut être activé ou désactivé.
- Suivi : bouton de suivi lorsque le HUD est actif (taille 20-80 px et position) et comportement lorsque le HUD est inactif (auto, own ou stock).
- Options : faire pivoter la carte avec le joueur, flèche du joueur, masquer le HUD à cheval, activation automatique avec le suivi de récolte, restaurer le HUD après /reload ou connexion, masquer les habillages des addons de minicarte, diagnostics.
- Profil : enregistrer plusieurs apparences, passer de l’une à l’autre ou les supprimer. Les profils sont partagés par tous les personnages ; chacun mémorise le sien.
- Réinitialiser le profil restaure les valeurs par défaut.]]

T.credits = H .. "GatherTimes 0.24.3" .. E .. [[

Auteur : miRidinsa
Site web : https://github.com/ridinsa/
Licence : GNU GPL v3 ou ultérieure (voir le fichier LICENSE dans le dossier de l’addon).

]] .. H .. "Bibliothèques" .. E .. [[

- HereBeDragons-2.0 et HereBeDragons-Pins-2.0 par Nevcairiel : positions des repères sur la minicarte et la carte du monde.
- LibStub et CallbackHandler-1.0 (bibliothèques WoW Ace) : chargement des bibliothèques et callbacks.

]] .. H .. "Nom aléatoire" .. E .. [[

Une copie intégrée du module HideUnitNames (l’addon autonome du même nom est également pris en charge : lorsqu’il est chargé, cette copie s’efface).

]] .. H .. "Addons d’appoint" .. E .. [[

- HereBeDragons : nécessaire pour les repères.
- GatherMate2 : ses données de points peuvent être importées.
- TomTom : waypoints pour la flèche et les itinéraires.

]] .. H .. "Traductions" .. E .. [[

Les fichiers de langue du dossier Locales. Merci à toutes les personnes qui ont contribué aux traductions et à celles qui ont envoyé un rapport de débogage.]]

T.start = H .. "Bienvenue dans GatherTimes" .. E .. [[

Suit quand les herbes et les minerais réapparaissent dans la zone où vous êtes, retient où les points apparaissent, et les affiche dans la fenêtre principale, sur la minicarte et sur la carte du monde.

]] .. H .. "Démarrage rapide" .. E .. [[

1. Ouvrez la fenêtre avec /gt.
2. Cliquez sur Points (en bas) et cochez les herbes / minerais que vous récoltez.
3. Récoltez. Un timer démarre dès que vous ramassez le butin d'un point.
4. Surveillez le tableau de la fenêtre principale. Quand un point est prêt, vous recevez une alerte à l'écran, un son, et un carillon quand vous êtes proche.

]] .. H .. "La fenêtre principale" .. E .. [[

- Liste déroulante (en haut) : afficher chaque point coché, ou un seul.
- Les quantités d'inventaire s'affichent alignées à droite dans la liste d'objets ouverte ; elles sont masquées sur l'objet fermé et sélectionné.
- Tableau : une ligne par groupe de points proches. G1, G2... sont les numéros de groupe que vous voyez aussi sur la carte.
- Statut : Waiting = tous les points comptent encore à rebours. 2/3 up = certains sont revenus. Ready = tous sont revenus. Idle = aucun timer en cours.
- Un point reste Ready un moment après sa réapparition, puis passe en Idle (vous choisissez la durée dans Options > Général > Durée du statut Prêt).
- Les alertes ne sont envoyées qu'une fois par timer. Utilisez Options > Général pour les distances minimale et maximale, et Points > Alert pour activer ou couper les alertes de chaque ressource.
- Bouton Minimap HUD On/Off : clic gauche active ou désactive le HUD, clic droit ouvre les réglages du HUD. Son texte est vert quand le HUD est actif, gris quand il est désactivé.
- Le libellé du serveur et du mode de jeu apparaît sous le tableau des timers.
- Les 5 boutons du bas ouvrent les panneaux. Cliquez de nouveau sur le même bouton pour fermer son panneau.
- Faites glisser la barre de titre pour déplacer la fenêtre. Le titre affiche la zone dans laquelle vous êtes.
- Le bouton ? de la barre de titre ouvre cette aide.
- Le bouton - de la barre de titre réduit la fenêtre en une barre fine le long du haut de l'écran. Clic droit pour les réglages de réduction. Dans la barre : la liste d'objets, une puce par groupe, l'or de la session et le bouton "+", qui rétablit la fenêtre. Deux clics droits sur l'or pour réinitialiser la session (le résumé est d'abord affiché dans le chat).

]]

T.panels = H .. "Timers" .. E .. [[

Chaque timer en cours, les prêts en premier (Grp, Point, Temps), plus les totaux de votre session. Clear waypoint retire la flèche. Show summary ouvre le résumé de session (objets, valeur en or et or par heure) dans une zone de texte que vous pouvez copier. Reset session affiche d'abord le résumé, puis relance le chronomètre de session et remet les compteurs à zéro.

]] .. H .. "Points" .. E .. [[

Choisissez ce que vous suivez et comment.
- On : cochez pour suivre une herbe / un minerai.
- Min : temps de réapparition en minutes. Tapez un nouveau nombre puis Entrée.
- Col : couleur du point sur la carte et dans les listes. Clic gauche = couleur suivante, clic droit = précédente.
- Alert : activer ou couper les alertes de disponibilité pour cette ressource. Le contrôle ne dépend pas de l'affichage de la ressource dans la liste principale.
- Sound : son d'alerte. Clic = suivant (joue un aperçu), clic droit = précédent.
- Dropdown : Tous / Herbes / Minerais. List all : afficher tous les points, pas seulement ceux de votre zone actuelle.
- Nodes per group : nombre de points proches formant un groupe (G1, G2...).
- Nodes up per group : nombre de points qui doivent être revenus pour que le groupe soit prêt.
- Select All, Select None, Reset (retour aux temps par défaut).
- La liste d'objets ouverte de la fenêtre principale affiche aussi le nombre de cette ressource dans vos sacs ; le bouton sélectionné n'affiche pas de quantité.

]] .. H .. "Nav" .. E .. [[

- Route : choisissez une herbe / un minerai activé ou toutes les ressources activées, puis Build route trace un chemin à travers les timers actifs. Next step passe à l'étape suivante, Clear route supprime le trajet. Les options incluent : seulement les points prêts, tracer sur la carte, flèche automatique, nombre maximal de points et fenêtre de temps. Donnez la priorité aux ressources en faible stock pour favoriser celles en dessous de la quantité cible (sacs uniquement).
- Repères : afficher les épingles de réapparition sur la carte et la minicarte, les étiquettes de groupe (G1, G2...), des points pour les autres objets, masquer les points récoltés pendant cette session, clic droit sur un point pour le menu de groupe, décalage des points pendant la récolte, et Refresh pins. Le filtre des points récoltés se vide quand vous réinitialisez la session.
- Flèche : intégration TomTom, flèche vers le point le plus proche, passage automatique au point suivant d'un trajet, distance de la flèche, Waypoint to nearest. Nécessite l'addon TomTom.

]] .. H .. "Durées" .. E .. [[

Par point : Now = le temps de réapparition utilisé. Learned (n) = la plage mesurée lors de vos propres visites, la valeur rapide typique (par exemple 10.5-12.0), n = nombre de mesures (orange sous 5, jaune 5-9, vert 10 ou plus ; une durée apprise en vert signifie que la valeur typique est plus rapide que Now ; * = valeur de l'objet entier affichée en mode Per zone). Les réapparitions varient, attendez-vous donc à une valeur dans cette plage. Apply / auto-apply utilisent la valeur typique (à droite). Taken = fréquence à laquelle un point a été trouvé vide.
- Learned times : Per item (une durée apprise par herbe / minerai, par défaut) ou Per zone (la zone où vous êtes, une fois qu'elle a 5 mesures).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (plus court ou plus long, jamais plus du double du temps d'origine). L'interrupteur de zone est dans Options > Général.
- Apply all faster copie les durées apprises dans Now. Reset learned timings les efface.

]] .. H .. "Options" .. E .. [[

- Général : alerte à l'écran et Alert time, distance minimale et maximale d'alerte de disponibilité (0 désactive cette limite), alerte quand le chat annonce une maintenance (couleur du clignotement 1-7), avertissement de faible vie (Hardcore), Durée du statut Prêt, et Afficher seulement les timers et les repères de la zone où je suis.
- Affichage : taille du texte de la carte, taille de la fenêtre, semi-transparent pendant le déplacement, garder les fenêtres visibles (ECHAP ne les ferme pas), et info-bulle d'objet au survol. La liste de langue se trouve sous Look ; elle prend effet après un rechargement de l'interface (affiché comme "w/reload").
- Look : Langue, Frame skin (thèmes de couleurs pour les fenêtres et les info-bulles ; Pastel Pink et Sakura utilisent un texte sombre avec un fin contour), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, ou Friends si le client le possède) et Font size (80 % à 130 %). Le coréen, le chinois, le japonais et le russe gardent leur propre police, donc le choix de police est remplacé par une note pour eux.
- Outils : état de l'addon et de ses aides, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (partager des points avec des amis), Copy debug report (un bloc de texte pour un rapport de bug), Reset timers, Start a new session at login, et le journal d'erreurs.

]] .. H .. "Inventaire et résumé de session" .. E .. [[

La liste d'objets ouverte affiche votre quantité en sacs à côté de chaque objet ; le bouton de l'objet sélectionné la masque. Le panneau Timers affiche les totaux de session. Show summary ouvre le même résumé ; Reset session l'affiche d'abord, puis remet les compteurs à zéro et relance le chronomètre. Seul le butin de récolte reconnu compte. Reset session efface aussi le filtre des points récoltés, propre à la session.

]] .. H .. "Nom aléatoire" .. E .. [[

Clic droit sur le bouton Options de la fenêtre principale pour l'ouvrir (un nouveau clic droit le ferme). Il masque votre propre nom à l'écran, pour un stream ou des captures d'écran. Les autres joueurs voient toujours votre vrai nom.
- Disguise names : active ou désactive le déguisement. Quand il est actif, les noms des autres joueurs sont aussi masqués (via les réglages de noms du jeu, rétablis à la désactivation).
- Hide party / raid names : masque séparément les étiquettes de noms de groupe et de raid à l'écran.
- Fake player name / Fake pet name : les noms affichés à la place. Tapez un nom puis Entrée ou Apply. 12 caractères maximum.
- Randomize Names : choisit de nouveaux noms aléatoires et un niveau factice. Le curseur Random level range définit le niveau maximum. Opacity rend le fond de la fenêtre plus transparent tout en gardant le texte lisible.
- Affiché sur : vos cadres d'unité (aussi quand vous vous ciblez vous-même ou votre familier), l'info-bulle d'unité, le titre de la fenêtre de personnage et le chat. Quand le déguisement est actif, les noms de personnages correspondants sont aussi masqués dans les info-bulles d'objets.
- Commandes : /hun (active ou désactive le déguisement), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Si l'addon autonome HideUnitNames est chargé, le Nom aléatoire d'ici est désactivé. Utilisez cet addon.

]]

T.tips = H .. "Groupes" .. E .. [[

Les points proches sont traités comme un seul groupe, de sorte que vous voyez quand tout le groupe est revenu au lieu de chaque point. Avec One shared timer per group (panneau Durées), le groupe n'a qu'un seul timer.

]] .. H .. "Corriger un point (carte du monde)" .. E .. [[

Clic droit sur un texte de timer ou une épingle de point sur la carte du monde pour ouvrir un petit menu (à activer dans Nav > Repères) :
- Ce point est vide : quelqu'un d'autre l'a pris.
- Groupe pris par quelqu'un : tout le groupe avait déjà été récolté.
- Déplacer ce point vers un groupe : le mettre dans un autre groupe (1, 2, 3... ou New).
- Saisissez une courte note et cliquez sur Save note pour attacher un rappel à ce point. Survolez le point pour voir sa note. Les notes sont enregistrées avec le point.
La minicarte n'ouvre jamais ce menu. Vous pouvez le désactiver dans Nav > Repères.

]] .. H .. "Comment les temps de réapparition sont appris" .. E .. [[

Chaque fois qu'un point est revenu et que vous en ramassez le butin, le temps écoulé depuis le butin dont il est la réapparition est enregistré (dans un groupe avec plusieurs points revenus en même temps, c'est le plus ancien des butins récents, pas le plus récent). L'addon ignore les intervalles très courts et très longs, puis affiche, dans Durées, la valeur du quart le plus rapide jusqu'à la médiane (typique) de vos mesures, arrondie à 15 secondes. Apply et auto-apply utilisent la médiane. Il faut 3 mesures pour afficher une valeur et 5 pour l'appliquer automatiquement.

]] .. H .. "Partager des points avec des amis" .. E .. [[

Options > Outils > Export my spots (ou /gt export) affiche vos propres points sous forme d'une ligne de texte. Cliquez dans la zone, appuyez sur Ctrl+C et envoyez-le à un ami. Votre ami utilise Import spots (ou /gt import), le colle avec Ctrl+V et clique sur Import. Seuls l'objet, la zone et la position sont partagés, pas les timers ni les compteurs. Les points déjà présents sont laissés en place, et un texte coupé en chemin est refusé plutôt qu'importé à moitié.

]] .. H .. "Addons auxiliaires" .. E .. [[

- HereBeDragons : nécessaire pour les épingles sur la carte et la minicarte. Installez-le.
- GatherMate2 : Options > Outils > Import GatherMate2 ajoute les emplacements de points qu'il connaît.
- TomTom : permet à la flèche et aux waypoints des trajets de s'afficher.

]] .. H .. "Un problème ?" .. E .. [[

- Pas d'épingles : installez HereBeDragons. Options > Outils indique ce qui a été trouvé.
- Les timers ne démarrent pas : tapez /gt debug puis ramassez le butin d'un point ; l'addon affiche ce qu'il voit.
- Les erreurs sont listées dans Options > Outils > Error log (cliquez, Ctrl+A, Ctrl+C pour copier).
- Pour signaler un problème ou un conflit avec un autre addon : Options > Outils > Copy debug report (ou /gt report), copiez le texte et collez-le dans le rapport.
- Point ou groupe incorrect : clic droit dessus sur la carte du monde.]]

T.cmds = H .. "Commandes slash" .. E .. [[

/gt - ouvre ou ferme la fenêtre principale
/gt list - timers actifs dans le chat
/gt stats - totaux de session dans le chat
/gt yield - rendements enregistrés par zone et objet (10 zones principales)
/gt yield current - totaux de rendement pour la zone actuelle
/gt debug - messages de détection de butin activés / désactivés
/gt profile start | stop | report - profile la boucle des timers
/gt hud - minicarte HUD (voir plus bas)
/gt min - réduit dans la barre, ou rétablit la fenêtre
/gt dock - la barre repousse les cadres supérieurs du jeu vers le bas (activé) ou les recouvre seulement (désactivé)
/gt export - affiche vos propres points sous forme de texte à partager
/gt import - importe des points depuis le texte d'un ami
/gt report - rapport de débogage à copier dans un rapport de bug
/gthud - identique à /gt hud
/hun - Nom aléatoire (voir Panneaux > Options > Nom aléatoire)

]] .. H .. "Commandes HUD" .. E .. [[

/gthud - active ou désactive le HUD
/gthud on | off
/gthud config - ouvre les réglages du HUD
/gthud size 800 - taille du HUD (150 à 1400)
/gthud alpha 0.5 - opacité de la carte (0 à 1)
/gthud zoom 3 - zoom de la minicarte (0 à 5)
/gthud rotate - rotation avec le joueur activée / désactivée
/gthud ring 150 - rayon de l'anneau en px (0 = désactivé)
/gthud ring2 300 - deuxième anneau
/gthud ringthick 2 - épaisseur de l'anneau (1 à 10)
/gthud ringseg 96 - finesse de l'anneau (8 à 256)
/gthud ringstyle solid | stripes | dots - style de l'anneau
/gthud ringdensity 24 - rayures ou points autour de l'anneau (4 à 128)
/gthud ringcolor 1 1 1 0.8 - rouge vert bleu opacité
/gthud ringcolor2 1 1 1 0.8 - couleur du deuxième anneau
/gthud dirs - lettres de la boussole activées / désactivées
/gthud heading - affichage du cap activé / désactivé
/gthud tracking - bouton de suivi activé / désactivé
/gthud tracksize 50 - taille du bouton de suivi (20 à 80)
/gthud trackpos 0 0 - décalage du bouton de suivi pour l'état actuel du HUD
/gthud trackmode auto | own | stock - bouton de suivi quand le HUD est désactivé
/gthud arrow - flèche du joueur activée / désactivée
/gthud addons - masquer les habillages / boutons des addons de minicarte activé / désactivé
/gthud scan - recherche approfondie d'addons de minicarte activée / désactivée
/gthud mountfade - masquer le HUD en monture activé / désactivé
/gthud autogather - activation automatique avec le suivi de récolte activée / désactivée
/gthud restore - rétablir le HUD après /reload ou connexion activé / désactivé
/gthud profile - liste les profils ; /gthud profile <n> change de profil ou en crée un
/gthud profile delete <n> - supprime un profil (Default et le profil actif ne peuvent pas être supprimés)
/gthud status | info | frames | debug - état, diagnostic ou messages de débogage
/gthud reset - réinitialise le profil actuel
/gthud help - affiche l'aide des commandes]]

GT.helpText.frFR = T
