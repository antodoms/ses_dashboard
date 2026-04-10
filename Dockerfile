FROM ruby:3.4

WORKDIR /usr/src/app
COPY . /usr/src/app

RUN bundle install

CMD ["bundle", "exec", "rspec"]
