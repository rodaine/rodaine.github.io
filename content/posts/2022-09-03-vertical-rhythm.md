---
title: 'Style Guide (?)'
description: Just want to make sure that the veritical rhythm is preserved if the description is super long and spans multiple lines
draft: true
---

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales ex venenatis ipsum dictum pretium. Vestibulum at venenatis nulla. Sed eu pellentesque dui. Mauris eget vulputate odio. Morbi feugiat nibh vel metus imperdiet, id volutpat augue iaculis. Maecenas sit amet nibh nisi. Ut lobortis tincidunt diam, eget suscipit mauris mollis sit amet. Duis eros justo, vestibulum sit amet enim et, euismod feugiat nunc. Sed volutpat ante et nunc egestas, id egestas diam consectetur. Sed eu ornare nibh. Fusce aliquam odio ac justo fringilla interdum. Donec elementum non mauris quis tristique.

### H3. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales ex venenatis

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales ex venenatis ipsum dictum pretium. Vestibulum at venenatis nulla. Sed eu pellentesque dui. Mauris eget vulputate odio. Morbi feugiat nibh vel metus imperdiet, id volutpat augue iaculis. Maecenas sit amet nibh nisi. Ut lobortis tincidunt diam, eget suscipit mauris mollis sit amet. Duis eros justo, vestibulum sit amet enim et, euismod feugiat nunc. Sed volutpat ante et nunc egestas, id egestas diam consectetur. Sed eu ornare nibh. Fusce aliquam odio ac justo fringilla interdum. Donec elementum non mauris quis tristique.

1. This is a non paragraph ordered list
1. The values should be like essentially `<br\>`'d to each other with the appropriate prefix.
1. If there is a really long line this should just wrap and totally be OK without affecting the rhythm of the following content. Or at least that was the intent.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales ex venenatis ipsum dictum pretium. Vestibulum at venenatis nulla. Sed eu pellentesque dui. Mauris eget vulputate odio. Morbi feugiat nibh vel metus imperdiet, id volutpat augue iaculis. Maecenas sit amet nibh nisi. Ut lobortis tincidunt diam, eget suscipit mauris mollis sit amet. Duis eros justo, vestibulum sit amet enim et, euismod feugiat nunc. Sed volutpat ante et nunc egestas, id egestas diam consectetur. Sed eu ornare nibh. Fusce aliquam odio ac justo fringilla interdum. Donec elementum non mauris quis tristique.

#### H4. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales ex venenatis

#### H4. Another one `CODE`

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque sodales ex venenatis ipsum dictum pretium. Vestibulum at venenatis nulla. Sed eu pellentesque dui. Mauris eget vulputate odio. Morbi feugiat nibh vel metus imperdiet, id volutpat augue iacul

#### H4. Another one `with code` in the middle of it which is apparently affecting flow

is. Maecenas sit amet nibh nisi. Ut lobortis tincidunt diam, eget suscipit mauris mollis sit amet. Duis eros justo, vestibulum sit amet enim et, euismod feugiat nunc. Sed volutpat ante et nunc egestas, id egestas diam consectetur. Sed eu ornare nibh. Fusce aliquam odio ac justo fringilla interdum. Donec elementum non mauris quis tristique.

##### H5. Oh no

This line *contains* emphasized text.

This line **contains** strong text.

This paragraph has a line break
in the middle of it

This line has a ~~strikethrough~~ in it.

