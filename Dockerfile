FROM meedan/ruby
MAINTAINER Meedan <sysops@meedan.com>

# the Rails stage can be overridden from the caller
ENV RAILS_ENV development

# install dependencies
RUN apt-get update -qq && apt-get install -y libpq-dev imagemagick redis-server inkscape graphviz siege apache2-utils fontconfig libfontconfig ttf-devanagari-fonts ttf-bengali-fonts ttf-gujarati-fonts ttf-telugu-fonts ttf-tamil-fonts ttf-malayalam-fonts --no-install-recommends && rm -rf /var/lib/apt/lists/*

# phantomjs
RUN wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 && \
    tar -vxjf phantomjs-2.1.1-linux-x86_64.tar.bz2 && \
    mv phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/bin/

# install our app
WORKDIR /app
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN echo "gem: --no-rdoc --no-ri" > ~/.gemrc \
    gem install bundler \
    && bundle install --jobs 20 --retry 5
COPY . /app

# startup
COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["tini", "--"]
CMD ["/docker-entrypoint.sh"]
