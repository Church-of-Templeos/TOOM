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

asm {
_FAST_FIND_NOT_TRANSPARENT::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  MOV AX,TRANSPARENT
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
_FAST_FIND_TRANSPARENT::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  MOV AX,TRANSPARENT
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
};
_extern _FAST_FIND_NOT_TRANSPARENT U8 *FastFindNotTransparent(U8 *data,I64 cnt);
_extern _FAST_FIND_TRANSPARENT U8 *FastFindTransparent(U8 *data,I64 cnt);

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

Bool ClipLineToScrenCoords(CDoomCamera *cam,CD2 *p,CD2 *p2,F64 level=0) {
  CD2 s,e,at,*ptr;
  I64 cnt;
  Bool ground_y=FALSE;
  F64 angle;
  TransformPointToCamera(cam,p);
  TransformPointToCamera(cam,p2);
  if(p->x<0.&&p2->x<0.) return FALSE;
  s.x=0.,s.y=I16_MIN;
  e.x=0.,e.y=I16_MAX;
  if(PlaneIntersect(&at,&s,&e,p,p2)) {
    ground_y=TRUE;
    if(p->x>=0.) {
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

I64 FloorShader(CDC *to_dc,CDC *texture,F64 x,F64 y,F64 altitude,CDoomCamera *cam) {
  F64 angle=(x-GR_WIDTH/2)/GR_WIDTH*cam->fov/2+cam->angle;
//Dont ask Nroot how this works,i typed in random stuff till it looked good
  F64 dist=DIST_SCALE/(y-GR_HEIGHT/2)*(Abs(cam->h-altitude)/GR_HEIGHT);
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
  base=&to_dc->body[ToI64(x)+ToI64(y)*to_dc->width_internal];
  *base=color;
  base(U8*)+=to_dc->width_internal;
  color=texture->body[floorx+(1+floory)*texture->width](U16);
  *base=color;

}


U0 FillPolygon(CDC *to_dc,I64 cnt,CD2 *starts,CD2 *ends,CDC *texture,F64 altitude,CDoomCamera *cam) {
  I64 idx,hit_cnt;
  F64 *hits=CAlloc(8*cnt);
  F64 minx=GR_WIDTH,maxx=0;
  F64 miny=GR_HEIGHT,maxy=0;
  F64 mingx,maxgx,mingy,maxgy;
  F64 x,y,from_x,to_x;
  CD2 at,s,e;
  U8 *row,*col;
  Bool odd;
  for(idx=0;idx!=cnt;idx++) {
    minx=Min(starts[idx].x,minx);
    miny=Min(starts[idx].y,miny);
    maxx=Max(starts[idx].x,maxx);
    maxy=Max(starts[idx].y,maxy);
    minx=Min(ends[idx].x,minx);
    miny=Min(ends[idx].y,miny);
    maxx=Max(ends[idx].x,maxx);
    maxy=Max(ends[idx].y,maxy);
  }
  mingy=Max(0,miny);
  maxgy=Min(GR_HEIGHT-2,maxy);
  mingx=Max(0,minx);
  maxgx=Min(GR_WIDTH-2,maxx);
  for(y=mingy;y<=maxgy;y+=FLOOR_HPIXEL_HEIGHT)  {
    s.x=minx-2;
    e.x=maxx+2;
    s.y=y;
    e.y=y;
    hit_cnt=0;
    for(idx=0;idx!=cnt;idx++) {
      if(PlaneIntersect(&at,&s,&e,starts+idx,ends+idx)) {
        if(hit_cnt)
	  if(ToI64(hits[hit_cnt-1])==ToI64(at.x))
	    goto skip;
        hits[hit_cnt++]=ToI64(at.x);
skip:;
      }
    }
    QSortI64(hits,hit_cnt,&HitCmp);
    odd=FALSE;
    for(idx=0;idx<hit_cnt-1;idx++) {
      odd=!odd;
      if(odd)  {
        if(hits[idx+1]<mingx||hits[idx]>maxgx)
	  ;
        else {
	  row=&to_dc->body[ToI64(y)*to_dc->width_internal];
	  from_x=Max(hits[idx],mingx);
	  to_x=Min(hits[idx+1],maxgx);
	  for(x=from_x;x<=to_x;x+=FLOOR_VPIXEL_WIDTH) {
	    col=row+ToI64(x);
            if(*col!=TRANSPARENT) {
	      col=FastFindTransparent(col,GR_WIDTH-ToI64(x));
	      if(!col) break;
              x=col-row-FLOOR_VPIXEL_WIDTH;
            } else 
	      FloorShader(to_dc,texture,x,y,altitude,cam);
	  }
        }
      }
    }
//If we have an odd number of hits,color for both sides
    if(hit_cnt&1) {
      for(idx=hit_cnt-2;idx>=(hit_cnt-1)/2;idx--) {
        for(x=Max(hits[idx],0);x<=Min(hits[idx+1],GR_WIDTH-1);x+=FLOOR_VPIXEL_WIDTH)
	    FloorShader(to_dc,texture,x,y,altitude,cam);
      } 
    }
  }
  Free(hits);
}


U0 DrawTexturedFlat(CDC *to_dc,CDoomCamera *cam,CDoomSector *sector,F64 at,CDC *texture) {
  CDC *dummy;
  I64 line_cnt=0;
  CD2 p,p2,*starts=MAlloc(sizeof(CD2)*sector->linedef_cnt),*ends=MAlloc(sizeof(CD2)*sector->linedef_cnt);
  I64 idx,w,idx2,h,len;
  U8 *row_ptr,*orp;
  for(idx=0;idx!=sector->linedef_cnt;idx++) {
    p.x=sector->linedefs[idx]->start->x;
    p.y=sector->linedefs[idx]->start->y;
    p2.x=sector->linedefs[idx]->end->x;
    p2.y=sector->linedefs[idx]->end->y;
    if(ClipLineToScrenCoords(cam,&p,&p2,at)) {
      starts[line_cnt].x=p.x;
      starts[line_cnt].y=p.y;
      ends[line_cnt].x=p2.x;
      ends[line_cnt].y=p2.y;
      line_cnt++;
    }
  }
  FillPolygon(to_dc,line_cnt,starts,ends,texture,at,cam);
  Free(starts),Free(ends);
fin:;
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
    if(seg->linedef->front^^seg->linedef->back) {
      if(seg->linedef->front)
        sidedef=seg->linedef->front;
       else
        sidedef=seg->linedef->back;
    } else {
      cam_cord.x=cam->x-seg->start->x;
      cam_cord.y=cam->y-seg->start->y;
      SetVector(wall_vect,seg->end->x-seg->start->x,0);
      SetVector(wall_vect,seg->end->y-seg->start->y,1);
      if(IsFrontSideOfVector2D(wall_vect,&cam_cord))
        sidedef=seg->linedef->front;
      else
        sidedef=seg->linedef->back;
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
skip:;
    }
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
  I64 idx=0;
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next,idx++) {
   sorted[idx]=sector;
  }
//Sort by height then go backwards
  QSortI64(sorted,idx,&SectorFloorSort);
  while(--idx>=0) {
    DrawTexturedFlat(to_dc,cam,sorted[idx],sorted[idx]->floor_height,sorted[idx]->floor_dc);
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
cam.x=sect->linedefs[0]->start->x-100;
cam.y=sect->linedefs[0]->start->y-100;
cam.fov=pi/4;
cam.angle=-pi;
cam.h=0;
DocClear;
while(TRUE) {
DCFill;
// DrawLevelOverview(l,gr.dc,1/8.,TRUE,cam.x,cam.y);
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