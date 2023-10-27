//See enemy.c in doom3do
#define TICK_FPS_SCALE (1/3.) //Ticks_per_sec/fps
#define TICK_TIME (1/10.)

#define MISSILE_RANGE (64*32)
#define MELEE_RANGE 70
#define FLOATSPEED 2.
#define GRAVITY 4.
//These P pushers are used with FramePtrAdd
class CState {
  F64 time;
  CDoomAnimationFrame *anim_frames;
  U0 (*action)(CDoomLevel *,CDoomThinker *);
  U8 *next_state;
};
//2 Special times
#define STATE_NO_REPEAT -1
#define STATE_UNTIL_ANIM_DONE -2
U0 AddState(U8 *name,F64 ticks,CDoomAnimationFrame *f,U8 *fptr=NULL,U8 *next=NULL) {
  CState *s=CAlloc(sizeof CState);
  if(ticks=STATE_UNTIL_ANIM_DONE)
    s->time=AnimationTime(f);
  else
    s->time=ticks/4.;
  s->anim_frames=f;
  s->action=fptr;
  s->next_state=next;
  FramePtrAdd(name,s);
}
#define MF_JUST_ATTACKED (1<<16)
#define MF_ALLOW_FLOAT (2<<16)
#define MF_AMBUSH (4<<16)
#define MF_SKULL_ATTACK (8<<16)
#define MF_MISSILE (0x10<<16)
class CMonsterThinker:CDoomThinkerBase {
  CDoomThing *self;
  CDoomThing *parent; //Who shot the missle
  CDoomThing *target;
  F64 last_hit_time; //incoming damage to self
  F64 last_attack_time;
  F64 state_start_tS;
  F64 state_length;
  I64 steps_to_walk,reaction_time;
  F64 attack_time; //time to attack for
  I64 flags;
  CState *state;
};

#define MELEE_RANGE 70.
#define JUST_HIT_TIME .75
CDoomThing *GetPlayer() {
  return p;
}
U0 RemoveMonsterFromMem(CMonsterThinker *t) {
  QueRem(t->self);
  Free(t->self);
  QueRem(t);
  Free(t);
}


U0 DamageMob(CDoomLevel *l,CDoomThing *target,CDoomThing *opp,F64 damage){
  if(!(target->template->flags&TF_SHOOTABLE))
    return;
  if(target->health<=0.) return;
  if(target->health) {
  }
}

Bool MMove(CDoomLevel *l,CMonsterThinker *m) {
  CDoomThing *self=m->self,*target=m->target;
  CDoomSector *sec;
  CDoomLinedef *lv;
  CFifoI64 *crossed=FifoI64New(16);
  CD2 dummy;
  I64 allow_float=0;
  dummy.x=self->x,dummy.y=self->y;
  if(!(self->template->flags&TF_FLOATING))
    allow_float=COLLISF_NO_DROP;
    lv=MoveInLevel(l,&dummy,
	self->angle,
	self->template(CDoomMonsterTemplate*)->speed*TICK_FPS_SCALE,
	self->template->radius,
	self->height,
	allow_float|COLLISF_SLIDE|COLLISF_NO_HIT_THING|COLLISF_MONSTER,
	crossed
	);
    self->x=dummy.x;
    self->y=dummy.y;
    if(self->template->flags&TF_FLOATING) {
      if(sec=GetSectorForCoord(l,self->x,self->y)) {
	if(target&&self->height<target->height-FLOATSPEED) {
	  self->height=Clamp(self->height-FLOATSPEED,sec->floor_height,sec->ceil_height);
	} else if(target&&self->height>FLOATSPEED+target->height){
	  self->height=Clamp(self->height+FLOATSPEED,sec->floor_height,sec->ceil_height);
	}
      }
    }
//If we hit a line,try opening the door ?
  if(lv) {
    TriggerLinedef(l,lv,WACTIVATE_MONSTER|WACTIVATE_PUSH);
    while(FifoI64Rem(crossed,&lv))
      TriggerLinedef(l,lv,WACTIVATE_MONSTER|WACTIVATE_WALK);
  }
  FifoI64Del(crossed);
  return !!lv;
}

