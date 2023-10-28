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
  CDoomLinedef *ld;
  CDoomSector *sec;
  CDoomActionSector *special;
  F64 mom_t=thing->mom;
  at.x=thing->x;
  at.y=thing->y;
  if(ld=MoveInLevel(l,&at,thing->angle,mom_t,thing->template->radius,thing->height,COLLISF_SLIDE|COLLISF_NO_HIT_THING,,thing)) {
  }
  thing->mom*=FRICTION;
  if(thing->mom<1.)
    thing->mom=0.;
//Gravity
  if(sec=GetSectorForCoord(l,thing->x,thing->y)) {
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
U0 Physics(CDoomLevel *l) {
  CDoomThing *t,*head;
  CDoomSector *s;
  head=&l->sectors;
  for(s=head->next;s!=head;s=s->next) {
//Reset the paused awaiting for checking for monsters in the way
    s->paused=FALSE;
  }

  head=&l->things;
  for(t=head->next;t!=head;t=t->next) {
    PhysicsOnThing(l,t);
  }
}
#endif