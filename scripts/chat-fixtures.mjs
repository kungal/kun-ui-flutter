#!/usr/bin/env node
// Generates packages/kun_ui/test/chat/chat_core.fixture.json from kun-ui's
// ui-core chat module. ESM, Node 24 type stripping, no dependencies.
//
//   node scripts/chat-fixtures.mjs <kun-ui-root> [outfile]
//   node scripts/chat-fixtures.mjs <kun-ui-root> --check <path>

import { pathToFileURL } from 'node:url'
import { join, resolve } from 'node:path'
import { readFileSync, writeFileSync } from 'node:fs'

const args = process.argv.slice(2)
if (!args[0]) {
  console.error(
    'usage: node scripts/chat-fixtures.mjs <kun-ui-root> [outfile]\n' +
      '       node scripts/chat-fixtures.mjs <kun-ui-root> --check <path>',
  )
  process.exit(2)
}

const upstream = resolve(args[0])
const checkPath = args[1] === '--check' ? args[2] : null
const outPath =
  args[1] === '--check'
    ? null
    : resolve(args[1] ?? 'packages/kun_ui/test/chat/chat_core.fixture.json')

if (args[1] === '--check' && !checkPath) {
  console.error('usage: node scripts/chat-fixtures.mjs <kun-ui-root> --check <path>')
  process.exit(2)
}

const chat = await import(
  pathToFileURL(join(upstream, 'packages/ui-core/src/chat/index.ts')).href
)

