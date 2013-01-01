require 'chef-workflow/support/db'

module ChefWorkflow
  class DatabaseSupport
    class VMGroup
      include Enumerable

      def initialize(clean=false)
        @db = ChefWorkflow::DatabaseSupport.instance
        drop_table if clean
        create_table
      end

      def [](key)
        rows = @db.execute("select provisioner from vm_groups where name=? order by id", [key])
        rows.count == 0 ? nil : rows.to_a.map { |x| Marshal.load(x.first) }
      end

      def []=(key, value)
        delete(key)

        values = value.map { |x| Marshal.dump(x) }
        value_string = ("(?, ?)," * values.count).chop

        @db.execute("insert into vm_groups (name, provisioner) values #{value_string}", values.map { |x| [key, x] }.flatten)
      end

      def keys
        @db.execute("select name from vm_groups").map(&:first)
      end

      def delete(key)
        @db.execute("delete from vm_groups where name=?", [key])
      end

      def has_key?(key)
        @db.execute("select count(*) from vm_groups where name=?", [key]).count > 0
      end

      def each
        # XXX very slow, but fuck it
        keys.each do |key|
          yield self[key]
        end
      end

      private

      def drop_table
        @db.execute "drop table if exists vm_groups"
      end

      def create_table
        @db.execute <<-EOF
        create table if not exists vm_groups (
          id integer not null primary key autoincrement,
          name varchar(255) not null,
          provisioner text not null
        )
        EOF

        @db.execute <<-EOF
        create index if not exists vm_group_name_index on vm_groups (name)
        EOF
      end
    end
  end
end
