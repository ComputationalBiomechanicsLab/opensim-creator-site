---
title: "DevBlog: Implementing HighDPI Support"
date: 2024-11-11
draft: true
params:
    banner: img/gallery/0.5.16_color-scaling-preview.png
---


In this post, I'm going to document how high DPI support is being developed for
OpenSim Creator. I thought this would be nice to write up, because I found the
process interesting, but unintuitive, in places. So this post acts as both 
a development reminder for myself (when I'm debugging the inevitable issues
that will arise due to any technical choices outlined here) and as a technical
explanation for other developers (who will look at OpenSim Creator's source code
and wonder why on earth "pixels" or "virtual pixels" aren't the same as "physical
pixels" or "device pixels").


# Technical Overview

OSC began development as a cross-platform application that used very "raw" libraries,
so that it could be lightweight and easy to natively build on multiple platforms.
It used [SDL2](https://www.libsdl.org/) to abstract the different operating systems,
[OpenGL](https://www.opengl.org/) for rendering 3D graphics, and [Dear ImGui](https://github.com/ocornut/imgui) for
rendering the 2D UI (buttons, dropdowns, and so on). Skipping over OSC's development
timeline (that could be another post), the takeaway is that OSC was initially
developed with low-level APIs - and with little regard for high-DPI rendering.

Low-level APIs *usually* work in "device pixels". If you tell SDL to create a window
that's `600` wide, you'd expect a window that is 600 dots (pixels) wide. When
SDL later emits an `SDL_MouseMotionEvent` within that window, you'd also expect
that the `x`, `y`, `xrel`, and `yrel` quantities are expressed in terms of pixels.


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