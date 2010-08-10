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

  def _store_new_bookmarks
    now = Time.now
    Configuration.bookmarks(@data,@mtime){|url,data|
      data.store(url)
      progressing
    }
    @mtime = now
  end

  def delete_bookmarks_not_on_files
    on_files = Configuration.bookmarks{|url,seen| seen[url] = true }
    @data.delete_if{|url,values| (values.nil? || (values[:hits] <= 0.0)) && !on_files[url]}
  end

  def _hit_urls(urls)
    while url = urls.shift do
      @data.hit(url)
      progressing
    end
  end

  def build_dock_menu(urls=nil)
    return if @thread
    progressing
    @thread = Thread.new {
      begin
        _hit_urls(urls) if urls
        _store_new_bookmarks
        delete_bookmarks_not_on_files
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
            title = App.trunc(title,60,link)
            submenu.append_menu_item(title){
              system( "#{APP[:browser]} '#{link}' > /dev/null 2>&1 &" )
              @query.text = "#{tag1} #{tag2}"
              build_dock_menu([link])
            }
          }
          submenu.append_menu_item('Run'){
            @query.text = "#{tag1} #{tag2}"
            search
            @dock_menu.children[1].activate # <= should be Run's item
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

  def full_reload
    if !@thread then
      urls = []
      @data.each{|url,values| urls.push(url) if !values}
      build_dock_menu(urls)
    end
  end

  def self.trunc(title,n,url='')
    title = title.gsub(/\s+/,' ').gsub(/&\S+;/,'*')
    title = url if title.length < 1
    (title.length<n)? title: title[0..(n-4)] + '...'
  end

  def self.fg_color(_sort)
    (_sort < LOW_THRESH_HOLD)?  LOW_THRESH_HOLD_COLOR: (_sort > HIGH_THRESH_HOLD)?  HIGH_THRESH_HOLD_COLOR: DEFAULT_FG_COLOR
  end

  def search
    i = 0
    Configuration.hits_valuation(@data, @query.text, MAX_LIST).each{|url,title,_sort|
      result = @results[i]
      i+=1
      label = result[0]
      label.text = App.trunc(title,80,url)
      label.modify_fg(Gtk::STATE_NORMAL, App.fg_color(_sort))
      button = result[1]
      button.value = url
    }
  end

  def build_window(window)
    vbox = Gtk2AppLib::VBox.new(window)

    form = Gtk2AppLib::HBox.new(vbox)
    @results = []
    Gtk2AppLib::Button.new(IMAGE[:search],form){ search }
    @query = Gtk2AppLib::Entry.new('',form,{:entry_width=>500}){ search }
    Gtk2AppLib::Button.new(IMAGE[:clear],form){
      overwrite_top_tags
      @query.text = ''
      @query.activate
    }
    Gtk2AppLib::Button.new(IMAGE[:google],form){
      if (query = @query.text.strip).length > 0 then
        system( "#{APP[:browser]} 'http://www.google.com/search?q=#{CGI.escape(query)}' > /dev/null 2>&1 &" )
      end
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

    MAX_LIST.times do |i|
      results = Gtk2AppLib::HBox.new(vbox)
      link = Gtk2AppLib::Button.new(IMAGE[:go2], results){|url|
        system( "#{APP[:browser]} '#{url}' > /dev/null 2>&1 &" )
        @data.hit(url)
      }
      link.value = nil
      label = nil
      event_box = Gtk2AppLib::EventBox.new(results){|e1,e2|
        if e2.button == 1 && link.value then
          if title = Gtk2AppLib::DIALOGS.entry('New title:') then
            @data[link.value][:title] = title
            label.text = App.trunc(title,80)
          end
          true
        else
          false
        end
      }
      label = Gtk2AppLib::Label.new('', event_box, {:label_width=>500})
      Gtk2AppLib::Button.new(IMAGE[:reload], results){
        if url = link.value then
          values = @data.store(url)
          if values then
            label.text = App.trunc(values[:title],80,url)
          else
            link.value = nil
            label.text = '*'
          end
        end
      }
      Gtk2AppLib::Button.new(IMAGE[:down], results){
	@data[link.value][:hits] = 0.0 # this demotes the link
        search
      }
      @results.push([label,link])
    end

    progress = Gtk2AppLib::HBox.new(vbox)
    @progress_bar = Gtk2AppLib::ProgressBar.new(progress)
    Gtk2AppLib::Button.new(IMAGE[:reload],progress){ build_dock_menu }
    @progress_label = Gtk2AppLib::Label.new('0',progress)
    done if done?
  end
end
end
