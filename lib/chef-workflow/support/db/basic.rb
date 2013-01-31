require 'chef-workflow/support/db'

module ChefWorkflow
  class DatabaseSupport
    class Generic
      attr_accessor :db

      def initialize(table_name, object_name=nil)
        raise "a table_name must be provided!" unless table_name

        @table_name   = table_name
        @object_name  = object_name
        post_marshal_init
        create_table
      end

      def self._load(value)
        obj = self.new(*Marshal.load(value))
        return obj
      end

      def _dump(level)
        self.db = nil
        res = Marshal.dump([@table_name, @object_name])
        post_marshal_init
        return res
      end

      def post_marshal_init
        @db = ChefWorkflow::DatabaseSupport.instance
      end

      def create_table
        raise "Do not use the Generic type directly!"
      end
    end

    class Object < Generic
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

    class Collection < Generic
      include Enumerable

      def initialize(table_name, object_name)
        raise "an object_name must be provided!" unless object_name
        super
      end
    end

    class List < Collection
      def push(val)
        @db.execute(
          "insert into #{@table_name} (name, value) values (?, ?)",
          [@object_name, Marshal.dump(val)]
        )
      end

      alias << push

      def unshift(val)
        replace([val] + to_a)
      end

      def shift
        to_a.shift
      end

      def pop
        to_a.pop
      end

      def replace(ary)
        clear

        value_string = ("(?, ?)," * ary.count).chop

        @db.execute(
          "insert into #{@table_name} (name, value) values #{value_string}",
          ary.map { |x| [@object_name, Marshal.dump(x)] }.flatten
        )
      end

      def clear
        @db.execute("delete from #{@table_name} where name=?", [@object_name])
      end

      def each
        to_a.each { |x| yield x }
      end

      def to_a
        @db.execute(
            "select value from #{@table_name} where name=? order by id", 
            [@object_name]
        ).map { |x| Marshal.load(x.first) }
      end

      def create_table
        @db.execute <<-EOF
        create table if not exists #{@table_name} (
          id integer not null primary key autoincrement,
          name varchar(255) not null,
          value text not null
        )
        EOF

        @db.execute "create index if not exists #{@table_name}_name_index on #{@table_name} (name)"
      end
    end

    class Set < Collection
      def add(key)
        @db.execute("insert into #{@table_name} (name, key) values (?, ?)", [@object_name, key])
      end

      def delete(key)
        @db.execute("delete from #{@table_name} where name=? and key=?", [@object_name, key])
      end

      def has_key?(key)
        @db.execute("select count(*) from #{@table_name} where name=? and key=?", [@object_name, key]).first.first.to_i > 0
      end

      alias include? has_key?

      def clear
        @db.execute("delete from #{@table_name} where name=?", [@object_name])
      end

      def replace(set)
        clear

        return if set.empty?

        value_string = ("(?, ?)," * set.count).chop

        @db.execute("insert into #{@table_name} (name, key) values #{value_string}", set.map { |x| [@object_name, x] }.flatten)
      end

      def keys
        @db.execute("select key from #{@table_name} where name=?", [@object_name]).map(&:first)
      end

      def each
        keys.each { |x| yield x }
      end

      def create_table
        @db.execute <<-EOF
        create table if not exists #{@table_name} (
          id integer not null primary key autoincrement,
          name varchar(255) not null,
          key varchar(255) not null,
          UNIQUE(name, key) 
        )
        EOF

        @db.execute "create index if not exists #{@table_name}_name_idx on #{@table_name} (name)"
      end
    end

    class Map < Set
      def [](key)
        value = @db.execute("select value from #{@table_name} where name=? and key=?", [@object_name, key]).first.first rescue nil
        return value && Marshal.load(value) 
      end

      def []=(key, value)
        delete(key)
        @db.execute("insert into #{@table_name} (name, key, value) values (?, ?, ?)", [@object_name, key, Marshal.dump(value)])
        value
      end

      def each
        keys.each do |key|
          yield key, self[key]
        end
      end

      def to_hash
        rows = @db.execute("select key, value from #{@table_name} where name=?", [@object_name])
        Hash[rows.map { |x| [x[0], Marshal.load(x[1])] }]
      end

      def create_table
        @db.execute <<-EOF
        create table if not exists #{@table_name} (
          id integer not null primary key autoincrement,
          name varchar(255) not null,
          key varchar(255) not null,
          value text not null,
          UNIQUE(name, key)
        )
        EOF

        @db.execute "create index if not exists #{@table_name}_name_idx on #{@table_name} (name)"
      end
    end
  end
end
