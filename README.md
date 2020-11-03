# Overview

This repository contains a bash script leveraging [buildah](https://buildah.io/) to 
create a podman container running Spotify. 

The setup is designed to run with unprivileged podman containers.

This is only tested for X11 environments and might not run with Wayland!

Please look inside `run-container.sh` if you want to see how this can be run

# How it works

Spotify will run with an individual non root user (`spotify_user`) mapped to uid 1500 inside the container. Persistant storage needs to be mapped to 
`/home/spotify_user/.cache/spotify` and `/home/spotify_user/.cache/spotify`

To make the storage available/writeable to the `spotify_user` inside the container, the storage ownership needs to be 
changed. To do this run: 

```podman unshare chown -R 1500:1500 /path/to/persitant/storage```

To share audio with the container a special setup is needed.
This setup leverages pulseaudios shared unix socket functionality to share your local audio device with 
the container. 

It is  required to change the host pulseaudio configuration and add the following line to
either `/etc/pulse/default.pa` or `~/.config/pulse/default.pa` and restart your pulseaudio daemon: 

`load-module module-native-protocol-unix socket=pulse-socket auth-cookie=pulse-cookie`

This will allow to write to the pulse audio socket with a different uid than the host user, if we have access to the cookie.
This is required as with 
non privileged containers the executing host user uid is mapped to root inside the container. This disables the direct sharing 
of the pulseaudio socket via

```
					-v $XDG_RUNTIME_DIR/pulse:$XDG_RUNTIME_DIR/pulse:ro \
					-v $HOME/.config/pulse/cookie:/root/.config/pulse/cookie:ro \
```

here only the root user inside the container can access the socket, as it shares it's uid with the host user running 
the container, and as we don't and should'nt rewrite the privileges/owner of the socket allow access with other users inside of the container.
We need to explicitly enable the pulseaudio unix socket sharing method on the host.

This all needs to be done so the application is not run as root inside of the container, as it buries the risk of an malicious application escaping the container 
accessing your user data. 

Also passing through the sound device via `--device /dev/snd:/dev/snd` and using ALSA is not an option with non privileged containers, as 
the host root uid is not in the range of the guest container uids an therefore the access to the device is blocked as it belongs to 
an unknown `nobody` user. 

GUI access is shared by sharing the x11 socket with the container, and afterwards running `xhost local:root` inside the container.
This allows the `spotify_user` (and also every other user inside the container. So please don't run this command on your host, as 
it is not safe!) to access the x11 server. 


# Files

`build-container.sh`: Builds and commits Podman container via buildah

`pulse-client.conf`: Pulseaudio client configuration to use host audio device as audio source

`run-container.sh`: Example script to run previously build ts3 container as `ts3pod`. Persistent files will be shared on
`$HOME/.spotify` on host. 

 
## Comment

Thanks to @fadams for giving examples sharing audio and display ressources with containers. Especially:
- https://github.com/TheBiggerGuy/docker-pulseaudio-example/issues/1
- https://github.com/fadams/docker-gui

Also thanks @jessfraz for the int blog post:
- https://blog.jessfraz.com/post/docker-containers-on-the-desktop/
	
I would appreciate any comments to this approach or alternative ideas

## Problems

For some reason spotify tends to crash with out of memory error:

```
[1103/173130.577407:FATAL:memory.cc(40)] Out of memory. size=26214
```

I don't know where this is comming from and I'm still searching for the reason
