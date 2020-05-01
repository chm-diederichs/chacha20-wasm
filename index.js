const assert = require('nanoassert')
const wasm = require('./chacha20.js')({
  imports: {
    debug: {
      log (...args) {
        console.log(...args.map(int => (int >>> 0).toString(16).padStart(8, '0')))
      },
      log_tee (arg) {
        console.log((arg >>> 0).toString(16).padStart(8, '0'))
        return arg
      }
    }
  }
})

let head = 0
const freeList = []

module.exports = Chacha20
const BLOCKSIZE = module.exports.BLOCKSIZE = 64
const k = Buffer.from('expand 32-byte k')
// const k = Buffer.from('apxe3 dnyb-2k et')

function Chacha20 (key, ctr, nonce) {
  if (!(this instanceof Chacha20)) return new Chacha20()
  if (!(wasm && wasm.exports)) throw new Error('WASM not loaded. Wait for Chacha20.ready(cb)')

  if (!freeList.length) {
    freeList.push(head)
    head += 128 // need 100 bytes for internal state
  }

  this.finalized = false
  this.pointer = freeList.pop()

  wasm.memory.fill(0, this.pointer, this.pointer + 128)

  wasm.memory.set(k, this.pointer)
  wasm.memory.set(key, this.pointer + 16)

  wasm.memory[48] = ctr & 0xff
  wasm.memory[49] = (ctr >> 8) & 0xff
  wasm.memory[50] = (ctr >> 16) & 0xff
  wasm.memory[51] = (ctr >> 24) & 0xff

  wasm.memory.set(nonce, this.pointer + 52)

  // wasm.exports.init(this.pointer)
}

Chacha20.prototype.encrypt = function (input, enc) {
  assert(this.finalized === false, 'Hash instance finalized')

  if (head % 4 !== 0) head += 4 - head % 4
  assert(head % 4 === 0, 'input shoud be aligned for int32')

  let [ inputBuf, length ] = formatInput(input, enc)
  
  assert(inputBuf instanceof Uint8Array, 'input must be Uint8Array or Buffer')
  
  if (head + length > wasm.memory.length) wasm.realloc(head + input.length)
  
  // if (this.leftover != null) {
  //   wasm.memory.set(this.leftover, head)
  //   wasm.memory.set(inputBuf, this.leftover.byteLength + head)
  // } else {
  wasm.memory.set(inputBuf, head)
  
  // const overlap = this.leftover ? this.leftover.byteLength : 0
  wasm.exports.encrypt(this.pointer, head, head + length)

  // this.leftover = inputBuf.slice(inputBuf.byteLength - leftover)
  return hexSlice(wasm.memory, head, length)
}

// Chacha20.prototype.digest = function (enc, offset = 0) {
//   assert(this.finalized === false, 'Hash instance finalized')

//   this.finalized = true
//   freeList.push(this.pointer)

//   wasm.exports.chacha20(this.pointer, head, head + this.leftover.byteLength, 1)

//   const resultBuf = readReverseEndian(wasm.memory, 4, this.pointer, this.digestLength)

//   if (!enc) {    
//     return resultBuf
//   }

//   if (typeof enc === 'string') {
//     return resultBuf.toString(enc)
//   }

//   assert(enc instanceof Uint8Array, 'input must be Uint8Array or Buffer')
//   assert(enc.byteLength >= this.digestLength + offset, 'input not large enough for digest')

//   for (let i = 0; i < this.digestLength; i++) {
//     enc[i + offset] = resultBuf[i]
//   }

//   return enc
// }

Chacha20.ready = function (cb) {
  if (!cb) cb = noop
  if (!wasm) return cb(new Error('WebAssembly not supported'))

  var p = new Promise(function (reject, resolve) {
    wasm.onload(function (err) {
      if (err) resolve(err)
      else reject()
      cb(err)
    })
  })

  return p
}

Chacha20.prototype.ready = Chacha20.ready

function noop () {}

function formatInput (input, enc = null) {
  let result
  if (Buffer.isBuffer(input)) {
    result = input
  } else {
    result = Buffer.from(input, enc)
  }

  return [result, result.byteLength]
}

function readReverseEndian (buf, interval, start, len) {
  if (!start) start = 0
  if (!len) len = buf.byteLength

  const result = Buffer.allocUnsafe(len)

  for (let i = 0; i < len; i++) {
    const index = Math.floor(i / interval) * interval + (interval - 1) - i % interval
    result[index] = buf[i + start]
  }

  return result
}

function hexSlice (buf, start = 0, len) {
  if (!len) len = buf.byteLength

  var str = ''
  for (var i = 0; i < len; i++) str += toHex(buf[start + i])
  return str
}

function toHex (n) {
  if (n < 16) return '0' + n.toString(16)
  return n.toString(16)
}
