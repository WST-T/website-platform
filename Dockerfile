FROM --platform=$BUILDPLATFORM debian:buster
ARG BUILDPLATFORM

RUN echo "Building for ${BUILDPLATFORM}"

ENV NODENV_VERSION="20.11.0" \
    GO_VERSION=1.21.8 \
    HUGO_VERSION="0.112.6" \
    PYTHONUNBUFFERED=1

RUN apt-get update \
  && apt-get install -y curl software-properties-common gnupg \
  && apt-get install -y jq \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A1715D88E1DF1F24 \
  && add-apt-repository ppa:git-core/ppa \
  && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get install -y git \
  && apt-get update \
  && apt-get install -y qemu-user-static \
  && apt-get install -y python3 python3-pip python3-venv

RUN if [ "$BUILDPLATFORM" = "linux/amd64" ]; then \
      SYSTEM_TYPE="linux-amd64"; \
    else \
      SYSTEM_TYPE="linux-arm64"; \
    fi && \
    curl -L https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_${SYSTEM_TYPE}.deb -o hugo.deb && \
    dpkg -i hugo.deb && \
    rm hugo.deb

ENV NODENV_ROOT /root/.nodenv
ENV PATH "$NODENV_ROOT/shims:$NODENV_ROOT/bin:$PATH"
ENV HUGO_SECURITY_EXEC_OSENV ".*"
RUN set -x \
  && curl -fsSL https://github.com/nodenv/nodenv-installer/raw/master/bin/nodenv-installer | bash \
  && nodenv install $NODENV_VERSION \
  && nodenv global $NODENV_VERSION \
  && nodenv rehash \
  && apt-get install -yq --no-install-recommends yarn \
  && curl -OL https://golang.org/dl/go$GO_VERSION.linux-$(echo $BUILDPLATFORM | sed 's/linux\///').tar.gz \
  && tar -C /usr/local -xzf go$GO_VERSION.linux-$(echo $BUILDPLATFORM | sed 's/linux\///').tar.gz \
  && echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/profile \
  && . /etc/profile

WORKDIR /app

COPY . .

RUN pip3 install requests

RUN yarn install --frozen-lockfile

RUN curl -L "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-$(echo $BUILDPLATFORM | sed 's/linux\///').deb" -o hugo.deb \
  && apt install ./hugo.deb \
  && hugo version

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 1313