#include "Wad.HC";
class CDoomCamera {
  F64 x,y,h;
  F64 angle,fov;
};
#define GRID_SZ  128
#define DIST_SCALE (GR_HEIGHT*GRID_SZ*3)

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
  F64 angle=Arg(x=p->x-cam->x,y=p->y-cam->y)-cam->angle;
  F64 dist=Sqrt(x*x+y*y);
  p->x=dist*Cos(angle);
  p->y=dist*Sin(angle);
}

Bool ScreenCordsToPlaneCoords(CDoomCamera *cam,CD2 *p,F64 level) {
  F64 angle=(p->x-GR_WIDTH/2)/(GR_WIDTH/2-1)*(cam->fov/2),dist;
  if(Abs(cam->h-level)<.1)
    dist=0;
  else
    dist=DIST_SCALE/((p->y-GR_HEIGHT/2)/(cam->h-level)*Cos(angle)*GR_HEIGHT)-1;
  p->x=Cos(angle+cam->angle)*dist+cam->x;
  p->y=Sin(angle+cam->angle)*dist+cam->y;
  if(dist<0.) return FALSE;
  if(-cam->fov/2.<angle<cam->fov/2.)
    return TRUE;
  return FALSE;
}


Bool ClipLineToScrenCoords(CDoomCamera *cam,CD2 *p,CD2 *p2,F64 level=0,F64 *p_clip_seg=NULL,F64 *p2_clip_seg=NULL) {
  CD2 s,e,at,*ptr,debug;
  I64 cnt;
  Bool ground_y=FALSE;
  F64 angle,dist;
  TransformPointToCamera(cam,p);
  TransformPointToCamera(cam,p2);
  if(p->x<0.&&p2->x<0.) return FALSE;
  s.x=0.,s.y=I16_MIN;
  e.x=0.,e.y=I16_MAX;
  if(p_clip_seg) *p_clip_seg=0;
  if(p2_clip_seg) *p2_clip_seg=dist;
  if(PlaneIntersect(&at,&s,&e,p,p2)) {
    ground_y=TRUE;
    dist=Sqrt(Sqr(p2->x-p->x)+Sqr(p2->y-p->y));
    if(p->x>=0.) {
      p2->x=at.x;
      p2->y=at.y;
      if(p2_clip_seg) *p2_clip_seg=dist-Sqrt(Sqr(p2->x-p->x)+Sqr(p2->y-p->y));
    } else {
      p->x=at.x;
      p->y=at.y;
      if(p_clip_seg) *p_clip_seg=Sqrt(Sqr(p2->x-p->x)+Sqr(p2->y-p->y));
    }
  }
  for(cnt=0;cnt!=2;cnt++) {
    if(!cnt) ptr=p;
    else ptr=p2;
    angle=Arg(ptr->x,ptr->y);
    at.x=GR_WIDTH/2+angle/(cam->fov/2)*(GR_WIDTH/2-1);
    if(ground_y)
      at.y=GR_HEIGHT;
    else
      at.y=GR_HEIGHT/2+DIST_SCALE/(1+Sqrt(ptr->x*ptr->x+ptr->y*ptr->y))/GR_HEIGHT/Cos(angle)*(cam->h-level);
    ptr->x=at.x;
    ptr->y=at.y;
  }
  return TRUE;
}


I64 HitCmp(F64 a,F64 b) {
  if(a>b) return 1;
  if(a<b) return -1;
  return 0;
}

I64 FloorShader(CDC *to_dc,CDC *texture,I64 x,I64 y,F64 altitude,CDoomCamera *cam) {
  F64 angle=(ToF64(x)-GR_WIDTH/2)/GR_WIDTH*cam->fov/2+cam->angle;
//Dont ask Nroot how this works,i typed in random stuff till it looked good
  F64 dist=DIST_SCALE/(ToF64(y)-GR_HEIGHT/2)*(Abs(cam->h-altitude)/GR_HEIGHT);
  I64 floorx=Cos(angle)*dist,floory=Sin(angle)*dist;
  U16 *base,color;
  if(y>to_dc->height-2)
    y=to_dc->height-2;
  if(x>to_dc->width-2)
    x=to_dc->width-2;
 //I use dithering(which makes up 2x2 "pixels"),chop off first bit to align to 2
  floorx=(2*floorx%texture->width)&~1;
  floory=(2*floory%texture->height)&~1;
  if(floorx<0) floorx=-floorx;
  if(floory<0) floory=-floory;
  color=texture->body[floorx+floory*texture->width](U16);
  base=&to_dc->body[x+y*to_dc->width_internal];
  *base=color;
  base(U8*)+=to_dc->width_internal;
  color=texture->body[floorx+(1+floory)*texture->width](U16);
  *base=color;

}


CDoomSector *GetSectorForCoord(CDoomLevel *level,I64 x,I64 y) {
  CDoomSector *head=&level->sectors,*s=head->next;
  while(s!=head) {
    if(0<=x-s->shape_start_x<=s->shape_dc->width)
      if(0<=y-s->shape_start_y<=s->shape_dc->height) {
        if(GrPeek0(s->shape_dc,x-s->shape_start_x,y-s->shape_start_y))
	  return s;
      }
    s=s->next;
  }
  return NULL;
}

