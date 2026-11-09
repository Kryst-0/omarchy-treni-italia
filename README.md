# Treni Italia — Trains Italy for Omarchy

A small railway control panel in your Omarchy bar. Whistle not included.

[Italian documentation](README.it.md)

## Features

- Search for a station and remember your selection.
- View arrivals and departures with times, delays, cancellations and platforms.
- Distinguish actual platforms from scheduled platforms and unavailable data.
- Click a train to view its route and stops.
- Explore a schematic railway network for an Italian region or the whole country.
- Select a section to see its trains, or request all available traffic.
- Follow your Omarchy theme and language, with English and Italian translations,
  including the stationmaster’s occasional jokes.

## Requirements and installation

Requires Omarchy with its Quickshell shell, Python 3.9 or newer, and timezone
information for `Europe/Rome`. Only Python’s standard library is used; no API
key, account, additional service or privileged installer is required.

For a local checkout, copy this folder to
`~/.config/omarchy/plugins/krysto.treni`, then run:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/krysto.treni
omarchy plugin enable krysto.treni --section right
```

The public repository is https://github.com/Kryst-0/omarchy-treni-italia. Marketplace submission is tracked in this repository’s GitHub issues.

## Usage

Click the train icon to open the panel. Search for a station and select a result,
then choose **Departures** or **Arrivals**. Each row shows the platform provided
by the source and whether it is actual or scheduled. Click a train for its stops.

Open **Network and traffic**, select **Italy** or a region, then click a line
for its trains. **All traffic** searches the active sections; the national
search queries each regional map to include available regional services too.
Searches stop starting new section requests after three minutes and report
partial results if some requests fail or the time limit is reached.

Right-click the bar icon or click **Refresh** to update. **Auto 60 s** enables
optional refresh while the panel is open. It is off by default. Full traffic
searches only run on request, with up to four concurrent requests.
Press Escape or click **Close** to dismiss the panel.

The panel follows Omarchy’s selected language; other languages fall back to
English. Italian station and route names are kept as supplied by the source.

## Track simulation

Select a station and click **Track simulation**. The illustration uses the
arrival board’s timestamps, delays and reported platforms. Each track shows
the next train due within an hour; additional trains are counted underneath.
Click a train to inspect its route. **Try demo · 30×** shows clearly labelled
fictional trains with an accelerated clock. Pause stops the illustration.

Track layout and train positions are illustrative, not physical measurements.
Elapsed arrival estimates do not confirm arrival: only the source can do that.
Trains without a platform or timestamp are not placed on invented tracks.
After two minutes without fresh data the illustration freezes; refresh manually
or enable the panel’s optional automatic refresh. Animation stops when hidden.

## Data source and limitations

Data comes from the public ViaggiaTreno website endpoints, checked on
9 November 2026. This is an unofficial plugin, unaffiliated with Trenitalia or
Gruppo FS, and these endpoints are not a guaranteed public API.

The operator filter accepts source customer codes `1`, `2`, `63` and `64` and
excludes other codes. Coverage of associated and replacement services depends
on the source. Foreign railway networks are not included.

Arrival and departure boards may omit trains passing without stopping.
Platforms can change: check the station displays. Highlighted sections show
traffic reported on that section, not GPS positions. The national map is
ViaggiaTreno’s summary map; the full national traffic search queries the regions
separately. Missing platforms and times are never invented.

The public endpoints redirect HTTPS requests to **unencrypted HTTP**. This
version uses HTTP, explicitly authorized by the owner of this installation.
Requests are restricted to the official host and API path. Requests contain
station searches, station/section/train identifiers and query times. The source
also receives normal connection information, including the client IP address.
No credentials, location tracking or analytics are added by the plugin.

## Configuration and removal

The selected station, region and auto-refresh preference are stored in the
widget’s entry in `~/.config/omarchy/shell.json`.

```sh
omarchy bar move krysto.treni --section tray
omarchy plugin disable krysto.treni
omarchy plugin remove krysto.treni
```

Removing the plugin requires no service cleanup or system changes.

## Validation

```sh
omarchy plugin validate .
python3 -m unittest discover -s tests -v
```

## Verified station layouts

- Montelupo-Capraia (`S06511`): two passenger tracks, through station.
  Source: [Metropolitan City of Florence railway atlas](https://www.cittametropolitana.fi.it/wp-content/uploads/5-QCA4-Atlante-rete-della-mobilita%CC%80-ferroviaria_signed-301-400.pdf).
- Firenze Santa Maria Novella (`S06421`): 19 passenger tracks, terminal station.
  Source: [Gruppo FS station description](https://www.fsitaliane.it/it/innovazione/tecnologie-per-i-trasporti/le-principali-stazioni-av/firenze-santa-maria-novella.html).

Terminal tracks have buffer stops; through tracks extend past both platform
ends. Other station layouts are marked unverified. Physical track type does
not imply departure-only operation. The demo illustrates through departures
and reversals; live arrivals do not provide a subsequent departure time.

## Automatic layouts for other stations

Version 1.2 looks up each selected station using official ViaggiaTreno coordinates
and a small HTTPS OpenStreetMap API map extract. Overpass is a fallback. It
uses train stop-position/platform labels, connected rails and buffer stops
to infer individual terminal and through tracks, including mixed stations.
Tracks without enough evidence remain unverified. Passenger tracks without
upcoming trains remain visible when mapped. No source guarantees complete
coverage or current operating rules for every Italian station.

The map request runs separately from the live board and is cached for seven
days under `$XDG_CACHE_HOME/omarchy-treni/layouts` (normally
`~/.cache/omarchy-treni/layouts`). It does not run periodically. Disable it with
**Automatic layout: off**; **Retry layout** retries failed lookups. Queries send
the station area to `api.openstreetmap.org` (or `overpass-api.de` and
`overpass.kumi.systems`), all via HTTPS. Responses are size- and time-limited.

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright),
available under the Open Database License (ODbL). Derived layouts are estimates,
not official track diagrams. Verified local layouts take precedence.

Terminal tracks now display a buffer stop at the mapped end. The diagram uses
a shared West–East or South–North axis, independent of OSM way-node order.
Arrival animation approaches the buffer from the open end; a terminal track
without endpoint evidence is marked “schematic end”. Cached layouts from
older schema versions are refreshed automatically.

## Install

```sh
omarchy plugin add https://github.com/Kryst-0/omarchy-treni-italia.git --enable
```

## Remove

```sh
omarchy plugin remove krysto.treni
```
