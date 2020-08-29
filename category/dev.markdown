---
layout: page
title: DEV
menu: true
permalink: /dev/
---

<ul>
    {% for post in site.posts %}
        {% if post.categories == "dev" %}
            <li>
                <a href="{{ post.url }}">{{ post.title }} {{post.categories}} </a>
            </li>
        {% endif %}
    {% endfor %}
</ul>