Bool SetState(CDoomLevel *l,CMonsterThinker *m,U8 *st) {
  CState *s=NULL;
  if(st) s=FramePtr(st);
  m->state=s;
  if(!s) {
    if(st) DbgPrint("Unimplemented state ASK NROOT(%s)",st);
    //You done silly
    RemoveMonsterFromMem(m);
    return FALSE;
  }
PrintI(st,1);
  if(m->self->animation!=s->anim_frames) {
    m->self->anim_start_tS=tS;
    m->self->animation=s->anim_frames;
  }
  m->state_start_tS=tS;
  m->state_length=s->time;
  if(s->action)
    (*s->action)(l,m);
}
U0 MonsterThinker(CDoomLevel *l,CMonsterThinker *m) {
  CDoomThing *self=m->self;
  if(m->state->action)
    (*m->state->action)(l,m);
//Class 10 pooperism
  if(m->state_start_tS+m->state_length<tS) {
    SetState(l,m,m->state->next_state);
  }
}
U0 InitMonsters(CDoomLevel *l) {
  CDoomThing *thing,*head=&l->things;
  CMonsterThinker *einstein;
  for(thing=head->next;thing!=head;thing=thing->next) {
    switch(thing->template->type) {
///See Things.TXT homedog
      case 68:
      case 64:
      case 3002:
      case 65:
      case 69:
      case 3003:
      case 3005:
      case 3001:
      case 3006:
      case 76:
      case 16:
      case 67:
      case 71:
      case 66:
      case 9:
      case 58:
      case 7:
      case 84:
      case 3004:
        thing->health=thing->template(CDoomMonsterTemplate*)->health;
        einstein=AddThinker(l,&MonsterThinker,sizeof CMonsterThinker);
	einstein->self=thing;
	SetState(l,einstein,thing->template(CDoomMonsterTemplate*)->spawn_state);
    }
  }
}


Bool CanSeeTarget(CDoomLevel *l,CMonsterThinker *t) {
  if(!t->target) return FALSE;
  CDoomThing *self=t->self;
  CDoomThing *tar=t->target;
  F64 dist=Sqrt(Sqr(self->x-tar->x)+Sqr(self->y-tar->y));
  F64 angle=FArg(tar->x-self->x,tar->y-self->y);
//Returns -1 if we Pushin P didnt hit a wall
  if(ValidateLineOfSightShot(l,&self->x,angle,dist,self->height+16,tar->height+16)<0.) {
    return TRUE;
  }
  return FALSE;
}
U0 Sub1RandomTick(CDoomLevel *l,CMonsterThinker *t) {
  I64 d=RandU64&4;
  if(t->state_length<d)
    t->state_length=0.;
  else
    t->state_length-=d;
}
Bool CheckMeleeRange(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *thing=t->self;
  CDoomThing *target=t->target;
  if(!target) return FALSE;
  return Sqrt(Sqr(target->x-thing->x)+Sqr(target->y-thing->y))<MELEE_RANGE;
}

Bool CheckMissileRange(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *thing=t->self;
  CDoomThing *target=t->target;
  if(!target) return FALSE;
  F64 dist;
  if(t->last_hit_time>0.)
    if(tS<JUST_HIT_TIME+t->last_hit_time) {
      t->last_hit_time=-1.;
      return TRUE;
    }
  dist=Sqrt(Sqr(target->x-thing->x)+Sqr(target->y-thing->y));
  if(!thing->template(CDoomMonsterTemplate*)->melee_state)
    dist-=128.;
  if(thing->template->type==3006) //Lost soul
    dist/=2.;
  if(dist>200.)
    dist=200.;
  return RandU64&0xff<ToI64(dist);
}
//Choose an angle to chase in
U0 NewChaseDir(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *thing=t->self;
  CDoomThing *target=t->target;
  CD2 dummy;
  F64 angle,dist=ToF64(RandU64&0xf),off=(Rand-.5)*pi/8.;
  if(!target) return;
  angle=FArg(target->x-thing->x,target->y-thing->y)+off;
  dummy.x=thing->x;
  dummy.y=thing->y;
  if(!MoveInLevel(l,&dummy,angle,thing->template->radius,thing->template->radius,thing->height,COLLISF_NO_DROP)) {
     thing->angle=angle;
  } else if(!MoveInLevel(l,&dummy,angle-pi,thing->template->radius,thing->template->radius,thing->height,COLLISF_NO_DROP)) {
     thing->angle=angle-pi;
  } else {
//Pushin P path is blocked so random direction
    thing->angle=(Rand-.5)*2.*2.*pi;
  }
  t->steps_to_walk=dist;
  t->state_length=dist;
  t->state_start_tS=tS;
  thing->x=dummy.x;
  thing->y=dummy.y;
}
Bool LookForPlayers(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *thing=t->self;
  CDoomThing *target=t->target;
  F64 angle,dist;
  if(!CanSeeTarget(l,t)) {
new_target:
    t->target=GetPlayer;
    return TRUE;
  }
  if(!target||!target->health)
    goto new_target;
//TODO sound
  angle=FArg(target->x-thing->x,target->y-thing->y)-thing->angle;
  if(FCos(angle)>0.) {
    dist=Sqrt(Sqr(target->x-thing->x)+Sqr(target->y-thing->y));
    if(dist>MELEE_RANGE)
	return FALSE; 
  }
  t->attack_time=4.;
  return TRUE;
}
U0 Look(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *p=GetPlayer;
  t->target=p;
  if(!CanSeeTarget(t->self,t))
    return ;
//TODOstart sound
  SetState(l,t,t->self->template(CDoomMonsterTemplate*)->see_state);
}
U0 Chase(CDoomLevel *l,CMonsterThinker *t) {
  if(t->reaction_time)
    --t->reaction_time;
  t->attack_time=Clamp(t->attack_time-TICK_TIME,0,I16_MAX);
  if(!t->target||t->target->health<=0.)  {
    if(LookForPlayers(l,t))
      return;
    SetState(l,t,t->self->template(CDoomMonsterTemplate*)->spawn_state);
    return;
  }
  if(t->self->flags&MF_JUST_ATTACKED) {
    t->self->flags&=~MF_JUST_ATTACKED;
    NewChaseDir(l,t);
    return;
  }
  if(t->self->template(CDoomMonsterTemplate*)->melee_state&&CheckMeleeRange(l,t)) {
    SetState(l,t,t->self->template(CDoomMonsterTemplate*)->melee_state);
    t->self->flags|=MF_JUST_ATTACKED;
    return;
  }
  if(t->steps_to_walk<=0&&t->self->template(CDoomMonsterTemplate*)->missile_state&&CheckMissileRange(l,t)) {
    SetState(l,t,t->self->template(CDoomMonsterTemplate*)->missile_state);
    t->self->flags|=MF_JUST_ATTACKED;
    return;
  }
  if(t->steps_to_walk) {
    --t->steps_to_walk;
  }
  if(!t->steps_to_walk)
    NewChaseDir(l,t);
  else
    MMove(l,t);
  //TODO chase sound
}
U0 FaceTarget(CDoomLevel *l,CMonsterThinker *t)  {
  CDoomThing *self=t->self;
  CDoomThing *target=t->target;
  if(target) {
    target->flags&=~MF_AMBUSH;
    self->angle=FArg(target->x-self->x,target->y-self->y);
  }
}


