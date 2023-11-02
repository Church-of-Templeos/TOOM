#ifndef DOOM_MAIN
#define DOOM_MAIN "Doom" 
#include "FastTrig.HC";
#include "Wad.HC";
#include "Thinker.HC";
class AmmoType{
  U64 ammo;
  Bool splash;
  
};

class GunAvail{
  Bool available;
  I16 baseDamage;
  AmmoType *load;
};

class CDoomPlayer:CDoomThing {
  F64 armor;
//When you die,the player stares at the thing that killed the player
  CDoomThing *stare_at;
  GunAvail **arsenal;
  Bool running;
};

//IMPORTANT
CacheAnimationFrames;

I64 cursor_x = ms.pos.x, cursor_tx = ms.pos.x;


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
#define DIST_SCALE (GR_HEIGHT*1.4)

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
  if(FramePtr("F_SKY1")==texture) return;
  I64 x,y;
  I64 w=sector->shape_dc->width*2,h=sector->shape_dc->height*2;
  I64 floorx,floory;
  I32 *db_z;
  U16 *dst,color;
  I64 maxx=I16_MIN,maxy=I16_MIN;
  I64 minx=I16_MAX,miny=I16_MAX;
  F64 angle,dist;
  F64 cos,sin,cos2;
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
    maxx=MaxI64(maxx,point3.x);
    maxy=MaxI64(maxy,point3.y);
    maxx=MaxI64(maxx,point4.x);
    maxy=MaxI64(maxy,point4.y);

    minx=MinI64(minx,point3.x);
    miny=MinI64(miny,point3.y);
    minx=MinI64(minx,point4.x);
    miny=MinI64(miny,point4.y);
  }
  if(ClipLineToScrenCoords(cam,&point,&point2,at)) {
    maxx=MaxI64(maxx,point2.x);
    maxy=MaxI64(maxy,point2.y);
    maxx=MaxI64(maxx,point.x);
    maxy=MaxI64(maxy,point.y);

    minx=MinI64(minx,point2.x);
    miny=MinI64(miny,point2.y);
    minx=MinI64(minx,point.x);
    miny=MinI64(miny,point.y);
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
    maxx=MaxI64(maxx,point2.x);
    maxy=MaxI64(maxy,point2.y);
    maxx=MaxI64(maxx,point4.x);
    maxy=MaxI64(maxy,point4.y);

    minx=MinI64(minx,point2.x);
    miny=MinI64(miny,point2.y);
    minx=MinI64(minx,point4.x);
    miny=MinI64(miny,point4.y);
  }
  if(ClipLineToScrenCoords(cam,&point,&point3,at)) {
    maxx=MaxI64(maxx,point3.x);
    maxy=MaxI64(maxy,point3.y);
    maxx=MaxI64(maxx,point.x);
    maxy=MaxI64(maxy,point.y);

    minx=Min(minx,point3.x);
    miny=MinI64(miny,point3.y);
    minx=MinI64(minx,point.x);
    miny=MinI64(miny,point.y);
  }


  if(maxx<minx)
    return;
  minx=MaxI64(0,minx)>>1;
  miny=MaxI64(0,miny)>>1;
  maxx=MinI64(GR_WIDTH-2,maxx)>>1;
  maxy=MinI64(GR_HEIGHT-2,maxy)>>1;
//
  for(x=minx;x<maxx;x++) {
    angle=(ToF64(x*2)-GR_WIDTH/2)/(GR_WIDTH/2)*(cam->fov/2);
    cos=FCos(angle+cam->angle);
    sin=FSin(angle+cam->angle);
    cos2=FCos(angle);
    for(y=miny;y<maxy;y++) {
      if(1) { //TODOmagic
        dist=DIST_SCALE/((ToF64(y*2)-GR_HEIGHT/2)/(cam->h-at))/cos2;
        if(dist<0.) goto next;
        point.x=cam->x+cos*dist-sector->shape_start_x;
        point.y=cam->y+sin*dist-sector->shape_start_y;
        if(0.<=point.x<w)
	  if(0.<=point.y<h){
	    db_z=&to_dc->depth_buf[x*2+(y*2)*to_dc->width_internal];
	    if(*db_z>dist)
	      if(GrPeek0(sector->shape_dc,point.x/2,point.y/2)) {
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
	        dst=&to_dc->body[(x*2)+(y*2)*to_dc->width_internal];
	        *dst=color;
	        dst(U8*)+=to_dc->width_internal;
	        color=texture->body[floorx+(1+floory)*texture->width](U16);
	        *dst=color;
	      }
	  }
next:;
      }
    }
  }
} 

