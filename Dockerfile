FROM elixir:1.4.2

####### PostgreSQL #######
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    postgresql-client-9.4 \
    build-essential \
    erlang-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
####### PostgreSQL #######

####### Node #######
RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 7.7.4

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

CMD [ "node" ]

RUN npm install -g yarn
####### Node #######

# Initialize
RUN mkdir /app
WORKDIR /app

# Things don't change that oftern. For instance, dependencies
# Install Elixir Deps
ADD mix.* ./
RUN MIX_ENV=prod mix local.rebar
RUN MIX_ENV=prod mix local.hex --force
RUN MIX_ENV=prod mix deps.get

# Install Node Deps
RUN mkdir -p ./apps／phoenix_china_web/assets
ADD ./apps／phoenix_china_web/assets ./apps／phoenix_china_web/assets
WORKDIR ./apps／phoenix_china_web/assets
# Install Node Deps
RUN yarn install


WORKDIR /app
ADD . .
# Compile Node App
WORKDIR ./apps/phoenix_china_web/assets
RUN yarn run deploy
WORKDIR ../
# Phoenix digest
RUN MIX_ENV=prod mix phx.digest
WORKDIR /app
# Compile Elixir App
RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix ecto.create && mix ecto.migrate
RUN MIX_ENV=prod mix run apps/phoenix_china/priv/repo/seeds.exs
# Exposes port
EXPOSE 4000

# The command to run when this image starts up
CMD MIX_ENV=prod mix phx.server