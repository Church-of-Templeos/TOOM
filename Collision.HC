#ifndef COLLISION_H
#define COLLISION_H "Yunno wut I mean"
//Returns TRUE on collision
#define STEP_HEIGHT 24.
#define COLLISF_SLIDE 1
#define COLLISF_NO_DROP 2
#define COLLISF_NO_HIT_THING 4
#define COLLISF_MONSTER 8
#define COLLISF_ADJUST_FOR_RADIUS 0x10
extern Bool MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=0,CFifoI64 *walked_over_hot=NULL,CDoomThing *exclude=NULL);

//https://stackoverflow.com/questions/14176776/find-out-if-2-lines-intersect
Bool CrosesLine(CDoomLinedef *ld,CD2 *a,CD2 *b) {
  CD2 st,en;
  st.x=ld->start->x;
  st.y=ld->start->y;
  en.x=ld->end->x;
  en.y=ld->end->y;
  return PlaneIntersect(NULL,a,b,ld->start,ld->end);
/*
  F64 angle=FArg(en.x-st.x,en.y-st.y);
  F64 bbl_t=Max(a->y,b->y)+1.;
  F64 bbl_b=Min(a->y,b->y)-1.;
  F64 bbl_r=Max(a->x,b->x)+1.;
  F64 bbl_l=Min(a->x,b->x)-1.;

  F64 bbld_t=Max(st.y,en.y)+1.;
  F64 bbld_b=Min(st.y,en.y)-1.;
  F64 bbld_r=Max(st.x,en.x)+1.;
  F64 bbld_l=Min(st.x,en.x)-1.;

  if(bbl_r<=bbld_l
	||bbld_l>=bbl_r
        ||bbl_t<=bbld_b
        ||bbld_b>=bbld_t
	)
    return FALSE;
  return (((a->x-st.x)*(en.y-st.y) - (a->y-st.y)*(en.x-st.x))
  * ((b->x-st.x)*(en.y-st.y) - (b->y-st.y)*(en.x-st.x)) < 0.)
  &&
        (((st.x-a->x)*(b->y-a->y) - (st.y-a->y)*(b->x-a->x))
  * ((en.x-a->x)*(b->y-a->y) - (en.y-a->y)*(b->x-a->x)) < 0.);
*/
}

//https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
F64 DistFromLine(CD2 *p,CD2 *l1,CD2 *l2) {
  return Abs((l2->x-l1->x)*(l1->y-p->y)-(l2->y-l1->y)*(l1->x-p->x))/Sqrt(Sqr(l1->x-l2->x)+Sqr(l1->y-l2->y));
}

Bool CheckLineWithBox(CDoomLinedef *ld,CD2 *at,F64 radius) {
  CD2 tl,tr,bl,br;
  tl.x=at->x-radius; 
  bl.x=at->x-radius;
  tr.x=at->x+radius;
  br.x=at->x+radius;
  tl.y=at->y+radius;
  tr.y=at->y+radius;
  bl.y=at->y-radius;
  br.y=at->y-radius;
  return CrosesLine(ld,&tl,&tr)||
	CrosesLine(ld,&tr,&br)||
	CrosesLine(ld,&br,&bl)||
	CrosesLine(ld,&tl,&bl);
}

//Sort of from here
//https://www.sevenson.com.au/programming/sat/
Bool CloseToLine(CD2 *tip=NULL,CD2 *p1,CD2 *p2,CD2 *at,F64 radius) {
  I64 idx;
  F64 magnitude,ax,ay,p1min,p1max,dot,p2min,p2max,a;
  magnitude=Sqrt(Sqr(p2->x-p1->x)+Sqr(p2->y-p1->y));
  ax=p2->x-p1->x;
  ay=p2->y-p1->y;
  if(magnitude>0.) {
    ax*=1/magnitude;
    ay*=1/magnitude;
  }

  p1min=ax*at->x+ay*at->y;
  p1max=p1min;

  dot=ax*p1->x+ay*p1->y;
  p2min=dot;
  p2max=dot;

  dot=ax*p2->x+ay*p2->y;
  p2min=Min(p2min,dot);
  p2max=Max(p2max,dot);

//Check for overlap
//https://stackoverflow.com/questions/3269434/whats-the-most-efficient-way-to-test-if-two-ranges-overlap
  if(Max(p2min-radius,p1min)<=Min(p2max+radius,p1max)) {
    if(DistFromLine(at,p1,p2)<radius) {
      if(tip) {
	magnitude=p1min-p2min;
	a=FArg(p2->x-p1->x,p2->y-p1->y);
	tip->x=p1->x+FCos(a)*magnitude;
	tip->y=p1->y+FSin(a)*magnitude;
	tip->x+=FCos(a+pi/2)*radius;
	tip->y+=FSin(a+pi/2)*radius;
      }
      return TRUE;
    }
  }
  return FALSE;
}

