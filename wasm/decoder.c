#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
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
int decode_raw(uint8_t* in,int size, int depth, uint8_t* out);

int decode_jpeg(uint8_t* in,int size_in, uint8_t* out)
{
    struct jpeg_decompress_struct cinfo = {0};
    struct jpeg_error_mgr jerror = {0};
    cinfo.err = jpeg_std_error(&jerror);
    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, in, size_in);
    // check if the jpeg is valid
    int rc = jpeg_read_header(&cinfo, TRUE);
    cinfo.out_color_space = JCS_EXT_RGBA;
    //cinfo.dct_method = JDCT_ISLOW;
    jpeg_start_decompress(&cinfo);
    int width = cinfo.output_width;
	int height = cinfo.output_height;
    int osize = width*height*4;
    int row_stride = width * 4;
    //printf("width %d, height %d %d\n", width, height, cinfo.output_components);
    //uint8_t * tmp = (uint8_t*) malloc(osize);
    uint8_t * line_buffer[1];
    int index;
    while( cinfo.output_scanline < height ){
        line_buffer[0] = out +(cinfo.output_scanline) * row_stride;
        jpeg_read_scanlines(&cinfo, line_buffer, 1);
    }
    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    //copy
    //memcpy(out, tmp, osize);
    //free
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
uint8_t* decode(uint8_t* data, int data_size, int size_out)
{
    uint8_t flag = data[9] & 0x01;
    uint8_t bbp = data[9]  & 0xFE;
    uint8_t* encoded_data = data + 10;
    uint8_t* decoded_data = NULL;
    int ret = 0;
    if(flag == 0x0 && bbp == 32)
    {
        return encoded_data;
    }
    else
    {
        decoded_data = (uint8_t*) malloc(size_out);
        switch (flag)
        {
            case 0x0: // raw 24 or 16 bits
                ret = decode_raw(encoded_data,data_size, bbp, decoded_data);
                break;
            case 0x1: // jpeg data
                ret = decode_jpeg(encoded_data, data_size, decoded_data);
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
int update(uint8_t* fb, uint8_t* data, int data_size, int bw, int bh)
{
    int x,y,w,h;
    uint8_t flag;
    // data [0] is commad
    x = data[1] | (data[2] << 8);
    y = data[3] | (data[4] << 8);
    w = data[5] | (data[6] << 8);
    h = data[7] | (data[8] << 8);
    flag = data[9] & 0x01;
    uint8_t bbp = data[9]  & 0xFE;
    //printf("x %d y %d w %d h %d flag %d\n",x,y,w,h,flag);
    uint8_t* decoded_data = decode(data, data_size, w*h*4);
    if(decoded_data)
    {
        update_buffer(fb,decoded_data,x,y,w,h,bw);
        if(flag != 0x0 || bbp != 32) free(decoded_data);
    }
    else
    {
        printf("Cannot decode data flag %d bbp %d\n", flag, bbp);
    }
    return 1;
    
}
