import { chromium } from 'playwright-chromium';
const b = await chromium.launch(); const p = await b.newPage({viewport:{width:1280,height:720}});
for (let i=1;i<=43;i++){ await p.goto('http://localhost:3030/'+i); await p.waitForTimeout(2500); await p.screenshot({path:`/tmp/shots/s${String(i).padStart(2,'0')}.png`}); }
await b.close();
