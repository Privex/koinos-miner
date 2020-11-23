'use strict';
require('dotenv').config();
const { program } = require('commander');
let KoinosMiner = require('.');
const readlineSync = require('readline-sync');
const crypto = require('crypto');
var Web3 = require('web3');
var w3 = new Web3(program.endpoint);
var fs = require('fs');
const packagejson = require('./package.json');

const VER = packagejson.version;

function conf_get(k, fallback = null) {
  if (k in process.env) return process.env[k];
  if (k.toUpperCase() in process.env) return process.env[k.toUpperCase()];
  return fallback;
}

function is_true(v) {
   if (v === true) return true;
   if (v >= 1 || v === "1") return true;
   if (v === "true" || v === "True" || v === "TRUE") return true;
   if (v === "yes" || v === "Yes" || v === "YES") return true;
   if (v === "y" || v === "Y" || v === "t" || v === "T") return true;
   return false;
}

var config = {
  address: conf_get('address'),
  endpoint: conf_get('endpoint', 'http://mining.koinos.io'),
  tip: conf_get('tip', '5'),
  proof_period: conf_get('proof_period', '172800'), // 86400 * 2 = 172800 (2 days)
  gas_multiplier: conf_get('gas_multiplier', '1'),
  gas_price_limit: conf_get('gas_price_limit', '1000000000000'),
  gwei_limit: conf_get('gwei_limit', '1000'),
  speed: conf_get('speed', false),
  gwei_minimum: conf_get('gwei_minimum', '15'),
  private_key: conf_get('private_key', conf_get('privateKey')),
  use_env: is_true(conf_get('use_env', conf_get('useEnv', false))),
  privex_mode: is_true(conf_get('privex_mode', conf_get('privexMode', false))),
  use_pool: is_true(conf_get('use_pool', conf_get('usePool', true))),
  pool_endpoint: conf_get('pool_endpoint', conf_get('poolEndpoint', 'https://api.koinos.club'))
};

config.useEnv = config.use_env;

program
   .version(packagejson.version, '-v, --version')
   .usage('[OPTIONS]...')
   .option('-a, --addr <addr>', 'An ethereum address')
   .option('-e, --endpoint <endpoint>', 'An ethereum endpoint', 'http://mining.koinos.io')
   .option('-t, --tip <percent>', 'The percentage of mined coins to tip the developers', config.tip)
   .option('-p, --proof-period <seconds>', 'How often you want to submit a proof on average', config.proof_period)
   .option('-pe, --pool-endpoint <pool endpoint>', 'A mining pool endpoint', config.pool_endpoint)
   .option('-k, --key-file <file>', 'AES encrypted file containing private key')
   .option('-m, --gas-multiplier <multiplier>', 'The multiplier to apply to the recommended gas price', config.gas_multiplier)
   .option('-l, --gas-price-limit <limit>', 'The maximum amount of gas to be spent on a proof submission', config.gas_price_limit)
   .option('-g, --gwei-limit <limit>', 'The maximum amount of gas in gwei unit to be spent on a proof submission', config.gwei_limit)
   .option('-b, --gwei-minimum <limit>', 'The minimum amount of gas in gwei unit to be spent on a proof submission', config.gwei_minimum)
   .option('-s, --speed <speed>', `How fast should the transaction be: slow | medium | optimal | fast | fastest (https://fees.upvest.co/estimate_eth_fees)`)
   .option('--import', 'Import a private key')
   .option('--export', 'Export a private key')
   .option('--use-env', 'Use private key from .env file (privateKey=YOUR_PRIVATE_KEY)')
   .option('--lean', `(not yet working) Use this option to have a less verbose logging and so you can actually see when you're finding something`)
   .option('--privex', 'Using this option is going to reward 1% (or --tip if > 0) of your mined coins to Privex Inc. (community developer)')
   .option('--wolf-mode', 'Using this option is going to reward 1% (or --tip if > 0) of your mined coins to therealwolf (community developer)')
   .option('--test-mode', `DON'T USE IF NOT DEV!`)
   .option('--no-pool', 'Do not use a mining pool')
   .parse(process.argv);

