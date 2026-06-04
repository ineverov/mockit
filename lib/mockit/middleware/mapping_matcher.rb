# frozen_string_literal: true

module Mockit
  module Middleware
    # Responsible for evaluating whether a mapping matches a Rack env.
    # Extracted from MappingFilter to keep matching logic testable and focused.
    class MappingMatcher
      # Returns true if the mapping matches the given Rack env.
      # Matching semantics:
      # - "path": regex string matched against PATH_INFO/REQUEST_PATH
      # - "remote_address": exact string match against REMOTE_ADDR or HTTP_X_FORWARDED_FOR
      # - "headers": hash of header_name => regex_or_value (regex string or literal)
      # - "params": hash of param_name => regex_or_value matched against query string
      def self.match?(mapping, env)
        m = mapping["match"] || {}
        results = {
          path: match_path?(m, env), remote: match_remote?(m, env),
          headers: match_headers?(m, env), params: match_params?(m, env),
          body: match_body?(m, env), body_json: match_body_json?(m, env)
        }
        Mockit.logger.debug("Mockit Match #{env}: #{results}. Mapping: #{mapping}")
        results.values.all?
      end

      def self.match_path?(match, env)
        return true unless match["path"]

        path = env["PATH_INFO"] || env["REQUEST_PATH"]
        safe_regex_match(path, match["path"])
      end

      def self.match_remote?(match, env)
        return true unless match["remote_address"]

        remote = env["REMOTE_ADDR"] || env["HTTP_X_FORWARDED_FOR"]
        remote == match["remote_address"]
      end

      def self.match_headers?(match, env)
        return true unless match["headers"].is_a?(Hash)

        match["headers"].all? { |h_name, h_val| match_header_entry?(h_name, h_val, env) }
      end

      def self.match_params?(match, env)
        return true unless match["params"].is_a?(Hash)

        params_hash = parse_query(env)
        match["params"].all? { |p_name, p_val| match_param_entry?(p_name, p_val, params_hash) }
      end

      def self.match_header_entry?(h_name, h_val, env)
        req_val = header_request_value(env, h_name)
        match_value_with_pattern(req_val, h_val)
      end

      def self.match_param_entry?(p_name, p_val, params_hash)
        req_val = params_hash[p_name.to_s]
        match_value_with_pattern(req_val, p_val)
      end

      def self.match_value_with_pattern(req_val, pattern)
        if pattern.is_a?(String)
          safe_regex_match(req_val, pattern)
        else
          req_val == pattern.to_s
        end
      end

      def self.safe_regex_match(req_val, pattern)
        regex = Regexp.new(pattern)
        !!req_val&.match?(regex)
      rescue RegexpError
        false
      end

      def self.header_request_value(env, h_name)
        env["HTTP_#{h_name.upcase.tr("-", "_")}"]&.to_s
      end

      def self.match_body?(match, env)
        return true unless match["body"]

        safe_regex_match(read_body(env), match["body"])
      end

      def self.match_body_json?(match, env)
        return true unless match["body_json"].is_a?(Hash)

        parsed = JSON.parse(read_body(env))
        match_json_node?(match["body_json"], parsed)
      rescue JSON::ParserError
        false
      end

      def self.match_json_node?(pattern, value)
        case pattern
        when Hash  then match_json_hash?(pattern, value)
        when Array then match_json_array?(pattern, value)
        else            match_value_with_pattern(value&.to_s, pattern)
        end
      end

      def self.match_json_hash?(pattern, value)
        return false unless value.is_a?(Hash)

        pattern.all? { |key, sub| match_json_node?(sub, value[key.to_s]) }
      end

      def self.match_json_array?(pattern, value)
        return false unless value.is_a?(Array)

        pattern.each_with_index.all? { |sub, i| match_json_node?(sub, value[i]) }
      end

      def self.read_body(env)
        env["mockit.body"] ||= read_rack_body(env["rack.input"])
      end

      def self.read_rack_body(input)
        return "" unless input

        body = input.read
        input.rewind
        body
      end

      def self.parse_query(env)
        query = env["QUERY_STRING"] || (env["REQUEST_URI"] && env["REQUEST_URI"].split("?", 2)[1])
        params_hash = {}
        query&.split("&")&.each do |pair|
          k, v = pair.split("=", 2)
          params_hash[k] = v
        end

        params_hash
      end
    end
  end
end
