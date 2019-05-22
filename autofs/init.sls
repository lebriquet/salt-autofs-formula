# vim: sts=2 ts=2 sw=2 et ai
{% from "autofs/map.jinja" import autofs with context %}

autofs__pkg_autofs:
  pkg.installed:
    - name: autofs
{% if autofs.slsrequires is defined and autofs.slsrequires %}
    - require:
{% for slsrequire in autofs.slsrequires %}
      - {{slsrequire}}
{% endfor %}
{% endif %}
    - pkgs: {{autofs.autofspackages}}

autofs__file_/etc/auto.master.d:
  file.directory:
    - name: /etc/auto.master.d
    - user: root
    - group: root
    - mode: 0755
    - require:
      - pkg: autofs__pkg_autofs
    - watch_in:
      - service: autofs__service_autofs


autofs__file_/etc/auto.master:
  file.managed:
    - name: /etc/auto.master
    - user: root
    - group: root
    - mode: 0644
    - contents: "+dir:/etc/auto.master.d"
    - require:
      - pkg: autofs__pkg_autofs
      - file: autofs__file_/etc/auto.master.d
    - watch_in:
      - service: autofs__service_autofs


{% if autofs.maps is defined and autofs.maps %}
{% for autofsmap, autofsmap_data in autofs.maps.items() %}
autofs__file_/etc/auto.master.d/{{autofsmap}}.autofs:
  file.managed:
    - name: /etc/auto.master.d/{{autofsmap}}.autofs
    - template: jinja
    - user: root
    - group: root
    - mode: 0644
    - contents: "{{autofsmap_data.mount}} /etc/auto.{{autofsmap}} --timeout=0"
    - contents_newline: True
    - require:
      - pkg: autofs__pkg_autofs
      - file: autofs__file_/etc/auto.master
      - file: autofs__file_/etc/auto.master.d
    - watch_in:
      - service: autofs__service_autofs

{% if autofsmap_data.credentials is defined %}
{% set opt_str = autofsmap_data.opts ~ ',credentials=/root/.autofs-' ~ autofsmap %}
autofs__credentials_/root/.autofs-{{ autofsmap }}:
  file.managed:
    - name: /root/.autofs-{{ autofsmap }}
    - user: root
    - group: root
    - mode: 0600
    - contents: |
        {% for key, value in autofsmap_data.credentials.items() -%}
        {{ key }}={{ value }}
        {% endfor %}
{% else %}
{% set opt_str = autofsmap_data.opts %}
{% endif %}
autofs__file_/etc/auto.{{autofsmap}}:
  file.managed:
    - name: /etc/auto.{{autofsmap}}
    - contents: |
        {% for entity, entity_data in autofsmap_data.entities.items() -%}
        {%- if entity_data.opts is defined -%}{%- set opt_str = opt_str~','~entity_data.opts -%}{%- endif -%}
        {{ [entity, opt_str, entity_data.source] | join(' ') }}
        {% endfor %}
    - require:
      - pkg: autofs__pkg_autofs
      - file: autofs__file_/etc/auto.master
      - file: autofs__file_/etc/auto.master.d
    - watch_in:
      - service: autofs__service_autofs
{% endfor %}
{% endif %}

autofs__service_autofs:
  service.running:
    - name: autofs
    - reload: True
    - enable: true
    - require:
      - pkg: autofs__pkg_autofs
    - watch: 
      - file: autofs__file_/etc/auto.*