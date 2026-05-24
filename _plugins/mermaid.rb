# Jekyll Mermaid Plugin
#
# Kramdown 이 ```mermaid 코드 블록을 아래 구조로 변환:
#   <pre><code class="language-mermaid">...</code></pre>
#
# Mermaid.js 가 인식하는 구조로 빌드 완료 후 파일 직접 수정:
#   <pre class="mermaid">...</pre>
#
# :site, :post_write — Jekyll 3/4 모두 지원, 파일 기록 후 실행됨

Jekyll::Hooks.register :site, :post_write do |site|
  pattern = /<pre><code class="language-mermaid">(.*?)<\/code><\/pre>/m

  Dir.glob(File.join(site.dest, '**', '*.html')).each do |file|
    content = File.read(file, encoding: 'utf-8')
    next unless content.match?(pattern)

    modified = content.gsub(pattern) do
      "<pre class=\"mermaid\">#{$1.strip}</pre>"
    end

    File.write(file, modified, encoding: 'utf-8')
  end
end
