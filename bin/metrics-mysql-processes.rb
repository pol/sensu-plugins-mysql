#!/opt/sensu/embedded/bin/ruby
#
# metrics-mysql-processes
#
# DESCRIPTION:
#   Gets metrics out of of MySQL's "SHOW PROCESSLIST" query.
#
#   Output number of connections per-users, number of connections
#   per-databases, number of the different commands running.
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mysql
#
# USAGE:
#   This was implemented to load mysql credentials without parsing the username/password.
#   The ini file should be readable by the sensu user/group.
#   Ref: http://eric.lubow.org/2009/ruby/parsing-ini-files-with-ruby/
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
# NOTES:
#
# LICENSE:
#   Jonathan Ballet <jballet@edgelab.ch>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
# Modified by Pol Llovet <pol@actionverb.com> to allow loading rails-style yml config files 
#


require 'sensu-plugin/metric/cli'
require 'mysql'
require 'socket'
require 'inifile'
require 'yaml'

class MetricsMySQLProcesses < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'MySQL Host to connect to',
         required: true

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

  option :ini,
         short: '-i',
         long: '--ini VALUE',
         description: 'My.cnf ini file'

  option :yaml,
         short: '-y',
         long: '--yaml VALUE',
         description: 'My.cnf yaml file'

  option :ini_section,
         description: 'Section in my.cnf ini file',
         long: '--ini-section VALUE',
         default: 'production'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.mysql"

  option :socket,
         short: '-S SOCKET',
         long: '--socket SOCKET',
         description: 'MySQL Unix socket to connect to'

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
      mysql_host = config[:host]
    end

    mysql_shorthostname = mysql_host.split('.')[0]

    begin
      mysql = Mysql.new(mysql_host, db_user, db_pass, nil, config[:port], config[:socket])

      results = mysql.query('SHOW PROCESSLIST')
    rescue => e
      unknown "Unable to query MySQL: #{e.message}"
    end

    metrics = {
      'user' => {},
      'database' => {},
      'time' => {},
      'command' => {}
    }

    metrics.each_value { |value| value.default = 0 }
    index = 0

    results.each_hash do |row|
      index += 1
      metrics['user'][row['User']] += 1
      if row['db'] # If no database has been selected by the process, it is set to nil.
        metrics['database'][row['db']] += 1
      end
      metrics['command'][row['Command']] += 1
      metrics['time'][row['Command']] += row['Time'].to_i
    end

    metrics.each do |key, value|
      value.each do |instance, count|
        output "#{config[:scheme]}.#{mysql_shorthostname}.#{key}.#{instance}", count
      end
    end

    ok
  end
end