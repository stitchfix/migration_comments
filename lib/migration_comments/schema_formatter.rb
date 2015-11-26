module MigrationComments
  module SchemaFormatter
    def render_comment(comment)
      render_kv_pair(:comment, comment)
    end

    def render_kv_pair(key, value)
      "#{key}: #{render_value(value)}"
    end

    def render_value(value)
      case value
        when String
          %Q[#{value}].inspect
        when Symbol
          ":#{value}"
        else
          value
      end
    end
  end
end
