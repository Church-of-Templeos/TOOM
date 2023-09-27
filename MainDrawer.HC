#ifndef DOOM_MAIN
#define DOOM_MAIN "Doom" 
class CWad {
  U8 body[0];
  U8 ident[4];
  U32 lump_cnt;
  U32 directory_ptr;
}; 


CWad *LoadWad(U8 *filename) {
  return FileRead(filename);
}

static CWad *wad=LoadWad("DOOM.WAD");

#include "Wad.HC";
//#include "Weapons.HC";
#include "ST.HC";
#include "FastTrig.HC"
class CDoomCamera {
  F64 x,y,h;
  F64 angle,fov;
//Private
//These include the wall heights too
  F64 floor_heights[GR_WIDTH/2]; //used for choosing which things not to draw
  F64 ceil_heights[GR_WIDTH/2]; //used for choosing which things not to draw
  F64 floor_depths[GR_WIDTH/2];
  F64 ceil_depths[GR_WIDTH/2];
//Cordnates are diveded by 2
  CDC *floor_dc; //This is black or white,this is used for reducing floor overdraw
  CFifoI64 *visible_sectors;
};
#define GRID_SZ  128
#define Y_SCALE 5
#define DIST_SCALE (GR_HEIGHT*GRID_SZ)

#define FLOOR_VPIXEL_WIDTH 2
#define WALL_VPIXEL_WIDTH 2
#define WALL_HPIXEL_HEIGHT 2
#define FLOOR_HPIXEL_HEIGHT 2

#define HIDDEN_BYTE 0xfe

asm {
_FAST_FIND_NOT_HIDDEN::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  MOV AX,HIDDEN_BYTE
  MOV RCX,U64 SF_ARG2[RBP]
  MOV RDI,U64 SF_ARG1[RBP]
  REPE SCASB 
  CMP RCX,0
  JLE @@fail
  MOV RAX,RDI
  POP RDI
  LEAVE
  RET1 16
@@fail:
  POP RDI
  MOVRAX,NULL
  LEAVE
  RET1 16
_FAST_FIND_HIDDEN::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  MOV AX,HIDDEN_BYTE
  MOV RCX,U64 SF_ARG2[RBP]
  MOV RDI,U64 SF_ARG1[RBP]
  REPNE SCASB 
  CMP RCX,0
  JLE @@fail
  MOV RAX,RDI
  POP RDI
  LEAVE
  RET1 16
@@fail:
  POP RDI
  MOVRAX,NULL
  LEAVE
  RET1 16

_FAST_FIND_NOT_HIDDEN_R::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  PUSHF
  MOV AX,HIDDEN_BYTE
  MOV RCX,U64 SF_ARG2[RBP]
  MOV RDI,U64 SF_ARG1[RBP]
  LEA RDI,-1[RDI+RCX]
  STD
  REPE SCASB 
  CMP RCX,0
  JLE @@fail
  LEA RAX,1[RDI]
  POPF
  POP RDI
  LEAVE
  RET1 16
@@fail:
  POPF
  POP RDI
  MOVRAX,NULL
  LEAVE
  RET1 16
_FAST_FIND_HIDDEN_R::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  PUSHF
  MOV AX,HIDDEN_BYTE
  MOV RCX,U64 SF_ARG2[RBP]
  MOV RDI,U64 SF_ARG1[RBP]
  LEA RDI,-1[RDI+RCX]
  STD
  REPNE SCASB 
  CMP RCX,0
  JLE @@fail
  LEA RAX,1[RDI]
  POPF
  POP RDI
  LEAVE
  RET1 16
@@fail:
  POPF
  POP RDI
  MOVRAX,NULL
  LEAVE
  RET1 16


};
_extern _FAST_FIND_NOT_HIDDEN U8 *FastFindNotHidden(U8 *data,I64 cnt);
_extern _FAST_FIND_HIDDEN U8 *FastFindHidden(U8 *data,I64 cnt);
_extern _FAST_FIND_NOT_HIDDEN_R U8 *FastFindNotHiddenR(U8 *data,I64 cnt);
_extern _FAST_FIND_HIDDEN_R U8 *FastFindHiddenR(U8 *data,I64 cnt);

/*
 * Listen up,here's the deal
 * A view plane is FLAT,not a point,so when we look at an angle,we 
 * need to "straigten" our line,otherwise we will have a curved lense effect 
 *
 * Ask Nroot about this
 */

