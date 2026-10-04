FROM ruby:4.0.6-slim AS gems

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN BUNDLE_WITHOUT=test BUNDLE_DEPLOYMENT=true BUNDLE_PATH=/usr/local/bundle \
  bundle install --jobs 4 --retry 3

FROM ruby:4.0.6-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y libsqlite3-0 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY . .

ENV PORT=8080 DATABASE_PATH=/data/availability.sqlite3 BUNDLE_WITHOUT=test BUNDLE_PATH=/usr/local/bundle
EXPOSE 8080
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:8080", "config.ru"]
