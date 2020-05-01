const fs = require('fs')

var str = fs.createWriteStream('./chacha20.txt', function (err) {
  if (err) throw err
})

// for (let i = 0; i < 20; i++) {
//   str.write(`\n\n;; ROUND ${i}\n`)
//   str.write(QR(0, 4, 8, 12))
//   str.write(QR(1, 5,  9, 13))
//   str.write(QR(2, 6, 10, 14))
//   str.write(QR(3, 7, 11, 15))
//   str.write(QR(0, 5, 10, 15))
//   str.write(QR(1, 6, 11, 12))
//   str.write(QR(2, 7,  8, 13))
//   str.write(QR(3, 4,  9, 14))
// }

function QR (a, b, c, d) {
  return `
(set_local $w${a} (i32.add (get_local $w${b}) (get_local $w${a})))
(set_local $w${d} (i32.rotl (i32.xor (get_local $w${d}) (get_local $w${a})) (i32.const 16)))

(set_local $w${c} (i32.add (get_local $w${d}) (get_local $w${c})))
(set_local $w${b} (i32.rotl (i32.xor (get_local $w${b}) (get_local $w${c})) (i32.const 12)))

(set_local $w${a} (i32.add (get_local $w${b}) (get_local $w${a})))
(set_local $w${d} (i32.rotl (i32.xor (get_local $w${d}) (get_local $w${a})) (i32.const 8)))

(set_local $w${c} (i32.add (get_local $w${d}) (get_local $w${c})))
(set_local $w${b} (i32.rotl (i32.xor (get_local $w${b}) (get_local $w${c})) (i32.const 7)))
`
}

for (let i = 0; i < 16; i++) {
  // str.write(`(i32.store offset=${4 * i} (get_local $input) (i32.add (i32.load offset=${4 * i} (get_local $input)) (i32.load offset=${64 + 4 * i} (get_local $ctx))))\n`)
  str.write(`(set_local $w${i} (i32.load offset=${4 * i} (get_local $ctx)))\n`)
}
