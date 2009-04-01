# $Date: 2009/03/31 23:36:30 $
require 'lib/bookmarks'
require 'net/http'
require 'timeout'

class MyButton < Gtk::Button
  attr_accessor :value
  def initialize(go)
    super()
    self.image = Gtk::Image.new(go)
    @value = nil
    self.signal_connect('clicked'){ system("#{Configuration::APP[:browser]} '#{@value}' &") if @value }
  end
end

class MyLabel < Gtk::Label
  def value=(txt)
    self.text = txt
    self.modify_font(Configuration::FONT[:normal])
  end
end


class Gtk2BookmarksApp
  def initialize(window)
    entries = Bookmarks.new(Configuration::BOOKMARK_FILES)
    
    entries.delete_if {|entry|
      delete = false
      if entry[Bookmarks::LINK] =~ /^file:\/\/(.*)$/ then
        delete = true if !File.exist?($1)
      end
      delete
    }

    scrolled = Gtk::ScrolledWindow.new
    window.add(scrolled)
    vbox = Gtk::VBox.new
    scrolled.add_with_viewport( vbox )

    entry_text = ''
    entries.sort!(entry_text)

    th_response =  Thread.new {
      entries.each {|entry|
        if entry[Bookmarks::LINK] =~ /^http:\/\/([^\/]+)(\/.*)?$/ then
          begin
            host = $1
            path = ($2)? $2: '/'
            response = nil
            Timeout::timeout(3) {
              Net::HTTP.start(host, 80) {|http|
                response = http.head(path)
                entry[Bookmarks::RESPONSE] = (response.message=~/Not\s+Found/i)? nil: response.message
              }
            }
          rescue Exception
            entry[Bookmarks::RESPONSE] = nil
          end
          $stderr.puts entry[Bookmarks::RESPONSE] if $trace
        end
      }
    }

    entry = Gtk::Entry.new
    entry.modify_font(Configuration::FONT[:normal])
    vbox.pack_start(entry, false, false, Configuration::GUI[:padding])
    Configuration::LIST_SIZE.times do |i|
      break if !entries[i]
      hbox = Gtk::HBox.new
      button = MyButton.new(Configuration::IMAGE[:go])
      button.value = entries[i][Bookmarks::LINK]
      hbox.pack_start(button, false, false, Configuration::GUI[:padding])
      label = MyLabel.new
      label.value = entries[i][Bookmarks::TITLE] + ' (' + entries[i][Bookmarks::SUBJECT].join(', ') + ')' 
      hbox.pack_start(label, false, false, Configuration::GUI[:padding])
      vbox.pack_start(hbox, false, false, Configuration::GUI[:padding])
    end

    th_list = Thread.new {
      while window do
        begin
          if !(entry_text == entry.text) then
            entry_text = entry.text
            entries.sort!(entry_text)
            Configuration::LIST_SIZE.times do |i|
              hbox	= vbox.children[i+1]
              hbox.children[0].value = entries[i][Bookmarks::LINK]
              hbox.children[1].value = entries[i][Bookmarks::TITLE]  + ' (' + entries[i][Bookmarks::SUBJECT].join(', ') + ')'
            end
          end
          sleep(Configuration::SLEEP[:normal])
        rescue Exception
          puts_bang!
        end
      end
    }
    window.signal_connect('destroy'){
      th_response.kill if th_response && th_response.alive?
      th_list.kill if th_list && th_list.alive?
    }
  end
end
