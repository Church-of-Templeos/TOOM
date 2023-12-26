#ifndef DOOM_MAIN
#define DOOM_MAIN "Doom" 
#exe {Cd(__DIR__);};;
#ifndef PrintI 
U0 PrintI(U8*,I64) {}
U0 PrintF(U8*,F64) {}
U0 DbgPrint(U8*,...) {}
#endif
#ifndef MemSetI64
#define MemSetI64 MemSetU64
#endif
#include "Serialize.HC";
#include "FastTrig.HC";
#include "Wad.HC";
#include "Intermission.HC";
CTask *doom_task=Fs;
#include "Thinker.HC";
#include "Music.HC";

#define MUZZLE_FLASH_LIGHT 50

extern U0 DamageMob(CDoomLevel *l,CDoomThing *target,CDoomThing *opp,F64 damage);
extern CDoomThing **GetCrushedThingsInSector(CDoomLevel *l,CDoomSector *s);
#define mp_cnt 1 //Reduces flickering
F64 ray_cast_table_cos[GR_WIDTH/2];
F64 ray_cast_table_sin[GR_WIDTH/2];
Bool paused = FALSE,gameExit=FALSE;
F64 time_offset=0,base_tS=tS;
F64 paused_at=0;
F64 Server_tS() {
  if(paused) {
    return paused_at;
  }
  paused_at=tS-base_tS+time_offset;
  return paused_at;
}
U0 Unpause(F64 to=-1) {
  base_tS=tS;
  if(to<0)
    time_offset=paused_at;
  else
    time_offset=to;
  paused_at=time_offset;
  paused=FALSE;
}
#include "Lighting.HC";
class CJobRunnerData {
  U0 (*fptr)(U8*);
};

CDC *doom_scrn=gr.dc;
doom_scrn->flags|=DCF_NO_TRANSPARENTS;
I64 doom_scrn_in_draw=0;
CDoomSector *GetSectorForCoord(CDoomLevel *level,I64 x,I64 y) {
  CDoomSubsector *ss;
  CDoomBSPNode *node=DoomWhichBSPNode(x,y,level,&ss);
  if(ss) {
    return ss->sector;
  }
  return NULL;
}

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
//rad_suit_time is the time remaining(same for bezerk_time) in ticks
  F64 armor,rad_suit_time,bezerk_time,last_attack;
//These are used for screen palete effects
  F64 hurt_amt,pickup_amt;
  F64 muzzle_flash_end_tS;
//When you die,the player stares at the thing that killed the player
  CDoomThing *stare_at;
  GunAvail arsenal[8];
  Bool running,made_a_sound,has_backpack;
} *p=NULL;

//IMPORTANT
CacheAnimationFrames;

I64 cursor_x = ms.pos.x, cursor_tx = ms.pos.x;

class CVisplane {
  I64 color;
  I64 fminx,fmaxx; //floor
  I64 cminx,cmaxx; //ceil
  I64 fminy,fmaxy; //floor
  I64 cminy,cmaxy; //ceil
  CDoomSector *sector;
//Farthest are per x
  I32 sector_limits[GR_WIDTH/2]; 
};

I64 class CWallCommand {
  I16 start,end;
  I32 dist;
  CDoomLinedef *ld;
};


class CDoomCamera {
  F64 x,y,h;
  F64 angle,fov;
//Private
//These are used for rejecting places to draw
  I64 wall_command_cnts[GR_WIDTH/2];
  CWallCommand wall_commands[GR_WIDTH/2][0x80];
  //These include the wall heights too
  //Cordnates are diveded by 2
  F64 floor_heights[GR_WIDTH/2]; //used for choosing which things not to draw
  F64 ceil_heights[GR_WIDTH/2]; //used for choosing which things not to draw
  F64 floor_depths[GR_WIDTH/2];
  F64 wall_depths[GR_WIDTH/2]; //Absolute blocking walls
  CDC *floor_dc; //This is black or white,this is used for reducing floor overdraw
  I64 visplane_cnt;
  CVisplane visplanes[256];
} cam;
cam.fov=pi/4;

I64 IsBlockedByWall(CDoomCamera *cam,I64 x,I64 y,I64 dist) {
  I64 i,cnt=cam->wall_command_cnts[x>>1];
  CWallCommand *cmd=cam->wall_commands[x>>1];
  for(i=0;i!=cnt;i++,cmd++) {
    if(cmd->dist<=dist) {
      if(cmd->start<y<cmd->end) {
	return cmd->end-y;
      }
    }
  }
  return 0;
}

I64 IsBlockedByWallReverse(CDoomCamera *cam,I64 x,I64 y,I64 dist) {
  I64 i,cnt=cam->wall_command_cnts[x>>1];
  CWallCommand *cmd=cam->wall_commands[x>>1];
  for(i=0;i!=cnt;i++,cmd++) {
    if(cmd->dist<=dist) {
      if(cmd->start<y<cmd->end) {
	return y-cmd->start;
      }
    }
  }
  return 0;
}


U0 InsertVisplane(CDoomCamera *cam,CDoomSector *s) {
  I64 cnt=cam->visplane_cnt;
  CVisplane *vp;
  if(cnt<255) {
    vp=&cam->visplanes[cnt];
    vp->fminx=GR_WIDTH;
    vp->fminy=GR_HEIGHT;
    vp->fmaxy=0;
    vp->fmaxx=0;
    vp->cminx=GR_WIDTH;
    vp->cminy=GR_HEIGHT;
    vp->cmaxy=0;
    vp->cmaxx=0;
    vp->sector=s;
    vp->color=cnt+1;
    s->visplane_idx=cnt;
    cam->visplane_cnt++;
    MemSetU32(vp->sector_limits,I32_MAX,GR_WIDTH/2);
  }
}
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
I64 F64SortRev(F64 a,F64 b) {
  if(a<b) return 1;
  if(a>b) return -1;
  return 0;
}
I64 F64Sort(F64 a,F64 b) {
  if(a>b) return 1;
  if(a<b) return -1;
  return 0;
}


U0 DrawTexturedFlat(CDoomLevel *l,CDC *to_dc,CDoomCamera *cam,CDoomSector *sector,F64 at,CDC *texture,Bool floor=TRUE) {
  if(!texture) return;
  if(GetFlatDC("F_SKY1")==texture) return;
  F64 *intersects=MAlloc((sector->linedef_cnt+1)*8);
  Bool in_sector=GetSectorForCoord(l,cam->x,cam->y)==sector;
  I64 x,y;
  I64 plane=sector->visplane_idx;
  I64 floorx,floory;
  I32 *db_z;
  U16 *dst;
  U32 color;
  I64 maxx,maxy;
  I64 minx,miny,idist,dir,from,to,skip,hit_cnt;
  I64 consec_y,idx;
  I64 wx,wy;
  F64 dist,angle;
  F64 cos2;
  U8 *already;
  CD2 ray,hit;
  CDoomLinedef*ld;
  static F64 last_angle=I16_MAX; //Not possible to start with this angle
  static F64 cos_table[GR_WIDTH/2];
  static F64 sin_table[GR_WIDTH/2];
  if(last_angle!=cam->angle) {
    for(x=0;x!=GR_WIDTH/2;x++) {
      angle=(ToF64(x*2)-GR_WIDTH/2)/(GR_WIDTH/2)*(cam->fov/2);
      sin_table[x]=Sin(cam->angle+angle);
      cos_table[x]=Cos(cam->angle+angle);
    }
    last_angle=cam->angle;
  }
  CVisplane *vp=&cam->visplanes[plane];
  if(floor) {
    miny=vp->fminy>>1;
    maxy=vp->fmaxy>>1;
    minx=vp->fminx>>1;
    maxx=vp->fmaxx>>1;
  } else {
    minx=vp->cminx>>1;
    maxx=vp->cmaxx>>1;
    miny=vp->cminy>>1;
    maxy=vp->cmaxy>>1;
  }
//https://www.doomworld.com/forum/topic/102392-the-definitive-guide-to-visplanes/
  minx=minx-1;
  if(minx<0) minx=0;
  maxx=maxx+1;
  if(maxx>GR_WIDTH/2) maxx=GR_WIDTH/2;
  for(x=minx;x<maxx;x++) {
    ray.x=cos_table[x]*I16_MAX+cam->x;
    ray.y=sin_table[x]*I16_MAX+cam->y;
    cos2=ray_cast_table_cos[x];
    hit_cnt=0;
    if(floor)
      intersects[hit_cnt++]=GR_HEIGHT/2;
    else
      intersects[hit_cnt++]=0;
    for(skip=0;skip!=sector->linedef_cnt;skip++) {
      ld=sector->linedefs[skip];
      if(PlaneIntersect(&hit,ld->start,ld->end,&cam->x,&ray)) {
        dist=Sqrt(Sqr(hit.x-cam->x)+Sqr(hit.y-cam->y));
        dist*=cos2;
        dist=(((DIST_SCALE/dist)*(cam->h-at))+GR_HEIGHT/2)/2;
        dist=Clamp(dist,0,GR_HEIGHT/2);
        intersects[hit_cnt++]=dist;
already_has:;
      }
    } 
    if(floor) //Most bottom point is good to start at
      QSortI64(intersects,hit_cnt,&F64SortRev); 
    else //Most top point is good to stop at
      QSortI64(intersects,hit_cnt,&F64Sort);
    if(!hit_cnt)
      goto next3;
    for(idx=hit_cnt-2;idx>=0;idx--) {
      if(floor)  {
//Reverse sorted
        from=intersects[idx];
        to=intersects[idx+1];
        dir=-1;
      } else{
//Forward sorted
        from=intersects[idx];
        to=intersects[idx+1];
        dir=1;
      }
      dist=DIST_SCALE/((ToF64(ToF64(to+from)/2.*2.)-GR_HEIGHT/2)/(cam->h-at));
      wx=cam->x+(dist/cos2)*cos_table[x];
      wy=cam->y+(dist/cos2)*sin_table[x];
      if(GetSectorForCoord(l,wx,wy)!=sector) {
        goto next2;
      }
      for(y=from;(dir==1&&y<to)||(dir==-1&&y>to);y+=dir) {
        if(y<0) {
	  y=0-dir;
	  if(dir==-1)
	    break;
	  goto next;
        }
        if(y>=GR_HEIGHT/2) {
	  y=GR_HEIGHT/2-1-dir;
	  if(dir==1)
	    break;
	  goto next;
        }
        dist=DIST_SCALE/((ToF64(y*2)-GR_HEIGHT/2)/(cam->h-at));
        idist=dist;
        db_z=&to_dc->depth_buf[GR_WIDTH-2-x*2+y*2*to_dc->width_internal];
        already=cam->floor_dc->body+y*cam->floor_dc->width_internal+x;
        if(!floor) {
	  if(skip=IsBlockedByWall(cam,x*2,y*2,idist)) {
	    y+=skip>>1-1;
	    goto next;
	  }
        } else {
	  if(skip=IsBlockedByWallReverse(cam,x*2,y*2,idist)) {
	    y-=skip>>1+1;
	    goto next;
	  }
        }
        if(*already)
	  goto next;
        if(cam->wall_depths[x]<idist)
	  goto next2;
        if(idist>*db_z)
	  goto next;
        wx=cam->x+(dist/cos2)*cos_table[x];
        wy=cam->y+(dist/cos2)*sin_table[x];
        dst=&to_dc->body[GR_WIDTH-2-x*2+y*2*to_dc->width_internal];
        *already=TRUE;
        db_z[0]=idist;
        db_z[1]=idist;
        db_z+=to_dc->width_internal;
        db_z[0]=idist;
        db_z[1]=idist;
        db_z-=to_dc->width_internal;
        floorx=(wx<<1)&127; //In doom flats are 64,(*2 for dither super pixel)
        floory=(wy<<1)&127;
        floorx&=~1;
        floory&=~1;
	if(Server_tS<p->muzzle_flash_end_tS)
	  color=LookupLighting(texture->body[floorx+floory*128](U16),sector->cur_light_level+MUZZLE_FLASH_LIGHT,dist);
	else
          color=LookupLighting(texture->body[floorx+floory*128](U16),sector->cur_light_level,dist);
        *dst=color&0xffff;
        dst(U8*)+=to_dc->width_internal;
        *dst=color>>16;
        dst(U8*)-=to_dc->width_internal;
next:;
      }
next2:;
    } 
next3:;
  }
  Free(intersects);
}