F64 IntersectDist(CDoomLinedef *ld,CD2 *a,CD2 *b) {
//I will use a divine heuristic(Ask God how this works),see InterceptVector from doom3do
  F64 dx1=ld->end->x-ld->start->x;
  F64 dy1=ld->end->y-ld->start->y;
  F64 dx2=a->x-b->x;
  F64 dy2=a->y-b->y;
  F64 den=dy2*dx1,num;
  den-=dx2*dy1;
  if(den==0.) return -1.;
  num=(a->x-ld->start->x)*dy2;
  num+=(a->y-ld->start->y)*dx2;
  return num/den;
  /*F64 d1=DistFromLine(a,ld->start,ld->end),final;
  F64 angle_ld=FArg(ld->end->x-ld->start->x,ld->end->y-ld->start->y);
  F64 angle_move=FArg(b->x-a->x,b->y-a->y);
  F64 angle;
//Check what side of the line we on
  if((ld->end->x-ld->start->x)*(a->y-ld->start->y)-(ld->end->y-ld->start->y)*(a->x-ld->start->x)>0.) {
    angle=angle_move-(angle_ld-pi/2); //Normal of vector
  } else {
    angle=angle_move-(angle_ld+pi/2); //Other Normal of vector
  }
  return d1/FCos(angle);*/
}

Bool SlideWalk(CDoomLevel *l,CDoomLinedef *ld,CD2 *point,F64 angle,F64 radius,F64 cur_h,F64 to_travel,CDoomThing *exclude) {
  I64 i;
  CD2 closest_point,side,rel_point;
  F64 ld_normal1,ld_normal2,angle2;
  F64 dist;
  F64 x,y;
  angle2=FArg(closest_point.x-point->x,closest_point.y-point->y);
  Vector *v=CreateVector(2);
  v->data[0]=ld->end->x-ld->start->x;
  v->data[1]=ld->end->y-ld->start->y;
  rel_point.x=point->x-ld->start->x;
  rel_point.y=point->y-ld->start->y;
  ld_normal1=FArg(ld->end->x-ld->start->x,ld->end->y-ld->start->y)+pi/2;
  ld_normal2=FArg(ld->end->x-ld->start->x,ld->end->y-ld->start->y)-pi/2;
  if(IsFrontSideOfVector2D(v,&rel_point)) {
    angle2=ld_normal1-angle;
    x=-to_travel*FSin(angle2);
    MoveInLevel(l,point,ld_normal1+pi/2,x,radius,cur_h,COLLISF_ADJUST_FOR_RADIUS|COLLISF_NO_HIT_THING);
  } else{
    dist=radius-DistFromLine(point,ld->start,ld->end);
    angle2=ld_normal2-angle;
    x=-to_travel*FSin(angle2);
    MoveInLevel(l,point,ld_normal2+pi/2,x,radius,cur_h,COLLISF_ADJUST_FOR_RADIUS|COLLISF_NO_HIT_THING);
  }
  DestroyVector(v);
}

CDoomThing *HitsAThing(CDoomLevel *l,CD2 *dummy,CDoomThing *exclude=NULL,CDoomThing *test_for=NULL) {
  F64 ceil_height,bbt_l,bbt_r,bbt_t,bbt_b;
  CDoomThing *cur,*head=&l->things,*max=NULL;
  F64 min_dist=I16_MAX,dist;
  if(test_for) {
    cur=test_for;
    goto enter;
  }
  for(cur=head->next;cur!=head;cur=cur->next) {
enter:
    bbt_l=cur->x-cur->template->radius;
    bbt_r=cur->x+cur->template->radius;
    bbt_b=cur->y-cur->template->radius;
    bbt_t=cur->y+cur->template->radius;
    if(exclude!=cur&&cur->flags&TF_OBSTACLE) {
      if(bbt_l<=dummy->x<=bbt_r)
        if(bbt_b<=dummy->y<=bbt_t) {
	  dist=Sqrt(Sqr(cur->x-dummy->x)+Sqr(cur->y-dummy->y));
	  if(dist<min_dist) {
	    max=cur;
	    min_dist=dist;
	  }
	}
      }
    if(test_for)
      break;
  }
  return max;
}

