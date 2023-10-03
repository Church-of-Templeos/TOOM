I64 ammo;


class CDoomPlayer {
  CD2 position;
  F64 angle,height;
  F64 health,armor; 
  Bool running;
};

U0 PlayerUse(CDoomLevel *l,CDoomPlayer *p) {
  CD2 dummy;
  CDoomLinedef *ld;
  dummy.x=p->position.x;
  dummy.y=p->position.y;
  if(ld=MoveInLevel(l,&dummy,p->angle,64.,1.,p->height,0)) {
     TriggerLinedef(l,ld,WACTIVATE_SWITCH);
  }
}

U0 PlayerMove(CDoomLevel *l,CDoomPlayer *p,F64 speed=GRID_SZ/4) {
  CFifoI64 *crossed_f=FifoI64New(16);
  CDoomLinedef *crossed;
  CDoomLinedef *hit=MoveInLevel(l,&p->position,p->angle,speed,16,p->height);
  while(FifoI64Rem(crossed_f,&crossed)) {
    TriggerLinedef(l,crossed,WACTIVATE_WALK);
  }
  if(hit) TriggerLinedef(l,hit,WACTIVATE_PUSH);
  FifoI64Del(crossed_f);
  if(GetSectorForCoord(l,p->position.x,p->position.y))
    p->height=GetSectorForCoord(l,p->position.x,p->position.y)->floor_height;
}

U0 PlayerLook(CDoomPlayer *p,F64 angle) {
  p->angle=angle;
}


CDoomPlayer *PlayerNew(CDoomLevel *l) {
  CDoomPlayer *p=CAlloc(sizeof CDoomPlayer);
  CDoomThing *t,*head=&l->things;
  for(t=head->next;t!=head;t=t->next) {
//https://doomwiki.org/wiki/Thing_types#Other
    if(t->thing_type==1) {
      p->position.x=t->x+10;
      p->position.y=t->y;
      p->angle=t->angle;
      break;
    }
  }
  return p;
}