U0 DrawTexturedFlat(CDC *to_dc,CDoomCamera *cam,CDoomSector *sector,F64 at,CDC *texture) {
  I64 x,y;
  I64 w=sector->shape_dc->width,h=sector->shape_dc->height;
  I64 lastx=-1,lasty=-1;
  F64 maxx=I16_MIN,maxy=I16_MIN;
  F64 minx=I16_MAX,miny=I16_MAX;
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
    maxx=Max(maxx,point2.x);
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


  if(maxx<minx) {
    return;
  }
  minx=Max(0,minx);
  miny=Max(0,miny);
  maxx=Min(GR_WIDTH,maxx);
  maxy=Min(GR_HEIGHT,maxy);
  for(x=minx;x<maxx;x+=2) {
    for(y=miny;y<maxy;y+=2) {
      point.x=x,point.y=y;
      if(ScreenCordsToPlaneCoords(cam,&point,at)) {
        point.x-=sector->shape_start_x;
        point.y-=sector->shape_start_y;
        if(0<=point.x<w)
	  if(0<=point.y<h){
	    if(GrPeek0(sector->shape_dc,point.x,point.y)) {   
	      FloorShader(to_dc,texture,x,y,at,cam);
	    }
	  }
      }
    }
  }
} 

U0 TextureMapWall(CDC *to_dc,F64 sx,F64 sy,F64 sh,F64 ex,F64 ey,F64 eh,
	I64 start_seg,I64 end_seg,CDC *texture,F64 sz,F64 ez) {
  F64 cx,h,cy,at_y,cur_z,to_x,to_h;
  F64 percent;
  I64 texture_x,texture_y;
  U16 *super_pixel,*dst;
  I32 *db_z;
  U8 *col;
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
    at_y=percent*(ey-sy)+sy;
    cur_z=percent*(ez-sz)+sz;
    for(cy=0;cy<=h;cy+=WALL_HPIXEL_HEIGHT) {
      if(0<=at_y-h+cy<GR_HEIGHT-WALL_HPIXEL_HEIGHT) {
//I willl only check 2 buf for 1 pixel,assume other pixels are same as we render in 2x2 super pixels
        db_z=&to_dc->depth_buf[ToI64(cx)+ToI64(at_y-h+cy)*to_dc->width_internal];
        if(*db_z>cur_z) {
	  texture_y=Lerp(cy/h,0,texture->height/2);
	  texture_y=(2*texture_y%texture->height)&~1;
	  super_pixel=&texture->body[texture_x+texture_y*texture->width_internal];
	  dst=&to_dc->body[ToI64(cx)+ToI64(at_y-h+cy)*to_dc->width_internal];
	  *dst=*super_pixel;
	  super_pixel(U8*)+=texture->width_internal;
	  dst(U8*)+=to_dc->width_internal;
	  *dst=*super_pixel;
          db_z[0]=cur_z;
          db_z[1]=cur_z;
	  db_z+=to_dc->width_internal;
          db_z[0]=cur_z;
          db_z[1]=cur_z;
        }
      }
    }
  }
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
  CDoomBSPSeg *seg;
  CDoomSidedef *sidedef;
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
    if(seg->linedef->front^^seg->linedef->back) {
      if(seg->linedef->front)
        sidedef=seg->linedef->front;
      else
        sidedef=seg->linedef->back;	
    } else{
//Backface culling
      if(wall_vect->data[0]*cam_cord.y-wall_vect->data[1]*cam_cord.x<0.)
        sidedef=seg->linedef->front;
      else
        sidedef=seg->linedef->back;
    }
    if(!sidedef) goto skip;
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
	  TextureMapWall(to_dc,start_floor.x,start_floor.y,h,end_floor.x,end_floor.y,h2,
	        start_seg,end_seg,texture,
	        Sqrt(Sqr(seg->start->x-cam->x)+Sqr(seg->start->y-cam->y)),
	        Sqrt(Sqr(seg->end->x-cam->x)+Sqr(seg->end->y-cam->y))
	  );
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
    return 1;
  if(a->floor_height<b->floor_height)
    return -1;
  return 0;
}

U0 DrawDoomWorld(CDoomCamera *cam,CDoomLevel *level,CDC *to_dc) {
  CDoomSector *sector,**sorted=MAlloc(8*QueCnt(&level->sectors));  
  I64 idx=0,idx2;
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next,idx++) {
   sorted[idx]=sector;
  }
  QSortI64(sorted,idx,&SectorFloorSort);
  for(idx2=0;idx2!=idx;idx2++) {
    DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->floor_height,sorted[idx2]->floor_dc);
  }
  Free(sorted);
  if(!to_dc->depth_buf)
    DCDepthBufAlloc(to_dc);
  else
    DCDepthBufRst(to_dc);
  DrawBSP(to_dc,cam,level);
}


CDoomCamera cam;
CDoomSector *sect=l->sectors.last;
"%x,$ER$%x\n",sect->linedef_cnt,sect->linedefs[0];
cam.x=sect->linedefs[0]->start->x-00;
cam.y=sect->linedefs[0]->start->y-0;
cam.fov=pi/4;
//cam.angle=-pi;
cam.h=0;
DocClear;
while(TRUE) {
DCFill;
 DrawLevelOverview(l,gr.dc,1/8.,TRUE,cam.x,cam.y);
  cam.h=ms.pos.z*16;
  DrawDoomWorld(&cam,l,gr.dc);
  if(Bt(kbd.down_bitmap,SC_CURSOR_UP)) {
    cam.x+=GRID_SZ*Cos(cam.angle);
    cam.y+=GRID_SZ*Sin(cam.angle);
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_DOWN)) {
    cam.x-=GRID_SZ*Cos(cam.angle);
    cam.y-=GRID_SZ*Sin(cam.angle);
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_LEFT)) {
     cam.angle-=pi/16;
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)) {
     cam.angle+=pi/16;
  }
  Refresh;
}