//Make sure no walls in way of the Glizzy shot









$SP,"<1>",BI=1$


//Returns apporixmate (wall) hit distance,or -1. if the shoot Pushin-P Pwned the target
F64 ValidateLineOfSightShot(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 source_h,F64 target_h) {
  CD2 dummy;
  Bool hit_wall=FALSE;
  I64 blockx,blocky;
  CDoomLinedef **lds;
  F64 dist2=0.,sin=Sin(angle),cos=Cos(angle);
  F64 diff;
  F64 vslope=(target_h-source_h)/dist;
  F64 ceil_height,floor_height;
  dummy.x=at->x,dummy.y=at->y;
  while(dist2<=dist) {
    blocky=(dummy.y-l->block_map_y_off)/128;
    blockx=(dummy.x-l->block_map_x_off)/128;
    if(dist2+8<=dist) {
      dist2+=8.; //Smallest radius??>
      source_h+=8.*vslope;
      dummy.x+=8.*cos;   
      dummy.y+=8.*sin;
    } else {
      diff=dist-dist2;
      source_h+=diff*vslope;
      dummy.x+=diff*cos;   
      dummy.y+=diff*sin;
      dist2=dist+.1;
    }
    if(0<=blockx<l->block_map_cols)
      if(0<=blocky<l->block_map_rows) {
        lds=l->block_map_data+l->block_map_offsets[
	      blockx+
	      blocky*l->block_map_cols];
        for(;*lds;lds++) {
	  if(lds[0]->front^^lds[0]->back) {
	    ceil_height=I16_MAX;
	    floor_height=I16_MAX;
	  } else {
	    floor_height=Max(lds[0]->back->sector->floor_height,
		  lds[0]->front->sector->floor_height);
	    ceil_height=Min(lds[0]->back->sector->ceil_height,
		  lds[0]->front->sector->ceil_height);
	  }
	  if(!(floor_height<=source_h<=ceil_height))
	    while(CrosesLine(*lds,at,&dummy)&&dist2>0.) {
	      hit_wall=TRUE;
//get a more "precise" wall hit positon,homie
	      dummy.x=at->x+dist2*cos;
	      dummy.y=at->y+dist2*sin;
	      dist2-=1.;;

	    }
	  if(hit_wall) {
	    return Min(dist2,dist);
	  }
        }
      }
  }
  return -1.;
}



//
// Shoot_h  MUST BE OFF THE GROUND,it is the height the shot is fired out
// 

CDoomThing *ShotSmacksAHomie(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 shoot_h,CDoomThing *exclude=NULL) {
  if(dist<0) {
    dist=-dist;
    angle+=pi;
  }
  CDoomThing *head=&l->things,*cur,*closest=NULL;
  CD2 dummy;
  I64 blockx,blocky;
  CDoomLinedef **lds;
  F64 wall_dist;
  F64 dist2=0.,sin=Sin(angle),cos=Cos(angle),cd,closest_dist=I16_MAX;
  F64 bbt_l,bbt_r,bbt_t,bbt_b,ceil_height,floor_height;
  dummy.x=at->x,dummy.y=at->y;
  for(cur=head->next;cur!=head;cur=cur->next) {
    if(cur==exclude||!(cur->flags&TF_SHOOTABLE)||(cur->health<=0.))
      goto next;
    wall_dist=ValidateLineOfSightShot(l,at,angle,
	  (cd=Sqrt(Sqr(cur->x-at->x)+Sqr(cur->y-at->y)))*1.5, //1.5 for partly missed angle
	  shoot_h,
	  cur->height+cur->template->height-2
	  );
    if(wall_dist==-1||wall_dist>cd*1.5) {
      do {
        dummy.x=at->x+wall_dist*cos;
        dummy.y=at->y+wall_dist*cos;
	if(HitsAThing(l,&dummy,NULL,cur))
	  break;
        wall_dist-=cur->template->radius/2.+1;
      } while(wall_dist>=0.);
      if(cd<closest_dist) {
        closest=cur;
        closest_dist=wall_dist;
      }
    }
next:;
  }
  return closest;
}


