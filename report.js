const chromeLauncher = require('chrome-launcher');
const { Builder, By } = require('selenium-webdriver');
const { Options } = require('selenium-webdriver/chrome');
const CDP = require('chrome-remote-interface');
const fs = require('fs');

TOP_URL = 'https://lovelive-aqoursclub.jp';
REPORT_URL = 'https://lovelive-aqoursclub.jp/mob/cont/contLis.php?site=AC&ima=3232&cd=133';
USER_ID = '';
PASSWD = '';
M3U8_URL_LIST_FILE_NAME = 'url.txt';

let port = 9222;
let report_url = null;
let driver = null;
let chrome = null;

function testChromeRemoteInterface() {
  let page = 0;
  CDP({port: port},(client)=> {
    const { Network, Page, DOM } = client;
    Network.requestWillBeSent((params)=> {
      if( !params.request.url.includes('m3u8') ) return;
      //console.log('Network.requestWillBeSent', params.request.url);
      fs.appendFile(M3U8_URL_LIST_FILE_NAME, (params.request.url + '\n\r'), (err)=> {
        if(err) console.error('Failed to write file.', err);
      });
    });
    Page.loadEventFired(()=> {
      console.log('Page.loadEventFired');
      DOM.getDocument((error, params)=> {
        const options = {
	  'nodeId': params.root.nodeId,
	  'selector': '#container > div > section.paging > section > a:nth-child(2)'
	};
	DOM.querySelector(options, (error, params)=> {
	  DOM.getAttributes({nodeId: params.nodeId}, (error, params)=> {
	    const i = params.attributes.indexOf('class');
	    if( !params.attributes[i+1].includes('disable') ) {
	      page += 1;
	      const url = report_url + '&page=' + page;
	      return Page.navigate({url: url});
	    } else {
	      client.close();
	      chrome.kill();
	    }
	  });
	});
      });
    });
    Promise.all([
      console.log('Promise.all'),
      Network.enable(),
      Page.enable()
    ]).then(()=> {
      console.log('Promise.then');
      //fs.unlinkSync(M3U8_URL_LIST_FILE_NAME);
      return Page.navigate({url: report_url});
    });
  });
}

async function testSelenium(chrome) {
  const server_url = 'localhost:' + port;
  console.log('Server URL: ', server_url);
  let options = new Options();
  options.options_['debuggerAddress'] = server_url;
  driver = new Builder().forBrowser('chrome').setChromeOptions(options).build();
  await driver.get(TOP_URL);
  await driver.findElement(By.name('loginUser')).sendKeys(USER_ID);
  await driver.findElement(By.name('loginPass')).sendKeys(PASSWD);
  await driver.findElement(By.xpath('/html/body//form[@name="ajaxLoginForm"]/div[position()=3]/a')).click();
  await driver.getTitle().then(function(title){
    console.log('Title: ', title);
    driver.findElement(By.xpath('/html/body/header/div/nav/div/ul/li[position()=5]/a')).getAttribute('href').then(function(val){
      console.log('Report path: ', val);
      report_url = val;
      testChromeRemoteInterface();
    });
    //testChromeRemoteInterface();
    //driver.close();
  });
}


function launchChrome() {
  chromeLauncher.launch({
    startingUrl: 'https://google.com',
    //chromeFlags: ['--no-sandbox']
    //chromeFlags: ['--headless', '--disable-gpu', '--no-sandbox']
    chromeFlags: ['--headless', '--no-sandbox']
  }).then(c => {
    chrome = c;
    port = chrome.port;
    console.log("Chrome debugging port running on " + port);
    testSelenium(chrome);
  });
}

launchChrome();
console.log('code end');
