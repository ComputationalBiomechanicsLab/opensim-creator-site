---
title: "DevBlog: Custom Icon Fonts"
date: 2024-12-05
draft: true
params:
    banner: img/gallery/0.5.16_color-scaling-preview.png
---


In this post, I'm going to outline how custom fonts are designed, aggregated,
and integrated into OpenSim Creator. The reason I wrote this up is because the
process had a few false starts (bad tooling pathways, unclear documentation, etc.)
and I thought it would be useful to document---in an informal way---what I
eventually settled on.

# Background/Technical Overview

OpenSim Creator uses custom icon fonts as a way of both sprite-sheeting
the icons (so they load/blit more easily) and piggy-backing on its existing
UI text rendering infrastructure (which supports stuff like compositing text
into button widgets). Before going through this process, OpenSim Creator
exclusively used a combination of [fontawesome](https://fontawesome.com/),
which encodes 1000+ icons into a single `ttf` file, and [IconFontCppHeaders](https://github.com/juliettef/IconFontCppHeaders),
which exposes the icons' glyph unicode codepoints as preprocessor `#define`s
that could be directly used in OpenSim Creator's UI code in places where
the UI accepts text.

- Inkscape UI is usually excellent for my purposes, but the SVG font
  tooling results in having mega-SVGs. The UX for encoding an entire
  font into an inkscape SVG, followed by double-checking it in FontForge,
  followed by encoding it into a TTF/OTF is extremely annoying.

- Fontforge UI has terrible UX, but is otherwise very competent

- Luckily, it exposes a python API. However, the API is a little bit
  annoying to set up on each OS, which might be an opportunity for
  switching it over later etc.