//floor is 0 for floor
//floor is 1 for middle
//floor is 2 for ceil
U0 RayCastWall(CDC *to_dc,CDC *texture,CD2 *st,CD2 *en,CDoomCamera *cam,I64 level,I64 height,I64 flrh,I64 ceilh,U8 floor,CDoomLinedef *ld,CDoomSidedef *sd) {
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
  I64 ix,iy,ih=0,tx,ty,ih2,xoff=sd->xoff-texture->x,yoff=sd->yoff-texture->y;
  I32 *db_z,idist;
  F64 dist,ratio;
  Bool repeat=FALSE,onesided=ld->front^^ld->back;
  Bool is_sky=FALSE,is_sky2=FALSE;
  CDoomSidedef *opposite;
  if(ld->front==sd)
    opposite=ld->back;
  else
    opposite=ld->front;
  if(opposite)
    is_sky=opposite->sector->ceil_dc[0]==FramePtr("F_SKY1")&&floor==2;
  if(is_sky) return;
  if(onesided)
    is_sky2=sd->sector->ceil_dc[0]==FramePtr("F_SKY1");
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
  repeat=TRUE;
  for(ca=start_angle;ca<=end_angle;ca+=cam->fov/GR_WIDTH*2) {
    ray.x=I16_MAX*FCos(ca);
    ray.y=I16_MAX*FSin(ca); 
    if(PlaneIntersect(&hit,&ray,&zero,st,en)) {
      dist=Sqrt(Sqr(hit.x)+Sqr(hit.y));
      idist=dist;
      ix=GR_WIDTH/2.+ca/(cam->fov/2.)*GR_WIDTH/2.;
      ix&=~1;
      if(dist<=0.) dist=1;
      tx=(ToI64(Sqrt(Sqr(hit.x-en->x)+Sqr(hit.y-en->y)))*2+xoff*2)%texture->width;
      if(0<=ix<=GR_WIDTH-2) {
//The offset from the ground is included in the "height",we dont render the overdraw
        margin=DIST_SCALE/(dist*FCos(ca))*(cam->h-level);
        ih=DIST_SCALE/(dist*FCos(ca))*height;
        ratio=height/ToF64(ih);
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
        ih2+=2;
        if(is_sky2) {//Fill in upper pixels Z-buf distance with distnce for sky
	  ty=iy;
	  while(ty>=0) {
	    db_z=&to_dc->depth_buf[ix+ty*to_dc->width_internal];
	    if(*db_z>idist) {
	      db_z[0]=idist;
	      db_z[1]=idist;
	      db_z+=to_dc->width_internal;
	      db_z[0]=idist;
	      db_z[1]=idist;
	    }
	    ty-=2;
	  }
        }
        if(is_sky) {
	  ih2+=iy;
	  while(ih2>=0) {
	    db_z=&to_dc->depth_buf[ix+ih2*to_dc->width_internal];
	    if(*db_z>idist) {
	      db_z[0]=idist;
	      db_z[1]=idist;
	      db_z+=to_dc->width_internal;
	      db_z[0]=idist;
	      db_z[1]=idist;
	    }
	    ih2-=2;
	  }
        } else
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
	    if(idist>cam->floor_depths[ix/2]) {
	      if(iy+ih2>=cam->floor_heights[ix/2]) {
	        break;
	      }
	    }
//https://doomwiki.org/wiki/Texture_alignment
	    if(repeat) {
	      if(onesided) {
//Dont ask nroot how any of this works,he typed in random stuff
	        if(ld->flags&WAD_LINEDEFF_LOWER_UNPEGGED) {
		  ty=(ToI64(ih2*ratio)*2+yoff*2+texture->height-2-ToI64(ratio*ih*2))%texture->height;
	        } else {
		  ty=(ToI64(ih2*ratio)*2+yoff*2-sd->sector->door_height_offset*2)%texture->height;
	        }
	      } else {
	        if(floor==0) {
		  if(ld->flags&WAD_LINEDEFF_LOWER_UNPEGGED) {
		    ty=(ToI64(ih2*ratio)*2+yoff*2+texture->height-2-ToI64(ratio*ih*2)+2*ToI64(ceilh-flrh))%texture->height;
		  } else {
		    ty=ToI64(ToI64(ih2*ratio)*2+yoff*2-ToI64(sd->sector->door_height_offset)*2)%texture->height;
		  }
	        } else{
		  if(!(ld->flags&WAD_LINEDEFF_UPPER_UNPEGGED)) {
		    ty=(ToI64(ih2*ratio)*2+yoff*2+texture->height-2-ToI64(ratio*ih*2)-ToI64(sd->sector->door_height_offset)*2)%texture->height;
		  } else {
		    ty=(ToI64(ih2*ratio)*2+yoff*2-ToI64(sd->sector->door_height_offset)*2)%texture->height;
		  }
	        }
	      }
	    } else {
	      ty=(ToF64(ih2)/ih)*(texture->height-2);
	    }
//Doors raise the ceiling but the texture needs to move along with it
	    if(opposite)
	      ty=ToI64(ty)%texture->height;
	    tx=AbsI64(tx);
	    ty=AbsI64(ty);
	    ty=ClampI64(ty,0,texture->height-2);
	    tx=ClampI64(tx,0,texture->width-2);
	    tx&=~1;
	    ty&=~1;
	    color=texture->body[tx+ty*texture->width_internal](U16);
	    to=&to_dc->body[ix+(iy+ih2)*to_dc->width_internal];
	    db_z=&to_dc->depth_buf[ix+(iy+ih2)*to_dc->width_internal];
	    if(*db_z>idist) {
	      if(color&0xff!=TRANSPARENT) {
	        db_z[0]=idist;
	        db_z[1]=idist;
	        db_z+=to_dc->width_internal;
	        db_z[0]=idist;
	        db_z[1]=idist;
	        *to=color;
	        to(U8*)+=to_dc->width_internal;
	        color=texture->body[tx+(ty+1)*texture->width_internal](U16);
	        *to=color;
	      }
	    }
	  }
      }
      if(texture->flags&DCF_NO_TRANSPARENTS) {
        if(!is_sky) {
	  if(iy<cam->floor_heights[ix/2]) {
set_floor_height:
	    if(floor==0)
	      cam->floor_heights[ix/2]=ClampI64(iy,0,GR_HEIGHT);
	    else
	      cam->ceil_heights[ix/2]=ClampI64(iy+ih,0,GR_HEIGHT);
	    cam->floor_depths[ix/2]=idist;
//	  cam->ceil_depths[ix/2]=idist;
	    //	  GrVLine(cam->floor_dc,ix/2,0,(iy+ih)/2);
	  } else if(cam->floor_depths[ix/2]>=idist) {
	    goto set_floor_height;
	  }
        }
      }
    }
  }
}


U0 PlotSpriteIn3DSpace(CDC *to_dc,F64 height,CDC *sprite,CDoomCamera *cam,CD2 *p,F64 level,Bool reflect=FALSE) {
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
  new_height=DIST_SCALE/(1+ToF64(dist))*sprite->height/2;
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
      if(y>cam->floor_heights[x/2])
        if(dist>cam->floor_depths[x/2])
	  goto nextx;
      if(y<cam->ceil_heights[x/2])
        if(dist>cam->ceil_depths[x/2])
	  goto nextx;
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
          *dst=*from,*db_z=dist,db_z[1]=dist;
        from(U8*)+=sprite->width_internal;
        dst(U8*)+=to_dc->width_internal;
	db_z+=to_dc->width_internal;
        if(from->u8[0]!=TRANSPARENT)
          *dst=*from,*db_z=dist,db_z[1]=dist;
      }
nextx:;
    }
  }
}

CDoomSector *GetSectorForCoord(CDoomLevel *level,I64 x,I64 y) {
  CDoomSubsector *ss;
  CDoomBSPNode *node=DoomWhichBSPNode(x,y,level,&ss);
  if(ss) {
    return ss->sector;
  }
  return NULL;
}

