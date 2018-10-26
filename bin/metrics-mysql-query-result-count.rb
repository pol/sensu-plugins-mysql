#!/opt/sensu/embedded/bin/ruby
#
# MySQL Query Result Count Metric
#
# Creates a graphite-formatted metric for the length of a result set from a MySQL query.
#
# Copyright 2017 Andrew Thal <athal7@me.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Modified by Pol Llovet <pol@actionverb.com> to allow loading rails-style yml config files 

require 'sensu-plugin/metric/cli'
require 'mysql'
require 'inifile'
require 'yaml'

class MysqlQueryCountMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'MySQL Host to connect to',

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'MySQL Port to connect to',
         proc: proc(&:to_i),
         default: 3306

  option :username,
         short: '-u USERNAME',
         long: '--user USERNAME',
         description: 'MySQL Username'

  option :password,
         short: '-p PASSWORD',
         long: '--pass PASSWORD',
         description: 'MySQL password',
         default: ''

  option :database,
         short: '-d DATABASE',
         long: '--database DATABASE',
         description: 'MySQL database',
         default: ''

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
         default: 'client'

  option :socket,
         short: '-S SOCKET',
         long: '--socket SOCKET',
         description: 'MySQL Unix socket to connect to'

  option :name,
         short: '-n NAME',
         long: '--name NAME',
         description: 'Metric name for a configured handler',
         default: 'mysql.query_count'

  option :query,
         short: '-q QUERY',
         long: '--query QUERY',
         description: 'Query to execute',
         required: true

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
      db_user    = section['user']
      db_pass    = section['password']
      mysql_host = section['host']
    else
      db_user    = config[:username]
      db_pass    = config[:password]
      mysql_host = config[:hostname]
    end

    db = Mysql.real_connect(mysql_host, db_user, db_pass, config[:database], config[:port].to_i, config[:socket])
    length = db.query(config[:query]).count

    output config[:name], length
    ok

  rescue Mysql::Error => e
    errstr = "Error code: #{e.errno} Error message: #{e.error}"
    critical "#{errstr} SQLSTATE: #{e.sqlstate}" if e.respond_to?('sqlstate')

  rescue => e
    critical e

  ensure
    db.close if db
  end
end
