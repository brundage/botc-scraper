#!/sbin/env ruby

require "httparty" 
require "nokogiri"
require "csv"
require "uri"

VERSION = "0.0.1"
USER_AGENT = "OccamBlazer Bot"
USER_AGENT_STRING = "#{USER_AGENT}/#{VERSION}"
#USER_AGENT_STRING = "Mozilla/5.0 (X11; Linux x86_64; rv:129.0) Gecko/20100101 Firefox/129.0"

BASEURL = "https://wiki.bloodontheclocktower.com"

TEAM_MAP = { "Demons" => "demon",
             "Minions" => "minion",
             "Outsiders" => "outsider",
             "Townsfolk" => "townsfolk"
           }


def fetch(url)
  if url =~ /^http/
    http_get(url).body
  else
    File.open(URI.decode_www_form_component(url))
  end
end


def http_get(url)
  HTTParty.get( url,
                headers: { "User-Agent": USER_AGENT_STRING }
              )
end


def parse_abilities(doc)
  abilities = doc.css("#Summary").first.parent.next_element.text
  matches = abilities.match(/^([^\]]+)\s*\[(.*)\]/)
  if( matches )
    [ trim_text(matches[1]), trim_text(matches[2]) ]
  else
    [ trim_text(abilities), nil ]
  end
end


def parse_character_page(document)
  name = document.css("h1.title span.mw-page-title-main").text
  flavor = trim_text(document.css("p.flavour").first.text)
  abilities = parse_abilities(document)
  image = document.css("div#character-details a.image img").first.attribute("src").value
  { name: name,
    ability: abilities[0],
    flavor: flavor,
    image: BASEURL + image,
    setup_ability: abilities[1]
  }
end


def scrape_doc(url)
end


def scrape_character_page(url)
  return unless url
  page = fetch(url)
  doc = Nokogiri::HTML(page)
  parse_character_page(doc)
end


def trim_text(string)
  trim_quotes(string).strip
end


def trim_quotes(string)
  string.gsub(/^"|"$/, "")
end


characters = []

%w( Townsfolk Outsiders Minions Demons ).each do |team|
  category_response = fetch("#{BASEURL}/Category:#{team}")
  category_document = Nokogiri::HTML(category_response)
  anchors = category_document.css("div.mw-category ul li a")

  anchors.each do |a|
    url = BASEURL + a.attribute("href")
    characters.push({team: TEAM_MAP[team]}.merge(scrape_character_page(url)))
  end

end

column_names = characters.first.keys

csv = CSV.generate do |c|
  c << column_names
  characters.each do |cha|
    c << cha.values
  end
end

puts csv
