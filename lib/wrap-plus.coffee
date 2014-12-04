# Wrap Plus.

{Range} = require 'atom'
{PrefixStrip} = require './prefix-strip'
{Wrap} = require './wrap'

# Various utilities.
startsWith = (s, text) ->
  s[0..text.length] == s

# Various patterns.

# This doesn't always work, but seems decent.
numberedList = '(?:(?:[0-9#]+[.)])+[\t ])'
# This should probably handle things like "ii.", but I fear adding
# a repeat would significantly raise the chance of a false positive.
letteredList = '(?:(?:[\\w][.)])+[\t ])'
bulletList = '(?:[*+#-]+[\t ])'
listPattern = ///
  ^[\t\ ]*           # Starts with optional whitespace.
  (?:
    (?:#{numberedList}) |
    (?:#{letteredList}) |
    (?:#{bulletList})
  ) [\t\ ]*          # Optional trailing whitespace.
///
fieldStart = '(?:[:@])'  # rest, javadoc, jsdoc, etc.
# XXX: Does not handle escaped colons in field name.
fieldPattern = ///
  ^([ \t]*)
  (?:
    (?::[^:]+:) |
    (?:@[a-zA-Z]+[ ])
  )
///

newParagraphPattern = ///
  ^(?:
    (?:[\t\ ]*)          # Starts with optional whitespace.
    (?:#{numberedList}) |
    (?:#{letteredList}) |
    (?:#{bulletList}) |
    (?:#{fieldStart})
  )
///

latexHack = '(:?\\\\)'
restDirective = '(:?\\.\\.)'
sepChars = '!@#$%^&*=+`~\'\":;.,?_-'
sepLine = "(?:[#{sepChars}]+[ \\t#{sepChars}]*)"

# Break pattern is a little ambiguous.  Something like "# Header" could also be
# a list element.
breakPattern = ///
    ^
    (?:[\t\ ]*)      # Starts with optional space.
    (?:
      #{sepLine} |  # A separator line, or:
      (?:(?:#{latexHack}) | (?:#{restDirective}).*)  # Special patterns at the
                                                     # beginning of the line.
    )
    $
///
pureBreakPattern = ///^[\t\ ]*#{sepLine}$///

spacePrefixPattern = /^[ \t]*/



module.exports =

  activate: (state) ->
    atom.commands.add '.editor',
      'wrap-plus:rewrap': (event) => @rewrap

  rewrap: ->
    if editor = atom.workspace.getActiveEditor()
      width = @getPreferredLineLength()
      tabLength = editor.getTabLength()
      {bc, lc} = @determineCommentStyle(editor)

      paragraphs = []
      for range in editor.getSelectedBufferRanges()
        Array::push.apply paragraphs @findParagraphs(editor, range)

      for paragraph in paragraphs
        {range, lines, requiredCommentPrefix} = paragraph
        {initialPrefix, subsequentPrefix, lines} = @extractPrefix(
          editor, range, lines, requiredCommentPrefix)
        newLines = Wrap.wrap lines
          width: width
          tabLength: tabLength
          initialPrefix: initialPrefix
          subsequentPrefix: subsequentPrefix
        # TODO: add trailing newline?
        # TODO: \r\n?
        editor.setTextInBufferRange(range, newLines.join('\n'))
        # XXX: Cursor position?

  # Returns an array of {range, lines, requiredCommentPrefix} objects.
  findParagraphs: (editor, range) ->
    result = []
    if range.isEmpty()
      isEmpty = true
      minRow = 0
      maxRow = editor.getLineCount()-1
    else
      isEmpty = false
      minRow = range.start.row
      maxRow = range.end.row
      if range.end.column == 0
        maxRow -= 1

    startedInComment = @pointIsComment(editor, range.start)
    maxRowColumns = editor.lineLengthForBufferRow(maxRow)
    expandedRange = new Range([minRow, 0], [maxRow, maxRowColumns])
    prefixStripper = new PrefixStrip(editor, expandedRange)

    # Loop for each paragraph (only loops once if sr is empty).
    paragraphStartPoint = range.start
    loop
      # Accumulate the lines for this paragraph.
      lines = []

      if isEmpty
        # Find the beginning of this paragraph.
        [currentRowText, currentRowRange] = @findParagraphStart(prefixStripper,
                                                         paragraphStartPoint)
      else
        # The selection defines the beginning.
        [currentRowText, currentRowRange] = prefixStripper.getLine(paragraphStartPoint.row)

      # Skip blank and unambiguous break lines.
      loop
        if not @isParagraphBreak(editor, currentRowText, currentRowRange.start.row, pure=true)
          break
        if isEmpty
          return []
        # Get next line.
        [currentRowText, currentRowRange] = prefixStripper.getLine(currentRowRange.start.row+1)
        # TODO: Check for null here?

      paragraphStartPt = currentRowRange.start
      paragraphEndPt = currentRowRange.end
      # currentRowRange now points to the beginning of the paragraph.
      # Move down until the end of the paragraph.
      loop
        # If we started in a non-comment scope, and the end of the
        # line contains a comment, include any non-comment text in the
        # wrap and stop looking for more.
        if not startedInComment and @pointIsComment(editor, currentRowRange.end)
          # Find the start of the comment.
          # This assumes comments do not have multiple scopes.
          throw new Error("TODO")

        lines.push(currentRowText)
        paragraphEndPt = currentRowRange.end

        # Get next line.
        [currentRowText, currentRowRange] = prefixStripper.getLine(currentRowRange.start.row+1)
        if currentRowText == null
          # Line is outside of our range.
          break
        if @isParagraphBreak(editor, currentRowText, currentRowRange.start.row)
          break
        if @isParagraphStart(currentRowText)
          break

      paragraphRange = new Range(paragraphStartPt, paragraphEndPt)
      result.push
        range: paragraphRange
        lines: lines
        requiredCommentPrefix: prefixStripper.requiredCommentPrefix

      if isEmpty
        break

      # Skip over blank lines and break lines till the next paragraph (or end
      # of range).
      while currentRowRange != null
        if @isParagraphStart(currentRowText)
          break
        if @isParagraphBreak(editor, currentRowText, currentRowRange.start.row)
          break
        # It's a paragraph break, skip over it.
        [currentRowText, currentRowRange] = prefixStripper.getLine(currentRowRange.start.row+1)

      if currentRowRange == null
        break

      paragraphStartPt = currentRowRange.start
      if paragraphStartPt.row >= maxRow
        break

    return result

  # Starts at the given point, and moves upwards trying to determine where a
  # paragraph starts.
  #
  # Returns [rowText, rowRange] of the first line of the paragraph.
  findParagraphStart: (prefixStripper, pt) ->
    editor = prefixStripper.editor
    [currentRowText, currentRowRange] = prefixStripper.getLine(pt.row)
    startedInComment = @pointIsComment(editor, pt)

    if @isParagraphBreak(editor, currentRowText, currentRowRange.start.row)
      return [currentRowText, currentRowRange]

    loop
      # Check if this line is a start of a paragraph.
      if @isParagraphStart(currentRowText)
        break
      # Check if the previous line is a "break" separator.
      [prevRowText, prevRowRange] = prefixStripper.getLine(currentRowRange.start.row-1)
      if prevRowText == null
        # Cannot go further up.
        break
      if @isParagraphBreak(editor, prevRowText, prevRowRange.start.row)
        break
      # If the previous line has a comment, and we started in a
      # non-comment scope, stop.  No need to check for comment to
      # non-comment change because the prefix restrictions should handle
      # that.
      if not startedInComment and @pointIsComment(editor, prevRowRange.end)
        break
      currentRowText = prevRowText
      currentRowRange = prevRowRange

    return [currentRowText, currentRowRange]

  scopeMatch: (editor, pt, scope) ->
    # Would prefer TextMate-style scoring.
    scopes = editor.scopesForBufferPosition(pt)
    return scopes.some (x) -> x.indexOf(scope) != -1

  pointIsComment: (editor, pt) ->
    return @scopeMatch(editor, pt, 'comment')

  # Determines if the given line looks like the beginning of a paragraph.
  isParagraphStart: (line) ->
    return line.match(newParagraphPattern) != null

  # Determine if the given line is a break between paragraphs.
  isParagraphBreak: (editor, line, rowNum, pure=false) ->
    # Blank lines count as a break.
    if line.match(/^[\t ]*$/)
      return true
    # This helps with markdown.
    if @scopeMatch(editor, [rowNum, 0], 'heading')
      return true
    if pure
      return line.match(pureBreakPattern) != null
    else
      return line.match(breakPattern) != null

  getPreferredLineLength: ->
    atom.config.getPositiveInt('editor.preferredLineLength', 80)

  determineCommentStyle: (editor) ->
    # Is there a better way to get the top-level scope of the editor?
    scopes = editor.scopesForBufferPosition([0, 0])
    properties = atom.syntax.propertiesForScope(scopes, "editor.commentStart")
    return unless properties

    bc = []
    lc = []
    for props in properties
      if props.editor.commentEnd
        bc.push
          start: props.editor.commentStart.trim()
          end: props.editor.commentEnd.trim()
      else
        lc.push(props.editor.commentStart.trim())

    return {bc, lc}

  # This determines what the prefix of the first and subsequent lines should be.
  # Prefixes that are already part of the text will be removed.
  # Returns object {initialPrefix, subsequentPrefix, lines}
  extractPrefix: (editor, range, lines, requiredCommentPrefix) ->
    # Comment prefixes have already been removed by the PrefixStrip.
    tabLength = editor.getTabLength()
    initialPrefix = ''
    subsequentPrefix = ''
    firstLine = lines[0]
    m = firstLine.match(listPattern)
    if m
      matchLength = m[0].length
      initialPrefix = firstLine[0...matchLength]
      spaceLength = @widthInSpaces(initialPrefix, tabLength)
      subsequentPrefix = Array(spaceLength).join(' ')
    else
      m = firstLine.match(fieldPattern)
      if m
        # The spaces in front of the field start.
        initialPrefix = m[1].length
        if lines.length > 1
          # How to handle subsequent lines.
          m = lines[1].match(spacePrefixPattern)
          if m
            # It's already indented, keep this indent level
            # (unless it is less than where the field started).
            spaces = m[0]
            if @widthInSpaces(spaces, tabLength) >=
               @widthInSpaces(initialPrefix, tabLength)+1
              subsequentPrefix = spaces
        if not subsequent_prefix
          # Not already indented, make an indent.
          # This is suboptimal.  I don't remember why, but there were problems
          # using tabLength.
          subsequent_prefix = initialPrefix + '    '
      else
        m = firstLine.match(spacePrefixPattern)
        if m
          matchLength = m[0].length
          initialPrefix = firstLine[0...matchLength]
          if lines.length > 1
            m = lines[1].match(spacePrefixPattern)
            if m
              matchLength = m[0].length
              subsequentPrefix = lines[1][0...matchLength]
            else
              subsequentPrefix = ''
          else
            subsequentPrefix = initialPrefix
        else
          # This should never happen.
          initialPrefix = ''
          subsequentPrefix = ''

      # TODO: quoted string.

      # Remove the prefixes that are already in the text.
      newLines = []
      newLines.push(firstLine[initialPrefix.length...].trim())
      for line in lines[1...]
        if startsWith(line, subsequentPrefix)
          line = line[subsequentPrefix.length...]
        newLines.push(line)

      return {
        initialPrefix:    requiredCommentPrefix + initialPrefix
        subsequentPrefix: requiredCommentPrefix + subsequentPrefix
        lines:            newLines
      }

  widthInSpaces: (row, tabLength) ->
    # This is probably broken, use expandTabs?
    tabCount = (row.match(/\t/g) or []).length
    return tabCount*tabLength + row.length - tabCount