U0 PopulateTables() {
  I64 inc=0;
  F64 angle=-cam.fov/2;
  for(inc=0;inc!=GR_WIDTH/2;inc++) {
    ray_cast_table_cos[inc]=Cos(angle);
    ray_cast_table_sin[inc]=Sin(angle);
    angle+=cam.fov/GR_WIDTH*2;
  }
}
PopulateTables;
//floor is 0 for floor
//floor is 1 for middle
//floor is 2 for ceil
//floor is 3 if visplane only
U0 RayCastWall(CDC *to_dc,CDC *texture,CD2 *st,CD2 *en,CDoomCamera *cam,I64 level,I64 height,I64 flrh,I64 ceilh,U8 floor,CDoomLinedef *ld,CDoomSidedef *sd) {
  I64 light=sd->sector->cur_light_level;
  if(ld->front==sd&&ld->back)
    light=MaxI64(light,ld->back->sector->cur_light_level);
  if(ld->back==sd&&ld->front)
    light=MaxI64(light,ld->front->sector->cur_light_level);
  if(Server_tS<p->muzzle_flash_end_tS)
    light+=MUZZLE_FLASH_LIGHT;
  CD2 clone_st,clone_en,zero;
  clone_st.x=st->x,clone_st.y=st->y;
  clone_en.x=en->x,clone_en.y=en->y;
  zero.x=0.,zero.y=0.;
  TransformPointToCamera(cam,&clone_st);
  TransformPointToCamera(cam,&clone_en);
  st=&clone_st;
   en=&clone_en;
  F64 start_angle=FArg(st->x,st->y);
  F64 end_angle=FArg(en->x,en->y),tmp,tyf;
  F64 margin;
  CD2 ray,hit,*sw;
  I64 ix,iy,ih=0,tx,ty,ih2,xoff=sd->xoff-texture->x,yoff=sd->yoff-texture->y,ex,dir,skip;
  CVisplane *vp;
  I32 *db_z,idist;
  U32 dither_px;
  CWallCommand *wall_cmd;
  F64 dist,ratio;
  Bool repeat=FALSE,onesided=ld->front^^ld->back;
  Bool is_sky=FALSE,is_sky2=FALSE,clipped=FALSE,recompute_ty;
  I64 low_ih,high_ih;
  CDoomSidedef *opposite;
  U16 *color,*to;
  CDoomScroller1 *scroll1;
  if(ld->special_type&&ld->special_type->type=='Scroll1'&&sd==ld->front) {
    scroll1=ld->special_type;
    if(scroll1->x)
      xoff+=Server_tS*30*scroll1->x;
    else if(scroll1->offset_type) {
      yoff=yoff*Server_tS*30;
      xoff=xoff*Server_tS*30;
    }
  }
  if(ld->front==sd)
    opposite=ld->back;
  else
    opposite=ld->front;
  if(opposite)
    is_sky=opposite->sector->ceil_dc[0]==GetFlatDC("F_SKY1")&&floor==2;
  if(is_sky) return;
  if(onesided)
    is_sky2=sd->sector->ceil_dc[0]==GetFlatDC("F_SKY1");
  start_angle=Wrap(start_angle);
  end_angle=Wrap(end_angle);
//Angles are strange so i will just assume whole range if out of bound
  if(!(-cam->fov/2<start_angle<cam->fov/2)||!(-cam->fov/2<end_angle<cam->fov/2)) {
    clipped=TRUE;
    if(-cam->fov/2<start_angle<cam->fov/2) {
      end_angle=Sign(st->x*en->y-st->y*en->x)*cam->fov/2.;
    } else if(-cam->fov/2<end_angle<cam->fov/2) {
      start_angle=Sign(en->x*st->y-en->y*st->x)*cam->fov/2.;
    } else {
      start_angle=-cam->fov/2;
      end_angle=cam->fov/2;
    }
  }
  repeat=TRUE;
  ix=GR_WIDTH/2.+start_angle/(cam->fov/2.)*GR_WIDTH/2.;
  ix&=~1;
  ex=GR_WIDTH/2.+end_angle/(cam->fov/2.)*GR_WIDTH/2.;
  ex&=~1;
  if(ix<ex)
    dir=2;
  else
    dir=-2;
  for(;ix!=ex;ix+=dir) {
    ray.x=I16_MAX*ray_cast_table_cos[ix/2];
    ray.y=I16_MAX*ray_cast_table_sin[ix/2]; 
    if(PlaneIntersect(&hit,&ray,&zero,st,en)) {
      dist=Sqrt(Sqr(hit.x)+Sqr(hit.y));
      idist=dist;
      if(dist<=0.) dist=1;
      if(cam->wall_depths[ix>>1]<idist)
        goto next;
      tx=(ToI64(Sqrt(Sqr(hit.x-st->x)+Sqr(hit.y-st->y)))*2+xoff*2)%texture->width;
//The offset from the ground is included in the "height",we dont render the overdraw
      margin=DIST_SCALE/(dist*ray_cast_table_cos[ix/2])*(cam->h-level);
      ih=DIST_SCALE/(dist*ray_cast_table_cos[ix/2])*height;
      ih&=~1;
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
      if(floor==3) { //If a "visplane" draw
        if(0<=ix<=GR_WIDTH-2) {
	  vp=&cam->visplanes[sd->sector->visplane_idx];
          if(vp->sector_limits[ix>>1]<idist||vp->sector_limits[ix>>1]==I32_MAX)
	    vp->sector_limits[ix>>1]=idist;
	  for(ty=0;ty!=2;ty++) {
	    if(!ty)
	      ih2=0;
	    else
	      ih2=ih;
	    xoff=ClampI64(ix,0,GR_WIDTH-2);
	    yoff=ClampI64(iy+ih2,1,GR_HEIGHT-2);
	    if(ty) { //Y grows down
//If our line is partialy behind the camera,we draw the floor from GR_HEIGHT
	      if(clipped)
	        vp->fmaxy=GR_HEIGHT;
	      if(xoff<vp->fminx)
	        vp->fminx=xoff;
	      if(xoff>vp->fmaxx)
	        vp->fmaxx=xoff;

	      if(yoff<vp->fminy)
	        vp->fminy=yoff;
	      if(yoff>vp->fmaxy)
	        vp->fmaxy=yoff;

	    } else {
//If our line is partialy behind the camera,we draw the ceil from 0
	      if(clipped)
	        vp->cminy=0;
	      if(xoff<vp->cminx)
	        vp->cminx=xoff;
	      if(xoff>vp->cmaxx)
	        vp->cmaxx=xoff;

	      if(yoff<vp->cminy)
	        vp->cminy=yoff;
	      if(yoff>vp->cmaxy)
	        vp->cmaxy=yoff;
	    }
	  }
        }
        goto next;
      }
      if(0<=ix<=GR_WIDTH-2) {
        if(idist<cam->floor_depths[ix/2]) {
	  cam->floor_heights[ix/2]=GR_HEIGHT;
	  cam->ceil_heights[ix/2]=0;
	  cam->floor_depths[ix/2]=idist;
        }
        ih2+=2;
        if(is_sky2&&!is_sky) {//Fill in upper pixels Z-buf distance with distnce for sky
	  ty=ClampI64(iy,GR_HEIGHT-2,0);
	  while(ty>=0) {
	    db_z=&to_dc->depth_buf[GR_WIDTH-2-ix+ty*to_dc->width_internal];
	    to=&to_dc->body[GR_WIDTH-2-ix+ty*to_dc->width_internal];
	    if(*db_z>idist) {
	      db_z[0]=idist+1; //+1 so walls are drawn before the sky
	      db_z[1]=idist+1;
	      *to=TRANSPARENT|TRANSPARENT<<8;
	      db_z+=to_dc->width_internal;
	      to(U8*)+=to_dc->width_internal;
	      db_z[0]=idist+1;
	      db_z[1]=idist+1;
	      *to=TRANSPARENT|TRANSPARENT<<8;
	    }
	    ty-=2;
	  }
        }
        if(is_sky) {
	  ih2=ClampI64(ih2+iy,0,GR_HEIGHT-2);
	  while(ih2>=0) {
	    db_z=&to_dc->depth_buf[GR_WIDTH-2-ix+ih2*to_dc->width_internal];
	    to=&to_dc->body[GR_WIDTH-2-ix+(iy+ih2)*to_dc->width_internal];
	    if(*db_z>idist) {
	      db_z[0]=idist;
	      db_z[1]=idist;
	      *to=TRANSPARENT|TRANSPARENT<<8;
	      db_z+=to_dc->width_internal;
	      to(U8*)+=to_dc->width_internal;
	      db_z[0]=idist;
	      db_z[1]=idist;
	      *to=TRANSPARENT|TRANSPARENT<<8;
	    }
	    ih2-=2;
	  }
        } else {
	  tx=ClampI64(AbsI64(tx),0,texture->width-2);
	  tx&=~1;
	  low_ih=MaxI64(cam->ceil_heights[ix>>1]-iy,0);
	  ih2=low_ih;
//https://doomwiki.org/wiki/Texture_alignment
	  if(repeat) {
	    if(onesided) {
//Dont ask nroot how any of this works,he typed in random stuff
	      if(ld->flags&WAD_LINEDEFF_LOWER_UNPEGGED) {
	        tyf=(ih2*ratio+yoff+texture->height-1-ratio*ih)*2;
	      } else {
	        tyf=(ih2*ratio+yoff-sd->sector->door_height_offset)*2;
	      }
	    } else {
	      if(floor==0) {
	        if(ld->flags&WAD_LINEDEFF_LOWER_UNPEGGED) {
		  tyf=(ih2*ratio+yoff+texture->height-1-ratio*ih+ceilh-flrh)*2;
	        } else {
		  tyf=(ih2*ratio+yoff-sd->sector->door_height_offset)*2;
	        }
	      } else{
	        if(!(ld->flags&WAD_LINEDEFF_UPPER_UNPEGGED)) {
		  tyf=(ih2*ratio+yoff+texture->height-1-ratio*ih-sd->sector->door_height_offset)*2;
	        } else {
		  tyf=(ih2*ratio+yoff-sd->sector->door_height_offset)*2;
	        }
	      }
	    }
	  } else {
	    tyf=(ToF64(ih2)/ih)*(texture->height-2);
	  }

          wall_cmd=&cam->wall_commands[ix>>1][cam->wall_command_cnts[ix>>1]];
	  wall_cmd->ld=ld;
	  wall_cmd->end=0;
	  wall_cmd->start=GR_HEIGHT;
	  wall_cmd->dist=idist;
	  for(ih2=low_ih;TRUE;ih2+=2,tyf+=2*ratio*2) { //2 for dither pixel,2 for ih2+=2
	    if(ih2>=ih||ih2+iy>=GR_HEIGHT-2)
	      break;
	    if(idist>cam->floor_depths[ix/2]) {
	      if(iy+ih2>=cam->floor_heights[ix/2]) {
	        break;
	      } else if(iy+ih2<cam->ceil_heights[ix/2]) {
	        ih2=cam->ceil_heights[ix/2]-iy;
	        goto skip_p;
	      }
	    }
	    if((skip=IsBlockedByWall(cam,ix,iy+ih2,idist))>2) {
	      tyf+=2*ratio*(skip-2); //*2 for dither super pixel
	      ih2+=skip-2;
	      goto skip_p;
	    }
	    wall_cmd->start=MinI64(wall_cmd->start,iy+ih2);
	    wall_cmd->end=MaxI64(wall_cmd->end,iy+ih2);
	    if(floor==0)
	     wall_cmd->end=GR_HEIGHT/2; //All the way down(we dont need to drawn benith the floor)
	    if(floor==2)
	     wall_cmd->start=0; //All the way up(We dont need to draw past the ceiling)
	    ty=tyf;
	    if(repeat)
	      ty=ty%texture->height;
	    if(ty<0) ty=-ty;
	    ty=ClampI64(ty,0,texture->height-2);
	    ty&=~1;
	    color=texture->body[tx+ty*texture->width_internal](U16);
	    dither_px=LookupLighting(color,light,dist);
	    to=&to_dc->body[GR_WIDTH-2-ix+(iy+ih2)*to_dc->width_internal];
	    db_z=&to_dc->depth_buf[GR_WIDTH-2-ix+(iy+ih2)*to_dc->width_internal];
	    if(*db_z>idist) {
	      if(color&0xff!=TRANSPARENT) {
	        db_z[0]=idist;
	        db_z[1]=idist;
	        db_z+=to_dc->width_internal;
	        db_z[0]=idist;
	        db_z[1]=idist;
	        *to=dither_px&0xffff;
	        to(U8*)+=to_dc->width_internal;
	        *to=dither_px>>16;
	      }
	    }
skip_p:;
	  }
        }
	if(wall_cmd->start<wall_cmd->end&&(texture->flags&DCF_NO_TRANSPARENTS)) {
	  if(tx=cam->wall_command_cnts[ix>>1]) {
	    if(cam->wall_command_cnts[tx-1]!=*wall_cmd) { //CWallCommand is I64
              cam->wall_command_cnts[ix>>1]++;
	    }
	  } else
            cam->wall_command_cnts[ix>>1]++;
	}
      }
      if(texture->flags&DCF_NO_TRANSPARENTS) {
        if(!is_sky) {
	  if(0) {
set_floor_height:
	    if(floor==0)  {
	      cam->floor_heights[ix/2]=ClampI64(iy,0,GR_HEIGHT);
	      cam->ceil_heights[ix/2]=0;
	    } else if(floor==1) {
	      cam->ceil_heights[ix/2]=GR_HEIGHT;
	      cam->floor_heights[ix/2]=0;
	    } else if(floor==2) {
	      cam->floor_heights[ix/2]=GR_HEIGHT;
	      cam->ceil_heights[ix/2]=ClampI64(iy+ih,0,GR_HEIGHT);
	    }
	    cam->floor_depths[ix/2]=idist;
	  } else if(cam->floor_depths[ix/2]>=idist) {
	    goto set_floor_height;
	  }
	  if(floor==1) 
	    if(cam->wall_depths[ix/2]>idist)
	      cam->wall_depths[ix/2]=idist;
        }
      }
    }
next:;
  }
}
class CRayJobData:CJobRunnerData {
  CDC *to_dc,*texture;
  CD2 *st,*en;
  CDoomCamera *cam;
  I64 level,height,flrh,ceilh,floor;
  CDoomLinedef *ld;
  CDoomSidedef *sd;
};
U0 RayCastJob(CRayJobData *data) {
  RayCastWall(
	data->to_dc,data->texture,data->st,data->en,data->cam,
	data->level,
	data->height,
	data->flrh,
	data->ceilh,
	data->floor,
	data->ld,
	data->sd
	);
  Free(data);
}
U0 QueRayCastJob(CDC *to_dc,CDC *texture,CD2 *st,CD2 *en,CDoomCamera *cam,I64 level,I64 height,I64 flrh,I64 ceilh,U8 floor,CDoomLinedef *ld,CDoomSidedef *sd) {
  CRayJobData *j=CAlloc(sizeof(CRayJobData),adam_task);
  j->to_dc=to_dc;
  j->texture=texture;
  j->st=st;
  j->en=en;
  j->cam=cam;
  j->height=height;
  j->level=level;
  j->flrh=flrh;
  j->ceilh=ceilh;
  j->floor=floor;
  j->ld=ld;
  j->sd=sd;
  j->fptr=&RayCastJob;
  RayCastJob(j);
}
U0 PlotSpriteIn3DSpace(CDC *to_dc,F64 height,CDC *sprite,CDoomCamera *cam,CD2 *_p,F64 level,Bool reflect=FALSE,Bool transparent=FALSE,I64 light=255) {
  if(!sprite) return;
  CD2 copy,copy2;
  F64 new_height,new_width,angle;
  I64 x,y,tox,fromx,toy,fromy,ix,iy,dist,best_color;
  U16 *from,*dst,black=BLACK|BLACK<<8,trans_pixel=TRANSPARENT|TRANSPARENT<<8;
  U32 dither_px;
  I32 *db_z;
  copy.x=_p->x,copy.y=_p->y;
  copy2.x=_p->x,copy2.y=_p->y;
  if(!ClipLineToScrenCoords(cam,&copy,&copy2,level))
    return;
  angle=(ToF64(copy.x)-GR_WIDTH/2)/(GR_WIDTH/2)*(cam->fov/2);
  angle=Clamp(angle,-cam->fov/2,cam->fov/2);
  dist=Sqrt(1+Sqr(_p->x-cam->x)+Sqr(_p->y-cam->y));
  new_height=DIST_SCALE/(ToF64(1+dist)*FCos(angle))*sprite->height/2;
  new_width=new_height/sprite->height*sprite->width;
  fromx=copy.x-new_width/2;
  tox=ClampI64(copy.x+new_width/2,0,GR_WIDTH-2);;
  fromy=copy.y-new_height;
  toy=ClampI64(copy.y,0,GR_HEIGHT-2);
//&~1 aligns to 2 for dithering super pixels
  fromy&=~1;
  toy&=~1;
  fromx&=~1;
  tox&=~1;
  for(y=fromy;y<toy;y+=2) {
    if(y<0) y=0;
    if(y>toy) break;
    for(x=fromx;x<tox;x+=2) {
      if(x<0) x=0;
      if(x>tox) break;
      db_z=&to_dc->depth_buf[GR_WIDTH-2-x+y*to_dc->width_internal];
      if(*db_z>dist) {
        if(!reflect)
	  ix=Lerp((x-fromx)/new_width,0,sprite->width-2);
        else
	  ix=Lerp((x-fromx)/new_width,sprite->width-2,0);
        iy=Lerp((y-fromy)/new_height,0,sprite->height-2);
        from=&sprite->body[(ix&~1)+(iy&~1)*sprite->width_internal];
        if(transparent) {
	  if(RandU16<ToI64(0x10000*.75)) {
	    if(*from!=trans_pixel)
	      from=&black;
	    else
	      from=&trans_pixel;
	  } else
	    from=&trans_pixel;
        }
        dst=&to_dc->body[GR_WIDTH-2-x+y*to_dc->width_internal];
       if(Server_tS<p->muzzle_flash_end_tS)
	  dither_px=LookupLighting(*from,light*ray_cast_table_cos[ix/2],dist);
	else
	  dither_px=LookupLighting(*from,light,dist);
        if(from->u8[0]!=TRANSPARENT)
	  *dst=dither_px&0xffff,*db_z=dist,db_z[1]=dist;
        dst(U8*)+=to_dc->width_internal;
        db_z+=to_dc->width_internal;
        if(from->u8[0]!=TRANSPARENT)
	  *dst=dither_px>>16,*db_z=dist,db_z[1]=dist;
      }
nextx:;
    }
  }
}


