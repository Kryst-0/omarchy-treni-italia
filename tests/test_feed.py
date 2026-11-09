import importlib.util
import pathlib
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('feed',pathlib.Path(__file__).parents[1]/'feed.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
class FeedTests(unittest.TestCase):
 def sample(self,**changes):
  return dict(numeroTreno=123,codOrigine='S08409',dataPartenzaTreno=1794178800000,codiceCliente=1,**changes)
 def test_actual_platform_precedes_scheduled(self):
  t=f.train(self.sample(binarioEffettivoPartenzaDescrizione='11',binarioProgrammatoPartenzaDescrizione='8'))
  self.assertEqual((t['platform'],t['platformKind']),('11','actual'))
 def test_arrivals_use_arrival_platform(self):
  t=f.train(self.sample(binarioEffettivoPartenzaDescrizione='11',binarioProgrammatoArrivoDescrizione='4'),'arrivi')
  self.assertEqual((t['platform'],t['platformKind']),('4','planned'))
 def test_missing_platform_is_unknown(self):
  t=f.train(self.sample());self.assertEqual((t['platform'],t['platformKind']),('','unknown'))
 def test_other_operators_are_excluded(self):
  t=self.sample();t['codiceCliente']=99
  self.assertEqual(f.trains([t]),[])
 def test_markup_is_only_rendered_as_plaintext(self):
  payload='<img src="https://example.invalid/tracker">'
  t=f.train(self.sample(destinazione=payload));self.assertEqual(t['destination'],payload)
  root=pathlib.Path(__file__).parents[1]
  self.assertIn('textFormat: Text.PlainText',(root/'Label.qml').read_text())
  panel=(root/'Panel.qml').read_text()
  self.assertNotIn('tooltipText: root.',panel)
  self.assertNotIn('text:modelData.name;onClicked',panel)
 def test_invalid_station_cannot_enter_url(self):
  with self.assertRaises(ValueError):f.station('S08409/../../')
 def test_search_rejects_invalid_station_ids(self):
  with patch.object(f,'get',return_value='ROMA|S08409\nEvil|https://bad\n'):
   self.assertEqual(f.dispatch(['search','roma'])['stations'],[{'name':'ROMA','id':'S08409'}])
 def test_redirect_outside_api_is_rejected(self):
  for url in ('http://evil.invalid/','http://www.viaggiatreno.it/','http://user@www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/'):
   with self.assertRaises(ValueError):f.SafeRedirect().redirect_request(None,None,302,'',{},url)
 def test_arrival_estimate_uses_epoch_and_delay(self):
  t=f.train(self.sample(orarioArrivo=1794211800000,ritardo=6,arrivato=True),'arrivi')
  self.assertEqual(t['expectedAt'],1794212160000)
  self.assertTrue(t['arrived'])
 def test_missing_time_does_not_create_a_simulated_arrival(self):
  t=f.train(self.sample(orarioArrivo='2026-11-09'),'arrivi')
  self.assertEqual(t['expectedAt'],0)
  self.assertFalse(t['arrived'])
 def test_error_translations_cover_both_languages(self):
  import json
  root=pathlib.Path(__file__).parents[1]
  english=json.loads((root/'i18n/en.json').read_text())
  italian=json.loads((root/'i18n/it.json').read_text())
  self.assertEqual(set(english),set(italian))
  for message,key in f.ERROR_KEYS.items():
   self.assertIn(key,english)
   self.assertEqual(english[key],message)
if __name__=='__main__':unittest.main()
