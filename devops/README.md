# opensim-creator-devops

> High-level documentation and scripts for deploying and maintaining the various
> parts of the OpenSimCreator project


# Top-Level Architectural Explanation

OpenSim Creator uses one redirection domain and three distinct domain names to
organize its content:

- `opensimcreator.com`: apex domain that 301 redirects to `www.opensimcreator.com`
- `www.opensimcreator.com`: what you see in this repo: top-level landing page
  content. Top-level organizational notes, roadmap, etc.
- `docs.opensimcreator.com`: hosts builds of documentation (e.g. from
  `opensim-creator-docs`)
- `files.opensimcreator.com`: storage location for larger assets (think: images,
   meshes, videos) that may be shared between various tendrils of the opensimcreator
   project (e.g. `docs.opensimcreator.com` may want to link to a video hosted
   here but, equally, the same video may be used in a blog post by
   `www.opensimcreator.com`)

The reason for this organizational split is so that there's:

- `www.opensimcreator.com` (this repo) is suitable for published, usually
  un-versioned (from a user PoV), and quite dynamic, top-level project news,
  marketing, roadmaps, download links etc.

- `docs.opensimcreator.com` is suitable for potentially-multi-versioned
  documentation releases that may have new releases over time, and may have some
  occasional unversioned updates (links changed, etc.), but the general structure
  will be quite static. In the future, this system may also need to support
  dynamic documentation content (e.g. visualizers, notebooks)

- `files.opensimcreator.com` is suitable for storing large, mostly immutable,
  files that can't practically be saved into a git repository, because `git`
  hosts typically have size limits and  `git`'s default behavior is to clone
  the entire repository. This system needs to focus on being an extremely simple
  key-value blob store (e.g. its design should make it possible to host on an
  S3 bucket without breaking links). In the future, it may need to also support
  recording download statistics and integration with `git lfs`


# Concrete Technical Explanation

This section contains a concrete, manual, explanation of how the various services
for `opensimcreator.com` are deployed:

- A bare Debian VPS with daily snapshot backups was hired from Hetzner
- Namecheap, the domain name provider, was used to update the subdomains to
  contain A and AAAA records that point to the server's static IP address(es). The
  apex domain (`opensimcreator.com`) uses the same A and AAAA records as the `www`
  subdomain (redirection is performed by the server).
- `nginx` and `certbot` were installed onto the server
- `certbot certonly` was used to acquire TLS certificates for each subdomain
- A systemd timer (modern-day cronjob) was setup to run `certbox -q renew` at
  regular intervals, to ensure the certificate doesn't expire. **Note**: debian
  installs this unit for you, but you _must_ disable `nginx` during the renew
  procedure (see `ExecStartPre` and `ExecStartPost`)

```text
root@opensimcreator-server:~# cat /lib/systemd/system/certbot.timer
[Unit]
Description=Run certbot twice daily

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=43200
Persistent=true

[Install]
WantedBy=timers.target
root@opensimcreator-server:~# cat /lib/systemd/system/certbot.service
[Unit]
Description=Certbot
Documentation=file:///usr/share/doc/python-certbot-doc/html/index.html
Documentation=https://letsencrypt.readthedocs.io/en/latest/
[Service]
Type=oneshot
ExecStartPre=systemctl stop nginx
ExecStart=/usr/bin/certbot -q renew
ExecStartPost=systemctl start nginx
PrivateTmp=true
```

- The timer was enabled with `systemctl enable certbot.timer`
- `nginx` was configured to serve static assets for each subdomain, e.g.:

