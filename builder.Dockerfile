# CI toolbox image for the TIC-80 pipeline's lint / minify / docs steps:
# Lua 5.4 with luacheck and ldoc preinstalled, so the pipeline does not
# run luarocks (and a C compiler install) on every run.
#
# The export step keeps using the separate TIC-80 Pro image
# (git.teletype.hu/internal/tic80pro, built from the tic80pro-dockerfile
# repo) — this image only covers the Lua tooling around it.
#
# Build & push (the CI runner is linux/amd64):
#   docker build --platform linux/amd64 -f builder.Dockerfile \
#     -t git.teletype.hu/internal/tic80-luatools:latest .
#   docker push git.teletype.hu/internal/tic80-luatools:latest

FROM alpine:3.22

RUN apk add --no-cache make zip curl git lua5.4 lua5.4-dev luarocks gcc musl-dev \
 && ln -sf /usr/bin/lua5.4 /usr/bin/lua \
 && ln -sf /usr/bin/luarocks-5.4 /usr/bin/luarocks \
 && luarocks install luacheck \
 && luarocks install ldoc

WORKDIR /workspace

CMD ["/bin/sh"]
