import importlib.util
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('layout',Path(__file__).parents[1]/'layout.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class LayoutTests(unittest.TestCase):
 def fixture(self, buffer=False, ref='1'):
  return {'elements':[
   {'type':'way','id':1,'tags':{'railway':'rail','railway:track_ref':ref},'nodes':[10,11,12],'geometry':[{'lat':43,'lon':10.997},{'lat':43,'lon':11},{'lat':43,'lon':11.003}]},
   {'type':'way','id':2,'tags':{'railway':'platform_edge','ref':ref},'geometry':[{'lat':43.00004,'lon':10.999},{'lat':43.00004,'lon':11.001}]}
  ]+([{'type':'node','id':10,'lat':43,'lon':10.997,'tags':{'railway':'buffer_stop'}}] if buffer else [])}
 def test_through_requires_geometry_on_both_sides(self):
  d=m.parse(self.fixture(),43,11);self.assertEqual(d['platforms']['1'],'through')
 def test_terminal_requires_connected_buffer(self):
  d=m.parse(self.fixture(True),43,11);self.assertEqual(d['platforms']['1'],'terminal')
 def test_buffer_side_uses_geography_not_way_order(self):
  f=self.fixture(True)
  self.assertEqual(m.parse(f,43,11)['bufferEnds']['1'],'left')
  f['elements'][0]['nodes'].reverse();f['elements'][0]['geometry'].reverse()
  self.assertEqual(m.parse(f,43,11)['bufferEnds']['1'],'left')
 def test_eastern_buffer_is_on_right(self):
  f=self.fixture(True);f['elements'][-1]['id']=12;f['elements'][-1]['lon']=11.003
  self.assertEqual(m.parse(f,43,11)['bufferEnds']['1'],'right')
 def test_unconnected_buffer_is_not_evidence(self):
  f=self.fixture();f['elements'].append({'type':'node','id':99,'lat':43,'lon':11,'tags':{'railway':'buffer_stop'}})
  self.assertEqual(m.parse(f,43,11)['platforms']['1'],'through')
 def test_platform_without_geometry_is_unknown(self):
  f=self.fixture();f['elements']=f['elements'][1:]
  self.assertEqual(m.parse(f,43,11)['platforms']['1'],'unknown')
 def test_remote_track_is_not_station_platform(self):
  f=self.fixture();f['elements'][0]['tags']['railway:track_ref']='9'
  self.assertNotIn('9',m.parse(f,43,11)['platforms'])
 def test_incomplete_response_is_rejected(self):
  f=self.fixture();f['remark']='runtime error: timeout'
  with self.assertRaises(ValueError):m.parse(f,43,11)
 def test_refs_keep_nonsequential_labels(self):
  self.assertEqual(m.refs('1; 2 EST; 5'),['1','2 EST','5'])
if __name__=='__main__':unittest.main()