//For blood and smoke
CDoomThingTemplate *blood_templates[3];
CDoomThingTemplate *smoke_templates[4];
U0 CreatePuffTemplates() {
  I64 i,j;
  CDC *what;
  for(i=0;i!=3;i++) {
    blood_templates[i]=CAlloc(sizeof CDoomThingTemplate);
    blood_templates[i]->_animation=CAlloc(sizeof CDoomAnimationFrame);
    switch(i) {
      case 0: what=FramePtr("BLOOD1"); break;
      case 1: what=FramePtr("BLOOD2"); break;
      case 2: what=FramePtr("BLOOD3"); break;
    }
    for(j=0;j!=8;j++)
      blood_templates[i]->_animation->faces[j]=what;
  }
  for(i=0;i!=4;i++) {
    smoke_templates[i]=CAlloc(sizeof CDoomThingTemplate);
    smoke_templates[i]->_animation=CAlloc(sizeof CDoomAnimationFrame);
    switch(i) {
      case 0: what=FramePtr("PUFF1"); break;
      case 1: what=FramePtr("PUFF2"); break;
      case 2: what=FramePtr("PUFF3"); break;
      case 3: what=FramePtr("PUFF4"); break;
    }
    for(j=0;j!=8;j++)
      smoke_templates[i]->_animation->faces[j]=what;
  }
}
class CPuffThinker:CDoomThinkerBase {
  CDoomThing *self;
  F64 spawn_time;
};
U0 PuffThinker(CDoomLevel *l,CPuffThinker *puff) {
  CDoomThing *self=puff->self;
  CDoomThingTemplate **templates;
  I64 i,i2;
  CDoomSector *s=GetSectorForCoord(l,self->x,self->x)->floor_height;
  if(!s) {
//wut
    kill_puff:
    QueRem(self);
    Free(self);
    QueRem(puff);
    Free(puff);
    return;
  }
  self->height+=self->momz;
  self->momz-=GRAVITY;
  if(s->floor_height<self->height)
    goto kill_puff;
//I will goto the next puff frame
  if(tS-puff->spawn_time>1./5.) {
    puff->spawn_time=tS;
    for(i=0;i!=2;i++) {
      if(i==0)
        templates=blood_templates,i2=3;
      else
        templates=smoke_templates,i2=4;
      while(i2--) {
        if(templates[i2]==self->template)
	  break;
      }
      if(i2>=0) {
        i2++;
//No more animation frames
        if(i==0&&i2==3) goto kill_puff;
        else if(i==1&&i2==4) goto kill_puff;
	self->template=templates[i2];
      }
    }
  }
}
U0 SpawnBloodPuff(CDoomLevel *l,CD2 *at,F64 h,F64 damage) {
  CDoomThing *blood=CAlloc(sizeof CDoomThing);
  CPuffThinker *t;
  blood->x=at->x,blood->y=at->y;
  blood->height=h;
  blood->momz=RandU64&15+2;
//Heres the deal,BLOOD1  is the messy-est
//BLOOD2 is the middle,
//BLOOD3 is the final frame of anmation
  if(damage>13.) {
//Whooping load of damage
    blood->template=blood_templates[0];
  } else if(damage>9.) {
    blood->template=blood_templates[1];
  } else {
    blood->template=blood_templates[2];
  }
  t=AddThinker(l,&PuffThinker,sizeof CPuffThinker);
  t->spawn_time=tS;
  t->self=blood;
}
U0 SpawnSmokePuff(CDoomLevel *l,CD2 *at,F64 h,F64 attack_range) {
  CDoomThing *smoke=CAlloc(sizeof CDoomThing);
  CPuffThinker *t;
  smoke->x=at->x,smoke->y=at->y;
  smoke->height=h;
  smoke->momz=RandU64&15+2;
  if(attack_range<MELEE_RANGE) {
//Use Puff 3 if we hit the wall,we dont want the spark puff's when Pwnin a wall homie
    smoke->template=smoke_templates[2];
  } else
    smoke->template=smoke_templates[0];
  t=AddThinker(l,&PuffThinker,sizeof CPuffThinker);
  t->spawn_time=tS;
  t->self=smoke;
} 
U0 LineAttack(CDoomLevel *l,CMonsterThinker *t,F64 range,F64 angle,F64 damage) {
  CDoomThing *hit=ShotSmacksAHomie(l,&t->self->x,angle,range,t->self->height+t->self->template->height/2);
  if(hit) {
//Spawn a BLOOD PUFF,and I AINT talkin marshmellow

  }
}
U0 PosAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 angle,damage;
  if(t->target) {
    FaceTarget(l,t);
//TODO start sound
    angle=t->self->angle;
    angle+=(.5-Rand)*180./pi*5;
    damage=((RandU64&7)+1)*3;
    LineAttack(l,t,MISSILE_RANGE,angle,damage);
  }
}
U0 SPosAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 bangle,angle,damage;
  I64 i;
  if(t->target) {
//TODO sound start 
    FaceTarget(l,t);
    bangle=t->self->angle;
    for(i=0;i!=3;i++) {
      angle=bangle;
      angle+=(.5-Rand)*180./pi*5;
      damage=((RandU64&7)+1)*3;
      LineAttack(l,t,MISSILE_RANGE,angle,damage);
    }
  }
}
U0 SpidRefire(CDoomLevel *l,CMonsterThinker *t) {
  FaceTarget(l,t);
  if(RandU64&255>=10) {
    if(!t->target||t->target->health<=0.||!CanSeeTarget(l,t))
      SetState(l,t,t->self->template(CDoomMonsterTemplate*)->see_state);
  }
}
U0 SpawnMissile(CDoomLevel *l,CDoomThing *t,CDoomThing *target,U64 type) {
//TODO choose state
}
//Imp poo poo
U0 TroopAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 damage;
  if(t->target) {
    FaceTarget(l,t);
    if(CheckMeleeRange(l,t)) {
	//TODO sound
      damage=((RandU64&7)+1)*3;
      DamageMob(l,t->target,t,damage);
      return;
    }
    SpawnMissile(l,t,t->target,'Imp');
  }
}
//Spectre
U0 SargAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 angle,damage;
  if(t->target) {
    FaceTarget(l,t);
//TODO start sound
    angle=t->self->angle;
    angle+=(.5-Rand)*180./pi*5;
    damage=((RandU64&7)+1)*4;
    LineAttack(l,t,MELEE_RANGE,angle,damage);
  }
}

