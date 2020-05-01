
module.exports = loadWebAssembly

loadWebAssembly.supported = typeof WebAssembly !== 'undefined'

function loadWebAssembly (opts) {
  if (!loadWebAssembly.supported) return null

  var imp = opts && opts.imports
  var wasm = toUint8Array('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')
  var ready = null

  var mod = {
    buffer: wasm,
    memory: null,
    exports: null,
    realloc: realloc,
    onload: onload
  }

  onload(function () {})

  return mod

  function realloc (size) {
    mod.exports.memory.grow(Math.max(0, Math.ceil(Math.abs(size - mod.memory.length) / 65536)))
    mod.memory = new Uint8Array(mod.exports.memory.buffer)
  }

  function onload (cb) {
    if (mod.exports) return cb()

    if (ready) {
      ready.then(cb.bind(null, null)).catch(cb)
      return
    }

    try {
      if (opts && opts.async) throw new Error('async')
      setup({instance: new WebAssembly.Instance(new WebAssembly.Module(wasm), imp)})
    } catch (err) {
      ready = WebAssembly.instantiate(wasm, imp).then(setup)
    }

    onload(cb)
  }

  function setup (w) {
    mod.exports = w.instance.exports
    mod.memory = mod.exports.memory && mod.exports.memory.buffer && new Uint8Array(mod.exports.memory.buffer)
  }
}

function toUint8Array (s) {
  if (typeof atob === 'function') return new Uint8Array(atob(s).split('').map(charCodeAt))
  return (require('buf' + 'fer').Buffer).from(s, 'base64')
}

function charCodeAt (c) {
  return c.charCodeAt(0)
}