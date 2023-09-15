Bool InRange(F64 low,F64 x,F64 high) {
  if(low<high)
    return low-.05<=x<=high+.05;
  return high-.05<=x<=low+.05;
}

Bool PlaneIntersect(CD2 *dst,CD2 *a,CD2 *b,CD2 *a2,CD2 *b2) {  
/*
* Nroot here,Heres the deal,I make a system of 2 linear equations and solve for an intersect
* I solve for the intersect and check if they are in bounds of points

Check for intersection basically.

     /
----*------
   / 
  /
 /
*/
  F64 slope1,slope2,off1,off2;
  CD2 dummy;
  if(!dst) dst=&dummy;
//If the line points straight up,we can check to see if the other
  //line goes through the y position,if so,it is a hit
  if((b->x==a->x)||(b2->x==a2->x)) {
    if(a->x==b->x&&a2->x==b2->x) {
      if(a->x==a2->x) {
        dst->x=a->x;
        dst->y=a->y;
	goto fin;
      } else
	return FALSE;
    }
    if(a->x==b->x) {
      dst->x=a->x;
      slope2=(b2->y-a2->y)/(b2->x-a2->x);
      dst->y=slope2*(dst->x-a2->x)+a2->y;
      goto fin;
    }
    if(a2->x==b2->x) {
      dst->x=a2->x;
      slope1=(b->y-a->y)/(b->x-a->x);
      dst->y=slope1*(dst->x-a->x)+a->y;
      goto fin;
    }
    goto fin;
  }
//https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection
  slope2=(b2->y-a2->y)/(b2->x-a2->x);
  slope1=(b->y-a->y)/(b->x-a->x);
  off1=slope1*-a->x+a->y;
  off2=slope2*-a2->x+a2->y;
  dst->x=((off2-off1)/(slope1-slope2));
  dst->y=slope1*(dst->x)+off1;
fin:
  return InRange(a->x,dst->x,b->x)&&
        InRange(a2->x,dst->x,b2->x)&&
        InRange(a->y,dst->y,b->y)&&
        InRange(a2->y,dst->y,b2->y);
}