U0 DrawAThing(CDC *to_dc,CDoomThing *thing,CDoomCamera *cam) {
  if(!thing->template) return; //???
  if(thing->template==doom_thing_types[1]) return; //Dont render player
  if(!thing->animation) thing->animation=thing->template->_animation;
  I64 anim_frame=(tS-thing->anim_start_tS)*4,frame_cnt,face;
  F64 angle,gap;
  CDC *sprite;
  CD2 p;
  Bool reflect;
  frame_cnt=0;
  while(thing->animation[frame_cnt].chr)
    frame_cnt++;
  if(!frame_cnt) return;
  if(thing->anim_no_repeat)
    anim_frame=MinI64(frame_cnt-1,anim_frame);
  else
    anim_frame%=frame_cnt;
  angle=cam->angle;
  angle-=thing->angle;
  angle=Wrap(angle+pi);
  if(angle<0.)
    angle+=2.*pi;
  face=1;
  for(gap=-2.*pi/8.;gap<2*pi;gap+=2.*pi/8.) {
    if(gap<=angle<=gap+2.*pi/8.)
      break;
    face++;
  }
  if(face>8)
    face=8;
  reflect=thing->animation[anim_frame].reflect[face-1];
  sprite=thing->animation[anim_frame].faces[face-1];
  p.x=thing->x,p.y=thing->y;
  if(sprite)
    PlotSpriteIn3DSpace(to_dc,thing->template->height,sprite,cam,&p,thing->height,reflect);
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

F64 HighestCeil(CDoomLinedef *l,CDoomSector *sector) {
  F64 ret=sector->ceil_height;
  return ret;
}

I64 FrameCnt(CDC **arr) {
  I64 i=0;
  while(i<4&&arr[i])
    i++;
  return i;
}

CDC *GetMiddleTexture(CDoomSidedef *s) {
  if(!s->middle_texture[0]) return NULL;
  I64 t=ToI64(tS*4)%FrameCnt(s->middle_texture);
  return s->middle_texture[t];
}

CDC *GetUpperTexture(CDoomSidedef *s) {
  if(!s->upper_texture[0]) return NULL;
  I64 t=ToI64(tS*4)%FrameCnt(s->upper_texture);
  return s->upper_texture[t];
}

CDC *GetLowerTexture(CDoomSidedef *s) {
  if(!s->lower_texture[0]) return NULL;
  I64 t=ToI64(tS*4)%FrameCnt(s->lower_texture);
  return s->lower_texture[t];
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
  F64 floor,ceil,highest_ceil;
  for(seg_idx=0;seg_idx!=ss->cnt;seg_idx++) {
    seg=&ss->first[seg_idx];
//Use linedef as we want to see what side of the WALL we are on(not seg)
    cam_cord.x=cam->x-seg->linedef->start->x;
    cam_cord.y=cam->y-seg->linedef->start->y;
    SetVector(wall_vect,seg->linedef->end->x-seg->linedef->start->x,0);
    SetVector(wall_vect,seg->linedef->end->y-seg->linedef->start->y,1);
    opposite=NULL;
    if(IsFrontSideOfVector2D(wall_vect,&cam_cord)) 
      sidedef=seg->linedef->front,opposite=seg->linedef->back;
    else
      sidedef=seg->linedef->back,opposite=seg->linedef->front;
    no_draw=FALSE;
    if(!sidedef)
      goto skip;
    sector=sidedef->sector;
    highest_ceil=HighestCeil(seg->linedef,sector);
    for(wall=0;wall!=3;wall++) {
      if(wall==0&&(texture=GetLowerTexture(sidedef))) {
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
	      RayCastWall(to_dc,texture,seg->start,seg->end,cam,floor,ceil-floor,sector->floor_height,highest_ceil,wall,seg->linedef,sidedef);
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
      } else if(wall==2&&(texture=GetUpperTexture(sidedef))) {
        floor=Min(sector->ceil_height,CeilDepress(seg->linedef,sector));
        ceil=Max(sector->ceil_height,CeilDepress(seg->linedef,sector));
        goto draw_wall;
      } else if(wall==1&&(texture=GetMiddleTexture(sidedef))) {
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
  if(IsFrontSideOfVector2D(vect,&cam_cord)) {
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

U0 DrawSky(CDC *to_dc,CDoomLevel *l,CDoomCamera *cam) {
  CDC *texture=FramePtr("SKY1");
  I64 iy,ix,off=texture->width*cam->angle/pi,tx,ty;
  U16 *to,*from;
  for(iy=0;iy!=GR_HEIGHT;iy+=2) {
    ty=iy/ToF64(GR_HEIGHT)*texture->height;
    if(ty>texture->height-2)
      ty=texture->height-2;
    for(ix=0;ix!=GR_WIDTH;ix+=2) {
      tx=(ix+off)/ToF64(GR_WIDTH)*texture->width;
      tx%=texture->width-2;
      tx=AbsI64(tx);
      from=&texture->body[tx+ty*texture->width_internal];
      to=&to_dc->body[ix+iy*to_dc->width_internal];
      *to=*from;
      from(U8*)+=texture->width_internal;
      to(U8*)+=to_dc->width_internal;
      *to=*from;
    }
  }
}

U0 DrawDoomWorld(CDoomCamera *cam,CDoomLevel *level,CDC *to_dc) {
  CDoomSector *sector,**sorted;  
  CDoomThing *thing;
  I64 idx=0,idx2,af,tf;
  DrawSky(to_dc,l,cam);
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next)
    sector->drawn=FALSE;
  for(idx=0;idx!=GR_WIDTH/2;idx++) {
    cam->floor_heights[idx]=GR_HEIGHT;
    cam->ceil_heights[idx]=0;
    cam->floor_depths[idx]=I16_MAX;
    cam->ceil_depths[idx]=I16_MAX;
  }
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
  af=ToI64(tS*4);
  for(idx2=0;idx2!=idx;idx2++) {
    if(sorted[idx2]->floor_dc) {
      if(sorted[idx2]->floor_height<cam->h)
        DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->floor_height,sorted[idx2]->floor_dc[af%FrameCnt(sorted[idx2]->floor_dc)],TRUE);
    }
    if(sorted[idx2]->ceil_dc) {
      if(sorted[idx2]->ceil_height>cam->h)
        DrawTexturedFlat(to_dc,cam,sorted[idx2],sorted[idx2]->ceil_height,sorted[idx2]->ceil_dc[af%FrameCnt(sorted[idx2]->ceil_dc)],FALSE);
    }
  }
  for(thing=level->things.next;thing!=&level->things;thing=thing->next) {
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



CDoomCamera cam;
CDoomSector *sect=l->sectors.last;
"%x,$ER$%x\n",sect->linedef_cnt,sect->linedefs[0];
cam.x=sect->linedefs[0]->start->x;
cam.y=sect->linedefs[0]->start->y;
cam.fov=pi/4;
//cam.angle=-pi;
cam.h=0;
Fs->song_task=Spawn(&SongTask,NULL,"Song",,Fs);

F64 GetTargetLiftHeight(CDoomSector *floor,I64 type) {
  F64 lowest=floor->floor_height,highest=floor->floor_height,diff;
  I64 idx,idx2;
  CDoomSidedef *sd;
  Bool up;
  switch(type) {
    case LIFT_STOP:
      return floor->floor_height;
    case LIFT_LOWEST_FLOOR:
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        sd=floor->linedefs[idx]->front;
        if(sd&&sd!=floor)
	  lowest=Min(lowest,sd->sector->floor_height);
        sd=floor->linedefs[idx]->back;
        if(sd&&sd!=floor)
	  lowest=Min(lowest,sd->sector->floor_height);
      }
      up=floor->floor_height==lowest;
      if(up) return floor->base_floor_height;
      return lowest;
    case LIFT_RAISE_32:
      up=floor->base_floor_height+32<floor->floor_height;
      if(up)
        return floor->base_floor_height+32;
      return floor->base_floor_height;
    case LIFT_RAISE_24:
      up=floor->base_floor_height+24<floor->floor_height;
      if(up)
        return floor->base_floor_height+24;
      return floor->base_floor_height;
    case LIFT_RAISE_NEXT_FLOOR:
      diff=0.;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        for(idx2=0;idx2!=2;idx2++) {
	  if(idx2)
	    sd=floor->linedefs[idx]->front;
	  else
	    sd=floor->linedefs[idx]->back;
	  if(sd&&sd!=floor)
	    if(sd->sector->floor_height>floor->floor_height)
	      diff=Max(diff,sd->sector->floor_height-floor->floor_height);
        }
        if(diff==0.)
          return floor->base_floor_height;
        return diff+floor->floor_height;
      }
      return lowest;     
    case LIFT_LOW_HIGH_REPEAT:
      if(!floor->going_down) {
	floor->going_up=TRUE;
	floor->going_down=FALSE;
        for(idx=0;idx!=floor->linedef_cnt;idx++) {
	  sd=floor->linedefs[idx]->front;
	  if(sd&&sd!=floor)
	    highest=Max(highest,sd->sector->floor_height);
	  sd=floor->linedefs[idx]->back;
	  if(sd&&sd!=floor)
	    highest=Max(highest,sd->sector->floor_height);
        }
	return highest;
      } else {
	floor->going_up=FALSE;
	floor->going_down=TRUE;
        for(idx=0;idx!=floor->linedef_cnt;idx++) {
	  sd=floor->linedefs[idx]->front;
	  if(sd&&sd!=floor)
	    lowest=Min(lowest,sd->sector->floor_height);
	  sd=floor->linedefs[idx]->back;
	  if(sd&&sd!=floor)
	    lowest=Min(lowest,sd->sector->floor_height);
        }
        return lowest;
      }
    case LIFT_CEIL_TOGGLE:
      if(floor->base_floor_height==floor->floor_height)
	return floor->base_ceil_height;
      return floor->base_floor_height;
  }
}


#define WACTIVATE_PUSH 1
#define WACTIVATE_SHOOT 2
#define WACTIVATE_SWITCH 4
#define WACTIVATE_MONSTER 8
#define WACTIVATE_WALK 0x10

#define TIME_SCALE (35.)

Bool OutsideOfRange(F64 p,F64 s,F64 e) {
  if(s<e&&s<=p<=e)
    return FALSE;
  else if(e<=p<=s)
    return FALSE;
  return TRUE;
}

U0 UpdateSector(CDoomSector *s) {
  F64 time=tS,ceil=I16_MAX,dir;
  I64 idx;
  CDoomLinedef *ld=s->cur_action_linedef;
  if(!ld) return;
  if(s->paused) return;
  if(ld->special_type->type=='Ceil') {
    if(!s->going_up&&!s->going_down) {
      if(s->target_end>s->ceil_height)
        s->going_up=TRUE,s->going_down=FALSE;
      else
        s->going_down=TRUE,s->going_up=FALSE;
    }
    dir=Sign(s->target_end-s->target_start);
    s->ceil_height=dir*s->speed*TIME_SCALE*(tS-s->start_tS)+s->target_start;
    if(s->going_up&&s->ceil_height>s->target_end) {
      s->ceil_height=s->target_end;
      s->going_up=FALSE;
      s->cur_action_linedef=NULL;
    } else if(s->going_down&&s->ceil_height<s->target_end) {
      s->ceil_height=s->target_end;
      s->going_down=FALSE;
      s->cur_action_linedef=NULL;
    }
  } else if(ld->special_type->type=='Lift') {
    if(ld->special_type(CDoomLift*)->target==LIFT_LOW_HIGH_REPEAT) {
      dir=Sign(s->target_end-s->target_start);
      s->floor_height=dir*s->speed*TIME_SCALE*(tS-s->start_tS)+s->target_start;
      if(s->going_up) {
        if(s->floor_height>s->target_end) {
	  s->floor_height=s->target_end;
lift_again:
	  s->start_tS=tS;
	  s->target_end=GetTargetLiftHeight(s,ld);
        }
      } else if(s->going_down) {
        if(s->floor_height<s->target_end) {
	  s->floor_height=s->target_end;
	  goto lift_again;
        }
      }
    } else  {
      if(s->target_end>s->floor_height)
        s->going_up=TRUE,s->going_down=FALSE;
      else
        s->going_down=TRUE,s->going_up=FALSE;
      goto floor_defacto;
    }
  } else if(ld->special_type->type=='Door') {
//A door is fully open when its ceiling height is 4 less than the lowest neighbor ceiling adjacent to it
    for(idx=0;idx!=s->linedef_cnt;idx++) {
      if(s->linedefs[idx]->back&&s->linedefs[idx]->back->sector!=s)
        ceil=Min(s->linedefs[idx]->back->sector->base_ceil_height-4,ceil);
      else if(s->linedefs[idx]->front&&s->linedefs[idx]->front->sector!=s)
        ceil=Min(s->linedefs[idx]->front->sector->base_ceil_height-4,ceil);
    }
    if(s->opening) {
      s->target_end=ceil;
      dir=Sign(s->target_end-s->target_start);
      if(!s->waiting) 
        s->ceil_height=dir*s->speed*TIME_SCALE*(tS-s->start_tS)+s->target_start;      
      if(OutsideOfRange(s->ceil_height,s->target_start,s->target_end)||s->waiting) {
        s->ceil_height=ceil;
//-1 for never close/open again
        if(s->wait_time>=0.) {
//close again
	  if(!s->waiting) {
	    s->waiting=TRUE;
	    s->start_tS=tS;
	  }
	  if(s->wait_time+s->start_tS>time) return;
	  s->waiting=FALSE;
	  s->start_tS=tS;
	  s->opening=FALSE;
	  s->closing=TRUE;
	  s->wait_time=-1.;
	  s->target_start=s->ceil_height;
        }
      }
    } else if(s->closing) {
      s->target_end=s->floor_height;
      dir=Sign(s->target_end-s->target_start);
      s->ceil_height=dir*s->speed*TIME_SCALE*(tS-s->start_tS)+s->target_start;      
      if(OutsideOfRange(s->ceil_height,s->target_start,s->target_end)||s->waiting) {
        s->ceil_height=s->base_floor_height;
//-1 for never close/open again
        if(s->wait_time>=0.) {
	  if(!s->waiting) {
	    s->waiting=TRUE;
	    s->start_tS=tS;
	  }
	  if(s->wait_time+s->start_tS>time) return;
	  s->waiting=FALSE;
//open again
	  s->start_tS=tS;
	  s->opening=TRUE;
	  s->closing=FALSE;
	  s->wait_time=-1.;
	  s->target_start=s->floor_height;
        }
      }
    }
    s->door_height_offset=s->ceil_height-s->base_floor_height;
  } else if(ld->special_type->type=='Floor') {
floor_defacto:
    dir=Sign(s->target_end-s->target_start);
    if(!s->waiting) 
      s->floor_height=dir*s->speed*TIME_SCALE*(tS-s->start_tS)+s->target_start;
     if(s->going_up) {
      if(s->floor_height>=s->target_end) {
        s->floor_height=s->target_end;
        s->going_up=FALSE;
floor_en:
        if(ld->special_type->type=='Lift'&&!s->reverting) {
	  if(!s->waiting) {
	    s->waiting=TRUE;
	    s->start_tS=tS;
	  }
	  if(s->wait_time+s->start_tS>time) {
	    return;
	  }
	  s->waiting=FALSE;
	  s->start_tS=tS;
	  s->reverting=TRUE;
	  s->target_start=s->floor_height;
	  s->target_end=s->base_floor_height;
        } else {
	  s->reverting=FALSE;
	  s->cur_action_linedef=NULL;
	  s->going_up=FALSE,s->going_down=FALSE;
        }
      }
    } else if(s->going_down) {
      if(s->floor_height<=s->target_end) {
        s->floor_height=s->target_end;
        s->going_down=FALSE;
        goto floor_en;
      }
    }
  }
}

F64 GetTargetFloorHeight(CDoomSector *floor,I64 type,Bool up) {
  F64 dst;
  F64 diff;
  CDoomSidedef *sd;
  I64 idx;
  switch(type) {
      break; case FLOOR_DST_LOWEST:
      dst=I16_MAX;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
        } else
	  sd=floor->linedefs[idx]->back;
        if(sd&&sd->sector!=floor&&sd->sector->floor_height<dst)
	  dst=sd->sector->floor_height;
      }
      break; case FLOOR_ABS_24:
      dst=floor->base_floor_height;
      if(up)
        return dst+24;
      return dst-24;
      break; case FLOOR_ABS_512:
      dst=floor->base_floor_height;
      if(up)
        return dst+512;
      return dst-512;
    start:
      dst=I16_MIN;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
        } else
	  sd=floor->linedefs[idx]->back;
        if(sd&&sd->sector!=floor&&sd->sector->ceil_height>dst)
	  dst=sd->sector->ceil_height;
      }
      case FLOOR_DST_HIGHEST_CEIL:
        break;
      case FLOOR_DST_HIGHEST_CEIL_ADD_8:
        dst+=8.;
        break;
    end:
      break;
    start:
      dst=I16_MIN;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
        } else
	  sd=floor->linedefs[idx]->back;
        if(sd&&sd->sector!=floor&&sd->sector->floor_height>dst)
	  dst=sd->sector->floor_height;
      }
      case FLOOR_DST_HIGHEST_FLOOR:
        break;
      case FLOOR_DST_HIGHEST_FLOOR_ADD_8:
        dst+=8.;
        break;
    end:
      break;
    start:
      dst=I16_MAX;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
        } else
	  sd=floor->linedefs[idx]->back;
        if(sd&&sd->sector!=floor&&sd->sector->ceil_height<dst)
	  dst=sd->sector->ceil_height;
      }
      case FLOOR_DST_LOWEST_CEIL:
        break;
      case FLOOR_DST_LOWEST_CEIL_SUB_8:
        dst-=8.;
        break;
    end:
      break;
    start:
      dst=I16_MAX;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
        } else
	  sd=floor->linedefs[idx]->back;
        if(sd&&sd->sector!=floor&&sd->sector->floor_height<dst)
	  dst=sd->sector->floor_height;
      }
      case FLOOR_DST_LOWEST_FLOOR:
        break; case FLOOR_DST_LOWEST_FLOOR_SUB_8:
        dst-=8.;
        break;
    end:
      break; case FLOOR_DST_NEXT_FLOOR:
      if(up) {
        dst=floor->ceil_height;
        for(idx=0;idx!=floor->linedef_cnt;idx++) {
	  if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
	  } else
	    sd=floor->linedefs[idx]->back;
	  if(sd&&sd->sector!=floor) {
	    if(sd->sector->floor_height<dst) {
	      diff=sd->sector->floor_height-floor->floor_height;
	      if(diff<dst-floor->floor_height)
	        dst=sd->sector->floor_height;
	    }
	  }
        }
      } else {
        dst=I16_MIN;
        for(idx=0;idx!=floor->linedef_cnt;idx++) {
	  if((sd=floor->linedefs[idx]->front)&&sd->sector!=floor) {
	  } else
	    sd=floor->linedefs[idx]->back;
	  if(sd&&sd->sector!=floor) {
	    if(sd->sector->floor_height>dst) {
	      diff=sd->sector->floor_height-dst;
	      if(diff<floor->floor_height-dst)
	        dst=sd->sector->floor_height;
	    }
	  }
        }
      }
      break;
  }
  return dst;
}
F64 GetTargetCeilHeight(CDoomSector *s,I64 target) {
  I64 idx;
  CDoomSector *other;
  F64 to=s->ceil_height;
  switch(target) {
    case CEIL_DST_FLOOR:
      return s->floor_height;
    case CEIL_DST_HIGHEST_CEIL:
      for(idx=0;idx!=s->linedef_cnt;idx++) {
	if(s->linedefs[idx]->back&&s!=s->linedefs[idx]->back->sector) {
	  other=s->linedefs[idx]->back->sector;
        } else if(s->linedefs[idx]->front&&s!=s->linedefs[idx]->front->sector) {
	  other=s->linedefs[idx]->front->sector;
	}
	if(other)
	  to=Max(to,other->ceil_height);
      }
      return to;
    case CEIL_DST_FLOOR8:
      return s->floor_height+8;
    case CEIL_DST_LOWEST_CEIL:
      for(idx=0;idx!=s->linedef_cnt;idx++) {
	if(s->linedefs[idx]->back&&s!=s->linedefs[idx]->back->sector) {
	  other=s->linedefs[idx]->back->sector;
        } else if(s->linedefs[idx]->front&&s!=s->linedefs[idx]->front->sector) {
	  other=s->linedefs[idx]->front->sector;
	}
	if(other)
	  to=Min(to,other->ceil_height);
      }
      return to;
    case CEIL_DST_HIGHEST_FLOOR:
      to=s->floor_height;
      for(idx=0;idx!=s->linedef_cnt;idx++) {
	if(s->linedefs[idx]->back&&s!=s->linedefs[idx]->back->sector) {
	  other=s->linedefs[idx]->back->sector;
        } else if(s->linedefs[idx]->front&&s!=s->linedefs[idx]->front->sector) {
	  other=s->linedefs[idx]->front->sector;
	}
	if(other)
	  to=Min(to,other->floor_height);
      }
      return to;
  }
}
U0 _TriggerLinedef(CDoomLevel *l,CDoomSector *s,CDoomLinedef *ld,I64 flags) {
  CDoomActionSector *type;
  CDoomFloor *fl;
  CDoomDoor *door;
  CDoomLift *lift;
  CDoomCeil *ceil;
  I64 idx;
  CDoomLinedef *ld2;
  F64 dst;
  if(ld) {
    if((type=ld->special_type)) {
      if(type->type=='Ceil') {
	ceil=type;
        switch(ceil->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return;
cactivate1:          
	    if(s->activated) return;
	    s->activated=TRUE;
cactivate:
	    if(s->cur_action_linedef)
	      return;
	    dst=GetTargetLiftHeight(s,ceil->target);
	    s->target_start=s->floor_height;
	    s->target_end=dst;
	    s->start_tS=tS;
	    s->speed=ceil->speed;
	    s->cur_action_linedef=ld;
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto cactivate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto cactivate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto cactivate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return;
	    goto cactivate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto cactivate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto cactivate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto cactivate;
        }
      } else if(type->type=='Lift') {
        lift=type;
        switch(lift->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return;
lactivate1:          
	    if(s->activated) return;
	    s->activated=TRUE;
lactivate:
	    if(s->cur_action_linedef)
	      return;
	    dst=GetTargetLiftHeight(s,lift->target);
	    s->target_start=s->floor_height;
	    s->target_end=dst;
	    s->start_tS=tS;
	    s->speed=lift->speed;
	    s->cur_action_linedef=ld;
	    s->wait_time=lift->delay;
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto lactivate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto lactivate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto lactivate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return;
	    goto lactivate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto lactivate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto lactivate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto lactivate;
        }
      } else if(type->type=='Floor') {
        fl=type;
        switch(fl->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return;
factivate1:

	    if(s->activated) return;
	    s->activated=TRUE;
factivate:
	    dst=GetTargetFloorHeight(s,fl->target,fl->direction==FLOOR_DIR_UP);
	    if(fl->direction==FLOOR_DIR_UP&&s->going_up) return;
	    if(fl->direction==FLOOR_DIR_DOWN&&s->going_down) return;
	    if(fl->direction==FLOOR_DIR_UP)
	      s->going_up=TRUE;
	    if(fl->direction==FLOOR_DIR_DOWN)
	      s->going_down=TRUE;
	    s->target_start=s->floor_height;
	    s->target_end=dst;
	    s->start_tS=tS;
	    s->speed=fl->speed;
	    s->cur_action_linedef=ld;
//Account for texture/type change
	    if(fl->texture_change||fl->type_change) {
	      if(fl->model==FLOOR_MODEL_NUMBERED) {
//See EV_DoFloor in doom3do source code
	        for(idx=0;idx!=s->linedef_cnt;idx++) {
		  ld2=s->linedefs[idx];
		  if(ld2->front&&ld2->back) {
		    if(ld2->front->sector!=s) {
		      if(fl->texture_change)
		        MemCpy(s->floor_dc,ld2->front->sector->floor_dc,8*4);
		      if(fl->type_change)
		        s->special_type=ld2->front->sector->special_type;
		      break;
		    }
		    if(ld2->back->sector!=s) {
		      if(fl->texture_change)
		        MemCpy(s->floor_dc,ld2->back->sector->floor_dc,8*4);
		      if(fl->type_change)
		        s->special_type=ld2->back->sector->special_type;
		      break;
		    }
		  }
	        }
	      } else if(fl->model==FLOOR_MODEL_TRIGGER) {
	        if(fl->texture_change)
		  MemCpy(s->floor_dc,ld->front->sector->floor_dc,8*4);
	        if(fl->type_change)
		  s->special_type=ld->front->sector->special_type;
	      }
	    }
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto factivate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto factivate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto factivate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return;
	    goto factivate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto factivate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto factivate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto factivate;
        }
      } else if(type->type=='Door') {
        door=type;
        switch(door->trigger) {
	  case 'P1':
	    s=ld->back->sector;
	    if(!(flags&WACTIVATE_PUSH)) return;
activate1:
	    if(s->activated) return;
	    s->activated=TRUE;
activate:
//Check for keys
	    if(l->has_red_key^^(door->key&DOOR_LOCK_RED)) return;
	    if(l->has_blue_key^^(door->key&DOOR_LOCK_BLUE)) return;
	    if(l->has_yellow_key^^(door->key&DOOR_LOCK_YELLOW)) return;
//Do the door action
	    s->target_start=s->ceil_height;
	    switch(door->action) {
	      case DOOR_ACTION_OPEN_WAIT_CLOSE:
	        if(s->opening) return;
	        s->cur_action_linedef=ld;
	        s->opening=TRUE;
	        s->start_tS=tS;
	        s->speed=door->speed;
	        s->wait_time=door->wait;
	        break;
	      case DOOR_ACTION_CLOSE_WAIT_OPEN:
	        if(s->closing) return;
	        s->cur_action_linedef=ld;
	        s->closing=TRUE;
	        s->start_tS=tS;
	        s->speed=door->speed;
	        s->wait_time=door->wait;
	        break;
	      case DOOR_ACTION_CLOSE:
	        if(s->closing) return;
	        s->cur_action_linedef=ld;
	        s->closing=TRUE;
	        s->start_tS=tS;
	        s->speed=door->speed;
	        s->wait_time=-1.;
	        break;
	      case DOOR_ACTION_OPEN:
	        if(s->opening) return;
	        s->cur_action_linedef=ld;
	        s->opening=TRUE;
	        s->start_tS=tS;
	        s->speed=door->speed;
	        s->wait_time=-1.;
	        break;
	    }
	    break;
	  case 'W1':
	    if(s->activated) return;
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto activate1;
	    break;
	  case 'S1':
	    if(s->activated) return;
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto activate1;
	    break;
	  case 'G1':
	    if(s->activated) return;
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto activate1;
	    break;
	  case 'PR':
	    s=ld->back->sector;
	    if(!(flags&WACTIVATE_PUSH)) return;
	    goto activate;
	  case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return;
	    goto activate;
	  case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return;
	    goto activate;
	  case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return;
	    goto activate;
        }
      }
    }
  }
}
CDC *AltSwitchTexture(U8 *txt,Bool on=FALSE) {
  static U8 *switch_textures[40]={
  "SW1BLUE",
        "SW1BRCOM", 
        "SW1BRI",
        "SW1BRN1",
        "SW1BRN2",
        "SW1BRNGN", 
        "SW1BROWN", 
        "SW1CMT", 
        "SW1COMM", 
        "SW1COMP", 
        "SW1DIRT", 
        "SW1EXIT", 
        "SW1GARG", 
        "SW1GRAY", 
        "SW1GRAY1", 
        "SW1GSTON", 
        "SW1HOT", 
        "SW1LION", 
        "SW1MARB", 
        "SW1MET2", 
        "SW1METAL", 
        "SW1MOD1", 
        "SW1PANEL", 
        "SW1PIPE", 
        "SW1ROCK", 
        "SW1SATYR", 
        "SW1SKIN", 
        "SW1SKULL", 
        "SW1SLAD", 
        "SW1STARG",
        "SW1STON1", 
        "SW1STON2", 
        "SW1STON6", 
        "SW1STONE", 
        "SW1STRTN", 
        "SW1TEK",
        "SW1VINE", 
        "SW1WDMET", 
        "SW1WOOD",
        "SW1ZIM"
        };
  U8 buf[STR_LEN];
  I64 idx=40;
  while(idx--) {
    StrCpy(buf,switch_textures[idx]);
    if(!FramePtr(buf))
     goto skip;
    if(FramePtr(buf)==txt&&!on) {
      buf[2]='2';
      return FramePtr(buf);
    }
    if(on) {
      buf[2]='2';       
      if(FramePtr(buf)==txt) {
        buf[2]='1';
        return FramePtr(buf);
      }
    }
skip:;
  }
  return NULL;
}