I64 PointToLinedefSegment(CDoomCamera *cam,CDoomLinedef *def,CD2 *coord) {
  CD2 line_s,at;
  F64 dist;
  line_s.x=cam->x;
  line_s.y=cam->y;
  PlaneIntersect(&at,&line_s,coord,def->start,def->end);
  dist=Sqrt(Sqr(at.x-def->start->x)+Sqr(at.y-def->start->y));
  return ToI64(dist);
}

F64 Lerp(F64 per,F64 min,F64 max) {
  F64 tmp;
  if(min>max)
    return Clamp(per*(max-min)+min,max,min);
  return Clamp(per*(max-min)+min,min,max);

}

I64 YSort(CD2 *a,CD2 *b) {
  if(a->y>b->y)
    return 1;
  else if(a->y<b->y)
   return -1;
  return 0;
}


U0 TransformPointToCamera(CDoomCamera *cam,CD2 *p) {
  F64 x,y;
  F64 angle=FArg(x=p->x-cam->x,y=p->y-cam->y)-cam->angle;
  F64 dist=Sqrt(x*x+y*y);
  p->x=dist*FCos(angle);
  p->y=dist*FSin(angle);
}

Bool ScreenCordsToPlaneCoords(CDoomCamera *cam,CD2 *p,F64 level) {
  F64 angle=(p->x-GR_WIDTH/2)/(GR_WIDTH/2-1)*(cam->fov/2),dist;
  if(Abs(cam->h-level)<.05)
    dist=0;
  else
    dist=DIST_SCALE/((p->y-GR_HEIGHT/2)/(cam->h-level)*Clamp(FCos(angle),.8,1.)*GR_HEIGHT/Y_SCALE)-1;
  p->x=FCos(angle+cam->angle)*dist+cam->x;
  p->y=FSin(angle+cam->angle)*dist+cam->y;
  if(dist<0.) return FALSE;
  if(-cam->fov/2.<angle<cam->fov/2.)
    return TRUE;
  return FALSE;
}


Bool ClipLineToScrenCoords(CDoomCamera *cam,CD2 *p,CD2 *p2,F64 level=0.) {
  CD2 s,e,at,*ptr,debug;
  I64 cnt,fail_cnt;
  F64 angle;
  TransformPointToCamera(cam,p);
  TransformPointToCamera(cam,p2);
  if(p->x<1&&p2->x<1) return FALSE;
  s.x=1,e.x=1;
  s.y=I16_MIN,e.y=I16_MAX;  
  if(PlaneIntersect(&at,&s,&e,p,p2)) {
    if(p->x>=1) {
      p2->x=at.x;
      p2->y=at.y;
    } else {
      p->x=at.x;
      p->y=at.y;
    }
  }
  for(cnt=0;cnt!=2;cnt++) {
    if(!cnt) ptr=p;
    else ptr=p2;
    angle=FArg(ptr->x,ptr->y);
    at.x=GR_WIDTH/2+angle/(cam->fov/2)*(GR_WIDTH/2-1);
    at.y=GR_HEIGHT/2+DIST_SCALE/(1.+Sqrt(ptr->x*ptr->x+ptr->y*ptr->y))/GR_HEIGHT*Y_SCALE/Clamp(FCos(angle),.8,1.)*(cam->h-level);
    ptr->x=at.x;
    ptr->y=at.y;
  }
  return TRUE;
}

