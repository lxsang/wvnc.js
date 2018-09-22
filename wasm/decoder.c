#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <zlib.h>
#include <jpeglib.h>
#include <string.h>
#include "emscripten.h"
/*
* This file is the decoder for the wvnc data
* received on the client side, it will be complied
* to web assembly to be used on the browser
*/

typedef struct{
    uint8_t r;
    uint8_t g;
    uint8_t b;
} raw_pixel_t;
EMSCRIPTEN_KEEPALIVE
uint8_t* create_buffer(int size) {
  return malloc(size);
}
/*destroy buffer*/
EMSCRIPTEN_KEEPALIVE
void destroy_buffer(uint8_t* p) {
  free(p);
}
int decode_zlib(uint8_t* in,int size_in, uint8_t* out, int size_out)
{
    z_stream dstream;
    dstream.zalloc = Z_NULL;
    dstream.zfree = Z_NULL;
    dstream.opaque = Z_NULL;
    dstream.next_in = in;
    dstream.avail_in = size_in;
    dstream.avail_out = size_out;
    dstream.next_out = out;
    inflateInit(&dstream);
    inflate(&dstream, Z_FINISH);
    inflateEnd(&dstream);
    return dstream.total_out;
}


int decode_jpeg(uint8_t* in,int size_in, uint8_t* out)
{
    struct jpeg_decompress_struct cinfo = {0};
    struct jpeg_error_mgr jerror = {0};
    cinfo.err = jpeg_std_error(&jerror);
    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, in, size_in);
    // check if the jpeg is valid
    int rc = jpeg_read_header(&cinfo, TRUE);
	if (rc != 1) {
		printf("Cannot read JPEG header");
		return 0;
    }
    //cinfo.out_color_space = JCS_RGB;
    //cinfo.dct_method = JDCT_ISLOW;
    jpeg_start_decompress(&cinfo);
    int width = cinfo.output_width;
	int height = cinfo.output_height;
    int osize = width*height*3;
    int row_stride = width * 3;
    //printf("width %d, height %d %d\n", width, height, cinfo.output_components);
    uint8_t * tmp = (uint8_t*) malloc(osize);
    uint8_t * line_buffer[1];
    int index;
    while( cinfo.output_scanline < height ){
        line_buffer[0] = tmp +(cinfo.output_scanline) * row_stride;
        jpeg_read_scanlines(&cinfo, line_buffer, 1);
    }
    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    for(int j = 0; j < height; j++)
    {
        for(int i = 0; i < width; i++)
        {
            index = j*width*4 + i*4;
            memcpy(out + index, tmp + j*width*3 + i*3, 3);
            *(out + index + 3) = 255;
        }
    }
    //copy
    //memcpy(out, tmp, osize);
    //free
    free(tmp);
    return osize;
}


int decode_raw(uint8_t* in,int size, int depth, uint8_t* out)
{
    if(depth != 24 && depth != 16)
    {
        printf("Depth % d is not supported\n", depth);
        return 0;
    }
    int components = depth/8;
    int npixels = size / components;
    int outsize = npixels*4;
    unsigned int value = 0;
    uint8_t* tmp = (uint8_t*) malloc(outsize);
    raw_pixel_t px;
    for(int i = 0; i < npixels; i++)
    {
        value = 0;
        for(int j=0; j < components; j++ )
            value = (in[i * components + j] << (j*8)) | value ;
        // lookup for pixel
        
        switch (depth)
        {
            case 24:
                px.r = value & 0xFF;
                px.g = (value >> 8) & 0xFF;
                px.b = (value >> 16) & 0xFF;
                break;
            case 16:
                px.r = (value & 0x1F) * (255 / 31);
                px.g = ((value >> 5) & 0x3F) * (255 / 63);
                px.b = ((value >> 11) & 0x1F) * (255 / 31);
                break;
            default:
                break;
        }
        tmp[i*4] = px.r;
        tmp[i*4+1] = px.g;
        tmp[i*4+2] = px.b;
        tmp[i*4+3] = 255;
    }
    memcpy(out, tmp, outsize);
    free(tmp);
    return outsize;
}

void update_buffer(uint8_t* fb, uint8_t* data, int x, int y, int w, int h, int bw)
{
    //printf("update buffer\n");
    //copy line by line
    uint8_t *src_ptr, *dest_ptr;
    for(int j = 0; j < h; j++)
    {
        src_ptr = data + (j*w*4);
        dest_ptr = fb + ((j+y)*bw*4 + x*4);
        memcpy(dest_ptr, src_ptr, w*4);
    }
}

EMSCRIPTEN_KEEPALIVE
uint8_t* decode(uint8_t* data, int data_size, int depth, int size_out)
{
    uint8_t flag = data[9];
    //printf("x %d y %d w %d h %d flag %d\n",x,y,w,h,flag);
    uint8_t* encoded_data = data + 10;
    uint8_t* decoded_data = NULL;
    int ret = 0;
    if(flag == 0x0 && depth == 32)
    {
        return encoded_data;
    }
    else
    {
        decoded_data = (uint8_t*) malloc(size_out);
        switch (flag)
        {
            case 0x0: // raw 24 or 16 bits
                ret = decode_raw(encoded_data,data_size,depth, decoded_data);
                break;
            case 0x1: // jpeg data
                ret = decode_jpeg(encoded_data, data_size, decoded_data);
                break;
            case 0x2: // zlib data
                ret = decode_zlib(encoded_data, data_size, decoded_data, size_out);
                if(ret > 0 && depth != 32)  
                    ret = decode_raw(decoded_data,ret,depth, decoded_data);
                break;
            case 0x3: // jpeg and zlib data
                ret = decode_zlib(encoded_data, data_size, decoded_data, size_out);
                if(ret > 0)
                    ret = decode_jpeg(decoded_data, ret, decoded_data);
                break;
            default:
                if(decoded_data) free(decoded_data);
                return NULL;
        }
        // write decoded data to buffer
        return decoded_data;
    }
}

/*decode the data format*/
EMSCRIPTEN_KEEPALIVE
int update(uint8_t* fb, uint8_t* data, int data_size, int bw, int bh, int depth)
{
    int x,y,w,h;
    uint8_t flag;
    // data [0] is commad
    x = data[1] | (data[2] << 8);
    y = data[3] | (data[4] << 8);
    w = data[5] | (data[6] << 8);
    h = data[7] | (data[8] << 8);
    flag = data[9];
    uint8_t* decoded_data = decode(data, data_size, depth, w*h*4);
    if(decoded_data)
        update_buffer(fb,decoded_data,x,y,w,h,bw);
        if(flag != 0x0 || depth != 32) free(decoded_data);
    else
        printf("Cannot decode data\n");
    return 1;
    
}