U0 DrawAThing(CDC *to_dc,CDoomThing *thing,CDoomCamera *cam) {
  if(!thing->template) return; //???
  if(thing->template==doom_thing_types[1]) return; //Dont render player
  if(!thing->animation) thing->animation=thing->template->_animation;
  if(!thing->animation) return; //???
  I64 anim_frame=(Server_tS-thing->anim_start_tS)*4,frame_cnt,face;
  if(anim_frame<0) anim_frame=0;
  F64 angle,gap;
  CDoomSector *sec;
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
  for(gap=-2.*pi/8./2;gap<2*pi;gap+=2.*pi/8.) {
    if(gap<=angle<=gap+2.*pi/8.)
      break;
    face++;
  }
  if(face>8)
    face=8;
  reflect=thing->animation[anim_frame].reflect[face-1];
  sprite=thing->animation[anim_frame].faces[face-1];
  sec=GetSectorForCoord(l,thing->x,thing->y);
  p.x=thing->x,p.y=thing->y;
  if(sec) {
    if(thing->template==doom_thing_types[58]) { //Spectre
      PlotSpriteIn3DSpace(to_dc,thing->template->height,sprite,cam,&p,thing->height,reflect,TRUE,sec->cur_light_level); //TRUEfor transparent
    } else if(sprite)
      PlotSpriteIn3DSpace(to_dc,thing->template->height,sprite,cam,&p,thing->height,reflect,,sec->cur_light_level);
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
  I64 t=ToI64(Server_tS*4)%FrameCnt(s->middle_texture);
  return s->middle_texture[t];
}

CDC *GetUpperTexture(CDoomSidedef *s) {
  if(!s->upper_texture[0]) return NULL;
  I64 t=ToI64(Server_tS*4)%FrameCnt(s->upper_texture);
  return s->upper_texture[t];
}

CDC *GetLowerTexture(CDoomSidedef *s) {
  if(!s->lower_texture[0]) return NULL;
  I64 t=ToI64(Server_tS*4)%FrameCnt(s->lower_texture);
  return s->lower_texture[t];
}
U0 DrawSubsector(CDC *to_dc,CDoomCamera *cam,CDoomSubsector *ss) {
  CD2 start_floor,start_ceil;
  CD2 end_floor,end_ceil;
  I64 seg_idx,wall,fail_cnt;
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
    if(!sidedef) {
      goto skip;
    }
    sector=sidedef->sector;
    highest_ceil=HighestCeil(seg->linedef,sector);
    for(wall=0;wall!=4;wall++) {
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
        h=Abs(start_floor.y-start_ceil.y);
        h2=Abs(end_ceil.y-end_floor.y);
        if(ToI64(h)&&ToI64(h2)) {
	  if(fail_cnt!=2) {
	    if(!sector->drawn) {
	      sector->drawn=TRUE;
	      InsertVisplane(cam,sector);
	    }
	    if(opposite&&opposite->sector&&!opposite->sector->drawn) {
	      opposite->sector->drawn=TRUE;
	      InsertVisplane(cam,opposite->sector);
	    }
	    if(!no_draw) {
	      if(seg->back_side)
	        QueRayCastJob(to_dc,texture,seg->end,seg->start,cam,floor,ceil-floor,sector->floor_height,highest_ceil,wall,seg->linedef,sidedef);
	      else
	        QueRayCastJob(to_dc,texture,seg->start,seg->end,cam,floor,ceil-floor,sector->floor_height,highest_ceil,wall,seg->linedef,sidedef);
	      if(wall==3&&opposite&&opposite->sector) {
	        sector=opposite->sector;
	        sidedef=opposite;
	        floor=sector->floor_height;
	        ceil=sector->ceil_height;
	        QueRayCastJob(to_dc,texture,seg->start,seg->end,cam,floor,ceil-floor,sector->floor_height,highest_ceil,wall,seg->linedef,opposite);
	      }
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
      } else if(wall==3) { //This is for generating visplanes
        texture=gr.dc; //Dummy texture
        floor=sector->floor_height;
        ceil=sector->ceil_height;
        goto draw_wall;
      }
    }
skip:;
  }
}
Bool FrontSide(Vector *v,CD2 *p) {
  return v->data[0]*p->y-v->data[1]*p->x>=0.;
}


//box will either inteserect viewport,or point will be inside of it














$SP,"<1>",BI=1$









Bool HitsBBox(CDoomCamera *cam,CBoundBoxF64 *bbox) {
  F64 x=cam->x,y=cam->y,angle,base;
  Vector *v,*v2;
  Bool ret=FALSE;
  CD2 a,b,c,d,zero,ra,rb;
  zero.x=0,zero.y=0;
  if(InRange(bbox->x,x,bbox->x2))
    if(InRange(bbox->y,y,bbox->y2)) {
      return TRUE;
    }
  ra.x=I16_MAX*Cos(cam->angle-cam->fov/2.);
  ra.y=I16_MAX*Sin(cam->angle-cam->fov/2.);
  rb.x=I16_MAX*Cos(cam->angle+cam->fov/2.);
  rb.y=I16_MAX*Sin(cam->angle+cam->fov/2.);
//Check if points are behind camera
  a.x=bbox->x-x;
  a.y=bbox->y-y;
  b.x=bbox->x2-x;
  b.y=bbox->y-y;
  c.x=bbox->x2-x;
  c.y=bbox->y2-y;
  d.x=bbox->x-x;
  d.y=bbox->y2-y;

  v=CreateVector(2);
  v2=CreateVector(2);
  v2->data[0]=rb.x;
  v2->data[1]=rb.y;
  v->data[0]=ra.x;
  v->data[1]=ra.y;
  if(!FrontSide(v2,&a)&&FrontSide(v,&a))  {
    ret=TRUE;
  } else if(!FrontSide(v2,&b)&&FrontSide(v,&b)) {
    ret=TRUE;
  } else if(!FrontSide(v2,&c)&&FrontSide(v,&c)) {
    ret=TRUE;
  } else if(!FrontSide(v2,&d)&&FrontSide(v,&d)) {
    ret=TRUE;
  } else if(PlaneIntersect(NULL,&a,&b,&zero,&ra)||
	PlaneIntersect(NULL,&b,&c,&zero,&ra)||
	PlaneIntersect(NULL,&c,&d,&zero,&ra)||
	PlaneIntersect(NULL,&d,&a,&zero,&ra)) {
    ret=TRUE;
  } else if(PlaneIntersect(NULL,&a,&b,&zero,&rb)||
	PlaneIntersect(NULL,&b,&c,&zero,&rb)||
	PlaneIntersect(NULL,&c,&d,&zero,&rb)||
	PlaneIntersect(NULL,&d,&a,&zero,&rb)) {
    ret=TRUE;
  }
  DestroyVector(v);
  DestroyVector(v2);
  return ret;
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
    if(HitsBBox(cam,&node->left))
      DrawBSP0(to_dc,cam,node->left_child);
    if(HitsBBox(cam,&node->right))
      DrawBSP0(to_dc,cam,node->right_child);
  } else {
    DestroyVector(vect);
    if(HitsBBox(cam,&node->right))
      DrawBSP0(to_dc,cam,node->right_child);
    if(HitsBBox(cam,&node->left))
      DrawBSP0(to_dc,cam,node->left_child);
  }
  if(node->parent) DrawBSP0(to_dc,cam,node->parent);
  node->visited=FALSE;
}

U0 DrawBSP(CDC *to_dc,CDoomCamera *cam,CDoomLevel *level) {
  DrawBSP0(to_dc,cam,DoomWhichBSPNode(cam->x,cam->y,level));
}

I64 FloorSort(CVisplane *va,CVisplane *vb)  {
  CDoomSector *a=va->sector,*b=vb->sector;
  if(a->floor_height>b->floor_height)
    return -1;
  if(a->floor_height<b->floor_height)
    return 1;
  return 0;
}

I64 CeilSort(CVisplane *va,CVisplane *vb)  {
  CDoomSector *a=va->sector,*b=vb->sector;
  if(a->ceil_height<b->ceil_height)
    return -1;
  if(a->ceil_height>b->ceil_height)
    return 1;
  return 0;
}


U0 DrawSky(CDC *to_dc,CDoomLevel *l,CDoomCamera *cam) {
  CDC *texture;
  switch(l->episode) {
   case 1:
     texture=GetGrLump("SKY1");
   break;
   case 2:
     texture=GetGrLump("SKY2");
   break;
   case 3:
     texture=GetGrLump("SKY3");
   break;
   case 4:
     texture=GetGrLump("SKY4");
   break;
  }
  I64 iy,ix,off=texture->width*cam->angle/pi,tx,ty;
  U16 *to,*from;
  for(iy=0;iy!=GR_HEIGHT;iy+=2) {
    ty=iy/ToF64(GR_HEIGHT)*texture->height;
    if(ty>texture->height-2)
      ty=texture->height-2;
    for(ix=0;ix!=GR_WIDTH;ix+=2) {
      to=&to_dc->body[GR_WIDTH-2-ix+iy*to_dc->width_internal];
      if(*to&TRANSPARENT!=TRANSPARENT)
        goto skip;
      *to=*from;
      tx=(ix+off)/ToF64(GR_WIDTH)*texture->width;
      tx&=~1;
      tx%=texture->width-2;
      tx=AbsI64(tx);
      from=&texture->body[tx+ty*texture->width_internal];
      from(U8*)+=texture->width_internal;
      to(U8*)+=to_dc->width_internal;
      *to=*from;
skip:;
    }
  }
}

U0 WallCmdSort(CWallCommand *a,CWallCommand *b) {  
  if(a->start==b->start) {
    return a->end-b->end;
  }
  return a->start-b->start;
}
Bool WallCmdIsCovered(CWallCommand *others,CWallCommand *wall,I64 cnt) {
  I64 idx;
  Bool visible=FALSE;
  I64 y=ClampI64(wall->start,0,GR_HEIGHT/2),ey=ClampI64(wall->end,0,GR_HEIGHT/2);
  I64 a,b;
  U8 check[GR_HEIGHT/2];
  CWallCommand *other;
  MemSet(check,0,GR_HEIGHT/2);
  MemSet(check+y,TRUE,ey-y);
  for(idx=0;idx!=cnt;idx++) {
    other=&others[idx];
    if(other!=wall&&other->dist<wall->dist) {
      a=ClampI64(other->start,0,GR_HEIGHT/2);
      b=ClampI64(other->end,0,GR_HEIGHT/2);
      MemSet(check+a,FALSE,b-a);
    }
  }
  while(y<ey)
    if(check[y++])
      return FALSE;
  return TRUE;
}
U0 MergeWallCommands(CDoomCamera *cam) {
  I64 i=0,i2,cnt,new_cnt;
  CWallCommand *cmds;
  for(i=0;i!=GR_WIDTH/2;i++) {
    cmds=&cam->wall_commands[i];
    QSort(cmds,cnt=cam->wall_command_cnts[i],sizeof(CWallCommand),&WallCmdSort);
    new_cnt=0;
    for(i2=0;i2!=cnt;i2++) {
      if(WallCmdIsCovered(cmds,&cmds[i2],cnt)) {
        ; //Exclude from result
      } else {
        if(new_cnt!=i2)
	  MemCpy(&cmds[new_cnt],&cmds[i2],sizeof CWallCommand);
        new_cnt++;
      }
    }
    cam->wall_command_cnts[i]=new_cnt;
  }
}
U0 DrawDoomWorld(CDoomCamera *cam,CDoomLevel *level,CDC *to_dc) {
  CDoomSector *sector;  
  CDoomThing *thing;
  CVisplane *sorted[256];
  I64 idx=0,idx2,af,tf;
  LBts(&doom_scrn_in_draw,0);
  cam->visplane_cnt=0;
  if(!cam->floor_dc) {
    cam->floor_dc=DCNew(GR_WIDTH/2,GR_HEIGHT/2);
    DCDepthBufAlloc(cam->floor_dc);
  }
  DCDepthBufRst(cam->floor_dc);
  DCFill(doom_scrn);
  DCFill(cam->floor_dc,BLACK);
  for(sector=level->sectors.next;sector!=&level->sectors;sector=sector->next)
    sector->drawn=FALSE;
  for(idx=0;idx!=GR_WIDTH/2;idx++) {
    cam->floor_heights[idx]=GR_HEIGHT;
    cam->ceil_heights[idx]=0;
    cam->floor_depths[idx]=I16_MAX;
    cam->wall_depths[idx]=I16_MAX;
  }
  MemSetI64(cam->wall_command_cnts,0,GR_WIDTH/2);
  if(!to_dc->depth_buf)
    DCDepthBufAlloc(to_dc);
  else
    DCDepthBufRst(to_dc);
  DrawBSP(to_dc,cam,level);

  MergeWallCommands(cam);

  af=Server_tS*4;
  for(idx2=0;idx2!=cam->visplane_cnt;idx2++) {
    sorted[idx2]=&cam->visplanes[idx2];
  }
  QSortI64(sorted,cam->visplane_cnt,&FloorSort);
  for(idx2=0;idx2!=cam->visplane_cnt;idx2++) {
    sector=sorted[idx2]->sector;
    if(sector->floor_dc)
      if(sector->floor_height<cam->h)
        DrawTexturedFlat(l,to_dc,cam,sector,sector->floor_height,sector->floor_dc[af%FrameCnt(sector->floor_dc)],TRUE);
  }
  QSortI64(sorted,cam->visplane_cnt,&CeilSort);
  for(idx2=0;idx2!=cam->visplane_cnt;idx2++) {
    sector=sorted[idx2]->sector;
    if(sector->ceil_dc) {
      if(sector->ceil_height>cam->h)
        DrawTexturedFlat(l,to_dc,cam,sector,sector->ceil_height,sector->ceil_dc[af%FrameCnt(sector->ceil_dc)],FALSE);
    }
  }
  for(thing=level->things.next;thing!=&level->things;thing=thing->next) {
    sector=GetSectorForCoord(level,thing->x,thing->y);
    if(sector->drawn)
      DrawAThing(to_dc,thing,cam);
  }
  DrawSky(to_dc,l,cam);
  for(idx=0;idx!=GR_WIDTH/2;idx++) {
    for(idx2=0;idx2!=cam->wall_command_cnts[idx];idx2++) {
//Earlier we trimmed out the hidden wall commands that are behind walls
	cam->wall_commands[idx][idx2].ld->seen=TRUE;
    }
  }
  LBtr(&doom_scrn_in_draw,0);
}



U0 SongTask(I64)
{//Original Song by Robert Prince
  Fs->task_end_cb=&SndTaskEndCB;
  MusicSettingsRst;
  //Play("ttt");
  //     Play("4eDEqFFetEEFqDeCDDEetCGF");
  //   Play("4eDEqFFetEEFqDeCDDEetCGF");
  //   Play("4eDCqDE3eAA4etEEFEDG3B4DCqF");
   //  Play("4eDCqDE3eAA4etEEFEDG3B4DCqF");
 
    // Play("4eDEqFFetEEFqDeCDDEetCGF");
    // Play("4eDEqFFetEEFqDeCDDEetCGF");
    // Play("4eDCqDE3eAA4etEEFEDG3B4DCqF");
    // Play("4eDCqDE3eAA4etEEFEDG3B4DCqF");
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
/*
U0 SongTask(U8 *title) {
  CWadDirectory *wad_dir=wad->body+wad->directory_ptr;
  U8 lump_name[9],*m;
  StrPrint(lump_name,"D_%s",title);
  wad_dir+=W_CheckNumForName(lump_name,wad);
  m=MUS2Freqs(wad->body+wad_dir->ptr);
  Fs->task_end_cb=&SndTaskEndCB;
  PlayMusicTask(m);
}
*/



F64 GetTargetLiftHeight(CDoomSector *floor,I64 type,Bool going_up=TRUE) {
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
      up=floor->base_floor_height+32>floor->floor_height;
      if(up)
        return floor->base_floor_height+32;
      return floor->base_floor_height;
    case LIFT_RAISE_24:
      up=floor->base_floor_height+24>floor->floor_height;
      if(up)
        return floor->base_floor_height+24;
      return floor->base_floor_height;
    case LIFT_RAISE_NEXT_FLOOR:
      diff=I16_MAX;
      for(idx=0;idx!=floor->linedef_cnt;idx++) {
        for(idx2=0;idx2!=2;idx2++) {
	  if(idx2)
	    sd=floor->linedefs[idx]->front;
	  else
	    sd=floor->linedefs[idx]->back;
	  if(sd&&sd!=floor)
	    if(sd->sector->floor_height>floor->floor_height)
	      diff=Min(diff,sd->sector->floor_height-floor->floor_height);
        }
      }
      if(diff==ToF64(I16_MAX))
        return floor->base_floor_height;
      return diff+floor->floor_height;
    case LIFT_LOW_HIGH_REPEAT:
      if(going_up) {
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

class CCeilThinker:CDoomThinkerBase {
  F64 target_start,target_end;
  F64 start_tS,speed,wait;
  CDoomSector*s;
  Bool going_up,going_down;
};
U0 CeilThinker(CDoomLevel *l,CCeilThinker *t) {
  CDoomSector *s=t->s;
  if(s->paused) return;
  if(!t->going_up&&!t->going_down) {
    if(t->target_end>s->ceil_height)
      t->going_up=TRUE,t->going_down=FALSE;
    else
      t->going_down=TRUE,t->going_up=FALSE;
  }
  F64 dir=Sign(t->target_end-t->target_start);
  s->ceil_height=dir*t->speed*TIME_SCALE*(Server_tS-t->start_tS)+t->target_start;
  if(t->going_up&&s->ceil_height>t->target_end) {
    s->ceil_height=t->target_end;
    t->going_up=FALSE;
    s->cur_action_linedef=NULL;
    Spawn(&PlaySoundTask,"PSTOP","snd",0,Fs);
    QueRem(t);
    Free(t);
  } else if(t->going_down&&s->ceil_height<t->target_end) {
    s->ceil_height=t->target_end;
    t->going_down=FALSE;
    s->cur_action_linedef=NULL;
    Spawn(&PlaySoundTask,"PSTOP","snd",0,Fs);
    QueRem(t);
    Free(t);
  }
}
U0 AddCeilThinker(CDoomLevel *l,CDoomSector *s,CDoomLinedef *ld,CDoomCeil *ceil) {
  if(s->cur_action_linedef) return;
  F64 dst=GetTargetCeilHeight(s,ceil->target);  
  CCeilThinker *t=AddThinker(l,&CeilThinker,"CCeilThinker");
  t->target_start=s->floor_height;
  t->target_end=dst;
  t->start_tS=Server_tS;
  t->speed=ceil->speed;
  s->cur_action_linedef=ld;
}
//This is used for floors too
class CLiftThinker:CDoomThinkerBase {
  F64 target_start,target_end;
  F64 start_tS,speed,wait_time;
  CDoomSector*s;
  CDoomLinedef *ld;
  CDoomLift *action;
  Bool going_up,going_down,reverting,waiting;
};

U0 LiftThinker(CDoomLevel *l,CLiftThinker *t) {
  CDoomSector *s=t->s;
  CDoomLift *action=t->action;
  CDoomLinedef *ld=t->ld;
  F64 dir;
  if(action->type=='Lift') {
    if(action->target==LIFT_LOW_HIGH_REPEAT) {
      dir=Sign(t->target_end-t->target_start);
      s->floor_height=dir*t->speed*TIME_SCALE*(Server_tS-t->start_tS)+t->target_start;
      if(t->going_up) {
        if(s->floor_height>t->target_end) {
	  s->floor_height=t->target_end;
lift_again:
	  Spawn(&PlaySoundTask,"PSTART","snd",0,Fs);
	  t->start_tS=Server_tS;
	  t->target_end=GetTargetLiftHeight(s,ld,!t->going_up);
        }
      } else if(t->going_down) {
        if(s->floor_height<t->target_end) {
	  s->floor_height=t->target_end;
	  goto lift_again;
        }
      }
    } else  {
      if(t->target_end>s->floor_height)
        t->going_up=TRUE,t->going_down=FALSE;
      else
        t->going_down=TRUE,t->going_up=FALSE;
      goto floor_defacto;
    }
  } else if(action->type=='Floor') {
floor_defacto:
    dir=Sign(t->target_end-t->target_start);
    if(!t->waiting) 
      s->floor_height=dir*t->speed*TIME_SCALE*(Server_tS-t->start_tS)+t->target_start;
    if(t->going_up) {
      if(s->floor_height>=t->target_end) {
        s->floor_height=t->target_end;
        t->going_up=FALSE;
floor_en:
	  if(action->type=='Lift'&&!t->reverting) {
	    if(!t->waiting) {
	      t->waiting=TRUE;
	      Spawn(&PlaySoundTask,"PSTOP","snd",0,Fs);
	      t->start_tS=Server_tS;
	    }
	    if(t->wait_time+t->start_tS>Server_tS||t->wait_time<0.) {
	      return;
	    }
	    t->waiting=FALSE;
	    t->start_tS=Server_tS;
	    t->reverting=TRUE;
	    t->target_start=s->floor_height;
	    t->target_end=s->base_floor_height;
	  } else {
	    t->reverting=FALSE;
	    s->cur_action_linedef=NULL;
	    QueRem(t);
	    Free(t);
	    t->going_up=FALSE,t->going_down=FALSE;
	    Spawn(&PlaySoundTask,"PSTOP","snd",0,Fs);
	  }
      }
    } else if(t->going_down) {
      if(s->floor_height<=t->target_end) {
        s->floor_height=t->target_end;
        t->going_down=FALSE;
        goto floor_en;
      }
    }

  }
}

U0 AddLiftThinker(CDoomLevel *l,F64 st,F64 en,
	CDoomSector *s,CDoomLinedef *ld,
	CDoomLift *action,Bool up) {
  if(s->cur_action_linedef) return;
  s->cur_action_linedef=ld;
  CLiftThinker *t=AddThinker(l,&LiftThinker,"CLiftThinker");
  t->start_tS=Server_tS;
  t->target_start=st;
  t->target_end=en;
  t->wait_time=action->delay;
  t->speed=action->speed;
  t->s=s;
  t->ld=ld;
  t->action=action;
  if(up)
   t->going_up=TRUE;
  else
   t->going_down=TRUE;
}

class CDoorThinker:CDoomThinkerBase {
  F64 target_start,target_end;
  F64 start_tS,speed;
  F64 wait_time;
  CDoomSector*s;
  CDoomLinedef *ld;
  CDoomDoor *action;
  Bool opening,closing,waiting;
  Bool reverting;
};
U0 DoorThinker(CDoomLevel *l,CDoorThinker *t) {
  CDoomSector *s=t->s;
  CDoomThing **things;
  F64 ceil=I16_MAX,dir;
  I64 idx;
//A door is fully open when its ceiling height is 4 less than the lowest neighbor ceiling adjacent to it
  for(idx=0;idx!=s->linedef_cnt;idx++) {
    if(s->linedefs[idx]->back&&s->linedefs[idx]->back->sector!=s)
      ceil=Min(s->linedefs[idx]->back->sector->base_ceil_height-4,ceil);
    else if(s->linedefs[idx]->front&&s->linedefs[idx]->front->sector!=s)
      ceil=Min(s->linedefs[idx]->front->sector->base_ceil_height-4,ceil);
  }
  if(t->opening) {
    t->target_end=ceil;
    s->bumped_into=FALSE;
    dir=Sign(t->target_end-t->target_start);
    if(!t->waiting) 
      s->ceil_height=dir*t->speed*TIME_SCALE*(Server_tS-t->start_tS)+t->target_start;
    if(OutsideOfRange(s->ceil_height,t->target_start,t->target_end)||t->waiting) {
      s->ceil_height=ceil;
//-1 for never close/open again
      if(t->wait_time>=0.) {
//close again
        if(!t->waiting) {
	  t->waiting=TRUE;
	  t->start_tS=Server_tS;
        }
        if(t->wait_time+t->start_tS>Server_tS) return;
        t->waiting=FALSE;
        t->start_tS=Server_tS;
        t->opening=FALSE;
        t->closing=TRUE;
        Spawn(&PlaySoundTask,"DORCLS",,0,Fs);
        t->wait_time=-1.;
        t->target_start=s->ceil_height;
      } else {
        s->cur_action_linedef=NULL;
        QueRem(t);
        Free(t);
      }
    }
  } else if(t->closing) {
    t->target_end=s->floor_height;
    dir=Sign(t->target_end-t->target_start);
    s->ceil_height=dir*t->speed*TIME_SCALE*(Server_tS-t->start_tS)+t->target_start;
    if(OutsideOfRange(s->ceil_height,t->target_start,t->target_end)||t->waiting) {
      s->ceil_height=s->base_floor_height;
//-1 for never close/open again
      if(t->wait_time>=0.) {
        if(!t->waiting) {
	  t->waiting=TRUE;
	  t->start_tS=Server_tS;
        }
        if(t->wait_time+t->start_tS>Server_tS) return;
        t->wait_time=-1.;
        t->target_start=s->floor_height;
open_again:
        t->waiting=FALSE;
//open again
        t->start_tS=Server_tS;
        t->opening=TRUE;
        t->closing=FALSE;
        Spawn(&PlaySoundTask,"DOROPN","snd",0,Fs);
      } else {
        s->cur_action_linedef=NULL;
        QueRem(t);
        Free(t);
      }
    } else if(s->bumped_into) {
      s->bumped_into=FALSE;
      t->target_start=s->ceil_height;
      t->wait_time=t->action->wait;
      goto open_again;
    } else {
      things=GetCrushedThingsInSector(l,s); //NULL terminated
      for(idx=0;things[idx];idx++) {
        if(things[idx]>0.) {
	  Free(things);
	  t->target_start=s->ceil_height;
	  t->wait_time=t->action->wait;
	  goto open_again;
        }
      }
      Free(things);
    }
  }
  s->door_height_offset=s->ceil_height-s->base_floor_height;  
}
U0 AddDoorThinker(CDoomLevel *l,F64 st,F64 en,
	CDoomSector *s,CDoomLinedef *ld,
	CDoomDoor *action,Bool up,F64 wait_time=-1.) {
  if(s->cur_action_linedef) return;
  s->cur_action_linedef=ld;
  CDoorThinker *t=AddThinker(l,&DoorThinker,"CDoorThinker");
  t->start_tS=Server_tS;
  s->cur_action_linedef=ld;
  t->target_start=st;
  t->target_end=st;
  t->speed=action->speed;
  t->s=s;
  t->ld=ld;
  t->action=action;
  t->wait_time=wait_time;
  if(up)
   t->opening=TRUE;
  else
   t->closing=TRUE;
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
	      if(.5<diff<dst-floor->floor_height)
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

class CDonutThinker:CDoomThinkerBase {
  F64 start_tS;
  CDoomLinedef *ld;
};

U0 DonutThinker(CDoomLevel *l,CDonutThinker *t) {
  CDoomSector *s1,*s2,*s3;
  CDoomLinedef *ld;
  F64 time=Server_tS-t->start_tS;
  I64 i;
  for(s1=l->sectors.next;s1!=&l->sectors;s1=s1->next) {
    if(s1->tag_number==t->ld->sector_tag) {
//      if(s1->cur_action_linedef)
//	goto next;
      ld=s1->linedefs[0];
      if(ld->front^^ld->back) goto next;
      if(ld->front->sector==s1) {
	s2=ld->back->sector;
      } else
	s2=ld->front->sector;
      i=0;
      do {
	ld=s2->linedefs[i];
	if(!(ld->front&&ld->back)||ld->back->sector==s1)
	  goto next2;
	s3=ld->back->sector;
//Rising slime
	if(s2->floor_height<s3->floor_height) {
	  s2->cur_action_linedef=t->ld;
	  s2->floor_height+=1.5*(1/35.);
        } else {
	  s2->floor_height=s3->floor_height;
	  MemCpy(s2->floor_dc,s3->floor_dc,sizeof(CDC*)*4);
	  s2->cur_action_linedef=NULL;
	}
//Decending poo poo
	if(s1->floor_height>s3->floor_height) {
	  s1->cur_action_linedef=t->ld;
	  s1->floor_height-=1.5*(1/35.);
        } else {
	  s1->floor_height=s3->floor_height;
	  s1->cur_action_linedef=NULL;
	}
next2:;
      } while(++i<s2->linedef_cnt);
    }
next:;
  }
}
class CStairsThinker:CDoomThinkerBase {
  CDoomSector *s;
  F64 start_h,start_tS,target_h;
  F64 speed;
};
U0 StairThinker(CDoomLevel *l,CStairsThinker *t) {
  F64 tm=Server_tS-t->start_tS;
  t->s->floor_height=t->start_h+tm*t->speed*30;
  if(t->s->floor_height>t->target_h) {
    t->s->floor_height=t->target_h;
    QueRem(t);
    Free(t);
  }
}
U0 BuildStairs(CDoomLevel *l,CDoomLinedef *ld) {
  CDoomSector *s,*s2,*new;
  CStairsThinker *think;
  CDoomLinedef *ld2;
  CDoomStairs *st=ld->special_type;
  F64 step;
  I64 idx;
  for(s=l->sectors.next;s!=&l->sectors;s=s->next) {
    if(ld->sector_tag==s->tag_number) {
      if(s->cur_action_linedef)
        goto nxt;
      s->cur_action_linedef=ld;
      step=s->floor_height;
      s2=s;
loop:
      step+=st->step;
      think=AddThinker(l,&StairThinker,"CStairsThinker");
      think->start_h=s->floor_height;
      think->start_tS=Server_tS;
      think->target_h=step;
      think->speed=st->speed;
      think->s=s2;
      for(idx=0;idx!=s2->linedef_cnt;idx++) {
        ld2=s2->linedefs[idx];
        if(ld2->front&&ld2->back) {
	  if(ld2->front->sector!=s2)
	    new=ld2->front->sector;
	  else
	    new=ld2->back->sector;
	  if(new!=s2&&!new->cur_action_linedef)
	    if(new->floor_dc[0]==s2->floor_dc[0]) {
	      new->cur_action_linedef=ld;
	      s2=new;
	      goto loop;
	    }
        }
      }
    }
nxt:;
  }
}
class CTeleportThinker:CDoomThinkerBase {
  CDoomThing *fog;
};
U0 TeleportFogThinker(CDoomLevel *l,CTeleportThinker *t) {
  CDoomThing *fog=t->fog;
  I64 frame;
  fog->anim_no_repeat=TRUE;
  frame=ToI64((Server_tS-fog->anim_start_tS)*4);
  if(frame>=StrLen(fog->template->animation)) {
    QueRem(fog);
    Free(fog);
    QueRem(t);
    Free(t);
  }
}
U0 TeleportThing(CDoomLevel *l,CDoomTeleporter *tp,I64 sector_tag,CDoomThing *who) {
  CDoomThing *cur,*fog;
  CDoomSector *sec;
  static CDoomThingTemplate *teleport_fog=NULL;
  if(!teleport_fog) {
     teleport_fog=CAlloc(sizeof CDoomThingTemplate);
     teleport_fog->spr_base_name[0](U32)='TFOG';
     teleport_fog->radius=20;
     teleport_fog->animation="ABABCDEFGHIJ";
     teleport_fog->_animation=GenerateCacheFrames(teleport_fog,teleport_fog->animation);
  }
  for(cur=l->things.next;cur!=&l->things;cur=cur->next) {
//https://doomwiki.org/wiki/Teleporter
    if(cur->template->type==14) {
       sec=GetSectorForCoord(l,cur->x,cur->y);
       if(sec->tag_number==sector_tag) {
	 who->x=cur->x;
	 who->y=cur->y;
	 if(tp->orient==TP_ORIENT_SET)
	   who->angle=cur->angle;
	 if(!tp->silent) {
           Spawn(&PlaySoundTask,"TELEPT","snd",0,Fs);
	   fog=CAlloc(sizeof CDoomThing);
	   QueIns(fog,l->things.last);
	   fog->template=teleport_fog;
	   fog->x=cur->x;
	   fog->y=cur->y;
	   fog->anim_start_tS=Server_tS;
	   fog->thinker=AddThinker(l,&TeleportFogThinker,"CTeleportThinker");
	   fog->thinker(CTeleportThinker*)->fog=fog;
	 }
	 return;
       }
    }
  }
}
U0 ChangeByModel(CDoomLinedef *ld,CDoomSector *s,I64 model,Bool texture_change,Bool type_change,Bool zero) {
  CDoomLinedef *ld2;
  I64 idx;
//Account for texture/type change
  if(texture_change||type_change) {
    if(texture_change) s->tx_changed=TRUE;
    if(zero) s->special_type=0;
    if(model==FLOOR_MODEL_NUMBERED) {
//See EV_DoFloor in doom3do source code
      for(idx=0;idx!=s->linedef_cnt;idx++) {
        ld2=s->linedefs[idx];
        if(ld2->front&&ld2->back) {
	  if(ld2->front->sector!=s) {
	    s->changed_from_sector=ld2->front->sector;
	    if(texture_change)
	      MemCpy(s->floor_dc,ld2->front->sector->floor_dc,8*4);
	    if(type_change)
	      s->special_type=ld2->front->sector->special_type;
	    break;
	  }
	  if(ld2->back->sector!=s) {
	    s->changed_from_sector=ld2->back->sector;
	    if(texture_change)
	      MemCpy(s->floor_dc,ld2->back->sector->floor_dc,8*4);
	    if(type_change)
	      s->special_type=ld2->back->sector->special_type;
	    break;
	  }
        }
      }
    } else if(model==FLOOR_MODEL_TRIGGER) {
      s->changed_from_sector=ld->front->sector;
      if(texture_change){
        MemCpy(s->floor_dc,ld->front->sector->floor_dc,8*4);
      }
      if(type_change)
        s->special_type=ld->front->sector->special_type;
    }
  }
}

class CCrushThinker:CDoomThinkerBase {
  CDoomSector *s;
  F64 base_speed;
  Bool going_up;
};
//NULL terminated
CDoomThing **GetCrushedThingsInSector(CDoomLevel *l,CDoomSector *s) {
  I64 cnt=0;
  F64 gap=s->ceil_height-s->floor_height;
  CDoomThing *cur,*head=&l->things,**ret=NULL;;
again:;
  for(cur=head->next;cur!=head;cur=cur->next) {
    if(GetSectorForCoord(l,cur->x,cur->y)==s) {
      if((cur->height-s->floor_height)+cur->template->height>gap) {
	if(!ret)
          cnt++;
	else
	  ret[cnt++]=cur;
       }
    }
  }
  if(ret) return ret;
  if(!cnt) return CAlloc(8);
  ret=CAlloc(cnt*8);
  cnt=0;
  goto again;
}

class CLightBlinkThinker:CDoomThinkerBase {
  CDoomSector *s;
  F64 begin_at_tS;
  F64 change_tS;
  Bool on;
};
U0 LightBlinkThinker(CDoomLevel *l,CLightBlinkThinker *t) {
  F64 ts=Server_tS;
  CDoomSector *s=t->s;
  if(ts<t->begin_at_tS) {
    return;
  }
  if(ts>t->change_tS) {
    t->on^=TRUE;
    if(t->on)
      t->change_tS=ts+1/7.*30;
    else
      t->change_tS=ts+1;
  }
  if(t->on) {
    s->cur_light_level=s->base_light_level;
  } else {
    s->cur_light_level=LowestSurrondingLight(s);
  }
}
extern U0 AddCrushThinker(CDoomLevel *l,CDoomSector *s,CDoomCrusher *c);
Bool _TriggerLinedef(CDoomLevel *l,CDoomSector *s,CDoomLinedef *ld,I64 flags,CDoomThing *who) {
  CDoomActionSector *type;
  CDoomFloor *fl;
  CDoomDoor *door;
  CDoomLift *lift;
  CDoomCeil *ceil;
  CDoomDonut *donut;
  CDoomExit *exit;
  CDoomTeleporter *tp;
  CDoomCrusher *crush;
  CDoomLight *light;
  I64 idx;
  CDoomLinedef *ld2;
  CDonutThinker *dt;
  CLightBlinkThinker *blink;
  Vector *cross;
  CD2 point;
  F64 dst;
  if(ld) {
    if((type=ld->special_type)) {
      if(type->type=='Light') {
	light=type;
        switch(light->trigger) {
	    break;case 'P1':
light_activate1:
	    if(ld->activated) return FALSE;
light_activate:
	    if(light->target==LIGHT_255) {
	      s->cur_light_level=255;
	    } else if(light->target==LIGHT_35) {
	      s->cur_light_level=35;
	    } else if(light->target==LIGHT_MIN_NIEGHBOR)
	      s->cur_light_level=LowestSurrondingLight(s);
	    else if(light->target==LIGHT_MAX_NIEGHBOR)
	      s->cur_light_level=HighestSurrondingLight(s);
            else if(light->target==LIGHT_BLINK) {
	      if(ld->activated) return FALSE; //No need to add another thikner
	      blink=AddThinker(l,&LightBlinkThinker,"CLightBlinkThinker");
	      blink->on=FALSE;
	      blink->begin_at_tS=Server_tS+1/30.*9;
	    }
	    return TRUE;
	    break; case 'S1':    
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto light_activate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto light_activate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto light_activate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto light_activate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto light_activate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto light_activate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto light_activate;
        }
      } else if(type->type=='Crush') {
        crush=type;
        switch(crush->trigger) {
	    break;case 'P1':
crush_activate1:
	    if(ld->activated) return FALSE;
crush_activate:
	    if(crush->turn_on) {
	      s->cur_action_linedef=ld;
	      AddCrushThinker(l,s,crush);
	    } else  //The thinker checks for this
	      s->cur_action_linedef=NULL;
	    return TRUE;
	    break; case 'S1':    
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto crush_activate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto crush_activate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto crush_activate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto crush_activate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto crush_activate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto crush_activate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto crush_activate;
        }
      } else if(type->type=='Stairs') {
        tp=type;
        switch(tp->trigger) {
	    break;case 'P1':
stairs_activate1:
	    if(ld->activated) return FALSE;
stairs_activate:
	    BuildStairs(l,ld);
	    return TRUE;
	    break; case 'S1':    
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto stairs_activate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto stairs_activate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto stairs_activate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto stairs_activate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto stairs_activate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto stairs_activate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto stairs_activate;
        }
      } else if(type->type=='Teleport') {
        tp=type;
        switch(tp->trigger) {
	    break;case 'P1':
teleport_activate1:
	    if(ld->activated) return FALSE;
teleport_activate:
	    if(tp->dest==TP_DEST_TP_THING) {
	      if(flags&WACTIVATE_MONSTER&&!tp->monster)
	        return FALSE;
	      if(!(flags&WACTIVATE_MONSTER)&&!tp->player)
	        return FALSE;
//You must be have passed the first sidedef to trigger a tele[P]orter(meaning you are on the backside)
	      cross=CreateVector(2);
	      cross->data[0]=ld->end->x-ld->start->x;
	      cross->data[1]=ld->end->y-ld->start->y;
	      point.x=who->x-ld->start->x;
	      point.y=who->y-ld->start->y;
	      if(flags&WACTIVATE_WALK&&IsFrontSideOfVector2D(cross,&point)) {
	        DestroyVector(cross);
	        return FALSE;
	      }
	      DestroyVector(cross);
	      TeleportThing(l,tp,ld->sector_tag,who);
	    } else
	      PrintI("UNIMP_DEST",tp->dest); 
	    return TRUE;
	    break; case 'S1':    
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto teleport_activate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto teleport_activate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto teleport_activate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto teleport_activate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto teleport_activate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto teleport_activate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto teleport_activate;
        }

      } else if(type->type=='Exit') {
        exit=type;
        switch(exit->trigger) {
	    break;case 'P1':
exit_activate1:
	    if(ld->activated) return FALSE;
exit_activate:
	    if(s->cur_action_linedef)
	      return FALSE;
	    s->cur_action_linedef=ld;
	    Spawn(&PlaySoundTask,"SWTCHX","snd",0,Fs);
	    l->ended_special=exit->secret;
	    l->ended=TRUE;
	    return TRUE;
	    break; case 'S1':    
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto exit_activate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto exit_activate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto exit_activate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto exit_activate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto exit_activate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto exit_activate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto exit_activate;
        }
      } else if(type->type=='Donut') {
        donut=type;
        switch(donut->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
donut_activate1:          
	    if(ld->activated) return FALSE;
donut_activate:
	    if(s->cur_action_linedef)
	      return FALSE;
	    s->cur_action_linedef=ld;
	    dt=AddThinker(l,&DonutThinker,"CDonutThinker");
	    dt->ld=ld;
	    dt->start_tS=Server_tS;
	    return TRUE;
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto donut_activate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto donut_activate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto donut_activate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto donut_activate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto donut_activate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto donut_activate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto donut_activate;
        }
      } else if(type->type=='Ceil') {
        ceil=type;
        switch(ceil->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
cactivate1:          
	    if(ld->activated) return FALSE;
cactivate:
	    if(s->cur_action_linedef)
	      return FALSE;
	    Spawn(&PlaySoundTask,"STNMOV","snd",0,Fs);
	    AddCeilThinker(l,s,ld,ceil);
	    return TRUE;
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto cactivate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto cactivate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto cactivate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto cactivate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto cactivate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto cactivate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto cactivate;
        }
      } else if(type->type=='Lift') {
        lift=type;
        switch(lift->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
lactivate1:
	    if(ld->activated) return FALSE;
lactivate:
	    if(s->cur_action_linedef)
	      return FALSE;
	    dst=GetTargetLiftHeight(s,lift->target);
	    AddLiftThinker(l,s->floor_height,dst,s,ld,lift,dst>s->floor_height);
	    Spawn(&PlaySoundTask,"STNMOV","snd",0,Fs);
	    ChangeByModel(ld,s,lift->model,lift->texture_change,lift->type_change,lift->zero_type);
	    return TRUE;
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto lactivate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto lactivate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto lactivate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto lactivate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto lactivate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto lactivate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto lactivate;
        }
      } else if(type->type=='Floor') {
        fl=type;
        switch(fl->trigger) {
	    break; case 'P1':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
factivate1:
	    if(ld->activated) return FALSE;
factivate:
	    if(s->cur_action_linedef)
	      return FALSE;
	    dst=GetTargetFloorHeight(s,fl->target,fl->direction==FLOOR_DIR_UP);
	    AddLiftThinker(l,s->floor_height,dst,s,ld,fl,dst>s->floor_height);
	    Spawn(&PlaySoundTask,"STNMOV","snd",0,Fs);
	    ChangeByModel(ld,s,fl->model,fl->texture_change,fl->type_change,fl->zero_type);
	    return TRUE;
	    break; case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto factivate1;
	    break; case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto factivate1;
	    break; case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto factivate1;
	    break; case 'PR':
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto factivate;
	    break; case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto factivate;
	    break; case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto factivate;
	    break; case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto factivate;
        }
      } else if(type->type=='Door') {
        door=type;
        switch(door->trigger) {
	  case 'P1':
	    s=ld->back->sector;
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
activate1:
	    if(ld->activated) return 0;
activate:
	    if(s->cur_action_linedef)
	      return FALSE;
//Check for keys
	    if(!l->has_red_key&&(door->key&DOOR_LOCK_RED)) return 0;
	    if(!l->has_blue_key&&(door->key&DOOR_LOCK_BLUE)) return 0;
	    if(!l->has_yellow_key&&(door->key&DOOR_LOCK_YELLOW)) return 0;
//Do the door action
	    switch(door->action) {
	      case DOOR_ACTION_OPEN_WAIT_CLOSE:
	        Spawn(&PlaySoundTask,"DOROPN","snd",0,Fs);
	        AddDoorThinker(l,s->ceil_height,0.,s,ld,door,TRUE,door->wait);
	        break;
	      case DOOR_ACTION_CLOSE_WAIT_OPEN:
	        Spawn(&PlaySoundTask,"DORCLS","snd",0,Fs);
	        AddDoorThinker(l,s->ceil_height,0.,s,ld,door,FALSE,door->wait);
	        break;
	      case DOOR_ACTION_CLOSE:
	        Spawn(&PlaySoundTask,"DORCLS","snd",0,Fs);
	        AddDoorThinker(l,s->ceil_height,0.,s,ld,door,FALSE,-1.);
	        break;
	      case DOOR_ACTION_OPEN:
	        Spawn(&PlaySoundTask,"DOROPN","snd",0,Fs);
	        AddDoorThinker(l,s->ceil_height,0.,s,ld,door,TRUE,-1.);
	        break;
	    }
	    return TRUE;
	    break;
	  case 'W1':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto activate1;
	    break;
	  case 'S1':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto activate1;
	    break;
	  case 'G1':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto activate1;
	    break;
	  case 'PR':
	    s=ld->back->sector;
	    if(!(flags&WACTIVATE_PUSH)) return FALSE;
	    goto activate;
	  case 'WR':
	    if(!(flags&WACTIVATE_WALK)) return FALSE;
	    goto activate;
	  case 'GR':
	    if(!(flags&WACTIVATE_SHOOT)) return FALSE;
	    goto activate;
	  case 'SR':
	    if(!(flags&WACTIVATE_SWITCH)) return FALSE;
	    goto activate;
        }
      }
    }
  }
  return FALSE;
}
CDC *AltSwitchTexture(U8 *txt,Bool on=FALSE,Bool *res_txtr_is_on=NULL) {
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
    if(!TextureName2DC(buf))
      goto skip;
    if(TextureName2DC(buf)==txt&&!on) {
      buf[2]='2';
      if(res_txtr_is_on) *res_txtr_is_on=TRUE;
      return TextureName2DC(buf);
    }
    if(on) {
      buf[2]='2';       
      if(TextureName2DC(buf)==txt) {
        buf[2]='1';
        if(res_txtr_is_on) *res_txtr_is_on=FALSE;
        return TextureName2DC(buf);
      }
    }
skip:;
  }
  return NULL;
}
class CButtonThinker:CDoomThinkerBase {
  CDoomSector *s;
  F64 switch_tS;
  I64 which_part;
  Bool repeat;
};

U0 ButtonThinker(CDoomLevel *l,CButtonThinker *t) {
  CDoomSidedef *sd=t->s;
  Bool repeat=t->repeat;
  F64 reset_time=t->switch_tS;
  I64 which_texture=t->which_part;
  U8 on_off_idx='2'; 
  CDC *dc;
  if(!repeat) {
    on_off_idx='2';
    Free(t);
    QueRem(t);
    goto set_and_ret;
  }
  if(reset_time>Server_tS) {
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
  Spawn(&PlaySoundTask,"SWTCHX","snd",0,Fs);
  goto set_and_ret;
}
U0 AddButtonThinker(CDoomLevel *l,CDoomSidedef *s,I64 which_part,Bool repeat=TRUE,Bool on) {
  CButtonThinker *t=AddThinker(l,&ButtonThinker,"CButtonThinker");
  t->s=s;
  t->repeat=repeat;
  t->switch_tS=Server_tS+2.;
  t->which_part=which_part;
}

U0 TriggerLinedef(CDoomLevel *l,CDoomLinedef *ld,I64 flags,CDoomThing *who) {
  CDoomSector *sector,*head=&l->sectors;
  I64 trig=FALSE;
  if(!ld->special_type) return;
//Push operators on the linedef that called it
  if(ld->special_type(CDoomDoor*)->trigger.u8[0]=='P') {
    ld->back->sector->bumped_into=TRUE;
    trig|=_TriggerLinedef(l,ld->back->sector,ld,flags,who);
  } else
    for(sector=head->next;sector!=head;sector=sector->next) {
      if(sector->tag_number==ld->sector_tag)
        trig|=_TriggerLinedef(l,sector,ld,flags,who);
    }
  if(!ld->activated)
    ld->activated=trig;
}



extern U0 LineAttack(CDoomLevel *l,CDoomThing *self,CDoomThing *target,F64 range,F64 angle,F64 damage);
#include "Collision.HC";
#include "ST.HC";
#include "Player.HC";
#include "Enemy.HC";
#include "Physics.HC";
U0 CheckPowerupPickup(CDoomLevel *l) {
  CDoomThing *t,*head=&l->things,*next;
  AmmoType *load;
  GunAvail *avail;
  Bool change,new_gun=FALSE;
  I64 picked_up_gun=-1;
  I64 orig;
  for(t=head->next;t!=head;t=next) {
    next=t->next;
    if(SqrI64(2*t->template->radius)>=SqrI64(p->x-t->x)+SqrI64(p->y-t->y)) {
      switch(t->template->type) {
	  case 2006: //BFG
	    new_gun=!p->arsenal[7].available;
	    p->arsenal[7].available=TRUE;
	    picked_up_gun=7;
cell:
	    load=p->arsenal[6].load;
	    orig=load->ammo;
	    if(l->skill==0||l->skill==5)
	      load->ammo+=40;
	    else
	      load->ammo+=20;
	    load->ammo=ClampI64(load->ammo,0,maxCells);
	    if(load->ammo!=orig||new_gun) {
rem:
	      p->pickup_amt+=6;
	      if(t->template->flags&TF_ARTIFACT)
	        l->stats.have_items++;
	      QueRem(t);
	      Free(t);
	    }
	    break;
	  case 2002: //Chaingun
	    new_gun=!p->arsenal[3].available;
	    load=p->arsenal[3].load;
	    p->arsenal[3].available=TRUE;
	    picked_up_gun=3;
	    orig=load->ammo;
	    if(l->skill==0||l->skill==5)
	      load->ammo+=40;
	    else
	      load->ammo+=20;
	    load->ammo=ClampI64(load->ammo,0,maxBullets);
	    if(load->ammo!=orig||new_gun) 
	      goto rem;
	    break;
	  case 2005: //Chainsaw
	    new_gun=!p->arsenal[5].available;
	    picked_up_gun=5;
	    p->arsenal[5].available=TRUE;
	    if(new_gun)
	      goto rem;
	  case 2004: //Plasma gun
	    new_gun=!p->arsenal[6].available;
	    picked_up_gun=6;
	    load=p->arsenal[6].load;
	    p->arsenal[6].available=TRUE;
	    goto cell;
	  case 2003: //Rocket luancher
	    picked_up_gun=4;
	    new_gun=!p->arsenal[4].available;
	    load=p->arsenal[4].load;
	    p->arsenal[4].available=TRUE;
	    orig=load->ammo;
	    if(l->skill==0||l->skill==5)
	      load->ammo+=2;
	    else
	      load->ammo+=1;
	    load->ammo=ClampI64(load->ammo,0,maxRockets);
	    if(load->ammo!=orig||new_gun) 
	      goto rem;
	    break;
	  case 2001: //Shutgun
	    picked_up_gun=2;
	    new_gun=!p->arsenal[2].available;
	    load=p->arsenal[2].load;
	    p->arsenal[2].available=TRUE;
	    orig=load->ammo;
	    if(l->skill==0||l->skill==5)
	      load->ammo+=8;
	    else
	      load->ammo+=4;
	    load->ammo=ClampI64(load->ammo,0,maxBullets);
	    if(load->ammo!=orig||new_gun)
	      goto rem;
	    break;
	  case 2008: //4 shells
	    load=p->arsenal[2].load;
	    orig=load->ammo;
	    load->ammo+=4;
	    load->ammo=ClampI64(load->ammo,0,maxShells);
	    if(load->ammo!=orig) 
	      goto rem;
	    break;
	  case 2048: //Box of bullets
	    load=p->arsenal[1].load;
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
	    load=p->arsenal[4].load;
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
	    load=p->arsenal[2].load;
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
	    load=p->arsenal[1].load;
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
	    load=p->arsenal[6].load;
	    orig=load->ammo;
	    load->ammo+=20;
	    load->ammo=ClampI64(load->ammo,0,maxCells);
	    if(load->ammo!=orig)
	      goto rem;
	    break;
	  case 2010: //Rocket
	    load=p->arsenal[4].load;
	    orig=load->ammo;
	    load->ammo+=1;
	    load->ammo=ClampI64(load->ammo,0,maxRockets);
	    if(load->ammo!=orig)
	      goto rem;
	    break;
	  case 8: //Backpack
	    if(!p->has_backpack) {
              p->has_backpack=TRUE;
	      maxBullets=400;
	      maxShells=200;
	      maxRockets=100;
	      maxCells=600;
	    }
	    //Poo poo cells
	    load=p->arsenal[6].load;
	    load->ammo=ClampI64(load->ammo+20,0,maxCells);
	    //4 Shothun shells
	    load->ammo=ClampI64(load->ammo,0,maxCells);
	    load=p->arsenal[2].load;
	    load->ammo=ClampI64(load->ammo+4,0,maxShells);
	    //10 bullets
	    load=p->arsenal[1].load;
	    load->ammo=ClampI64(load->ammo+10,0,maxBullets);
	    //1 rocket
	    load=p->arsenal[4].load;
	    load->ammo=ClampI64(load->ammo+1,0,maxRockets);
	    goto rem;
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
	    p->health=ClampI64(p->health+100,0,200);
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
	  case 2025: //Radiuation suit
	    p->rad_suit_time=60*30; //assumes 30 ticks a motherfuckin second
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
  if(picked_up_gun!=-1&&new_gun)
    SwapWeapon(p,picked_up_gun);
}

Bool PlayerAttack(F64 shots_per_minute,F64 min_damage,F64 max_damage,F64 range,U64 rocket_type=0) {
  F64 cooldown=60./shots_per_minute;
  if(Server_tS<p->last_attack+cooldown) return FALSE;
  p->last_attack=Server_tS;
  F64 angle=p->angle,r;
  F64 damage=Rand*(max_damage-min_damage)+min_damage;
  I64 idx;
//Use mouse angle as real angle,then restore
  r=p->angle;
//Views in TOOM are reversed
  p->angle+=((GR_WIDTH-cursor_x)-GR_WIDTH/2)/ToF64(GR_WIDTH/2)*cam.fov/2;
  angle=p->angle;
  CDoomThing *target=PlayerPickTarget(l,p);
  if(target)
    angle=FArg(target->x-p->x,target->y-p->y);
  p->angle=r;
//Account for mouse aim
  if(!rocket_type) {
    if(weaponIndex==2) {//Shotgun
      for(idx=0;idx!=7;idx++) {
	if(!idx)
	  r=0;
	else
          r=(Rand-.5); 
        LineAttack(l,p,target,range,angle+r*9.8*pi/360.,damage);
      }
    } else
      LineAttack(l,p,target,range,angle,damage);
  } else {
    SpawnMissile(l,p,target,rocket_type);
  }
  p->muzzle_flash_end_tS=Server_tS+1/10.;
  return TRUE;
}

U0 UpdateLevel(CDoomLevel *l) {
  CDoomSector *sector,*head=&l->sectors;
  Physics(l);
  UpdateThinkers(l);
  CheckPowerupPickup(l);
  if(p&&p->rad_suit_time)
    p->rad_suit_time=Clamp(p->rad_suit_time-1/30.,0.,60.);
}



U0 PressAWall(CDoomLevel *l,CD2 *where,F64 angle,F64 height) {
  CD2 dummy;
  F64 floor,floor2,ceil,ceil2;
  I64 which_texture=0;
  Bool repeat=FALSE,passed=FALSE,is_on;
  U64 trigger;
  CDoomLinedef *ld;
  CDoomSidedef *sd;
  Vector *ldv;
   dummy.x=where->x;
  dummy.y=where->y;
  ld=MoveInLevel(l,&dummy,angle,64.,1.,height,0);
  if(ld) {
    if(ld->front^^ld->back) {
      which_texture=1;
      if(ld->front) sd=ld->front;
      else if(ld->back) sd=ld->back;
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
        if(ld->special_type&&AltSwitchTexture(sd->upper_texture[0],,&is_on)) {
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
	    TriggerLinedef(l,ld,WACTIVATE_PUSH,p);
	  else
	    TriggerLinedef(l,ld,WACTIVATE_SWITCH,p);
	  passed=TRUE;
	  Spawn(&PlaySoundTask,"SWTCHN","snd",0,Fs);
	  AddButtonThinker(l,sd,which_texture,trigger.u8[1]!='1',is_on);
        }
        break;
      case 1:
        if(ld->special_type&&AltSwitchTexture(sd->middle_texture[0]))
	  goto pass;
        break;
      case 0:
        if(ld->special_type&&AltSwitchTexture(sd->lower_texture[0]))
	  goto pass;
        break;
    }
  }
  if(!passed&&ld)
    TriggerLinedef(l,ld,WACTIVATE_SWITCH,p);
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



WinMax;
U0 InitLevel(CDoomLevel *l) {
  CDoomThing *t,*head=&l->things,*next;
  CDoomSector *s;
  for(t=head->next;t!=head;t=next) {
    next=t->next;
    if(p!=t)
      switch(t->template->type) {
//Players
        case 1:
        case 2:
        case 3:
        case 4:
	  QueRem(t);
	  Free(t);
	  break;
        default:
      }
    if(s=GetSectorForCoord(l,t->x,t->y))
      t->height=s->floor_height;
  }
  InitMonsters(l);
}
U0 FreeLevel(CDoomLevel *l) {
  QueDel(&l->things);
  QueDel(&l->sidedefs);
  QueDel(&l->subsectors);
  QueDel(&l->thinkers);
  Free(l->segs);
  QueDel(&l->sectors);
  QueDel(&l->sidedefs);
  Free(l->vertices);
  QueDel(&l->linedefs);
  Free(l->block_map_data);
  Free(l->action_linedefs);
  Free(l);
}


extern U0 SaveGame(U8 *filename,U8 *title="Quick");
extern U0 LoadGame(U8 *filename);
#include "Automap.HC";
#include "Menu.HC";
U8 *NextLevel(U8 *nm,Bool special=FALSE) {
//Episode 1
  if(!StrCmp(nm,"E1M1")) 
    return "E1M2";
  else if(!StrCmp(nm,"E1M2")) 
    return "E1M3";
  else if(!StrCmp(nm,"E1M3")) 
    return "E1M4";
  else if(!StrCmp(nm,"E1M4")) {
    if(special) return "E1M9";
    return "E1M5";
  } else if(!StrCmp(nm,"E1M5")) 
    return "E1M6";
  else if(!StrCmp(nm,"E1M6")) 
    return "E1M7";
  else if(!StrCmp(nm,"E1M7")) 
    return "E1M8";
  else if(!StrCmp(nm,"E1M9")) 
    return "E1M5";
//Episode 2
  if(!StrCmp(nm,"E2M1")) 
    return "E2M2";
  else if(!StrCmp(nm,"E2M2")) 
    return "E2M3";
  else if(!StrCmp(nm,"E2M3")) 
    return "E2M4";
  else if(!StrCmp(nm,"E2M4"))
    return "E2M5";
  else if(!StrCmp(nm,"E2M5"))  {
    if(special) return "E2M9";
    return "E2M6";
  } else if(!StrCmp(nm,"E2M6")) 
    return "E2M7";
  else if(!StrCmp(nm,"E2M7")) 
    return "E2M8";
  else if(!StrCmp(nm,"E2M9")) 
    return "E2M6";
//Episode 3
  if(!StrCmp(nm,"E3M1")) 
    return "E3M2";
  else if(!StrCmp(nm,"E3M2")) 
    return "E3M3";
  else if(!StrCmp(nm,"E3M3")) 
    return "E3M4";
  else if(!StrCmp(nm,"E3M4"))
    return "E3M5";
  else if(!StrCmp(nm,"E3M5"))
    return "E3M6";
  else if(!StrCmp(nm,"E3M6")) { 
    if(special) return "E3M9";
    return "E3M7";
  } else if(!StrCmp(nm,"E3M7")) 
    return "E3M8";
  else if(!StrCmp(nm,"E3M9")) 
    return "E3M7";
//Episode 4
  if(!StrCmp(nm,"E4M1")) 
    return "E4M2";
  else if(!StrCmp(nm,"E4M2")) {
    if(special) return "E4M9";
    return "E4M3";
  } else if(!StrCmp(nm,"E4M3")) 
    return "E4M4";
  else if(!StrCmp(nm,"E4M4"))
    return "E4M5";
  else if(!StrCmp(nm,"E4M5"))
    return "E4M6";
  else if(!StrCmp(nm,"E4M6"))
    return "E4M7";
  else if(!StrCmp(nm,"E4M7")) 
    return "E4M8";
  else if(!StrCmp(nm,"E4M9")) 
    return "E4M3";
  //Intermission
  return NULL;
}
Bool in_level=FALSE;
#include"Finale.HC";
U0 PlayLevel(Bool init=TRUE) { 
  WinBorder;
  WinMax;
  DocClear;
  Bool transition=FALSE;
  CDoomThing *t,*head;
  U8 *next_lvl;
ent:;
  CDoomLevel *l2;
  if(init) {
    if(!transition) {
      p=PlayerNew(l);
    } else  {
      transition=FALSE;
      head=&l->things;
      for(t=head->next;t!=head;t=t->next) {
//https://doomwiki.org/wiki/Thing_types#Other
        if(t->thing_type==1) {
	  p->x=t->x;
	  p->y=t->y;
	  p->angle=t->angle;
	  QueIns(p,&l->things);
	  break;
        }
      }
    }
    PlayerMove(l,p,0);   
    InitLevel(l);
  }
//Return to parent instance  of PlayLevel(if recursivly called)
  //But be sure to initailize the level and player
  if(in_level) return;
  in_level=TRUE;
  I64 a,b;
  U64 mr;
  if(Fs->animate_task)
    Kill(Fs->animate_task,FALSE);
  Fs->animate_task=Spawn(&AnimateTask,NULL,"Animate",,Fs);
  Unpause;
  while(!l->ended) {
    UpdateCameraFromPlayer(&cam,p);
    DrawDoomWorld(&cam,l,doom_scrn);

    if(!paused) {
      AutomapInteract;

      if(am_state.active)
        DrawAutomap(gr.dc,l);
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
        if(weaponIndex!=0)
	  weapons.x_off=cursor_x-GR_WIDTH/2;
      }
#define SCRN_MARGIN 200
      #define SCRN_TURN_RATE (pi/1.5/30.)
      if(SCRN_MARGIN>cursor_x) {
        p->angle+=Lerp((SCRN_MARGIN-cursor_x)/ToF64(SCRN_MARGIN),0,SCRN_TURN_RATE);
      } else if(GR_WIDTH-SCRN_MARGIN<cursor_x) {
        p->angle-=Lerp((cursor_x-(GR_WIDTH-SCRN_MARGIN))/ToF64(SCRN_MARGIN),0,SCRN_TURN_RATE);
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
        if(Bt(kbd.down_bitmap,Char2ScanCode('a'))||Bt(kbd.down_bitmap,SC_CURSOR_LEFT)) {
	  p->running=Bt(kbd.down_bitmap,SC_SHIFT);
	  PlayerMove(l,p,1,pi/2);
	  UpdateCameraFromPlayer(&cam,p);
	  ST_Key(2);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('d'))||Bt(kbd.down_bitmap,SC_CURSOR_RIGHT)) {
	  p->running=Bt(kbd.down_bitmap,SC_SHIFT);
	  PlayerMove(l,p,1,-pi/2);
	  UpdateCameraFromPlayer(&cam,p);
	  ST_Key(1);
        }
        if(ms.lb) {
	  ST_Fire(p);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('1'))) {
	  SwapWeapon(p,1);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('2'))) {
	  SwapWeapon(p,2);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('3'))) {
	  SwapWeapon(p,3);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('4'))) {
	  SwapWeapon(p,4);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('5'))) {
	  SwapWeapon(p,5);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('6'))) {
	  SwapWeapon(p,6);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('7'))) {
	  SwapWeapon(p,7);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('8'))) {
	  SwapWeapon(p,8);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode('0'))) {
	  SwapWeapon(p,0);
        }
        if(Bt(kbd.down_bitmap,Char2ScanCode(' ')&0xff)) {
	  PressAWall(l,&p->x,p->angle,p->height);
        }
      }
//This accounts for key-press delay
      while((mr=ScanMsg(&a,&b))!=MSG_NULL) {
        if(mr==MSG_KEY_DOWN&&a==CH_ESC) {
	  paused=TRUE;
	  Refresh;
	  FlushMsgs; //Flush Esc msg
	  break;
        }
      }
    } else {
      mr=MainMenu;
      if(!mr) {
        Unpause;
      }
    }

    if(!paused)
      UpdateLevel(l);
    Refresh;
  }
