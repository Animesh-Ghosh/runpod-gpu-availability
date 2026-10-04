FROM ruby:4.0.6-slim AS build

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set without test && bundle install

FROM ruby:4.0.6-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y libsqlite3-0 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

ENV PORT=8080 DATABASE_PATH=/data/availability.sqlite3
EXPOSE 8080
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:8080", "config.ru"]
