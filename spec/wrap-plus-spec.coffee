{WorkspaceView, Range} = require 'atom'
WrapPlus = require '../lib/wrap-plus'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "WrapPlus", ->
  editor = null
  editorView = null
  activationPromise = null

  configureWorkspace = (filename) ->
    beforeEach ->
      atom.workspaceView = new WorkspaceView

      waitsForPromise ->
        atom.workspace.open(filename)
      waitsForPromise ->
        atom.packages.activatePackage('language-source')
      waitsForPromise ->
        atom.packages.activatePackage('language-c')
      waitsForPromise ->
        atom.packages.activatePackage('language-html')
      waitsForPromise ->
        atom.packages.activatePackage('language-gfm')
      runs ->
        editorView = atom.workspaceView.getActiveView()
        expect(editorView).not.toBeUndefined()
        {editor} = editorView
        atom.config.set('editor.preferredLineLength', 40)
        activationPromise = atom.packages.activatePackage('wrap-plus')
        editorView.trigger 'wrap-plus:rewrap'
      waitsForPromise ->
        activationPromise

  setGrammar = (scope) ->
    grammar = atom.syntax.grammarForScopeName(scope)
    editor.setGrammar(grammar)

  describe 'no-file tests', ->

    configureWorkspace()

    it 'can determine correct comment styles', ->
      setGrammar('source.c')
      {bc, lc} = WrapPlus.determineCommentStyle(editor)
      expect(bc).toEqual([{start: '/*', end: '*/'}])
      expect(lc).toEqual(['//'])

      setGrammar('text.html.basic')
      {bc, lc} = WrapPlus.determineCommentStyle(editor)
      expect(bc).toEqual([{start: '<!--', end: '-->'}])
      expect(lc).toEqual([])

  describe 'test.txt tests', ->

    configureWorkspace('test.txt')

    it 'can discover a paragraph from simple cursor', ->
      for row in [0..2]
        for column in [0, 15]
          pt = [row, column]
          result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
          expect(result.length).toBe(1)
          expect(result[0].requiredCommentPrefix).toBeUndefined()
          expect(result[0].range).toEqual([[0, 0], [2, 104]])

    it 'will find no results for empty line and pure paragraph breaks', ->
      for row in [5, 6, 8, 10]
        pt = [row, 0]
        result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
        expect(result.length).toBe(0)

    it 'can find paragraph start', ->
      # These are all single line paragraphs.
      for row in [7, 9, 11, 13]
        pt = [row, 0]
        result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
        rowLength = editor.lineLengthForBufferRow(row)
        expect(result[0].range).toEqual([pt, [row, rowLength]])

    it 'will handle starting on a "paragraph start" line', ->
      for row in [22, 24, 26, 28, 30, 32, 34]
        pt = [row, 0]
        result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
        nextLength = editor.lineLengthForBufferRow(row+1)
        expect(result[0].range).toEqual([pt, [row+1, nextLength]])

    it 'will join up to a paragraph start', ->
      for row in [23, 25, 27, 29, 31, 33, 35]
        pt = [row, 0]
        result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
        length = editor.lineLengthForBufferRow(row)
        expect(result[0].range).toEqual([[row-1, 0], [row, length]])


  describe 'test2.txt tests', ->

    configureWorkspace('test2.txt')

    it 'wraps every line', ->


# TODO:
# - non-empty selections.
# - in a non-empty selection, will skip across pure paragraph break junk.
# - started in comment, moving up won't leave comment.
# - Test comment prefixes.

  describe 'test.md tests', ->

    configureWorkspace('test.md')

    it 'can break on header reliably.', ->
      for row in [0, 2]
        pt = [row, 0]
        result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
        expect(result.length).toBe(0)
      for row in [1, 3]
        pt = [row, 0]
        result = WrapPlus.findParagraphs(editor, new Range(pt, pt))
        length = editor.lineLengthForBufferRow(row)
        expect(result[0].range).toEqual([pt, [row, length]])
