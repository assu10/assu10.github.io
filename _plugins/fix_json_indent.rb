require 'json'
require 'rouge'

# Rouge's JSON lexer drops leading-whitespace tokens, stripping indentation.
# This hook finds rendered JSON blocks, re-parses the content, pretty-prints it,
# then re-highlights so the indentation is preserved in the final HTML.
Jekyll::Hooks.register [:pages, :posts], :post_render do |doc|
  doc.output = doc.output.gsub(
    /(<div class="language-json highlighter-rouge"><div class="highlight"><pre class="highlight"><code>)(.*?)(<\/code><\/pre>\s*<\/div>\s*<\/div>)/m
  ) do
    prefix  = $1
    content = $2
    suffix  = $3

    # Strip HTML tags to recover plain text
    text = content
      .gsub(/<[^>]+>/, '')
      .gsub('&amp;',  '&')
      .gsub('&lt;',   '<')
      .gsub('&gt;',   '>')
      .gsub('&quot;', '"')
      .gsub('&#39;',  "'")

    begin
      parsed    = JSON.parse(text.strip)
      formatted = JSON.pretty_generate(parsed)
      formatter = Rouge::Formatters::HTML.new
      lexer     = Rouge::Lexers::JSON.new
      highlighted = formatter.format(lexer.lex(formatted))
      prefix + highlighted + suffix
    rescue
      # Leave unchanged if JSON is invalid or not parseable
      prefix + content + suffix
    end
  end
end
