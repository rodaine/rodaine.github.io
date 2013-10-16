---
layout: post
title: Browser Testing Internet Explorer with Virtual Machines
description: In which I reliably simulate legacy AND modern browsers.
keywords: Browser Testing, Internet Explorer, IE, virtual machine, IEVMS
---

I am a born-again Mac user; I openly admit that. Originally, I viewed Apple products as Pretension Incarnate™ but have since come to realize that they not only contain superior hardware but also sport finer software, too (excluding, perhaps, videogames).

That said, I am intentionally placing myself in a minority. At the time of writing, [Windows represents ~85% of internet use worldwide][oses] according to StatCounter, while Mac represents only slightly more than 7%. I'm OK with that, but when it comes to my work, I am well aware that the vast majority of users will not be using the same environment as me. So how do I ensure that what I see in Chrome on an up-to-date Mac looks just as good on Windows XP running IE8? <strike>I die a little on the inside, and</strike> *I browser test*.

### The Trouble with Browser Testing ###

In theory, browser testing is as easy as it gets: You open up your site – either live or [a local development version][local] – in whichever browser you want to test and adjust the styles, scripts or markup accordingly. *Right?!* I can hear you guffawing from here…

Beyond the obvious differences in feature support, bugs, rendering differences, and vendor-specific *things*, there are also a boatload of technical hurdles as well. For one, different versions of IE cannot be installed alongside each other on the same machine. And don't forget that certain IE versions only run on certain versions of Windows; XP only supports IE 6-8, Windows 7 covers IE 8-10, and Windows 8 handles IE 10+. 

[oses]: http://gs.statcounter.com/#os-ww-monthly-201307-201309-bar
[local]: /2013/10/develop-locally-with-wordpress/
