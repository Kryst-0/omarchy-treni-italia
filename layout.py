"""On-demand OSM passenger track layouts. Derived classifications are estimates."""
import collections
import json
import math
import os
from pathlib import Path
import re
import time
import urllib.parse
import urllib.request

ENDPOINTS = ('https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter')

class Redirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, url):
        p=urllib.parse.urlsplit(url)
        if p.scheme!='https' or p.hostname not in ('overpass-api.de','overpass.kumi.systems','api.openstreetmap.org') or p.username or p.password or p.port not in (None,443):
            raise ValueError('Unexpected map redirect')
        return super().redirect_request(req,fp,code,msg,headers,url)

def refs(value):
    return [v.strip() for v in re.split(r'[;,]',str(value or '')) if re.fullmatch(r'[\w .-]{1,16}',v.strip()) and not (v.strip().isdigit() and len(v.strip())>3)][:32]

def point(p, lat, lon):
    return ((float(p['lon'])-lon)*111320*math.cos(math.radians(lat)),(float(p['lat'])-lat)*111320)

def distance(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])

def segment_distance(p,a,b):
    dx=b[0]-a[0];dy=b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy or 1)))
    return distance(p,(a[0]+dx*t,a[1]+dy*t))

def parse(data,lat,lon):
    if not isinstance(data,dict) or not isinstance(data.get('elements'),list):raise ValueError('Invalid OSM response')
    if data.get('remark'):raise ValueError('Incomplete OSM response')
    ways=[]; buffers=set(); points={}; anchors=collections.defaultdict(list); stop_refs=collections.defaultdict(set)
    for e in data['elements'][:30000]:
        tags=e.get('tags') or {}; rail=tags.get('railway')
        try:
            if e.get('type')=='node':
                pt=point(e,lat,lon)
                if rail=='buffer_stop':buffers.add(e['id'])
                if tags.get('public_transport')=='stop_position' and (tags.get('train')=='yes' or rail=='stop'):
                    for ref in refs(tags.get('local_ref') or tags.get('ref')):
                        anchors[ref].append(pt);stop_refs[e['id']].add(ref)
            elif e.get('type')=='way':
                coords=[point(p,lat,lon) for p in e.get('geometry',[]) if p and 'lat' in p]
                if rail in ('platform','platform_edge') and coords:
                    # Platform polygons often cover two tracks; retain every
                    # outline point instead of confusing platform centre with track.
                    for ref in refs(tags.get('ref') or tags.get('local_ref')):anchors[ref].extend(coords)
                if rail=='rail' and len(coords)==len(e.get('nodes',[])) and len(coords)>1:
                    for n,p in zip(e['nodes'],coords):points[n]=p
                    ways.append((e,coords))
        except (KeyError,TypeError,ValueError,OverflowError):continue
    graph=collections.defaultdict(set)
    for e,coords in ways:
        for a,b in zip(e['nodes'],e['nodes'][1:]):graph[a].add(b);graph[b].add(a)
    candidates=collections.defaultdict(list)
    for e,coords in ways:
        tags=e.get('tags') or {}
        if tags.get('service') in ('yard','siding','crossover'):continue
        labels=set(refs(tags.get('railway:track_ref')))
        for node in e['nodes']:labels.update(stop_refs[node])
        for ref in labels:
            if not anchors.get(ref):continue
            gap=min(segment_distance(p,a,b) for p in anchors[ref] for a,b in zip(coords,coords[1:]))
            centre=min(segment_distance((0,0),a,b) for a,b in zip(coords,coords[1:]))
            if gap<=18 and centre<=800:candidates[ref].append((gap,centre,e))
    result={}; buffer_ends={}
    # Give the flattened diagram one consistent geographic axis. Select the
    # passenger track nearest the station; never use the arbitrary OSM way order.
    ranked=[option for options in candidates.values() for option in options]
    ranked.sort(key=lambda option:option[1])
    axis=(1.,0.); orientation='west-east'
    if ranked:
        ns=ranked[0][2]['nodes'];a=points[ns[0]];b=points[ns[-1]]
        dx=b[0]-a[0];dy=b[1]-a[1]
        if abs(dy)>abs(dx):axis=(0.,1.);orientation='south-north'
    # Platform labels alone establish an inventory, not track connectivity.
    for ref,locations in anchors.items():
        if any(distance(p,(0,0))<=750 for p in locations):result[ref]='unknown'
    for ref,options in candidates.items():
        options.sort(key=lambda t:(t[0],t[1]));way=options[0][2]
        nodes=way['nodes']
        # Start on the mapped platform track; follow each end only along
        # unambiguous chains. Never cross a turnout to find a remote buffer.
        found_buffers={n for n in nodes if n in buffers}
        terminal=bool(found_buffers)
        exits=[]
        for start,previous in [(nodes[0],nodes[1]),(nodes[-1],nodes[-2])]:
            length=0.;seen=set(nodes);cur=start;prev=previous
            while True:
                if cur in buffers:terminal=True;found_buffers.add(cur);break
                if len(graph[cur])!=2:break
                nxt=next((n for n in graph[cur] if n!=prev),None)
                if nxt is None or nxt in seen or nxt not in points:break
                length+=distance(points[cur],points[nxt]);seen.add(nxt);prev,cur=cur,nxt
                if length>1200:break
            exits.append(length)
        # Through evidence requires railway geometry on BOTH sides of the
        # station centre, not merely absence of a mapped buffer stop.
        xy=[points[n] for n in nodes]
        dx=xy[-1][0]-xy[0][0];dy=xy[-1][1]-xy[0][1];norm=math.hypot(dx,dy)
        projection=[(x*dx+y*dy)/norm for x,y in xy] if norm else [0]
        spans=min(projection)<-100 and max(projection)>100
        result[ref]='terminal' if terminal else ('through' if spans or min(exits)>150 else 'unknown')
        if found_buffers:
            anchor=(sum(p[0] for p in anchors[ref])/len(anchors[ref]),sum(p[1] for p in anchors[ref])/len(anchors[ref]))
            sides=set('left' if (points[n][0]-anchor[0])*axis[0]+(points[n][1]-anchor[1])*axis[1]<0 else 'right' for n in found_buffers if n in points)
            if len(sides)==1:buffer_ends[ref]=sides.pop()
    return {'platforms':dict(sorted(result.items())[:128]),'source':'OpenStreetMap','bufferEnds':buffer_ends,'orientation':orientation,'estimated':True,'schemaVersion':3,'fetchedAt':int(time.time()*1000)}

