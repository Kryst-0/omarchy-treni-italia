#!/usr/bin/env python3
"""Bounded, read-only adapter for the public ViaggiaTreno website."""
import concurrent.futures
import datetime as dt
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

# Public HTTP source explicitly authorized by the user.
BASE = 'http://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/'
CATEGORIES = 'ES*,IC,EXP,EC,EN,REG,MET'
REGIONS = [(0,'Italia',6),(19,'Abruzzo',9),(15,'Basilicata',9),(17,'Calabria',8),(18,'Campania',8),(8,'Emilia-Romagna',8),(10,'Friuli Venezia Giulia',9),(5,'Lazio',8),(2,'Liguria',8),(1,'Lombardia',8),(11,'Marche',9),(7,'Molise',9),(3,'Piemonte',8),(16,'Puglia',8),(20,'Sardegna',8),(14,'Sicilia',8),(13,'Toscana',8),(21,'Provincia di Trento',8),(22,'Provincia di Bolzano',8),(6,'Umbria',9),(4,"Valle d'Aosta",9),(9,'Veneto',8)]

ERROR_KEYS = {'Redirect outside the permitted data source': 'error.redirect', 'The data source returned too much data': 'error.tooLarge', 'ViaggiaTreno refused the request': 'error.refused', 'Invalid station code': 'error.station', 'Invalid number': 'error.number', 'Invalid region': 'error.region', 'Section unavailable': 'error.route', 'Invalid station board': 'error.boardKind', 'Station board unavailable': 'error.board', 'Network map unavailable': 'error.map', 'Too many sections: select a region': 'error.tooMany', 'The request timed out': 'error.timeout', 'Train unavailable': 'error.train', 'Invalid action': 'error.action'}

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        u = urllib.parse.urlsplit(newurl)
        if (u.scheme not in ('http', 'https') or u.hostname != 'www.viaggiatreno.it'
                or u.port not in (None, 80, 443) or u.username or u.password
                or not u.path.startswith('/infomobilita/resteasy/viaggiatreno/')):
            raise ValueError('Redirect outside the permitted data source')
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def get(path, raw=False):
    url = BASE + '/'.join(urllib.parse.quote(str(p), safe=',*') for p in path)
    req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0 OmarchyTreni/1.0', 'Referer':'https://www.viaggiatreno.it/infomobilita/'})
    with urllib.request.build_opener(SafeRedirect).open(req, timeout=12) as r:
        body = r.read(4_000_001)
    if len(body) > 4_000_000:
        raise ValueError('The data source returned too much data')
    text = body.decode('utf-8')
    if text.lstrip().lower().startswith(('<html','<!doctype')):
        raise ValueError('ViaggiaTreno refused the request')
    return text if raw else json.loads(text)

def clean(v, limit=160):
    return re.sub(r'[\x00-\x1f\x7f]', ' ', html.unescape(str(v or '')))[:limit]

def station(v):
    if not re.fullmatch(r'S\d{5}', str(v)):
        raise ValueError('Invalid station code')
    return v

def number(v, low=0, high=10**15):
    n = int(v)
    if not low <= n <= high:
        raise ValueError('Invalid number')
    return n

def region(v):
    n = number(v,0,22)
    if n not in [r[0] for r in REGIONS]:
        raise ValueError('Invalid region')
    return n

def allowed(t):
    # Source uses multiple customer IDs for Trenitalia divisions. Exclude
    # other operators explicitly; do not infer ownership from train category.
    return t.get('codiceCliente') in (1,2,63,64)

def train(t, kind='route'):
    arrival = kind == 'arrivi'
    suffix = 'Arrivo' if arrival else 'Partenza'
    actual = clean(t.get('binarioEffettivo'+suffix+'Descrizione'),24)
    planned = clean(t.get('binarioProgrammato'+suffix+'Descrizione'),24)
    stamp=t.get('orarioArrivo' if arrival else 'orarioPartenza')
    scheduled=number(stamp) if isinstance(stamp,(int,float)) and not isinstance(stamp,bool) else 0
    delay=number(t.get('ritardo') or 0,-1440,10080)
    return {'scheduledAt':scheduled, 'expectedAt':scheduled + delay*60000 if scheduled else 0,
            'arrived':arrival and t.get('arrivato') is True,
            'number':clean(t.get('compNumeroTreno') or t.get('numeroTreno'),40),
            'id':str(number(t.get('numeroTreno'))),
            'originId':station(t.get('codOrigine')),
            'date':str(number(t.get('dataPartenzaTreno'))),
            'origin':clean(t.get('origineEstera') or t.get('origine')),
            'destination':clean(t.get('destinazioneEstera') or t.get('destinazione')),
            'time':clean(t.get('compOrarioArrivo' if arrival else 'compOrarioPartenza'),20),
            'delay':number(t.get('ritardo') or 0,-1440,10080),
            'platform':actual or planned, 'platformKind':'actual' if actual else ('planned' if planned else 'unknown'),
            'cancelled':t.get('provvedimento') == 1,
            'departed':t.get('nonPartito') is False and t.get('inStazione') is True,
            'operator':t.get('codiceCliente')}

