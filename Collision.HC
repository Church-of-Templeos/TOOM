#ifndef COLLISION_H
#define COLLISION_H "Yunno wut I mean"
//Returns TRUE on collision
#define STEP_HEIGHT 24
#define COLLISF_CENTER_RADIUS 1

extern Bool MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=0,CFifoI64 *walked_over_hot=NULL);

Bool CrosesLine(CDoomLinedef *ld,CD2 *a,CD2 *b) {
  F64 v0=ld->end->x-ld->start->x;
  F64 v1=ld->end->y-ld->start->y;
  
  return (v0*(a->y-ld->start->y)-v1*(a->x-ld->start->x)<0.)!=
	(v0*(b->y-ld->start->y)-v1*(b->x-ld->start->x)<0.);
}

//https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
F64 DistFromLine(CD2 *p,CD2 *l1,CD2 *l2) {
  return Abs((l2->x-l1->x)*(l1->y-p->y)-(l2->y-l1->y)*(l1->x-p->x))/Sqrt(Sqr(l1->x-l2->x)+Sqr(l1->y-l2->y));
}
Bool AdjustForRadius(CDoomLevel *l,CDoomLinedef *ld,CD2 *point,F64 angle,F64 radius,F64 cur_h,F64 to_travel) {
  I64 i;
  CD2 closest_point,side,opoint;
  F64 ld_normal1,ld_normal2,angle2;
  F64 dist;
  F64 x,y;
  opoint.x=point->x;
  opoint.y=point->y;
  ld_normal1=FArg(ld->end->x-ld->start->x,ld->end->y-ld->start->y)+pi/2;
  ld_normal2=FArg(ld->end->x-ld->start->x,ld->end->y-ld->start->y)-pi/2;
  side.x=point->x+(radius)*FCos(ld_normal1);
  side.y=point->y+(radius)*FSin(ld_normal1);
  if(CrosesLine(ld,&side,point)) {
    dist=radius-DistFromLine(point,ld->start,ld->end);
    MoveInLevel(l,point,ld_normal1,-dist,radius,cur_h,0);
    angle2=ld_normal1-angle;
    x=-to_travel*FSin(angle2);
    MoveInLevel(l,point,ld_normal1+pi/2,x,radius,cur_h,0);
    return TRUE;
  } else{
    side.x=point->x+(radius)*FCos(ld_normal2);
    side.y=point->y+(radius)*FSin(ld_normal2);
    if(CrosesLine(ld,&side,point)) {
      dist=radius-DistFromLine(point,ld->start,ld->end);
      MoveInLevel(l,point,ld_normal2,-dist,radius,cur_h,0);
      angle2=ld_normal2-angle;
      x=-to_travel*FSin(angle2);
      MoveInLevel(l,point,ld_normal2+pi/2,x,radius,cur_h,0);
      return TRUE;
    }
  }
  return FALSE;
}