def normalize(data):
    """Convert direct OSM JSON node/way data to Overpass-style way geometry."""
    elements=data.get('elements',[])
    if len(elements)>150000:raise ValueError('Map has too many elements')
    nodes={e['id']:e for e in elements if e.get('type')=='node'}
    out=[]
    for e in elements:
        tags=e.get('tags') or {};rail=tags.get('railway')
        if e.get('type')=='node' and (rail=='buffer_stop' or (tags.get('public_transport')=='stop_position' and (tags.get('train')=='yes' or rail=='stop'))):out.append(e)
        if e.get('type')=='way' and rail in ('rail','platform','platform_edge'):
            geometry=[{'lat':nodes[n]['lat'],'lon':nodes[n]['lon']} for n in e.get('nodes',[]) if n in nodes]
            if len(geometry)==len(e.get('nodes',[])):out.append(dict(e,geometry=geometry))
    return {'elements':out}

def direct(lat,lon):
    dy=650/111320;dx=dy/math.cos(math.radians(lat))
    bbox=','.join(f'{v:.7f}' for v in (lon-dx,lat-dy,lon+dx,lat+dy))
    req=urllib.request.Request('https://api.openstreetmap.org/api/0.6/map.json?bbox='+bbox,headers={'User-Agent':'OmarchyTreni/1.2 (cached station track layout)'})
    with urllib.request.build_opener(Redirect).open(req,timeout=20) as response:body=response.read(10_000_001)
    if len(body)>10_000_000:raise ValueError('Map response too large')
    return parse(normalize(json.loads(body)),lat,lon)

def fetch(code,get_coordinates):
    if not re.fullmatch(r'S\d{5}',code):raise ValueError('Invalid station code')
    cache=Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache')))/'omarchy-treni'/'layouts'
    path=cache/(code+'.json')
    try:
        age=time.time()-path.stat().st_mtime
        if 0<=age<7*86400 and path.stat().st_size<100000:
            d=json.loads(path.read_text())
            if d.get('source')=='OpenStreetMap' and d.get('schemaVersion')==3 and isinstance(d.get('platforms'),dict):return d
    except (OSError,ValueError):pass
    coord=get_coordinates(['getCoordinateStazione',code])
    lat=float(coord['lat']);lon=float(coord['lon'])
    if not (35<=lat<=48 and 5<=lon<=20):raise ValueError('Coordinates outside Italy')
    query=f'''[out:json][timeout:18];(way(around:1400,{lat:.6f},{lon:.6f})[railway=rail];node(around:1400,{lat:.6f},{lon:.6f})[railway=buffer_stop];way(around:750,{lat:.6f},{lon:.6f})[railway~"^(platform|platform_edge)$"];node(around:750,{lat:.6f},{lon:.6f})[public_transport=stop_position][train=yes];);out body geom;'''
    error=None
    def save(d):
        cache.mkdir(parents=True,exist_ok=True)
        temp=path.with_suffix('.tmp');temp.write_text(json.dumps(d));temp.replace(path)
        return d
    try:
        return save(direct(lat,lon))
    except (OSError,ValueError,KeyError,TypeError) as e:error=e
    for endpoint in ENDPOINTS:
        try:
            request=urllib.request.Request(endpoint+'?'+urllib.parse.urlencode({'data':query}),headers={'User-Agent':'OmarchyTreni/1.2 (station layout lookup)'})
            with urllib.request.build_opener(Redirect).open(request,timeout=23) as response:body=response.read(6_000_001)
            if len(body)>6_000_000:raise ValueError('Map response too large')
            d=parse(json.loads(body),lat,lon)
            return save(d)
        except (OSError,ValueError,KeyError,TypeError) as e:error=e
    raise ValueError('Station map unavailable') from error
