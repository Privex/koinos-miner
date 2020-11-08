const { sleep } = require("./looper");

async function retry(msg, fn, context = "[JS]") {
    let tries = 0;
    let sleepTime = 200;
    let MAX_SLEEP_TIME = 60000;
    let errorMessage = "";

    while (true) {
        try {
            if( tries > 0 ) {
               console.log(`${context} Attempting to ${msg} (${tries} failed attempts)`);
            }
            return await fn(tries, errorMessage);
        }
        catch (e) {
            console.log(`${context} Error with ${msg}`);
            if(e.response && e.response.data) {
              console.log(e.response.data);
              if(typeof e.response.data === "object")
                errorMessage = JSON.stringify(e.response.data);
              else
                errorMessage = e.response.data;
            } else {
              console.log(e.message);
              errorMessage = e.message;
            }
            ++tries;
            await sleep( (0.75 + 0.25*Math.random()) * sleepTime );
            sleepTime = Math.min( sleepTime*2, MAX_SLEEP_TIME );
        }
    }
}

module.exports = retry;
