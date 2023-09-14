

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

#include "DoomGr.HC";
#include "Wad.HC";
#include "System.HC";
//#include "ST.HC";

class CDoomCamera {
  F64 x,y,h;
  F64 angle,fov;
};
#define GRID_SZ 64
#define DIST_SCALE (GR_HEIGHT*GRID_SZ*3)
/*
 * Listen up,here's the deal
 * A view plane is FLAT,not a point,so when we look at an angle,we 
 * need to "straigten" our line,otherwise we will have a curved lense effect 
 *
 * Ask Nroot about this
 */
F64 Shrink(F64 vangle,F64 distance,F64 height=GR_HEIGHT) {
  distance*=Cos(vangle);  
  return (DIST_SCALE/distance);
}

F64 SectorHighestCeilHeight(CDoomSector *sector) {
  I64 idx;
  F64 highest=sector->ceil_height;
  CDoomLinedef *ld;
  for(idx=0;idx!=sector->linedef_cnt;idx++) {
    ld=sector->linedefs[idx];
    if(ld->front)
      if(ld->front->sector!=sector)
	highest=Max(ld->front->sector->ceil_height,highest);
    if(ld->back)
      if(ld->back->sector!=sector)
	highest=Max(ld->back->sector->ceil_height,highest);
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
	lowest=Min(ld->front->sector->floor_height,lowest);
    if(ld->back)
	lowest=Min(ld->back->sector->floor_height,lowest);
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
  return cam->h+Shrink(angle-cam->angle,dist,h)+GR_HEIGHT/2;
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

U0 TextureMapWall(CDC *to_dc,F64 sx,F64 sy,F64 sh,F64 ex,F64 ey,F64 eh,
	I64 start_seg,I64 end_seg,CDC *texture) {
  F64 cx,h,cy,at_y;
  I64 texture_x;
  if(sx>ex) {
    SwapI64(&sx,&ex);
    SwapI64(&sy,&ey);
    SwapI64(&sh,&eh);
    SwapI64(&start_seg,&end_seg);
  }  
/*PrintF("start",start_seg);
PrintF("end",end_seg);
PrintF("sx",sx);
PrintF("ex",ex);
PrintF("sh",sh);
PrintF("eh",eh);
PrintF("sy",sy);
PrintF("ey",ey);*/
  for(cx=sx;cx<=ex;cx++) {
    h=Lerp((cx-sx)/(ex-sx),sh,eh);
    texture_x=Lerp((cx-sx)/(ex-sx),start_seg,end_seg)%texture->width;
    at_y=Lerp((cx-sx)/(ex-sx),sy,ey);
    for(cy=0;cy<=h;cy++) {
	to_dc->color=GrPeek0(
	texture,
	texture_x,
	Lerp(cy/h,0,texture->height)
	);
	GrPlot(to_dc,cx,at_y-h+cy);
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
  Bool front;
  cam_cord.x=cam->x,cam_cord.y=cam->y;
  CDoomSector *sector;
  CDoomSidedef *sidedef;
//TODO bsp
  for(ld=head->next;ld!=head;ld=ld->next) {
    if(DoomClipLinedef(cam->fov,cam->x,cam->y,cam->angle,ld,&left,&right)) {
      SetVector(wall_vector,ld->end->x-ld->start->x,0);
      SetVector(wall_vector,ld->end->y-ld->start->y,1);
      if(ld->front)
        sidedef=ld->front;
      if(ld->back)
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
        sect_y=100;
	sect_y2=100;
        TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
	      start_seg,end_seg,sidedef->lower_texture
	      );
      }
      if(sidedef->upper_texture) {
        ceil=sector->ceil_height;
        sy=PointToBaseY(cam,ceil,&left);
        sx=PointToScreenX(cam,&left);
        ey=PointToBaseY(cam,ceil,&right);
        ex=PointToScreenX(cam,&right);
        start_seg=PointToLinedefSegment(cam,ld,&left);
        end_seg=PointToLinedefSegment(cam,ld,&right);
        sect_y=PointToBaseY(cam,sector->ceil_height,&left)-sy;
        sect_y2=PointToBaseY(cam,sector->ceil_height,&right)-ey;
        sect_y=100;
	sect_y2=100;
        TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
	      start_seg,end_seg,sidedef->upper_texture
	      );
      }
      if(sidedef->middle_texture) {
        ceil=sector->ceil_height;
        sy=PointToBaseY(cam,ceil,&left);
        sx=PointToScreenX(cam,&left);
        ey=PointToBaseY(cam,ceil,&right);
        ex=PointToScreenX(cam,&right);
        start_seg=PointToLinedefSegment(cam,ld,&left);
        end_seg=PointToLinedefSegment(cam,ld,&right);
        sect_y=PointToBaseY(cam,sector->ceil_height,&left)-sy;
        sect_y2=PointToBaseY(cam,sector->ceil_height,&right)-ey;
        sect_y=20;
	sect_y2=20;
        TextureMapWall(to_dc,sx,sy,sect_y,ex,ey,sect_y2,
	      start_seg,end_seg,sidedef->middle_texture
	      );
      }
    }
next:;
  }
  DestroyVector(wall_vector);
}

CDoomSector *sect=l->sectors.last;
CDoomCamera cam;
"%x,$ER$%x\n",sect->linedef_cnt,sect->linedefs[0];
cam.x=sect->linedefs[0]->start->x-100;
cam.y=sect->linedefs[0]->start->y-100;
cam.fov=pi/4;
while(TRUE) {
DCFill;
  cam.angle=tS;
  DrawDoomWorld(&cam,l,gr.dc);
  Refresh;
}