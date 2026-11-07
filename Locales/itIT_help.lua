-- itIT_help.lua : testo italiano del pannello Aiuto (un blocco per argomento, vedi UI/Panels/PanelHelp.lua)
local ADDON, GT = ...
GT.locales = GT.locales or {}
GT.locales.itIT = GT.locales.itIT or {}
GT.helpText = GT.helpText or {}

-- topic tab captions (the buttons are ~54 px wide: keep them short)
GT.locales.itIT["Start"] = "Inizio"
GT.locales.itIT["Panels"] = "Pannelli"
GT.locales.itIT["Tips"] = "Consigli"
GT.locales.itIT["HUD"] = "HUD"
GT.locales.itIT["Cmds"] = "Comandi"
GT.locales.itIT["Credits"] = "Crediti"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "HUD minimappa" .. E .. [[

Trasforma la minimappa vera e propria in una grande mappa trasparente estesa sullo schermo, con cerchi opzionali, lettere della bussola, indicazione della direzione, letture che mostrano prima i punti pronti e l'avanzamento del percorso. I tuoi marker di raccolta restano visibili.

]] .. H .. "Attivazione / disattivazione" .. E .. [[

- Clic sinistro sul pulsante HUD minimappa nella finestra principale.
- Scrivi /gt hud (o /gthud).
- Usa un tasto: Opzioni HUD > scheda Mappa > Tasto di scelta rapida (clicca il pulsante del tasto, premine uno; Esc annulla, Cancella lo rimuove). È disponibile anche in Tasti associati > AddOns > GatherTimes.
- Facoltativo: attiva l'accensione automatica quando è attivo il tracciamento della raccolta (Opzioni HUD > Opzioni).

]] .. H .. "Opzioni HUD (clic destro sul pulsante HUD)" .. E .. [[

- Mappa: dimensione HUD, opacità mappa (0% = mappa vuota, si vedono solo i marker; 100% = opaca; 10 livelli), zoom minimappa, offset X / Y, tasto di scelta rapida.
- Cerchi: raggio, secondo cerchio, spessore, uniformità, stile del cerchio (linea, righe o punti: il pulsante li alterna), densità, colori dei cerchi (Colore cerchio... apre il selettore: cursori per ogni cerchio e pulsante Colore casuale per la scheda del cerchio aperta), lettere della bussola (N E S W), indicazione della direzione, lettura di raccolta con priorità ai punti pronti (punto pronto più vicino, altrimenti respawn più vicino) e lettura dell'avanzamento del percorso (passo attualmente pianificato). Ogni lettura può essere attivata o disattivata.
- Tracciamento: pulsante di tracciamento mentre l'HUD è attivo (dimensioni 20-80 px e posizione) e cosa fa quando l'HUD è disattivato (auto, own o stock).
- Opzioni: ruota la mappa con il giocatore, freccia del giocatore, nascondi HUD in sella, attivazione automatica con il tracciamento della raccolta, ripristina HUD dopo /reload o l'accesso, nascondi le skin degli addon della minimappa, diagnostica.
- Profili: salva diversi aspetti, passa da uno all'altro o eliminali. I profili sono condivisi da tutti i personaggi; ogni personaggio ricorda il proprio.
- Sblocca / trascina (in basso): posiziona l'HUD con il mouse, premi di nuovo per bloccarlo. Reimposta profilo ripristina i valori predefiniti.]]

T.credits = H .. "GatherTimes 0.24.1" .. E .. [[

Autore: miRidinsa
Sito web: https://github.com/ridinsa/
Licenza: GNU GPL v3 o successiva (vedi il file LICENSE nella cartella dell'addon).

]] .. H .. "Librerie" .. E .. [[

- HereBeDragons-2.0 e HereBeDragons-Pins-2.0 di Nevcairiel: posizioni dei marker sulla minimappa e sulla mappa del mondo.
- LibStub e CallbackHandler-1.0 (librerie WoW Ace): caricamento delle librerie e callback.

]] .. H .. "Nome casuale" .. E .. [[

Una copia incorporata del modulo HideUnitNames (è supportato anche l'addon autonomo omonimo: quando viene caricato, questa copia si disattiva).

]] .. H .. "Addon di supporto" .. E .. [[

- HereBeDragons: necessario per i marker.
- GatherMate2: è possibile importarne i dati dei punti.
- TomTom: waypoint per la freccia e i percorsi.

]] .. H .. "Traduzioni" .. E .. [[

I file delle lingue nella cartella Locales. Grazie a tutti coloro che hanno contribuito e a chi ha inviato un rapporto di debug.]]

T.start = H .. "Benvenuto in GatherTimes" .. E .. [[

Tiene traccia di quando erbe e minerali riappaiono nella zona in cui ti trovi, ricorda dove si trovano i nodi e li mostra nella finestra principale, sulla minimappa e sulla mappa del mondo.

]] .. H .. "Avvio rapido" .. E .. [[

1. Apri la finestra con /gt.
2. Clicca Punti (in basso) e spunta le erbe / i minerali che raccogli.
3. Raccogli. Un timer parte appena prendi il bottino di un nodo.
4. Guarda la tabella nella finestra principale. Quando un nodo è pronto ricevi un avviso a schermo, un suono e un segnale quando sei vicino.

]] .. H .. "La finestra principale" .. E .. [[

- Menu a tendina (in alto): mostra ogni nodo spuntato, oppure uno solo.
- I conteggi dell'inventario appaiono allineati a destra nel menu degli oggetti aperto; sull'oggetto chiuso e selezionato sono nascosti.
- Tabella: una riga per gruppo di nodi vicini. G1, G2... sono i numeri di gruppo che vedi anche sulla mappa.
- Stato: Waiting = tutti i nodi stanno ancora contando. 2/3 up = alcuni sono tornati. Ready = tutti sono tornati. Idle = nessun timer in corso.
- Un nodo resta Ready per un po' dopo che è riapparso, poi diventa Idle (scegli quanto a lungo in Opzioni > Generale > Stato pronto dura).
- Gli avvisi vengono inviati una sola volta per timer. Usa Opzioni > Generale per la distanza minima e massima, e Punti > Alert per attivare o silenziare gli avvisi di ogni risorsa.
- Pulsante Minimap HUD On/Off: il clic sinistro attiva o disattiva l'HUD, il clic destro apre le impostazioni dell'HUD. Il testo è verde quando l'HUD è attivo e grigio quando è spento.
- L'etichetta del server e della modalità di gioco appare sotto la tabella dei timer.
- I 5 pulsanti in basso aprono i pannelli. Clicca di nuovo lo stesso pulsante per chiudere il suo pannello.
- Trascina la barra del titolo per spostare la finestra. Il titolo mostra la zona in cui ti trovi.
- Il pulsante ? nella barra del titolo apre questa guida.
- Il pulsante - nella barra del titolo riduce la finestra a una barra sottile lungo la parte alta dello schermo. Il clic destro apre le opzioni di riduzione. Nella barra: il menu degli oggetti, un chip per gruppo, l'oro della sessione e il pulsante "+", che riporta la finestra. Due clic destri sull'oro reimpostano la sessione (il riepilogo viene prima stampato in chat).

]]

T.panels = H .. "Timer" .. E .. [[

Ogni timer in corso, prima quelli pronti (Grp, Nodo, Tempo), più i totali della sessione. Clear waypoint rimuove la freccia. Show summary apre il riepilogo della sessione (oggetti, valore in oro e oro all'ora) in una casella che puoi copiare. Reset session stampa prima il riepilogo, poi riavvia il timer della sessione e azzera i conteggi.

]] .. H .. "Punti" .. E .. [[

Scegli cosa tracciare e come.
- On: spunta per tracciare un'erba / un minerale.
- Min: tempo di riapparizione in minuti. Scrivi un nuovo numero e premi Invio.
- Col: colore del nodo sulla mappa e negli elenchi. Clic sinistro = colore successivo, clic destro = precedente.
- Alert: attiva o silenzia gli avvisi di pronto per questa risorsa. Il controllo non dipende dal fatto che la risorsa sia mostrata nel menu principale.
- Sound: suono dell'avviso. Clic = successivo (riproduce un'anteprima), clic destro = precedente.
- Dropdown: Tutti / Erbe / Minerali. List all: mostra ogni nodo, non solo quelli della zona attuale.
- Nodes per group: quanti nodi vicini formano un gruppo (G1, G2...).
- Nodes up per group: quanti devono essere tornati perché il gruppo risulti pronto.
- Select All, Select None, Reset (torna ai tempi predefiniti).
- Il menu degli oggetti aperto nella finestra principale mostra anche quanto di quella risorsa hai nelle borse; il pulsante selezionato non mostra il conteggio.

]] .. H .. "Nav" .. E .. [[

- Percorso: scegli un'erba / un minerale attivo o tutte le risorse attive, poi Build route traccia un percorso tra i timer attivi. Next step passa al passo successivo, Clear route lo rimuove. Le opzioni includono solo nodi pronti, disegno sulla mappa, freccia automatica, numero massimo di nodi e finestra temporale. Dai priorità alle risorse con poco stock per favorire quelle sotto il valore obiettivo (solo borse).
- Marker: mostra i pin di comparsa sulla mappa e sulla minimappa, le etichette di gruppo (G1, G2...), punti per gli altri oggetti, nasconde i punti raccolti in questa sessione, clic destro su un punto per il menu del gruppo, offset dei nodi durante la raccolta e Refresh pins. Il filtro dei punti raccolti si azzera quando reimposti la sessione.
- Freccia: integrazione con TomTom, freccia verso il nodo più vicino, passaggio automatico al nodo successivo di un percorso, distanza della freccia, Waypoint to nearest. Richiede l'addon TomTom.

]] .. H .. "Tempi" .. E .. [[

Per nodo: Now = il tempo di riapparizione in uso. Learned (n) = l'intervallo misurato dalle tue visite, il valore tipico rapido (ad esempio 10.5-12.0), n = numero di campioni (arancione sotto 5, giallo 5-9, verde 10 o più; un tempo appreso verde significa che il valore tipico è più rapido di Now; * = valore dell'oggetto intero mostrato in modalità Per zone). I tempi di riapparizione variano, quindi aspettati un valore in quell'intervallo. Apply / auto-apply usano il valore tipico (a destra). Taken = quante volte un punto è stato trovato vuoto.
- Learned times: Per item (un tempo appreso per erba / minerale, predefinito) oppure Per zone (la zona in cui ti trovi, una volta che ha 5 campioni).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (più corto o più lungo, mai più del doppio del tempo di fabbrica). L'interruttore di zona è in Opzioni > Generale.
- Apply all faster copia i tempi appresi in Now. Reset learned timings li cancella.

]] .. H .. "Opzioni" .. E .. [[

- Generale: avviso a schermo e Alert time, distanza minima e massima per l'avviso di pronto (0 disattiva quel limite), avviso quando la chat annuncia una manutenzione (colore del lampeggio 1-7), avviso di salute bassa (Hardcore), Stato pronto dura, e Mostra solo timer e pin della zona in cui mi trovo.
- Aspetto: dimensione del testo della mappa, dimensione della finestra, semitrasparente durante lo spostamento, mantieni le finestre visibili (ESC non le chiude), e tooltip dell'oggetto al passaggio del mouse. Il menu della lingua si trova in Look; ha effetto dopo il ricaricamento dell'interfaccia (mostrato come "w/reload").
- Look: Lingua, Frame skin (temi di colore per finestre e tooltip; Pastel Pink e Sakura usano testo scuro con un sottile contorno), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, o Friends se il client lo possiede) e Font size (dall'80% al 130%). Coreano, cinese, giapponese e russo mantengono il proprio font, quindi per loro la scelta del font è sostituita da una nota.
- Strumenti: stato dell'addon e dei suoi aiutanti, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (condividi punti con gli amici), Copy debug report (un blocco di testo per una segnalazione di bug), Reset timers, Start a new session at login, e il registro errori.

]] .. H .. "Inventario e riepilogo sessione" .. E .. [[

Il menu degli oggetti aperto mostra il conteggio nelle borse accanto a ogni oggetto; il pulsante dell'oggetto selezionato lo nasconde. Il pannello Timer mostra i totali della sessione. Show summary apre lo stesso riepilogo; Reset session lo stampa prima, poi azzera i conteggi e riavvia l'orologio della sessione. Conta solo il bottino di raccolta riconosciuto. Reset session cancella anche il filtro dei punti raccolti, valido solo per la sessione.

]] .. H .. "Nome casuale" .. E .. [[

Clic destro sul pulsante Opzioni della finestra principale per aprirlo (un altro clic destro lo chiude). Nasconde il tuo nome sullo schermo, per streaming o screenshot. Gli altri giocatori continuano a vedere il tuo nome reale.
- Disguise names: attiva o disattiva il travestimento. Quando è attivo, anche i nomi degli altri giocatori sono nascosti (tramite le impostazioni dei nomi del gioco, ripristinate alla disattivazione).
- Hide party / raid names: nasconde separatamente le etichette dei nomi di gruppo e di incursione sullo schermo.
- Fake player name / Fake pet name: i nomi mostrati al posto dei veri. Scrivi un nome e premi Invio o Apply. Fino a 12 caratteri.
- Randomize Names: sceglie nuovi nomi casuali e un livello falso. Il cursore Random level range imposta il livello massimo. Opacity rende lo sfondo della finestra più trasparente, mantenendo leggibile il testo.
- Mostrato su: i tuoi riquadri unità (anche quando ti selezioni o selezioni il tuo pet), il tooltip dell'unità, il titolo della finestra del personaggio e la chat. Quando il travestimento è attivo, i nomi dei personaggi corrispondenti sono nascosti anche nei tooltip degli oggetti.
- Comandi: /hun (attiva o disattiva il travestimento), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Se l'addon autonomo HideUnitNames è caricato, il Nome casuale qui viene disattivato. Usa quell'addon.

]]

T.tips = H .. "Gruppi" .. E .. [[

I nodi vicini vengono trattati come un unico gruppo, così vedi quando l'intero gruppo è tornato invece di ogni singolo nodo. Con One shared timer per group (pannello Tempi), il gruppo ha un solo timer.

]] .. H .. "Correggere un punto (mappa del mondo)" .. E .. [[

Clic destro sul testo di un timer o su un pin di punto sulla mappa del mondo per aprire un piccolo menu (da attivare in Nav > Marker):
- Questo punto è vuoto: qualcun altro l'ha preso.
- Gruppo preso da qualcuno: l'intero gruppo era già stato raccolto.
- Sposta questo punto nel gruppo: mettilo in un altro gruppo (1, 2, 3... o New).
- Scrivi una breve nota e clicca Save note per collegare un promemoria a quel punto. Passa con il mouse sul punto per vedere la nota. Le note vengono salvate con il punto.
La minimappa non apre mai questo menu. Puoi disattivarlo in Nav > Marker.

]] .. H .. "Come vengono appresi i tempi di riapparizione" .. E .. [[

Ogni volta che un nodo è tornato e ne prendi il bottino, viene salvato il tempo trascorso dal bottino di cui è la riapparizione (in un gruppo con più nodi tornati insieme, è il più vecchio dei bottini recenti, non il più nuovo). L'addon ignora gli intervalli molto brevi e molto lunghi, quindi mostra in Tempi il valore del quarto più rapido fino alla mediana (tipica) dei tuoi campioni, arrotondato a 15 secondi. Apply e auto-apply usano la mediana. Servono 3 campioni per mostrare un valore e 5 per applicarlo automaticamente.

]] .. H .. "Condividere punti con gli amici" .. E .. [[

Opzioni > Strumenti > Export my spots (o /gt export) mostra i tuoi punti come una riga di testo. Clicca nella casella, premi Ctrl+C e invialo a un amico. Il tuo amico usa Import spots (o /gt import), lo incolla con Ctrl+V e clicca Import. Vengono condivisi solo oggetto, zona e posizione, senza timer né conteggi. I punti che ha già restano invariati, e un testo tagliato durante l'invio viene rifiutato invece di essere importato a metà.

]] .. H .. "Addon di supporto" .. E .. [[

- HereBeDragons: necessario per i pin sulla mappa e sulla minimappa. Installalo.
- GatherMate2: Opzioni > Strumenti > Import GatherMate2 aggiunge le posizioni dei nodi che conosce.
- TomTom: fa comparire la freccia e i waypoint dei percorsi.

]] .. H .. "Qualcosa non va?" .. E .. [[

- Nessun pin: installa HereBeDragons. Opzioni > Strumenti mostra cosa è stato trovato.
- I timer non partono: scrivi /gt debug e prendi il bottino di un nodo; l'addon stampa ciò che vede.
- Gli errori sono elencati in Opzioni > Strumenti > Error log (clicca, Ctrl+A, Ctrl+C per copiare).
- Per segnalare un problema o un conflitto con un altro addon: Opzioni > Strumenti > Copy debug report (o /gt report), copia il testo e incollalo nella segnalazione.
- Punto o gruppo sbagliato: clic destro su di esso sulla mappa del mondo.]]

T.cmds = H .. "Comandi slash" .. E .. [[

/gt - apre o chiude la finestra principale
/gt list - timer attivi in chat
/gt stats - totali della sessione in chat
/gt yield - rendimenti salvati per zona e oggetto (prime 10 zone)
/gt yield current - totali dei rendimenti per la zona attuale
/gt debug - messaggi di rilevamento del bottino attivati / disattivati
/gt profile start | stop | report - profila il ciclo dei timer
/gt hud - minimappa HUD (vedi sotto)
/gt min - riduce alla barra, oppure riporta la finestra
/gt dock - la barra spinge in basso i riquadri superiori del gioco (attivo) oppure li copre soltanto (disattivo)
/gt export - mostra i tuoi punti come testo da condividere
/gt import - importa punti dal testo di un amico
/gt report - rapporto di debug da copiare in una segnalazione di bug
/gthud - uguale a /gt hud
/hun - Nome casuale (vedi Pannelli > Opzioni > Nome casuale)

]] .. H .. "Comandi HUD" .. E .. [[

/gthud - attiva o disattiva l'HUD
/gthud on | off
/gthud config - apre le impostazioni dell'HUD
/gthud unlock | lock - sposta l'HUD con il mouse
/gthud size 800 - dimensione dell'HUD (da 150 a 1400)
/gthud alpha 0.5 - opacità della mappa (da 0 a 1)
/gthud zoom 3 - zoom della minimappa (da 0 a 5)
/gthud offset 0 0 - posizione
/gthud rotate - ruota con il giocatore attivo / disattivo
/gthud ring 150 - raggio dell'anello in px (0 = disattivato)
/gthud ring2 300 - secondo anello
/gthud ringthick 2 - spessore dell'anello (da 1 a 10)
/gthud ringseg 96 - morbidezza dell'anello (da 8 a 256)
/gthud ringstyle solid | stripes | dots - stile dell'anello
/gthud ringdensity 24 - strisce o punti intorno all'anello (da 4 a 128)
/gthud ringcolor 1 1 1 0.8 - rosso verde blu opacità
/gthud ringcolor2 1 1 1 0.8 - colore del secondo anello
/gthud dirs - lettere della bussola attive / disattive
/gthud heading - indicatore di direzione attivo / disattivo
/gthud tracking - pulsante di tracciamento attivo / disattivo
/gthud tracksize 50 - dimensione del pulsante di tracciamento (da 20 a 80)
/gthud trackpos 0 0 - posizione del pulsante di tracciamento per lo stato attuale dell'HUD
/gthud trackmode auto | own | stock - pulsante di tracciamento quando l'HUD è spento
/gthud arrow - freccia del giocatore attiva / disattiva
/gthud addons - nascondi skin / pulsanti degli addon della minimappa attivo / disattivo
/gthud scan - ricerca approfondita degli addon della minimappa attiva / disattiva
/gthud mountfade - nascondi l'HUD mentre sei in sella attivo / disattivo
/gthud autogather - attiva in automatico con il tracciamento della raccolta attivo / disattivo
/gthud restore - ripristina l'HUD dopo /reload o login attivo / disattivo
/gthud profile - elenca i profili; /gthud profile <n> passa a un profilo o ne crea uno
/gthud profile delete <n> - elimina un profilo (Default e il profilo attivo non si possono eliminare)
/gthud status | info | frames | debug - stato, diagnostica o messaggi di debug
/gthud reset - reimposta il profilo attuale
/gthud help - mostra l'aiuto dei comandi]]

GT.helpText.itIT = T
