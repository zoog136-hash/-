import {chromium, browserOptions} from './browser.mjs';
const browser=await chromium.launch(browserOptions);
const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:1});
page.on('pageerror',e=>console.log('PAGEERROR',e.message));
for(const s of ['transform','inventory']){
 await page.goto('http://127.0.0.1:4173/?screen='+s);await page.waitForTimeout(300);await page.screenshot({path:'evidence/'+s+'-pass1.png'});
 console.log(s,await page.locator('.game-window').boundingBox());
}
await browser.close();