if (!program.addr && !config.address) {
  console.error("ERROR: You MUST specify your Ethereum address, either by using '-a 0xABCD1234abcDeF' - or have it in the environment variable 'ADDRESS'");
  console.error("Exiting miner!");
  process.exit(0);
}

config.addr             = config.address = program.addr ? program.addr : config.address;
config.endpoint         = program.endpoint ? program.endpoint : config.endpoint;
config.pool_endpoint    = config.poolEndpoint  = program.poolEndpoint ? program.poolEndpoint : config.poolEndpoint;
config.tip              = program.tip ? program.tip : config.tip;
config.speed            = program.speed ? program.speed : config.speed;
config.useEnv           = config.use_env = program.useEnv ? program.useEnv : config.use_env;
config.usePool          = config.use_pool = program.noPool ? false : config.use_pool;
config.proofPeriod      = config.proof_period = program.proofPeriod ? program.proofPeriod : config.proof_period;
config.gasMultiplier    = config.gas_multiplier = program.gasMultiplier ? program.gasMultiplier : config.gas_multiplier;
config.gasPriceLimit    = config.gas_price_limit = program.gasPriceLimit ? program.gasPriceLimit : config.gas_price_limit;
config.gweiLimit        = config.gwei_limit = program.gweiLimit ? program.gweiLimit : config.gwei_limit;
config.gweiMinimum      = config.gwei_minimum = program.gweiMinimum ? program.gweiMinimum : config.gwei_minimum;
config.privexMode       = config.privex_mode = program.privex ? program.privex : config.privex_mode;
config.wolfMode         = config.wolf_mode = program.wolfMode ? program.wolfMode : config.wolf_mode;

console.log(` _  __     _                   __  __ _`);
console.log(`| |/ /    (_)                 |  \\/  (_)`);
console.log(`| ' / ___  _ _ __   ___  ___  | \\  / |_ _ __   ___ _ __`);
console.log(`|  < / _ \\| | '_ \\ / _ \\/ __| | |\\/| | | '_ \\ / _ \\ '__|`);
console.log(`| . \\ (_) | | | | | (_) \\__ \\ | |  | | | | | |  __/ |`);
console.log(`|_|\\_\\___/|_|_| |_|\\___/|___/ |_|  |_|_|_| |_|\\___|_|`);
console.log(`--------- Version ${VER} (Privex/Wolf Edition) ----------`);
console.log(`--------------------------------------------------------`);

const privexModeOnly = (!program.tip || program.tip === '0') && config.privexMode;
const wolfModeOnly = (!program.tip || program.tip === '0') && config.wolfMode;

const getProofPeriodDate = () => {
   const proofPeriod = Number(program.proofPeriod);
   if(proofPeriod >= 86400) {
      return `${Math.round(proofPeriod / 86400)}d`;
   } else if(proofPeriod >= 86400 / 24) {
      return `${Math.round(proofPeriod / 3600)}h`;
   } else {
      return `${Math.round(proofPeriod / 60)}m`;
   }
}

