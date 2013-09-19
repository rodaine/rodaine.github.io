---
layout: post
title: "Experimenting with Canvas &amp; request­Animation­Frame"
description: Or that giddiness you feel when something is way easier than you expected
keywords: "html5, canvas, requestAnimationFrame, JavaScript"
---

![Screenshot of the animation we will be creating](http://res.cloudinary.com/rodaine/image/upload/c_scale,w_1024/v1379290833/Screen_Shot_2013-09-15_at_8_19_22_PM_hkqqn3.png "Checkout the embeded Pen below to see it in all its screensaver-esque glory")

Recently at work, I was checking out some designs for a client's print piece, and was struck by this mesmerizing geometric pattern in the background. I mentioned to [Taylor Gorman][taylor] that it'd be awesome if &ndash; when these designs were translated to their site &ndash; the background was animated similar to the old [bezier screensaver][bezier] that used to come with Windows (it might still do?). 

Up to this point, I hadn't experimented with the new-ish canvas features of HTML5, so I figured I'd give it a go. Today, I'll walk through the process I used to create [this animation][pen]. Just a fair warning, I've come to love writing my JavaScript in [CoffeeScript][cs], so if you aren't a fan, I encourage you to check out the generated JS on the [pen][pen]. The entire source is also available as [a gist][gist], too!

The goal was to have a bunch of overlapping translucent triangles animate within the canvas. Each triangle's vertices should animate independently to give the scene a very chaotic feel. Let's see how we do...

### Configuration & Utilities ###

<aside>Honestly, I wrote this portion last, but since I make reference to it throughout the code, it's best to start here.</aside>

The `config` object provides a bunch of static settings for tweaking the behavior of the animation, including the number of triangles to render, their speed, and the ranges for color and opacity for each of the shapes. 

{% gist 6575633 config.script.coffee %}

`clamp` keeps numbers inside a range; this is particularly useful for keeping the triangle vertices within the canvas boundary. `rand` is a small random number utility to keep us DRY. And finally, `requestAnimFrame` is a compatibility wrapper for [`requestAnimationFrame`][raf]. 

#### Ok…so what the heck is `requestAnimationFrame`? ####

Back in the day, JS animations relied on `setTimeout` as the event/update/render loop for animations. While this worked, it was suboptimal especially if multiple animations were occurring simultaneously. 

Thus, browser vendors implemented this new API which allows developers to update their animations right before a repaint. Our version of `requestAnimFrame` is brought to you by [Paul Irish][paul], which handles vendor prefixed versions of this method with a fallback to the old-school `setTimeout` method.

### In the Beginning: The `Vector` ###

Our first class will be the `Vector`, which is somewhat of a misnomer. In this case, a `Vector` object is either used as a point or bearing on the canvas. Let's dig into the definition:

{% gist 6575633 vector.script.coffee %}

A `Vector` instance stores the coordinates (or bearing) in it's `x` and `y` properties. The rest of the methods are helper functions related to boundaries, translations and reflections, just a bit of baby linear algebra.

`Vector.random` will generate a random instance within the boundary provided (we'll cover the `Bounds` class next, don't you worry). Since each of the triangles will be randomly generated, this function is more than just a fancy little toy.

`Vector#outOfBounds` tests to see if a vector instance is outside the limits of a provided boundary. This is important for collision detection after a translation has been applied to the vector.

`Vector#clamp` does the same thing as the scalar `clamp` function, but now forces the vector coordinates within the provided boundary.

`Vector#addVector` performs a vector addition by adding the provided vector to the current instance. Mathematically, an example would be `{1, 1} + {1, 2} = {2, 3}`. This is the method we will be using to translate the vertices of each of the trianges.

`Vector#scalarProduct` multiples a scalar against the current vector instance, e.g. `2 * {1, 2} = {2, 4}`. This will be important for applying our speed factor set in the `config` object.

And finally, `Vector#reflectAndClamp` checks if a vector is out of bounds, and &ndash; if it is &ndash; reflects the bearing `Vector` instance depending on which side of the boundary it has crossed before clamping the current instance to the provided bounds. That is to say: *collision detection*. 

All super exciting stuff, right?! I promise things will get more exciting, but first one more *thrilling* class...

### Party gone out of `Bounds`! ###

This little class describes a rectangular boundary on the Cartesian plane, defined by two `Vector` instances at the top-left and bottom-right. It also includes a few helper methods to characterize the extrema:

{% gist 6575633 bounds.script.coffee %}

This one is super-straightforward, so we'll skip ahead to the bread-and-butter of the animation...

### The `Triangle` ###

Our meat-and-potatoes (I can do these food analogies all day, if you'd like), a `Triangle` instance is described by its three vertices & corresponding bearings, the bounds it's contained within, and its color & opacity. For each update step, the triangle translates each vertex by its bearing, performing any collision detection necessary. A `Triangle` object is also responsible for rendering itself on the canvas context. Enough preamble!

{% gist 6575633 triangle.script.coffee %}

A `new Triangle` takes a `Bounds` to create a completely random instance. First, the fill color RGBA values are randomly selected from the ranges specified in `config`. Notice that the color numbers must be floored; any non-integer value for the RGB  will result in opaque black triangles. Nooooot what we're looking for. Next, random `vertices` are generated for the three points of the triangle. Likewise, random `bearings` are created from a boundary between `{-1, -1}` and `{1, 1}`, which are then scaled by the speed factor defined in `config`. 

`Triangle#update` steps the instance one tick or translation, which we will define explicitly in the next section. Each `Vector` of the triangle is translated by it's bearing, and collision detection is then performed on the point to reflect it's bearing if it's encountered an edge. That's it!

`Triangle#render`, well, renders the triangle on the canvas. Two arguments are provided: the `context`, and a `partialStep`. The `context` handles actually drawing the shape onto canvas element, while `partialStep` will help us extrapolate if there is any lag in the time between the current request to render and the last update (more on this in a moment). 

First, `Triangle#render` generates the points it needs to render. Basically, this is just the `vertices` of the triangle. However, sometimes the request to render is made midway between calls to `Triangle#update`, so the animation may appear jittery as it's playing catch up. For example, suppose `update` is called every 30ms, but `render` is called every 45ms. The animation would lag the actual position of the triangle's vertices by half an update. 

To counteract this lag, `Triangle#render` is passed how many partial update steps &ndash; `partialStep` &ndash; the animation is behind. This will be a real number between 0 (completely in-sync) and 1 (exclusive). `partialStep` is then used to extrapolate the true position of the `Vertex` by translating it partially. Notice, that no collision detection is done, so it is possible the point may render outside of the bounds, but this will only exist for a single frame (hopefully) and the next render will be more closely caught up with the updates). Overkill? Perhaps considering the simplicity of this example, but it guarantees the smoothest possible animation. 

Lastly, notice that the points' coordinates are run through `parseInt` to get an integer value. When rendering to a canvas, using non-integers will result in really hideous anti-aliasing. You could probably also use `Math.floor`, `Math.ceil` or `Math.round` to the same effect.

Now that we have our points, we can actually draw them on the `context`, our canvas' instance of [`CanvasRenderingContext2D`][context]. The `fillStyle` is set to the RGBA color for the triangle, a path is drawn between each point in the triangle and then filled with our specified color. Simple as that. We're almost there; hang in!

### The <del>Artist's</del> Developer's `Canvas` ###

Okay, so probably not the best name for the class considering it's not the actual `<canvas/>` element. A `Canvas` instance will wrap the element however, hold references to all the triangles to be displayed, and contain the update/render loop:

{% gist 6575633 canvas.script.coffee %}

`updateStep` stores the time (in ms) between each update. It's defaulted to 60fps (1000ms / 60fps = 16.67ms) but should be a value less than or equal to the time between frames (inverse of fps).

When a `new Canvas` is created, the 2d  `context` is retrieved from the passed canvas `el`, and the other properties are set.

`Canvas#update` runs through all the triangles added via `Canvas#addTriangle` and updates their position one tick. Likewise, `Canvas#render` tells the triangles to render themselves on the `context` after clearing the previous frame. Remember, all the actual magic occurs over on the `Triangle` instances.

On to the update loop: `Canvas#loop`. The actual logic for this method was inspired by [Bob Nystrom][bob] in his online book *[Game Programming Patterns][gpp]*; I strongly encourage you check it out, even if you aren't interested in game dev. First, the `current` timestamp is obtained, and the time difference between `current` and our `previous` timestamp is added to the cumulative `lag` of our animation. Next, we attempt to perform an update for each `updateStep` in `lag`, attempting to catch us up with the real-time position of the triangles in the animation. Once the `lag` is reduced to below a single `updateStep`, `Canvas#render` is called and passed the ratio of `lag` to `updateStep` as the `partialStep` extrapolation value.

And, finally, the ON button for this whole contraption: `Canvas#start`. This method makes the self referencing call to our `requestAnimFrame` wrapper and then calls `Canvas#loop`. Why loop after the rAF? If the animation has fallen-back to the `setTimeout` method, calling it first will ensure we are as close to 60fps as possible.

### Putting it all together ###

All that's left is to bootstrap our animation onto a canvas element. We do rely on a bit of jQuery here (read: laziness), but depending on how you were to implement the canvas, it may not be necessary:

{% gist 6575633 bootstrap.script.coffee %}

First, we grab the canvas element in our document and set it's actual width & height, to the CSS width & height. Why? Think of a canvas element like an image; you can use CSS to stretch an image to any size, but it will end up looking deformed. Same goes for a canvas, but you can modify it's width & height prior to drawing on it to expand it appropriately. If you check out the [pen][pen], you'll notice that I wanted the canvas to fill the screen, so this technique made sure the canvas dimensions were changed accordingly.

Next, based off these dimensions, we define the `Bounds` in which we will render the animation. You could simply set the boundary to be the same as the canvas element, but the animation is not as pretty (due to the many triangle points on screen at once). Instead, the bounds are set to account for some overflow by extending it 25% in every direction. I encourage you to experiment with these values for your own aesthetic.

Now, we create the `Canvas` object with our canvas element and add our triangles to the stack (the quantity of which we defined in `config`). Finally, to get things rolling, we make the call to `Canvas#start`. Profit!

So, what does it look like?

{% include widgets/codepen.html slug='mEnuw' height=400 %}

### What's Next ###

There is a *lot* of room for improvement here. Looking at the memory profile in dev tools reveals there aren't any memory leaks, but there is a pattern of garbage collection spikes resulting from discarded objects, most likely from the temporary `points` collection in `Triangle#render`. If we were to forgo creating those objects in the first place or cache those points on the `Triangle` instance (overwritting the coordinates on each render), those spikes would be minimized.

Another cool addition would be to also animate the color of each triangle. Switching the colors to a HSLA implementation would allow you to loop through the hue value similar to the actual bezier screensaver. Actually, I'm kicking myself for not thinking of it when I first implemented this. Blast you, 20-20 hindsight!

Lastly, it would be nice if it responded appropriately to DOM events, especially resize. Right now if you were to resize the preview screen on the [pen][pen], the animation will distort with it. Basic DOM event handling would avoid this.

Of course, I leave these as exercises for my dear readers (or future self, more likely). This was a fun foray into the land of JS/canvas animations, and I'm tempted to delve into the topic deeper. Perhaps, a game... more to come!

[taylor]: http://taylorpatrickgorman.com/
[bezier]: http://www.youtube.com/watch?v=sql60Bvz0rU
[pen]: http://codepen.io/rodaine/pen/mEnuw
[cs]: http://coffeescript.org/
[gist]: https://gist.github.com/rodaine/6575633
[raf]: https://developer.mozilla.org/en-US/docs/Web/API/window.requestAnimationFrame
[paul]: http://www.paulirish.com/2011/requestanimationframe-for-smart-animating/
[context]: https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D
[bob]: https://twitter.com/munificentbob
[gpp]: http://gameprogrammingpatterns.com/
