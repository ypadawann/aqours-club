require 'net/http'

require File.expand_path(File.dirname(__FILE__)) + '/blog'
require File.expand_path(File.dirname(__FILE__)) + '/photo'

module AqoursClub
	HOST_URL = 'https://lovelive-aqoursclub.jp'
	LOGIN_URL = "#{HOST_URL}/mob/form/ajaxLogin.php"
	LOGIN_URI = URI(LOGIN_URL)
	BASE_URL	= "#{HOST_URL}/mob/news/diarKiji.php"
	BASE_URI	= URI(BASE_URL)

	CONF_FILE_PATH = File.expand_path(File.dirname(__FILE__)) + '/aqours-club.conf'

	class Base
		@@cookie = nil
		@@conf = nil

		def self.init
			get_conf_from_file
			p @@conf
			Dir::mkdir(@@conf['dir']) unless Dir::exist?(@@conf['dir'])
			login()
		end

		def self.login
			puts 'login to Aqours Club'
			Net::HTTP.start(LOGIN_URI.host, LOGIN_URI.port, :use_ssl=>true) do |http|
				data = {
					site: 'AC',
					loginUser: @@conf['id'],
					loginPass: @@conf['pass'],
					webCookie: nil,
					errMsgFlg: 'ON'
				}
				req = Net::HTTP::Post.new(LOGIN_URI)
				req.set_form_data(data)
				res = http.request(req)
				cookies = res.get_fields('Set-Cookie').map do |cookie|
					cookie.split(';')[0].rstrip
				end
				cookies.uniq!
				@@cookie = cookies.join('; ')
			end
		end
		
		def self.get_cookie
			return @@cookie
		end

		def self.get_base_uri
			return BASE_URI
		end

		def self.get_conf_from_file
			return false unless File.exist?(CONF_FILE_PATH)
			File.open(CONF_FILE_PATH, 'r') do |f|
				@@conf = JSON.load(f)
			end
			return true
		end

		def self.save_conf_file
			File.open(CONF_FILE_PATH, 'w') do |f|
				JSON.dump(@@conf, f)
			end
		end

		def self.get_conf
			if @@conf == nil
				@@conf = {
					'id'=> '',
					'pass'=> '',
					'dir'=> File.expand_path(File.dirname(__FILE__))+'/Aqours Club',
					'data'=> {
						'photo'=> {
							'key'=> nil
						},
						'blog'=> {
							'id'=> nil
						}
					}
				}
			end
			return @@conf
		end

		def self.get_home_dir
			return @@conf['dir']
		end

		def self.get_blog_last_id
			return @@conf['data']['blog']['id']
		end

		def self.update_conf_blog(id)
			@@conf['data']['blog']['id'] = id
			save_conf_file
		end

		def self.get_photo_last_key
			return @@conf['data']['photo']['key']
		end

		def self.update_conf_photo(key)
			@@conf['data']['photo']['key'] = key
			save_conf_file
		end

		def self.create_default_conf_file
			conf = {
				'id'=> 'chika.takami@uranohosi.co.jp',
				'pass'=> 'shitake',
				'dir'=> './Aqours Club',
				'data'=> {
					'photo'=> {
						'key'=> nil
					},
					'blog'=> {
						'id'=> nil
					}
				}
			}
			File.open(CONF_FILE_PATH, 'w') do |f|
				JSON.dump(json, f)
			end
		end

	end
end

AqoursClub::Base.init

blog = AqoursClub::Blog.new
blog.start

photo = AqoursClub::Photo.new
photo.start
