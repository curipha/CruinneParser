CruinneParser
=======
Cruinne is a plain text formatting syntax parser.

A syntax is designed by me but it is just a mess of ancient wisdoms.
For more details of syntax, see `test/format.txt`.
(It is written in Japanese :D)


How to use
-----
Parse strings:

```ruby
parsed_string = CruinneParser.new.generate('string to parse')
```

Parse file:

```ruby
parsed_string = CruinneParser.new.read('path/to/file')
```


Files
-----

### crparser.rb

Plain text formatting syntax parser.


Thanks
------
A syntax is heavily influenced by Pukiwiki's syntax.
Moreover it also incorporate the characteristics of Markdown, TeX and Dokuwiki's syntax.

The code of parser was created using pukipa.rb as a reference.

I would like to express my deepest gratitude to all forerunners.


Links
-----
- Pukiwiki http://pukiwiki.sourceforge.jp/
- Dokuwiki https://www.dokuwiki.org/
- pukipa.rb http://magazine.rubyist.net/?0010-CodeReview

