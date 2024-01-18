FROM ruby:3.2-alpine

WORKDIR /app
COPY . .
ENV BUNDLER_WITHOUT="development test"
ENV ASSET_PRECOMPILE=1

RUN apk update
RUN apk add --no-cache build-base

RUN apk add nodejs npm
RUN apk add --update nodejs=20.11.0-r0

RUN apk add curl yarn postgresql-dev build-base tzdata git

RUN gem install bundler
RUN gem install pg -v '1.5.4' -- --with-cflags="-Wno-error=implicit-function-declaration"

RUN yarn install

RUN bundle install -V
RUN rails webpacker:install
RUN rails assets:clean
RUN rails assets:precompile
RUN rails webpacker:compile

CMD ["./start.sh"]
