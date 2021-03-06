FROM ruby:2.6.5-alpine

RUN apk add --no-cache --update \
    nano \
    curl-dev \
    ca-certificates \
    linux-headers \
    build-base \
    libxml2-dev \
    libxslt-dev \
    tzdata \
    postgresql-dev \
    nodejs \
    yarn

ARG master_key
ENV MASTER_KEY=$master_key

ARG rails_env
ENV RAILS_ENV=$rails_env

ENV RAILS_ROOT /app
ENV BUNDLE_DIR /bundle

RUN mkdir -p $RAILS_ROOT
WORKDIR $RAILS_ROOT
COPY . $RAILS_ROOT

RUN yarn install
RUN gem install bundler:2.0.1
RUN bundle install --path $BUNDLE_DIR --jobs 20 --retry 5 --without development test
RUN bundle exec rake assets:precompile