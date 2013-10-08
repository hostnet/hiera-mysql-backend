class Hiera
  module Backend
    class Mysql_backend

      def initialize(cache=nil)
        begin
          require 'mysql2'
        rescue LoadError
          require 'rubygems'
          require 'mysql2'
        end

        @cache = cache || Filecache.new

        Hiera.debug("Hiera MySQL initialized")
      end

      def lookup(key, scope, order_override, resolution_type)
        # default answer just to make it easier on ourselves

        Hiera.debug("looking up %{key} in MySQL Backend")
        Hiera.debug("resolution type is #{resolution_type}")

        Backend.datasources(scope, order_override) do |source|
          Hiera.debug("Looking for data source #{source}")
          sqlfile = Backend.datafile(:mysql, scope, source, "sql") || next

          next unless File.exist?(sqlfile)
          data = @cache.read(sqlfile, Hash, {}) do |datafile|
            YAML.load(datafile)
          end

          next if data.empty?
          next unless data.include?(key)

          Hiera.debug("Found #{key} in #{source}")

          new_answer = Backend.parse_answer(data[key], scope)
          results = query(new_answer)
          return results
        end
      end


      def query(query)
        Hiera.debug("Executing SQL Query: #{query}")

        data=[]
        mysql_host = Config[:mysql][:host]
        mysql_user = Config[:mysql][:user]
        mysql_pass = Config[:mysql][:pass]
        mysql_database = Config[:mysql][:database]
        client = Mysql2::Client.new(:host => mysql_host, 
                                    :username => mysql_user, 
                                    :password => mysql_pass, 
                                    :database => mysql_database,
                                    :reconnect => true)
        begin
          data = client.query(query).to_a
          Hiera.debug("Mysql Query returned #{data.size} rows")
        rescue => e
          Hiera.debug e.message
          data = nil
        end

        return data

      end
    end
  end
end