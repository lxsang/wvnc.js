#zlib library
importScripts('wvnc_asm.js')
api = {}
resolution = undefined
#frame_buffer = undefined
#timeout = undefined
Module.onRuntimeInitialized = () ->
    api =
    {
        createBuffer: Module.cwrap('create_buffer', 'number', ['number', 'number']),
        destroyBuffer: Module.cwrap('destroy_buffer', '', ['number']),
        updateBuffer: Module.cwrap("update", 'number', ['number', 'number', 'number', 'number', 'number', 'number']),
        decodeBuffer: Module.cwrap("decode",'number', ['number', 'number', 'number','number'] )
    }

wasm_update = (msg) ->
    datain = new Uint8Array msg
    x = datain[1] | (datain[2] << 8)
    y = datain[3] | (datain[4] << 8)
    w = datain[5] | (datain[6] << 8)
    h = datain[7] | (datain[8] << 8)
    flag = datain[9]
    p = api.createBuffer datain.length
    Module.HEAP8.set datain, p
    size = w * h * 4
    po = api.decodeBuffer p, datain.length, size
    #api.updateBuffer frame_buffer, p, datain.length, resolution.w, resolution.h, resolution.depth
    #api.destroyBuffer p
    # create buffer array and send back to main
    dataout = new Uint8Array Module.HEAP8.buffer, po, size
    # console.log dataout
    msg = {}
    tmp = new Uint8Array size
    tmp.set dataout, 0
    msg.pixels = tmp.buffer
    msg.x = x
    msg.y = y
    msg.w = w
    msg.h = h
    postMessage msg, [msg.pixels]
    #if flag isnt 0x0 or resolution.depth isnt 32
    api.destroyBuffer po
    api.destroyBuffer p

#update_screen = () ->
#    size = resolution.w * resolution.h * 4
#    dataout = new Uint8Array Module.HEAP8.buffer, frame_buffer, size
#    tmp = new Uint8Array size
#    tmp.set dataout, 0
#    postMessage tmp.buffer, [tmp.buffer]
#    timeout = setTimeout(update_screen, 50)

onmessage = (e) ->
    if e.data.depth
        resolution = e.data
        #api.destroyBuffer frame_buffer if frame_buffer
        #frame_buffer = api.createBuffer resolution.w * resolution.h * 4
   # else if e.data.cleanup
    #    api.destroyBuffer frame_buffer if frame_buffer
    #    clearTimeout(timeout)
    #    timeout = undefined
    else
        wasm_update e.data
        #if timeout is undefined
        #    timeout = setTimeout(update_screen, 50)