U0 PlotSpriteIn3DSpace(CDC *to_dc,CDC *sprite,CDoomCamera *cam,CD2 *p,F64 level,Bool reflect=FALSE) {
  CD2 copy,copy2;
  F64 new_height,new_width;
  I64 x,y,tox,fromx,toy,fromy,ix,iy,dist;
  U16 *from,*dst;
  I32 *db_z;
  copy.x=p->x,copy.y=p->y;
  copy2.x=p->x,copy2.y=p->y;
  if(!ClipLineToScrenCoords(cam,&copy,&copy2,level))
    return;
  dist=Sqrt(Sqr(p->x-cam->x)+Sqr(p->y-cam->y));
  new_height=DIST_SCALE/(1+ToF64(dist))/GR_HEIGHT*Y_SCALE*sprite->height;
  new_width=new_height/sprite->height*sprite->width;
  fromx=copy.x-new_width/2;
  tox=ClampI64(copy.x+new_width/2,0,GR_WIDTH-2);;
  fromy=copy.y-new_height;
  toy=ClampI64(copy.y,0,GR_HEIGHT-2);
  for(y=fromy;y<toy;y+=2) {
    if(y<0) y=0;
    if(y>toy) break;
    for(x=fromx;x<tox;x+=2) {
      if(x<0) x=0;
      if(x>tox) break;
       if(!reflect)
        ix=Lerp((x-fromx)/new_width,0,sprite->width-1);
      else
        ix=Lerp((x-fromx)/new_width,sprite->width-1,0);
      iy=Lerp((y-fromy)/new_height,0,sprite->height-1);
      from=&sprite->body[(ix&~1)+(iy&~1)*sprite->width_internal];
      db_z=&to_dc->depth_buf[x+y*to_dc->width_internal];
      if(*db_z>dist) {
        dst=&to_dc->body[x+y*to_dc->width_internal];
        if(from->u8[0]!=TRANSPARENT)
          *dst=*from,*db_z=dist;
        from(U8*)+=sprite->width_internal;
        dst(U8*)+=to_dc->width_internal;
        if(from->u8[0]!=TRANSPARENT)
          *dst=*from,*db_z=dist;
      }
    }
  }
}

CDoomSector *GetSectorForCoord(CDoomLevel *level,I64 x,I64 y) {
  CDoomSector *head=&level->sectors,*s=head->next;
  while(s!=head) {
    if(0<=x-s->shape_start_x<=s->shape_dc->width*2)
      if(0<=y-s->shape_start_y<=s->shape_dc->height*2) {
        if(GrPeek0(s->shape_dc,(x-s->shape_start_x)/2,(y-s->shape_start_y)/2))
	  return s;
      }
    s=s->next;
  }
  return NULL;
}

U0 DrawAThing(CDC *to_dc,CDoomThing *thing,CDoomCamera *cam) {
  if(!thing->template) return; //???
  I64 anim_frame=tS*4,frame_cnt;
  F64 angle;
  CDC *sprite;
  CD2 p;
  Bool reflect;
  frame_cnt=StrLen(thing->template->animation);
  if(StrOcc(thing->template->animation,'+'))
    frame_cnt--; //Last one??? This is temporary so it doesnt mater now
  anim_frame%=frame_cnt;
  angle=FArg(cam->x-thing->x,cam->y-thing->y)+cam->angle+thing->angle;
  sprite=GetThingFaceSprite(thing->template,angle,'A'+anim_frame,&reflect);
  p.x=thing->x,p.y=thing->y;
  if(sprite)
    PlotSpriteIn3DSpace(to_dc,sprite,cam,&p,thing->height,reflect);
}


