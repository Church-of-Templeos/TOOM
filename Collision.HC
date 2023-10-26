#ifndef COLLISION_H
#define COLLISION_H "Yunno wut I mean"
//Returns TRUE on collision
#define STEP_HEIGHT 24.
#define COLLISF_SLIDE 1
#define COLLISF_NO_DROP 2
extern Bool MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=0,CFifoI64 *walked_over_hot=NULL);
//https://stackoverflow.com/questions/14176776/find-out-if-2-lines-intersect
Bool CrosesLine(CDoomLinedef *ld,CD2 *a,CD2 *b) {
  CD2 st,en;
  st.x=ld->start->x;
  st.y=ld->start->y;
  en.x=ld->end->x;
  en.y=ld->end->y;
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
}

//https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
F64 DistFromLine(CD2 *p,CD2 *l1,CD2 *l2) {
  return Abs((l2->x-l1->x)*(l1->y-p->y)-(l2->y-l1->y)*(l1->x-p->x))/Sqrt(Sqr(l1->x-l2->x)+Sqr(l1->y-l2->y));
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

Bool SlideWalk(CDoomLevel *l,CDoomLinedef *ld,CD2 *point,F64 angle,F64 radius,F64 cur_h,F64 to_travel) {
  I64 i;
  CD2 closest_point,side,rel_point;
  F64 ld_normal1,ld_normal2,angle2;
  F64 dist;
  F64 x,y;
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
    MoveInLevel(l,point,ld_normal1+pi/2,x,radius,cur_h,0);
  } else{
    dist=radius-DistFromLine(point,ld->start,ld->end);
    angle2=ld_normal2-angle;
    x=-to_travel*FSin(angle2);
    MoveInLevel(l,point,ld_normal2+pi/2,x,radius,cur_h,0);
  }
  DestroyVector(v);
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
  F64 vslope=Tan((target_h-source_h)/dist);
  F64 ceil_height,floor_height;
  dummy.x=at->x,dummy.y=at->y;
  while(dist2<=dist) {
    blocky=(dummy.y-l->block_map_y_off)/128;
    blockx=(dummy.x-l->block_map_x_off)/128;
    dist2+=16.; //Smallest radius??>
    source_h+=16.*vslope;
    dummy.x+=16.*cos;   
    dummy.y+=16.*sin;
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
	      return dist2;
	    }
        }
      }
  }
  return -1.;
}



//
// Shoot_h  MUST BE OFF THE GROUND,it is the height the shot is fired out
// 

CDoomThing *ShotSmacksAHomie(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 shoot_h) {
  if(dist<0) {
    dist=-dist;
    angle+=pi;
  }
  CDoomThing *head=&l->things,*cur;
  CD2 dummy;
  I64 blockx,blocky;
  CDoomLinedef **lds;
  F64 wall_dist;
  F64 dist2=0.,sin=Sin(angle),cos=Cos(angle);
  F64 bbt_l,bbt_r,bbt_t,bbt_b,ceil_height,floor_height;
  dummy.x=at->x,dummy.y=at->y;
  while(dist2<=dist) {
    blocky=(dummy.y-l->block_map_y_off)/128;
    blockx=(dummy.x-l->block_map_x_off)/128;
    dist2+=16.; //Smallest radius??>
    dummy.x+=16.*cos;   
    dummy.y+=16.*sin;
    for(cur=head->next;cur!=head;cur=cur->next) {
      bbt_l=cur->x-cur->template->radius/2.;
      bbt_r=cur->x+cur->template->radius/2.;
      bbt_b=cur->y-cur->template->radius/2.;
      bbt_t=cur->y+cur->template->radius/2.;
      if(bbt_l<=dummy.x<=bbt_r)
        if(bbt_b<=dummy.y<=bbt_t) {
	  wall_dist=ValidateLineOfSightShot(l,at,angle,
	        Sqrt(Sqr(cur->x-at->x)+Sqr(cur->y-at->y)),
	        shoot_h,
	        cur->height+cur->template->height/2.
	        );
	  if(wall_dist<0.)
	    return cur;
        }
    }
  }
  return NULL;
}
//walked_over_hot is "hot" linedefs that have a walkover action on them
CDoomLinedef *MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=COLLISF_SLIDE,CFifoI64 *walked_over_hot=NULL) {
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
  F64 dist2=0,sin=Sin(angle),cos=Cos(angle),cap;
  F64 floor_height=0,ceil_height,odist=dist,best_dist;
  F64 min_dist=I16_MAX,wall_angle,slope,off,tmp,max_dist,step;
  CDoomLinedef *best=NULL;
  CDoomLinedef *walls[64],*walked_over[64];
  F64 walked_over_dists[64];
  I64 walked_over_idx=0;
  I64 xoff,yoff,try_wall;
  CDoomLinedef **lds,*wall;
  vector=CreateVector(2);
  move1.x=at->x,move1.y=at->y;
//Add dummy length for radius
  move2.x=at->x+dist*cos,move2.y=at->y+dist*sin;
  dist+=radius;
  move_fat.x=at->x+dist*cos,move_fat.y=at->y+dist*sin;
  cur_pos.x=move1.x;
  cur_pos.y=move1.y;
  while(dist2<=dist+128) {
    for(xoff=-1;xoff<=1;xoff++)
      for(yoff=-1;yoff<=1;yoff++)
        if(0<=blockx+xoff<l->block_map_cols)
	  if(0<=blocky+yoff<l->block_map_rows) {
	    i=0;
	    o=l->block_map_offsets[
		  (blockx+xoff)+
		  (blocky+yoff)*l->block_map_cols];
	    wall_idx=0;
	    for(lds=l->block_map_data+o;*lds;lds++,i++) {
//TODO ceiling
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
	        if(CrosesLine(lds[0],&move1,&move_fat)&&CrosesLine(lds[0],&move1,&move2)) {
		  tmp=IntersectDist(lds[0],&move1,&move2);
		  if(tmp<min_dist) {
		    best=lds[0];
		    min_dist=tmp;
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
    dist2+=64;
    cur_pos.x=move1.x+cos*dist2;
    cur_pos.y=move1.y+sin*dist2;
    blockx=(dist2*cos+move1.x-l->block_map_x_off)/128;
    blocky=(dist2*sin+move1.y-l->block_map_y_off)/128;
  }
  if(best) {
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
  if(flags&COLLISF_SLIDE&&best)
    SlideWalk(l,best,result,angle,radius,cur_height,odist);
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
  DestroyVector(vector);
  return best;
}
#endif
        0                    "      '         !      !   õÿÿÿ   .   ÷ÿÿÿ   ÷ÿÿÿ   ,      ³   ×ÿÿÿ   -   ûÿÿÿ.   ñÿÿÿ;   ñÿÿÿ   ¨   áÿÿÿ¦      º      µ   Üÿÿÿ§   áÿÿÿ   º   ÜÿÿÿÃ   ÓÿÿÿÈ   Ûÿÿÿ   Á   ÒÿÿÿÁ   Äÿÿÿ   Ê   Èÿÿÿ¶   Çÿÿÿ   ¹   ÁÿÿÿÌ   ÅÿÿÿÌ   »ÿÿÿ¶   ¹ÿÿÿº   Áÿÿÿ   êÿÿÿ    