# -*- coding: utf-8 -*-
require 'webrick'
require 'erb'
require 'rubygems'
require 'dbi'

class String
	alias_method(:orig_concat, :concat)
	def concat(value)
		if RUBY_VERSION > "1.9"
			orig_concat value.force_encoding('UTF-8')
		else
			orig_concat value
		end
	end
end

config = {
	:Port => 8099,
	:DocumentRoot => '.'
}


WEBrick::HTTPServlet::FileHandler.add_handler("erb",WEBrick::HTTPServlet::ERBHandler)
server = WEBrick::HTTPServer.new(config)
server.config[:MimeTypes]["erb"] = "text/html"

# 一覧表示からの処理
server.mount_proc("/list"){|req,res|
	p req.query
	if /(.*)\.(delete|edit)$/ =~ req.query['operation']
		target_id = $1
		operation = $2
		if operation == 'delete'
			template = ERB.new(File.read('delete.erb'))
		elsif operation == 'edit'
			template = ERB.new(File.read('edit.erb'))
		end
		res.body << template.result(binding)
	else
		template = ERB.new(File.read('noselected.erb'))
		res.body << template.result(binding)
	end
}

# 登録の処理
server.mount_proc("/entry"){|req,res|
	p req.query
	dbh = DBI.connect('DBI:SQLite3:bookinfo_sqlite.db')
	rows = dbh.select_one("select * from bookinfos where id='#{req.query['id']}';")
	if rows then
		dbh.disconnect
		template = ERB.new(File.read('noentried.erb'))
		res.body << template.result(binding)
	else
		dbh.do("insert into bookinfos values ('#{req.query['id']}','#{req.query['title']}','#{req.query['author']}','#{req.query['page']}','#{req.query['publish_date']}');")
		dbh.disconnect

		template = ERB.new(File.read('entried.erb'))
		res.body << template.result(binding)
	end
}

# 検索の処理
server.mount_proc("/retrieve"){|req,res|
	p req.query
	a = ['id','title','author','page','publish_date']
	a.delete_if {|name| req.query[name] == ""}

	if a.empty?
		where_data = ""
	else
		a.map! {|name| "#{name}=\'#{req.query[name]}\'"}
		where_data = "where " + a.join(' or ')
	end

	template = ERB.new(File.read('retrieved.erb'))
	res.body << template.result(binding)
}

# 修正の処理
server.mount_proc("/edit"){|req,res|
	p req.query
	dbh = DBI.connect('DBI:SQLite3:bookinfo_sqlite.db')
	dbh.do("update bookinfos set id='#{req.query['id']}',title='#{req.query['title']}',author='#{req.query['author']}',page='#{req.query['page']}',publish_date='#{req.query['publish_date']}' where id='#{req.query['target_id']}';")
 	dbh.disconnect

	template = ERB.new(File.read('edited.erb'))
	res.body << template.result(binding)
}

# 削除の処理
server.mount_proc("/delete"){|req,res|
	p req.query
	dbh = DBI.connect('DBI:SQLite3:bookinfo_sqlite.db')
	dbh.do("delete from bookinfos where id='#{req.query['target_id']}';")
 	dbh.disconnect

	template = ERB.new(File.read('deleted.erb'))
	res.body << template.result(binding)
}


trap(:INT) do
	server.shutdown
end
server.start