U0 DrawTexturedFlat(CDC *to_dc,CDoomCamera *cam,CDoomSector *sector,F64 at,CDC *texture,Bool floor=TRUE) {
  I64 x,y;
  I64 w=sector->shape_dc->width*2,h=sector->shape_dc->height*2;
  I64 floorx,floory;
  I32 *db_z,dist;
  U16 *dst,color;
  F64 maxx=I16_MIN,maxy=I16_MIN;
  F64 minx=I16_MAX,miny=I16_MAX,angle;
  CD2 point,point2,point3,point4;
  point.x=sector->shape_start_x;
  point.y=sector->shape_start_y;

  point2.x=sector->shape_start_x+w;
  point2.y=sector->shape_start_y;

  point3.x=sector->shape_start_x;
  point3.y=sector->shape_start_y+h;

  point4.x=sector->shape_start_x+w;
  point4.y=sector->shape_start_y+h;
  if(ClipLineToScrenCoords(cam,&point3,&point4,at)) {
    maxx=Max(maxx,point3.x);
    maxy=Max(maxy,point3.y);
    maxx=Max(maxx,point4.x);
    maxy=Max(maxy,point4.y);

    minx=Min(minx,point3.x);
    miny=Min(miny,point3.y);
    minx=Min(minx,point4.x);
    miny=Min(miny,point4.y);
  }
  if(ClipLineToScrenCoords(cam,&point,&point2,at)) {
    maxx=Max(maxx,point2.x);
    maxy=Max(maxy,point2.y);
    maxx=Max(maxx,point.x);
    maxy=Max(maxy,point.y);

    minx=Min(minx,point2.x);
    miny=Min(miny,point2.y);
    minx=Min(minx,point.x);
    miny=Min(miny,point.y);
  }

  point.x=sector->shape_start_x;
  point.y=sector->shape_start_y;

  point2.x=sector->shape_start_x+w;
  point2.y=sector->shape_start_y;

  point3.x=sector->shape_start_x;
  point3.y=sector->shape_start_y+h;

  point4.x=sector->shape_start_x+w;
  point4.y=sector->shape_start_y+h;


  if(ClipLineToScrenCoords(cam,&point2,&point4,at)) {
    maxx=Max(maxx,point2.x);
    maxy=Max(maxy,point2.y);
    maxx=Max(maxx,point4.x);
    maxy=Max(maxy,point4.y);

    minx=Min(minx,point2.x);
    miny=Min(miny,point2.y);
    minx=Min(minx,point4.x);
    miny=Min(miny,point4.y);
  }
  if(ClipLineToScrenCoords(cam,&point,&point3,at)) {
    maxx=Max(maxx,point3.x);
    maxy=Max(maxy,point3.y);
    maxx=Max(maxx,point.x);
    maxy=Max(maxy,point.y);

    minx=Min(minx,point3.x);
    miny=Min(miny,point3.y);
    minx=Min(minx,point.x);
    miny=Min(miny,point.y);
  }


  if(maxx<minx)
    return;
  minx=Max(0,minx);
  miny=Max(0,miny);
  maxx=Min(GR_WIDTH-2,maxx);
  maxy=Min(GR_HEIGHT-2,maxy);
  for(x=minx;x<maxx;x+=2) {
    angle=(ToF64(x)-GR_WIDTH/2)/(GR_WIDTH/2)*cam->fov/2;
    for(y=miny;y<maxy;y+=2) {
      if(!GrPeek0(cam->floor_dc,x/2,y/2)) {
        point.x=x,point.y=y;
        if(ScreenCordsToPlaneCoords(cam,&point,at)) {
	  dist=Sqrt(Sqr(point.x-cam->x)+Sqr(point.y-cam->y));
	  point.x-=sector->shape_start_x;
	  point.y-=sector->shape_start_y;
	  if(0.<=point.x<w)
	    if(0.<=point.y<h){
	      db_z=&to_dc->depth_buf[x+y*to_dc->width_internal];
	      if(*db_z>dist)
	        if(GrPeek0(sector->shape_dc,point.x/2,point.y/2)) {
		  cam->floor_dc->color=WHITE;
		  GrPlot0(cam->floor_dc,x/2,y/2);
		  db_z[0]=dist;
		  db_z[1]=dist;
		  db_z+=to_dc->width_internal;
		  db_z[0]=dist;
		  db_z[1]=dist;
		  floorx=point.x;
		  floory=point.y;
		  floorx=(2*floorx%texture->width)&~1;
		  floory=(2*floory%texture->height)&~1;
		  if(floorx<0) floorx=-floorx;
		  if(floory<0) floory=-floory;
		  color=texture->body[floorx+floory*texture->width](U16);
		  dst=&to_dc->body[x+y*to_dc->width_internal];
		  *dst=color;
		  dst(U8*)+=to_dc->width_internal;
		  color=texture->body[floorx+(1+floory)*texture->width](U16);
		  *dst=color;
	        }
	    }
        }
      }
next:;
    }
  }
} 

