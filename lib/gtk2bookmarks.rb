require 'gtk2bookmarks/data'
module Gtk2Bookmarks
class App
  include Configuration

  def initialize(data,dock_menu)
    @data = data
    @dock_menu = dock_menu
    @mtime = Time.at(0)

    @progress_bar = nil
    @progress_label = nil
    @count = 1

    @thread = nil
  end

  def thread_kill
    @thread.kill if @thread
  end

  def progressing
    @count = 1 if @count < 1
    if @progress_bar && @progress_label then
      @progress_bar.fraction = 1.0 - 1.0 / (1.0 + Math.log(@count))
      @progress_label.text = @count.to_s
    end
    @count += 1
  end

  def done?
    @count == 0
  end

  def overwrite_top_tags(match=nil)
    i = 0
    @data.top_tags(match)[0..(TOP_TAGS-1)].each{|tag|
      top_tag = @top_tags[i]
      top_tag.label = tag
      top_tag.value = tag
      i+=1
    }
  end

  def done
    @count = 0
    if @progress_bar && @progress_label then
      @progress_bar.fraction = 1.0
      @progress_label.text = 'Ready!'
      i = 0
      overwrite_top_tags
      search
    end
  end

  def bookmarks
    now = Time.now
    Configuration.bookmarks(@data,@mtime){|url,data|
      data.store(url)
      progressing
    }
    @mtime = now
  end

  def build_dock_menu(url=nil)
    return if @thread
    progressing
    @thread = Thread.new {
      begin
        if url then
          @data.hit(url)
          progressing
        end
        bookmarks
        progressing
        s = '-'
        item1 = {}
        item2 = {}
        @dock_menu.clear
        @data.top_paths{|tag1,tag2,links|
          progressing
          key1 =  tag1
          if !item1[key1] then
	      item1[key1] = @dock_menu.append_menu_item(tag1)
	      item1[key1].set_submenu(Gtk2AppLib::Menu.new)
          end
          submenu = item1[key1].submenu
          key2 =  tag1+s+tag2
          if !item2[key2] then
              item2[key2] = submenu.append_menu_item(tag2)
              item2[key2].set_submenu(Gtk2AppLib::Menu.new)
          end
          submenu = item2[key2].submenu
          links.each{|title,link|
            title = title.gsub(/\s+/,' ')
            title = title[0..57]+'...' if title.length > 60
            submenu.append_menu_item(title){
              system( "#{APP[:browser]} '#{link}' > /dev/null 2>&1 &" )
              build_dock_menu(link)
            }
          }
        }
        @dock_menu.show_all
      rescue Exception
        Gtk2AppLib.puts_bang!
      ensure
        @thread = nil
        done
      end
    }
  end

  def self.fg_color(_sort)
    (_sort < LOW_THRESH_HOLD)?  LOW_THRESH_HOLD_COLOR: (_sort > HIGH_THRESH_HOLD)?  HIGH_THRESH_HOLD_COLOR: DEFAULT_FG_COLOR
  end

  def search
    i = 0
    Configuration.hits_valuation(@data, @query.text, LIST_SIZE).each{|url,title,_sort|
      if title.strip.length < 1 then
        title = url
      end
      result = @results[i]
      i+=1
      label = result[0]
      label.text = title.gsub(/\s+/,' ')[0..80]
      label.modify_fg(Gtk::STATE_NORMAL, App.fg_color(_sort))
      button = result[1]
      button.value = url
    }
  end

  def build_window(window)
    vbox = Gtk2AppLib::VBox.new(window)

    form = Gtk2AppLib::HBox.new(vbox)
    @results = []
    Gtk2AppLib::Button.new(IMAGE[:click],form){ search }
    @query = Gtk2AppLib::Entry.new('',form,{:entry_width=>500}){ search }
    Gtk2AppLib::Button.new('clear',form){
      overwrite_top_tags
      @query.text = ''
      @query.activate
    }

    top_tags = Gtk2AppLib::HBox.new(vbox)
    @top_tags = []
    TOP_TAGS.times do
      top_tag = Gtk2AppLib::Button.new('',top_tags){|tag|
        overwrite_top_tags(tag)
        @query.text += " "+tag
        @query.activate
      }
      top_tag.value = nil
      @top_tags.push(top_tag)
    end

    LIST_SIZE.times do |i|
      results = Gtk2AppLib::HBox.new(vbox)
      label = nil
      link = Gtk2AppLib::Button.new(IMAGE[:go], results){|url|
        system( "#{APP[:browser]} '#{url}' > /dev/null 2>&1 &" )
        build_dock_menu(url)
      }
      link.value = nil
      label = Gtk2AppLib::Label.new('', results, {:label_width=>600})
      @results.push([label,link])
    end

    progress = Gtk2AppLib::HBox.new(vbox)
    @progress_bar = Gtk2AppLib::ProgressBar.new(progress)
    @progress_label = Gtk2AppLib::Label.new('0',progress)
    done if done?
  end
end
end
