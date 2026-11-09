# Treni Italia — Omarchy

Plugin locale per la barra superiore. Cerca e ricorda una stazione; mostra arrivi,
partenze, ritardo, binario effettivo o programmato. Clic su un treno: percorso e
fermate. La rete schematica per regione o Italia permette di selezionare una
tratta e vedere i treni. Il pulsante di ricerca completa consulta le tratte
attive della vista corrente, deduplicando le corse e segnalando risposte parziali.

La mappa nazionale è quella sintetica di ViaggiaTreno; il pulsante di ricerca
completa nazionale consulta separatamente tutte le regioni per includere anche
le circolazioni regionali disponibili. La ricerca ha un limite di tre minuti
e segnala i risultati parziali. I tabelloni non garantiscono transiti senza fermata.
I binari possono cambiare. Le linee evidenziate indicano occupazione della tratta,
non una posizione GPS del treno. Non vengono inventati orari o binari mancanti.

Fonte: endpoint del sito pubblico ViaggiaTreno, verificati il 9 novembre 2026.
Non è un'API contrattualmente garantita. Il filtro include i codici cliente
1, 2, 63 e 64 ed esclude gli altri: la copertura dei servizi associati e degli
sostitutivi dipende da quanto pubblica la fonte. Non include reti estere.

La fonte reindirizza HTTPS verso HTTP. L'utente ha autorizzato esplicitamente
l'accesso alle API pubbliche via HTTP. L'adattatore usa esclusivamente il dominio
ufficiale e rifiuta reindirizzamenti al di fuori del percorso API autorizzato.
Non sono richiesti account o chiavi. Nessun dato personale viene inviato:
solo ricerca stazione, codici delle stazioni, tratte, treni e ora della ricerca.

Aggiornamento all'apertura o manuale. Autoaggiornamento opzionale ogni 60 secondi,
solo a pannello aperto; disattivato inizialmente. La ricerca completa avviene
solo su richiesta, con un massimo di quattro richieste contemporanee.

Sorgenti: questo repository.
Installazione: `~/.config/omarchy/plugins/krysto.treni`.
Manifest validato con `omarchy plugin validate`. Test: `python -m unittest discover -s tests -v`.

## Simulazione dei binari

Seleziona una stazione e premi **Simulazione binari**. I treni si avvicinano
in base agli orari di arrivo e ai ritardi, sui binari indicati dalla fonte.
Ogni binario mostra il prossimo treno entro un’ora e il numero di quelli a seguire.
La disposizione dei binari e le posizioni sono illustrative, non rilevate dal vivo.
Un orario superato non conferma l’arrivo. I treni senza binario o orario non
vengono collocati nel disegno. Dopo due minuti senza nuovi dati la vista si ferma.
**Prova demo · 30×** mostra treni inventati con animazione accelerata; **Pausa**
ferma l’illustrazione. L’animazione non gira a pannello chiuso.

## Schemi automatici per tutte le stazioni

Per ogni stazione selezionata il plugin usa le coordinate ViaggiaTreno e cerca
binari, fermate ferroviarie, banchine e respingenti in OpenStreetMap via HTTPS.
Overpass viene usato come alternativa. Lo schema è stimato per singolo binario,
anche nelle stazioni miste; i binari vuoti restano visibili se mappati.
La copertura dipende dai dati disponibili: dove mancano riscontri compare
«schema non verificato». Non è una planimetria ferroviaria ufficiale.

Le richieste cartografiche sono separate dal tabellone; cache locale di 7 giorni
in `~/.cache/omarchy-treni/layouts`, nessuna ricerca periodica. È possibile
disattivarle con **Schema automatico: no** o riprovare se il servizio non risponde.
Dati © collaboratori OpenStreetMap, licenza ODbL:
https://www.openstreetmap.org/copyright .

## Repository pubblico

https://github.com/Kryst-0/omarchy-treni-italia

```sh
omarchy plugin add https://github.com/Kryst-0/omarchy-treni-italia.git --enable
omarchy plugin remove krysto.treni
```
