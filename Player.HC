class AmmoType{
  U64 ammo;
  I16 baseDamage;

  Bool splash;
  
};

class GunAvail{
  Bool available;
  AmmoType *load;
};

class CDoomPlayer {
  CD2 position;
  F64 angle,height;
  F64 health,armor;
  GunAvail **arsenal;
  
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
  CDoomLinedef *hit=MoveInLevel(l,&p->position,p->angle,speed,16,p->height,,crossed_f);
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

AmmoType *CreateAmmoType(U64 ammo, I16 baseDamage,Bool splash)
{
  AmmoType *at = CAlloc(sizeof(AmmoType));
  at->ammo = ammo;
  at->baseDamage=baseDamage;
  at->splash = splash;
  return at;
}

CDoomPlayer *PlayerNew(CDoomLevel *l) {
  U16 gunsInit=0;
  CDoomPlayer *p=CAlloc(sizeof(CDoomPlayer));
  p->arsenal=CAlloc(sizeof(GunAvail*)*8);  
  for(gunsInit=0;gunsInit<8;gunsInit++)
  {
    p->arsenal[gunsInit] = CAlloc(sizeof(GunAvail));
    p->arsenal[gunsInit]->available = TRUE;//all guns enabled
    p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
    //p->arsenal[gunsInit]->load->ammo=999;
    //p->arsenal[gunsInit]->load->baseDamage=2;
    //p->arsenal[gunsInit]->load->splash=FALSE;   
            
    switch(gunsInit)
    {
      case 0://fists
        p->arsenal[gunsInit]->load->ammo=0;
        p->arsenal[gunsInit]->load->baseDamage=2;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 1://pistol
        p->arsenal[gunsInit]->load->ammo=9;
        p->arsenal[gunsInit]->load->baseDamage=4;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 2://shotgun
        p->arsenal[gunsInit]->load->ammo=99;
        p->arsenal[gunsInit]->load->baseDamage=4;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 3://chaingun
        p->arsenal[gunsInit]->load->ammo=999;
        p->arsenal[gunsInit]->load->baseDamage=4;
        p->arsenal[gunsInit]->load->splash=FALSE;
        break;
      case 4://rocket launcher
        p->arsenal[gunsInit]->load->ammo=9;
        p->arsenal[gunsInit]->load->baseDamage=20;
        p->arsenal[gunsInit]->load->splash=TRUE;
        break;
      case 5://chainsaw
        p->arsenal[gunsInit]->load->ammo=0;
        p->arsenal[gunsInit]->load->baseDamage=3;
        p->arsenal[gunsInit]->load->splash=FALSE;
        break;
      case 6://plasma
        p->arsenal[gunsInit]->load->ammo=99;
        p->arsenal[gunsInit]->load->baseDamage=5;
        p->arsenal[gunsInit]->load->splash=FALSE;
        break;
      case 7://bfg
        p->arsenal[gunsInit]->load->ammo=999;
        p->arsenal[gunsInit]->load->baseDamage=100;
        p->arsenal[gunsInit]->load->splash=FALSE;
        break;
    }

  }
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
