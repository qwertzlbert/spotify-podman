#!/usr/bin/env bash

crt=$(buildah from ubuntu)

buildah run $crt apt-get update

# ad flag to allow silent install as it is asking for location
buildah run $crt env DEBIAN_FRONTEND=noninteractive apt-get install -y \
					curl \
					gnupg \
					sudo \
					pulseaudio \
					pulseaudio-utils \
					ca-certificates \
					--no-install-recommends \
					&& rm -rf /var/lib/apt/lists/*
buildah copy $crt pulse-client.conf /etc/pulse/client.conf

# setup spotify + spotify user
buildah run $crt bash -c 'curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | apt-key add - '
buildah run $crt bash -c 'echo "deb http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list'
buildah run $crt apt-get update 
buildah run $crt env DEBIAN_FRONTEND=noninteractive apt-get install -y spotify-client

# setup spotify user and pulseaudio
buildah run $crt useradd --create-home -u 1500 -d /home/spotify_user spotify_user
buildah run $crt gpasswd -a spotify_user audio 
buildah run $crt chown -R spotify_user:spotify_user /home/spotify_user

buildah config --entrypoint "cp -a /tmp/pulse-cookie /tmp/pulse-spotify-cookie && \
							chown spotify_user:spotify_user /tmp/pulse-spotify-cookie && \
							xhost local:root && \
							sudo -u spotify_user \
							PULSE_COOKIE=/tmp/pulse-spotify-cookie \
							PULSE_SERVER=unix:/tmp/pulse-socket /usr/bin/spotify" \
							$crt

buildah commit $crt spotify_pod
