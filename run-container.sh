#!/usr/bin/env bash

mkdir -p $HOME/.spotify/cache
mkdir -p $HOME/.spotify/config
podman unshare chown -R 1500:1500 $HOME/.spotify
podman run -it --rm -e DISPLAY=unix$DISPLAY \
					-v /tmp/.X11-unix:/tmp/.X11-unix \
					-v $XDG_RUNTIME_DIR/pulse/pulse-socket:/tmp/pulse-socket \
					-v $HOME/.config/pulse/pulse-cookie:/tmp/pulse-cookie:ro \
					-v $HOME/.spotify/cache:/home/spotify_user/.cache/spotify:rw,shared \
					-v $HOME/.spotify/config:/home/spotify_user/.config/spotify:rw,shared \
					--name spotify-container spotify_pod bash