const privex_tip_address = '0x2e8687E5349f38e833F9111b25761B903902AdC0';
const tip_addresses = [
   "0x292B59941aE124acFca9a759892Ae5Ce246eaAD2",
   "0xbf3C8Ffc87Ba300f43B2fDaa805CcA5DcB4bC984",
   "0x407A73626697fd22b1717d294E6B39437531013d",
   "0x69486fda786D82dBb61C78847A815d5F615C2B15",
   "0x434eAbB24c0051280D1CC0AF6E12bF59b5F932e9",
   "0xa524095504833359E6E1d41161102B1a314b97C0",
   "0xf7771105679d2bfc27820B93C54516f1d8772C88",
   "0xa0fc784961E6aCc30D28FA072Aa4FB3892C1938A",
   "0x306443eeBf036A35a360f005BE306FD7855e8Cb5",
   "0x40609227175ac3093086072391Ff603db2e3D72a",
   "0xE536fdfF635aEB8B9DFd6Be207e1aE10A58fB85e",
   "0x9d2DfA864887dF1f41bC02CE94C74Bb0dE471Da6",
   "0x563f6EB769883f98e56BF20127c116ABce8EF564",
   "0x33D682B145f4AA664353b6B6A7B42a13D1c190a9",
   "0xea701365BC23Aa696D5DaFa0394cC6f1a18b2832",
   "0xc8B02B313Bd56372D278CAfd275641181d29793d",
   "0xd73B6Da85bE7Dae4AC2A7D5388e9F237ed235450",
   "0x03b6470040b5139b82F96f8D9D61DAb43a01a75c",
   "0xF8357581107a12c3989FFec217ACb6cd0336acbE",
   "0xeAdB773d0896EC5A3463EFAF6A1b763ECEC33743",
   "0x746696B8900a901200bAfE6398879fDe23B30b45",
   privex_tip_address
   ];

const contract_address = '0xa18c8756ee6B303190A702e81324C72C0E7080c5';

const wolf_tip_address = '0x13FB459eB72D7c8B1E45a181a079aD8a683ce98F';

var account;

const hashrates = [];

let warningCallback = function(warning) {
   console.log(`[JS](app.js) Warning: `, warning);
};

let errorCallback = function(error) {
   console.log(`[JS](app.js) Error: `, error);
};

let finishedCallback = function () {
   try {
      const average = hashrates.reduce((a, b) => a + b) / hashrates.length;
      console.log(`[JS] (app.js) Average Hashrate: ${ KoinosMiner.formatHashrate(average)}`)
   } catch (error) {}
};

let hashrateCallback = function(hashrate)
{
   /* if(program.lean) {
      if(hashrate) hashrates.push(hashrate)
   } else { */
   console.log(`[JS](app.js) Hashrate: ` + KoinosMiner.formatHashrate(hashrate));
   // }
};

let proofCallback = function(submission) {}

let signCallback = async function(web3, txData)
{
   return (await web3.eth.accounts.signTransaction(txData, account.privateKey)).rawTransaction;
};

let poolStatsCallback = function(responsePool)
{
   console.log(`[JS](app.js) Hashrate detected by the pool:`);// ${KoinosMiner.formatHashRate(responsePool.hashRate)}`);
   console.log(responsePool);
}

function enterPassword()
{
   return readlineSync.questionNewPassword('Enter password for encryption: ', {mask: ''});
}

function encrypt(data, password)
{
   const passwordHash = crypto.createHmac('sha256', password).digest();
   const key = Buffer.from(passwordHash.toString('hex').slice(16), 'hex');
   const iv = Buffer.from(crypto.createHmac('sha256', passwordHash).digest('hex').slice(32), 'hex');
   var cipher = crypto.createCipheriv('aes-192-cbc', key, iv );

   var cipherText = cipher.update(data, 'utf8', 'hex');
   cipherText += cipher.final('hex');

   return cipherText;
}

function decrypt(cipherText, password)
{
   const passwordHash = crypto.createHmac('sha256', password).digest();
   const key = Buffer.from(passwordHash.toString('hex').slice(16), 'hex');
   const iv = Buffer.from(crypto.createHmac('sha256', passwordHash).digest('hex').slice(32), 'hex');
   var decipher = crypto.createDecipheriv('aes-192-cbc', key, iv );

   let decrypted = '';

   decipher.on('readable', () => {
      let chunk;
      while (null !== (chunk = decipher.read())) {
         decrypted += chunk.toString('utf8');
      }
   });

   decipher.write(cipherText, 'hex');
   decipher.end();

   return decrypted;
}

if(program.testMode) {
   readlineSync.question('Are you sure?');
}

