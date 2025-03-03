FROM ruby:2.7
MAINTAINER Carlos Nunez <dev@carlosnunez.me>
ARG ENVIRONMENT

COPY Gemfile /
RUN bundle install --gemfile /Gemfile

WORKDIR /app
ENTRYPOINT ["ruby", "-e", "puts 'Welcome to slack-api'"]
