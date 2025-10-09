This repository holds the `debian/` package configuration and handles automation tasks for creating source packages and pushing them to `ppa:redislabs/redis`.

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
> To install an earlier version, say `7.4.2`, run the following command:
> ```sh
> sudo apt-get install redis=6:7.4.2-1rl1~jammy1
> ```
>
> You could view the available versions by running `apt policy redis`.

## Starting Redis

To start the `redis-server`:
```sh
redis-server /etc/redis/redis.conf &
```

Note that `redis-server` output is redirected to `/var/log/redis/redis-server.log`.

> [!TIP]
> Redis will not start automatically, nor will it start at boot time. To do this, run the following commands.
> ```sh
> sudo systemctl enable redis-server
> sudo systemctl start redis-server
> ```

This will start `redis-server` with `/etc/redis/redis.conf`.

## Supported Operating Systems

Redis officially tests the latest version of this distribution against the following OSes:

- Ubuntu 24.04 (Noble Numbat)
- Ubuntu 22.04 (Jammy Jellyfish)
- Debian 12 (Bookworm)
- Debian 11 (Bullseye)
