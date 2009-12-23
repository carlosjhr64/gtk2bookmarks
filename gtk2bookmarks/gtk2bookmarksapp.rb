require 'timeout'
require 'net/http'
require 'gtk2applib/gtk2_app_widgets_entry'
require 'gtk2applib/gtk2_app_widgets_button'
require 'gtk2bookmarks/bookmarks'

class Gtk2BookmarksApp
  include Configuration

  def head(bookmark)
    if bookmark[Bookmarks::LINK] =~ /^http:\/\/([^\/]+)(\/.*)?$/ then
      begin
        host = $1
        path = ($2)? $2: '/'
        response = nil
        Timeout::timeout(HTTP_TIMEOUT) {
          Net::HTTP.start(host, 80) {|http|
            response = http.head(path)
            bookmark[Bookmarks::RESPONSE] = (response.message=~/Not\s+Found/i)? nil: response.message
          }
        }
      rescue Exception
        puts_bang!
        bookmark[Bookmarks::RESPONSE] = nil
      end
      $stderr.puts bookmark[Bookmarks::RESPONSE] if $trace
    end
  end

  def initialize(window)
    # Aggregate available boomarks
    bookmarks = Bookmarks.new(BOOKMARK_FILES)

    # Delete links to missing files
    bookmarks.delete_if {|bookmark|
      delete = false
      if bookmark[Bookmarks::LINK] =~ /^file:\/\/(.*)$/ then
        delete = true if !File.exist?($1)
      end
      delete
    }

    vbox = Gtk::VBox.new
    scrolled = Gtk2App::ScrolledWindow.new(vbox)
    window.add(scrolled)

    entry_text = ''
    bookmarks.sort!(entry_text)

    entry = Gtk2App::Entry.new('',vbox)
    LIST_SIZE.times do |i|
      break if !bookmarks[i]
      hbox = Gtk::HBox.new
      button = Gtk2App::Button.new(IMAGE[:go],hbox){|bookmark|
	system("#{APP[:browser]} '#{bookmark[Bookmarks::LINK]}' &")
        head(bookmark)
      }
      button.value = bookmarks[i]
      label = bookmarks[i][Bookmarks::TITLE] + ' (' + bookmarks[i][Bookmarks::SUBJECT].join(', ') + ')' 
      label = Gtk2App::Label.new(label,hbox,{:wrap=>false})
      Gtk2App.pack(hbox,vbox)
    end

    relist = proc {
      entry_text = entry.text
      bookmarks.sort!(entry_text)
      LIST_SIZE.times do |i|
        hbox	= vbox.children[i+1]
        hbox.children[0].value = bookmarks[i]
        hbox.children[1].text = bookmarks[i][Bookmarks::TITLE]  + ' (' + bookmarks[i][Bookmarks::SUBJECT].join(', ') + ')'
      end
    }
    entry.signal_connect('activate'){ relist.call }
  end
end
