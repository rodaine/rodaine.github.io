---
layout: post
title: Style Guide
description: Or how I strive to stay consistent
---

This _perma_-draft shall serve two purposes. First, it should describe the desired layout of posts. Specifically, the document should describe how and when to use certain markup features, structural components, widgets, and writing style.

<aside><strong>Style Note:</strong> every article should open with a paragraph or two leading into the meat of the article. This should precede any headings in the article. It should <strong>NOT</strong> open with an <code>&lt;aside&gt;</code> like this as it would appear in the snippet on the list view.</aside>

The second purpose is as an example of most (if not all) of the CSS rules that can exist in an article, which is useful for making sure the layout behaves as expected.

### Metadata

While I don't mind screaming into the void, optimizing for the discoverability and usability of these posts is important. To better achieve that, carefully curating the metadata around articles is very important for search crawlers, social embeds, and the like.

#### Title, Subtitle, and Permalink

The title of a post should capture the main content of the entire article. It is what shows up in the <abbr>SERP</abbr>, the title of the html page, in social cards, and embeds. While probably chockful of jargon, the title should still not come off as if it belongs on an academic thesis. The subtitle (description field in the <abbr>YAML</abbr> front-matter) should be a dependent clause (ex: "Where I code the thing") that captures the subtext of the article.

The permalink should closely resemble the title of the article but can strip out valueless words. For ambiguous jargon, thinking in particular about Go, it is best to use its more searchable name (Golang) both in the titles and permalink.

#### Other Metadata

The majority of the meta tags in the `head` element are automatically generated from the rest of the information provided in the the front-matter. This includes traditional metatags, [schema.org](https://schema.org) microdata and Open Graph (and the Twitter extensions). There are some interesting overrides on a per-page basis, however, that can be overridden in the front-matter:

* `schema` - Defaults to "WebPage" for all pages (the article content itself is identified as a "BlogPosting"). Notable exception would be the "AboutPage", though it is likely that'll be the only one.
* `keywords` - While having no effect on SEO, keywords could be useful later on for different ways to display or access the content.
*

### Headings

The `h1` tag is used by the site title, and the `h2` is reserved for the article title. While it might be an arbitrary rule with <abbr>HTML5</abbr>, an article should still maintain the header hierarchy and **only contain `h3` and smaller headers.** The headers must follow the page hierarchy, cannot skip (eg, an `h4` before an "opening" `h3`) and should not be consecutive without some body content in-between.
