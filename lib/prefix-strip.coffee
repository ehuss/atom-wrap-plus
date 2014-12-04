{Range} = require 'atom'

# This prevides an interface to fetch lines from the buffer and strip leading
# text (like comment characters).
#
# It also enforces a range restriction.  If you try to fetch text outside
# of its boundaries, it will return null.
class PrefixStrip
  constructor: (@editor, @restrictRange) ->

  setComments: (lc, bc, pt) ->
    # If the line at pt is inside a comment, set requiredCommentPrefix to the
    # prefix we need.
    @lc = lc
    @bc = bc
    @requiredCommentPrefix = ''
    @requiredCommentPattern = null
    text = @editor.lineForBufferRow(pt.row)
    textTrim = text.trim()
    if textTrim.length == 0
      return

    # Determine if pt is inside a "line comment".
    # Only whitespace is allowed to the left of the line comment.
    for lcStr in lc
      if textTrim.indexOf(lcStr) == 0
        ldiff = text.search(/\S/)
        @requiredCommentPrefix = text[...ldiff+lcStr.length]
        break

    # TODO: Regexp escape requiredCommentPrefix.

    # Handle email-style quoting.
    emailQuotePattern = RegExp('^' + @requiredCommentPrefix + '[\\t ]*>[>\\t ]*')
    m = text.match(emailQuotePattern)
    if m
      @requiredCommentPrefix = m[0]
      @requiredCommentPattern = emailQuotePattern

    # Check for C-style comments with each line starting with an asterisk.
    # TODO: Need to figure out a way to determine the range of a block comment.
    # scopes = @editor.scopesForBufferPosition(pt)
    # if scopes.some (x) -> x.indexOf('comment.block') != -1
    #   # Extract the entire range of this comment block.
    #   @editor.displayBuffer.bufferRangeForScopeAtPosition()

    # Narrow the min/max range if inside a "quoted" string.
    # TODO: Need to figure out a way to determine the range of a quoted string.

  # Get a line of text for the given row number.
  # Returns [Range, text] of the line.  Returns [null, null] if the line is
  # not valid.
  getLine: (row) ->
    if row < @restrictRange.start.row or row > @restrictRange.end.row
      return [null, null]

    text = @editor.lineForBufferRow(row)
    realLineLength = text.length
    lineRange = new Range([row, 0], [row, realLineLength])

    # Constrain to the range.
    if @restrictRange.start.row == row and @restrictRange.start.column > 0
      text = text[@restrictRange.start.column...]
      lineRange = new Range([row, @restrictRange.start.column], lineRange.end)
    if @restrictRange.end.row == row and @restrictRange.end.column < realLineLength
      toCut = realLineLength - @restrictRange.end.column
      text = text[...text.length-toCut]
      lineRange = new Range(lineRange.start, [row, lineRange.end.column-toCut])

    if @requiredCommentPrefix
      # If it starts with the prefix.
      if text[0...@requiredCommentPrefix.length] == @requiredCommentPrefix
        # Check for regex pattern requirement.
        if @requiredCommentPattern
          m = text.match(@requiredCommentPattern)
          if m
            if m[0] != @requiredCommentPrefix
              # This might happen, if for example with an email
              # comment, we go from one comment level to a
              # deeper one (the regex matched more > characters
              # than are in requiredCommentPattern).
              return [null, null]
          else
            # This should never happen.
            return [null, null]
        text = text[@requiredCommentPrefix.length...]
        lineRange = newRange([row, lineRange.start.column+@requiredCommentPrefix.length],
                               lineRange.end)
      else
        # Does not start with required prefix.
        return [null, null]
    return [text, lineRange]

module.exports = {PrefixStrip}
