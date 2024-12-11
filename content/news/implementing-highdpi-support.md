---
title: "DevBlog: Implementing HighDPI Support"
date: 2024-11-11
draft: true
params:
    banner: img/gallery/0.5.16_color-scaling-preview.png
---


In this post, I'm going to document how high DPI support is being developed for
OpenSim Creator. I thought this would be nice to write up, because I found the
process interesting, but unintuitive. So this post acts as both a
development reminder for myself and as a technical explanation for other
developers (who will look at OpenSim Creator's source code
and wonder why on earth "pixels" or "virtual pixels" aren't the same as "physical
pixels" or "device pixels").


# Technical Overview

OpenSim Creator uses very "raw" and low-level libraries. This is so that it is
lightweight, can directly call the OpenSim C++ API, and is easy to natively
build/debug from source on all target platforms. The alternative is to use/build
a larger cross-platform library stack (e.g. Qt) on each each platform, or use a
non-native stack (e.g. Electron). The reason I opted for the former is because
I enjoy the degree of control it grants over the user experience - albeit, at
the cost of debugging stuff like highDPI support.

At time of writing, OpenSim Creator uses [SDL2](https://www.libsdl.org/) to abstract the
different operating systems, [OpenGL](https://www.opengl.org/) to render 3D graphics,
and [Dear ImGui](https://github.com/ocornut/imgui) to render the 2D UI. These libraries
don't automagically support high-DPI scaling. If you tell SDL to create a window that's `600`
wide, the expectation is that it creates a window that is 600 physical pixels (as in,
dots on a screen) wide. Also, when SDL later emits events related to that window (e.g.
a `SDL_MouseMotionEvent` *within* a window), the expectation is that the `x`, `y`, `xrel`,
and `yrel` fields in that event are expressed in terms of physical pixels.

However, in the world of highDPI, these assumptions aren't necessarily true. Some OSes
differentiate between the number of physical pixels in a window and the number of
"virtual" or "native" pixels in the window, where the "virtual" ones typically
exist to emulate a pixel density that roughly matches what pre-highDPI monitors were
(usually, 96 DPI). Here's an example of how some OSes behave:

- **MacOS**: In 2010, Apple became one of the first mainstream highDPI vendors when
  it released retina displays. Almost no (third-party) software supported highDPI at
  this time, which is why (I'm *guessing*) MacOS uses a virtual pixel emulation system
  at the OS level. What this means is that---even when running in highDPI mode---MacOS's
  events, window dimensions, etc. are all expressed as "virtual" pixels with a roughly
  96 DPI density, so that any application code that's density-dependent (e.g.
  "draw a line that's 5 px long") will occupy roughly the same physical space on a
  highDPI screen once the virtual pixels are upscaled to the higher-DPI system.

- **Windows**: Windows

   when it released
  retina displays in  it   market When retina displays entered the market in 2010, macs were one of the first
  entrants into  One of the first entrants into highDPI scaling
windows (e.g. MacOS, one of the first entrants into HighDPI because of its retina screen
support, opted for this emulation approach). Other OSes uniformly use physical pixels, but
*also* provide a recommendation scalar to the application to tell it to scale UI elements
up to a larger number of pixels (e.g. Windows, which entered the HighDPI game a little later
but also has in-OS support for stuff like user-defined per-window scaling for legacy software
support).

These 


# Background Work: Other Implementations

## The Web

The web uses a virtual pixel system in which the pixel density is assumed to
be 96 DPI. Mozilla's [window.devicePixelRatio](https://developer.mozilla.org/en-US/docs/Web/API/Window/devicePixelRatio) documentation
describes some of the details and uses the terms "CSS pixel" to describe a
virtual pixel and "physical pixel" to describe a pixel in the display device.

CSS, Javascript, and HTML all use this virtual pixel system. The [window.devicePixelRatio](https://developer.mozilla.org/en-US/docs/Web/API/Window/devicePixelRatio)
API can be used to query how many physical pixels correspond to a single virtual
pixel.

For example, I have two monitors. If I open the Firefox developer tools console
and play around, here's what I see:

- Window on a low DPI monitor @ 1920x1080: `window.innerWidth == 1920`, `window.devicePixelRatio == 1`
- Window on a high DPI monitor @ 3840x2160 , `window.innerWidth == 1920`, `window.devicePixelRatio == 2`

Dragging the Firefox application window between the two monitors changes the
values to match where the window is dragged to. On Windows, there's a
breakpoint where you can see the OS snap between the two window modes.

The same also applies to events - even if those events aren't directly related
to the window. E.g. if I monitor mouse motion, the mouse motion is given in
terms of virtual pixels:

```javascript
window.addEventListener("mousemove", (e) => { console.log(e); });
// when the mouse is near the right-hand edge:
// mousemove { target: html, buttons: 0, clientX: 1920, clientY: 199, layerX: 1920, layerY: 199 }
```

## Qt

Qt uses a virtual pixel system, where the virtual pixels are called
"device-independent pixels" and are usually 96 DPI ([source](https://doc.qt.io/qt-6/highdpi.html)).
Most of Qt's widgets and events use device-independent pixels, including middle-layer
drawing APIs (e.g. `QPainter`, which is somewhat analogous to ImGui's `ImDrawList`).

For example, if I write a Qt application that contains a `QWindow` with a status
bar and listen to mouse move events, emitting the X, plus the current `devicePixelRatio`:

```c++
bool MainWindow::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::MouseMove)
    {
        QMouseEvent *mouseEvent = static_cast<QMouseEvent*>(event);
        statusBar()->showMessage(QString("X = %1, ratio =  %2").arg(mouseEvent->pos().x()).arg(devicePixelRatio()));
    }
    return false;
}

```

Then here's what I see when I move my mouse to the right-hand edge of a maximized
window:

- Window on a low DPI monitor @ 1920x1080: `X = 1920, ratio = 1`
- Window on a high DPI monitor @ 3840x2160 , `X = 1920, ratio = 2`

Qt doesn't use device-independent pixels when using low-level graphics APIs (e.g.
OpenGL), which makes sense, because those APIs are lacking the concept.

`QImage` and `QPixmap` represent "raw" pixels and, as a result, also don't use
device-independent pixels. However, in order to deal with (e.g.) a `QPixmap` not
rescaling when it's moved between windows/screens with different `devicePixelRatio`s,
`QPixmap` additionally stores its own `devicePixelRatio` in addition to its pixel
width/height. This is then used by the compositing engine to rescale the image
when it's composited into the rest of the UI.

Another notable trick is how Qt handles scaling image assets. It's usually achieved
using a special naming convention (e.g. `logo@2x.png`) and the `QIcon` implementation
will load the various available sizes, so that the icons are handled correctly
when moving between screens with different DPIs.


## Scalable Vector Graphics (SVG)

## Godot/Unity?


# SDL3 Changes

As part of advancing OSC's support for high DPI monitors, I adopted SDL3, which
has better support for querying the various scale factors etc.


# Scrap Notes

```c++
#include "mainwindow.h"
#include "./ui_mainwindow.h"

#include <QImage>
#include <QMouseEvent>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    qApp->installEventFilter(this);
    QFont font = ui->label->font();
    font.setPointSize(72);
    ui->label->setFont(font);


    image.load(R"(C:\Users\adamk\Desktop\Screenshot 2024-11-10 153056.png)");
    qDebug() << image.devicePixelRatio();
    scene = new QGraphicsScene(this);
    scene->addPixmap(image);
    scene->setSceneRect(image.rect());

    ui->graphicsView->setScene(scene);
}

bool MainWindow::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::MouseMove)
    {
        QMouseEvent *mouseEvent = static_cast<QMouseEvent*>(event);
        statusBar()->showMessage(QString("X = %1, ratio =  %2").arg(mouseEvent->pos().x()).arg(devicePixelRatio()));
    }
    return false;
}

MainWindow::~MainWindow()
{
    delete ui;
}
```