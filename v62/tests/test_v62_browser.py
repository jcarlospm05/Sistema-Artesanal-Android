import asyncio,json,sqlite3,re
from pathlib import Path
from playwright.async_api import async_playwright
root=Path(__file__).resolve().parents[1];asset=root/'app/src/main/assets'
c=sqlite3.connect(asset/'artesanal.sqlite');c.row_factory=sqlite3.Row
allq=lambda sql:[dict(x) for x in c.execute(sql)]
data={
 'settings':{x['key']:x['value'] for x in allq('SELECT * FROM settings')},
 'families':allq('SELECT * FROM families'),
 'products':allq('SELECT * FROM products'),
 'variants':allq('SELECT v.*,p.name product,f.name family FROM variants v JOIN products p ON p.id=v.product_id JOIN families f ON f.id=p.family_id'),
 'recipes':allq('SELECT r.*,v.name variant,p.name product FROM recipe_versions r JOIN variants v ON v.id=r.variant_id JOIN products p ON p.id=v.product_id ORDER BY version_no DESC'),
 'ingredients':allq('SELECT * FROM ingredients'),
 'recipe_lines':allq('SELECT rl.*,i.name ingredient FROM recipe_lines rl JOIN ingredients i ON i.id=rl.ingredient_id'),
 'skus':allq('SELECT s.*,v.name variant,p.name product,p.family_id,v.alcohol FROM skus s JOIN variants v ON v.id=s.variant_id JOIN products p ON p.id=v.product_id'),
 'batches':[], 'clients':[],'stock':[],'quotes':[],'invoices':[],'payments':[],'packs':[],'pack_lines':[],
 'dashboard':{'billed_cents':0,'collected_cents':0,'receivable_cents':0,'stock':0,'batches':0,'clients':0}
}
source=(asset/'index.html').read_text()
source=source.replace('<link rel="stylesheet" href="ui_v62.css">','<style>'+ (asset/'ui_v62.css').read_text()+'</style>')
source=source.replace('<script src="local_repository.js"></script>', '<script>window.ArtesanalRepository={make:()=>({execute:()=>({})})}</script>')
source=source.replace('<script src="mobile_adapter.js"></script>', '<script>window.localAPI={execute:async function(path,body){if(path==="/api/data")return '+json.dumps(data,ensure_ascii=False).replace('</','<\\/')+';if(path==="/api/calculator/config")return {result:{ok:true}};return {result:{ok:true}}}};window.AndroidFiles={}</script>')
for name in ['calculator_engine.js','calculator_ui.js']:
 source=source.replace('<script src="'+name+'"></script>','<script>'+ (asset/name).read_text().replace('</','<\\/') +'</script>')
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox']);
  for width in (360,393,768):
   page=await browser.new_page(viewport={'width':width,'height':800})
   errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
   await page.set_content(source,wait_until='load');await page.wait_for_timeout(220)
   if await page.locator('#enter').is_visible(): await page.locator('#enter').click()
   assert await page.locator('.mobile-appbar').is_visible(),'mobile appbar missing'
   assert await page.locator('.command-bar').is_visible(),'bottom bar missing'
   await page.locator('#menu-toggle').click(); await page.wait_for_timeout(260)
   assert await page.locator('#drawer').evaluate('(e)=>e.getBoundingClientRect().left') >=0,'drawer not visible'
   await page.locator('#drawer-shade').click(position={'x':width-25,'y':130})
   await page.locator('.command-bar [data-page=calculator]').click()
   assert await page.locator('#calc-workspace').is_visible(),'calc view missing'
   # use ingredients available
   for el in await page.locator('[data-calc-stock]').all():
    v=await el.get_attribute('data-calc-stock'); await el.fill('700' if v=='ING-RON' else '100')
   await page.wait_for_timeout(120)
   assert not errors,errors
   # test order mode 3x750 + 7x350
   await page.locator('[data-calc-mode=order]').click()
   for s,n in [('SKU-VAR-TRAD-RON-750','3'),('SKU-VAR-TRAD-RON-350','7')]:await page.locator('[data-calc-count="'+s+'"]').fill(n)
   await page.wait_for_timeout(100)
   assert '4,700' in await page.locator('#calc-result').inner_text() or '4700' in await page.locator('#calc-result').inner_text(),await page.locator('#calc-result').inner_text()
   if width==393: await page.screenshot(path=str(root/'v62_calculator_393.png'),full_page=True)
   # button `Usar cálculo en producción`
   await page.locator('#calc-transfer').click()
   assert await page.locator('#production-form').is_visible()
   assert await page.locator('[name=actual_ml]').input_value()==''
   # menú: cada subopción debe apuntar a sección real
   if width==393:
    for module in ('dashboard','calculator','catalog','production','stock','clients','quotes','invoices','packs','documents','settings'):
     await page.evaluate('(module)=>window.nav(module)',module)
     names=await page.locator('#view .panel h2').all_inner_texts()
     parts=await page.locator('#drawer .nav-group').all()
     link=page.locator('#drawer [data-page="'+module+'"][data-anchor]')
     count=await link.count()
     print('NAV',module,'panels',len(names),'submenu',count,'titles',names)
     assert len(names)>=count, 'Submenú roto '+module
   # home dashboard quick shortcuts
   await page.locator('.command-bar [data-page=dashboard]').click()
   assert await page.locator('.dashboard-actions .quick-card').count()==8
   overflow=await page.evaluate('document.documentElement.scrollWidth - document.documentElement.clientWidth')
   assert overflow<=1,f'Overflow {width}: {overflow}'
   print('PASS mobile',width,'menu drawer; calculator order; transfer; bottom bar; dashboard shortcuts; overflow',overflow)
   await page.screenshot(path=str(root/f'v62_mobile_{width}.png'),full_page=True)
   await page.close()
  await browser.close()
asyncio.run(main())