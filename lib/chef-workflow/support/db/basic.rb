module ChefWorkflow
  class DatabaseSupport
    class Object

      attr_accessor :db

      def initialize(table_name)
        @table_name = table_name
        post_marshal_init
        create_table
      end

      def [](key)
        value = @db.execute("select value from #{@table_name} where key=?", [key]).first.first rescue nil
        return value && Marshal.load(value)
      end

      def []=(key, value)
        delete(key)
        @db.execute("insert into #{@table_name} (key, value) values (?, ?)", [key, Marshal.dump(value)])
        value
      end

      def delete(key)
        @db.execute("delete from #{@table_name} where key=?", [key])
      end

      def self._load(value)
        obj = self.new(*Marshal.load(value))
        return obj
      end

      def _dump(level)
        self.db = nil
        res = Marshal.dump([@table_name])
        post_marshal_init
        return res
      end

      def post_marshal_init
        @db = ChefWorkflow::DatabaseSupport.instance
      end

      def create_table
        @db.execute <<-EOF
        create table if not exists #{@table_name} (
          id integer not null primary key autoincrement,
          key varchar(255) not null,
          value text not null,
          UNIQUE(key)
        )
        EOF
      end
    end
  end
end
