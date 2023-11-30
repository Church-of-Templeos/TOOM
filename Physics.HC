#ifndef PHYSICS
#define PHYSICS "P Pushin" 
#define FRICTION .90625
Bool IsCrushed(CDoomSector *s,CDoomThing *t) {
  F64 gap=s->ceil_height-s->floor_height;
  if(gap<=t->template->height)
    return TRUE;
  return FALSE;
}
//Accoutns for momentum and falling
U0 PhysicsOnThing(CDoomLevel *l,CDoomThing *thing) {
  CD2 at;
  CDoomLinedef *ld=NULL;
  CDoomSector *sec;
  CDoomActionSector *special;
  CDoomThing *target=NULL;
  F64 angle=FArg(thing->momx,thing->momy);
  F64 mom_t=Sqrt(Sqr(thing->momx)+Sqr(thing->momy));
  if(mom_t>=1.)
    if(ld=MoveInLevel(l,&thing->x,angle,mom_t,thing->template->radius,thing->height,COLLISF_SLIDE|COLLISF_NO_HIT_THING,,thing,&target)) {
      if(target&&thing->flags&MF_SKULL_ATTACK) {
	thing->flags&=~MF_SKULL_ATTACK;
	DamageMob(l,target,thing,(23-3)*Rand+3);
      }
    }
  thing->momx*=FRICTION;
  thing->momy*=FRICTION;
  if(thing->momy<1.)
    thing->momy=0.;
  if(thing->momx<1.)
    thing->momx=0.;
  sec=GetHighestSectorInRadius(l,thing->x,thing->y,thing->template->radius);
//Gravity
  if(!(thing->flags&TF_FLOATING)) {
    if(sec) {
      if(thing->height>sec->floor_height) {
        thing->height+=thing->momz;
        thing->momz-=GRAVITY;
      } else if(thing->height>sec->ceil_height) {
        thing->height=sec->ceil_height-thing->template->height;
//Hit the ceiling so bump down
        thing->momz=-GRAVITY;
      }
      thing->height=Clamp(thing->height,sec->floor_height,sec->ceil_height);
      if(thing->height==sec->floor_height)
        thing->momz=0;
    }
  }
//Check for crusher  action linedef
  if(sec&&sec->cur_action_linedef) {
    if(special=sec->cur_action_linedef->special_type) {
      if(IsCrushed(sec,thing)) {
        if(special->type=='Door') {
	  if(sec->closing) {
	    if(thing->health<=0.) {
//TODO crush bodies at the bottom
	    } else {
	      sec->start_tS=tS;
	      sec->target_start=sec->ceil_height;
	      sec->opening=TRUE;
	    }
	  }
        } else if(special->type=='Ceil') {
//Cielings dont kill homies normally,they halt until the homie dies
	  if(thing->health<=0.) {
//TODO crush bodies at the bottom
	  } else  {
	    sec->start_tS=tS;
	    sec->paused=TRUE;
	  }
        } else if(special->type=='Floor'||special->type=='Lift') {
//go down if something is in the way
	  if(thing->health<=0.) {
//TODO crush bodies at the bottom
	  } else  {
//TODO damage homies(if crush)?
	    sec->start_tS=tS;
	    sec->target_start=sec->floor_height;
	    sec->going_down=TRUE;
	    sec->going_up=FALSE;
	  }
        }
      }
    }
  }
}
U0 EchoSound(CDoomLevel *l,CDoomThing *thing,CDoomSector *s,F64 len) {
  I64 cnt=s->linedef_cnt,i;
  CDoomLinedef *ld;
  CDoomSector *other;
  F64 tdist;
  if(s->sound_check) return;
  s->noise_thing=thing;
  s->sound_check=TRUE;
  for(i=0;i!=cnt;i++) {
    ld=s->linedefs[i];
    if(ld->front&&ld->back)
      if(!(ld->flags&WAD_LINEDEFF_BLOCK_SOUND)) {
        if(ld->front->sector==s)
	  other=ld->back->sector;
	else
	  other=ld->front->sector;
	if(other->ceil_height>s->floor_height&&
	  s->ceil_height>other->floor_height) { //Open gap?
	  tdist=DistFromLine(&thing->x,ld->start,ld->end);
	  if(tdist<len) {
	    EchoSound(l,thing,other,len-tdist);
	  }
	}
      }
  }
}
U0 Physics(CDoomLevel *l) {
  CDoomThing *t,*head;
  CDoomSector *s;
  head=&l->sectors;
  for(s=head->next;s!=head;s=s->next) {
//Reset the paused awaiting for checking for monsters in the way
    s->paused=FALSE;
    s->sound_check=FALSE;
  }
//TODO better sound 
  if(p(CDoomPlayer*)->made_a_sound) {
    p(CDoomPlayer*)->made_a_sound=FALSE;
    s=GetSectorForCoord(l,p->x,p->y);
    EchoSound(l,p,s,1024);
  }
  head=&l->things;
  for(t=head->next;t!=head;t=t->next) {
    PhysicsOnThing(l,t);
  }
}
#endif