Bool TextureMapWall(CDC *to_dc,F64 sx,F64 sy,F64 sh,F64 ex,F64 ey,F64 eh,
	I64 start_seg,I64 end_seg,CDC *texture,F64 sz,F64 ez,CDoomCamera *cam,
	Bool floor=FALSE,Bool ceil=FALSE,Bool no_draw=FALSE) {
  F64 cx,h,cy,at_y,cur_z,to_x,to_h,from,to;
  F64 percent;
  I64 texture_x,texture_y;
  U16 *super_pixel,*dst;
  I32 *db_z;
  U8 *col;
  I64 hi;
  Bool written=FALSE,changed=FALSE;
  if(sx>ex) {
    SwapI64(&sx,&ex);
    SwapI64(&sy,&ey);
    SwapI64(&sh,&eh);
    SwapI64(&sz,&ez);
    SwapI64(&start_seg,&end_seg);
  }
  to_x=MinI64(ex,GR_WIDTH-WALL_VPIXEL_WIDTH)&~1; //Align to 2 
  if(sy-sh>=GR_HEIGHT&&ey-eh>=GR_HEIGHT) return;
  for(cx=MaxI64(sx,0)&~1;cx<=to_x;cx+=WALL_VPIXEL_WIDTH) { //&~1 aligns to 2
    percent=(cx-sx)/(ex-sx);
    h=percent*(eh-sh)+sh;
    texture_x=percent*(end_seg-start_seg)+start_seg;
    if(texture_x<0) texture_x=-texture_x;
//Heres' the deal,I dither in 2x2 "super-pixels",so chop off first bit to get aligned to 2
    texture_x=(2*texture_x%texture->width)&~1; //*2 for "super-pixel"
    at_y=percent*(ey-sy)+sy-h;
    cur_z=percent*(ez-sz)+sz;
    hi=ClampI64(h,0,GR_HEIGHT*5);
//"Clip" the visible area between drawn ceiling/floor
    if(cam->ceil_depths[ToI64(cx)/2]<cur_z) {  
      from=Max(0,cam->ceil_heights[ToI64(cx)/2]-at_y);
    } else
      from=0;
    if(cam->floor_depths[ToI64(cx)/2]<cur_z) {  
      to=Min(hi,cam->floor_heights[ToI64(cx)/2]-at_y);
    } else
      to=hi;
    written=FALSE;
    if(at_y>=GR_HEIGHT)
      goto skip;
    if(at_y+to<0)
      goto skip;
    for(cy=from;cy<=to;cy+=WALL_HPIXEL_HEIGHT) {
      if(at_y+cy>GR_HEIGHT-WALL_HPIXEL_HEIGHT) {
        break;
      } else if(at_y+cy>=0) {
//I willl only check 2 buf for 1 pixel,assume other pixels are same as we render in 2x2 super pixels
        db_z=&to_dc->depth_buf[ToI64(cx)+ToI64(at_y+cy)*to_dc->width_internal];
        if(*db_z>cur_z) {
	  written=TRUE;
	  changed=TRUE;
	  if(!no_draw) {
	    texture_y=Lerp(cy/h,0,texture->height/2);
	    texture_y=(2*texture_y%texture->height)&~1;
	    super_pixel=&texture->body[texture_x+texture_y*texture->width_internal];
	    dst=&to_dc->body[ToI64(cx)+ToI64(at_y+cy)*to_dc->width_internal];
	    *dst=*super_pixel;
	    super_pixel(U8*)+=texture->width_internal;
	    dst(U8*)+=to_dc->width_internal;
	    *dst=*super_pixel;
	    db_z[0]=cur_z;
	    db_z[1]=cur_z;
	    db_z+=to_dc->width_internal;
	    db_z[0]=cur_z;
	    db_z[1]=cur_z;
	  } else {
	    changed=TRUE;
	    return changed; 
	  }
        }
      } else {
        cy+=0-(at_y+cy)-WALL_HPIXEL_HEIGHT;
      }
    }
skip:;
    if(written&&!no_draw) {
      if(floor&&cam->floor_depths[ToI64(cx)/2]>cur_z) {
        cam->floor_heights[ToI64(cx)/2]=at_y+from;
        cam->floor_depths[ToI64(cx)/2]=cur_z;
      } 
      if(ceil&&cam->ceil_depths[ToI64(cx)/2]>cur_z) {
        cam->ceil_heights[ToI64(cx)/2]=to+at_y;
        cam->ceil_depths[ToI64(cx)/2]=cur_z;
      }
    }
  }
  return changed;
}

F64 FloorRaise(CDoomLinedef *l,CDoomSector *sector) {
  F64 ret=sector->floor_height;
  if(l->back^^l->front) {
    if(l->back) return Max(ret,l->back->sector->floor_height);
    if(l->front) return Max(ret,l->front->sector->floor_height);
    return ret;
  }
  return Max(l->front->sector->floor_height,Max(
	l->back->sector->floor_height,ret
	));
}

F64 CeilDepress(CDoomLinedef *l,CDoomSector *sector) {
  F64 ret=sector->ceil_height;
  if(l->back^^l->front) {
    if(l->back) return Min(ret,l->back->sector->ceil_height);
    if(l->front) return Min(ret,l->front->sector->ceil_height);
    return ret;
  }
  return Min(l->front->sector->ceil_height,Min(
	l->back->sector->ceil_height,ret
	));
}


