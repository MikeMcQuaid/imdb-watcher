#!/usr/bin/env ruby
require 'httparty'
require 'xmlsimple'
require 'itunes'
require 'logger' # needed before netflix4r
require 'netflix4r'
require 'ap'

itunes_country = 'gb'
itunes_country = { country: itunes_country }

response = HTTParty.get 'http://rss.imdb.com/user/ur33181995/watchlist'
imdb = XmlSimple.xml_in response.body, ForceArray: false
imdb_watchlist_entries = imdb['channel']['item']

itunes = ITunes::Client.new

imdb_watchlist_entries.each do |imdb_item|
  _, title, year, tv = /(.*) \((\d+)\s?(.*)\)/.match(imdb_item['title']).to_a
  year = year.to_i
  tv = (tv == "TV Series")

  watch_item = {
    title: title,
    year: year,
    itunes_exact: [],
    itunes_fuzzy: [],
    netflix_exact: [],
    nexflix_fuzzy: [],
  }

  itunes_method = tv ? :tv_show : :movie
  itunes_videos = itunes.send(itunes_method, title, itunes_country).results
  itunes_videos.each do |itunes_video|
    itunes_year = Date.parse(itunes_video['release_date']).year
    itunes_title = itunes_video[tv ? 'artist_name' : 'track_name']
    itunes_url = itunes_video[tv ? 'artist_view_url' : 'track_view_url']

    if (itunes_title.downcase == title.downcase or itunes_title.downcase == "#{title} (#{year})".downcase)
      watch_item[:itunes_exact] = itunes_url
      break
    elsif itunes_year == year and not (itunes_title.downcase.split & title.downcase.split).empty?
      watch_item[:itunes_fuzzy] << {
        title: itunes_title,
        year: itunes_year,
        url: itunes_url
      }
    end
  end

  netflix_videos = NetFlix::Title.search(term: title, max_results: 10)
  netflix_videos.each do |netflix_video|
    next unless netflix_video.delivery_formats.include? 'instant'
    netflix_year = netflix_video.release_year
    netflix_title = netflix_video.title
    netflix_url = netflix_video.web_page

    if netflix_title.downcase == title.downcase
      watch_item[:netflix_exact] = netflix_url
      break
    elsif netflix_year == year and not (netflix_title.downcase.split & title.downcase.split).empty?
      watch_item[:nexflix_fuzzy] << {
        title: netflix_title,
        year: netflix_year,
        url: netflix_url
      }
    end
  end

  ap watch_item
end
