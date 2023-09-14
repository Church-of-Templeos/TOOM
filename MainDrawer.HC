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
F64 Shrink(F64 vangle,F64 distance,F64 height=GR_HEIGHT) {
  distance*=Cos(vangle);  
  if(!distance) return height;
  return (DIST_SCALE/distance);
}

F64 SectorHighestCeilHeight(CDoomSector *sector) {
  I64 idx;
  F64 highest=sector->ceil_height;
  CDoomLinedef *ld;
  for(idx=0;idx!=sector->linedef_cnt;idx++) {
    ld=sector->linedefs[idx];
    if(ld->front)
      highest=Min(ld->front->sector->ceil_height,highest);
    if(ld->back)
      highest=Min(ld->back->sector->ceil_height,highest);
  }
  return highest;
}


F64 SectorLowestFloorHeight(CDoomSector *sector) {
  I64 idx;
  F64 lowest=sector->floor_height;
  CDoomLinedef *ld;
  for(idx=0;idx!=sector->linedef_cnt;idx++) {
    ld=sector->linedefs[idx];
    if(ld->front)
      lowest=Max(ld->front->sector->floor_height,lowest);
    if(ld->back)
      lowest=Max(ld->back->sector->floor_height,lowest);
  }
  return lowest;
}
F64 PointToScreenX(CDoomCamera *cam,CD2 *coord) {
  F64 x=coord->x-cam->x;
  F64 y=coord->y-cam->y;
  F64 angle=Wrap(Arg(x,y)-cam->angle);
  if(angle<-cam->fov/2)
    return 0;
  if(angle>cam->fov/2)
    return GR_WIDTH;
  return GR_WIDTH/2+angle/(cam->fov/2)*GR_WIDTH/2;
}
F64 PointToBaseY(CDoomCamera *cam,F64 h,CD2 *coord) {
  F64 x=coord->x-cam->x;
  F64 y=coord->y-cam->y;
  F64 dist=Sqrt(x*x+y*y);
  F64 angle=Arg(x,y);
  F64 without_h=cam->h+Shrink(angle-cam->angle,dist)+GR_HEIGHT/2;
  return without_h-Shrink(angle-cam->angle,dist)/GR_HEIGHT*h;
}

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

U0 DrawTexturedFlat(CDC *to_dc,CDoomCamera *cam,CDoomSector *sector,F64 at,CDC *texture) {
  if(!sector->linedef_cnt) return;
  CD3 *polygon=CAlloc(2*sector->linedef_cnt*sizeof(CD3));
  CD2 *p;
  I64 idx,actual_cnt=0;
  for(idx=0;idx<sector->linedef_cnt;idx++) {
    if(sector->linedefs[idx]->in_view) {
      polygon[actual_cnt].x=PointToScreenX(cam,p=&sector->linedefs[idx]->clip_start);
      polygon[actual_cnt].z=10;
      polygon[actual_cnt].y=PointToBaseY(cam,at,p);    
      polygon[actual_cnt+1].x=PointToScreenX(cam,p=&sector->linedefs[idx]->clip_end);
      polygon[actual_cnt+1].z=10;
      polygon[actual_cnt+1].y=PointToBaseY(cam,at,p);    
      actual_cnt+=2;
    } else {
    }
  }
  if(!actual_cnt) goto fin;
  for(idx=0;idx<actual_cnt;idx+=2) {
    to_dc->color=YELLOW;
    to_dc->thick=1;
    GrLine3(to_dc,polygon[idx].x,polygon[idx].y,10,polygon[idx+1].x,polygon[idx+1].y,10);
  }
fin:
 Free(polygon);
} 