if (config.use_pool) {
   console.log('Using mining pool: ' + config.poolEndpoint);
   account = {
      address: "0x0000000000000000000000000000000000000000",
      privateKey: "0x0000000000000000000000000000000000000000",
   };
}
else if(config.useEnv || (!program.import && program.useEnv)) {
   if(!config.private_key) {
      console.log(``);
      console.log(`Can't find privateKey / PRIVATE_KEY within .env file. (--use-env)`);
      process.exit(1);
   }
   account = w3.eth.accounts.privateKeyToAccount(config.private_key);
}
else if (program.import)
{
   console.log(``);
   account = w3.eth.accounts.privateKeyToAccount(
      readlineSync.questionNewPassword('Enter private key: ', {
         mask: '',
         min: 64,
         max: 66,
         charlist: '$<0-9>$<A-F>$<a-f>x',
   }));

   if(readlineSync.keyInYNStrict('Do you want to store your private key encrypted on disk?'))
   {
      var cipherText = encrypt(account.privateKey, enterPassword());

      var filename = readlineSync.question('Where do you want to save the encrypted private key? ');
      fs.writeFileSync(filename, cipherText);
   }
}
else if (program.keyFile)
{
   console.log(``);
   if(program.export && !readlineSync.keyInYNStrict('Outputting your private key unencrypted can be dangerous. Are you sure you want to continue?'))
   {
      process.exit(0);
   }

   var data = fs.readFileSync(program.keyFile, 'utf8');
   account = w3.eth.accounts.privateKeyToAccount(decrypt(data, enterPassword()));

   console.log('Decrypted Ethereum address: ' + account.address);

   if(program.export)
   {
      console.log(account.privateKey);
      process.exit(0);
   }
}
else
{
   console.log(``);
   if(!readlineSync.keyInYNStrict('No private key file specified. Do you want to create a new key?'))
   {
      process.exit(0);
   }

   var seed = readlineSync.question('Enter seed for entropy: ', {hideEchoBack: true, mask: ''});
   account = w3.eth.accounts.create(crypto.createHmac('sha256', seed).digest('hex'));

   var cipherText = encrypt(account.privateKey, enterPassword());

   var filename = readlineSync.question('Where do you want to save the encrypted private key? ');
   fs.writeFileSync(filename, cipherText);
}

console.log(``);
console.log(`[JS](app.js) Mining with the following arguments:`);
console.log(`[JS](app.js) Ethereum Receiver Address: ${config.addr}`);
console.log(`[JS](app.js) Ethereum Miner Address: ${account.address}`);
console.log(`[JS](app.js) Ethereum Endpoint: ${config.endpoint}`);
console.log(`[JS](app.js) Proof every ${getProofPeriodDate()} (${config.proofPeriod})`);
if(wolfModeOnly) {
   console.log(`[JS](app.js) Wolf Mode Engaged! Gracias! (1% Tip)`);
   console.log(`[JS](app.js) Open Orchard Tip Disabled :(`);
} else if(privexModeOnly) {
   console.log(`[JS](app.js) Privex Mode Engaged! THANK YOU SO MUCH! (1% Tip)`);
   console.log(`[JS](app.js) Open Orchard Tip Disabled :(`);
} else {
   console.log(`[JS](app.js) Open Orchard Developer Tip: ${config.tip}%`); ;
   if(program.wolfMode) console.log(`[JS](app.js) Wolf Mode Engaged! Gracias!`);
}
console.log(``);


var miner = new KoinosMiner(
   config.addr,
   tip_addresses,
   config.use_pool ? "0x0000000000000000000000000000000000000000" : account.address,
   config.use_pool ? config.pool_endpoint : null,
   privex_tip_address,
   wolf_tip_address,
   // account.address,
   contract_address,
   config.endpoint,
   config.tip,
   config.proofPeriod,
   config.gasMultiplier,
   config.gasPriceLimit,
   config.gweiLimit,
   config.gweiMinimum,
   program.speed,
   config.privexMode,
   config.wolfMode,
   program.lean,
   program.testMode,
   signCallback,
   hashrateCallback,
   proofCallback,
   errorCallback,
   warningCallback,
   poolStatsCallback);

miner.start();
