require File.join(File.dirname(__FILE__), 'test_helper')

class SchemaDumperTest < Minitest::Unit::TestCase
  include TestHelper
  include MigrationComments::SchemaFormatter

  def test_dump
    ActiveRecord::Schema.define do
      set_table_comment :sample, "a table comment"
      set_column_comment :sample, :field1, "a \"comment\" \\ that ' needs; escaping''"
      add_column :sample, :field3, :string, :null => false, :default => "", :comment => "third column comment"
    end
    Sample.reset_column_information

    dest = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, dest)
    dest.rewind
    result = dest.read
    expected = <<EOS
  create_table "sample", #{render_kv_pair(:force, :cascade)}, #{render_kv_pair(:comment, "a table comment")} do |t|
    t.string  "field1"__MYSQL_LIMIT255__, __SPACES__#{render_kv_pair(:comment, %{a \"comment\" \\ that ' needs; escaping''})}
    t.integer "field2"__MYSQL_LIMIT4__
    t.string  "field3"__MYSQL_LIMIT255__, #{render_kv_pair(:default, "")}, #{render_kv_pair(:null, false)}, #{render_kv_pair(:comment, "third column comment")}
  end
EOS
    assert_match regex_escape(expected), result
  end

  def test_dump_with_no_columns
    ActiveRecord::Schema.define do
      remove_column :sample, :field1
      remove_column :sample, :field2
      set_table_comment :sample, "a table comment"
    end
    Sample.reset_column_information

    dest = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, dest)
    dest.rewind
    result = dest.read
    expected = <<EOS
  create_table "sample", #{render_kv_pair(:force, :cascade)}, #{render_kv_pair(:comment, "a table comment")} do |t|
  end
EOS

    assert_match regex_escape(expected), result
  end

  def test_schema_dump_with_custom_type_error_for_pg
    return unless ENV['DB'] == 'postgres'
    ActiveRecord::Base.connection.execute "DROP TYPE IF EXISTS my_custom_type; CREATE TYPE my_custom_type AS ENUM('thing1', 'thing2');"
    ActiveRecord::Base.connection.execute "ALTER TABLE sample ALTER COLUMN field2 TYPE my_custom_type USING 'thing1';"

    ActiveRecord::Schema.define do
      set_table_comment :sample, "a table comment"
      set_column_comment :sample, :field1, "column comment"
    end
    Sample.reset_column_information

    dest = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, dest)
    dest.rewind
    result = dest.read

    expected = <<EOS
# Could not dump table "sample" because of following StandardError
#   Unknown type 'my_custom_type' for column 'field2'
EOS

    assert_match regex_escape(expected), result
  end

  private

  def regex_escape(expected)
    /#{Regexp.escape(expected).
        gsub(/__SPACES__/, " +").
        gsub(/__MYSQL_LIMIT(\d+)__/){|s| ENV['DB'] == 'mysql' ? ", #{render_kv_pair(:limit, $1.to_i)}" : '' }}/
  end
end
