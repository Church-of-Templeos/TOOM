#include "Wad.HC";
class CDoomCamera {
  F64 x,y,h;
  F64 angle,fov;
};
#define GRID_SZ  128
#define DIST_SCALE (GR_HEIGHT*GRID_SZ*3)
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
  F64 angle;
  TransformPointToCamera(cam,p);
  TransformPointToCamera(cam,p2);
  if(p->x<2&&p2->x<2) return FALSE;
  s.x=2,s.y=I16_MIN;
  e.x=2,e.y=I16_MAX;
  if(PlaneIntersect(&at,&s,&e,p,p2)) {
    if(p->y>=0) {
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
    at.y=cam->h+GR_HEIGHT/2+DIST_SCALE/(1+Sqrt(ptr->x*ptr->x+ptr->y*ptr->y));
    at.y-=DIST_SCALE/Sqrt(ptr->x*ptr->x+ptr->y*ptr->y)*Cos(angle)/GR_HEIGHT*level;
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
  F64 angle=(x-GR_WIDTH/2)/GR_WIDTH*cam->fov/2;
  F64 dist=DIST_SCALE/(y-altitude-GR_HEIGHT/2-cam->h)*Cos(angle);
  I64 floorx=Cos(angle)*dist,floory=Sin(angle)*dist;
  to_dc->color=GrPeek0(texture,floorx&63,floory&63);
  GrPlot(to_dc,x,y);
}


U0 FillPolygon(CDC *to_dc,I64 cnt,CD2 *starts,CD2 *ends,CDC *texture,F64 altitude,CDoomCamera *cam) {
  I64 idx,hit_cnt;
  F64 *hits=CAlloc(8*cnt);
  F64 minx=GR_WIDTH,maxx=0;
  F64 miny=GR_HEIGHT,maxy=0;
  F64 x,y;
  CD2 at,s,e;
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
  for(y=miny;y<=maxy;y++)  {
    s.x=minx-2;
    e.x=maxx+2;
    s.y=y;
    e.y=y;
    hit_cnt=0;
    for(idx=0;idx!=cnt;idx++) {
      if(PlaneIntersect(&at,&s,&e,starts+idx,ends+idx)) {
        hits[hit_cnt++]=ToI64(at.x);
      }
    }
    QSortI64(hits,hit_cnt,&HitCmp);
    odd=FALSE;
    for(idx=0;idx<hit_cnt-1;idx++) {
        odd=!odd;
        if(odd) {
	  for(x=Max(hits[idx],0);x<=Min(hits[idx+1],GR_WIDTH);x++)
	    FloorShader(to_dc,texture,x,y,altitude,cam);
        }
    }
  }
  Free(hits);
}

asm {
_FAST_FIND_NZ::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  MOV AL,0
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
_FAST_FIND_Z::
  PUSH RBP
  MOV RBP,RSP
  PUSH RDI
  MOV AL,0
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
_extern _FAST_FIND_NZ U8 *FastFindNonZero(U8 *data,I64 cnt);
_extern _FAST_FIND_Z U8 *FastFindZero(U8 *data,I64 cnt);

U0 DrawTexturedFlat(CDC *to_dc,CDoomCamera *cam,CDoomSector *sector,F64 at,CDC *texture) {
  if(!sector->linedef_cnt) return;
  CDC *dummy;
  I64 line_cnt=0;
  CD2 p,p2,*starts=MAlloc(sizeof(CD2)*sector->linedef_cnt),*ends=MAlloc(sizeof(CD2)*sector->linedef_cnt);
  I64 idx,w,idx2,h,len,minx,maxx,rx,ry,maxy,miny;
  U8 *row_ptr,*orp;
  F64 angle,x;
  maxx=0;
  minx=GR_WIDTH;
  maxy=0;
  miny=GR_HEIGHT;
  for(idx=0;idx!=sector->linedef_cnt;idx++) {
    p.x=sector->linedefs[idx]->start->x;
    p.y=sector->linedefs[idx]->start->y;
    p2.x=sector->linedefs[idx]->end->x;
    p2.y=sector->linedefs[idx]->end->y;
    if(ClipLineToScrenCoords(cam,&p,&p2,at)) {
      maxx=MaxI64(p.x,maxx);
      minx=MinI64(p.x,minx);
      maxy=MaxI64(p.y,maxy);
      miny=MinI64(p.y,miny);
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
  F64 cx,h,cy,at_y,cur_z;
  I64 texture_x,texture_y;
  if(sx>ex) {
    SwapI64(&sx,&ex);
    SwapI64(&sy,&ey);
    SwapI64(&sh,&eh);
    SwapI64(&sz,&ez);
    SwapI64(&start_seg,&end_seg);
  }  
  for(cx=sx;cx<=ex;cx++) {
    h=Lerp((cx-sx)/(ex-sx),sh,eh);
    texture_x=Lerp((cx-sx)/(ex-sx),start_seg,end_seg)%texture->width;
    at_y=Lerp((cx-sx)/(ex-sx),sy,ey);
    cur_z=Lerp((cx-sx)/(ex-sx),sz,ez);
    for(cy=0;cy<=h;cy++) {
      if(0<=at_y-h<GR_HEIGHT) {
        texture_y=Lerp(cy/h,0,texture->height);
        to_dc->color=GrPeek0(
	      texture,
	      texture_x,
	      texture_y
	      );
        GrPlot3(to_dc,cx,at_y-h+cy,cur_z);
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


U0 DrawDoomWorld(CDoomCamera *cam,CDoomLevel *level,CDC *to_dc) {
  DCDepthBufAlloc(to_dc);
  CDoomLinedef *ld,*head=&level->linedefs;
  CD2 left,right,cam_cord,wall_coord;
  CD2 start_floor,end_floor,start_ceil,end_ceil;
  I64 start_seg,end_seg;
  F64 floor,ceil,sx,sy,ex,ey,sh,eh,cx,cy,h,sect_y,sect_y2;
  Vector *wall_vector=CreateVector(2);
  I64 front=FALSE,is_one_sided,idx;
  cam_cord.x=cam->x,cam_cord.y=cam->y;
  CDoomSector *sector;
  CDoomSidedef *sidedef;
  CDC*texture;
//TODO bsp
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next) {
    DrawTexturedFlat(to_dc,cam,sector,sector->floor_height,sector->floor_dc);
  }
  DCDepthBufRst(to_dc);
  for(ld=head->next;ld!=head;ld=ld->next) {
    &ld->clip_start,&ld->clip_end;
    if(ld->in_view=DoomClipLinedef(cam->fov,cam->x,cam->y,cam->angle,ld,&ld->clip_start,&ld->clip_end)) {
      for(front=0;front!=2;front++) {
        MemCpy(&left,&ld->clip_start,sizeof CD2);
        MemCpy(&right,&ld->clip_end,sizeof CD2);
        SetVector(wall_vector,ld->end->x-ld->start->x,0);
        SetVector(wall_vector,ld->end->y-ld->start->y,1);
	  if(front)
	    sidedef=ld->front;
	  if(!front)
	    sidedef=ld->back;
	  if(!sidedef) goto next;
	  is_one_sided=ld->front^^ld->back;
	  if(!is_one_sided) {
	    cam_cord.x=cam->x-ld->start->x;
	    cam_cord.y=cam->y-ld->start->y;
	    if(ToI64(IsFrontSideOfVector2D(wall_vector,&cam_cord))^^!front)
	      goto next;
	  }
	  sector=sidedef->sector;
	  for(idx=0;idx!=3;idx++){
	  if(idx==0&&(texture=sidedef->lower_texture)) {
	    floor=Min(sector->floor_height,FloorRaise(ld,sector));
	    ceil=Max(sector->floor_height,FloorRaise(ld,sector));
draw_wall:
	    start_floor.x=ld->start->x;
	    start_floor.y=ld->start->y;
	    end_floor.x=ld->end->x;
	    end_floor.y=ld->end->y;
	    start_ceil.x=ld->start->x;
	    start_ceil.y=ld->start->y;
	    end_ceil.x=ld->end->x;
	    end_ceil.y=ld->end->y;
	    ClipLineToScrenCoords(cam,&start_floor,&end_floor,floor);
	    ClipLineToScrenCoords(cam,&start_ceil,&end_ceil,ceil);
	    start_seg=PointToLinedefSegment(cam,ld,&left);
	    end_seg=PointToLinedefSegment(cam,ld,&right);
	    sect_y=Abs(start_floor.y-start_ceil.y);
	    sect_y2=Abs(end_ceil.y-end_floor.y);
	    sx=start_floor.x;
	    sy=start_floor.y;
	    ex=end_floor.x;
	    ey=end_floor.y;
	    if(ToI64(sect_y)&&ToI64(sect_y2)) {
	    TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
		  start_seg,end_seg,texture,
		  Sqrt(Sqr(left.x-cam->x)+Sqr(left.y-cam->y)),
		  Sqrt(Sqr(right.x-cam->x)+Sqr(right.y-cam->y))
	    );
	    }
	  } else if(idx==1&&(texture=sidedef->upper_texture)) {
	    floor=Min(sector->ceil_height,CeilDepress(ld,sector));
	    ceil=Max(sector->ceil_height,CeilDepress(ld,sector));
	    goto draw_wall;
	  } else if(idx==2&&(texture=sidedef->middle_texture)) {
	    floor=sector->floor_height;
	    ceil=sector->ceil_height;
	    goto draw_wall;
	  }
	}
next:;
      }
    }
  }
  DestroyVector(wall_vector);
}

CDoomCamera cam;
CDoomSector *sect=l->sectors.last;
"%x,$ER$%x\n",sect->linedef_cnt,sect->linedefs[0];
cam.x=sect->linedefs[0]->start->x-100;
cam.y=sect->linedefs[0]->start->y-100;
cam.fov=pi/4;
cam.angle=pi;
cam.h=0;
while(TRUE) {
DCFill;
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