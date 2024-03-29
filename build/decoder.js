// Generated by CoffeeScript 1.12.8
  var api, onmessage, resolution, wasm_update;

  importScripts('wvnc_asm.js');

  api = {};

  resolution = void 0;

  Module.onRuntimeInitialized = function() {
    return api = {
      createBuffer: Module.cwrap('create_buffer', 'number', ['number', 'number']),
      destroyBuffer: Module.cwrap('destroy_buffer', '', ['number']),
      updateBuffer: Module.cwrap("update", 'number', ['number', 'number', 'number', 'number', 'number']),
      decodeBuffer: Module.cwrap("decode", 'number', ['number', 'number', 'number'])
    };
  };

  wasm_update = function(msg) {
    var bbp, datain, dataout, flag, h, p, po, size, tmp, w, x, y;
    datain = new Uint8Array(msg);
    x = datain[1] | (datain[2] << 8);
    y = datain[3] | (datain[4] << 8);
    w = datain[5] | (datain[6] << 8);
    h = datain[7] | (datain[8] << 8);
    flag = datain[9] & 0x01;
    bbp = datain[9] & 0xFE;
    msg = {};
    msg.pixels = void 0;
    msg.x = x;
    msg.y = y;
    msg.w = w;
    msg.h = h;
    size = w * h * 4;
    if (size === 0) {
      return;
    }
    tmp = new Uint8Array(size);
    p = api.createBuffer(datain.length);
    Module.HEAP8.set(datain, p);
    po = api.decodeBuffer(p, datain.length, size);
    dataout = new Uint8Array(Module.HEAP8.buffer, po, size);
    tmp.set(dataout, 0);
    msg.pixels = tmp.buffer;
    postMessage(msg, [msg.pixels]);
    api.destroyBuffer(p);
    if (flag !== 0x0 || bbp !== 32) {
      return api.destroyBuffer(po);
    }
  };

  onmessage = function(e) {
    if (e.data.width) {
      return resolution = e.data;
    } else {
      return wasm_update(e.data);
    }
  };

