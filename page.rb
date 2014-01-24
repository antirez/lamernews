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

class HTMLGen
    @@newlinetags = %w{html body div br ul hr title link head fieldset label legend option table li select td tr meta}
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

    def _header()
        application_header
    end

    def _footer()
        application_footer
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
