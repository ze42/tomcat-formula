{% from "tomcat/map.jinja" import tomcat with context %}
{% set tomcat_java_home = tomcat.java_home %}
{% set tomcat_java_opts = tomcat.java_opts %}

tomcat ensure keg is linked on macos if already installed:
  cmd.run:
    - names:
      - /usr/local/bin/brew unlink tomcat || True
      - /usr/local/bin/brew link tomcat || True
    - runas: {{ tomcat.user }}
    - require_in:
      - pkg: tomcat package installed and service running
    - onlyif:
      - {{ grains.os == 'MacOS' }}
      - test -d /usr/local/Cellar/tomcat

tomcat package installed and service running:
  pkg.installed:
    - name: {{ tomcat.pkg }}
    {% if tomcat.version is defined %}
    - version: {{ tomcat.version }}
    {% endif %}
  {%- if grains.os == 'MacOS' %}
   #Register as Launchd LaunchAgent for users
    - require_in:
      - file: tomcat package installed and service running
  cmd.run:
    - names:
      - /usr/local/bin/brew unlink tomcat || True
      - /usr/local/bin/brew link tomcat || True
    - runas: {{ tomcat.user }}
    - unless: test -f /usr/local/opt/tomcat/{{ tomcat.service }}.plist
  file.managed:
    - name: /Library/LaunchAgents/{{ tomcat.service }}.plist
    - source: /usr/local/opt/tomcat/{{ tomcat.service }}.plist
    - group: wheel
    - onlyif: test -f /usr/local/opt/tomcat/{{ tomcat.service }}.plist
    - require_in:
      - cmd: tomcat package installed and service running
  {% endif %}
  service.running:
    - name: {{ tomcat.service }}
    - enable: {{ tomcat.service_enabled }}
    - unless:
      - {{ grains.os == 'MacOS' }}
      - {{ tomcat.ver|int < 9 }}       ####there is no macOS plist file for tomcat9
    - watch:
      - pkg: tomcat package installed and service running
# To install haveged on centos you need the EPEL repository. There is no haveged in MacOS
{% if tomcat.with_haveged and grains.os != 'MacOS' %}
  require:
    - pkg: tomcat haveged package installed and service running

tomcat haveged package installed and service running:
  pkg.installed:
    - name: haveged
  service.running:
    - enable: {{ tomcat.haveged_enabled }}
    - watch:
       - pkg: tomcat haveged package installed and service running
{% endif %}

tomcat init whats tomcat status:
  cmd.run:
  - name: systemctl status {{ tomcat.service }}
  - onfail:
    - service: tomcat package installed and service running

