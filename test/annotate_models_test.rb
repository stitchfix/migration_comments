require File.join(File.dirname(__FILE__), 'test_helper')
gem 'annotate'
require 'annotate/annotate_models'

class Sample < ActiveRecord::Base
  self.table_name = 'sample'
end

class AnnotateModelsTest < Minitest::Unit::TestCase
  include TestHelper

  TEST_PREFIX = "== Schema Information"

  def test_annotate_includes_comments
    ActiveRecord::Schema.define do
      set_table_comment :sample, "a table comment"
      set_column_comment :sample, :field1, "a \"comment\" \\ that ' needs; escaping''"
      add_column :sample, :field3, :string, :null => false, :default => '', :comment => "third column comment"
    end
    Sample.reset_column_information

    result = AnnotateModels.get_schema_info(Sample, TEST_PREFIX)
    expected = <<EOS
# #{TEST_PREFIX}
#
# Table name: sample # a table comment
#
#  id     :integer __SPACES__ not null, primary key
#  field1 __STR_COL__ __SPACES__ # a "comment" \\ that ' needs; escaping''
#  field2 :integer
#  field3 __STR_COL__ __SPACES__ default(""), not null # third column comment
#
EOS
    assert_match regex_escaped(expected), result
  end

  private

  def regex_escaped(expected)
    /#{Regexp.escape(expected).gsub(/__SPACES__/, ' +').gsub(/__STR_COL__/, ':string(\(255\))?')}/
  end
end

