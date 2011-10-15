require 'cgi'

class HTMLGen
    @@newlinetags = %w{html body div br ul hr title link head filedset label legend option table li select td tr meta}
    @@metatags = {
        "js" => {"tag"=>"script","type"=>"text/javascript"},
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
                self.title{H.entities @title}+
                self.meta(:charset => :utf8)+
                self.link(:href => "/css/style.css", :rel => "stylesheet",
                          :type => "text/css")+
                self.link(:href => "/images/favicon.png", :rel => "shortcut icon")+
                self.script(:src =>
                    "http://ajax.googleapis.com/ajax/libs/jquery/1.4/jquery.min.js"){}+
                self.script(:src => "/js/app.js"){}
            }+
            self.body {
                self.div(:class => "container") {
                    _header+H.content{yield}+_footer
                }
            }
        }
    end
end  