U0 ButtonThinker(CDoomLevel *l,CDoomThinker *t) {
  CDoomSidedef *sd=t->user_data1;
  Bool repeat=t->user_data2;
  F64 reset_time=t->user_data3(F64);
  I64 which_texture=t->user_data4;
  U8 on_off_idx='2'; 
  CDC *dc;
  if(!repeat) {
    on_off_idx='2';
    Free(t);
    QueRem(t);
    goto set_and_ret;
  }
  if(reset_time>tS) {
    on_off_idx='2';
set_and_ret:
      switch(which_texture) {
        case 2: 
	  if(dc=AltSwitchTexture(sd->upper_texture[0],on_off_idx!='2'))
	  sd->upper_texture[0]=dc;
	  break;
        case 1: 
	  if(dc=AltSwitchTexture(sd->middle_texture[0],on_off_idx!='2'))
	  sd->middle_texture[0]=dc;
	  break;
        case 0: 
	  if(dc=AltSwitchTexture(sd->lower_texture[0],on_off_idx!='2')) {
	  sd->lower_texture[0]=dc;
	  }
	  break;
      }
    return;
  }
  on_off_idx='1';
  Free(t);
  QueRem(t);
  goto set_and_ret;
}
U0 AddButtonThinker(CDoomLevel *l,CDoomSidedef *s,I64 which_part,Bool repeat=TRUE) {
  CDoomThinker *t=AddThinker(l,&ButtonThinker);
  t->user_data1=s;
  t->user_data2=repeat;
  t->user_data3(F64)=tS+2.;
  t->user_data4=which_part;
}