U0 DrawSubsector(CDC *to_dc,CDoomCamera *cam,CDoomSubsector *ss) {
  CD2 start_floor,start_ceil;
  CD2 end_floor,end_ceil;
  I64 seg_idx,wall,start_seg,end_seg;
  CDC *texture;
  F64 h,h2;
  Bool no_draw;
  CDoomBSPSeg *seg;
  CDoomSidedef *sidedef,*opposite;
  CDoomSector *sector,*sector2;
  Vector *wall_vect=CreateVector(2);
  CD2 cam_cord;
  I64 miss_cnt=0;
  F64 floor,ceil;
  for(seg_idx=0;seg_idx!=ss->cnt;seg_idx++) {
    seg=&ss->first[seg_idx];
//Use linedef as we want to see what side of the WALL we are on(not seg)
    cam_cord.x=cam->x-seg->linedef->start->x;
    cam_cord.y=cam->y-seg->linedef->start->y;
    SetVector(wall_vect,seg->linedef->end->x-seg->linedef->start->x,0);
    SetVector(wall_vect,seg->linedef->end->y-seg->linedef->start->y,1);
    opposite=NULL;
    if(seg->linedef->front^^seg->linedef->back) {
      if(seg->linedef->front)
        sidedef=seg->linedef->front;
      else
        sidedef=seg->linedef->back;	
    } else{
//Backface culling
      if(wall_vect->data[0]*cam_cord.y-wall_vect->data[1]*cam_cord.x<0.)
        sidedef=seg->linedef->front,opposite=seg->linedef->back;
      else
        sidedef=seg->linedef->back,opposite=seg->linedef->front;
    }
    no_draw=FALSE;
    if(!sidedef) {
//If the backside is invisible,the floor may still be visible
      sector=opposite->sector;
      sidedef=opposite;
      floor=sector->floor_height;
      ceil=sector->ceil_height;
      no_draw=TRUE;
      wall=2;
      if(!sector->drawn)
        goto draw_wall;
      else
        goto skip;
    }
    sector=sidedef->sector;
    for(wall=0;wall!=3;wall++) {
      if(wall==0&&(texture=sidedef->lower_texture)) {
        floor=Min(sector->floor_height,FloorRaise(seg->linedef,sector));
        ceil=Max(sector->floor_height,FloorRaise(seg->linedef,sector));
draw_wall:
        start_floor.x=seg->start->x;
        start_floor.y=seg->start->y;
        end_floor.x=seg->end->x;
        end_floor.y=seg->end->y;
        start_ceil.x=seg->start->x;
        start_ceil.y=seg->start->y;
        end_ceil.x=seg->end->x;
        end_ceil.y=seg->end->y;
        ClipLineToScrenCoords(cam,&start_floor,&end_floor,floor);
        ClipLineToScrenCoords(cam,&start_ceil,&end_ceil,ceil);
        start_seg=PointToLinedefSegment(cam,seg->linedef,seg->start);
        end_seg=PointToLinedefSegment(cam,seg->linedef,seg->end);
        h=Abs(start_floor.y-start_ceil.y);
        h2=Abs(end_ceil.y-end_floor.y);
        if(ToI64(h)&&ToI64(h2)) {
	  if(TextureMapWall(to_dc,start_floor.x,start_floor.y,h,end_floor.x,end_floor.y,h2,
	        start_seg,end_seg,texture,
	        Sqrt(Sqr(seg->start->x-cam->x)+Sqr(seg->start->y-cam->y)),
	        Sqrt(Sqr(seg->end->x-cam->x)+Sqr(seg->end->y-cam->y)),
	        cam,
	        wall==2||wall==0, //floor
	        wall==2||wall==1, //ceil
	        no_draw //If the wall is backfull culled,then dont draw it,TextureMapWall will register the visible floor/ceiling though
	        )) {
	    if(!sector->drawn) {
	      sector->drawn=TRUE;
	      FifoI64Ins(cam->visible_sectors,sector);
	    }
	    if(opposite&&opposite->sector&&!opposite->sector->drawn) {
	      opposite->sector->drawn=TRUE;
	      FifoI64Ins(cam->visible_sectors,opposite->sector);
	    }
	  }
        }
      } else if(wall==1&&(texture=sidedef->upper_texture)) {
        floor=Min(sector->ceil_height,CeilDepress(seg->linedef,sector));
        ceil=Max(sector->ceil_height,CeilDepress(seg->linedef,sector));
        goto draw_wall;
      } else if(wall==2&&(texture=sidedef->middle_texture)) {
        floor=sector->floor_height;
        ceil=sector->ceil_height;
        goto draw_wall;
      }
    }
skip:;
  }
}