//walked_over_hot is "hot" linedefs that have a walkover action on them
CDoomLinedef *MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=COLLISF_SLIDE,CFifoI64 *walked_over_hot=NULL,CDoomThing *exclude=NULL) {
  if(dist<0) {
    dist=-dist;
    angle+=pi;
  }
  Vector *vector;
  Bool hit=FALSE;
  I64 blockx=(at->x-l->block_map_x_off)/128,i,try_cnt;
  I64 blocky=(at->y-l->block_map_y_off)/128,o,wall_idx;
  CD2 move1,move2,dummy,*result=at,push_back,cur_pos,move_fat;
  CD2 orig,towards;
  F64 dist2=0,sin=Sin(angle),cos=Cos(angle),cap=dist;
  F64 floor_height=0,ceil_height,odist=dist,best_dist;
  F64 min_dist=I16_MAX,wall_angle,slope,off,tmp,max_dist,step;
  F64 last_good=0.;
  CDoomLinedef *best=NULL;
  CDoomLinedef *walls[64],*walked_over[64];
  CDoomSector *s;
  F64 walked_over_dists[64];
  I64 walked_over_idx=0;
  I64 xoff,yoff,try_wall;
  CDoomLinedef **lds,*wall;
  CDoomThing *hit_thing=NULL;
  vector=CreateVector(2);
  move1.x=at->x,move1.y=at->y;
//Add dummy length for radius
  move2.x=at->x+dist*cos,move2.y=at->y+dist*sin;
  dist+=radius;
  move_fat.x=at->x+dist*cos,move_fat.y=at->y+dist*sin;
  cur_pos.x=move1.x;
  cur_pos.y=move1.y;
  wall_idx=0;
  while(dist2<=dist+128) {
    for(xoff=-1;xoff<=1;xoff++)
      for(yoff=-1;yoff<=1;yoff++)
        if(0<=blockx+xoff<l->block_map_cols)
	  if(0<=blocky+yoff<l->block_map_rows) {
	    i=0;
	    o=l->block_map_offsets[
		  (blockx+xoff)+
		  (blocky+yoff)*l->block_map_cols];
	    for(lds=l->block_map_data+o;*lds;lds++,i++) {
//TODO ceiling
	      if(lds[0]->flags&WAD_LINEDEFF_WALL)
	        goto fail_walk;
	      if(lds[0]->flags&WAD_LINEDEFF_WALL_MONSTER&&flags&COLLISF_MONSTER)
	        goto fail_walk;
	      vector->data[0]=lds[0]->end->x-lds[0]->start->x;
	      vector->data[1]=lds[0]->end->y-lds[0]->start->y;
	      dummy.x=move1.x-lds[0]->start->x;
	      dummy.y=move1.y-lds[0]->start->y;
	      if(lds[0]->front^^lds[0]->back) {
	        ceil_height=I16_MAX;
	        floor_height=I16_MAX;
	      } else {
	        floor_height=Max(lds[0]->back->sector->floor_height,
		      lds[0]->front->sector->floor_height);
	        ceil_height=Min(lds[0]->back->sector->ceil_height,
		      lds[0]->front->sector->ceil_height);
	      }
//https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
	      if(floor_height-STEP_HEIGHT>cur_height||ceil_height-56.<=cur_height||floor_height==ceil_height) {
fail_walk:
	        if(wall_idx<64)
		  walls[wall_idx++]=*lds;
	        if(CrosesLine(lds[0],&move1,&move_fat)) {
		  tmp=IntersectDist(lds[0],&move1,&move2);
		  if(tmp<min_dist) {
		    best=lds[0];
		    min_dist=tmp;
		    cap=dist2;
		  }
	        }
	      } else {
//If we must not fall off the wall,we gunna check if we not fallin off a walk
	        if(flags&COLLISF_NO_DROP&&(lds[0]->back&&lds[0]->front)) {
		  dummy.x=cur_pos.x-lds[0]->start->x;
		  dummy.y=cur_pos.y-lds[0]->start->y;
		  if(IsFrontSideOfVector2D(vector,&dummy)) {
		    floor_height=lds[0]->back->sector->floor_height;
		  } else
		    floor_height=lds[0]->front->sector->floor_height;
		  if(floor_height+STEP_HEIGHT<cur_height)
		    goto fail_walk;
	        }
//W1/WR
	        if(lds[0]->special_type) {
		  if(lds[0]->special_type->type=='Door'
		        ||lds[0]->special_type->type=='Floor'
		        ||lds[0]->special_type->type=='Lift'
		        ||lds[0]->special_type->type=='Ceil') {
		    if(walked_over_idx<64) {
		      if(CrosesLine(lds[0],&move1,&move2))  {
		        tmp=IntersectDist(lds[0],&move1,&move2);
		        walked_over_dists[walked_over_idx]=tmp;
		        walked_over[walked_over_idx++]=*lds;
		      }
		    }
		  }
	        }
	      }
	    }
skip:;
	  }

	  //Things take less precednece than walls
    if(flags&COLLISF_NO_HIT_THING)
      if(hit_thing=HitsAThing(l,&cur_pos,exclude))  {
//NOSLIDING agianst things
	flags&=~COLLISF_SLIDE;
        break;
      }
    dist2+=radius/2;
    cur_pos.x=move1.x+cos*dist2;
    cur_pos.y=move1.y+sin*dist2;
    blockx=(dist2*cos+move1.x-l->block_map_x_off)/128;
    blocky=(dist2*sin+move1.y-l->block_map_y_off)/128;
  }
  if(best) {
    dist=0.;
    result->x=move1.x;
    result->y=move1.y;
  } else if(hit_thing) {
//Make a dummy linedef that will block the things from transgrsseing
    static CDoomLinedef dummy_ld;
    static CDoomSidedef dummy_sd;
    static CD2 dummy_ld_s,dummy_ld_e;
    MemSet(&dummy_ld,0,sizeof CDoomLinedef);
    dummy_ld.flags=3; //Block moonsters and players
    dummy_ld_s.x=hit_thing->x-Cos(angle+pi/4)*hit_thing->template->radius;
    dummy_ld_s.y=hit_thing->y-Sin(angle+pi/4)*hit_thing->template->radius;
    dummy_ld_e.x=hit_thing->x+Cos(angle+pi/4)*hit_thing->template->radius;
    dummy_ld_e.y=hit_thing->y+Sin(angle+pi/4)*hit_thing->template->radius;
    dummy_ld.start=&dummy_ld_s;
    dummy_ld.end=&dummy_ld_e;
    dummy_ld.front=&dummy_sd; //Make a 1 sided(solid) sidedef
    best=&dummy_ld;
    min_dist=0;

    dist=0.;
    result->x=move1.x;
    result->y=move1.y;
  } else if(dist-radius>=1.) {
    result->x=move1.x+cos*(dist-radius);
    result->y=move1.y+sin*(dist-radius);
  }
  cur_pos.x=result->x;
  cur_pos.y=result->y;
fin:
  dist=Clamp(cap+radius,0.,odist);
  while(dist>0.) {
    cur_pos.x=move1.x+cos*dist;
    cur_pos.y=move1.y+sin*dist;
    for(i=0;i!=wall_idx;i++) {
      if(CheckLineWithBox(walls[i],&cur_pos,radius))
        goto found;
    }
    result->x=cur_pos.x;
    result->y=cur_pos.y;
    break;
found:
    dist-=1;
  }
  if(flags&COLLISF_SLIDE&&best) {
    if(dist>0.)
      odist=odist-dist;
    SlideWalk(l,best,result,angle,radius,cur_height,odist,exclude);
  }
  if(!best&&walked_over_hot) {
    min_dist=I16_MAX;
    goto look_for_hot;
  } else if(best&&walked_over_hot) {
look_for_hot:
    if(walked_over_hot)
      while(--walked_over_idx>=0) {
        if(walked_over_dists[walked_over_idx]<min_dist) {
	  FifoI64Ins(walked_over_hot,walked_over[walked_over_idx]);
        }
      }
  }
//Final test,ensure the final destination is within step distance
  if(s=GetSectorForCoord(l,result->x,result->y)) {
    if(s->floor_height>cur_height+STEP_HEIGHT) {
      dist=0;
      result->x=move1.x;
      result->y=move1.y;
    }
  }

  DestroyVector(vector);
  return best;
}
#endif
        0                    "      '         !      !   õÿÿÿ   .   ÷ÿÿÿ   ÷ÿÿÿ   ,      ³   ×ÿÿÿ   -   ûÿÿÿ.   ñÿÿÿ;   ñÿÿÿ   ¨   áÿÿÿ¦      º      µ   Üÿÿÿ§   áÿÿÿ   º   ÜÿÿÿÃ   ÓÿÿÿÈ   Ûÿÿÿ   Á   ÒÿÿÿÁ   Äÿÿÿ   Ê   Èÿÿÿ¶   Çÿÿÿ   ¹   ÁÿÿÿÌ   ÅÿÿÿÌ   »ÿÿÿ¶   ¹ÿÿÿº   Áÿÿÿ   êÿÿÿ    