U0 TriggerLinedef(CDoomLevel *l,CDoomLinedef *ld,I64 flags) {
  CDoomSector *sector,*head=&l->sectors;
  if(!ld->special_type) return;
//Push operators on the linedef that called it
  if(ld->special_type(CDoomDoor*)->trigger.u8[0]=='P') {
    _TriggerLinedef(l,ld->back->sector,ld,flags);
  } else
    for(sector=head->next;sector!=head;sector=sector->next) {
      if(sector->tag_number==ld->sector_tag)
        _TriggerLinedef(l,sector,ld,flags);
    }
}



extern CDoomThing *p;
extern U0 LineAttack(CDoomLevel *l,CDoomThing *self,CDoomThing *target,F64 range,F64 angle,F64 damage);
#include "Collision.HC";
#include "ST.HC";
#include "Player.HC";
#include "Enemy.HC";
#include "Physics.HC";
CDoomPlayer *p=PlayerNew(l);
U0 CheckPowerupPickup(CDoomLevel *l) {
  CDoomThing *t,*head=&l->things,*next;
  AmmoType *load;
  GunAvail *avail;
  Bool change;
  I64 orig;
  for(t=head->next;t!=head;t=next) {
    next=t->next;
    if(SqrI64(t->template->radius)>=SqrI64(p->x-t->x)+SqrI64(p->y-t->y)) {
      switch(t->template->type) {
        case 2006: //BFG
	  p->arsenal[7]->available=TRUE;
cell:
	  load=p->arsenal[6]->load;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=40;
	  else
	    load->ammo+=20;
	  load->ammo=ClampI64(load->ammo,0,maxCells);
	  if(load->ammo!=orig) {
rem:
	    QueRem(t);
	    Free(t);
	  }
	  break;
        case 2002: //Chaingun
	  load=p->arsenal[3]->load;
	  p->arsenal[3]->available=TRUE;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=40;
	  else
	    load->ammo+=20;
	  load->ammo=ClampI64(load->ammo,0,maxBullets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2005: //Chainsaw
	  p->arsenal[5]->available=TRUE;
	  break;
        case 2004: //Plasma gun
	  load=p->arsenal[6]->load;
	  p->arsenal[6]->available=TRUE;
	  goto cell;
        case 2003: //Rocket luancher
	  load=p->arsenal[4]->load;
	  p->arsenal[4]->available=TRUE;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=2;
	  else
	    load->ammo+=1;
	  load->ammo=ClampI64(load->ammo,0,maxRockets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
	  break;
        case 2001: //Shutgun
	  load=p->arsenal[2]->load;
	  p->arsenal[2]->available=TRUE;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=8;
	  else
	    load->ammo+=4;
	  load->ammo=ClampI64(load->ammo,0,maxBullets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2008: //4 shells
	  load=p->arsenal[2]->load;
	  orig=load->ammo;
	  load->ammo+=4;
	  load->ammo=ClampI64(load->ammo,0,maxShells);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2048: //Box of bullets
	  load=p->arsenal[1]->load;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=100;
	  else
	    load->ammo+=50;
	  load->ammo=ClampI64(load->ammo,0,maxBullets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2046: //Box of rockets
	  load=p->arsenal[4]->load;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=10;
	  else
	    load->ammo+=5;
	  load->ammo=ClampI64(load->ammo,0,maxRockets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2049: //Box of shotfgu
	  load=p->arsenal[2]->load;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=40;
	  else
	    load->ammo+=20;
	  load->ammo=ClampI64(load->ammo,0,maxRockets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2007: //clip
	  load=p->arsenal[1]->load;
	  orig=load->ammo;
	  if(l->skill==0||l->skill==5)
	    load->ammo+=20;
	  else
	    load->ammo+=10;
	  load->ammo=ClampI64(load->ammo,0,maxBullets);
	  if(load->ammo!=orig) 
	    goto rem;
	  break;
        case 2047: //Energy cell
	  goto cell;
        case 17: //Energy cell pack
	  load=p->arsenal[6]->load;
	  orig=load->ammo;
	  load->ammo+=20;
	  load->ammo=ClampI64(load->ammo,0,maxCells);
	  if(load->ammo!=orig)
	    goto rem;
	  break;
        case 2010: //Rocket
	  load=p->arsenal[4]->load;
	  orig=load->ammo;
	  load->ammo+=1;
	  load->ammo=ClampI64(load->ammo,0,maxRockets);
	  if(load->ammo!=orig)
	    goto rem;
	  break;

//Yeah homie,we bout to get some power ups
	case 2015:
	  orig=p->armor;
	  p->armor=ClampI64(p->armor+1,0,200);
	  if(orig!=p->armor)
	    goto rem;
	  break;
	case 2014:
	  orig=p->health;
	  p->health=ClampI64(p->health+1,0,200);
	  if(orig!=p->health)
	    goto rem;
	  break;
	case 83: //Megasphere
	  p->health=200;
	  p->armor=200;
	  goto rem;
	case 2013: //Supercharge
	  orig=p->health;
	  p->health=ClampI64(p->health+20,0,200);
	  if(orig!=p->health)
	    goto rem;
	  break;
	case 2018: //de-facto Armor
	  if(p->armor>=100)
	    break;
	  p->armor=100.;
	  goto rem;
	case 2019: //megarmor
	  if(p->armor>=200)
	    break;
	  p->armor=200.;
	  goto rem;
	case 2012:
	  if(p->health>=100)
	    break;
	  p->health=ClampI64(p->health+25,0,100);
	  goto rem;
	case 2011:
	  if(p->health>=100)
	    break;
	  p->health=ClampI64(p->health+10,0,100);
	  goto rem;
//Keys
	case 5: //BLue keycard
	  l->has_blue_key=TRUE;
	  goto rem;
	case 40: //BLue skull key
	  l->has_blue_key=TRUE;
	  goto rem;
	case 38: //Red skull key
	  l->has_red_key=TRUE;
	  goto rem;
	case 13: //Red keycard
	  l->has_red_key=TRUE;
	  goto rem;
	case 39: //Yellow skull key
	  l->has_yellow_key=TRUE;
	  goto rem;
	case 6: //Yellow keycard
	  l->has_yellow_key=TRUE;
	  goto rem;
      }
    }
  }
}

U0 PlayerAttack(F64 shots_per_minute,F64 min_damage,F64 max_damage,F64 range,U64 rocket_type=0) {
  static F64 last_attack=0.;
  F64 cooldown=60./shots_per_minute;
  if(tS<last_attack+cooldown) return;
  last_attack=tS;
  F64 angle=p->angle,r;
  F64 damage=Rand*(max_damage-min_damage)+min_damage;
  I64 idx;
  CDoomThing *target=PlayerPickTarget(l,p);
  if(!rocket_type) {
     if(weaponIndex==2) {//Shotgun
       for(idx=0;idx!=3;idx++) {
         r=(Rand-.5)*2;
	 angle=p->angle+r*9.8*pi/360.; 
         LineAttack(l,p,target,range,angle,damage);
       }
     } else
       LineAttack(l,p,target,range,angle,damage);
  } else {
PrintI("p",1);
    SpawnMissile(l,p,target,rocket_type);
  }
}

U0 UpdateLevel(CDoomLevel *l) {
  CDoomSector *sector,*head=&l->sectors;
  Physics(l);
  UpdateThinkers(l);
  CheckPowerupPickup(l);
  for(sector=head->next;sector!=head;sector=sector->next) {
    UpdateSector(sector);
  }
}



U0 PressAWall(CDoomLevel *l,CD2 *where,F64 angle,F64 height) {
  CD2 dummy;
  F64 floor,floor2,ceil,ceil2;
  I64 which_texture=0;
  Bool repeat=FALSE;
  U64 trigger;
  CDoomLinedef *ld;
  CDoomSidedef *sd;
  Vector *ldv;
  dummy.x=where->x;
  dummy.y=where->y;
  ld=MoveInLevel(l,&dummy,angle,64.,1.,height,0);
  if(ld) {
    if(ld->front^^ld->back) {
      which_texture=0;
      if(ld->front) sd=ld->front;
      if(ld->back) sd=ld->front;
    } else {
	ldv=CreateVector(2);
	ldv->data[0]=ld->end->x-ld->start->x;
	ldv->data[1]=ld->end->y-ld->start->y;
	dummy.x=where->x-ld->start->x;
	dummy.y=where->y-ld->start->y;
	if(IsFrontSideOfVector2D(ldv,&dummy)) {
	   sd=ld->front;
	   floor=ld->front->sector->floor_height;
	   floor2=FloorRaise(ld,ld->front->sector);
	   ceil=ld->front->sector->ceil_height;
	   ceil2=CeilDepress(ld,ld->front->sector);
	} else {
	   sd=ld->back;
	   floor=ld->back->sector->floor_height;
	   floor2=FloorRaise(ld,ld->back->sector);
	   ceil=ld->back->sector->ceil_height;
	   ceil2=CeilDepress(ld,ld->back->sector);
	}
	if(height<floor2) which_texture=0;
	else if(floor2<=height<=ceil2) which_texture=1;
	else which_texture=2;
        DestroyVector(ldv);
    }
    switch(which_texture) {
      case 2:
	if(AltSwitchTexture(sd->upper_texture[0])) {
pass:
	  if(ld->special_type->type=='Door')
	    trigger=ld->special_type(CDoomDoor*)->trigger;
	  else if(ld->special_type->type=='Ceil')
	    trigger=ld->special_type(CDoomCeil*)->trigger;
	  else if(ld->special_type->type=='Floor')
	    trigger=ld->special_type(CDoomFloor*)->trigger;
	  else if(ld->special_type->type=='Lift')
	    trigger=ld->special_type(CDoomLift*)->trigger;
	  if(trigger.u8[1]=='P')
            TriggerLinedef(l,ld,WACTIVATE_PUSH);
	  else
            TriggerLinedef(l,ld,WACTIVATE_SWITCH);
	  AddButtonThinker(l,sd,which_texture,trigger.u8[1]!='1');
	}
	break;
      case 1:
	if(AltSwitchTexture(sd->middle_texture[0]))
	  goto pass;
	break;
      case 0:
	if(AltSwitchTexture(sd->lower_texture[0]))
	  goto pass;
	break;
    }
  }
}


U0 AnimateTask(I64)
{
  while(TRUE)
  {   
   AnimateFire(p);
   Sleep(60);  
  }
  
}


U0 UpdateCameraFromPlayer(CDoomCamera *cam,CDoomPlayer *p) {
  F64 angle;
  //if were are dead,sink the camera
  if(p->health<=0.) {
    cam->h=Clamp(cam->h-12*1/30.,p->height+8,p->height+32);
  } else 
    cam->h=p->height+32;
  cam->x=p->x;
  cam->y=p->y;
  if(p->stare_at) {
    //We are dead(?) and looking at who killed us
    angle=FArg(p->stare_at->x-cam->x,p->stare_at->y-cam->y);
    cam->angle=(cam->angle+angle)/2;
  } else {
    cam->angle=p->angle;
  }
}


PlayerMove(l,p,0);

Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
WinMax;
U0 InitLevel(CDoomLevel *l) {
  CDoomThing *t,*head=&l->things;
  CDoomSector *s;
  for(t=head->next;t!=head;t=t->next) {
    if(s=GetSectorForCoord(l,t->x,t->y))
      t->height=s->floor_height;
  }
  InitMonsters(l);
}
InitLevel(l);
try {
  while(TRUE) {

    DCFill;
    UpdateCameraFromPlayer(&cam,p);

    DrawDoomWorld(&cam,l,gr.dc);
    ST_Start(p);

    //mouse camera pan.
    cursor_x=ms.pos.x;
    if(cursor_tx!=cursor_x)
      {
      if(cursor_x<1)
        {
        cursor_x=1;
      }
      cursor_x=ms.pos.x;   
      cursor_tx = cursor_x;


    }

    if(p->health>0.) {
      if(Bt(kbd.down_bitmap,SC_CURSOR_UP)||Bt(kbd.down_bitmap,Char2ScanCode('w')))
        {
        p->running=Bt(kbd.down_bitmap,SC_SHIFT);
        PlayerMove(l,p,1);
        UpdateCameraFromPlayer(&cam,p);
        ST_Key(0);
      }
      if(Bt(kbd.down_bitmap,SC_CURSOR_DOWN)||Bt(kbd.down_bitmap,Char2ScanCode('s'))) {
        p->running=Bt(kbd.down_bitmap,SC_SHIFT);
        PlayerMove(l,p,-1);
        UpdateCameraFromPlayer(&cam,p);
        ST_Key(0);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('q'))) {
        MoveInLevel(l,&cam.x,cam.angle+90,-GRID_SZ/4,16,cam.h-90);
        PlayerMove(l,p,-GRID_SZ/4);
        ST_Key(0);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('e'))) {
        MoveInLevel(l,&cam.x,cam.angle-90,-GRID_SZ/4,16,cam.h-90);
        PlayerMove(l,p,-GRID_SZ/4);
        ST_Key(0);
      }
      if(Bt(kbd.down_bitmap,SC_CURSOR_LEFT)||Bt(kbd.down_bitmap,Char2ScanCode('a'))) {
        p->angle-=pi/16.;
        ST_Key(2);
      }
      if(Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)||Bt(kbd.down_bitmap,Char2ScanCode('d'))) {
        p->angle+=pi/16.;
        ST_Key(1);
      }
      if(!Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)&&!Bt(kbd.down_bitmap,SC_CURSOR_LEFT)) {
        ST_Key(0);
      }
      if(ms.lb) {
        ST_Fire(p);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('1'))) {
        SwapWeapon(p,0);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('2'))) {
        SwapWeapon(p,1);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('3'))) {
        SwapWeapon(p,2);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('4'))) {
        SwapWeapon(p,3);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('5'))) {
        SwapWeapon(p,4);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('6'))) {
        SwapWeapon(p,5);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('7'))) {
        SwapWeapon(p,6);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode('8'))) {
        SwapWeapon(p,7);
      }
      if(Bt(kbd.down_bitmap,Char2ScanCode(' ')&0xff)) {
        PressAWall(l,&p->x,p->angle,p->height);
      }
    }
    if(Bt(kbd.down_bitmap,Char2ScanCode('\n')&0xff)) {
      DCFill;
      ST_Exit();
      break;
    }
    UpdateLevel(l);
    Refresh;
  }} catch PutExcept(TRUE);
DCFill;
#endif
