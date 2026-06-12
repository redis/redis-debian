This repository contains the debian/ubuntu package configuration and automation for building Redis source and binary packages, then publishing them to the official packages.redis.io repositories for Ubuntu and Debian.

The Debian package is derived from work done by [Chris Lea](https://github.com/chrislea).

## Redis Open Source - Install using Debian Advanced Package Tool (APT)

Run the following commands:
```sh
sudo apt-get update
sudo apt-get install lsb-release curl gpg
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt-get update
sudo apt-get install redis
```

> [!TIP]
> The most recent version of Redis Open Source will be installed, along with
> `redis-tools`.
>
> To install an earlier release series, first add the repository as shown above,
> but do not install `redis` yet. Create `/etc/apt/preferences.d/redis` to pin
> the mainline version you want to install. For example, to install the latest
> Redis Open Source 7.4 package:
> ```text
> Package: redis redis-server redis-sentinel redis-tools
> Pin: version 6:7.4.*
> Pin-Priority: 1001
> ```
>
> Then install Redis:
> ```sh
> sudo apt-get install redis
> ```
>
> With this preference file, APT installs the latest package matching the pinned
> `7.4` release series.
>
> You can list the available versions with:
> ```sh
> apt policy redis
> ```
>
> To install an exact package version instead, note the full version string
> from the command above and explicitly install all Redis packages using that
> same version. For example, on Ubuntu 22.04 (Jammy), to install Redis Open
> Source 7.4.9:
> ```sh
> sudo apt-get install \
>   redis=6:7.4.9-1rl1~jammy1 \
>   redis-server=6:7.4.9-1rl1~jammy1 \
>   redis-sentinel=6:7.4.9-1rl1~jammy1 \
>   redis-tools=6:7.4.9-1rl1~jammy1
> ```

## Starting Redis

To start Redis using systemd:

```sh
sudo systemctl start redis-server
```

This starts `redis-server` with the configuration file at `/etc/redis/redis.conf`.

> [!TIP]
> To ensure Redis starts automatically at boot time, enable the service:
>
> ```sh
> sudo systemctl enable redis-server
> ```

### Starting Redis manually

In environments where systemd is not available, such as containers, you can start `redis-server` manually:

```sh
redis-server /etc/redis/redis.conf --daemonize yes
```

When started this way, `redis-server` runs in the background, uses `/etc/redis/redis.conf`, writes its PID to `/run/redis.pid`, and redirects its output to `/var/log/redis/redis-server.log`.


## Supported Operating Systems

Redis officially tests the latest version of this distribution against the following OSes:

- Ubuntu 26.04 (Resolute Raccoon)
- Ubuntu 24.04 (Noble Numbat)
- Ubuntu 22.04 (Jammy Jellyfish)
- Debian 13 (Trixie)
- Debian 12 (Bookworm)
