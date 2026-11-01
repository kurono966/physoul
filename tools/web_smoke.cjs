// PLAYWRIGHT_MODULE may point to a preinstalled Playwright package.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve('build/web');
const mime = {'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server = http.createServer((req,res)=>{
	if(req.url==='/favicon.ico'){res.writeHead(204).end();return;}
  const relative = decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/physoul\//,'');
  const file = path.resolve(root,relative || 'index.html');
  if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  if(!fs.existsSync(file)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
(async()=>{
 let browser;
 try{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1280,height:800}});
  const errors=[];
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('console',message=>{if(/SCRIPT ERROR|Parse Error|Failed to load|Aborted\(/.test(message.text()))errors.push(message.text());});
  page.on('requestfailed',request=>errors.push(request.url()+': '+request.failure()?.errorText));
  page.on('response',response=>{if(response.status()>=400)errors.push(`${response.status()} ${response.url()}`);});
  const url=process.env.GAME_URL||`http://127.0.0.1:${server.address().port}/physoul/`;
  await page.goto(url);
  await page.getByRole('button',{name:'プレイ',exact:true}).click();
  await page.waitForFunction(()=>document.getElementById('cover').style.display==='none',{},{timeout:90000});
  await page.locator('#canvas').click({position:{x:640,y:550}});
  await page.waitForTimeout(1200);
  await page.keyboard.press('m');
  await page.waitForTimeout(500);
  await page.locator('#canvas').click({position:{x:640,y:550}});
  await page.keyboard.press('4');
  await page.keyboard.press('Tab');
  await page.waitForTimeout(500);
  await page.keyboard.down('w');
  await page.waitForTimeout(250);
  await page.keyboard.up('w');
  await page.keyboard.press('h');
  await page.screenshot({path:'build/web-browser.png'});
  console.log(JSON.stringify({url,canvas:await page.locator('#canvas').evaluate(c=>({width:c.width,height:c.height})),errors},null,2));
  if(errors.length)process.exitCode=1;
 }catch(error){console.error(String(error));process.exitCode=1;}
 finally{if(browser)await browser.close();server.close();}
})();
