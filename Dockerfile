FROM node:12-buster as base

RUN npm install -g --force --unsafe-perm yarn

RUN apt-get update -qy && \
    apt-get install -qy git make build-essential libssl-dev cmake && \
    apt-get clean -qy

WORKDIR /app

ENV NODE_ENV=production

COPY . .

RUN yarn install
# RUN npm run postinstall

FROM node:12-buster-slim as release
WORKDIR /app
RUN apt-get update && \
    apt-get -y install libgomp1 && \
    apt-get clean -qy

COPY --from=base /app/package.json /app/package.json
COPY --from=base /app/app.js /app/app.js
COPY --from=base /app/index.js /app/index.js
COPY --from=base /app/abi.js /app/abi.js
COPY --from=base /app/looper.js /app/looper.js
COPY --from=base /app/MiningPool.js /app/MiningPool.js
COPY --from=base /app/retry.js /app/retry.js
COPY --from=base /app/node_modules /app/node_modules 
COPY --from=base /app/bin /app/bin

RUN chown -R node:node /app
USER node

ENTRYPOINT [ "npm", "start", "--" ]
