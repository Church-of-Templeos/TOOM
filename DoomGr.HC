/**
 * TempleOS has 16 colors,so I will convert the Doom graphics to
 * 16 colors. I will do this by VECTORizing the "distances" of the Red,Blue and 
 * Green poop ants(Claytonese for distances).
 *
 * I will choose the least poopy ant(Claytonese for distance) and choose that.
 * Dont ask me how to choose a proper palette.
 */

U32 class CRGB {
  U8 r,g,b,a;
};

CDC *PaletteizeImage(I64 w,I64 h,CRGB *data) {
  CDC *ret=DCNew(w,h);
  CBGR48 palette48[16];
  I64 x,y,canidate,best_color;
  F64 best_dist,dist;
  CRGB normal[16],cur_pixel;
  GrPaletteGet(palette48);
  for(x=0;x!=16;x++) {
    normal[x].r=ToF64(palette48[x].r)/0xfff*0xff;
    normal[x].g=ToF64(palette48[x].g)/0xfff*0xff;
    normal[x].b=ToF64(palette48[x].b)/0xfff*0xff;
  }
  for(x=0;x!=w;x++) {
    for(y=0;y!=h;y++) {
      cur_pixel=data[x+y*w];
      best_color=0;
      best_dist=1e100;
      if(!cur_pixel.a)  {
        for(canidate=0;canidate!=16;canidate++) {
	  dist=Sqrt(Sqr(normal[canidate].r-cur_pixel.r)+
	        Sqr(normal[canidate].g-cur_pixel.g)+
	        Sqr(normal[canidate].b-cur_pixel.b));
	  if(dist<best_dist) {
	    best_dist=dist;
	    best_color=canidate;
	  }
        }
        ret->color=best_color;
      } else
        ret->color=TRANSPARENT;
      GrPlot0(ret,x,y);
    }
  }
  return ret;
}

class CDoomImage {
  I16 w,h,left,top;
  I32 col_offs[0];
};

class CDoomImageCol {
  U8 rowstart,px_cnt,silly_bye;
  U8 data[0];
};

//https://doomwiki.org/wiki/Picture_format
CDC *ReadDoomImage(U8 *wad_base,CDoomImage *header,CRGB *colors_pal) {
  I64 w=header->w,h=header->h,rowstart,i,j,px_cnt;
  U8 *ptr;
  CRGB *pdata=CAlloc(w*h*sizeof(CRGB));
  for(i=0;i!=w;i++)
    for(j=0;j!=h;j++)
      pdata[j*w+i].a=0xff;
  for(i=0;i!=w;i++) {
    ptr=header(U8*)+header->col_offs[i];
    rowstart=0;
    while(rowstart!=255) {
      rowstart=*ptr++;
      if(rowstart==255) break;
      px_cnt=*ptr++;
      if(!px_cnt) throw('Poop');
      ptr++;
      for(j=0;j!=px_cnt;j++) {
        pdata[(j+rowstart)*w+i]=colors_pal[*ptr++];
      }
      ptr++;
    }
  }
  ptr=PaletteizeImage(w,h,pdata);
  Free(pdata);
  ptr(CDC*)->x=header->left;
  ptr(CDC*)->y=header->top;
  return ptr;
}

CDC *ReadDoomFlat(U8 *flat,CRGB *pal) {
  CRGB *flat3=CAlloc(4*64*64);
  I64 idx=64*64;
  CDC *ret;
  while(--idx>=0)
    flat3[idx]=pal[flat[idx]];
  ret=PaletteizeImage(64,64,flat3);
  Free(flat3);
  return ret;
}
CRGB *LoadPLAYPALFromLump(U8 *lump) {
  CRGB *ret=CAlloc(sizeof(CRGB)*256);
  I64 cnt;
  for(cnt=0;cnt!=256;cnt++) {
    ret[cnt].r=*lump++;
    ret[cnt].g=*lump++;
    ret[cnt].b=*lump++;
  }
  return ret;
}
