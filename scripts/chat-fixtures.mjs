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

function line(fn, input, output) {
  return JSON.stringify({ fn, in: input, out: output })
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

  const add = (fn, input, output) => {
    lines.push(line(fn, input, output))
    counts[fn]++
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

  const body = `${lines.join('\n')}\n`
  return { body, counts, bytes: Buffer.byteLength(body) }
}

const { body, counts, bytes } = generate()
const summary = `chat-fixtures: ${JSON.stringify(counts)} bytes=${bytes}`

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

if (bytes > 1024 * 1024) {
  console.error(`${summary} exceeds 1 MB`)
  process.exit(1)
}

writeFileSync(outPath, body)
console.log(`${summary} wrote ${outPath}`)
