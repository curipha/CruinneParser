#!/usr/bin/env ruby
# coding: utf-8

#   ___          _                 ___          Litmus Paper
#  / __|_ _ _  _(_)_ _  _ _  ___  | _ \__ _ _ _ ___ ___ _ _
# | (__| '_| || | | ' \| ' \/ -_) |  _/ _` | '_(_-</ -_) '_|
#  \___|_|  \_,_|_|_||_|_||_\___| |_| \__,_|_| /__/\___|_|

require '../crparser.rb'

class CruinneParserTester < CruinneParser

  # run    : Litmus paper framework {{{
  def run()
    @test_ok = 0
    @test_ng = 0

    @init_head_level = 2  # Fix the setting

    gen = lambda {|arg| generate(arg).gsub(/[\n\r]/, '') }

    msg = [
      'CruinneParser :: self diagnostic...',

      '', ':: General methods',
      tester('escapehtml (Simple)', lambda {|arg| escapehtml(arg) },
             %q!&"'<>!,
             %q!&amp;&quot;&#39;&lt;&gt;!),
      tester('escapehtml (keep space)', lambda {|arg| escapehtml(arg) },
             %Q! &\n" \n'<>\n\n A!,
             %Q! &amp;\n&quot; \n&#39;&lt;&gt;\n\n A!),
      tester('escapehtml (Complex)', lambda {|arg| escapehtml(arg) },
             %q!a&a"a'a<a>aあ!,
             %q!a&amp;a&quot;a&#39;a&lt;a&gt;aあ!),
      tester('urlencode (Not handling characters)', lambda {|arg| urlencode(arg) },
             %q!Lorem_ipsum!,
             %q!Lorem_ipsum!),
      tester('urlencode (White space)', lambda {|arg| urlencode(arg) },
             %Q!a a\r\na\n a!,
             %q!a+a%0D%0Aa%0A+a!),
      tester('urlencode (Complex)', lambda {|arg| urlencode(arg) },
             %q!a&a.a<a>a b!,
             %q!a%26a.a%3Ca%3Ea+b!),
      tester('urlencode (Japanese characters)', lambda {|arg| urlencode(arg) },
             %q!あいうえお!,
             %q!%E3%81%82%E3%81%84%E3%81%86%E3%81%88%E3%81%8A!),
      tester('urlencode (Unicode characters)', lambda {|arg| urlencode(arg) },
             %q!﨑鄧髙!,
             %q!%EF%A8%91%E9%84%A7%E9%AB%99!),
      tester('urlencode (Shift JIS characters w/ 0x5C)', lambda {|arg| urlencode(arg) },
             %q!表竹!,
             %q!%E8%A1%A8%E7%AB%B9!),

      '', ':: Parser',
      tester(%q!Inline decorations (**/__/''/--)!, gen,
             %q!'' -- ** __ A __ ** -- ''!,
             %q!<p><code> <del> <strong> <u> A </u> </strong> </del> </code></p>!), # White space is kept.
      tester(%q!Inline decoration (confusion w/ list '--')!, gen,
             %Q!A\n --A--!, # Put space to the head of line. The space is removed by parser.
             %q!<p>A<del>A</del></p>!),
      tester(%q!Inline decoration (token not closed)!, gen,
             %q!** A!,
             %q!<p>** A</p>!),
      tester(%q!Inline decoration (complex nesting)!, gen,
             %q!** __ A  -- C __ B -- **!,
             %q!<p><strong> <u> A  -- C </u> B -- </strong></p>!),
      tester(%q!Superscript/Subscript (^{}/_{})!, gen,
             %q!A^{ A } A_{ A }!,
             %q!<p>A<sup> A </sup> A<sub> A </sub></p>!), # White space is kept. This is expected.
      tester(%q!Superscript/Subscript (nesting inline decorations)!, gen,
             %q!A^{ **A** } A_{ __A__ }!,
             %q!<p>A<sup> <strong>A</strong> </sup> A<sub> <u>A</u> </sub></p>!),
      tester(%q!Line break (\\\\ + 'LF')!, gen,
             %Q!A\\\\\nA!,
             %q!<p>A<br />A</p>!),
      tester(%q!Line break (\\\\ + 'CR')!, gen,
             %Q!A\\\\\rA!,
             %q!<p>A<br />A</p>!),
      tester(%q!Line break (\\\\ + 'CRLF')!, gen,
             %Q!A\\\\\r\nA!,
             %q!<p>A<br />A</p>!),
      tester(%q!Line break (\\\\ + ' ')!, gen,
             %q!A\\\\ A!,
             %q!<p>A<br />A</p>!),
      tester(%q!Line break (no trailing spaces)!, gen,
             %q!A\\\\A!,
             %q!<p>A\\\\A</p>!),
      tester(%q!Line break (complex pattern)!, gen,
             %Q!A\\\\\nA\\\\\r\nA\\\\A\n\nA\\\\\nA!,
             %q!<p>A<br />A<br />A\\\\A</p><p>A<br />A</p>!),
      tester(%q!Comments (//)!, gen,
             %Q!// A\n//A!,
             %q!!),
      tester(%q!Comments (trailing normal line)!, gen,
             %Q!// A\nA!,
             %q!<p>A</p>!),
      tester(%q!Link ([[/]] w/ anchor text)!, gen,
             %q![[ A : http://www.google.com/ ]]!,
             %q!<p><a href="http://www.google.com/">A</a></p>!),
      tester(%q!Link ([[/]] w/o anchor text)!, gen,
             %q![[ http://www.google.com/ ]]!,
             %q!<p><a href="http://www.google.com/">http://www.google.com/</a></p>!),
      tester(%q!Link (confusion w/ not a link)!, gen,
             %q!between [[ and ]]!,
             %q!<p>between [[ and ]]</p>!),
      tester(%q!Link (include HTML special characters in anchor text)!, gen,
             %q![[A&B<b>C:http://www.google.com/]]!,
             %q!<p><a href="http://www.google.com/">A&amp;B&lt;b&gt;C</a></p>!),
      tester(%q!Link (include HTML special characters in URI)!, gen,
             %q![[http://www.google.com/search?q=text&amp;hl=ja]]!, # URI inputted must already be escaped.
             %q!<p><a href="http://www.google.com/search?q=text&amp;hl=ja">http://www.google.com/search?q=text&amp;hl=ja</a></p>!),
      tester(%q!Link (include HTML special characters in URI w/ anchor text)!, gen,
             %q![[A&B:http://www.google.com/search?q=text&amp;hl=ja]]!, # URI inputted must already be escaped.
             %q!<p><a href="http://www.google.com/search?q=text&amp;hl=ja">A&amp;B</a></p>!),
      tester(%q!Link (include markup token in anchor text)!, gen,
             %q![[**C**:http://www.google.com/]]!,
             %q!<p><a href="http://www.google.com/">**C**</a></p>!),
      tester(%q!Link (include ':' in anchor text)!, gen,
             %q![[a:b:http://www.google.com/]]!,
             %q!<p><a href="http://www.google.com/">a:b</a></p>!),
      tester(%q!Link (broken protocol scheme)!, gen,
             %q![[a:hxxp://www.google.com/]]!,
             %q!<p>[[a:hxxp://www.google.com/]]</p>!),
      tester(%q!Link (https protocol scheme)!, gen,
             %q![[https://www.google.com/]]!,
             %q!<p><a href="https://www.google.com/">https://www.google.com/</a></p>!),
      tester(%q!Link (ftp protocol scheme)!, gen,
             %q![[ftp://ftp.google.com/]]!,
             %q!<p><a href="ftp://ftp.google.com/">ftp://ftp.google.com/</a></p>!),
      tester(%q!Link (surrounded by inline decoration token)!, gen,
             %q!**[[Google:https://www.google.com/]]**!,
             %q!<p><strong><a href="https://www.google.com/">Google</a></strong></p>!),
      tester(%q!Heading (=)!, gen,
             %q!= A!,
             %q!<h2>A</h2>!),
      tester(%q!Heading (==)!, gen,
             %q!==B!,
             %q!<h3>B</h3>!),
      tester(%q!Heading (===)!, gen,
             %q!===  C!,
             %q!<h4>C</h4>!),
      tester(%q!Heading (w/ inline decorations)!, gen,
             %q!==== A **A** [[B:http://www.google.com/]]!,
             %q!<h5>A <strong>A</strong> <a href="http://www.google.com/">B</a></h5>!),
      tester(%q!Paragraph!, gen,
             %Q!A\nB\n\nC\n\n\nD!,
             %q!<p>AB</p><p>C</p><p>D</p>!),
      tester(%q!Blockquote (>)!, gen,
             %Q!>A\n> B\n\n>\n> C!,
             %q!<blockquote><p>AB</p></blockquote><blockquote><p>C</p></blockquote>!),
      tester(%q!Blockquote (w/ inline decorations)!, gen,
             %Q!>A\n> B\n>\n> **C**!,
             %q!<blockquote><p>AB</p><p><strong>C</strong></p></blockquote>!),
      tester(%q!Blockquote (includes block token)!, gen,
             %Q!> **C**\n\n> D\n>=H!,
             %q!<blockquote><p><strong>C</strong></p></blockquote><blockquote><p>D</p><h2>H</h2></blockquote>!),
      tester(%q!Code block (``` w/ language)!, gen,
             %Q!A\n``` LANG\ncode\n```\nC!,
             %q!<p>A</p><pre class="prettyprint"><code class="language-LANG">code</code></pre><p>C</p>!),
      tester(%q!Code block (``` w/o language)!, gen,
             %Q!```\nif answer = 1\n  echo "YES"\nend\n```!,
             %q!<pre class="prettyprint"><code>if answer = 1  echo &quot;YES&quot;end</code></pre>!),
      tester(%q!Code block (token not closed)!, gen,
             %Q!A\n```\ncode!,
             %q!<p>A</p><pre class="prettyprint"><code>code</code></pre>!),
      tester(%q!Code block (include HTML special characters)!, gen,
             %Q!```\nT<b>\n&\n```!,
             %q!<pre class="prettyprint"><code>T&lt;b&gt;&amp;</code></pre>!),
      tester(%q!Code block (include markup token)!, gen,
             %Q!```\n**B**\n __U__\n```!,
             %q!<pre class="prettyprint"><code>**B** __U__</code></pre>!),
      tester(%q!Code block (include '```')!, gen,
             %Q!```\nB\n ```\n```!, # ' ' + ```
             %q!<pre class="prettyprint"><code>B ```</code></pre>!),
      tester(%q!Code block (confusion w/ inline object)!, gen,
             %q!a```a!,
             %q!<p>a```a</p>!),
      tester(%q!Unordered list (-)!, gen,
             %Q!-A\n- B\n-C \n\n-D!,
             %q!<ul><li>A</li><li>B</li><li>C</li></ul><ul><li>D</li></ul>!),
      tester(%q!Unordered list (nested)!, gen,
             %Q!-A\n--B\n-C!,
             %q!<ul><li>A<ul><li>B</li></ul></li><li>C</li></ul>!),
      tester(%q!Unordered list (w/ inline decorations)!, gen,
             %Q!-[[a:http://www.google.com/]]\n- **B**!,
             %q!<ul><li><a href="http://www.google.com/">a</a></li><li><strong>B</strong></li></ul>!),
      tester(%q!Ordered list (+)!, gen,
             %Q!+A\n+ B\n+C \n\n+D!,
             %q!<ol><li>A</li><li>B</li><li>C</li></ol><ol><li>D</li></ol>!),
      tester(%q!Ordered list (nested)!, gen,
             %Q!+A\n++B\n+C!,
             %q!<ol><li>A<ol><li>B</li></ol></li><li>C</li></ol>!),
      tester(%q!Ordered list (w/ inline decorations)!, gen,
             %Q!+[[a:http://www.google.com/]]\n+ **B**!,
             %q!<ol><li><a href="http://www.google.com/">a</a></li><li><strong>B</strong></li></ol>!),
      tester(%q!Combinated list (+/-)!, gen,
             %Q!-A\n++B\n---C\n++++D!,
             %q!<ul><li>A<ol><li>B<ul><li>C<ol><li>D</li></ol></li></ul></li></ol></li></ul>!),
      tester(%q!Definition list (:/|)!, gen,
             %Q!: A | B\n:C|D\n\n:E|F!,
             %q!<dl><dt>A</dt><dd>B</dd><dt>C</dt><dd>D</dd></dl><dl><dt>E</dt><dd>F</dd></dl>!),
      tester(%q!Definition list (w/o description)!, gen,
             %Q!:A\n: A | !,
             %q!<dl><dt>A</dt><dt>A</dt></dl>!),
      tester(%q!Definition list (w/o title)!, gen,
             %Q!:|B\n: | B!,
             %q!<dl><dd>B</dd><dd>B</dd></dl>!),
      tester(%q!Definition list (complex pattern)!, gen,
             %Q!:A\n\n: A | \n:|B\n: | B!,
             %q!<dl><dt>A</dt></dl><dl><dt>A</dt><dd>B</dd><dd>B</dd></dl>!),
      tester(%q!Definition list (w/ inline decorations)!, gen,
             %Q!: __A__ | --B--!,
             %q!<dl><dt><u>A</u></dt><dd><del>B</del></dd></dl>!),
      tester(%q!Table ($)!, gen,
             %Q!$A$B $ C$!,
             %q!<table><tr><th>A</th><th>B</th><th>C</th></tr></table>!),
      tester(%q!Table (|)!, gen,
             %Q!|A|B | C|!,
             %q!<table><tr><td>A</td><td>B</td><td>C</td></tr></table>!),
      tester(%q!Table ($ w/ colspan)!, gen,
             %Q!$A$B$C$\n$$E$F$!,
             %q!<table><tr><th>A</th><th>B</th><th>C</th></tr><tr><th colspan="2">E</th><th>F</th></tr></table>!),
      tester(%q!Table (| w/ colspan)!, gen,
             %Q!|A|B|C|\n||E|F|!,
             %q!<table><tr><td>A</td><td>B</td><td>C</td></tr><tr><td colspan="2">E</td><td>F</td></tr></table>!),
      tester(%q!Table ($ w/ inline decorations)!, gen,
             %Q!$ **A** $[[B:http://www.google.com/]]$!,
             %q!<table><tr><th><strong>A</strong></th><th><a href="http://www.google.com/">B</a></th></tr></table>!),
      tester(%q!Table (| w/ inline decorations)!, gen,
             %Q!| **A** |[[B:http://www.google.com/]]|!,
             %q!<table><tr><td><strong>A</strong></td><td><a href="http://www.google.com/">B</a></td></tr></table>!),
      tester(%q!Table (complex $/|)!, gen,
             %Q!|A$B$C$\n$D|E|F|\n$G||H|!,
             %q!<table><tr><td>A</td><th>B</th><th>C</th></tr><tr><th>D</th><td>E</td><td>F</td></tr><tr><th>G</th><td colspan="2">H</td></tr></table>!),
      tester(%q!Table (confusion w/ definition list)!, gen,
             %Q!|:A| :B|!,
             %q!<table><tr><td>:A</td><td>:B</td></tr></table>!),
      tester(%q!Table (complex colspan)!, gen,
             %Q!$$$A$\n$ $ $C$\n|||D|\n| | | E|!,
             %q!<table><tr><th colspan="3">A</th></tr><tr><th></th><th></th><th>C</th></tr><tr><td colspan="3">D</td></tr><tr><td></td><td></td><td>E</td></tr></table>!),
      tester(%q!Horizonal line (----)!, gen,
             %q!----!,
             %q!<hr />!),
      tester(%q!Horizonal line (w/ trailing garbage)!, gen,
             %Q!-----\n---- a!,
             %q!<hr /><hr />!),
      tester(%q!Horizonal line (confusion w/ unordered list)!, gen,
             %Q!----\n---\n----!,
             %q!<hr /><ul><ul><ul><li><ul><li></li></ul></li></ul></ul></ul>!),
      tester(%q!Image ({{/}})!, gen,
             %q!{{ aa : /path/to/img.png : 120x40}}!,
             %q!<p><img src="/path/to/img.png" alt="aa" width="120" height="40" /></p>!),
      tester(%q!Image (w/o size)!, gen,
             %q!{{aa:/path/to/img.png}}!,
             %q!<p><img src="/path/to/img.png" alt="aa" /></p>!),
      tester(%q!Image (w/o text)!, gen,
             %q!{{/path/to/img.png}}!,
             %q!<p>{{/path/to/img.png}}</p>!),
      tester(%q!Image (include ':' in text)!, gen,
             %q!{{a:a:/path/to/img.png}}!,
             %q!<p><img src="/path/to/img.png" alt="a:a" /></p>!),
      tester(%q!Image (path not starting w/ '/')!, gen,
             %q!{{aa:path/to/img.png}}!,
             %q!<p>{{aa:path/to/img.png}}</p>!),
      tester(%q!Image (surrounded by inline decoration token)!, gen,
             %q!**{{a:/path/to/img.png}}**!,
             %q!<p><strong><img src="/path/to/img.png" alt="a" /></strong></p>!),
      tester(%q!Image (line up)!, gen,
             %q!a{{a:/path/to/img.png}}b{{a:/path/to/img.png}}c!,
             %q!<p>a<img src="/path/to/img.png" alt="a" />b<img src="/path/to/img.png" alt="a" />c</p>!),
      tester(%q!Bad pattern: Heading (very high level)!, gen,
             %q!======= A!,
             %q!<h8>A</h8>!), # <H8> is not exists
      tester(%q!Bad pattern: List (starting 2nd level)!, gen,
             %q!-- A!,
             %q!<ul><ul><li>A</li></ul></ul>!),
      tester(%q!Bad pattern: List (skipping the level)!, gen,
             %Q!+A\n---B\n+++++C!,
             %q!<ol><li>A<ul><ul><li>B<ol><ol><li>C</li></ol></ol></li></ul></ul></li></ol>!),
      tester(%q!Bad pattern: List (w/ '--' decoration)!, gen,
             %Q!- A\n- --B--\n- A--C--!,
             %q!<ul><li>A<ul><ul><li>B--</li></ul></ul></li><li>A<del>C</del></li></ul>!),
      tester(%q!Bad pattern: Combinated list (w/ both indicator exists at same level)!, gen,
             %Q!-A\n++B\n--C!,
             %q!<ul><li>A<ol><li>B</li><li>C</li></ol></li></ul>!),
      tester(%q!Bad pattern: Table (w/ much or less columns)!, gen,
             %Q!|A|B|C|\n|D|E|\n|F|G|H|I|!,
             %q!<table><tr><td>A</td><td>B</td><td>C</td></tr><tr><td>D</td><td>E</td></tr><tr><td>F</td><td>G</td><td>H</td><td>I</td></tr></table>!),
      tester(%q!Bad pattern: Table (w/o last close token)!, gen,
             %Q!|A|B|C|\n|D\n\n|E!,
             %q!<table><tr><td>A</td><td>B</td><td>C</td></tr></table><table></table>!),

#      tester(%q!Description!, gen,
#             %q!Input!,  # If inputting string has a "\n", use "%Q!" instead of "%q!".
#             %q!Output!),

      '',
      "Result: \033[1;32mOK\033[0m = #{@test_ok}, \033[1;31mNG\033[0m = #{@test_ng}"
    ]

    msg << "\n\033[1mEVERYTHING IS FINE!!\033[0m" if @test_ng == 0 && @test_ok > 0
    $stderr.puts msg
  end
  #}}}

  private

  # tester : Testing method {{{
  def tester(desc, func, arg, expected)
    actual = func.call(arg)

    if actual === expected
      @test_ok += 1

      msg = <<"OK"
[ \033[0;32mOK\033[0m ] #{desc}
OK
    else
      @test_ng += 1

      expected = "\n" + expected if expected.include?("\n")
      actual   = "\n" + actual if actual.include?("\n")

      msg = <<"NG"
[ \033[1;31mNG\033[0m ] #{desc}
       * Input      : #{arg.inspect}
       * Output
         - Expected : #{expected}
         - Actual   : #{actual}
NG
    end
  end
  #}}}

end


CruinneParserTester.new.run

=begin
if File.exists?('./format.txt')
  puts 'Starting sample output...'

  cp = CruinneParser.new

  print cp.read('format.txt')
  cp.report

  puts
end
=end

