# Copyright 2011 Salvatore Sanfilippo. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY SALVATORE SANFILIPPO ''AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL SALVATORE SANFILIPPO OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of Salvatore Sanfilippo.

require 'cgi'
require 'erb'

class HTMLGen
    @@newlinetags = %w{html body div br ul hr title link head filedset label legend option table li select td tr meta}
    @@metatags = {
        "js" => {"tag"=>"script"},
        "inputtext" => {"tag"=>"input","type"=>"text"},
        "inputpass" => {"tag"=>"input","type"=>"password"},
        "inputfile" => {"tag"=>"input","type"=>"file"},
        "inputhidden" => {"tag"=>"input","type"=>"hidden"},
        "button" => {"tag"=>"input","type"=>"button"},
        "submit" => {"tag"=>"input","type"=>"submit"},
        "checkbox" => {"tag"=>"input","type"=>"checkbox"},
        "radio" => {"tag"=>"input","type"=>"radio"}
    }

    def initialize
        @title = "Default title"
    end

    def method_missing(m, attrhash={})
        content = block_given? ? yield.to_s : nil
        gentag(m,attrhash,content)
    end

    def gentag(m, attrhash, content)
        m = m.to_s
        if (@@metatags[m])
            origm = m
            m = @@metatags[m]['tag']
            attrhash = @@metatags[origm].merge(attrhash)
            attrhash.delete('tag')
            if attrhash['!append']
                content += attrhash['!append']
                attrhash.delete('!append')
            end
        end
        nl = (@@newlinetags.include? m) ? "\n" : ""
        attribs = ""
        if attrhash.length != 0
            attrhash.each_pair {|k,v|
                attribs += " #{k}=\"#{entities(v.to_s)}\"" if v
            }
        end
        if content
            content += nl if content[-1] != 10
            content = nl+content if content[0] != 10
            html = "<#{m}#{attribs}>"+content+"</#{m}>"+nl
        else
            html = "<#{m}#{attribs}>"+nl
        end
        return html
    end

    def list(l)
        self.ul {
            aux = ""
            l.each {|x|
                if block_given?
                    aux += self.li {yield x}
                else
                    aux += self.li {x}
                end
            }
            aux
        }
    end

    def entities(s)
        CGI::escapeHTML(s)
    end

    def unentities(s)
        CGI::unescapeHTML(s)
    end

    def urlencode(s)
        CGI::escape(s)
    end

    def urldecode(s)
        CGI::unescape(s)
    end

    def set_title(t)
        @title = t
    end

    def page()  
        "<!DOCTYPE html>"+
        self.html {
            H.head {
                self.meta(:charset => "utf-8")+
                self.title{H.entities @title}+
                self.meta(:content => :index, :name => :robots)+
                self.meta(:content => "width=device-width, initial-scale=1, maximum-scale=1", :name => :viewport)+
                self.link(:href => "/css/style.css?v=10", :rel => "stylesheet",
                          :type => "text/css")+
                self.link(:href => "/favicon.ico", :rel => "shortcut icon")+
                self.script(:src => "/js/jquery.1.6.4.min.js"){}+
                self.script(:src => "/js/app.js?v=10"){}
            }+
            self.body {
                self.div(:class => "container") {
                    _header+H.div(:id => "content"){yield}+_footer
                }
            }
        }
    end
end

module Lamernews
  ###############################################################################
  # Navigation, header and footer.
  ###############################################################################
  
  # Return the HTML for the 'replies' link in the main navigation bar.
  # The link is not shown at all if the user is not logged in, while
  # it is shown with a badge showing the number of replies for logged in
  # users.
  def self.navbar_replies_link
      return "" if !$user
      count = $user['replies'] || 0
      H.a(:href => "/replies", :class => "replies") {
          "replies"+
          if count.to_i > 0
              H.sup {count}
          else "" end
      }
  end
  
  def self.navbar_admin_link
      return "" if !$user || !user_is_admin?($user)
      H.b {
          H.a(:href => "/admin") {"admin"}
      }
  end

  def self.application_header
    template = './views/header.erb'
    @navitems = [    ["top","/"],
                      ["latest","/latest/0"],
                      ["random","/random"],                    
                      ["submit","/submit"]]
    ERB.new(File.read(template)).result(binding)
  end

  def self.application_footer
    template = './views/footer.erb'
    if $user
        @apisecret = H.script() {
            "var apisecret = '#{$user['apisecret']}';";
        }
    else
        @apisecret = ""
    end
    @links = [
        ["about", "/about"],
        ["source code", "http://github.com/antirez/lamernews"],
        ["rss feed", "/rss"],
        ["twitter", FooterTwitterLink],
        ["google group", FooterGoogleGroupLink]
    ]
    @keyboardnavigation = self.keyboard_nav
    ERB.new(File.read(template)).result(binding)
  end

  def self.keyboard_nav
      if KeyboardNavigation == 1
          keyboardnavigation = H.script() {
              "setKeyboardNavigation();"
          } + " " +
          H.div(:id => "keyboard-help", :style => "display: none;") {
              H.div(:class => "keyboard-help-banner banner-background banner") {
              } + " " +
              H.div(:class => "keyboard-help-banner banner-foreground banner") {
                  H.div(:class => "primary-message") {
                      "Keyboard shortcuts"
                  } + " " +
                  H.div(:class => "secondary-message") {
                      H.div(:class => "key") {
                          "j/k:"
                      } + H.div(:class => "desc") {
                          "next/previous item"
                      } + " " +
                      H.div(:class => "key") {
                          "enter:"
                      } + H.div(:class => "desc") {
                          "open link"
                      } + " " +
                      H.div(:class => "key") {
                          "a/z:"
                      } + H.div(:class => "desc") {
                          "up/down vote item"
                      }
                  }
              }
          }
      else
          keyboardnavigation = ""
      end
  end
end  
