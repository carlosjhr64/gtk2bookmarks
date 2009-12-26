require 'timeout'
require 'net/http'
require 'gtk2applib/gtk2_app_widgets_entry'
require 'gtk2applib/gtk2_app_widgets_button'
#require 'gtk2bookmarks/bookmarks'

module Gtk2Bookmarks

def self.conditional_reload(bookmarks)
  if bookmarks.conditional_reload then
    bookmarks.delete_if {|bookmark| (bookmark[Bookmarks::LINK] =~ /^file:\/\/(.*)$/) && !File.exist?($1) }
    Gtk2Bookmarks.dock_menu(bookmarks)
  end
end

def self._append_menum_item_boomkmark(menu_item,links)
  links.each{|bookmark| menu_item.submenu.append_menu_item(bookmark[Bookmarks::TITLE]){ Gtk2Bookmarks.system_call(bookmark) } }
end

def self.dock_menu(bookmarks)
  Gtk2App.clear_dock_menu
  bookmarks.top_tags.each{|tag|
    item = Gtk2App.dock_menu.append_menu_item(tag)
    item.set_submenu( Gtk2App::Menu.new )
    links = []
    bookmarks.each{|bookmark| links.push(bookmark) if bookmark[Bookmarks::SUBJECT].include?(tag) }
    if links.length > LIST_SIZE then
      bookmarks.top_tags(tag).each{|gat|
        if !(gat == tag) then
          item2 = item.submenu.append_menu_item(gat)
          item2.set_submenu( Gtk2App::Menu.new )
          links = []
          bookmarks.each{|bookmark| links.push(bookmark) if bookmark[Bookmarks::SUBJECT].include?(tag) && bookmark[Bookmarks::SUBJECT].include?(gat) }
          if links.length > LIST_SIZE then
            item2.submenu.append_menu_item('Run'){ Gtk2App.activate }
          else
            Gtk2Bookmarks._append_menum_item_boomkmark(item2,links)
          end
        end
      }
    else
      Gtk2Bookmarks._append_menum_item_boomkmark(item,links)
    end
    item.submenu.show_all
  }
  Gtk2App.dock_menu.show_all
end

def self.system_call(bookmark)
  system("#{APP[:browser]} '#{bookmark[Bookmarks::LINK]}' &")
  Gtk2Bookmarks.head(bookmark)
end

def self.head(bookmark)
  if bookmark[Bookmarks::LINK] =~ /^http:\/\/([^\/]+)(\/.*)?$/ then
    begin
      host = $1
      path = ($2)? $2: '/'
      response = nil
      Timeout::timeout(HTTP_TIMEOUT) {
        Net::HTTP.start(host, 80) {|http|
          response = http.head(path)
          $stderr.puts response.message if $trace
          if response.message=~/Not\s+Found/i then
            Bookmarks::HITS[bookmark[Bookmarks::LINK]] -= 2
          else
            Bookmarks::HITS[bookmark[Bookmarks::LINK]] += 1
          end
        }
      }
    rescue Exception
      puts_bang!
      Bookmarks::HITS[bookmark[Bookmarks::LINK]] -= 1
    end
  end
end

class App
  include Configuration

  def overwrite_tags_buttons(bookmarks,top_tags_buttons,tag=nil)
    overwrites = top_tags_buttons.children
    new_tags = overwrites.map{|x| x.label}
    new_tags = bookmarks.top_tags(tag).concat(new_tags).uniq[0..TAGS_EOI]
    new_tags.each{|gat|
      overwrite = overwrites.shift
      overwrite.label = overwrite.value = gat
    }
    #top_tags_buttons.show_all
  end

  def initialize(window,bookmarks)
    # Delete links to missing files
    bookmarks.delete_if {|bookmark| (bookmark[Bookmarks::LINK] =~ /^file:\/\/(.*)$/) && !File.exist?($1) }

    vbox = Gtk::VBox.new
    scrolled = Gtk2App::ScrolledWindow.new(vbox)
    window.add(scrolled)

    entry_text = ''
    bookmarks.sort!(entry_text)

    # About to be defined...
    top_tags_buttons = relist = nil

    hbox1 = Gtk::HBox.new
    button1 = Gtk2App::Button.new(IMAGE[:click],hbox1){ relist.call }
    entry = Gtk2App::Entry.new('',hbox1,ENTRY_OPTIONS)
    entry.signal_connect('activate'){ relist.call }
    Gtk2App::Button.new('Clear',hbox1){
      entry.text = ''
      overwrite_tags_buttons(bookmarks,top_tags_buttons)
      relist.call
    }
    Gtk2App.pack(hbox1,vbox)

    # Top Tags
    top_tags_buttons = Gtk::HBox.new
    bookmarks.top_tags.each{|tag|
      Gtk2App::Button.new(tag,top_tags_buttons){|value|
        entry.text = entry.text + ' ' + value
        overwrite_tags_buttons(bookmarks,top_tags_buttons,value)
        relist.call
      }.value = tag
    }
    Gtk2App.pack(top_tags_buttons,vbox)

    list = Gtk::VBox.new
    LIST_SIZE.times do |i|
      hbox2 = Gtk::HBox.new
      button2 = Gtk2App::Button.new(IMAGE[:go],hbox2){|bookmark| Gtk2Bookmarks.system_call(bookmark)}
      label = Gtk2App::Label.new('',hbox2,{:wrap=>false})
      link_label(bookmarks[i],button2,label)
      Gtk2App.pack(hbox2,list)
    end
    Gtk2App.pack(list,vbox)

    relist = proc { # ...relist defined
      Gtk2Bookmarks.conditional_reload(bookmarks)
      entry_text = entry.text
      bookmarks.sort!(entry_text)
      LIST_SIZE.times{|i| link_label(bookmarks[i],*list.children[i].children)}
    }
  end

  def link_label(bookmark,button,label)
    button.value = bookmark
    label.text = (bookmark)? bookmark[Bookmarks::TITLE]  + ' (' + bookmark[Bookmarks::SUBJECT].join(', ') + ')': ''
    sort_value = bookmark[Bookmarks::SORT]
    label.modify_fg(Gtk::STATE_NORMAL,
	(sort_value < LOW_THRESH_HOLD)? LOW_THRESH_HOLD_COLOR: (sort_value > HIGH_THRESH_HOLD)? HIGH_THRESH_HOLD_COLOR: DEFAULT_FG_COLOR)
  end
end
end
