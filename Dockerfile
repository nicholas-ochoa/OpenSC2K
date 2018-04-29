FROM mhart/alpine-node:base

ENV PATH /root/.yarn/bin:$PATH

RUN apk update \
  && apk add curl bash binutils tar git \
  && rm -rf /var/cache/apk/* \
  && /bin/bash \
  && touch ~/.bashrc \
  && curl -o- -L https://yarnpkg.com/install.sh | bash \
  && git clone https://github.com/rage8885/OpenSC2K \
  && cd OpenSC2K \
  && yarn --ignore-engines install \
  && echo 'cd /OpenSC2K && yarn run start' >/run.sh \
  && chmod +x /run.sh \
  && apk del git curl tar binutils
  
EXPOSE 3000

ENTRYPOINT [ "/bin/bash" ]

CMD [ "/run.sh" ]
