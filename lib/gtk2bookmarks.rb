require 'gtk2bookmarks/data'
module Gtk2Bookmarks
class App

  #def initialize(data,dock_menu)
  def initialize(program,data)
    @data = data
    @program = program
    @mtime = Time.at(0)

    @progress_bar = nil
    @progress_label = nil
    @count = 1

    @thread = nil
    @top_tags = []
    @results = []

    @query = nil # gets set later
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
    @data.top_tags(match)[0..(Configuration::TOP_TAGS-1)].each{|tag|
      top_tag = @top_tags[i]
      top_tag.label = tag
      top_tag.is = tag
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
      self.search
    end
  end

  def _store_new_bookmarks
    now = Time.now
    Configuration.bookmarks(@data,@mtime) do |url,data|
      sleep(Configuration::RATE_LIMIT)
      while Thread.list.count >= Configuration::THREADS do
        Thread.pass
      end
      Thread.new{ data.store(url) }
      progressing
    end
    @mtime = now
  end

  def delete_bookmarks_not_on_files
    on_files = Configuration.bookmarks{|url,seen| seen[url] = true }
    @data.delete_if{|url,values| (values.nil? || (values[:HITS] <= 0.0)) && !on_files[url]}
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
    @thread = Thread.new do
      begin
        _hit_urls(urls) if urls
        _store_new_bookmarks
        delete_bookmarks_not_on_files
        s = '-'
        item1 = {}
        item2 = {}
        @program.clear_dock_menu
        @data.top_paths(Configuration::TOP_TAGS) do |tag1,tag2,links|
          progressing
          key1 =  tag1
          if !item1[key1] then
	      item1[key1] = @program.append_dock_menu(tag1)
	      item1[key1].set_submenu(Gtk2AppLib::Widgets::Menu.new)
          end
          submenu = item1[key1].submenu
          key2 =  tag1+s+tag2
          if !item2[key2] then
              item2[key2] = submenu.append_menu_item(tag2)
              item2[key2].set_submenu(Gtk2AppLib::Widgets::Menu.new)
          end
          submenu = item2[key2].submenu
          links.each do |title,link|
            title = App.trunc(title,60,link)
            submenu.append_menu_item(title) do
              Gtk2AppLib.run(link)
              @query.text = "#{tag1} #{tag2}"
              build_dock_menu([link])
            end
          end
          submenu.append_menu_item('Run'){
            @query.text = "#{tag1} #{tag2}"
            self.search
            @program.activate
          }
        end 
      rescue Exception
        $!.puts_bang!
      ensure
        @thread = nil
        done
      end
    end
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
    (_sort < Configuration::LOW_THRESH_HOLD)?
	Configuration::LOW_THRESH_HOLD_COLOR :
	((_sort > Configuration::HIGH_THRESH_HOLD)?  Configuration::HIGH_THRESH_HOLD_COLOR: Configuration::DEFAULT_FG_COLOR)
  end

  def search
    i = 0
    Configuration.hits_valuation(@data, @query.text, Configuration::MAX_LIST).each{|url,title,_sort|
      result = @results[i]
      i+=1
      label = result[0]
      label.text = App.trunc(title,80,url)
      label.modify_fg(Gtk::STATE_NORMAL, App.fg_color(_sort))
      button = result[1]
      button.is = url
    }
  end

  def build_window(window)
    vbox = Gtk2AppLib::Widgets::VBox.new(window)

    form = Gtk2AppLib::Widgets::HBox.new(vbox)
    @results.clear
    Gtk2AppLib::Widgets::Button.new(*Configuration::SEARCH_BUTTON+[form]){ search }
    @query = Gtk2AppLib::Widgets::Entry.new(*Configuration::SEARCH_ENTRY+[form]){ search }
    Gtk2AppLib::Widgets::Button.new(*Configuration::CLEAR_BUTTON+[form]){
      overwrite_top_tags
      @query.text = ''
      @query.activate
    }
    Gtk2AppLib::Widgets::Button.new(*Configuration::GOOGLE_BUTTON+[form]){
      if (query = @query.text.strip).length > 0 then
        Gtk2AppLib.run("https://www.google.com/search?q=#{CGI.escape(query)}")
      end
    }

    top_tags = Gtk2AppLib::Widgets::HBox.new(vbox)
    @top_tags.clear
    Configuration::TOP_TAGS.times do
      top_tag = Gtk2AppLib::Widgets::Button.new(*Configuration::TOP_TAG_BUTTON+[top_tags]){|tag,*emits|
        overwrite_top_tags(tag)
        @query.text += " "+tag
        @query.activate
      }
      top_tag.is = nil
      @top_tags.push(top_tag)
    end

    Configuration::MAX_LIST.times do |i|
      results = Gtk2AppLib::Widgets::HBox.new(vbox)
      link = Gtk2AppLib::Widgets::Button.new(*Configuration::GO2_BUTTON+[results]){|url,*emits|
        Gtk2AppLib.run(url)
        @data.hit(url)
      }
      link.is = nil
      label = nil
      event_box = Gtk2AppLib::Widgets::EventBox.new(results,'button_press_event'){|*emits|
        if emits.last.button == 1 && link.is then
          if title = Gtk2AppLib::DIALOGS.entry(*Configuration::NEW_TITLE_DIALOG) then
            @data[link.is][:TITLE] = title
            label.text = App.trunc(title,80)
          end
          true
        else
          false
        end
      }
      label = Gtk2AppLib::Widgets::Label.new(*Configuration::BOOKMARK_LABEL+[event_box])
      Gtk2AppLib::Widgets::Button.new(*Configuration::RELOAD_BUTTON+[results]){
        if url = link.is then
          values = @data.store(url)
          if values then
            label.text = App.trunc(values[:TITLE],80,url)
          else
            link.is = nil
            label.text = '*'
          end
        end
      }
      Gtk2AppLib::Widgets::Button.new(*Configuration::DOWN_BUTTON+[results]){
	@data[link.is][:HITS] = 0.0 # this demotes the link
        search
      }
      @results.push([label,link])
    end

    progress = Gtk2AppLib::Widgets::HBox.new(vbox)
    @progress_bar = Gtk2AppLib::Widgets::ProgressBar.new(progress)
    Gtk2AppLib::Widgets::Button.new(*Configuration::RELOAD_BUTTON+[progress]){ build_dock_menu }
    @progress_label = Gtk2AppLib::Widgets::Label.new('0',progress)
    done if done?
  end
end
end
