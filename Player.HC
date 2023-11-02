

U0 PlayerMove(CDoomLevel *l,CDoomPlayer *p,F64 dir=1) {
  F64 speed=dir;
  if(p->running) speed*=30;
  else speed*=20;
  CFifoI64 *crossed_f=FifoI64New(16);
  CDoomLinedef *crossed;
  CDoomLinedef *hit=MoveInLevel(l,&p->x,p->angle,speed,16,p->height,COLLISF_NO_HIT_THING|COLLISF_SLIDE,crossed_f,p);
  while(FifoI64Rem(crossed_f,&crossed)) {
    TriggerLinedef(l,crossed,WACTIVATE_WALK);
  }
  if(hit) TriggerLinedef(l,hit,WACTIVATE_PUSH);
  FifoI64Del(crossed_f);
}

U0 PlayerLook(CDoomPlayer *p,F64 angle) {
  p->angle=angle;
}

CDoomPlayer *PlayerNew(CDoomLevel *l) {
  U16 gunsInit=0;
  CDoomPlayer *p=CAlloc(sizeof(CDoomPlayer));
  QueIns(p,&l->things);
  p->template=doom_thing_types[1];
  p->flags|=TF_SHOOTABLE;
  p->health=100;
  p->armor=0;
  p->arsenal=CAlloc(sizeof(GunAvail*)*8);  
  for(gunsInit=0;gunsInit<8;gunsInit++)
  {
    p->arsenal[gunsInit] = CAlloc(sizeof(GunAvail));
//REMOVE TODO
   p->arsenal[gunsInit]->available=TRUE;
    //p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
    //p->arsenal[gunsInit]->load->ammo=999;
    //p->arsenal[gunsInit]->load->baseDamage=2;
    //p->arsenal[gunsInit]->load->splash=FALSE;   
            
    switch(gunsInit)
    {
      case 0://fists
	p->arsenal[gunsInit]->available = TRUE;
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));    
        p->arsenal[gunsInit]->load->ammo=0;
        p->arsenal[gunsInit]->baseDamage=2;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 1://pistol
	p->arsenal[gunsInit]->available = TRUE;
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
        p->arsenal[gunsInit]->load->ammo=50;
        p->arsenal[gunsInit]->baseDamage=4;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 2://shotgun
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
        p->arsenal[gunsInit]->load->ammo=10;
        p->arsenal[gunsInit]->baseDamage=4;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 3://chaingun
        p->arsenal[gunsInit]->load = p->arsenal[1]->load;
        p->arsenal[gunsInit]->baseDamage=4;
        break;
      case 4://rocket launcher
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
        p->arsenal[gunsInit]->load->ammo=10;
        p->arsenal[gunsInit]->baseDamage=20;
        p->arsenal[gunsInit]->load->splash=TRUE;
        break;
      case 5://chainsaw
        p->arsenal[gunsInit]->load = p->arsenal[0]->load;
        p->arsenal[gunsInit]->baseDamage=3;
        break;
      case 6://plasma
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
        p->arsenal[gunsInit]->load->ammo=10;
        p->arsenal[gunsInit]->baseDamage=5;
        p->arsenal[gunsInit]->load->splash=FALSE;
        break;
      case 7://bfg
        p->arsenal[gunsInit]->load = p->arsenal[6]->load;
        p->arsenal[gunsInit]->baseDamage=100;
        break;
    }

  }
  CDoomThing *t,*head=&l->things;
  for(t=head->next;t!=head;t=t->next) {
//https://doomwiki.org/wiki/Thing_types#Other
    if(t->thing_type==1) {
      p->x=t->x;
      p->y=t->y;
      p->angle=t->angle;
      break;
    }
  }
  return p;
}

CDoomThing *PlayerPickTarget(CDoomLevel *l,CDoomPlayer *p) {
  CDoomThing *cur,*head=&l->things,*best;
  F64 dist,angle,margin=5.6*pi/180;
  for(cur=head->next;head!=cur;cur=cur->next) 
    if(cur->flags&TF_SHOOTABLE&&cur!=p) {
    dist=Sqrt(Sqr(cur->x-p->x)+Sqr(cur->y-p->y));
    if(dist<=16.*64) {
      angle=Wrap(FArg(cur->x-p->x,cur->y-p->y)-p->angle);
      if(-margin<=angle<=margin) {
        if(ValidateLineOfSightShot(l,&p->x,angle,dist+16,p->height,cur->height)<dist+16.)
	  return cur;
}
    }
  }
  return NULL;
}