U0 TextureMapWall(CDC *to_dc,F64 sx,F64 sy,F64 sh,F64 ex,F64 ey,F64 eh,
	I64 start_seg,I64 end_seg,CDC *texture,F64 sz,F64 ez) {
  F64 cx,h,cy,at_y,cur_z;
  I64 texture_x,texture_y;
  if(sx>ex) {
    SwapI64(&sx,&ex);
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

U0 DrawDoomWorld(CDoomCamera *cam,CDoomLevel *level,CDC *to_dc) {
  DCDepthBufAlloc(to_dc);
  CDoomLinedef *ld,*head=&level->linedefs;
  CD2 left,right,cam_cord,wall_coord;
  I64 start_seg,end_seg;
  F64 floor,ceil,sx,sy,ex,ey,sh,eh,cx,cy,h,sect_y,sect_y2;
  Vector *wall_vector=CreateVector(2);
  Bool front=FALSE;
  cam_cord.x=cam->x,cam_cord.y=cam->y;
  CDoomSector *sector;
  CDoomSidedef *sidedef;
//TODO bsp
  for(ld=head->next;ld!=head;ld=ld->next) {
    if(ld->in_view=DoomClipLinedef(cam->fov,cam->x,cam->y,cam->angle,ld,&ld->clip_start,&ld->clip_end)) {
      MemCpy(&left,&ld->clip_start,sizeof CD2);
      MemCpy(&right,&ld->clip_end,sizeof CD2);
      SetVector(wall_vector,ld->end->x-ld->start->x,0);
      SetVector(wall_vector,ld->end->y-ld->start->y,1);
      for(front=0;front!=2;front++) {
      if(front)
        sidedef=ld->front;
      if(!front)
        sidedef=ld->back;
      if(!sidedef) goto next;
      sector=sidedef->sector;
      if(sidedef->lower_texture) {
        floor=SectorLowestFloorHeight(sector);
        sy=PointToBaseY(cam,floor,&left);
        sx=PointToScreenX(cam,&left);
        ey=PointToBaseY(cam,floor,&right);
        ex=PointToScreenX(cam,&right);
        start_seg=PointToLinedefSegment(cam,ld,&left);
        end_seg=PointToLinedefSegment(cam,ld,&right);
        sect_y=PointToBaseY(cam,sector->floor_height,&left)-sy;
        sect_y2=PointToBaseY(cam,sector->floor_height,&right)-ey;
        TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
	      start_seg,end_seg,sidedef->lower_texture,
		Sqrt(Sqr(left.x-cam->x)+Sqr(left.y-cam->y)),
		Sqrt(Sqr(right.x-cam->x)+Sqr(right.y-cam->y))
	      );
      }
      if(sidedef->upper_texture) {
        ceil=SectorHighestCeilHeight(sector);
        sy=PointToBaseY(cam,ceil,&left);
        sx=PointToScreenX(cam,&left);
        ey=PointToBaseY(cam,ceil,&right);
        ex=PointToScreenX(cam,&right);
        start_seg=PointToLinedefSegment(cam,ld,&left);
        end_seg=PointToLinedefSegment(cam,ld,&right);
        sect_y=sy-PointToBaseY(cam,sector->ceil_height,&left);
        sect_y2=ey-PointToBaseY(cam,sector->ceil_height,&right);
        TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
	      start_seg,end_seg,sidedef->upper_texture,
		Sqrt(Sqr(left.x-cam->x)+Sqr(left.y-cam->y)),
		Sqrt(Sqr(right.x-cam->x)+Sqr(right.y-cam->y))
	      );
      }
      if(sidedef->middle_texture) {
        ceil=SectorLowestFloorHeight(sector);
        sy=PointToBaseY(cam,ceil,&left);
        sx=PointToScreenX(cam,&left);
        ey=PointToBaseY(cam,ceil,&right);
        ex=PointToScreenX(cam,&right);
        start_seg=PointToLinedefSegment(cam,ld,&left);
        end_seg=PointToLinedefSegment(cam,ld,&right);
	ceil=SectorHighestCeilHeight(sector);
        sect_y=sy-PointToBaseY(cam,ceil,&left);
        sect_y2=ey-PointToBaseY(cam,ceil,&right);
        TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
	      start_seg,end_seg,sidedef->middle_texture,
		Sqrt(Sqr(left.x-cam->x)+Sqr(left.y-cam->y)),
		Sqrt(Sqr(right.x-cam->x)+Sqr(right.y-cam->y))
	      );
      }
next:;
      }
    }
  }
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next) {
      DrawTexturedFlat(to_dc,cam,sector,sector->floor_height,NULL);
  }
  DestroyVector(wall_vector);
}

CDoomCamera cam;
CDoomSector *sect=l->sectors.last;
"%x,$ER$%x\n",sect->linedef_cnt,sect->linedefs[0];
cam.x=sect->linedefs[0]->start->x-100;
cam.y=sect->linedefs[0]->start->y-100;
cam.fov=pi/4;
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