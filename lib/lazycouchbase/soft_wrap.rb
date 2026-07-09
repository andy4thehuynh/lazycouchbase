# frozen_string_literal: true

module Lazycouchbase
  # Breaks a long line into width-sized segments, preserving the original
  # leading indentation and indenting continuations four columns further so
  # wrapped JSON still reads as JSON. Prefers breaking at spaces.
  module SoftWrap
    CONTINUATION = 4

    module_function

    def wrap(text, width)
      pad = "#{text[/\A */]}#{" " * CONTINUATION}"
      return [text] if text.length <= width || width <= pad.length + 1

      segments = []
      rest = text
      while rest.length > width
        cut = break_position(rest, width, pad.length)
        segments << rest[0...cut]
        rest = "#{pad}#{rest[cut..].lstrip}"
      end
      segments << rest
    end

    def break_position(text, width, minimum)
      space = text.rindex(" ", width)
      space && space > minimum ? space : width
    end
  end
end
