# Dev container of a WarpEngine project: the platform's CI builder image (the
# same toolchain the pipeline builds with) plus git and a non-root `dev` user
# (uid 1000), so the files a build writes belong to you on Linux too. New Game
# fills {builderImage} from the host's platform description.
FROM {builderImage}

RUN set -e; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git openssh-client sudo ca-certificates lua-check; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache git openssh-client sudo bash shadow; \
    fi; \
    old="$(getent passwd 1000 | cut -d: -f1)"; \
    if [ -n "$old" ] && [ "$old" != dev ]; then \
      usermod -l dev -d /home/dev -m -s /bin/bash "$old"; \
      groupmod -n dev "$(getent group 1000 | cut -d: -f1)" 2>/dev/null || true; \
    elif [ -z "$old" ]; then \
      getent group 1000 >/dev/null || groupadd -g 1000 dev; \
      useradd -m -u 1000 -g 1000 -s /bin/bash dev; \
    fi; \
    mkdir -p /etc/sudoers.d; \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev
