class WVNC
    constructor: (args) ->
        @socket = undefined
        @ws = undefined
        @canvas = undefined
        worker = 'decoder.js'
        @scale = 1.0
        @ws = args.ws if args.ws
        @canvas = args.element
        @canvas = document.getElementById @canvas if typeof @canvas is 'string'
        worker = args.worker if args.worker
        @decoder = new Worker worker
        me = @
        @mouseMask = 0
        @decoder.onmessage = (e) ->
            me.process e.data
    init: () ->
        me = @
        return new Promise (r, e) ->
            return e('Canvas is not set') if not me.canvas
            me.initInputEvent()
            r()

    initInputEvent: () ->
        me = @
        return unless @canvas
        getMousePos = (e) ->
            rect = me.canvas.getBoundingClientRect()
            pos=
                x:  Math.floor((e.clientX - rect.left) / me.scale)
                y: Math.floor((e.clientY - rect.top) / me.scale)
            return pos

        sendMouseLocation = (e) ->
            p = getMousePos e
            me.sendPointEvent p.x, p.y, me.mouseMask

        return unless me.canvas
        me.canvas.oncontextmenu = (e) ->
            e.preventDefault()
            return false

        me.canvas.onmousemove = (e) -> sendMouseLocation e

        me.canvas.onmousedown = (e) ->
            state = 1 << e.button
            me.mouseMask = me.mouseMask | state
            sendMouseLocation e
            #e.preventDefault()

        me.canvas.onmouseup = (e) ->
            state = 1 << e.button
            me.mouseMask = me.mouseMask & (~state)
            sendMouseLocation e
            #e.preventDefault()

        me.canvas.onkeydown = me.canvas.onkeyup = (e) ->
            # get the key code
            keycode = e.keyCode
            #console.log e
            switch keycode
                when 8  then code = 0xFF08 #back space
                when 9  then code = 0xff89 #0xFF09 # tab ?
                when 13 then code = 0xFF0D # return
                when 27 then code = 0xFF1B # esc
                when 46 then code = 0xFFFF # delete to verify
                when 38 then code = 0xFF52 # up
                when 40 then code = 0xFF54 # down
                when 37 then code = 0xFF51 # left
                when 39 then code = 0xFF53 # right
                when 91 then code = 0xFFE7 # meta left
                when 93 then code = 0xFFE8 # meta right
                when 16 then code = 0xFFE1 # shift left
                when 17 then code = 0xFFE3 # ctrl left
                when 18 then code = 0xFFE9 # alt left
                when 20 then code = 0xFFE5 # capslock
                when 113 then code = 0xFFBF # f2
                when 112 then code = 0xFFBE # f1
                when 114 then code = 0xFFC0 # f3
                when 115 then code = 0xFFC1 # f4
                when 116 then code = 0xFFC2 # f5
                when 117 then code = 0xFFC3 # f6
                when 118 then code = 0xFFC4 # f7
                when 119 then code = 0xFFC5 # f8
                when 120 then code = 0xFFC6 # f9
                when 121 then code =  0xFFC7 # f10
                when 122 then code = 0xFFC8 # f11
                when 123 then code = 0xFFC9 # f12
                else
                    code = e.key.charCodeAt(0) #if not e.ctrlKey and not e.altKey
            #if ((keycode > 47 and keycode < 58) or (keycode > 64 and keycode < 91)  or (keycode > 95 and keycode < 112)  or (keycode > 185 and keycode < 193) or (keycode > 218 && keycode < 223))
            #    code = e.key.charCodeAt(0)
            #else 
            #    code = keycode
            e.preventDefault()
            return unless code
            if e.type is "keydown"
                me.sendKeyEvent code, 1
            else if e.type is "keyup"
                me.sendKeyEvent code, 0

        # mouse wheel event
        @canvas.addEventListener 'wheel', (e) ->
            #if (e.deltaY < 0) # up
            p = getMousePos e
            e.preventDefault()
            if e.deltaY < 0
                me.sendPointEvent p.x, p.y, 8
                me.sendPointEvent p.x, p.y, 0
                return
            me.sendPointEvent p.x, p.y, 16
            me.sendPointEvent p.x, p.y, 0
        # paste event
        @canvas.onpaste = (e) ->
            pastedText = undefined
            if window.clipboardData and window.clipboardData.getData  #IE
                pastedText = window.clipboardData.getData 'Text'
            else if e.clipboardData and e.clipboardData.getData
                pastedText = e.clipboardData.getData 'text/plain'
            return false unless pastedText
            e.preventDefault()
            me.sendTextAsClipboard pastedText
        # global event
        fn = (e) ->
            console.log "unload"
            me.socket.close() if me.socket
        window.addEventListener "unload", fn
        window.addEventListener "beforeunload", fn

    initCanvas: (w, h , d) ->
        me = @
        @depth = d
        @canvas.width = w
        @canvas.height = h
        @resolution =
            w: w,
            h: h,
            depth: @depth
        @decoder.postMessage @resolution
        me.canvas.style.cursor = "none"
        @setScale @scale

    process: (msg) ->
        if not @socket
            return
        data = new Uint8Array msg.pixels
        #w = @buffer.width * @scale
        #h = @buffer.height * @scale
        ctx = @canvas.getContext "2d", { alpha: false }
        imgData = ctx.createImageData  msg.w, msg.h
        imgData.data.set data
        ctx.putImageData imgData, msg.x, msg.y
        

    setScale: (n) ->
        @scale = n
        return unless @canvas
        @canvas.style.transformOrigin = '0 0'
        @canvas.style.transform = 'scale(' + n + ')'


    connect: (url, args) ->
        me = @
        @socket.close() if @socket
        return unless @ws
        @socket = new WebSocket @ws
        @socket.binaryType = "arraybuffer"
        @socket.onopen = () ->
            console.log "socket opened"
            me.initConnection(url, args)

        @socket.onmessage =  (e) ->
            me.consume e
        @socket.onclose = () ->
            me.socket = null
            me.canvas.style.cursor = "auto"
            me.canvas.getContext('2d').clearRect 0,0, me.resolution.w, me.resolution.h if me.canvas
            console.log "socket closed"

    disconnect: () ->
        @socket.close()

    initConnection: (vncserver, params) ->
        #vncserver = "192.168.1.20:5901"
        data = new Uint8Array vncserver.length + 3
        data[0] = 32 # bbp
        ###
        flag:
            0: raw data no compress
            1: jpeg no compress
            2: raw data compressed by zlib
            3: jpeg data compressed by zlib
        ###
        data[1] = 2
        data[2] = 50 # jpeg quality
        if params
            data[0] = params.bbp if params.bbp
            data[1] = params.flag if params.flag
            data[2] = params.quality if params.quality
        ## rate in milisecond

        data.set (new TextEncoder()).encode(vncserver), 3
        @socket.send(@buildCommand 0x01, data)

    sendPointEvent: (x, y, mask) ->
        return unless @socket
        data = new Uint8Array 5
        data[0] = x & 0xFF
        data[1] = x >> 8
        data[2] = y & 0xFF
        data[3] = y >> 8
        data[4] = mask
        @socket.send( @buildCommand 0x05, data )

    sendKeyEvent: (code, v) ->
        return unless @socket
        data = new Uint8Array 3
        data[0] = code & 0xFF
        data[1] = code >> 8
        data[2] = v
        console.log code, v
        @socket.send( @buildCommand 0x06, data )

    buildCommand: (hex, o) ->
        data = undefined
        switch typeof o
            when 'string'
                data = (new TextEncoder()).encode(o)
            when 'number'
                data = new Uint8Array [o]
            else
                data = o
        cmd = new Uint8Array data.length + 3
        cmd[0] = hex
        cmd[2] = data.length >> 8
        cmd[1] = data.length & 0x0F
        cmd.set data, 3
        #console.log "the command is", cmd.buffer
        return cmd.buffer

    oncopy: (text) ->
        console.log "Get clipboard text: " + text

    onpassword: () ->
        return new Promise (resolve, reject) ->
            reject("onpassword is not implemented")

    sendTextAsClipboard: (text) ->
        return unless @socket
        console.log "send ", text
        @socket.send (@buildCommand 0x07, text)

    oncredential: () ->
        return new Promise (resolve, reject) ->
            reject("oncredential is not implemented")

    consume: (e) ->
        data = new Uint8Array e.data
        cmd = data[0]
        me = @
        switch  cmd
            when 0xFE #error
                data = data.subarray 1, data.length - 1
                dec = new TextDecoder("utf-8")
                console.log "Error", dec.decode(data)
            when 0x81
                console.log "Request for password"
                @onpassword().then (pass) ->
                    me.socket.send (me.buildCommand 0x02, pass)
            when 0x82
                console.log "Request for login"
                @oncredential().then (user, pass) ->
                    arr = new Uint8Array user.length + pass.length + 1
                    arr.set (new TextEncoder()).encode(user), 0
                    arr.set ['\0'], user.length
                    arr.set (new TextEncoder()).encode(pass), user.length + 1
                    me.socket.send(me.buildCommand 0x03, arr)
            when 0x83
                console.log "resize"
                w = data[1] | (data[2]<<8)
                h = data[3] | (data[4]<<8)
                depth = data[5]
                @initCanvas w, h, depth
                # status command for ack
                @socket.send(@buildCommand 0x04, 1)
            when 0x84
                # send data to web assembly for decoding
                @decoder.postMessage data.buffer, [data.buffer]
            when 0x85
                # clipboard data from server
                data = data.subarray 1
                dec = new TextDecoder "utf-8"
                @oncopy dec.decode data
                @socket.send(@buildCommand 0x04, 1)
            else
                console.log cmd

window.WVNC = WVNC