U0 DrawBSP0(CDC *to_dc,CDoomCamera *cam,CDoomBSPNode *node) {
  if(node->signature!='NODE') {
    DrawSubsector(to_dc,cam,node);
    return;
  }
  if(node->visited) return;
  node->visited=TRUE;
  F64 left_dist,right_dist;
  CD2 cam_cord;
  cam_cord.x=node->x-cam->x;
  cam_cord.y=node->y-cam->y;
  Vector *vect=CreateVector(2);
  SetVector(vect,node->left_child->dx,0);
  SetVector(vect,node->left_child->dy,1);
  if(!IsFrontSideOfVector2D(vect,&cam_cord)) {
    DestroyVector(vect);
    DrawBSP0(to_dc,cam,node->left_child);
    DrawBSP0(to_dc,cam,node->right_child);
  } else {
    DestroyVector(vect);
    DrawBSP0(to_dc,cam,node->right_child);
    DrawBSP0(to_dc,cam,node->left_child);
  }
  if(node->parent) DrawBSP0(to_dc,cam,node->parent);
  node->visited=FALSE;
}

U0 DrawBSP(CDC *to_dc,CDoomCamera *cam,CDoomLevel *level) {
  CDoomSubsector *ss;
  CDoomBSPNode *node=DoomWhichBSPNode(cam->x,cam->y,level,&ss);
  if(node)
   DrawBSP0(to_dc,cam,node);
}

I64 SectorFloorSort(CDoomSector *a,CDoomSector *b)  {
  if(a->floor_height>b->floor_height)
    return -1;
  if(a->floor_height<b->floor_height)
    return 1;
  return 0;
}

U0 DrawDoomWorld(CDoomCamera *cam,CDoomLevel *level,CDC *to_dc) {
  CDoomSector *sector,**sorted;  
  CDoomThing *thing;
  I64 idx=0,idx2;
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next)
    sector->drawn=FALSE;
  for(idx=0;idx!=GR_WIDTH/2;idx++) {
    cam->floor_heights[idx]=GR_HEIGHT;
    cam->ceil_heights[idx]=0;
    cam->floor_depths[idx]=I16_MAX;
    cam->ceil_depths[idx]=I16_MAX;
  }
  if(!cam->floor_dc)
    cam->floor_dc=DCNew(GR_WIDTH/2,GR_HEIGHT/2);
  DCFill(cam->floor_dc,0);
  if(!cam->visible_sectors)
    cam->visible_sectors=FifoI64New(512);

  FifoI64Flush(cam->visible_sectors);
  if(!to_dc->depth_buf)
    DCDepthBufAlloc(to_dc);
  else
    DCDepthBufRst(to_dc);
  DrawBSP(to_dc,cam,level);
  idx=0;
  sorted=MAlloc(8*FifoI64Cnt(cam->visible_sectors));
  while(FifoI64Rem(cam->visible_sectors,&sector))
    sorted[idx++]=sector;
//SectorFloorSort is highest floor first
  QSortI64(sorted,idx,&SectorFloorSort);
  for(idx2=0;idx2!=idx;idx2++) {
    if(sorted[idx2]->floor_dc)
      DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->floor_height,sorted[idx2]->floor_dc,TRUE);
    if(sorted[idx2]->ceil_dc)
      DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->ceil_height,sorted[idx2]->ceil_dc,FALSE);
  }
  for(thing=level->things.next;thing!=&level->things;thing=thing->next) {
    sector=GetSectorForCoord(level,thing->x,thing->y);
    if(sector)
      thing->height=sector->floor_height;
    DrawAThing(to_dc,thing,cam);
  }
  Free(sorted);
}



