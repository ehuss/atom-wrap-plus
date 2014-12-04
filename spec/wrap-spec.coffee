{wrap, expandTabs} = require '../lib/wrap'

describe 'Expand Tabs', ->
  it 'Converts tabs to spaces', ->
    a = 'foo\tbar'
    b = 'foo bar'
    expect(expandTabs(a, 4)).toEqual(b)
    a = '\tfoo\tbar'
    b = '    foo bar'
    expect(expandTabs(a, 4)).toEqual(b)

  it 'Handles new lines.', ->
    a = 'a\t\r\n\tb\t'
    b = 'a   \r\n    b   '
    expect(expandTabs(a, 4)).toEqual(b)

describe 'Wrap', ->
  it 'Handles simple wrapping', ->
    a = 'steam shovel disk Veterans Day theory saffron cranberry transcript sugary fruitless pro tempore pail'
    b = ['steam shovel disk',
         'Veterans Day theory',
         'saffron cranberry',
         'transcript sugary',
         'fruitless pro',
         'tempore pail']
    expect(wrap(a, width:20)).toEqual(b)
    expect(wrap(a, width:100)).toEqual([a])
    expect(wrap('')).toEqual([])
    expect(wrap('\n')).toEqual([])
    expect(wrap('  \n')).toEqual([])
    expect(wrap('\t\n')).toEqual([])

  it 'retains whitespace when appropriate', ->
    a = 'a\tb  c d\n  e\r\nf'
    b = 'a   b  c d   e  f'
    expect(wrap(a)).toEqual([b])
    a = '  2\t456789    0123 56789 1234567890123456789 0'
    b = ['  2 456789',
         '0123 56789',
         '1234567890123456789',
         '0']
    expect(wrap(a, width:10)).toEqual(b)

  it 'supports custom tab length', ->
    a = 'a\tb'
    b = ['a       b']
    expect(wrap(a, tabLength:8)).toEqual(b)

  it 'supports custom prefixes', ->
    a = 'thrall flatulent motherland infantile slovenliness Coast Guard impatiently attainment commutative lieu'
    b = ['1234thrall flatulent',
         '\tmotherland infantile',
         '\tslovenliness Coast',
         '\tGuard impatiently',
         '\tattainment',
         '\tcommutative lieu']
    options =
      width: 24
      initialPrefix: '1234'
      subsequentPrefix: '\t'
    expect(wrap(a, options)).toEqual(b)
