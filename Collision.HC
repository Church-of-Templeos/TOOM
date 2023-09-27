#ifndef COLLISION_H
#define COLLISION_H "Yunno wut I mean"
//Returns TRUE on collision
#define STEP_HEIGHT 24
#define COLLISF_CENTER_RADIUS 1
#define COLLISF_ONLY_MOVE_ON_COLLIDE 2
//https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
F64 ClosestDist(CD2 *a,CD2 *b,CD2 *point) {
  return Abs((b->x-a->x)*(a->y-point->y)-(b->y-a->y)*(a->x-point->x))/Sqrt(Sqr(a->x-b->x)+Sqr(a->y-b->y));
}
U0 AdjustForRadius(CDoomLinedef **list,CD2 *point,F64 back_angle,F64 radius) {
  I64 i;
  CD2 closest_point;
  F64 dist;
  F64 x,y;
  for(i=0;list[i];i++) {
    dist=ClosestDist(list[i]->start,list[i]->end,point);
    if(dist<radius) {
       point->x+=(radius-dist)*Cos(back_angle);
       point->y+=(radius-dist)*Sin(back_angle);
    }
  }
}

Bool MoveInLevel(CDoomLevel *l,CD2 *at,F64 angle,F64 dist,F64 radius=64.,F64 cur_height=0.,I64 flags=COLLISF_CENTER_RADIUS) {
  if(dist<0) {
    dist=-dist;
    angle+=pi;
  }
  Vector *vector;
  Bool hit=FALSE;
  I64 blockx=(at->x-l->block_map_x_off)/128,i;
  I64 blocky=(at->y-l->block_map_y_off)/128,o;
  CD2 move1,move2,dummy,*result=at,push_back;
  CD2 orig;
  F64 dist2=0,sin=Sin(angle),cos=Cos(angle),cap;
  F64 floor_height=0,ceil_height;
  F64 min_dist=I16_MAX;
  CDoomLinedef *best=NULL;
  CDoomLinedef **lds;
  vector=CreateVector(2);
  move1.x=at->x,move1.y=at->y;
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
    for(lds=l->block_map_data+o;*lds;lds++,i++) {
//TODO ceiling
      if(lds[0]->front^^lds[0]->back) {
        floor_height=I16_MAX;
        ceil_height=I16_MIN;
      } else{
        vector->data[0]=lds[0]->end->x-lds[0]->start->x;
        vector->data[1]=lds[0]->end->y-lds[0]->start->y;
        dummy.x=move1.x-lds[0]->start->x;
        dummy.y=move1.y-lds[0]->start->y;
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
        if(PlaneIntersect(result,&move1,&move2,lds[0]->start,lds[0]->end)) {
	  dist=Sqrt(Sqr(result->x-move1.x)+Sqr(result->y-move1.y));
	  if(dist<min_dist) {
	    best=lds[0];
	    min_dist=dist;
	  }
        }
      }
    }
    dist2+=64;
    blockx=(dist2*cos+move1.x-l->block_map_x_off)/128;
    blocky=(dist2*sin+move1.y-l->block_map_y_off)/128;
  }
  if(best) {
    dist=min_dist;
    dist-=radius;
    if(dist<0.) dist=0.;
    result->x=move1.x+cos*dist;
    result->y=move1.y+sin*dist;
  } else{
     result->x=move1.x+cos*dist;
     result->y=move1.y+sin*dist;
  }
  return !!best;
  if(COLLISF_ONLY_MOVE_ON_COLLIDE&flags) {
    result->x=move1.x;
    result->y=move1.y;
  } else {
    result->x=move2.x;
    result->y=move2.y;
  }
  DestroyVector(vector);
  return FALSE;
}
#endif