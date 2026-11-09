// Time-based illustration only: the source does not provide physical positions.
function platforms(stationId, layout) {
    // Passenger tracks verified against RFI/FS (Florence) and the municipal
    // sustainable energy action plan (Montelupo-Capraia), November 2026.
    if (stationId === "S06421") return Array.from({length:19},function(_,i){return String(i+1)});
    if (stationId === "S06511") return ["1","2"];
    return layout && layout.platforms ? Object.keys(layout.platforms) : [];
}

// Physical layout, not whether a particular service originates or terminates.
function topology(stationId, platform, demo, layout) {
    if (demo) return String(platform) === "1" || String(platform) === "3" ? "terminal" : "through";
    if (stationId === "S06421") return "terminal";
    if (stationId === "S06511") return "through";
    var kind = layout && layout.platforms ? layout.platforms[String(platform)] : "unknown";
    return kind === "terminal" || kind === "through" ? kind : "unknown";
}

function bufferSide(platform, demo, layout) {
    if (demo) return String(platform)==="3" ? "left" : "right";
    var side=layout && layout.bufferEnds ? layout.bufferEnds[String(platform)] : "";
    if(side==="left" || side==="right")return side;
    // In a verified all-terminal station, other mapped buffers establish the
    // common concourse side. Otherwise retain a labelled schematic direction.
    return "unknown";
}

// The demo may depict a departure; an arrival timestamp in live data cannot
// establish when the train subsequently leaves the platform.
function position(progress, expectedAt, now, topology, demo) {
    var stop = topology === "terminal" ? 1 : 0.55;
    if (!demo || now <= expectedAt + 30000) return progress * stop;
    var departure = Math.max(0, Math.min(1, (now - expectedAt - 30000) / 60000));
    return topology === "terminal" ? 1 - departure : stop + departure * (1 - stop);
}

function build(trains, now, inventory) {
    var groups = Object.create(null), unknown = 0;
    (inventory || []).forEach(function(p){groups[String(p)]=[]});
    for (var i = 0; i < trains.length; ++i) {
        var t = trains[i];
        // Keep a reported track even if it has no approaching train.
        if (t.platform && !groups[String(t.platform)]) groups[String(t.platform)]=[];
        if (t.cancelled) continue;
        if (!t.platform) { unknown++; continue; }
        if (!isFinite(t.expectedAt) || t.expectedAt <= 0) continue;
        var remaining = (t.expectedAt - now) / 60000;
        if (remaining < -2 || remaining > 60) continue;
        var key = String(t.platform);
        if (!groups[key]) groups[key] = [];
        groups[key].push(t);
    }
    var tracks = Object.keys(groups).sort(function(a,b) {
        var na = parseInt(a, 10), nb = parseInt(b, 10);
        return isFinite(na) && isFinite(nb) && na !== nb ? na - nb : a.localeCompare(b);
    }).slice(0, 128).map(function(key) {
        var items = groups[key].sort(function(a,b) { return a.expectedAt - b.expectedAt; });
        if (!items.length) return {platform:key,train:null,count:0,minutes:0,progress:0,state:"emptyTrack"};
        var t = items[0], minutes = (t.expectedAt - now) / 60000;
        return { platform: key, train: t, count: items.length,
            minutes: Math.max(0, Math.ceil(minutes)),
            progress: Math.max(0, Math.min(1, 1 - minutes / 10)),
            // An elapsed estimate is not confirmation that a train has arrived.
            state: t.arrived ? "confirmed" : (minutes <= 0 ? "due" : "approaching") };
    });
    return { tracks: tracks, unknown: unknown };
}

function demo(now) {
    return [
        { number: "DEMO 101", platform: "1", platformKind: "planned", expectedAt: now + 300000, arrived: false },
        { number: "DEMO 202", platform: "2", platformKind: "planned", expectedAt: now + 90000, arrived: false },
        { number: "DEMO 303", platform: "4", platformKind: "planned", expectedAt: now + 480000, arrived: false }
    ];
}
