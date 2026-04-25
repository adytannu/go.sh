# Dot Bootstrap

Public bootstrap for a new Linux or macOS machine.

Run it from a new machine with:

```sh
curl -fsSL https://tannu.me/go.sh | bash
```

With explicit Git identity:

```sh
curl -fsSL https://tannu.me/go.sh | SETUP_GIT_NAME="Your Name" SETUP_GIT_EMAIL="you@example.com" bash
```

The script installs basic prerequisites when it can, installs Oh My Bash with `wget`, configures a few Git defaults, creates an RSA SSH key for Bitbucket with a comment like `aditya@hostname`, writes a Bitbucket-specific SSH config block, and prints the public key so it can be pasted into Bitbucket.

## Options

```sh
INSTALL_PACKAGES=0      # skip package manager installs
INSTALL_OH_MY_BASH=0    # skip Oh My Bash
CONFIGURE_GIT=0         # skip git config
CREATE_SSH_KEY=0        # skip SSH key setup
NO_PROMPT=1             # non-interactive defaults

SSH_KEY_NAME=id_rsa
OMB_THEME=font
OMB_PLUGINS=git
SETUP_EDITOR=vim
```

Example:

```sh
curl -fsSL https://tannu.me/go.sh | INSTALL_PACKAGES=0 OMB_THEME=powerline bash
```

## Hosting On GitHub Pages

1. Create a public GitHub repo, for example `dot`.
2. Commit `go.sh`, `.nojekyll`, and `CNAME`.
3. Push to GitHub.
4. In the repo settings, open **Pages** and publish from the `main` branch root.
5. Set the custom domain to `tannu.me`.
6. In your DNS provider, point the domain at GitHub Pages.

For the shortest clean command, use the apex domain:

```sh
curl -fsSL https://tannu.me/go.sh | bash
```

A `www` or dedicated subdomain is usually operationally simpler:

```sh
curl -fsSL https://setup.tannu.me/go.sh | bash
```

## Bitbucket

After the script prints or copies the public key:

1. Open Bitbucket.
2. Go to **Personal Bitbucket settings**.
3. Open **SSH keys** under **Security**.
4. Select **Add key**.
5. Paste the public key.
6. Test with:

```sh
ssh -T git@bitbucket.org
```

## Recommendations

Keep this repo public and boring. Do not put tokens, private keys, work-only config, or machine-specific secrets here.

Add new setup tasks to `go.sh` only when they are safe to run repeatedly. Prefer idempotent blocks with clear markers in files such as `~/.bashrc` and `~/.ssh/config`.

For private setup, use a second private repo that you clone after SSH is working, or encrypt secrets with a tool like `age` or `sops`.
