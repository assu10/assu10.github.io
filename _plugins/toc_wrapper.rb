Jekyll::Hooks.register :pages, :post_render do |page|
  page.output = page.output.gsub(
    /<!-- TOC -->\s*(.*?)\s*<!-- TOC -->/m,
    '<div id="toc-wrapper">\1</div>'
  )
end

Jekyll::Hooks.register :posts, :post_render do |post|
  post.output = post.output.gsub(
    /<!-- TOC -->\s*(.*?)\s*<!-- TOC -->/m,
    '<div id="toc-wrapper">\1</div>'
  )
end