ret:
  if(l->ended) Intermission(l,l->map_name[1]-'1',l->map_name[3]-'1');
  DCFill;
//Dont free the player,we will transfer him across the levels mofo
  transition=TRUE;
  QueRem(p);
//
  next_lvl=NextLevel(l->map_name);
  if(!next_lvl) {
    Finale(gr.dc,l->map_name[0]-'0');
    goto fin_level;
  }
  l2=LoadWadLevel(wad,next_lvl,l->skill);  
  FreeLevel(l);
  l=NULL;
  l=l2;
  in_level=FALSE;
  init=TRUE;
  goto ent;
fin_level:
  in_level=FALSE;
  return;
}
U0 CrushThinker(CDoomLevel *l,CCrushThinker *t) {
  F64 tar_dst;
  CDoomSector *s=t->s;
  CDoomThing **crushed=GetCrushedThingsInSector(l,s),*T;
  I64 idx;
//Maybe it was stopped
  if(s->cur_action_linedef) {
    QueRem(t);
    Free(t);
    return;
  }
  if(t->going_up) {
    tar_dst=s->base_ceil_height;
    s->ceil_height+=t->base_speed;
    if(s->ceil_height>=tar_dst) {
      s->ceil_height=tar_dst;
      t->going_up=FALSE;
    }
  } else {
    tar_dst=s->base_floor_height+8;
//Slow crushers will slow down by /8
    if(*crushed&&t->base_speed<=DOOR_SPEED_SLOW) {
      s->ceil_height-=t->base_speed/8;
    } else
      s->ceil_height-=t->base_speed;
    if(s->ceil_height<=tar_dst) {
      s->ceil_height=tar_dst;
      t->going_up=TRUE;
    }
  }
//About 4 times damages a second
  if(ToI64(tS*32)&0x7==0) {
    for(idx=0;T=crushed[idx];idx++) {
      DamageMob(l,T,NULL,5);
      SpawnBloodPuff(l,&T->x,T->height,5);
    }
  }
  Free(crushed);
}
U0 AddCrushThinker(CDoomLevel *l,CDoomSector *s,CDoomCrusher *c) {
  CCrushThinker *t=AddThinker(l,&CrushThinker,"CCrushThinker");
  t->base_speed=c->speed;
  t->s=s;
  t->going_up=FALSE;
}


#include "Save.HC";
U64 r;
while(TRUE) {
  DCFill;
  r=MainMenu;
  Refresh;
  if(!r) {
    DCFill;
    break;
  }
}
#endif        ‹         þÿÿÿ   þÿÿÿ   þÿÿÿ]   ›ÿÿÿ   üÿÿÿ   üÿÿÿ   üÿÿÿn      
!   Éÿÿÿ0   ûÿÿÿ
0   ûÿÿÿb   ðÿÿÿ
b   ðÿÿÿQ   ¼ÿÿÿ
Q   ¼ÿÿÿ   Êÿÿÿ 