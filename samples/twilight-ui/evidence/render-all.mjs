import {chromium, browserOptions} from './browser.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch(browserOptions);
const page=await browser.newPage({viewport:{width:1280,height:720}});const report={errors:[],screens:[]};
page.on('pageerror',e=>report.errors.push(e.message));
for(const screen of ['world','menu','transform','doll','relic','collection','inventory','character','stats','skills','forge','craft','storage','shop','settings']){
 await page.goto('http://127.0.0.1:4173/?screen='+screen);await page.waitForTimeout(150);
 await page.screenshot({path:'evidence/'+screen+'.png'});
 const metrics=await page.evaluate(()=>({buttons:document.querySelectorAll('button').length,brokenImages:[...document.images].filter(x=>!x.complete||!x.naturalWidth).map(x=>x.src),overflow:[...document.querySelectorAll('.game-window,.full-menu')].map(x=>({name:x.className,rect:{x:x.getBoundingClientRect().x,y:x.getBoundingClientRect().y,w:x.getBoundingClientRect().width,h:x.getBoundingClientRect().height}}))}));
 report.screens.push({screen,...metrics});
}
await page.goto('http://127.0.0.1:4173/?screen=collection');await page.locator('[data-action="collection-type"][data-id="transform"]').click();await page.screenshot({path:'evidence/card-collection.png'});
await page.goto('http://127.0.0.1:4173/?screen=inventory');await page.locator('[data-action="item-detail"]').click();await page.screenshot({path:'evidence/item-detail.png'});
await page.goto('http://127.0.0.1:4173/?screen=character');await page.locator('[data-action="detail-stats"]').click();await page.screenshot({path:'evidence/stats-detail.png'});
await page.goto('http://127.0.0.1:4173/?screen=settings');await page.locator('[data-action="setting-tab"][data-id="controls"]').click();await page.locator('[data-action="toggle-hit"]').click();await page.locator('.window-heading [data-id="world"]').click();await page.locator('.hud-tools [data-id="menu"]').click();await page.screenshot({path:'evidence/hit-menu.png'});
await page.locator('.menu-cell[data-id="inventory"]').click();await page.screenshot({path:'evidence/hit-inventory.png'});
await writeFile('evidence/render-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));await browser.close();
