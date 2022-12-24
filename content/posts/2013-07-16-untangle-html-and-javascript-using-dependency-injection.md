---
title: Untangle HTML and Javascript using Dependency Injection
description: Or how decoupling markup from behavior improves the maintainability of your client-side code
keywords: dependency injection, bindable, javascript, html, coffeescript, decouple
---

On the [CNP Blog][cnp] today, I wrote a post outlining a technique for dependency injection in JavaScript. We've all been there in a JS project: a series of simple, innocuous event bindings explodes into thousands of lines of unmanageable code so reliant on the markup that making changes potentially generates more bugs than it fixes. Hyperbole? Perhaps not:

{{<citation title="Untangle HTML and Javascript using Dependency Injection" url="http://clarknikdelpowell.com/blog/untangle-html-and-javascript-using-dependency-injection/">}}
For small projects with minimal JavaScript, abstraction of this nature is unnecessary, but as soon as the project grows to more than a few hundred lines with many moving parts, managing the code and its relationship to the markup becomes exponentially more difficult. Implementing changes, new features and bug fixes might have unintended side effects that slow down development and produce serious code smell. By decoupling the DOM from the JavaScript and using dependency injection to associate functionality with the elements on the page, we can easily improve the quality of our code and make it more flexible, testable and reusable across projects.
{{</citation>}}

[Jed Schneider][jed] of [ModeSet][ms] gave a great presentation on this topic at [Converge SE][con]. In fact, the method I outlined in the article is based off ModeSet's JS component library called Utensils. Hat tip to Jed!

[cnp]: http://www.clarknikdelpowell.com/blog
[jed]: http://twitter.com/jedschneider
[ms]: http://www.modeset.com/
[con]: http://convergese.com/