def trains(items,kind='route'):
    out=[]
    for t in items[:1200]:
        if not isinstance(t,dict) or not allowed(t): continue
        try: out.append(train(t,kind))
        except (ValueError,TypeError): continue
    return out

def route(reg,ab,ba):
    data=get(['dettagliTratta',region(reg),number(ab),number(ba),CATEGORIES,'null'])
    if not isinstance(data,list): raise ValueError('Section unavailable')
    return [{'name':clean(d.get('tratta')),'trains':trains(d.get('treni') or [])} for d in data[:4] if isinstance(d,dict)]

def dispatch(a):
    action=a[0]
    if action=='layout':
        import layout
        return {'layout':layout.fetch(station(a[1]),get)}
    if action=='search':
        query=clean(a[1],80).strip()
        if len(query)<2:return {'stations':[]}
        text=get(['autocompletaStazione',query],True)
        out=[]
        for line in text.splitlines()[:200]:
            if '|' not in line:continue
            name,code=line.rsplit('|',1)
            if re.fullmatch(r'S\d{5}',code):out.append({'name':clean(name),'id':code})
        return {'stations':out[:20]}
    if action=='board':
        code=station(a[1]); kind=a[2]
        if kind not in ('arrivi','partenze'):raise ValueError('Invalid station board')
        now=dt.datetime.now(ZoneInfo('Europe/Rome'))
        # Website accepts a JavaScript Date string; numeric offset is DST aware.
        stamp=now.strftime('%a %b %d %Y %H:%M:%S GMT%z')
        data=get([kind,code,stamp])
        if not isinstance(data,list):raise ValueError('Station board unavailable')
        return {'trains':trains(data,kind)}
    if action=='map':
        reg=region(a[1]); zoom=next(r[2] for r in REGIONS if r[0]==reg)
        data=get(['elencoTratte',reg,zoom,CATEGORIES,'null',int(time.time()*1000)])
        if not isinstance(data,list):raise ValueError('Network map unavailable')
        segments=[]
        for t in data[:5000]:
            try:
                coords=[float(t[k]) for k in ('longitudineA','latitudineA','longitudineB','latitudineB')]
                if not all(-180<=v<=180 for v in coords) or not all(-90<=coords[i]<=90 for i in (1,3)):continue
                segments.append({'a':number(t['trattaAB']),'b':number(t['trattaBA']),'points':coords,'active':t.get('occupata') is True})
            except (KeyError,TypeError,ValueError):continue
        return {'segments':segments}
    if action=='route':return {'routes':route(*a[1:4])}
    if action=='all':
        reg=region(a[1]); out={}; failures=0; pairs=set()
        deadline=time.monotonic()+180
        scope=[r[0] for r in REGIONS if r[0]!=0] if reg==0 else [reg]
        # National search covers each regional map, including regional trains
        # omitted by the source's summary national map.
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            maps={pool.submit(dispatch,['map',str(r)]):r for r in scope}
            for f in concurrent.futures.as_completed(maps):
                try:
                    pairs.update((maps[f],s['a'],s['b']) for s in f.result()['segments'] if s['active'])
                except Exception:failures+=1
            if len(pairs)>2000:raise ValueError('Too many sections: select a region')
            def fetch(pair):
                if time.monotonic()>deadline:raise TimeoutError('The request timed out')
                return route(*pair)
            futures=[pool.submit(fetch,pair) for pair in sorted(pairs)]
            for f in concurrent.futures.as_completed(futures):
                try:
                    for r in f.result():
                        for t in r['trains']:out[(t['id'],t['originId'],t['date'])]=t
                except Exception:failures+=1
        return {'trains':sorted(out.values(),key=lambda t:(t['destination'],t['number'])),'partial':failures>0,'failedRoutes':failures}
    if action=='train':
        data=get(['andamentoTreno',station(a[1]),number(a[2]),number(a[3])])
        if not isinstance(data,dict) or not allowed(data):raise ValueError('Train unavailable')
        stops=[]
        for s in (data.get('fermate') or [])[:150]:
            stops.append({'name':clean(s.get('stazione')),'time':clean(s.get('compOrarioPartenza') or s.get('compOrarioArrivo'),20),
                          'platform':clean(s.get('binarioEffettivoPartenzaDescrizione') or s.get('binarioEffettivoArrivoDescrizione') or s.get('binarioProgrammatoPartenzaDescrizione') or s.get('binarioProgrammatoArrivoDescrizione'),24)})
        return {'train':train(data),'stops':stops}
    raise ValueError('Invalid action')

if __name__=='__main__':
    try: result=dispatch(sys.argv[1:]); result['updated']=dt.datetime.now(ZoneInfo('Europe/Rome')).strftime('%H:%M:%S'); result['ok']=True
    except Exception as e:
        message=clean(str(e),220)
        result={'ok':False,'error':message,'errorKey':ERROR_KEYS.get(message,'error.network')}
    print(json.dumps(result,ensure_ascii=False))
