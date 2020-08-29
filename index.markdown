---
layout: default
title: Home
---
<ul>
    {% for post in site.posts %}
<li>
    <a href="{{ post.url }}">{{ post.title }}<span class="post-date" style="display: inline;font-size: 15px"> - {{ post.date | date: "%Y-%m-%d" }}</span></a>
</li>
    {% endfor %}
</ul>
