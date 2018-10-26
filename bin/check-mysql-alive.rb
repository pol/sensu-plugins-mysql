#!/opt/sensu/embedded/bin/ruby
#
# MySQL Alive Plugin
# ===
#
# This plugin attempts to login to mysql with provided credentials.
#
# Copyright 2011 Joe Crim <josephcrim@gmail.com>
# Updated by Lewis Preson 2012 to accept a database parameter
# Updated by Oluwaseun Obajobi 2014 to accept ini argument
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# USING INI ARGUMENT
# This was implemented to load mysql credentials without parsing the username/password.
# The ini file should be readable by the sensu user/group.
# Ref: http://eric.lubow.org/2009/ruby/parsing-ini-files-with-ruby/
#
#   EXAMPLE
#     mysql-alive.rb -h db01 --ini '/etc/sensu/my.cnf'
#     mysql-alive.rb -h db01 --ini '/etc/sensu/my.cnf' --ini-section customsection
#
#   MY.CNF INI FORMAT
#   [client]
#   user=sensu
#   password="abcd1234"
#
#   [customsection]
#   user=user
#   password="password"
#
# Modified by Pol Llovet <pol@actionverb.com> to allow loading rails-style yml config files 


require 'sensu-plugin/check/cli'
require 'mysql'
require 'inifile'
require 'yaml'

class CheckMySQL < Sensu::Plugin::Check::CLI
  option :user,
         description: 'MySQL User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'MySQL Password',
         short: '-p PASS',
         long: '--password PASS'

  option :ini,
         description: 'My.cnf ini file',
         short: '-i VALUE',
         long: '--ini VALUE'

  option :yaml,
         short: '-y',
         long: '--yaml VALUE',
         description: 'My.cnf yaml file'

  option :ini_section,
         description: 'Section in my.cnf ini file',
         long: '--ini-section VALUE',
         default: 'production'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST'

  option :database,
         description: 'Database schema to connect to',
         short: '-d DATABASE',
         long: '--database DATABASE',
         default: 'test'

  option :port,
         description: 'Port to connect to',
         short: '-P PORT',
         long: '--port PORT',
         default: '3306'

  option :socket,
         description: 'Socket to use',
         short: '-s SOCKET',
         long: '--socket SOCKET'

  def run
    if config[:ini]
      ini        = IniFile.load(config[:ini])
      section    = ini[config[:ini_section]]
      db_user    = section['user']
      db_pass    = section['password']
      mysql_host = section['host']
    elsif config[:yaml]
      yml        = YAML.safe_load(File.read(config[:yaml]))
      section    = yml[config[:ini_section]]
      db_user    = section['username']
      db_pass    = section['password']
      mysql_host = section['host']
    else
      db_user    = config[:username]
      db_pass    = config[:password]
      mysql_host = config[:hostname]
    end

    begin
      db = Mysql.real_connect(mysql_host, db_user, db_pass, config[:database], config[:port].to_i, config[:socket])
      info = db.get_server_info
      ok "Server version: #{info}"
    rescue Mysql::Error => e
      critical "Error message: #{e.error}"
    ensure
      db.close if db
    end
  end
end
