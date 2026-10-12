/** Calculadora comercial v6.2. Funciones puras: ninguna operación modifica inventario. */
(function(root){'use strict';
const EPS=1e-8;
const nonneg=(v,label)=>{const n=Number(v);if(!Number.isFinite(n)||n<0)throw Error(label+' debe ser un número mayor o igual a cero');return n};
const positive=(v,label)=>{const n=nonneg(v,label);if(n<=0)throw Error(label+' debe ser mayor que cero');return n};
const up3=n=>Math.ceil((n-EPS)*1000)/1000;
function formula(recipe,lines){const yieldMl=positive(recipe.yield_ml,'Rendimiento de fórmula');if(!Array.isArray(lines)||!lines.length)throw Error('La fórmula no tiene ingredientes');return {yieldMl,lines:lines.map(x=>({...x,qty:positive(x.quantity,'Cantidad de '+x.name)}))}}
function sizes(items){const unique=new Set();return(items||[]).map(s=>{const sizeMl=positive(s.size_ml,'Tamaño del envase');if(unique.has(String(s.id)))throw Error('Presentación repetida');unique.add(String(s.id));return {...s,sizeMl};})}
function wasteFactor(lossPct){const loss=nonneg(lossPct??0,'Merma %');if(loss>=100)throw Error('La merma debe ser menor al 100%');return 1-loss/100}
function available({recipe,lines,skus,stock={},mix={},lossPct=0}){
 const f=formula(recipe,lines),net=wasteFactor(lossPct),packages=sizes(skus);
 const ratios=f.lines.map(l=>{if(stock[l.ingredient_id]===undefined||stock[l.ingredient_id]==='')throw Error('Indica cuánto tienes de '+l.name);return {ingredient_id:l.ingredient_id,name:l.name,ratio:nonneg(stock[l.ingredient_id],'Disponible de '+l.name)/l.qty};});
 const factor=Math.min(...ratios.map(x=>x.ratio));const grossMl=Math.floor(f.yieldMl*factor+EPS),netMl=Math.floor(grossMl*net+EPS);
 const perSize=packages.map(x=>({...x,maxBottles:Math.floor(netMl/x.sizeMl)}));
 let chosen=perSize.map(x=>({...x,bottles:nonneg(mix[x.id]??0,'Botellas '+x.sizeMl+' ml')}));
 if(chosen.some(x=>!Number.isInteger(x.bottles)))throw Error('Las botellas deben ser cantidades enteras');
 const hasMix=chosen.some(x=>x.bottles>0);
 if(!hasMix){let remaining=netMl;chosen=chosen.map(x=>({...x,bottles:0})).sort((a,b)=>b.sizeMl-a.sizeMl);for(const x of chosen){x.bottles=Math.floor(remaining/x.sizeMl);remaining-=x.bottles*x.sizeMl}}
 const bottledMl=chosen.reduce((sum,x)=>sum+x.sizeMl*x.bottles,0);
 if(bottledMl>netMl)throw Error('La combinación de botellas supera el rendimiento disponible');
 return {mode:'available',grossMl,netMl,limiting:ratios.filter(x=>Math.abs(x.ratio-factor)<EPS).map(x=>x.name),factor,bottledMl,leftoverMl:netMl-bottledMl,perSize,distribution:chosen,ingredients:f.lines.map(x=>({name:x.name,unit:x.unit,usedQty:up3(x.qty*factor),onHand:nonneg(stock[x.ingredient_id],'Disponible')}))};
}
function order({recipe,lines,skus,counts={},onHand={},packageSizes={},packagePrices={},lossPct=0}){
 const f=formula(recipe,lines),net=wasteFactor(lossPct),packages=sizes(skus);
 const requested=packages.map(s=>{const bottles=nonneg(counts[s.id]??0,'Botellas '+s.sizeMl);if(!Number.isInteger(bottles))throw Error('La cantidad de botellas debe ser entera');return {...s,bottles}});
 const targetMl=requested.reduce((t,s)=>t+s.sizeMl*s.bottles,0);
 if(targetMl<=0)throw Error('Indica al menos una botella');
 const grossMl=Math.ceil(targetMl/net-EPS),scale=grossMl/f.yieldMl;
 const ingredients=f.lines.map(l=>{
   const needed=up3(l.qty*scale),availableQty=nonneg(onHand[l.ingredient_id]??0,'Existencia de '+l.name);
   const size=positive(packageSizes[l.ingredient_id]??1,'Presentación de compra de '+l.name);
   const price=nonneg(packagePrices[l.ingredient_id]??0,'Precio de '+l.name);
   const shortage=Math.max(0,needed-availableQty),packagesToBuy=Math.max(0,Math.ceil(shortage/size-EPS));
   return {ingredient_id:l.ingredient_id,name:l.name,unit:l.unit,needed,availableQty,shortage:up3(shortage),packageSize:size,packagesToBuy,purchasedQty:packagesToBuy*size,packagePrice:price,buyCost:Math.round(packagesToBuy*price*100)/100};
 });
 return {mode:'order',targetMl,grossMl,expectedNetMl:Math.floor(grossMl*net+EPS),scale,bottles:requested.filter(s=>s.bottles>0),ingredients,totalIngredientsCost:Math.round(ingredients.reduce((sum,x)=>sum+x.buyCost,0)*100)/100,containerCost:Math.round(requested.reduce((sum,x)=>sum+x.bottles*Number(x.bottle_cost_cents||0),0))/100};
}
root.ArtesanalCalculator={available,order};if(typeof module!=='undefined')module.exports=root.ArtesanalCalculator;
})(typeof window==='undefined'?globalThis:window);