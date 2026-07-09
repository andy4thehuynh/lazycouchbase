# frozen_string_literal: true

require "json"

module Lazycouchbase
  # Pretty-prints parsed JSON into logical lines annotated with the dot-path
  # and node each line represents, mirroring JSON.pretty_generate's 2-space
  # layout. The annotations power the document view's breadcrumb, value
  # yanking, and keys-only outline.
  class JsonDocument
    Line = Data.define(:text, :path, :node, :key)
    OutlineEntry = Data.define(:text, :line)

    attr_reader :lines, :outline

    def initialize(content)
      @lines = []
      @outline = []
      write(content, path: "", key: nil, indent: 0, comma: false)
    end

    private

    def write(node, path:, key:, indent:, comma:)
      @outline << OutlineEntry.new(text: "#{"  " * (indent - 1)}#{key}", line: @lines.size) if key

      case node
      when Hash then write_hash(node, path: path, key: key, indent: indent, comma: comma)
      when Array then write_array(node, path: path, key: key, indent: indent, comma: comma)
      else push("#{label(key, indent)}#{node.to_json}#{tail(comma)}", path, node, key)
      end
    end

    def write_hash(node, path:, key:, indent:, comma:)
      return push("#{label(key, indent)}{}#{tail(comma)}", path, node, key) if node.empty?

      push("#{label(key, indent)}{", path, node, key)
      node.each_with_index do |(child_key, child), position|
        name = child_key.to_s
        write(child, path: join(path, name), key: name, indent: indent + 1, comma: position < node.size - 1)
      end
      push("#{"  " * indent}}#{tail(comma)}", path, node, nil)
    end

    def write_array(node, path:, key:, indent:, comma:)
      return push("#{label(key, indent)}[]#{tail(comma)}", path, node, key) if node.empty?

      push("#{label(key, indent)}[", path, node, key)
      node.each_with_index do |child, position|
        write(child, path: "#{path}[#{position}]", key: nil, indent: indent + 1, comma: position < node.size - 1)
      end
      push("#{"  " * indent}]#{tail(comma)}", path, node, nil)
    end

    def label(key, indent)
      prefix = "  " * indent
      key ? "#{prefix}#{key.to_json}: " : prefix
    end

    def tail(comma)
      comma ? "," : ""
    end

    def join(path, key)
      path.empty? ? key : "#{path}.#{key}"
    end

    def push(text, path, node, key)
      @lines << Line.new(text: text, path: path, node: node, key: key)
    end
  end
end
