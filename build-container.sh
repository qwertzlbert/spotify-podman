#!/usr/bin/env bash

GETOPT=/usr/bin/getopt

PROG=${0##*/}
 
function usage ()
{
cat <<EOF
usage: $PROG [options] 
$PROG will build a podman container containing spotify. Audio is passed through using 
a shared pulseaudio socket. Video is shared by sharing the X11 socket.
Please see https://gitlab.com/qwertzlbert/spotify-podman for more details
 
  Options:
    -h,--help          print this help message.
    -n,--name [param]  define the image name to use (optional) (default: "spotify_pod")
    -u,--uid [param]   define the uid to use (optional) (default: 1500)
EOF
}

# process and assign command line arguments
_temp=$($GETOPT -o hn::u:: --long help,name::,uid:: -n $PROG -- "$@")
if [ $? != 0 ] ; then echo "bad command line options" >&2 ; exit 1 ; fi
eval set -- "$_temp"

_OPT_NAME="spotify_pod"
_OPT_UID=1500
 
while true ; do
        case "$1" in
        -h|--help)
                        usage; exit 0 ;;

        -n|--name)
                        if [[ -z "$2" ]]; then
                                _OPT_NAME="spotify_pod"
                        else
                                _OPT_NAME=$2
                        fi
                        shift 2; continue ;;
        -u|--uid)
                        if [[ -z "$2" ]]; then
                                _OPT_UID=1500
                        else
                                _OPT_UID=$2
                        fi
                        shift 2; continue ;;
        *)
            break
            ;;
        esac
done

crt=$(buildah from ubuntu)

buildah run $crt apt-get update

# ad flag to allow silent install as it is asking for location
buildah run $crt env DEBIAN_FRONTEND=noninteractive apt-get install -y \
					curl \
					gnupg \
					sudo \
					pulseaudio-utils \
					x11-xserver-utils \
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
buildah run $crt useradd --create-home -u $_OPT_UID -d /home/spotify_user spotify_user
buildah run $crt gpasswd -a spotify_user audio 
buildah run $crt chown -R spotify_user:spotify_user /home/spotify_user

buildah config --entrypoint "cp -a /tmp/pulse-cookie /tmp/pulse-spotify-cookie && \
							chown spotify_user:spotify_user /tmp/pulse-spotify-cookie && \
							xhost local:root && \
							sudo -u spotify_user \
							PULSE_COOKIE=/tmp/pulse-spotify-cookie \
							PULSE_SERVER=unix:/tmp/pulse-socket /usr/bin/spotify" \
							$crt

buildah commit $crt $_OPT_NAME
