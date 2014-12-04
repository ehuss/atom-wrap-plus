# This wrap code is blatently borrowed from Python's textwrap module.

# Convert tabs to spaces.
expandTabs = (text, tabLength) ->
  if '\t' not in text
    return text
  result = []
  j = 0
  for i in [0...text.length]
    ch = text[i]
    if ch == '\t'
      width = tabLength - (j % tabLength)
      j += width
      for _ in [0...width]
        result.push(' ')
    else
      result.push(ch)
      j += 1
      if ch == '\n' or ch == '\r'
        j = 0
  return result.join('')

# Word-wrap the given text.
#
# text - A {String} or {Array} of strings to wrap.
# options - Optional object of options:
#           * width - The maximum width of a line (default 80).
#           * tabLength - The length of a tab, default 4.  Tabs will be
#                         converted to spaces.
#           * initialPrefix - A string to include at the beginning of the first
#                             line.
#           * subsequentPrefix - A string to include at the beginning of the
#                                second and subsequent lines.
#
# Returns an {Array} of {String}s, for each line.
wrap = (text, options = {}) ->
  tabLength = options.tabLength ? 4
  if (text instanceof Array)
    strings = text
  else
    strings = [text]
  strings = strings.map((x) -> expandTabs(x, tabLength))
  strings = strings.map((x) -> x.replace(/\s/g, ' '))
  chunks = splitChunks(strings)
  lines = wrapChunks(chunks, options)
  return lines

splitChunks = (strings) ->
  result = []
  for s in strings
    chunks = s.split(/(\s+)/)
    # Remove empty strings (only if string ends with whitespace?).
    chunks = chunks.filter((x) -> x != '')
    Array::push.apply(result, chunks)
  return result

wrapChunks = (chunks, options) ->
  width = options.width ? 80
  initialPrefix = options.initialPrefix ? ''
  subsequentPrefix = options.subsequentPrefix ? ''
  tabLength = options.tabLength ? 4
  lines = []
  chunks.reverse()
  while chunks.length
    currentLine = []
    currentLength = 0
    if lines.length
      prefix = subsequentPrefix
    else
      prefix = initialPrefix

    lineWidth = width - expandTabs(prefix, tabLength).length

    if chunks[chunks.length-1].trim() == '' and lines.length
      chunks.pop()

    while chunks.length
      l = chunks[chunks.length-1].length

      if currentLength + l <= lineWidth
        currentLine.push(chunks.pop())
        currentLength += l
      else
        break

    if chunks.length and
       chunks[chunks.length-1].length > lineWidth and
       currentLine.length == 0
      currentLine.push(chunks.pop())

    if currentLine.length and currentLine[currentLine.length-1].trim() == ''
      currentLine.pop()

    if currentLine.length
      lines.push(prefix + currentLine.join(''))

  return lines

module.exports = {wrap, expandTabs}
