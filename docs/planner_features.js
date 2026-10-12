/* BOBC v0.4 · Presets y distribuciones: no escriben en IndexedDB. */
(function(root){'use strict';
function demo(){return {isDemo:true,productId:'demo',recipeId:'demo-recipe',baseMl:4000,extraMl:700,extraCost:700,additiveLabel:'Ron Brugal 700 ml',batchCount:1,distributionMode:'mixed',ingredients:[
{name:'Leche evaporada',quantity:8,unit:'latas',cost:480},
{name:'Leche condensada',quantity:4,unit:'latas',cost:520},
{name:'Leche entera',quantity:4,unit:'tazas',cost:80},
{name:'Canela',quantity:4,unit:'porciones',cost:20},
{name:'Huevos (yemas)',quantity:12,unit:'unidades',cost:120},
{name:'Maicena',quantity:4,unit:'cucharadas',cost:20},
{name:'Sal',quantity:4,unit:'pizcas',cost:4}
],skus:[
{id:'demo-750-e',title:'750 ml estándar',sizeMl:750,count:3,containerCost:55,labelCost:25,manualPrice:'',tier:'estandar'},
{id:'demo-350-e',title:'350 ml estándar',sizeMl:350,count:7,containerCost:35,labelCost:25,manualPrice:'',tier:'estandar'},
{id:'demo-750-p',title:'750 ml premium',sizeMl:750,count:0,containerCost:55,labelCost:25,manualPrice:'',tier:'premium'},
{id:'demo-350-p',title:'350 ml premium',sizeMl:350,count:0,containerCost:35,labelCost:25,manualPrice:'',tier:'premium'}
],extras:[],method:'margin',target:35,saleMode:'unidad'};}
function distribute(plan,mode){plan.distributionMode=mode; if(mode==='manual')return;for(const s of plan.skus)s.count=0;const total=Math.max(0,(Number(plan.baseMl)+Number(plan.extraMl))*Number(plan.batchCount||1));let eligible=plan.skus.filter(s=>(s.tier||'estandar')!=='premium');if(!eligible.length)eligible=plan.skus.slice();const sorted=[...eligible].sort((a,b)=>b.sizeMl-a.sizeMl),large=sorted[0],small=sorted.find(x=>Number(x.sizeMl)<Number(large.sizeMl));if(!large)return;
if(mode==='large'||!small){large.count=Math.floor(total/large.sizeMl);return}
if(mode==='small'){small.count=Math.floor(total/small.sizeMl);return}
let best=null;const maxLarge=Math.floor(total/large.sizeMl);for(let a=0;a<=maxLarge;a++){const b=Math.floor((total-a*large.sizeMl)/small.sizeMl);const left=total-a*large.sizeMl-b*small.sizeMl;const candidate={a,b,left,count:a+b};if(!best||left<best.left||(left===best.left&&candidate.count<best.count))best=candidate}
large.count=best.a;small.count=best.b;
}
root.BOBCPlannerFeatures={demo,distribute};
})(window);
