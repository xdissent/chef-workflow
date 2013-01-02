require 'chef-workflow/support/db'

module ChefWorkflow
  class DatabaseSupport
    class VMGroup
      include Enumerable

      def initialize(table_name, box_nil)
        raise "Must provide a table name!" unless table_name
        @table_name = table_name
        @box_nil = box_nil
        @db = ChefWorkflow::DatabaseSupport.instance
        create_table
      end

      def [](key)
        rows = @db.execute("select value from #{@table_name} where name=? order by id", [key])
        if rows.count == 0 
          @box_nil ? [] : nil 
        else
          rows.to_a.map { |x| Marshal.load(x.first) }
        end
      end

      def []=(key, value)
        delete(key)

        return value if value.empty?

        values = value.map { |x| Marshal.dump(x) }
        value_string = ("(?, ?)," * values.count).chop

        @db.execute("insert into #{@table_name} (name, value) values #{value_string}", values.map { |x| [key, x] }.flatten)
      end

      def keys
        @db.execute("select name from #{@table_name}").map(&:first)
      end

      def delete(key)
        @db.execute("delete from #{@table_name} where name=?", [key])
      end

      def has_key?(key)
        @db.execute("select count(*) from #{@table_name} where name=?", [key]).first.first.to_i > 0
      end

      def each
        # XXX very slow, but fuck it
        keys.each do |key|
          yield key, self[key]
        end
      end

      private

      def create_table
        @db.execute <<-EOF
        create table if not exists #{@table_name} (
          id integer not null primary key autoincrement,
          name varchar(255) not null,
          value text not null
        )
        EOF

        @db.execute <<-EOF
        create index if not exists #{@table_name}_name_index on #{@table_name} (name)
        EOF
      end
    end
  end
end
