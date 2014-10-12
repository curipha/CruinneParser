#!/usr/bin/env ruby
#   ___          _                 ___
#  / __|_ _ _  _(_)_ _  _ _  ___  | _ \__ _ _ _ ___ ___ _ _
# | (__| '_| || | | ' \| ' \/ -_) |  _/ _` | '_(_-</ -_) '_|
#  \___|_|  \_,_|_|_||_|_||_\___| |_| \__,_|_| /__/\___|_|

require 'cgi/util'

class CruinneParser

  # initialize    : Constructor {{{
  def initialize
    # Preferences
    @init_head_level = 2 # Initialize header level

    # Class variables
    @log = []         # Log record
    @inline_ep = nil  # In-line elements parser (Regexp)
  end
  #}}}

  # escapehtml    : Convert special characters to HTML entities {{{
  def escapehtml(str)
    return CGI.escapeHTML(str)
  end
  #}}}
  # urlencode     : Get a URL-encoded string {{{
  def urlencode(str)
    return CGI.escape(str)
  end
  #}}}

  # generate      : HTML Generator {{{
  def generate(src)
    lines = src.strip.split(/\r?\n/).map {|l| l.chomp } # Only chomp, Not strip!
    return parse_block(lines).join("\n")
  end
  #}}}
  # read          : Generate from file {{{
  def read(file)
    unless File.exists?(file)
      err 'File not found!'
      return ''
    end

    buf = ''
    File.open(file, 'r') {|fp|
      fp.flock(File::LOCK_SH)
      buf = generate(fp.read)
    }

    return buf
  end
  #}}}

  # report        : Log viewer {{{
  def report
    return if @log === []

    @log.each {|v|
      case v['level']
      when :info then l = 'INFO'
      when :warn then l = 'WARNING'
      when :err  then l = 'ERROR'
      else            l = 'N/A'
      end

      msg  = "[#{Time.at(v['time']).strftime("%Y-%m-%d %H:%M:%S")}.#{v['nsec'].to_s}]"
      msg += " #{l.ljust(7)} : #{v['msg']} (#{v['where']})"

      $stderr.puts msg
    }
  end
  #}}}

  private

  # parse_block   : Parse block elements (Top level parser) {{{
  def parse_block(lines)
    @inline_ep = nil
    buf = []

    while lines.first
      case lines.first
      when ''       # Blank line
        lines.shift
      when /\A\/\// # Comment line
        lines.shift
      when /\A----/ # Horizontal bar
        lines.shift
        buf.push '<hr />'
      when /\A=/   # Headings
        buf.push parse_h(lines.shift)
      when /\A```/  # Code block
        lang = lines.first.sub(/\A```/, '')
        buf.push parse_pre(get_block2(lines, /\A```\s*/), lang)
      when /\A>/    # Blockquote
        buf.push parse_quote(get_block(lines, /\A>\s*/))
      when /\A-/    # Unordered list
        buf.push parse_list('ul', get_block(lines, /\A[\+-]/))
      when /\A\+/   # Ordered list
        buf.push parse_list('ol', get_block(lines, /\A[\+-]/))
      when /\A:/    # Definition list
        buf.push parse_dl(get_block(lines, /\A:/))
      when /\A[|$]/ # Table
        buf.push parse_table(get_block(lines, /\A[|$]/, false))
      else          # Paragraph
        buf.push parse_p(get_block(lines, /\A(?![=>\-+:|$]|\/\/|----|```|\z)/))
      end
    end

    return buf
  end
  #}}}
  # parse_inline  : Parse in-line elements {{{
  def parse_inline(line)
    # use reluctant quantifier "+?" and un-captured group "(?:pattern)"
    @inline_ep ||= %r!
        \[\[(?:(.+?):)?\s*((?:https?|ftp)://\S+?)\s*\]\]      # $1: Anchor text, $2: URI
      | \{\{\s*(.+?):\s*(/\S+?)\s*(?::\s*(\d+)x(\d+))?\s*\}\} # $3: Text, $4: Src, $5: Width, $6: Height
      | \*\*(.+?)\*\*     # $7:  Bold
      | __(.+?)__         # $8:  Underline
      | ''(.+?)''         # $9:  Monospace
      | --(.+?)--         # $10: Line through
      | \^\{(.+?)\}       # $11: Superscript
      | _\{(.+?)\}        # $12: Subscript
      | (\\\\(?:\s|$))    # $13: Line break
      | ([&"'<>])         # $14: HTML escape characters (must put in last)
      !xu

    return line.gsub(@inline_ep) {
      case
      when uri   = $2  then create_anchor(uri, $1)
      when img   = $4  then create_img(img, $3, $5, $6)
      when bold  = $7  then create_tag(bold, 'strong')
      when uline = $8  then create_tag(uline, 'u')
      when mono  = $9  then create_tag(mono, 'code')
      when lthr  = $10 then create_tag(lthr, 'del')
      when sup   = $11 then create_tag(sup, 'sup')
      when sub   = $12 then create_tag(sub, 'sub')
      when         $13 then '<br />'
      when char  = $14 then escapehtml(char)
      else
        warn 'Failed in-line element parsing.'
      end
    }
  end
  #}}}

  # parse_h       : Parse headings <h1>, <h2>, <h3>, ... {{{
  def parse_h(line)
    level = @init_head_level + line.slice(/\A\=+/).length - 1

    if (level < 1 || level > 6)
      warn "Heading level (#{level}) is out of range."
    end

    return %Q!<h#{level}>#{parse_inline(line.sub(/\A\=+/, '').strip)}</h#{level}>!
  end
  #}}}
  # parse_p       : Parse paragraphs <p> {{{
  def parse_p(lines)
    parsedlines = lines.map {|l| parse_inline(l) }
    return %Q!<p>#{parsedlines.join("\n")}</p>!
  end
  #}}}
  # parse_quote   : Parse quote blocks <blockquote> {{{
  def parse_quote(lines)
    return %Q!<blockquote>#{parse_block(lines).join("\n")}</blockquote>!
  end
  #}}}
  # parse_pre     : Parse pre (or code) blocks <pre>, <code> {{{
  def parse_pre(lines, lang = nil)
    attr = ((lang.nil? || lang == '') ? '' : %Q! class="language-#{escapehtml(lang).strip}"!)

    escapedlines = lines.map {|l| escapehtml(l) }
    return %Q!<pre class="prettyprint"><code#{attr}>#{escapedlines.join("\n")}</code></pre>!
  end
  #}}}
  # parse_list    : Parse unordered/ordered lists <ul>, <ol> {{{
  def parse_list(type, lines)
    buf = ["<#{type}>"]
    closeli = nil

    until lines.empty?
      case lines.first
      when /\A-/
        if closeli.nil?
          warn 'Unordered list seems to skip over the level(s).'
        end

        buf.push parse_list('ul', get_block(lines, /\A[\+-]/))
      when /\A\+/
        if closeli.nil?
          warn 'Ordered list seems to skip over the level(s).'
        end

        buf.push parse_list('ol', get_block(lines, /\A[\+-]/))
      else
        buf.push closeli unless closeli.nil?
        closeli = '</li>'

        buf.push "<li>#{parse_inline(lines.shift)}"
      end
    end

    buf.push closeli unless closeli.nil?
    closeli = '</li>'

    buf.push "</#{type}>"

    return buf.join("\n")
  end
  #}}}
  # parse_dl      : Parse definition lists <dl> {{{
  def parse_dl(lines)
    buf = ['<dl>']

    lines.each {|l|
      dl = l.split('|', 2).map {|m| m.strip }

      buf.push "<dt>#{parse_inline(dl[0])}</dt>" if (dl[0].is_a?(String) && dl[0] != '')
      buf.push "<dd>#{parse_inline(dl[1])}</dd>" if (dl[1].is_a?(String) && dl[1] != '')
    }

    buf.push '</dl>'

    return buf.join("\n")
  end
  #}}}
  # parse_table   : Parse tables <table> {{{
  def parse_table(lines)
    tokenizedlines = lines.map {|l|
      l.split(/([|$]+)/).map {|m| m.strip }
    }

    buf = ['<table>']

    tokenizedlines.each {|tl|
      if tl.count % 2 != 0
        err 'Table line has a illegal markup. Skip the parsing of this line!!'
        next
      end

      tl.shift  # Drop the first element that must be empty
      tl.pop    # Drop the last element that must be token
      closetd = nil

      buf.push '<tr>'

      until tl.empty?
        case tl.first
        when /\A\$/
          colspan = tl.shift.slice(/\A\$+/).length
          attr = (colspan < 2 ? '' : %Q! colspan="#{escapehtml(colspan.to_s)}"!)

          buf.push "<th#{attr}>"
          closetd = '</th>'
        when /\A\|/
          colspan = tl.shift.slice(/\A\|+/).length
          attr = (colspan < 2 ? '' : %Q! colspan="#{escapehtml(colspan.to_s)}"!)

          buf.push "<td#{attr}>"
          closetd = '</td>'
        else
          buf.push parse_inline(tl.shift)
          buf.push closetd unless closetd.nil?
        end
      end

      buf.push '</tr>'
    }

    buf.push '</table>'

    return buf.join("\n")
  end
  #}}}

  # create_anchor : Create anchor tag {{{
  def create_anchor(uri, text)
    uri_output  = uri.strip
    text_output = (text.nil? ? uri_output : escapehtml(text.strip))

    return %Q!<a href="#{uri_output}">#{text_output}</a>! # URI must already be escaped.
  end
  #}}}
  # create_img    : Create image tag {{{
  def create_img(src, alt, width, height)
    attr = ''

    unless (width.nil? && height.nil?)
      attr = %Q! width="#{escapehtml(width).strip}" height="#{escapehtml(height).strip}"!
    end

    return %Q!<img src="#{escapehtml(src).strip}" alt="#{escapehtml(alt).strip}"#{attr} />!
  end
  #}}}
  # create_tag    : Create inlined tag (for general usage) {{{
  def create_tag(text, tag)
    return "<#{tag}>#{parse_inline(text)}</#{tag}>"
  end
  #}}}

  # get_block     : Get blocks all line has a marker as given {{{
  #   - This method strips the beginning/trailing spaces.
  #   - If strip_marker = true, the marker will be removed.
  def get_block(lines, marker, strip_marker = true)
    buf = []
    until lines.empty?
      break unless marker =~ lines.first

      if strip_marker
        buf.push lines.shift.sub(marker, '').strip
      else
        buf.push lines.shift.strip
      end
    end

    return buf
  end
  #}}}
  # get_block2    : Get blocks surrounded with a marker as given {{{
  #   - This method is never strip the beginning/trailing spaces.
  def get_block2(lines, marker)
    buf = []

    lines.shift # Drop first marker

    until lines.empty?
      break if marker =~ lines.first
      buf.push lines.shift  # not strip here !
    end

    lines.shift # Drop last marker

    return buf
  end
  #}}}

  # log           : Logger (Do NOT call directly. Use info/warn/err method instead.) {{{
  def log(msg, level)
    clock = Time.now

    @log << {
      'time'  => clock.to_i,
      'nsec'  => clock.nsec,
      'level' => level,
      'msg'   => msg,
      'where' => caller[1]
    }
  end
  #}}}
  # info          : Log "informational" messages {{{
  def info(msg)
    log(msg, :info)
  end
  #}}}
  # warn          : Log "warning" messages {{{
  def warn(msg)
    log(msg, :warn)
  end
  #}}}
  # err           : Log "error" messages {{{
  def err(msg)
    log(msg, :err)
  end
  #}}}

end