U0 SongTask(I64)
{//Song by Robert Prince
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  Play("ttt");
  while (TRUE) {
    I64 i =3;
    while(i!=0)
    {
     Play("1AA2A1AA2G1AA2F1AA2D#1A2EF");
     Play("1AA2A1AA2G1AA2F1AA2D#D#D#D#");   
     i--;
    }
    Play("1AA2A1AA2G1AA2F1AA2D#1A2EF");
    Play("1AA2A1AA2G1AAtt3BA2F#3BDCB2F#3BCDEDCB2F#..");

    Play("1AA2A1AA2G1AA2F1AA2D#1A2EF");
    Play("1AA2A1AA2G1AA2F1AA2D#D#D#D#");   
    Play("1AA2A1AA2G1AA2F1AA2D#1A2EF");
    Play("1AA2A1AA2G1AAtt3ECACECEAECECEA..");
   
    Play("1DD2D1DD2C1DDA#1DDG#DDAA#");
    Play("1DD2D1DD2C1DDA#1DDG#G#G#G#");
    Play("1DD2D1DD2C1DDA#1DDG#DDAA#");
    Play("1DD2D1DD2C1DDtt4AGFAFDFADAFAFAFAFD.."); 
  

    Play("1AA2A1AA2G1AA2F1AA2D#1AA2EF");
    Play("1AA2A1AA2G1AA2F1AA2D#D#D#D#D#");    
    Play("1AA2A1AA2G1AA2F1AA2D#1AA2EF");
    Play("1AA2A1AA2G1AA2F1AA2D#D#D#D#D#");

    Play("1F#F#2F#1F#F#2E1F#F#2D1F#F#2C1F#F#2C#D");
    Play("1EE2E1EE2D1EE2C1D#D1A#A#A#A#");
  
    Play("1AA2A1AA2G1AA2F1AA2D#1AA2EF");
    Play("1AA2A1AA2G1AA2tt3AC2EC3A2E3CACA2EC3ACEA..");

    Play("1AA2A1AA2G1AA2F1AA2D#1AA2EF");
    Play("1AA2A1AA2G1AA2F1AA2D#D#D#D#D#");    
    Play("1AA2A1AA2G1AA2F1AA2D#1AA2EF");

    Play("1AA2A1AA2G1AAtt2G#FEB3B2G#ED3DB2G#E3EDB2G#..");
    Play("1AA2C1AA2B1AAG#AAGAAG2A");
    Play("1AA2C1AA2B1AAEAAF#F#F#F#");
  
    Play("1F#F#3C1F#F#3B1F#F#3A1F#F#2F#1F#F#2F#A");
    Play("1EE3B1EE3A1EE2G#1D#D2EEEE");

    Play("1AA2C1AA2B1AAG#AAGAAG2A");
    Play("1AA2C1AA2B1AAtt3DB2G#EDB1G#E3E3DB2G#EDB..");
    Play("1G#2A");
  }
}

//temp variable
I64 play_weap=0;

U0 AnimateTask(I64)
{
  while(TRUE)
  {   
   AnimateFire(play_weap);
   Sleep(60);  
  }
  
}
//#include"Collision";

CDoomCamera cam;
CDoomSector *sect=l->sectors.last;
"%x,$ER$%x\n",sect->linedef_cnt,sect->linedefs[0];
cam.x=sect->linedefs[0]->start->x;
cam.y=sect->linedefs[0]->start->y;
cam.fov=pi/4;
//cam.angle=-pi;
cam.h=0;
DocClear;
Fs->song_task=Spawn(&SongTask,NULL,"Song",,Fs);
Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
  
while(TRUE) {
  DCFill;
  if(GetSectorForCoord(l,cam.x,cam.y))
    cam.h=GetSectorForCoord(l,cam.x,cam.y)->floor_height+48;
  DrawDoomWorld(&cam,l,gr.dc);
  ST_Start(gr.dc);
  if(Bt(kbd.down_bitmap,SC_CURSOR_UP)) {
    //MoveInLevel(l,&cam.x,cam.angle,GRID_SZ/4,128,cam.h-48);
    ST_Key(0);
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_DOWN)) {
    //MoveInLevel(l,&cam.x,cam.angle,-GRID_SZ/4,128,cam.h-48);
    ST_Key(0);
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_LEFT)) {
     cam.angle-=pi/16;
     ST_Key(2);
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)) {
     cam.angle+=pi/16;
     ST_Key(1);
  }
  if(!Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)&&!Bt(kbd.down_bitmap,SC_CURSOR_LEFT)) {
     ST_Key(0);
  }
  if(ms.lb) {
     ST_Fire();
  }
  if(Bt(kbd.down_bitmap,Char2ScanCode('1'))) {
     play_weap=0;
     SwapWeapon(0);
  }
  if(Bt(kbd.down_bitmap,Char2ScanCode('2'))) {
     play_weap=1;
     SwapWeapon(1);
  }
  if(Bt(kbd.down_bitmap,Char2ScanCode('3'))) {
     play_weap=2;
     SwapWeapon(2);
  }
  if(Bt(kbd.down_bitmap,Char2ScanCode('\n')&0xff)) {
     DCFill;
     ST_Exit();
    break;
  }
  Refresh;
}
#endif