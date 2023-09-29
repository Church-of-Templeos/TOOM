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
#define DIST_SCALE (GR_HEIGHT)

#define FLOOR_VPIXEL_WIDTH 2
#define WALL_VPIXEL_WIDTH 2
#define WALL_HPIXEL_HEIGHT 2
#define FLOOR_HPIXEL_HEIGHT 2

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
  dist=DIST_SCALE/((p->y-GR_HEIGHT/2)/(cam->h-level))/FCos(angle);
  p->x=FCos(angle+cam->angle)*dist+cam->x;
  p->y=FSin(angle+cam->angle)*dist+cam->y;
  if(dist<0.) return FALSE;
  if(-cam->fov/2.<angle<cam->fov/2.)
    return TRUE;
  return FALSE;
}


Bool ClipLineToScrenCoords(CDoomCamera *cam,CD2 *p,CD2 *p2,F64 level=0.,Bool *out_of_view=NULL) {
  CD2 s,e,at,*ptr,debug;
  I64 cnt,fail_cnt;
  F64 angle;
  TransformPointToCamera(cam,p);
  TransformPointToCamera(cam,p2);
  if(p->x<1&&p2->x<1) return FALSE;
  s.x=1,e.x=1;
  s.y=I16_MIN,e.y=I16_MAX;  
  if(out_of_view)
    *out_of_view=FALSE;
  if(PlaneIntersect(&at,&s,&e,p,p2)) {
    if(out_of_view)
      *out_of_view=TRUE;
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
    at.y=GR_HEIGHT/2+DIST_SCALE/(Sqrt(Sqr(ptr->x)+Sqr(ptr->y))*FCos(angle))*(cam->h-level);
    ptr->x=at.x;
    ptr->y=at.y;
  }
  return TRUE;
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

U0 RayCastWall(CDC *to_dc,CDC *texture,CD2 *st,CD2 *en,CDoomCamera *cam,I64 level,I64 height,Bool floor=FALSE) {
  CD2 clone_st,clone_en,zero;
  clone_st.x=st->x,clone_st.y=st->y;
  clone_en.x=en->x,clone_en.y=en->y;
  zero.x=0.,zero.y=0.;
  TransformPointToCamera(cam,&clone_st);
  TransformPointToCamera(cam,&clone_en);
  st=&clone_st;
  en=&clone_en;
  F64 start_angle=FArg(st->x,st->y),ca;
  F64 end_angle=FArg(en->x,en->y),tmp;
  F64 margin;
  CD2 ray,hit,*sw;
  I64 ix,iy,ih=0,tx,ty,ih2;
  I32 *db_z,idist;
  F64 dist;
  U16 *color,*to;
  if(start_angle>end_angle) {
    tmp=start_angle;
    start_angle=end_angle;
    end_angle=tmp;

    sw=st;
    st=en;
    en=sw;
  }
  start_angle=Clamp(start_angle,-cam->fov/2,cam->fov/2);
  end_angle=Clamp(end_angle,-cam->fov/2,cam->fov/2);
  for(ca=start_angle;ca<=end_angle;ca+=cam->fov/GR_WIDTH*2) {
    ray.x=I16_MAX*FCos(ca);
    ray.y=I16_MAX*FSin(ca);
    if(PlaneIntersect(&hit,&ray,&zero,st,en)) {
      dist=Sqrt(Sqr(hit.x)+Sqr(hit.y));
      idist=dist;
      ix=GR_WIDTH/2.+ca/(cam->fov/2.)*GR_WIDTH/2.;
      ix&=~1;
      if(dist<=0.) dist=1;
      tx=ToI64(Sqrt(Sqr(hit.x-st->x)+Sqr(hit.y-st->y)))%texture->width/2;
      if(0<=ix<=GR_WIDTH-2) {
//The offset from the ground is included in the "height",we dont render the overdraw
        margin=DIST_SCALE/(dist*FCos(ca))*(cam->h-level);
        ih=DIST_SCALE/(dist*FCos(ca))*height;
        iy=GR_HEIGHT/2;
        if(margin>=0.) {
	  iy-=ih;
	  iy+=margin;
	  ih2=ih;
        } else {
	  iy-=ih;
	  iy+=margin;
	  ih2=ih;
        }
        iy&=~1;
        if(idist<cam->floor_depths[ix/2]) {
	  cam->floor_heights[ix/2]=GR_HEIGHT;
	  cam->ceil_heights[ix/2]=0;
	  cam->floor_depths[ix/2]=idist;
        }
//Todo clip flooor_heights
        while((ih2-=2)>=0) {
	  if(!(cam->ceil_heights[ix/2]<=iy+ih2<=cam->floor_heights[ix/2]-2)) {
	    if(iy+ih2<cam->ceil_heights[ix/2])
	      break;
//GR_HEIGHT-2>iy+ih2;
	    ih2=cam->floor_heights[ix/2]-2-iy;
	    if(ih2>ih) break;
	    if(iy+ih2<0) break;
	    if(ih2<0) break;
	  }
	  ty=ToF64(ih2)/ih*(texture->height-1)/2;
	  tx=AbsI64(tx);
	  ty=ClampI64(ty,0,texture->height-2);
	  tx=ClampI64(tx,0,texture->width-2);
	  color=texture->body[tx*2+ty*2*texture->width_internal](U16);
	  to=&to_dc->body[ix+(iy+ih2)*to_dc->width_internal];
	  db_z=&to_dc->depth_buf[ix+(iy+ih2)*to_dc->width_internal];
	  if(*db_z>idist) {
	    db_z[0]=idist;
	    db_z[1]=idist;
	    db_z+=to_dc->width_internal;
	    db_z[0]=idist;
	    db_z[1]=idist;
	    *to=color;
	    to(U8*)+=to_dc->width_internal;
	    color=texture->body[tx*2+(ty*2+1)*texture->width_internal](U16);
	    *to=color;
	  }
        }
        if(iy<cam->floor_heights[ix/2]) {
set_floor_height:
	if(floor)
	  cam->floor_heights[ix/2]=ClampI64(iy,0,GR_HEIGHT);
	else
	  cam->ceil_heights[ix/2]=ClampI64(iy+ih,0,GR_HEIGHT);
	  cam->floor_depths[ix/2]=idist;
//	  cam->ceil_depths[ix/2]=idist;
        } else if(cam->floor_depths[ix/2]>=idist) {
	  goto set_floor_height;
        }
      }
    }
  }
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
  I64 seg_idx,wall,start_seg,end_seg,fail_cnt;
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
        fail_cnt=0;
        if(!ClipLineToScrenCoords(cam,&start_floor,&end_floor,floor))
	  fail_cnt++;
        if(!ClipLineToScrenCoords(cam,&start_ceil,&end_ceil,ceil))
	  fail_cnt++;
        start_seg=PointToLinedefSegment(cam,seg->linedef,seg->start);
        end_seg=PointToLinedefSegment(cam,seg->linedef,seg->end);
        h=Abs(start_floor.y-start_ceil.y);
        h2=Abs(end_ceil.y-end_floor.y);
        if(ToI64(h)&&ToI64(h2)) {
	  if(fail_cnt!=2) {
	    if(!no_draw)
	      RayCastWall(to_dc,texture,seg->start,seg->end,cam,floor,ceil-floor,wall==0||wall==2);
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
    if(sorted[idx2]->floor_dc) {
      if(sorted[idx2]->floor_height<cam->h)
        DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->floor_height,sorted[idx2]->floor_dc,TRUE);
//	RayCastFloor(to_dc,cam,sorted[idx2]->floor_dc,sorted[idx2],sorted[idx2]->floor_height);
    }
    if(sorted[idx2]->ceil_dc) {
      if(sorted[idx2]->ceil_height>cam->h)
        DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->ceil_height,sorted[idx2]->ceil_dc,FALSE);
//	RayCastFloor(to_dc,cam,sorted[idx2]->ceil_dc,sorted[idx2],sorted[idx2]->ceil_height);
    }
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
#include"Collision";

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
    MoveInLevel(l,&cam.x,cam.angle,GRID_SZ/4,16,cam.h-48);
    ST_Key(0);
  }
  if(Bt(kbd.down_bitmap,SC_CURSOR_DOWN)) {
    MoveInLevel(l,&cam.x,cam.angle,-GRID_SZ/4,16,cam.h-48);
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