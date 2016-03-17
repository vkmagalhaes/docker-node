FROM alpine:3.3

ENV LANG="C.UTF-8" \
	GOSU_VERSION="1.7" \
	GOSU_DOWNLOAD_URL="https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64" \
	GOSU_DOWNLOAD_SIG="https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64.asc" \
	GOSU_DOWNLOAD_KEY="0x036A9C25BF357DD4" \
	VERSION="v4.4.0" \
	NPM_VERSION="2" \
	NODE_ENV="production" \
	CONFIG_FLAGS="--fully-static" \
	DEL_PKGS="libgcc libstdc++" \
	RM_DIRS="/usr/include"

ADD https://github.com/Yelp/dumb-init/releases/download/v1.0.0/dumb-init_1.0.0_amd64 /usr/local/bin/dumb-init

# Here we install GNU libc (aka glibc) and set C.UTF-8 locale as default.
RUN ALPINE_GLIBC_BASE_URL="https://github.com/andyshinn/alpine-pkg-glibc/releases/download" && \
  ALPINE_GLIBC_PACKAGE_VERSION="2.23-r1" && \
  ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
  ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
  ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
  apk add --no-cache --virtual=build-dependencies wget ca-certificates && \
  wget "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
				"$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
				"$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
  apk add --no-cache --allow-untrusted \
      "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
      "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
      "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
  /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true && \
  echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
  apk del glibc-i18n && \
  apk del build-dependencies && \
  rm "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
     "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
     "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \

	# Download and install gosu
	#   https://github.com/tianon/gosu/releases
	buildDeps='curl gnupg' HOME='/root' && \
	set -x && \
	apk add --update $buildDeps && \
	gpg-agent --daemon && \
	gpg --keyserver pgp.mit.edu --recv-keys $GOSU_DOWNLOAD_KEY && \
	echo "trusted-key $GOSU_DOWNLOAD_KEY" >> /root/.gnupg/gpg.conf && \
	curl -sSL "$GOSU_DOWNLOAD_URL" > gosu-amd64 && \
	curl -sSL "$GOSU_DOWNLOAD_SIG" > gosu-amd64.asc && \
	gpg --verify gosu-amd64.asc && \
	rm -f gosu-amd64.asc && \
	mv gosu-amd64 /usr/bin/gosu && \
	chmod +x /usr/bin/gosu && \
	apk del --purge $buildDeps && \
	rm -rf /root/.gnupg && \
	rm -rf /var/cache/apk/* && \

  # give dumb-init run permission
  chmod +x /usr/local/bin/dumb-init && \

  # install node
	apk add --no-cache curl make gcc g++ binutils-gold python linux-headers paxctl libgcc libstdc++ gnupg && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys 9554F04D7259F04124DE6B476D5A82AC7E37093B && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys 94AE36675C464D64BAFA68DD7434390BDBE9B9C5 && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys 0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys FD3A5288F042B6850C66B31F09FE44734EB7990E && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys 71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys DD8F2338BAE7501E3DD5AC78C273792F7D83545D && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 && \
  gpg --keyserver pool.sks-keyservers.net --recv-keys B9AE9905FFD7803F25714661B63B535A4C206CA9 && \
  curl -o node-${VERSION}.tar.gz -sSL https://nodejs.org/dist/${VERSION}/node-${VERSION}.tar.gz && \
  curl -o SHASUMS256.txt.asc -sSL https://nodejs.org/dist/${VERSION}/SHASUMS256.txt.asc && \
  gpg --verify SHASUMS256.txt.asc && \
  grep node-${VERSION}.tar.gz SHASUMS256.txt.asc | sha256sum -c - && \
  tar -zxf node-${VERSION}.tar.gz && \
  cd /node-${VERSION} && \
  ./configure --prefix=/usr ${CONFIG_FLAGS} && \
  make -j$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
  make install && \
  paxctl -cm /usr/bin/node && \
  cd / && \
  if [ -x /usr/bin/npm ]; then \
    npm install -g npm@${NPM_VERSION} && \
    find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf; \
  fi && \
  apk del curl make gcc g++ binutils-gold python linux-headers paxctl gnupg ${DEL_PKGS} && \
  rm -rf /etc/ssl /node-${VERSION}.tar.gz /SHASUMS256.txt.asc /node-${VERSION} ${RM_DIRS} \
    /usr/share/man /tmp/* /var/cache/apk/* /root/.npm /root/.node-gyp /root/.gnupg \
    /usr/lib/node_modules/npm/man /usr/lib/node_modules/npm/doc /usr/lib/node_modules/npm/html && \

  # add app group and user
  addgroup -S app && \
  adduser -S -G app app && \
  mkdir /home/app/src && \
  chown -R app:app /home/app/src \
	;

WORKDIR /home/app/src

ONBUILD ADD ./build/package.json package.json
ONBUILD RUN npm install --production
ONBUILD ADD ./build .

CMD ["dumb-init", "gosu", "app", "npm", "start"]

EXPOSE 3000
