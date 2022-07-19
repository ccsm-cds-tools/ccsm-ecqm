import { readdirSync, readFileSync, writeFile, writeFileSync } from 'fs';
import { join, sep } from 'path';
import { request } from 'https';

// First ensure an API key is provided
let apiKey;
if (process.argv.length === 3) {
  apiKey = process.argv[2];
} else if (process.argv.length === 4) {
  console.error('UMLS username and password is no longer supported. Please pass in a UMLS API key instead.');
  process.exit(1);
} else {
  console.error('The UMLS API key must be passed in as an argument');
  process.exit(1);
}

let url = 'https://cts.nlm.nih.gov';

let options = {
  method: 'GET',
  auth: 'apikey:' + apiKey
};

const inputPath = join('input','vocabulary','valueset','external');
let files = readdirSync(inputPath);

const timer = ms => new Promise(res => setTimeout(res, ms));

// for (const file of files) {
//   if (/^(valueset-)(.+)(\.json)$/.test(file)) {
//     console.log(file);
//     let json = JSON.parse(readFileSync(inputPath + sep + file));
//     json.text = {};
//     json.expansion = {};
//     writeFileSync(inputPath + sep + file, JSON.stringify(json, null, 2));
//   }
// }

async function load() {
  for (const file of files) {
    await timer(1000);
    if (/^(valueset-)(.+)(\.json)$/.test(file)) {
      const oid = file.match(/^(valueset-)(.+)(\.json)$/)[2];
      console.log(oid);
      options.path = '/fhir/res/ValueSet/' + oid + '/$expand';
      let req = request(url, options, (res) => {
        let json = '';

        res.on('data', (chunk) => {
            json += chunk;
        });

        res.on('end', () =>{
          if (res.statusCode === 200) {
            try {
              console.log('Status:', res.statusCode);
              writeFile(inputPath + sep + file, json, (err) => {
                if (err) throw err;
                console.log('File written: ', inputPath + sep + file);
              });
            } catch (e) {
              console.log(e);
            }
          } else {
            console.log('Status:', res.statusCode);
          }
        });
      });

      req.on('error', (e) => {
        console.log(e);
      });

      req.end();
    }
  }
}

load();