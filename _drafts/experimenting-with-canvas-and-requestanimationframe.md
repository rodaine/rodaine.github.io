---
published: false
layout: post
title: "Experimenting with Canvas & requestAnimationFrame"
description: Or that giddiness you feel when something is way easier than you expected
keywords: "html5, canvas, requestAnimationFrame, JavaScript"
---

![Screenshot of the animation we will be creating](http://res.cloudinary.com/rodaine/image/upload/c_scale,w_1024/v1379290833/Screen_Shot_2013-09-15_at_8_19_22_PM_hkqqn3.png "Checkout the embeded Pen below to see it in all its screensaver-esque glory")

Recently at work, I was checking out some designs for a client's print piece, and was struck by this mesmerizing geometric pattern in the background. I mentioned to [Taylor Gorman][taylor] that it'd be awesome if &ndash; when these designs were translated to their site &ndash; the background was animated similar to the old [bezier screensaver][bezier] that used to come with Windows (it might still do?). 

Up to this point, I hadn't experimented with the new-ish canvas features of HTML5, so I figured I'd give it a go. Today, I'll walk through the process I used to create [this animation][pen]. Just a fair warning, I've come to love writing my JavaScript in [CoffeeScript][cs], so if you aren't a fan, I encourage you to check out the generated JS on the [pen][pen].

The goal was to have a bunch of overlapping translucent triangles animate within the canvas. Each triangle's vertices should animate independently to give the scene a very chaotic feel. Let's see how we do...

### Configuration & Utilities ###

Honestly, I wrote this portion last, but since I make reference to it throughout the code, it's best to start here. Let's take a look:

{% gist 6575633 config.script.coffee %}

The `config` object provides a bunch of static settings for tweaking the behavior of the animation, including the number of triangles to render, their speed, and the ranges for color and opacity for each of the shapes. 

`clamp` keeps numbers inside a range; this is particularly useful for keeping the triangle vertices within the canvas boundary. `rand` is a small random number utility to keep us DRY. And finally, `requestAnimFrame` is a compatibility wrapper for [`requestAnimationFrame`][raf]. 

#### Ok…so what the heck is `requestAnimationFrame`? ####

Back in the day, JS animations relied on `setTimeout(animate, 1000/60)` as the event/update/render loop for animations. While this worked, it was suboptimal especially if multiple animations were occurring simultaneously. 

Thus, browser vendors implemented this new API which allows developers to update their animations right before a repaint. Our version of `requestAnimFrame` is brought to you by [Paul Irish][paul], which handles vendor prefixed versions of this method with a fallback to the old-school `setTimeout` method.

### In the Beginning: The Vector ###

Our first class will be the `Vector`, which is somewhat of a misnomer. In this case, a `Vector` object is either used as a point or bearing on the canvas. Let's dig into the definition:

{% gist 6575633 vector.script.coffee %}

{% include widgets/codepen.html slug='mEnuw' height=400 %}

[taylor]: http://taylorpatrickgorman.com/
[bezier]: http://www.youtube.com/watch?v=sql60Bvz0rU
[pen]: http://codepen.io/rodaine/pen/mEnuw
[cs]: http://coffeescript.org/
[raf]: https://developer.mozilla.org/en-US/docs/Web/API/window.requestAnimationFrame
[paul]: http://www.paulirish.com/2011/requestanimationframe-for-smart-animating/