//walked_over_hot is "hot" linedefs that have a walkover action on them
CDoomLinedef *MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=COLLISF_CENTER_RADIUS,CFifoI64 *walked_over_hot=NULL) {
  if(dist<0) {
    dist=-dist;
    angle+=pi;
  }
  Vector *vector;
  Bool hit=FALSE;
  I64 blockx=(at->x-l->block_map_x_off)/128,i,try_cnt;
  I64 blocky=(at->y-l->block_map_y_off)/128,o,wall_idx;
  CD2 move1,move2,dummy,*result=at,push_back;
  CD2 orig,towards;
  F64 dist2=0,sin=Sin(angle),cos=Cos(angle),cap;
  F64 floor_height=0,ceil_height,odist=dist;
  F64 min_dist=I16_MAX,wall_angle,slope,off;
  CDoomLinedef *best=NULL;
  CDoomLinedef *walls[64],*walked_over[64];
  F64 walked_over_dists[64];
  I64 walked_over_idx=0;
  CDoomLinedef **lds,*wall;
  vector=CreateVector(2);
  move1.x=at->x,move1.y=at->y;
//We "dummy" move the length of the radius to check if our radius hits the wall
  dist+=radius;
  move2.x=at->x+dist*cos,move2.y=at->y+dist*sin;
  while(dist2<=dist+128) {
    if(!(0<=blockx<l->block_map_cols))
      break;
    if(!(0<=blocky<l->block_map_rows))
      break;
    i=0;
    o=l->block_map_offsets[
	  (blockx)+
	  (blocky)*l->block_map_cols];
    wall_idx=0;
    for(lds=l->block_map_data+o;*lds;lds++,i++) {
//TODO ceiling
      vector->data[0]=lds[0]->end->x-lds[0]->start->x;
      vector->data[1]=lds[0]->end->y-lds[0]->start->y;
      dummy.x=move1.x-lds[0]->start->x;
      dummy.y=move1.y-lds[0]->start->y;
      if(lds[0]->front^^lds[0]->back) {
        floor_height=I16_MAX;
        ceil_height=I16_MIN;
      } else{
//opposite side
        if(vector->data[0]*dummy.y-vector->data[1]*dummy.x<0.) {
	  floor_height=lds[0]->back->sector->floor_height;
	  ceil_height=lds[0]->back->sector->ceil_height;
        } else {
	  floor_height=lds[0]->front->sector->floor_height;
	  ceil_height=lds[0]->front->sector->ceil_height;
        }
      }
//https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
      if(floor_height-STEP_HEIGHT>cur_height||ceil_height-64<=cur_height||floor_height==ceil_height) {
        if(wall_idx<64)
	  walls[wall_idx++]=*lds;
        if(PlaneIntersect(result,&move1,&move2,lds[0]->start,lds[0]->end)) {
	  dist=Sqrt(Sqr(result->x-move1.x)+Sqr(result->y-move1.y));
	  if(dist<min_dist) {
	    best=lds[0];
	    min_dist=dist;
	  }
        }
      } else {
//W1/WR
        if(lds[0]->special_type) {
	  if(lds[0]->special_type->type=='Door'
		||lds[0]->special_type->type=='Floor'
		||lds[0]->special_type->type=='Lift') {
	    if(walked_over_idx<64) {
	      if(PlaneIntersect(result,&move1,&move2,lds[0]->start,lds[0]->end))  {
	        walked_over_dists[walked_over_idx]=Sqrt(Sqr(result->x-move1.x)+Sqr(result->y-move1.y));
	        walked_over[walked_over_idx++]=*lds;
	      }
	    }
	  }
        }
      }
skip:;
    }
    dist2+=64;
    blockx=(dist2*cos+move1.x-l->block_map_x_off)/128;
    blocky=(dist2*sin+move1.y-l->block_map_y_off)/128;
  }
  if(best) {
    dist=min_dist;
    if(min_dist<=radius) {
      dist=0.;
      result->x=move1.x;
      result->y=move1.y;
      goto fin;
    }
  }
  result->x=move1.x+cos*(dist-radius);
  result->y=move1.y+sin*(dist-radius);
fin:
  if(!best&&walked_over_hot) {
    min_dist=I16_MAX;
    goto look_for_hot;
  } else if(best&&walked_over_hot) {
look_for_hot:
    while(--walked_over_idx>=0) {
      if(walked_over_dists[walked_over_idx]<min_dist) {
        FifoI64Ins(walked_over_hot,walked_over[walked_over_idx]);
      }
    }
  }
  if(flags&COLLISF_CENTER_RADIUS) {
    try_cnt=0;
    if(best) AdjustForRadius(l,best,result,angle,radius,cur_height,Max(odist-dist,0.));
try_again:
    hit=FALSE;
    for(i=0;i!=wall_idx;i++) {
      hit|=AdjustForRadius(l,walls[i],result,angle,radius,cur_height,0);
    }
    if(hit&&try_cnt++<8)
      goto try_again;
  }
  DestroyVector(vector);
  return best;
}
#endif