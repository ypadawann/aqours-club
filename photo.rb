require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'active_support'
require 'active_support/core_ext'

module AqoursClub
	class Photo
		PHOTO_BASE_PATH = '/mob/news/diarLis.php'
		@key = nil
		@last_key = nil

		def initialize()
			@@photo_base_url = "#{AqoursClub::HOST_URL}#{PHOTO_BASE_PATH}"
			@last_key = AqoursClub::Base.get_photo_last_key
			check_dir()
		end

		def start
			page = 0
			loop do
				p uri = get_uri(page)
				html = open(uri, {'Cookie'=>AqoursClub::Base.get_cookie})
				doc = Nokogiri::HTML.parse(html, nil, html.charset)
				count = 0
				doc.xpath('//body/div[@id="container"]/div/section/div/figure/a/span[@class="photo-date"]').each do |node|
					count += 1
					unless download_title(doc, node)
						count = 0
						break
					end
				end
				break if count==0
				page += 1
			end

			AqoursClub::Base.update_conf_photo(@key) if @key != @last_key
		end

		def check_dir()
			@@photo_dir = "#{AqoursClub::Base.get_home_dir}/PHOTO"
			Dir::mkdir(@@photo_dir) unless Dir::exist?(@@photo_dir)
		end

		def get_uri(page=0)
			uri = URI(@@photo_base_url)
			uri.query = {
				site: 'AC',
				ima: '0315',
				page: page,
				rw: 6,
				cd: 'PHOTO_GALLERY',
				c1: 'top'
			}.to_query
			return uri
		end

		def download_title(doc, node)
			parent = node.parent
			key = parent.attribute('title').value
			@key = key if @key == nil
			return false if @last_key!=nil && key<=@last_key
			title = node.inner_text
			p "#{key}: #{title}"
			title_dir = "#{@@photo_dir}/#{title}"
			Dir::mkdir(title_dir) unless Dir::exists?(title_dir)
			doc.xpath("//body/div[@id='container']/div/section//a[@title='#{key}']/span[@class='photo-img']").each do |img_node|
				download_image(img_node.inner_text, title)
			end
			return true
		end

		def download_image(link, title)
			p "img: #{link}"
			url = "#{AqoursClub::HOST_URL}#{link}"
			file_path = "#{@@photo_dir}/#{title}/#{File.basename(url)}"
			File.open(file_path, 'wb') do |f|
				p "download: #{url}"
				open(URI(url), {'Cookie'=>AqoursClub::Base.get_cookie()}) do |data|
					f.write(data.read)
				end
			end
		end

	end
end
