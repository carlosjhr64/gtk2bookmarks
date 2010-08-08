require 'net/http'
require 'uri'
require 'cgi'
require 'hpricot'
require 'timeout'

module Gtk2Bookmarks
class Data < Hash
  attr_accessor :exclude_tags

  LIST_SIZE = 13
  MIN_LIST = 2

  SPLIT_BY = Regexp.new('[\W_]')

  def self.load(file,create=false)
    if File.exist?(file) then
       obj = nil
       File.open(file,'r'){|fh| obj = Marshal.load(fh) }
       return obj
    elsif create then
      return Data.new
    end
    raise "#{file} does not exist."
  end

  def self.tags(url,title,description,keywords)
    _tags = keywords.downcase.split(SPLIT_BY).uniq
    _tags += title.downcase.split(SPLIT_BY).uniq
    _tags += description.downcase.split(SPLIT_BY).uniq
    _tags += url.downcase.split(SPLIT_BY).uniq
    _tags = _tags.uniq.delete_if{|a| a.length < 3}
    return _tags
  end

  def initialize
   super
   @exclude_tags = []
  end

  def dump(file)
    File.rename(file,file+'.bak')	if File.exist?(file)
    self.each{|url,values| values[:hits] = Math.log(values[:hits]) + 1.0	if values }
    File.open(file, 'w'){|fh| Marshal.dump(self, fh)}
  end

  def self.meta(doc,name)
    begin
      return CGI.unescapeHTML( doc.at("meta[@name='#{name}']")['content'].encode )
    rescue Exception
      return  ''
    end
  end

  def self.title(doc)
    begin
      CGI.unescapeHTML( (doc/'title').inner_html.encode )
    rescue Exception
      return ''
    end
  end

  def store(url,timeout=15)
    begin
      uri = URI.parse(url)
      Net::HTTP.start(uri.host,uri.port) do |http|
        path = uri.path || '/'; path = '/' if path = ''
        path_query = path + ((query = uri.query)? ('?'+query): '')
        response = nil
        Timeout.timeout(timeout){ response = http.get(path_query) }
        if (response.code=~/^2/) && (response.content_type=='text/html') && (body = response.body) && (body.length > 0) then
          doc		= Hpricot(body)/'head'
          title		= Data.title(doc)
          description	= Data.meta(doc,'description')
          keywords	= Data.meta(doc,'keywords')
          tags		= Data.tags(url,title,description,keywords)
          if values = self[url] then
            values[:title]	= title
            values[:tags]	= tags
            values[:hits]	+= 1.0
          else
            self[url] = {:title=>title, :tags=>tags, :hits=>1.0}
          end
        else
          self[url] = nil
        end
        if location = response.header['location'] then
          location = 'http://' + uri.host + location if location=~/^\//
          store(location)	if !self.has_key?(location)
        end
      end
    rescue Exception
      self[url] = nil if !self.has_key?(url)
      Gtk2AppLib.puts_bang!(url)
    end
  end

  def hit(url)
    self[url][:hits] += 1.0
  end

  def hits(url)
    self[url][:hits]
  end

  def top_tags(match1=nil)
    top = Hash.new(0)
    self.keys.each{|url|
      next if !(values = self[url])
      _tags = values[:tags]
      if (!match1 || _tags.include?(match1)) then
        _tags.each{|tag| top[tag] += values[:hits] }
      end
    }
    # return top sorted keys
    top = top.sort{|a,b| b[1]<=>a[1]}
    max = top.first.last
    half = max/2
    half = LIST_SIZE if half < LIST_SIZE
    i = top.find_index{|a| a.last < half}
    top = top[i..-1].map{|a| a.first}
    top.delete_if{|a| @exclude_tags.include?(a)}
    return top
  end

  def path_links(tag1,tag2)
    count = 0
    urls = []
    self.each{|url,values|
      next if !values
      _tags = values[:tags]
      if _tags.include?(tag1) && _tags.include?(tag2) then
        count += 1
        return nil if count > LIST_SIZE
        urls.push([values[:title],url])
      end
    }
    return nil if count < MIN_LIST
    return urls
  end

  def top_paths
    seen = {}
    count1 = 0
    self.top_tags.each{|tag1|
      count2 = 0
      self.top_tags(tag1).each{|tag2|
        key = [tag1,tag2].sort.join('-')
        next if seen[key]
        seen[key] = true
        if links = path_links(tag1,tag2) then
          yield(tag1,tag2,links)
          count2 += 1
          break if count2 >= LIST_SIZE
        end
      }
      count1 += 1
      break if count1 >= LIST_SIZE
    }
  end
end
end