U0 CacodemonAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 damage;
  if(t->target) {
    FaceTarget(l,t);
    if(CheckMeleeRange(l,t)) {
      damage=((RandU64&7)+1)*8;
      DamageMob(l,t->target,t,damage);
      return;
    }
    SpawnMissile(l,t,t->target,'Caco');
  }
}

U0 CyberdemonAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 damage;
  if(t->target) {
    FaceTarget(l,t);
    SpawnMissile(l,t,t->target,'Cyber');
  }
}

U0 BarronOfHellAttack(CDoomLevel *l,CMonsterThinker *t) {
  F64 damage;
  if(t->target) {
    FaceTarget(l,t);
    if(CheckMeleeRange(l,t)) {
      damage=((RandU64&7)+1)*11;
      DamageMob(l,t->target,t,damage);
      return;
    }
    SpawnMissile(l,t,t->target,'Baron');
  }
}

#define SKULL_ATTACK_SPEED 40.
U0 SkullAttack(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *dest=t->target;
  CDoomThing *self=t->self;
  F64 dist;
  if(dest) {
    self->flags|=MF_SKULL_ATTACK;
    //TODO sound
    FaceTarget(l,t);
    self->momx=FCos(t)*SKULL_ATTACK_SPEED;
    self->momy=FSin(t)*SKULL_ATTACK_SPEED;
    dist=Sqrt(Sqr(dest->x-t->self->x)+Sqr(dest->y-t->self->y));
    self->momz=(dest->height+dest->template->height/2-t->self->height)/dist;
  }
}
U0 Scream(CDoomLevel *l,CMonsterThinker *t) {
}
U0 BOOM(CDoomLevel *l,CMonsterThinker *t) {
//Major death
} 
U0 Pain(CDoomLevel *l,CMonsterThinker *t) {
}
U0 Fall(CDoomLevel *l,CMonsterThinker *t) {
  t->self->solid=FALSE;
}
U0 XFall(CDoomLevel *l,CMonsterThinker *t) {
  t->self->solid=FALSE;
}
U0 RadiusAttack(CDoomLevel *l,CDoomThing *dik,F64 boom) {
  CDoomThing *cur,*head=&l->things;
  CD2 src,dst,dummy;
  F64 angle,dist;
  src.x=dik->x;
  src.y=dik->y;
  for(cur=head->next;cur!=head;cur=cur->next) {
    dist=Sqrt(Sqr(cur->y-src.y)+Sqr(cur->x-src.x));
    if(dist<boom) {
      angle=FArg(cur->x-src.x,cur->y-src.y);
      dummy.x=src.x;
      dummy.y=src.y;
      if(!MoveInLevel(l,&dummy,angle,dist,dik->template->radius,dik->height,0))
	DamageMob(l,cur,dik,dist);
    }
  }
}
U0 Explode(CDoomLevel *l,CMonsterThinker *t) {
  RadiusAttack(l,t->target,128);
}
U0 BossDeath(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *self=t->self;
//Check if the Drake treacherous twin's are all dead,then we fin ta trigger 666
  CDoomThing *treacherous_twin,*head=&l->things;
  CDoomLinedef dummy;
  for(
	treacherous_twin=head->next;
	head!=treacherous_twin;
	treacherous_twin=treacherous_twin->next
  ) {
    if(treacherous_twin->template==self->template&&treacherous_twin->health>0.)
	return ;
  }
//Yeah  will pwned em all homie,activate #666 Floor FloorToLowest
//See Floors.TXT for more info on our dummy thang(37)
  dummy.sector_tag=666;
  dummy.special_type=action_sector_types[37];
  TriggerLinedef(l,&dummy,WACTIVATE_WALK);   
}
U0 Hoof(CDoomLevel *l,CMonsterThinker *t) {
  //TODO start sound
  Chase(l,t);
} 