```text
root@opensimcreator-server:~# cat /etc/nginx/sites-available/*.opensimcreator.com
server {
        server_name docs.opensimcreator.com;
        listen 80;
        listen [::]:80;
        return 301 https://$host$request_uri;
}

server {
        server_name docs.opensimcreator.com;

        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        ssl_certificate /etc/letsencrypt/live/docs.opensimcreator.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/docs.opensimcreator.com/privkey.pem;

        root /var/www/docs.opensimcreator.com;
        index index.html;

        location = / {
                return 302 https://$host/manual/en/latest;
        }
}
server {
        server_name files.opensimcreator.com;
        listen 80;
        listen [::]:80;
        return 301 https://$host$request_uri;
}

server {
        server_name files.opensimcreator.com;

        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        ssl_certificate /etc/letsencrypt/live/files.opensimcreator.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/files.opensimcreator.com/privkey.pem;

        root /var/www/files.opensimcreator.com;
        index index.html;
        autoindex on;
}
server {
        server_name opensimcreator.com;
        listen 80;
        listen [::]:80;
        rewrite ^/(.*)$ https://www.opensimcreator.com/$1 permanent;
}

server {
        server_name opensimcreator.com;
        listen 443 ssl;
        listen [::]:443 ssl;
        ssl_certificate /etc/letsencrypt/live/opensimcreator.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/opensimcreator.com/privkey.pem;
        rewrite ^/(.*)$ https://www.opensimcreator.com/$1 permanent;
}
server {
        server_name www.opensimcreator.com;
        listen 80;
        listen [::]:80;
        return 301 https://$host$request_uri;
}

server {
        server_name www.opensimcreator.com;

        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        ssl_certificate /etc/letsencrypt/live/www.opensimcreator.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/www.opensimcreator.com/privkey.pem;

        root /var/www/opensimcreator.com;
        index index.html;
}
```

- A publisher account was added for each service: `opensimcreator-publisher`,
  `opensimcreator-docs-publisher`, `opensimcreator-files-publisher`, so that
  (e.g.) CI can publish to `docs.opensimcreator.com`, but can't mess around with
  `opensimcreator.com` or `files.opensimcreator.com`:

```bash
adduser opensimcreator-publisher
adduser opensimcreator-docs-publisher
adduser opensimcreator-files-publisher
```

- The static data directories were created and assigned to the relevant user so
  that they're able to write to those directories:

```bash
mkdir -p /var/www/opensimcreator.com
chmod -R 755 /var/www/opensimcreator.com
chown -R opensimcreator-publisher:www-data /var/www/opensimcreator.com

mkdir -p /var/www/docs.opensimcreator.com
chmod -R 755 /var/www/docs.opensimcreator.com
chown -R opensimcreator-docs-publisher:www-data /var/www/docs.opensimcreator.com

mkdir -p /var/www/files.opensimcreator.com
chmod -R 755 /var/www/files.opensimcreator.com
chown -R opensimcreator-files-publisher:www-data /var/www/files.opensimcreator.com
```

- The `docs` datastructure was created to have a similar path structure to Blender,
  to try and handle some forward-compatibility (languages, versions), but only initially
  supply the latest user-facing documentation:

```bash
su opensimcreator-docs-publisher
mkdir -p /var/www/docs.opensimcreator.com/manual/en/
```

- **Note**: the `docs.opensimcreator.com` virtual server has been configured
  (above) to automatically redirect to `docs.opensimcreator.com/manual/en/latest`
  until multi-version documentation is coded

- The server was then ready for uploads via very standard tooling, such as
  `rsync`: `rsync -avz files/* opensimcreator-files-publisher@files.opensimcreator.com:/var/www/files/`



Once the assets are built, they're typically uploaded to a standard static
web host (e.g. `nginx`, `apache`) using something like `rsync`. Here's an
example of how they might be uploaded to `docs.opensimcreator.com`:

```bash
# sync them to the server
rsync -avz build/html/ docs.opensimcreator.com:/var/www/docs.opensimcreator.com/manual/en/VERSION

# set them as 'latest` (if desired)
ssh docs.opensimcreator.com ln -sfn /var/www/docs.opensimcreator.com/manual/en/0.5.12 /var/www/docs.opensimcreator.com/manual/en/latest
```
