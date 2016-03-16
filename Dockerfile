FROM alpine:3.3

ENV GOSU_VERSION="1.7" \
	GOSU_DOWNLOAD_URL="https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64" \
	GOSU_DOWNLOAD_SIG="https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64.asc" \
	GOSU_DOWNLOAD_KEY="0x036A9C25BF357DD4" \
	NODE_ENV=production

ADD https://github.com/Yelp/dumb-init/releases/download/v1.0.0/dumb-init_1.0.0_amd64 /usr/local/bin/dumb-init
# Download and install gosu
#   https://github.com/tianon/gosu/releases
RUN buildDeps='curl gnupg' HOME='/root' \
	&& set -x \
	&& apk add --update $buildDeps \
	&& gpg-agent --daemon \
	&& gpg --keyserver pgp.mit.edu --recv-keys $GOSU_DOWNLOAD_KEY \
	&& echo "trusted-key $GOSU_DOWNLOAD_KEY" >> /root/.gnupg/gpg.conf \
	&& curl -sSL "$GOSU_DOWNLOAD_URL" > gosu-amd64 \
	&& curl -sSL "$GOSU_DOWNLOAD_SIG" > gosu-amd64.asc \
	&& gpg --verify gosu-amd64.asc \
	&& rm -f gosu-amd64.asc \
	&& mv gosu-amd64 /usr/bin/gosu \
	&& chmod +x /usr/bin/gosu \
	&& apk del --purge $buildDeps \
	&& rm -rf /root/.gnupg \
	&& rm -rf /var/cache/apk/* \

  # give dumb-initrun permission
  && chmod +x /usr/local/bin/dumb-init \

  # install node
  && apk add --no-cache --update 'nodejs>4.3.0' \

  # add app group and user
  && addgroup -S app \
  && adduser -S -G app app \
  && mkdir /home/app/src \
  && chown -R app:app /home/app/src \
	;

WORKDIR /home/app/src

ONBUILD ADD ./build/package.json package.json
ONBUILD RUN npm install --production
ONBUILD ADD ./build .

CMD ["dumb-init", "gosu", "app", "npm", "start"]

EXPOSE 3000