function mulberry32(a) {
  return function rand() {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const TYPES = [
  'bold',
  'italic',
  'underline',
  'strikethrough',
  'spoiler',
  'code',
  'pre',
  'blockquote',
  'text_link',
  'mention',
  'url',
]

const INLINE_FORMATS = ['bold', 'italic', 'underline', 'strikethrough', 'spoiler']
const PAIR_TYPES = [...INLINE_FORMATS]
const LINK_TYPES = ['text_link', 'mention']

const ALPHABET = [
  '*', '*', '_', '_', '+', '~', '|', '|',
  '`', '`', '[', ']', '(', ')', '>', '\\', '\\',
  '\n', '\n', ' ', ' ',
  'a', 'b', 'c', 'x', 'z',
  'A', 'B',
  '中', '文', '鲲', '测',
  '😀', '🌊',
  'mention:1', 'mention:42',
  '#', '.', '-',
]

function pick(r, xs) {
  return xs[Math.floor(r() * xs.length)]
}

function randomText(r, maxLen) {
  const n = Math.floor(r() * (maxLen + 1))
  let s = ''
  for (let i = 0; i < n; i++) s += pick(r, ALPHABET)
  return s
}

function extraFor(type, r) {
  if (type === 'text_link') {
    return { url: pick(r, ['https://a', 'https://x/(y)', 'https://x/a\\)b', 'x)\\', '']) }
  }
  if (type === 'mention') {
    return { user_id: r() < 0.8 ? String(1 + Math.floor(r() * 99)) : '' }
  }
  if (type === 'pre' && r() < 0.5) {
    return { language: pick(r, ['go', 'c++', 'objective-c', 'bad lang!']) }
  }
  return {}
}

function extraValid(type, r) {
  if (type === 'text_link') return { url: pick(r, ['https://a', 'https://x/(y)', 'https://x']) }
  if (type === 'mention') return { user_id: String(1 + Math.floor(r() * 99)) }
  if (type === 'url') return {}
  if (type === 'pre') return { language: pick(r, ['go', 'c++', '']) }
  return {}
}

function entityOf(type, offset, length, r, valid = false) {
  return {
    type,
    offset,
    length,
    ...(valid ? extraValid(type, r) : extraFor(type, r)),
  }
}

function randomEntities(r, text, n) {
  const entities = []
  for (let i = 0; i < n; i++) {
    const type = pick(r, TYPES)
    entities.push({
      type,
      offset: Math.floor(r() * 18) - 2,
      length: Math.floor(r() * 12),
      ...extraFor(type, r),
    })
  }
  return entities
}

function jsonTree(nodes) {
  return nodes.map((n) =>
    n.kind === 'text'
      ? { kind: 'text', text: n.text, offset: n.offset }
      : { kind: 'entity', entity: n.entity, children: jsonTree(n.children) },
  )
}

function line(fn, family, input, output) {
  return JSON.stringify({ fn, family, in: input, out: output })
}

const parseSources = [
  '**b**',
  '__i__',
  '++u++',
  '~~s~~',
  '||x||',
  '`c`',
  '```go\nfmt.Println()\n```',
  '[moyu](https://moyu.moe)',
  '[@鲲](mention:42)',
  '> quoted',
  '这是**粗体**文字',
  'a__b__c',
  '**a __b__ c**',
  '`a **b** c`',
  '**a `**` b**',
  '||[x](https://a)||',
  '**open',
  'a ** b',
  '****',
  '``',
  '[no link]',
  '[x]()',
  '***a***',
  '~~~',
  '```\nplain\n```',
  '```inline```',
  '```hello world\ncode```',
  '```go\n```',
  'see\n```js\nx\n```\nok',
  '> a\n> b\nc',
  '> a\n\n> b',
  '> **a**',
  '\\> not a quote',
  'a > b',
  '\\*\\*not bold\\*\\*',
  'C:\\Users\\kun',
  '¯\\_(ツ)_/¯',
  'a\\_b',
  '\\`tick\\`',
  '\\\\**b**',
  'plain',
  '**`['.repeat(1024),
]

const formatCases = [
  ['plain', []],
  ['a*b', []],
  ['2**10', []],
  ['snake__case__name', []],
  ['C:\\Users', []],
  ['¯\\_(ツ)_/¯', []],
  ['> not a quote', []],
  ['[1] citation', []],
  ['bold', [{ type: 'bold', offset: 0, length: 4 }]],
  ['*star*', [{ type: 'bold', offset: 1, length: 4 }]],
  ['a`b', [{ type: 'code', offset: 0, length: 3 }]],
  ['x\\', [{ type: 'code', offset: 0, length: 2 }]],
  [
    'one\ntwo',
    [
      { type: 'blockquote', offset: 0, length: 7 },
      { type: 'bold', offset: 4, length: 3 },
    ],
  ],
  ['func() {}', [{ type: 'pre', offset: 0, length: 9, language: 'go' }]],
  ['```', [{ type: 'pre', offset: 0, length: 3 }]],
  ['a)b', [{ type: 'text_link', offset: 0, length: 3, url: 'https://x.com/a_(b)' }]],
  ['@kun', [{ type: 'mention', offset: 0, length: 4, user_id: '9' }]],
  ['[x]', [{ type: 'text_link', offset: 0, length: 3, url: 'https://a' }]],
  ['https://a.b', [{ type: 'url', offset: 0, length: 11 }]],
  ['a b', [{ type: 'blockquote', offset: 2, length: 1 }]],
]

const entityTexts = [
  'hello',
  '',
  'abcdef',
  'ab cd',
  'link',
  'a😀b',
  'abc',
  'abcdefgh',
  'abcd',
  'ab\ncd',
  'ab\n',
  '\nab\n',
  'look:\ncode\nok',
  'a\n\nq',
  'say hi there',
]

const entityLists = [
  null,
  [],
  [{ type: 'bold', offset: 0, length: 3 }],
  [{ type: 'bold', offset: 1, length: 2 }],
  [
    { type: 'italic', offset: 2, length: 1 },
    { type: 'bold', offset: 0, length: 4 },
  ],
  [
    { type: 'bold', offset: 0, length: 3 },
    { type: 'italic', offset: 3, length: 3 },
  ],
  [{ type: 'bold', offset: 3, length: 2 }],
  [
    { type: 'bold', offset: 0, length: 4 },
    { type: 'text_link', offset: 0, length: 4, url: 'https://moyu.moe' },
  ],
  [{ type: 'bold', offset: 1, length: 2 }],
  [{ type: 'bold', offset: 2, length: 1 }],
  [{ type: 'bold', offset: 0, length: 2 }],
  [
    { type: 'bold', offset: -1, length: 2 },
    { type: 'bold', offset: 1, length: 0 },
    { type: 'bold', offset: 5, length: 1 },
    { type: 'bold', offset: 1.5, length: 1 },
    { type: 'marquee', offset: 0, length: 1 },
    { type: 'text_link', offset: 0, length: 1 },
    { type: 'mention', offset: 0, length: 1 },
  ],
  [{ type: 'italic', offset: 1, length: 99 }],
  [
    { type: 'bold', offset: 0, length: 5 },
    { type: 'italic', offset: 3, length: 5 },
  ],
  [
    { type: 'code', offset: 0, length: 4 },
    { type: 'bold', offset: 1, length: 2 },
  ],
  [
    { type: 'text_link', offset: 0, length: 4, url: 'https://a' },
    { type: 'mention', offset: 1, length: 2, user_id: '7' },
  ],
  [
    { type: 'blockquote', offset: 0, length: 4 },
    { type: 'blockquote', offset: 1, length: 2 },
  ],
  [
    { type: 'bold', offset: 0, length: 3 },
    { type: 'bold', offset: 3, length: 3 },
  ],
  [
    { type: 'bold', offset: 0, length: 4 },
    { type: 'bold', offset: 2, length: 4 },
  ],
  [
    { type: 'text_link', offset: 0, length: 2, url: 'https://a' },
    { type: 'text_link', offset: 2, length: 2, url: 'https://a' },
  ],
  [
    { type: 'bold', offset: 0, length: 5 },
    { type: 'blockquote', offset: 3, length: 2 },
  ],
  [{ type: 'blockquote', offset: 0, length: 3 }],
  [{ type: 'spoiler', offset: 0, length: 4 }],
  [{ type: 'pre', offset: 6, length: 4, language: 'go' }],
  [{ type: 'blockquote', offset: 3, length: 1 }],
  [
    { type: 'bold', offset: 4, length: 2 },
    { type: 'italic', offset: 0, length: 12 },
  ],
]

const albumFixtures = [
  [
    [1600, 900],
    [1600, 900],
  ],
  [
    [900, 1600],
    [1600, 900],
  ],
  [
    [600, 1200],
    [1200, 900],
    [1000, 1000],
  ],
  [
    [2000, 1000],
    [800, 1000],
    [1000, 1000],
    [1200, 900],
  ],
  [
    [1330, 1000],
    [750, 1000],
    [1000, 1000],
    [1500, 1000],
    [660, 1000],
  ],
  [
    [0, 0],
    [100, 100],
  ],
  [],
  Array.from({ length: 10 }, (_, i) => [800 + i * 150, 1000]),
  Array.from({ length: 13 }, () => [1000, 800]),
]

// Every (text, entities) pair that appears as input in ui-core chat tests,
// including the 2.51.1 repros. parse() sources are listed in parseSources;
// format() (text, entities) in formatCases plus the closer-line cases below.
const testNormalizeCases = [
  ['hello', null],
  ['hello', []],
  ['', [{ type: 'bold', offset: 0, length: 3 }]],
  ['abcdef', [{ type: 'bold', offset: 1, length: 2 }]],
  [
    'abcdef',
    [
      { type: 'italic', offset: 2, length: 1 },
      { type: 'bold', offset: 0, length: 4 },
    ],
  ],
  [
    'abcdef',
    [
      { type: 'bold', offset: 0, length: 3 },
      { type: 'italic', offset: 3, length: 3 },
    ],
  ],
  ['ab cd', [{ type: 'bold', offset: 3, length: 2 }]],
  [
    'link',
    [
      { type: 'bold', offset: 0, length: 4 },
      { type: 'text_link', offset: 0, length: 4, url: 'https://moyu.moe' },
    ],
  ],
  ['a😀b', [{ type: 'bold', offset: 1, length: 2 }]],
  ['a😀b', [{ type: 'bold', offset: 2, length: 1 }]],
  ['a😀b', [{ type: 'bold', offset: 0, length: 2 }]],
  [
    'abc',
    [
      { type: 'bold', offset: -1, length: 2 },
      { type: 'bold', offset: 1, length: 0 },
      { type: 'bold', offset: 5, length: 1 },
      { type: 'bold', offset: 1.5, length: 1 },
      { type: 'marquee', offset: 0, length: 1 },
      { type: 'text_link', offset: 0, length: 1 },
      { type: 'mention', offset: 0, length: 1 },
    ],
  ],
  ['abc', [{ type: 'italic', offset: 1, length: 99 }]],
  [
    'abcdefgh',
    [
      { type: 'bold', offset: 0, length: 5 },
      { type: 'italic', offset: 3, length: 5 },
    ],
  ],
  [
    'abcd',
    [
      { type: 'code', offset: 0, length: 4 },
      { type: 'bold', offset: 1, length: 2 },
    ],
  ],
  [
    'abcd',
    [
      { type: 'text_link', offset: 0, length: 4, url: 'https://a' },
      { type: 'mention', offset: 1, length: 2, user_id: '7' },
    ],
  ],
  [
    'abcd',
    [
      { type: 'blockquote', offset: 0, length: 4 },
      { type: 'blockquote', offset: 1, length: 2 },
    ],
  ],
  [
    'abcdef',
    [
      { type: 'bold', offset: 0, length: 3 },
      { type: 'bold', offset: 3, length: 3 },
    ],
  ],
  [
    'abcdef',
    [
      { type: 'bold', offset: 0, length: 4 },
      { type: 'bold', offset: 2, length: 4 },
    ],
  ],
  [
    'abcd',
    [
      { type: 'text_link', offset: 0, length: 2, url: 'https://a' },
      { type: 'text_link', offset: 2, length: 2, url: 'https://a' },
    ],
  ],
  [
    'ab\ncd',
    [
      { type: 'bold', offset: 0, length: 5 },
      { type: 'blockquote', offset: 3, length: 2 },
    ],
  ],
  ['ab\n', [{ type: 'blockquote', offset: 0, length: 3 }]],
  ['\nab\n', [{ type: 'spoiler', offset: 0, length: 4 }]],
  [
    '中中b*bab',
    [
      { type: 'blockquote', offset: 2, length: 8 },
      { type: 'url', offset: 6, length: 2 },
      { type: 'blockquote', offset: 5, length: 5 },
      { type: 'spoiler', offset: 1, length: 6 },
    ],
  ],
  [
    'abcdefgh',
    [
      { type: 'blockquote', offset: 0, length: 5 },
      { type: 'blockquote', offset: 3, length: 5 },
      { type: 'bold', offset: 1, length: 6 },
    ],
  ],
  ['look:\ncode\nok', [{ type: 'pre', offset: 6, length: 4, language: 'go' }]],
  ['a\n\nq', [{ type: 'blockquote', offset: 3, length: 1 }]],
  [
    'say hi there',
    [
      { type: 'bold', offset: 4, length: 2 },
      { type: 'italic', offset: 0, length: 12 },
    ],
  ],
]

const testCloserFormatCases = [
  ['a\n\\>b', [{ type: 'mention', offset: 1, length: 1, user_id: '12' }]],
  [
    ')\n>',
    [
      { type: 'blockquote', offset: 0, length: 1 },
      { type: 'blockquote', offset: 1, length: 2 },
      { type: 'mention', offset: 1, length: 1, user_id: '12' },
    ],
  ],
  ['a\n> b', [{ type: 'text_link', offset: 0, length: 2, url: 'https://a' }]],
  [
    'a\nb',
    [
      { type: 'mention', offset: 0, length: 2, user_id: '1' },
      { type: 'blockquote', offset: 2, length: 1 },
    ],
  ],
]

const testQuoteInLabelCases = [
  [
    'x\n\\>y',
    [
      { type: 'blockquote', offset: 0, length: 5 },
      { type: 'mention', offset: 0, length: 2, user_id: '1' },
    ],
  ],
]

const testParseSourcesExtra = [
  'a[\n](mention:12)\\\\>b',
  '> )[\n](mention:12)\\>',
  '[a\n](https://a)\\> b',
  '[a\n](mention:1)> b',
  '> [x\n> ](mention:1)\\>y',
]

const closerTails = ['>', '> b', '>x', '> ', '\\>', '\\\\>', '\\>y', '\\> b', '\\>x', '\\\\> b']
const closerHeads = ['', 'a', 'x', ')', '中', 'ab', 'z', '*', 'aa']

function closerCover(kind, offset, length, r) {
  if (kind === 'mention') return { type: 'mention', offset, length, user_id: pick(r, ['1', '12', '9']) }
  if (kind === 'text_link') {
    return { type: 'text_link', offset, length, url: pick(r, ['https://a', 'https://x']) }
  }
  return { type: kind, offset, length }
}

function generateQuotesCase(r) {
  const shape = pick(r, ['nested', 'crossing', 'triple', 'repro'])
  if (shape === 'repro') {
    if (r() < 0.5) {
      return {
        text: '中中b*bab',
        entities: [
          { type: 'blockquote', offset: 2, length: 8 },
          { type: 'url', offset: 6, length: 2 },
          { type: 'blockquote', offset: 5, length: 5 },
          { type: 'spoiler', offset: 1, length: 6 },
        ],
      }
    }
    return {
      text: 'abcdefgh',
      entities: [
        { type: 'blockquote', offset: 0, length: 5 },
        { type: 'blockquote', offset: 3, length: 5 },
        { type: 'bold', offset: 1, length: 6 },
      ],
    }
  }
  const n = 8 + Math.floor(r() * 9)
  let text = ''
  for (let i = 0; i < n; i++) text += pick(r, ['a', 'b', 'c', 'x', '中', '*', ' ', '\n'])
  const entities = []
  if (shape === 'nested') {
    const outerStart = Math.floor(r() * Math.max(1, text.length - 4))
    const outerLen = Math.min(text.length - outerStart, 3 + Math.floor(r() * 8))
    const innerStart = outerStart + 1 + Math.floor(r() * Math.max(1, outerLen - 2))
    const innerLen = Math.max(1, Math.min(outerStart + outerLen - innerStart - 1, 1 + Math.floor(r() * 4)))
    entities.push({ type: 'blockquote', offset: outerStart, length: outerLen })
    entities.push({ type: 'blockquote', offset: innerStart, length: innerLen })
    const inlineStart = Math.max(0, outerStart - Math.floor(r() * 2))
    const inlineLen = Math.min(text.length - inlineStart, outerLen + 2 + Math.floor(r() * 4))
    const inlineType = pick(r, [...INLINE_FORMATS, 'url', 'code', 'text_link', 'mention'])
    entities.push(entityOf(inlineType, inlineStart, inlineLen, r, true))
  } else if (shape === 'crossing') {
    const aStart = Math.floor(r() * Math.max(1, text.length - 5))
    const aLen = 3 + Math.floor(r() * 5)
    const bStart = aStart + 1 + Math.floor(r() * 3)
    const bLen = 3 + Math.floor(r() * 5)
    entities.push({ type: 'blockquote', offset: aStart, length: aLen })
    entities.push({ type: 'blockquote', offset: bStart, length: bLen })
    const inlineType = pick(r, INLINE_FORMATS)
    entities.push({
      type: inlineType,
      offset: Math.max(0, aStart - 1),
      length: aLen + bLen,
    })
  } else {
    for (let i = 0; i < 3; i++) {
      entities.push({
        type: 'blockquote',
        offset: Math.floor(r() * 14) - 1,
        length: 2 + Math.floor(r() * 8),
      })
    }
    for (let i = 0; i < 1 + Math.floor(r() * 3); i++) {
      const inlineType = pick(r, [...INLINE_FORMATS, 'url', 'text_link', 'mention', 'code'])
      entities.push(entityOf(inlineType, Math.floor(r() * 16) - 1, 1 + Math.floor(r() * 8), r, true))
    }
  }
  return { text, entities }
}

function generateCloserCase(r) {
  const head = pick(r, closerHeads)
  const tail = pick(r, closerTails)
  const text = `${head}\n${tail}`
  const cover = head.length + 1
  const kind = pick(r, [...LINK_TYPES, ...PAIR_TYPES])
  const start = pick(r, [0, Math.max(0, head.length - 1), Math.max(0, head.length)])
  const length = cover - start
  if (length <= 0) return { text, entities: [closerCover(kind, 0, cover, r)] }
  return { text, entities: [closerCover(kind, start, length, r)] }
}

function generateQuoteInLabelCase(r) {
  const head = pick(r, ['x', 'a', 'ab', '中', 'z'])
  const tail = pick(r, ['\\>y', '\\\\>y', '> b', '>x', '\\> b', '\\\\> b', '\\>', '>'])
  const text = `${head}\n${tail}`
  const labelEnd = head.length + 1 + (r() < 0.5 ? 0 : Math.min(2, tail.length))
  const kind = pick(r, LINK_TYPES)
  return {
    text,
    entities: [
      { type: 'blockquote', offset: 0, length: text.length },
      closerCover(kind, 0, Math.max(1, labelEnd), r),
    ],
  }
}

function generate() {
  const r = mulberry32(20260927)
  const lines = []
  const counts = {
    parse: 0,
    format: 0,
    normalize: 0,
    tree: 0,
    slice: 0,
    album: 0,
  }
  const families = {}

  const add = (fn, input, output, family = fn) => {
    lines.push(line(fn, family, input, output))
    counts[fn]++
    families[family] = (families[family] ?? 0) + 1
  }

  for (const source of parseSources) {
    add('parse', { source }, chat.parseKunChatMarkdown(source))
  }
  while (counts.parse < 500) {
    const source = randomText(r, 24)
    add('parse', { source }, chat.parseKunChatMarkdown(source))
  }

  for (const [text, entities] of formatCases) {
    add('format', { text, entities }, chat.formatKunChatMarkdown(text, entities))
  }
  const parseOuts = parseSources.slice(0, Math.ceil(parseSources.length / 2)).map((source) =>
    chat.parseKunChatMarkdown(source),
  )
  for (const p of parseOuts) {
    add('format', { text: p.text, entities: p.entities }, chat.formatKunChatMarkdown(p.text, p.entities))
  }
  while (counts.format < 500) {
    if (r() < 0.5 && parseOuts.length) {
      const p = chat.parseKunChatMarkdown(randomText(r, 20))
      add('format', { text: p.text, entities: p.entities }, chat.formatKunChatMarkdown(p.text, p.entities))
    } else {
      const text = randomText(r, 20)
      const entities = randomEntities(r, text, Math.floor(r() * 6))
      add('format', { text, entities }, chat.formatKunChatMarkdown(text, entities))
    }
  }

  const badClasses = (text) => [
    { type: 'marquee', offset: 0, length: 1 },
    { type: 'bold', offset: 1.5, length: 1 },
    { type: 'bold', offset: 0, length: 2.7 },
    { type: 'bold', offset: -3, length: 4 },
    { type: 'bold', offset: 0, length: 0 },
    { type: 'bold', offset: 2, length: -1 },
    { type: 'text_link', offset: 0, length: Math.min(2, text.length || 2) },
    { type: 'text_link', offset: 0, length: 1, url: '' },
    { type: 'mention', offset: 0, length: Math.min(2, text.length || 2) },
    { type: 'mention', offset: 0, length: 1, user_id: '' },
    { type: 'bold', offset: text.length + 2, length: 3 },
    { type: 'bold', offset: 2, length: 1 },
    { type: 'mention', offset: 0, length: 1, user_id: 9 },
    { type: 'bold', offset: true, length: 1 },
    { type: 1, offset: 0, length: 1 },
    'not-a-map',
    null,
    3,
  ]

  for (let i = 0; i < entityTexts.length; i++) {
    const text = entityTexts[i]
    const entities = entityLists[Math.min(i, entityLists.length - 1)]
    add(
      'normalize',
      { text, entities },
      chat.normalizeKunChatEntities(text, entities),
    )
    add('tree', { text, entities }, jsonTree(chat.buildKunChatEntityTree(text, entities)))
  }
  for (const entities of entityLists) {
    const text = 'abcdefgh😀中\nxy'
    add(
      'normalize',
      { text, entities },
      chat.normalizeKunChatEntities(text, entities),
    )
  }

  add(
    'normalize',
    { text: 'a😀b', entities: [{ type: 'bold', offset: 2, length: 1 }] },
    chat.normalizeKunChatEntities('a😀b', [{ type: 'bold', offset: 2, length: 1 }]),
  )
  add(
    'slice',
    {
      text: 'say hi there',
      entities: [
        { type: 'bold', offset: 4, length: 2 },
        { type: 'italic', offset: 0, length: 12 },
      ],
      start: 4,
      end: 12,
    },
    chat.sliceKunChatEntities(
      'say hi there',
      [
        { type: 'bold', offset: 4, length: 2 },
        { type: 'italic', offset: 0, length: 12 },
      ],
      4,
      12,
    ),
  )
  add(
    'slice',
    { text: 'a😀b', entities: [], start: 2, end: 4 },
    chat.sliceKunChatEntities('a😀b', [], 2, 4),
  )

  while (counts.normalize < 500) {
    const text = randomText(r, 16)
    const entities = [
      ...randomEntities(r, text, Math.floor(r() * 5)),
      ...badClasses(text).filter(() => r() < 0.35),
    ]
    add(
      'normalize',
      { text, entities },
      chat.normalizeKunChatEntities(text, entities),
    )
  }

  while (counts.tree < 500) {
    const text = randomText(r, 14)
    const entities = randomEntities(r, text, Math.floor(r() * 5))
    add('tree', { text, entities }, jsonTree(chat.buildKunChatEntityTree(text, entities)))
  }

  while (counts.slice < 500) {
    const text = r() < 0.3 ? `${randomText(r, 8)}😀${randomText(r, 8)}` : randomText(r, 16)
    const entities = randomEntities(r, text, Math.floor(r() * 5))
    const a = Math.floor(r() * (text.length + 3)) - 1
    const b = Math.floor(r() * (text.length + 3)) - 1
    add(
      'slice',
      { text, entities, start: a, end: b },
      chat.sliceKunChatEntities(text, entities, a, b),
    )
  }

  for (const sizes of albumFixtures) {
    const input = sizes.map(([width, height]) => ({ width, height }))
    add('album', { sizes: input }, chat.layoutKunChatAlbum(input))
  }

  while (counts.album < 300) {
    const n = 1 + Math.floor(r() * 10)
    const sizes = Array.from({ length: n }, () => {
      if (r() < 0.08) return { width: 0, height: r() < 0.5 ? 0 : 100 }
      if (r() < 0.08) return { width: 100, height: 0 }
      return {
        width: Math.floor(r() * 2000) + 1,
        height: Math.floor(r() * 2000) + 1,
      }
    })
    const options =
      r() < 0.25
        ? {
            maxWidth: 200 + Math.floor(r() * 400),
            minWidth: 40 + Math.floor(r() * 80),
            spacing: Math.floor(r() * 5),
          }
        : undefined
    add(
      'album',
      options ? { sizes, options } : { sizes },
      chat.layoutKunChatAlbum(sizes, options ?? {}),
    )
  }

  // (a) Every remaining input from the ui-core chat tests, including 2.51.1.
  for (const source of testParseSourcesExtra) {
    add('parse', { source }, chat.parseKunChatMarkdown(source), 'tests')
  }
  for (const [text, entities] of testNormalizeCases) {
    add(
      'normalize',
      { text, entities },
      chat.normalizeKunChatEntities(text, entities),
      'tests',
    )
    add(
      'tree',
      { text, entities },
      jsonTree(chat.buildKunChatEntityTree(text, entities)),
      'tests',
    )
  }
  add(
    'slice',
    {
      text: 'say hi there',
      entities: [
        { type: 'bold', offset: 4, length: 2 },
        { type: 'italic', offset: 0, length: 12 },
      ],
      start: 4,
      end: 12,
    },
    chat.sliceKunChatEntities(
      'say hi there',
      [
        { type: 'bold', offset: 4, length: 2 },
        { type: 'italic', offset: 0, length: 12 },
      ],
      4,
      12,
    ),
    'tests',
  )
  add(
    'slice',
    { text: 'a😀b', entities: [], start: 2, end: 4 },
    chat.sliceKunChatEntities('a😀b', [], 2, 4),
    'tests',
  )
  for (const [text, entities] of [...formatCases, ...testCloserFormatCases, ...testQuoteInLabelCases]) {
    add(
      'format',
      { text, entities },
      chat.formatKunChatMarkdown(text, entities),
      'tests',
    )
  }

  // (b) Targeted families aimed at the 2.51.1 paths.
  const rq = mulberry32(25110001)
  for (const [text, entities] of [
    ...testNormalizeCases.filter((c) =>
      (c[1] ?? []).some((e) => e && e.type === 'blockquote'),
    ),
  ]) {
    add(
      'normalize',
      { text, entities },
      chat.normalizeKunChatEntities(text, entities),
      'quotes',
    )
    add(
      'tree',
      { text, entities },
      jsonTree(chat.buildKunChatEntityTree(text, entities)),
      'quotes',
    )
  }
  for (let i = 0; i < 220; i++) {
    const { text, entities } = generateQuotesCase(rq)
    add(
      'normalize',
      { text, entities },
      chat.normalizeKunChatEntities(text, entities),
      'quotes',
    )
    add(
      'tree',
      { text, entities },
      jsonTree(chat.buildKunChatEntityTree(text, entities)),
      'quotes',
    )
  }

  for (const [text, entities] of testCloserFormatCases) {
    add(
      'format',
      { text, entities },
      chat.formatKunChatMarkdown(text, entities),
      'closer_line_start',
    )
  }
  for (let i = 0; i < 240; i++) {
    const { text, entities } = generateCloserCase(rq)
    add(
      'format',
      { text, entities },
      chat.formatKunChatMarkdown(text, entities),
      'closer_line_start',
    )
  }

  for (const [text, entities] of testQuoteInLabelCases) {
    add(
      'format',
      { text, entities },
      chat.formatKunChatMarkdown(text, entities),
      'quote_in_label',
    )
  }
  for (let i = 0; i < 160; i++) {
    const { text, entities } = generateQuoteInLabelCase(rq)
    add(
      'format',
      { text, entities },
      chat.formatKunChatMarkdown(text, entities),
      'quote_in_label',
    )
  }

  const body = `${lines.join('\n')}\n`
  return { body, counts, families, bytes: Buffer.byteLength(body) }
}

const { body, counts, families, bytes } = generate()
const summary = `chat-fixtures: ${JSON.stringify(counts)} families=${JSON.stringify(families)} bytes=${bytes}`

if (checkPath) {
  const existing = readFileSync(checkPath, 'utf8')
  if (existing === body) {
    console.log(`${summary} ok`)
    process.exit(0)
  }
  const got = body.split('\n')
  const want = existing.split('\n')
  const n = Math.max(got.length, want.length)
  for (let i = 0; i < n; i++) {
    if (got[i] !== want[i]) {
      console.error(`chat-fixtures: first difference at line ${i + 1}`)
      console.error(`generated: ${got[i] ?? '<missing>'}`)
      console.error(`file:      ${want[i] ?? '<missing>'}`)
      process.exit(1)
    }
  }
  console.error('chat-fixtures: files differ (trailing content)')
  process.exit(1)
}

const limit = 1.2 * 1024 * 1024
if (bytes > limit) {
  console.error(`${summary} exceeds 1.2 MB`)
  process.exit(1)
}

writeFileSync(outPath, body)
console.log(`${summary} wrote ${outPath}`)
