# OpenSim Creator Site

> The source code behind www.opensimcreator.com
>
> A landing page for the OpenSim Creator project, which includes a gallery and
> relevant links to (e.g.) documentation.

This repository contains the source code for OpenSim Creator's user-facing landing
page, which is hosted at https://www.opensimcreator.com . It's kept in a separate
repository from the [OpenSim Creator](https://github.com/ComputationalBiomechanicsLab/opensim-creator)
code because it has different build/deployment/development cycle requirements.


## 🖥️ Dependencies/Environment Setup

The website source code is self-standing, but may contain URLs to `https://files.opensimcreator.com`
when the asset is very large or shared (e.g. videos). The concrete deployment
steps and relevant configuration files that we use to ship the website
and `files.opensimcreator.com` is described in [devops](devops/).

The website is built using only [hugo](https://gohugo.io) as a dependency. The
general procedure for installing it is:

- Go to https://gohugo.io/installation/
- Follow the relevant guide for your platform. As a concrete example, download a
  prebuilt `hugo_extended` binary from https://github.com/gohugoio/hugo/releases/tag/v0.127.0
  and ensure it's on the `PATH` for your platform (or manually invoke it, e.g.
  on Windows, with `../hugo.exe`)
- Once installed, the docs should be serve-able by `cd`ing into this repository's
  working directory and running `hugo serve`


## 🏗️ Building

To build the source code into standalone web assets, use the `hugo` command:

```bash
hugo  # places built assets in `public/`
```

## ⌨️ Developing

To live-build the website, use `hugo serve`:

```bash
hugo serve  # usually hosts the local dev server at `localhost:1313`
```


## 🕊️ Releasing

This codebase doesn't have a release cadence/plan. It is just updated whenever
there's new content that we'd like to upload.


## 🚀 Deploying

Deployment of a release of the website to (e.g.) https://www.opensimcreator.com
is described in [devops/](devops/). The procedure is subject to change, but
*probably* involves some variation of `rsync`ing the built assets to a
webserver, or GitHub Pages.
