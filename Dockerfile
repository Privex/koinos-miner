FROM node:12-buster as base

RUN npm install -g --force --unsafe-perm yarn

RUN apt-get update -qy && \
    apt-get install -qy git make build-essential libssl-dev cmake && \
    apt-get clean -qy

WORKDIR /app


COPY package.json package-lock.json yarn.lock /app/
COPY CMakeLists.txt PreLoad.cmake /app/
COPY miner /app/miner

ENV NODE_ENV=production
RUN yarn install
# RUN npm run postinstall

FROM node:12-buster-slim as release
WORKDIR /app
RUN apt-get update && \
    apt-get -y install libgomp1 && \
    apt-get clean -qy

COPY --from=base /app/node_modules /app/node_modules 
COPY --from=base /app/package.json /app/yarn.lock /app/
COPY --from=base /app/bin /app/bin
COPY README.md LICENSE.md example.env /app/
COPY app.js index.js abi.js looper.js MiningPool.js retry.js /app/

RUN chown -R node:node /app
USER node

ENV NODE_ENV=production

LABEL maintainer="Privex Inc. - https://github.com/Privex - https://www.privex.io"
LABEL repository="https://github.com/Privex/koinos-miner/tree/koinclub"
LABEL description="This is a Docker container designed to run Privex's fork of the KoinClub Koinos Pool Miner. \
Official Repo: https://github.com/Privex/koinos-miner/tree/koinclub \
Privex website: https://www.privex.io"

ENTRYPOINT [ "npm", "start", "--" ]