//Metal robot spider foot homie
U0 Metal(CDoomLevel *l,CMonsterThinker *t) {
  //TODO start sound
  Chase(l,t);
} 

U0 ExplodeMissle(CDoomLevel *l,CMonsterThinker *t) {
  CDoomThing *self=t->self;
  self->momx=0.;
  self->momy=0.;
  self->momz=0.;
  SetState(l,t,t->self->template(CDoomMonsterTemplate*)->death_state);
  self->flags&=~MF_MISSILE; 
//Todo make some sound
}

U0 MissileHit(CDoomLevel *l,CMonsterThinker *t) {
  F64 damage;
  if(t) {
    damage=t->self->template(CDoomMonsterTemplate*)->damage*(RandU64&7+1);
    DamageMob(l,t->target,t->parent,damage);
  }
  ExplodeMissle(l,t);
}
U0 SkullHit(CDoomLevel *l,CMonsterThinker *t,CDoomThing *hit_thang) {
  F64 damage;
  CDoomThing *self=t->self;
  if(hit_thang) {
    damage=(RandU64&7+1)*t->self->template(CDoomMonsterTemplate*)->damage;
    DamageMob(l,hit_thang,t,damage);
  }
  self=t->self;
  self->flags&=~MF_SKULL_ATTACK;
  self->momx=0.;
  self->momy=0.;
  self->momz=0.;
  SetState(l,t,t->self->template(CDoomMonsterTemplate*)->spawn_state);
}

