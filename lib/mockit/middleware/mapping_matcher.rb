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
        match = mapping["match"] || {}

        path = match_path?(match, env)
        remote = match_remote?(match, env)
        headers = match_headers?(match, env)
        params = match_params?(match, env)

        Mockit.logger.debug <<-INFO
          Mockit Match #{env}: path #{path}; remote #{remote}; headers #{headers}; params #{params}.
          Mapping: #{mapping}
        INFO

        path && remote && headers && params
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

        match["headers"].each do |h_name, h_val|
          return false unless match_header_entry?(h_name, h_val, env)
        end

        true
      end

      def self.match_params?(match, env)
        return true unless match["params"].is_a?(Hash)

        params_hash = parse_query(env)

        match["params"].each do |p_name, p_val|
          return false unless match_param_entry?(p_name, p_val, params_hash)
        end

        true
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
        val = env["HTTP_#{h_name.upcase.tr("-", "_")}"]
        val = val.to_s unless val.nil?
        val
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
