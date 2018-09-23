# wvnc.js

**wvnc.js** is the client side protocol API for my [Antd's **wvnc**](https://github.com/lxsang/antd-wvnc-plugin) server side plugin. It allows to acess to VNC server from the web using websocket (via the **wvnc** server plugin).

Since the **wvnc** plugin offers data compression using JPEG and Zlib, **wvnc.js** uses **web assembly** and **web worker** to speed up the data decoding process, thus speed up the screen rendering on HTML canvas.

A prebuild version of **wvnc.js** is available in the **build** folder:
* **wvnc.js**:  main API class
* **decoder.js**: used by web worker to decode compressed data in the background
* **wvnc_asm.\***: web assembly version of the decoder API using libjeg and zlib

## Build from source
### Dependencies
* Coffee script
* uglifyjs
* EMSDK tool chain for web assembly [https://github.com/juj/emsdk](https://github.com/juj/emsdk)

### Build
Since the decoder relies on **libjpeg** and **zlib**, execute following command to fetch and build these libraries using emsdk tool chain:

```sh
make dep
```
Then build the code:
```
make
```
## Example
It is straight forward to use the api, first include the **wvnc.js** to the html file
```html
<!DOCTYPE html>
<html>
  <head>
    <script src="wvnc.js"></script>
    <title>VNC client</title>
  </head>
  <body>
    <canvas id = "screen"></canvas>
  </body>
</html>
```

Then in a **script** tag:
```javascript
  var args, client;
  args = {
    // the canvas element
    element: 'screen',
    // The websocket uri to the wvnc server side plugin
    ws: 'wss://localhost:9192/wvnc',
    // the decoder worker
    worker: 'decoder.js'
  };
  client = new WVNC(args);
  
  // This function responds to a VNC server password request
  // should return a promise
  client.onpassword = function() {
    return new Promise(function(r, e) {
      return r('password');
    });
  };
  
  // this function responds to the remote OS username and password request
  // should return a promise
  client.oncredential = function() {
    return new Promise(function(r, e) {
      return r('username', 'password');
    });
  };
  // event fired when a text is copied on
  // the remote computer
  client.oncopy = function(text) {
    console.log(text);
  };
  // init the WVNC client
  client.init()
    .then(function() {
        client.connect(
          // VNC server
          "192.168.1.20:5901", 
          {
            // bits per pixel
            bbp: 32,
            // data compression flag
            // 3 is for both JPEG and ZLIB compression
            flag: 3,
            // JPEG quality %
            quality: 50
          });
    })
    .catch(function(m, s) {
      return console.error(m, s);
    });
```