This line contains a [link](https://example.com).

This line contains inline `code` that we want to treat special.

---

> Single line blockquote

> This line is a multiline block quote.
>
> Multiple paragraphs as at were.
>
>> With a nested quote apparently

---

* This unordered list has a child list inside it!
  * Which is kinda weird no?
* I'm not so sure it's that bad.


1. This orderd list has a child but is paragraph-based.

    1. I'm not sure how often I'd use these, but I do have a couple of lists already, so...
    1. Maybe another child for good measure

1. Just to be on the safe side.


* Mid list block quote incoming

* Not yet, hold your horses...

  > Boom baby!

* There we go

- [x] This is a task list

- [ ] Maybe useful while i'm writing a post? What happens when I make a line in here really long though? Is the offset still appropriate so that the checkbox appears to be the bullet of the list?

- [ ] Could be interesting

- This is a paragraphed unorder list.

- It should basically behave like left/right-padded paragraphs with the floating prefix.

- Nullam egestas nibh quis felis pellentesque egestas ut in sem. Phasellus quis gravida justo. Aenean lobortis congue nibh a condimentum. Pellentesque pulvinar mauris eget purus pellentesque sollicitudin[^3]. Duis et eros erat. Proin condimentum diam vulputate dignissim pellentesque. Ut quis ultricies eros. Etiam ut nisi ligula. Sed ac libero faucibus magna convallis fermentum. Donec convallis erat a eros vulputate fringilla.

---

{{<citation title="Michael Scott">}}
  You miss 100% of the shots you don't take. - Wayne Gretzky
{{</citation>}}

{{<citation title="Dune" url="https://www.goodreads.com/quotes/2-i-must-not-fear-fear-is-the-mind-killer-fear-is">}}
I must not fear. **Fear is the mind-killer**. Fear is the little-death that brings total obliteration. I will face my fear. I will permit it to pass over me and through me. And when it has gone past I will turn the inner eye to see its path. Where the fear has gone there will be nothing. Only I will remain.
{{</citation>}}

---

```go {hl_lines=[3]}
package main

func main() {
  if err != nil {
    panic(err)
    // this comment should stretch pretty far outside the range of the code block so that it causes horizontal scrolling
  }
}
```

```go
package main

func main() {
  if err != nil {
    panic(err)
  }
}
```

---

| Syntax      | Description |
| :---------- | ----------- |
| Header      | Title       |
| Paragraph   | Text        |

| Syntax      | Description |  Money |
| :---------- | :---------: | -----: |
| Header      | Alpha       |  `$ 1.23` |
| Paragraph   | Beta        |  `$ 4.56` |
| Paragraph   | Gamma        |  `$ 7.89` |
| Paragraph   | Delta        | `$10.11` |
| Paragraph   | Zeta        | `$12.13` |
| Paragraph   | Eta, but this line is long enough to force the max-width to extend well belong a single line when at max width        | `$14.15` |

---

Definition List
: A list of definitions

So wait what?
: Yes, definition list. Not sure why we'd want to use one here, but this is what we're doing now.
: Apparently, you can also do multiple definitions? This can get messy quick...

---

###### H6. Here we go

Duis erat urna, placerat quis justo eu, feugiat placerat nibh. Quisque turpis tellus, viverra a pharetra eu, vestibulum vitae quam. Mauris hendrerit quam ut est gravida, vestibulum elementum erat fringilla. Etiam ornare massa nisl, quis ornare diam dapibus ut. Curabitur et tempus nibh.[^first-last] Ut et luctus quam. Etiam ut quam suscipit, rhoncus velit nec, varius arcu. Nullam vel commodo tortor, at porttitor justo. Maecenas imperdiet, enim non molestie tincidunt, lectus mauris congue neque, et gravida leo sem sit amet velit. Proin ultrices ante posuere odio elementum pharetra. Donec lectus dolor, finibus sit amet convallis id, fermentum eget sem. Pellentesque pretium arcu sed massa tempus sodales. Pellentesque aliquet mollis metus, ac sodales sapien mollis ornare. Aenean elementum dui ut tortor laoreet pellentesque. Curabitur pharetra vitae massa et vehicula. Sed vitae lacus nec enim malesuada scelerisque non vel est.[^and-another]

Aliquam eu dui porta, blandit metus sit amet, fringilla purus. Morbi rutrum purus leo, nec dapibus nisi vehicula non. Curabitur bibendum, elit a dictum vehicula, eros diam cursus quam, sit amet porttitor lectus ante ac magna. Nullam mattis justo quis nibh consequat accumsan. Aenean mauris nibh, porttitor sit amet consequat eu, pulvinar non mauris. Aliquam nec lobortis eros. Phasellus imperdiet velit non velit mollis porta. In ut varius lorem. Fusce nec condimentum erat. Fusce efficitur neque a urna tempor, a bibendum orci egestas. Aliquam vel nisl ac arcu scelerisque porta eget a purus. Sed maximus metus eu rhoncus scelerisque. Nam ut velit nunc.

[^3]: Foobar

[^first-last]: Honestly, I wrote this portion last, but since I make reference to it throughout the code, it's best to start here.

[^and-another]: Oh hey another footnote!