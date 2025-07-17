const puppeteer = require('puppeteer')
const config = require('./config')
const server = require('./server')

const sleep = time => new Promise(resolve => setTimeout(resolve, time))

const args = [
    '--no-sandbox',
    '--disable-gpu',
    '--disable-jit',
    '--disable-wasm',
    '--disable-dev-shm-usage',
]

server.run({ subscribe: true }, async ({ message }) => {
  const { challengeId, url } = message
  const challenge = config.challenges.get(challengeId)
  console.log(`Received submission for ${challengeId}: ${url}`);

  const extra_args = [];
  if (challenge.restrict_domains) {
    // Whitelist explicitly provided subdomains, and otherwise blacklist every provided domain
    const PAC_B64 = Buffer.from(`
function FindProxyForURL(url, host) {
${Object.values(challenge.restrict_domains).flat().map(subdomain => `  if (host == "${subdomain}") return "DIRECT";`).join('\n')}
${Object.keys(challenge.restrict_domains).map(domain => `  if (host.endsWith("${domain}")) return "PROXY 127.0.0.1:1";`).join('\n')}
  return "DIRECT";
}`).toString('base64');
    extra_args.push(`--proxy-pac-url=data:application/x-ns-proxy-autoconfig;base64,${PAC_B64}`);
  }

  const browser = await puppeteer.launch({
    headless: 'new',
    args: args.concat(extra_args),
  });

  let ctx = await browser.createBrowserContext();
  try {
    await Promise.race([
      challenge.handler(url, ctx),
      sleep(challenge.timeout),
    ])
  } catch (e) {
    console.error(`challenge handler for ${challengeId} when visiting ${url} errored:`, e)
  }

  try {
    await ctx.close()
  } catch {} finally {
    await browser.close()
  }
})
