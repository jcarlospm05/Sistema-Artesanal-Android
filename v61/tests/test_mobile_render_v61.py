from pathlib import Path
import sqlite3,json,asyncio
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]; assets=ROOT/'app/src/main/assets';db=sqlite3.connect(assets/'artesanal.sqlite');db.row_factory=sqlite3.Row
read=lambda q:[dict(x) for x in db.execute(q)]
DATA={
 'settings':dict((x['key'],x['value']) for x in read('select key,value from settings')),
 'families':read('select * from families'),
 'products':read('select p.*,f.name family from products p join families f on f.id=p.family_id'),
 'variants':read('select v.*,p.name product,f.name family from variants v join products p on p.id=v.product_id join families f on f.id=p.family_id'),
 'ingredients':read('select * from ingredients'),
 'recipes':read('select r.*,v.name variant,p.name product from recipe_versions r join variants v on v.id=r.variant_id join products p on p.id=v.product_id'),
 'recipe_lines':read('select rl.*,i.name ingredient from recipe_lines rl join ingredients i on i.id=rl.ingredient_id'),
 'packs':read('select * from packaging_packs'),
 'pack_lines':read('select * from pack_lines'),
 'skus':read('select s.*,v.name variant,p.name product,p.family_id,v.alcohol from skus s join variants v on v.id=s.variant_id join products p on p.id=v.product_id'),
 'clients':[], 'batches':[], 'stock':[], 'quotes':[], 'invoices':[], 'payments':[],
 'dashboard':{'clients':0,'batches':0,'stock':0,'billed_cents':0,'collected_cents':0,'receivable_cents':0}
}
html=(assets/'index.html').read_text(); html=html.replace('<script src="local_repository.js"></script>','').replace('<script src="mobile_adapter.js"></script>', '<script>window.localAPI={execute:(path,body)=>path==="/api/data"?'+json.dumps(DATA,ensure_ascii=False)+':{result:{ok:true}}};window.AndroidFiles={printHtml:()=>{}}</script>')
errors=[]; results=[]
async def main():
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
  for width in (360,393,768):
   page=await browser.new_page(viewport={'width':width,'height':850}); page.on('pageerror',lambda e:errors.append(str(e)))
   await page.set_content(html,wait_until='load'); await page.wait_for_timeout(100)
   await page.evaluate('document.querySelector("#welcome")?.remove()');await page.evaluate('(d)=>{data=d;render()}',DATA)
   for module in ('dashboard','catalog','production','stock','clients','quotes','invoices','packs','documents','settings'):
    await page.evaluate('(x)=>nav(x)',module)
    e=await page.evaluate('({body:document.body.scrollWidth,viewport:document.documentElement.clientWidth,fields:document.querySelectorAll("#view input,#view select").length,title:document.querySelector("#page-name").textContent})')
    good=e['body']<=e['viewport']+1 and bool(e['title'])
    results.append({'width':width,'module':module,'pass':good,'body_width':e['body'],'viewport':e['viewport'],'form_controls':e['fields']})
    if width==393 and module=='production': await page.screenshot(path=str(ROOT/'docs/PRODUCCION_v61_393.png'),full_page=True)
   await page.close()
  # snapshot document independent of SQLite bridge, preview logo encoded from historical data
  page=await browser.new_page(viewport={'width':393,'height':850});page.on('pageerror',lambda e:errors.append(str(e)))
  await page.set_content(html,wait_until='load');await page.evaluate('document.querySelector("#welcome")?.remove()');await page.evaluate('(d)=>{data=d;render()}',DATA)
  doc={'kind':'factura','header':{'number':'FAC-PRUEBA-61','client':'Comprador Original','phone':'8091234567','issued_at':'2026-10-12'},'company':'Mi Taller Anterior','logo':'','shipping_cents':12500,'discount_cents':2500,'total_cents':80000,'lines':[{'description':'Ponche Turrón', 'qty':3,'line_total_cents':70000}]}
  await page.evaluate('(d)=>showDocument(d)',doc)
  txt=await page.locator('#print-area').inner_text()
  assert 'Mi Taller Anterior' in txt and 'Comprador Original' in txt and 'Transporte:' in txt and 'Descuento:' in txt
  await page.screenshot(path=str(ROOT/'docs/DOCUMENTO_v61_393.png'),full_page=True)
  await page.close();await browser.close()
 out={'tested':len(results),'passed':sum(x['pass'] for x in results),'errors':errors,'documents_preview':'OK','cases':results}
 (ROOT/'docs/TEST_RENDER_v61.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
 print('UI',out['passed'],'/',out['tested'],'javascript_errors',len(errors),'document_preview',out['documents_preview']);
 if len(errors) or out['passed']!=out['tested']:raise RuntimeError(str(out)[:500])
asyncio.run(main())