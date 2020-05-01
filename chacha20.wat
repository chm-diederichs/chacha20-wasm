(module
    (func $i32.log (import "debug" "log") (param i32))
    (func $i32.log_tee (import "debug" "log_tee") (param i32) (result i32))
    ;; No i64 interop with JS yet - but maybe coming with WebAssembly BigInt
    ;; So we can instead fake this by splitting the i64 into two i32 limbs,
    ;; however these are WASM functions using i32x2.log:
    (func $i32x2.log (import "debug" "log") (param i32) (param i32))
    (func $f32.log (import "debug" "log") (param f32))
    (func $f32.log_tee (import "debug" "log_tee") (param f32) (result f32))
    (func $f64.log (import "debug" "log") (param f64))
    (func $f64.log_tee (import "debug" "log_tee") (param f64) (result f64))
    
    (memory (export "memory") 10 65536)
    
    ;; i64 logging by splitting into two i32 limbs
    (func $i64.log
        (param $0 i64)
        (call $i32x2.log
            ;; Upper limb
            (i32.wrap/i64
                (i64.shr_u (get_local $0)
                    (i64.const 32)))
            ;; Lower limb
            (i32.wrap/i64 (get_local $0))))

    (func $i64.log_tee
        (param $0 i64)
        (result i64)
        (call $i64.log (get_local $0))
        (return (get_local $0)))

    (func $encrypt (export "encrypt") (param $ctx i32) (param $input i32) (param $input_end i32)
        (local $ctr i32)

        (set_local $ctr (i32.load offset=48 (get_local $ctx)))

        (call $chacha20_block (get_local $ctx))
        (block $final_words
            (loop $a
                (i32.le_u (get_local $input_end) (get_local $input))
                (br_if $final_words)
                
                (i32.store offset=0  (get_local $input) (i32.xor (i32.load offset=0  (get_local $input)) (i32.load offset=64  (get_local $ctx))))
                (i32.store offset=4  (get_local $input) (i32.xor (i32.load offset=4  (get_local $input)) (i32.load offset=68  (get_local $ctx))))
                (i32.store offset=8  (get_local $input) (i32.xor (i32.load offset=8  (get_local $input)) (i32.load offset=72  (get_local $ctx))))
                (i32.store offset=12 (get_local $input) (i32.xor (i32.load offset=12 (get_local $input)) (i32.load offset=76  (get_local $ctx))))
                (i32.store offset=16 (get_local $input) (i32.xor (i32.load offset=16 (get_local $input)) (i32.load offset=80  (get_local $ctx))))
                (i32.store offset=20 (get_local $input) (i32.xor (i32.load offset=20 (get_local $input)) (i32.load offset=84  (get_local $ctx))))
                (i32.store offset=24 (get_local $input) (i32.xor (i32.load offset=24 (get_local $input)) (i32.load offset=88  (get_local $ctx))))
                (i32.store offset=28 (get_local $input) (i32.xor (i32.load offset=28 (get_local $input)) (i32.load offset=92  (get_local $ctx))))
                (i32.store offset=32 (get_local $input) (i32.xor (i32.load offset=32 (get_local $input)) (i32.load offset=96  (get_local $ctx))))
                (i32.store offset=36 (get_local $input) (i32.xor (i32.load offset=36 (get_local $input)) (i32.load offset=100 (get_local $ctx))))
                (i32.store offset=40 (get_local $input) (i32.xor (i32.load offset=40 (get_local $input)) (i32.load offset=104 (get_local $ctx))))
                (i32.store offset=44 (get_local $input) (i32.xor (i32.load offset=44 (get_local $input)) (i32.load offset=108 (get_local $ctx))))
                (i32.store offset=48 (get_local $input) (i32.xor (i32.load offset=48 (get_local $input)) (i32.load offset=112 (get_local $ctx))))
                (i32.store offset=52 (get_local $input) (i32.xor (i32.load offset=52 (get_local $input)) (i32.load offset=116 (get_local $ctx))))
                (i32.store offset=56 (get_local $input) (i32.xor (i32.load offset=56 (get_local $input)) (i32.load offset=120 (get_local $ctx))))
                (i32.store offset=60 (get_local $input) (i32.xor (i32.load offset=60 (get_local $input)) (i32.load offset=124 (get_local $ctx))))

                (set_local $input (i32.add (get_local $input) (i32.const 64)))
                (set_local $ctr (i32.add (get_local $ctr) (i32.const 1)))
                (i32.store offset=48 (get_local $ctx) (get_local $ctr))

                (call $chacha20_block (get_local $ctx))
                (br $a))))

        ;; (set_local $ctr (i32.const 64))
        ;; (block $final_bytes
        ;;     (loop $b
        ;;         (i32.lt_u (i32.sub (get_local $input_end) (get_local $input)) (i32.const 4))
        ;;         (br_if $final_bytes)

        ;;         (i32.store (get_local $input) (i32.xor (i32.load (get_local $input)) (i32.load (i32.add (get_local $ctr) (get_local $ctx)))))
        ;;         (set_local $input (i32.add (get_local $input) (i32.const 4)))
        ;;         (set_local $ctr (i32.add (get_local $ctr) (i32.const 4)))
        ;;         (br $b)))

        ;; (block $end
        ;;     (loop $c
        ;;         (i32.eq (get_local $input) (get_local $input_end))
        ;;         (br_if $end)

        ;;         (i32.store8 (get_local $input) (i32.xor (i32.load8_u (get_local $input)) (i32.load8_u (i32.add (get_local $ctr) (get_local $ctx)))))
        ;;         (set_local $input (i32.add (get_local $input) (i32.const 1)))
        ;;         (set_local $ctr (i32.add (get_local $ctr) (i32.const 1)))
        ;;         (br $c))))

    (func $chacha20_block (param $ctx i32)

        ;; storage schema:
        ;; [0....16] - constant ("expand 32-byte k")
        ;; [16...48] - key
        ;; [48...52] - counter
        ;; [52...64] - nonce
        ;; [64..128] - keystream

        (local $ctr i32)

        (local $w0  i32) (local $w1  i32) (local $w2  i32) (local $w3  i32)
        (local $w4  i32) (local $w5  i32) (local $w6  i32) (local $w7  i32)
        (local $w8  i32) (local $w9  i32) (local $w10 i32) (local $w11 i32)
        (local $w12 i32) (local $w13 i32) (local $w14 i32) (local $w15 i32)

        (set_local $w0  (i32.load offset=0  (get_local $ctx)))
        (set_local $w1  (i32.load offset=4  (get_local $ctx)))
        (set_local $w2  (i32.load offset=8  (get_local $ctx)))
        (set_local $w3  (i32.load offset=12 (get_local $ctx)))
        (set_local $w4  (i32.load offset=16 (get_local $ctx)))
        (set_local $w5  (i32.load offset=20 (get_local $ctx)))
        (set_local $w6  (i32.load offset=24 (get_local $ctx)))
        (set_local $w7  (i32.load offset=28 (get_local $ctx)))
        (set_local $w8  (i32.load offset=32 (get_local $ctx)))
        (set_local $w9  (i32.load offset=36 (get_local $ctx)))
        (set_local $w10 (i32.load offset=40 (get_local $ctx)))
        (set_local $w11 (i32.load offset=44 (get_local $ctx)))
        (set_local $w12 (i32.load offset=48 (get_local $ctx)))
        (set_local $w13 (i32.load offset=52 (get_local $ctx)))
        (set_local $w14 (i32.load offset=56 (get_local $ctx)))
        (set_local $w15 (i32.load offset=60 (get_local $ctx)))


        ;; ROUND 0 & 1

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 2 & 3

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))

    
        ;; ROUND 4 & 5

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 6 & 7

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 8 & 9

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 10 & 11

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 12 & 13

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 14 & 15

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 16 & 17

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; ROUND 18 & 19

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w4) (get_local $w0)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w0)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w12) (get_local $w8)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w8)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w5) (get_local $w1)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w1)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w13) (get_local $w9)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w9)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w6) (get_local $w2)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w2)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w14) (get_local $w10)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w10)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w7) (get_local $w3)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w3)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w15) (get_local $w11)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w11)) (i32.const 7)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 16)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 12)))

        (set_local $w0 (i32.add (get_local $w5) (get_local $w0)))
        (set_local $w15 (i32.rotl (i32.xor (get_local $w15) (get_local $w0)) (i32.const 8)))

        (set_local $w10 (i32.add (get_local $w15) (get_local $w10)))
        (set_local $w5 (i32.rotl (i32.xor (get_local $w5) (get_local $w10)) (i32.const 7)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 16)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 12)))

        (set_local $w1 (i32.add (get_local $w6) (get_local $w1)))
        (set_local $w12 (i32.rotl (i32.xor (get_local $w12) (get_local $w1)) (i32.const 8)))

        (set_local $w11 (i32.add (get_local $w12) (get_local $w11)))
        (set_local $w6 (i32.rotl (i32.xor (get_local $w6) (get_local $w11)) (i32.const 7)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 16)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 12)))

        (set_local $w2 (i32.add (get_local $w7) (get_local $w2)))
        (set_local $w13 (i32.rotl (i32.xor (get_local $w13) (get_local $w2)) (i32.const 8)))

        (set_local $w8 (i32.add (get_local $w13) (get_local $w8)))
        (set_local $w7 (i32.rotl (i32.xor (get_local $w7) (get_local $w8)) (i32.const 7)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 16)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 12)))

        (set_local $w3 (i32.add (get_local $w4) (get_local $w3)))
        (set_local $w14 (i32.rotl (i32.xor (get_local $w14) (get_local $w3)) (i32.const 8)))

        (set_local $w9 (i32.add (get_local $w14) (get_local $w9)))
        (set_local $w4 (i32.rotl (i32.xor (get_local $w4) (get_local $w9)) (i32.const 7)))


        ;; PERMUTATION FINISHED

        (i32.store offset=64  (get_local $ctx) (i32.add (get_local $w0 ) (i32.load offset=0  (get_local $ctx))))
        (i32.store offset=68  (get_local $ctx) (i32.add (get_local $w1 ) (i32.load offset=4  (get_local $ctx))))
        (i32.store offset=72  (get_local $ctx) (i32.add (get_local $w2 ) (i32.load offset=8  (get_local $ctx))))
        (i32.store offset=76  (get_local $ctx) (i32.add (get_local $w3 ) (i32.load offset=12 (get_local $ctx))))
        (i32.store offset=80  (get_local $ctx) (i32.add (get_local $w4 ) (i32.load offset=16 (get_local $ctx))))
        (i32.store offset=84  (get_local $ctx) (i32.add (get_local $w5 ) (i32.load offset=20 (get_local $ctx))))
        (i32.store offset=88  (get_local $ctx) (i32.add (get_local $w6 ) (i32.load offset=24 (get_local $ctx))))
        (i32.store offset=92  (get_local $ctx) (i32.add (get_local $w7 ) (i32.load offset=28 (get_local $ctx))))
        (i32.store offset=96  (get_local $ctx) (i32.add (get_local $w8 ) (i32.load offset=32 (get_local $ctx))))
        (i32.store offset=100 (get_local $ctx) (i32.add (get_local $w9 ) (i32.load offset=36 (get_local $ctx))))
        (i32.store offset=104 (get_local $ctx) (i32.add (get_local $w10) (i32.load offset=40 (get_local $ctx))))
        (i32.store offset=108 (get_local $ctx) (i32.add (get_local $w11) (i32.load offset=44 (get_local $ctx))))
        (i32.store offset=112 (get_local $ctx) (i32.add (get_local $w12) (i32.load offset=48 (get_local $ctx))))
        (i32.store offset=116 (get_local $ctx) (i32.add (get_local $w13) (i32.load offset=52 (get_local $ctx))))
        (i32.store offset=120 (get_local $ctx) (i32.add (get_local $w14) (i32.load offset=56 (get_local $ctx))))
        (i32.store offset=124 (get_local $ctx) (i32.add (get_local $w15) (i32.load offset=60 (get_local $ctx))))))
