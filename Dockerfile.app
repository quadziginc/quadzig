FROM public.ecr.aws/f1h7x2r4/ruby-with-rails:v1

WORKDIR /app
COPY . .
ENV BUNDLER_WITHOUT="development test"
ENV ASSET_PRECOMPILE=1

RUN apk update
RUN apk add curl yarn postgresql-dev build-base tzdata git
RUN gem install bundler
RUN gem install pg -v '0.18.4' -- --with-cflags="-Wno-error=implicit-function-declaration"

RUN yarn install
RUN bundle install -V
RUN rails assets:clean
RUN rails assets:precompile
RUN rails webpacker:compile

CMD ["./start.sh"]