//Yvng Poop toad here(Nrootconauto)
//I am NOT messing around with the C sprite names(they dont map to real sprite names)
CDoomThingTemplate *imp_fireball;
CDoomThingTemplate *baron_fireball;
CDoomThingTemplate *cacodemon_fireball;
CDoomThingTemplate *rocket;
U0 LoadMonsterInfo() {
  CDoomProjectileTemplate *p;
  //https://doomwiki.org/wiki/Imp
  CDoomMonsterTemplate *t=doom_thing_types[0xbb9];
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFG");
  t->_attack_frames=GenerateCacheFrames(t,"EFG");
  t->_hurt_frames=GenerateCacheFrames(t,"HH");
  t->_dying_frames=GenerateCacheFrames(t,"IJKLM");
  t->_gib_frames=GenerateCacheFrames(t,"NOPQRSTU");
  t->pain_time=1/35.*4;
  t->reaction_time=1/35.*8;
  t->health=60;
  t->speed=8.;
  t->damage=3;
  t->pain_chance=200./255;
  AddState(t->spawn_state="IMP.S_POSS_STND",10*4,t->_idle_frames,&Look,"IMP.S_POSS_STND");
  AddState(t->see_state="IMP.S_POSS_RUN",9*4,t->_chase_frames,&Chase,"IMP.S_POSS_RUN");
  AddState(t->missile_state="IMP.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"IMP.S_POSS_ATK2");
  AddState("IMP.S_POSS_ATK2",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&TroopAttack,"IMP.S_POSS_RUN");
  AddState(t->pain_state="IMP.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"IMP.S_POSS_RUN");
  AddState(t->death_state="IMP.S_POSS_DIE",STATE_NO_REPEAT,t->_hurt_frames,&Fall,"ST_NULL");
  AddState(t->gib_state="IMP.S_POSS_GIB",STATE_NO_REPEAT,t->_dying_frames,&XFall,"ST_NULL");
//Fireball and I aint talkin alchohol
  p=imp_fireball=CAlloc(sizeof CDoomProjectileTemplate);
  p->damage=9;
  p->radius=6.;
  p->height=8.;
  StrCpy(p->spr_base_name,"BAL1");
  p->flags=TF_MISSILE;
  p->_idle_frames=GenerateCacheFrames(p,"AB");
  p->_hit_frames=GenerateCacheFrames(p,"CDE");
//https://doomwiki.org/wiki/Baron_of_Hell
  t=doom_thing_types[0xbbb];
  t->pain_time=1/35.*4;
  t->reaction_time=1/35.*8;
  t->health=1000;
  t->damage=10;
  t->pain_chance=16.8/100.;
  t->speed=8.; //TODO check it
  t->mass=1000.;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFG");
  t->_attack_frames=GenerateCacheFrames(t,"EFG");
  t->_hurt_frames=GenerateCacheFrames(t,"HH");
  t->_dying_frames=GenerateCacheFrames(t,"IJKLM");
  t->_gib_frames=GenerateCacheFrames(t,"NOPQRSTU");
  AddState(t->spawn_state="BARON.S_POSS_STND",10*4,t->_idle_frames,&Look,"BARON.S_POSS_STND");
  AddState(t->see_state="BARON.S_POSS_RUN",20*4,t->_chase_frames,&Chase,"BARON.S_POSS_RUN");
  AddState(t->missile_state="BARON.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"BARON.S_POSS_ATK2");
  AddState(t->missile_state="BARON.S_POSS_ATK2",0,t->_idle_frames,&FaceTarget,"BARON.S_POSS_ATK3");
  AddState("BARON.S_POSS_ATK3",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&BarronOfHellAttack,"BARON.S_POSS_RUN");
  AddState(t->pain_state="BARON.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"BARON.S_POSS_RUN");
  AddState(t->death_state="BARON.S_POSS_DIE",STATE_NO_REPEAT,t->_dying_frames,&Fall,"BARON.S_POSS_DIE2");
  AddState(t->death_state="BARON.S_POSS_DIE2",STATE_NO_REPEAT,t->_dying_frames,&BossDeath,"ST_NULL");
//Booger ball
  p=baron_fireball=CAlloc(sizeof CDoomProjectileTemplate);
  p->damage=8;
  p->radius=6.;
  p->height=8.;
  StrCpy(p->spr_base_name,"BAL7");
  p->flags=TF_MISSILE;
  p->_idle_frames=GenerateCacheFrames(p,"AB");
  p->_hit_frames=GenerateCacheFrames(p,"CDE");
//Flying meatball
  t=doom_thing_types[0xbbd];
  t->pain_time=1/35.*6;
  t->reaction_time=1/35.*8;
  t->health=400.;
  t->speed=8.;
  t->pain_chance=.50;
  t->_idle_frames=GenerateCacheFrames(t,"A");
  t->_chase_frames=GenerateCacheFrames(t,"A");
  t->_melee_frames=GenerateCacheFrames(t,"BCD");
  t->_attack_frames=GenerateCacheFrames(t,"BCD");
  t->_hurt_frames=GenerateCacheFrames(t,"BCD");
  t->_dying_frames=GenerateCacheFrames(t,"GHIJKL");
//Kako in greek
  AddState(t->spawn_state="CACO.S_POSS_STND",5*4,t->_idle_frames,&Look,"CACO.S_POSS_STND");
  AddState(t->see_state="CACO.S_POSS_RUN",1*4,t->_chase_frames,&Chase,"CACO.S_POSS_RUN");
  AddState(t->missile_state="CACO.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"CACO.S_POSS_ATK2");
  AddState(t->missile_state="CACO.S_POSS_ATK2",0,t->_idle_frames,&FaceTarget,"CACO.S_POSS_ATK3");
  AddState("CACO.S_POSS_ATK3",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&SkullAttack,"CACO.S_POSS_RUN");
  AddState(t->pain_state="CACO.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"CACO.S_POSS_RUN");
  AddState(t->death_state="CACO.S_POSS_DIE",STATE_NO_REPEAT,t->_dying_frames,&Fall,"CACO.S_POSS_DIE2");
  AddState(t->death_state="CACO.S_POSS_DIE2",STATE_NO_REPEAT,t->_hurt_frames,&BossDeath,"ST_NULL");
//Cacodemon ball
  p=cacodemon_fireball=CAlloc(sizeof CDoomProjectileTemplate);
  p->damage=5;
  p->radius=6.;
  p->height=8.;
  StrCpy(p->spr_base_name,"BAL2");
  p->flags=TF_MISSILE;
  p->_idle_frames=GenerateCacheFrames(p,"AB");
  p->_hit_frames=GenerateCacheFrames(p,"CDE");
//Cyber demon
  t=doom_thing_types[0x10];
  t->pain_time=1/35.*4;
  t->reaction_time=1/35.*10;
  t->health=4000.;
  t->speed=16.;
  t->mass=1000;
  t->pain_chance=20./255;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFEFEF");
  t->_attack_frames=GenerateCacheFrames(t,"EFEFEF");
  t->_hurt_frames=GenerateCacheFrames(t,"G");
  t->_dying_frames=GenerateCacheFrames(t,"HIJKLMNOPP");
//Rocket
  p=rocket=CAlloc(sizeof CDoomProjectileTemplate);
  p->damage=20.;
  p->radius=11.;
  p->height=8.;
  StrCpy(p->spr_base_name,"MISL");
  p->flags=TF_MISSILE;
  p->_idle_frames=GenerateCacheFrames(p,"A");
  p->_hit_frames=GenerateCacheFrames(p,"BCD");
//Pink demon
  t=doom_thing_types[0xbba];
  t->reaction_time=1/35.*8;
  t->pain_time=1/35.*4;
  t->health=150.;
  t->speed=10.;
  t->mass=400.;
  t->damage=4;
  t->pain_chance=180./255.;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFG");
  t->_attack_frames=GenerateCacheFrames(t,"EFG");
  t->_hurt_frames=GenerateCacheFrames(t,"HH");
  t->_dying_frames=GenerateCacheFrames(t,"IJKLMN");
  AddState(t->spawn_state="PANKY.S_POSS_STND",10*4,t->_idle_frames,&Look,"PANKY.S_POSS_STND");
  AddState(t->see_state="PANKY.S_POSS_RUN",6*4,t->_chase_frames,&Chase,"PANKY.S_POSS_RUN");
  AddState(t->missile_state="PANKY.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"PANKY.S_POSS_ATK2");
  AddState(t->missile_state="PANKY.S_POSS_ATK2",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&SkullAttack,"PANKY.S_POSS_RUN");
  AddState(t->pain_state="PANKY.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"PANKY.S_POSS_RUN");
  AddState(t->death_state="PANKY.S_POSS_DIE",STATE_NO_REPEAT,t->_dying_frames,&Fall,"PANKY.S_POSS_DIE2");
  AddState(t->death_state="PANKY.S_POSS_DIE2",STATE_NO_REPEAT,t->_dying_frames,NULL,NULL);
//Skull demon
  t=doom_thing_types[0xbbe];
  t->reaction_time=1/35.*8;
  t->pain_time=1/35.*6;
  t->health=100.;
  t->speed=8.;
  t->skull_attack_speed=20.;
  t->mass=50.;
  t->pain_chance=1;
  t->damage=3.;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AB");
  t->_melee_frames=GenerateCacheFrames(t,"CDCD");
  t->_attack_frames=GenerateCacheFrames(t,"CDCD");
  t->_hurt_frames=GenerateCacheFrames(t,"EE");
  t->_dying_frames=GenerateCacheFrames(t,"FGHIJK");
  AddState(t->spawn_state="SKULL.S_POSS_STND",10*4,t->_idle_frames,&Look,"SKULL.S_POSS_STND");
  AddState(t->see_state="SKULL.S_POSS_RUN",STATE_UNTIL_ANIM_DONE,t->_chase_frames,&Chase,"SKULL.S_POSS_RUN");
  AddState(t->missile_state="SKULL.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"SKULL.S_POSS_ATK2");
  AddState(t->missile_state="SKULL.S_POSS_ATK2",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&SkullAttack,"SKULL.S_POSS_RUN");
  AddState(t->pain_state="SKULL.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"SKULL.S_POSS_RUN");
  AddState(t->death_state="SKULL.S_POSS_DIE",9*4,t->_hurt_frames,&Fall,"SKULL.S_POSS_DIE2");
  AddState(t->death_state="SKULL.S_POSS_DIE2",0,t->_hurt_frames,NULL,NULL);
//Shotgun guy
  t=doom_thing_types[9];
  t->reaction_time=1/35.*8;
  t->pain_time=1/35.*6;
  t->health=30;
  t->speed=8;
  t->mass=100;
  t->damage=3;
  t->pain_chance=170./255.;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFE");
  t->_attack_frames=GenerateCacheFrames(t,"EFE");
  t->_dying_frames=GenerateCacheFrames(t,"HIJKL");
  t->_hurt_frames=GenerateCacheFrames(t,"GG");
  t->_gib_frames=GenerateCacheFrames(t,"MNOPQRSTU");

  AddState(t->spawn_state="SHOTGUN.S_POSS_STND",STATE_UNTIL_ANIM_DONE,t->_idle_frames,&Look,"SHOTGUN.S_POSS_STND");
  AddState(t->see_state="SHOTGUN.S_POSS_RUN",STATE_UNTIL_ANIM_DONE,t->_chase_frames,&Chase,"SHOTGUN.S_POSS_RUN");
  AddState(t->missile_state="SHOTGUN.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"SHOTGUN.S_POSS_ATK2");
  AddState("SHOTGUN.S_POSS_ATK2",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&SPosAttack,"SHOTGUN.S_POSS_RUN");
  AddState(t->pain_state="SHOTGUN.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"SHOTGUN.S_POSS_RUN");
  AddState(t->death_state="SHOTGUN.S_POSS_DIE",STATE_NO_REPEAT,t->_dying_frames,&Fall,"ST_NULL");
  AddState(t->gib_state="SHOTGUN.S_POSS_GIB",STATE_UNTIL_ANIM_DONE,t->_dying_frames,&XFall,"ST_NULL");

//Transparent demon
  t=doom_thing_types[0x3a];
  t->reaction_time=1/35.*8;
  t->pain_time=1/35.*4;
  t->health=150;
  t->speed=10;
  t->mass=400.;
  t->pain_chance=180./255.;
  t->damage=4.;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFG");
  t->_attack_frames=GenerateCacheFrames(t,"EFG");
  t->_hurt_frames=GenerateCacheFrames(t,"HH");
  t->_dying_frames=GenerateCacheFrames(t,"IJKLMN");
//TODO fix
  AddState(t->spawn_state="TRANS.S_POSS_STND",10*4,t->_idle_frames,&Look,"TRANS.S_POSS_STND");
  AddState(t->see_state="TRANS.S_POSS_RUN",6*4,t->_chase_frames,&Chase,"TRANS.S_POSS_RUN");
  AddState(t->missile_state="TRANS.S_POSS_ATK1",0,t->_idle_frames,&FaceTarget,"TRANS.S_POSS_ATK2");
  AddState(t->missile_state="TRANS.S_POSS_ATK2",10*4,t->_idle_frames,&SkullAttack,"TRANS.S_POSS_RUN");
  AddState(t->pain_state="TRANS.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"TRANS.S_POSS_RUN");
  AddState(t->death_state="TRANS.S_POSS_DIE",9*4,t->_hurt_frames,&Fall,"TRANS.S_POSS_DIE2");
  AddState(t->death_state="TRANS.S_POSS_DIE2",0,t->_hurt_frames,NULL,NULL);
//Scrotum spider
  t=doom_thing_types[0x7];
  t->reaction_time=1/35.*8;
  t->pain_time=1/35.*6;
  t->health=3000;
  t->speed=12;
  t->mass=1000;
  t->pain_chance=40/255.;
  t->damage=3;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDDEEFF");
  t->_melee_frames=GenerateCacheFrames(t,"GHH");
  t->_attack_frames=GenerateCacheFrames(t,"GHHH");
  t->_hurt_frames=GenerateCacheFrames(t,"II");
  t->_dying_frames=GenerateCacheFrames(t,"JKLMNOPQRSS");
//Zombieman
  t=doom_thing_types[0xbbc];
  t->reaction_time=1/35.*8;
  t->pain_time=1/35.*6;
  t->health=20;
  t->speed=8;
  t->pain_chance=200/255.;
  t->_idle_frames=GenerateCacheFrames(t,"AB");
  t->_chase_frames=GenerateCacheFrames(t,"AABBCCDD");
  t->_melee_frames=GenerateCacheFrames(t,"EFE");
  t->_attack_frames=GenerateCacheFrames(t,"EFE");
  t->_hurt_frames=GenerateCacheFrames(t,"GG");
  t->_dying_frames=GenerateCacheFrames(t,"HIJKL");
  t->_gib_frames=GenerateCacheFrames(t,"MNOPQRSTU");
  AddState(t->spawn_state="ZOMBIE.S_POSS_STND",10*4,t->_idle_frames,&Look,"ZOMBIE.S_POSS_STND");
  AddState(t->see_state="ZOMBIE.S_POSS_RUN",8*4,t->_chase_frames,&Chase,"ZOMBIE.S_POSS_RUN");
  AddState(t->missile_state="ZOMBIE.S_POSS_ATK1",STATE_UNTIL_ANIM_DONE,t->_idle_frames,&FaceTarget,"ZOMBIE.S_POSS_ATK2");
  AddState("ZOMBIE.S_POSS_ATK2",STATE_UNTIL_ANIM_DONE,t->_attack_frames,&PosAttack,"ZOMBIE.S_POSS_ATK3");
  AddState("ZOMBIE.S_POSS_ATK3",STATE_UNTIL_ANIM_DONE,t->_chase_frames,NULL,"ZOMBIE.S_POSS_RUN");
  AddState(t->pain_state="ZOMBIE.S_POSS_PAIN",STATE_UNTIL_ANIM_DONE,t->_hurt_frames,&Pain,"ZOMBIE.S_POSS_RUN");
  AddState(t->death_state="ZOMBIE.S_POSS_DIE",STATE_UNTIL_ANIM_DONE,t->_dying_frames,&Fall,"ST_NULL");
  AddState(t->gib_state="ZOMBIE.S_POSS_GIB",STATE_NO_REPEAT,t->_gib_frames,&XFall,"ST_NULL");
};
LoadMonsterInfo;