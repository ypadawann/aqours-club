require 'nokogiri'
require 'open-uri'
require 'json'
require 'active_support'
require 'active_support/core_ext'

module AqoursClub
	class Blog
		BLOG_BASE_PATH = '/mob/news/diarKiji.php'
		@id = nil
		@last_id = nil
		
		def initialize()
			@@blog_base_uri = URI("#{AqoursClub::HOST_URL}#{BLOG_BASE_PATH}")
			@last_id = AqoursClub::Base.get_blog_last_id
			check_dir()
		end

		def start
			page = 0
			loop do
				p uri = get_uri(page)
				html = open(uri, {'Cookie'=>AqoursClub::Base.get_cookie})
				doc = Nokogiri::HTML.parse(html, nil, html.charset)
				count = 0
				doc.xpath('//body/div[@id="container"]//div[@class="items-info"]').each do |node|
					title = nil
					link = nil
					node.xpath('h2/a').each do |title_node|
						title = title_node.inner_text
						link = title_node.attribute('href').value
					end
					member = nil
					date = nil
					node.xpath('p[@class="items-info-detail"]').each do |detail_info_node|
						member = detail_info_node.children[0].inner_text
						date = detail_info_node.xpath('//span[@class="info-date"]')[0].inner_text
					end

					id = Hash[URI::decode_www_form(URI(link).query)]['id']
					break if @last_id != nil && id <= @last_id
					@id = id if @id == nil

					save(title, link, member, date)
					count += 1
				end
				break if count==0
				page += 1
			end

			AqoursClub::Base.update_conf_blog(@id) if @id != nil && @id != @last_id
		end

		def check_dir
			@@blog_dir = "#{AqoursClub::Base.get_home_dir}/BLOG"
			Dir::mkdir(@@blog_dir) unless Dir::exist?(@@blog_dir)
		end

		def get_uri(page=0)
			uri = @@blog_base_uri
			uri.query = {
				site: 'AC',
				ima: 5221,
				page: page,
				rw: 10,
				cd: 'blog',
				type: 'MEMBER_BLOG',
			}.to_query
			return uri
		end

		def save(title, link, member, date)
			p "#{member}: #{date} #{title}"
			member_dir = "#{@@blog_dir}/#{member}"
			Dir::mkdir(member_dir) unless Dir::exist?(member_dir)

			content = get_blog_text(link)

			file_name = get_file_name(date, title)
			file_path = "#{member_dir}/#{file_name}.txt"
			File.open(file_path, 'w') do |f|
				f << content[:text]
			end
			content[:images].each do |img|
				p img
				download_image(img, date, member_dir)
			end
		end

		def get_blog_text(link)
			content = {
				text: '',
				images: []
			}
			uri = URI("#{AqoursClub::HOST_URL}#{link}")
			html = open(uri, {'Cookie'=>AqoursClub::Base.get_cookie})
			doc = Nokogiri::HTML.parse(html, nil, html.charset)
			content[:text] = doc.xpath('//section[@class="entry"]')[0].inner_text
			doc.xpath('//div[@class="entry-body"]//img').each do |node|
				content[:images] << node.attribute('src').value
			end
			return content
		end

		def get_file_name(date, title)
			# Remove invalid character
			tmp = title.gsub(/[<>:"\\\/|?*]/, '')
			return "#{date} #{tmp}";
		end

		def download_image(link, date, member_dir)
			file_path = "#{member_dir}/#{date}.#{File.basename(link)}"
			File.open(file_path, 'wb') do |f|
				uri = URI(link)
				if uri.host == nil then
					uri = URI("#{AqoursClub::HOST_URL}/#{link}")
				end
				open(uri, {'Cookie'=>AqoursClub::Base.get_cookie}) do |data|
					f.write(data.read)
				end
			end
		end

	end
end
