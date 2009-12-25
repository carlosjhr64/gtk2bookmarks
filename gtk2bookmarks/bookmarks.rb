# $Date: 2009/03/09 15:32:59 $
require 'rexml/document'

class Bookmarks < Array
  TITLE_	= 'title'
  LINK_		= 'link'
  SUBJECT_	= 'subject'

  SORT		= 0
  TITLE		= 1
  LINK		= 2
  SUBJECT	= 3 # AKA TAGS
  KEYWORDS	= 4
  RESPONSE	= 5

  HREFX		= Regexp.new( '<A\s+HREF="([^"]*)"[^>]*>([^<>]*?)<\/A>', Regexp::IGNORECASE )

 
  # there's got to be a better way!!! :-?? 
  def get_xml_bookmarks( item, tags=[] )
    item.elements.each do |element|
      if element.name == 'bookmark' then
        link = element.attributes.to_hash['href']
        element.each_element do |data|
          if data.name == 'title' then
            title = data.text
            if @seen[link] then
              @seen[link][SUBJECT].concat( tags.dup )
              @seen[link][SUBJECT].uniq!
              @seen[link][KEYWORDS].concat( title.split(/\W+/) )
              @seen[link][KEYWORDS].uniq!
              @seen[link][KEYWORDS].delete_if{|x| @seen[link][TITLE].include?(x)}
            else
              # Keywords are added later on duplicate links
              self.push([ 0, title, link, tags, [], '' ])
              @seen[link] = self.last
            end
          end
        end
      else
        if element.name == 'folder' then
          element.each_element do |data|
            if data.name == 'title' then
              tags.push(data.text)
            end
          end
          get_xml_bookmarks( element, tags )
          tags.pop
        else
          get_xml_bookmarks( element, tags )
        end
      end
    end
  end

  def get_rdf_bookmarks( root )
    entry = {}; entry[TITLE_] = []; entry[LINK_] = []; entry[SUBJECT_] = []
    root.elements.each do |item|
      if item.name == 'item' then
        entry[TITLE_].clear; entry[LINK_].clear; entry[SUBJECT_].clear
        item.elements.each{|part| part.each{|p| entry[part.name].push( p.to_s.strip ) if entry[part.name] } }
        link = entry[LINK_][0].strip
        title = entry[TITLE_][0].strip
        if @seen[link] then
          @seen[link][SUBJECT].concat( entry[SUBJECT_].dup )
          @seen[link][SUBJECT].uniq!
          @seen[link][KEYWORDS].concat( title.split(/\W+/) )
          @seen[link][KEYWORDS].uniq!
          @seen[link][KEYWORDS].delete_if{|x| @seen[link][TITLE].include?(x)}
        else
          # Keywords are added later on duplicate links
          self.push([ 0,  title, link, entry[SUBJECT_].dup, [], '' ]) 
          @seen[link] = self.last
        end
      end
    end
  end

  def get_html_bookmarks(fh)
    buffer = ''
    fh.each do |line|
      buffer += line
      # could not find an easy way to get the tags :(
      while md = HREFX.match(buffer) do
        link = md[1].strip
        title = md[2].gsub(/<[^<>]*>/,'').gsub(/\s+/,' ').strip
        if @seen[link] then
          @seen[link][KEYWORDS].concat( title.split(/\W+/) )
          @seen[link][KEYWORDS].uniq!
          @seen[link][KEYWORDS].delete_if{|x| @seen[link][TITLE].include?(x)}
        else
          # Keywords are added later on duplicate links
          self.push([ 0, title, link, [], [], '' ]) 
          @seen[link] = self.last
        end
        buffer = md.post_match
      end
    end
  end

  def _load
    @seen = {}

    xml = nil
    @files.each do |file|
      if file =~ /\.rdf$/ then
        # RDFs epiphany
        File.open(file, 'r'){|fh| xml = REXML::Document.new(fh) }
        get_rdf_bookmarks( xml.root )
      elsif file =~ /\.html$/ then
        # HTMLs firefox
        File.open(file, 'r'){|fh| get_html_bookmarks(fh) }
      elsif file =~ /\.xml$/ then
        # XML microb
        File.open(file, 'r'){|fh| xml = REXML::Document.new(fh)}
        get_xml_bookmarks( xml.root )
      end
    end

    @seen = nil # to GC
  end

  def reload
    self.clear
     _load
  end

  def conditional_reload
    ret = false

    if @rdf_exist && (Time.now - @rdf_checked > Configuration::RDF_CHECK_TIME) then # just to avoid immediate re-checks
      fmt = File.mtime(Configuration::EPIPHANY_RDF)
      if fmt > @mtime then
        @mtime = fmt
        reload
        ret = true
      end
      @rdf_checked = Time.now
    end

    return ret
  end

  def initialize(files)
    super()

    @rdf_exist = File.exist?(Configuration::EPIPHANY_RDF)
    @rdf_checked = (@rdf_exist)? Time.now: nil
    @mtime = (@rdf_exist)? File.mtime(Configuration::EPIPHANY_RDF): nil

    @files = files
    _load
  end

  def sort!(query)
    Configuration.hits_valuation(self,query)
    super(){|a,b|
      b[SORT] <=> a[SORT]
    }
  end

  def top_tags(match=nil)
    tags = Hash.new(0)
    self.each{|bookmark|
      if !match || bookmark[SUBJECT].include?(match) then
        bookmark[SUBJECT].uniq.each{|subject|
          tags[subject] += 1
        }
      end
    }
    # return top 10 sorted keys TBD: Configurable?
    ret = tags.sort{|a,b| b[1]<=>a[1]}.map{|ab| ab.first}[0..Configuration::TAGS_EOI]
    (Configuration::INITIAL_TAGS && !match)? Configuration::INITIAL_TAGS.concat(ret).uniq[0..Configuration::TAGS_EOI]: ret
  end
end
