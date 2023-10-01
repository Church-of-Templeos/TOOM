#ifndef DOORS
#define DOORS "wealth provoke stormy inhabitant "
//https://doomwiki.org/wiki/Linedef_type#Terminology
//P  == Push
//S  == Switch
//W  == Walkover
//G  == Gun
// 1 == Once
// R == Repeat
#define DOOR_SPEED_SLOW 1.
#define DOOR_SPEED_FAST 3.


#define DOOR_ACTION_OPEN_WAIT_CLOSE 1
#define DOOR_ACTION_OPEN 2 //Stays open
#define DOOR_ACTION_CLOSE 3 //Stays closed
#define DOOR_ACTION_CLOSE_WAIT_OPEN 4

#define DOOR_LOCK_RED 1
#define DOOR_LOCK_BLUE 2
#define DOOR_LOCK_YELLOW 4

class CDoomDoor {
  U64 type;
  U64 trigger;
  I64 key;
  F64 speed;
  F64 wait;
  I64 monster;
  I64 action;
};

class CDoomFloor {
  U64 type;
  U64 trigger;
  U64 direction;
  F64 speed;
  Bool texture_change;
  Bool type_change;
  Bool pad[6];
  I64 model;
  I64 monster;
  I64 crush;
};


union CDoomActionSector {
  U64 type;
  CDoomDoor door;
};

CDoomActionSector *action_sector_types[0x10000];
MemSet(action_sector_types,0,0x10000*8);

#define DOOM_DOORS_FILE "Doors.TXT"
U8 *ReadALine(U8 **fbuf) {
  U8 *en,*st=*fbuf,*buf;
  if(!*st) return NULL;
  if(en=StrFirstOcc(st,"\n")) {
    buf=MAlloc(en-st+2);
    MemCpy(buf,st,en-st+1);
    buf[en-st+1]=0;
    *fbuf=en+1;
    return buf;
  }
  *fbuf+=StrLen(st);
  return StrNew(st);
}
U0 LoadDoors() {
  U8 *optr=FileRead(DOOM_DOORS_FILE),*fptr,*ln;
  I64 num;
  CDoomDoor *door;
  U8 cls[STR_LEN],*cls_ptr=cls;
  U8 trig[STR_LEN],*trig_ptr=trig;
  U8 key[STR_LEN],*key_ptr=key;
  U8 speed[STR_LEN],*speed_ptr=speed;
  U8 wait[STR_LEN],*wait_ptr=wait;
  U8 monster[STR_LEN],*monster_ptr=monster;
  U8 action[STR_LEN],*action_ptr=action;
  fptr=optr;
  while(ln=ReadALine(&fptr)) {
    if(*ln=='#') goto skip;
    StrScan(ln,"%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
	&num,
	&cls_ptr,
	&trig_ptr,
	&key_ptr,
	&speed_ptr,
	&wait_ptr,
	&monster_ptr,
	&action_ptr
	);
   door=CAlloc(sizeof CDoomDoor);
   door->type='Door';
   action_sector_types[num]=door;
   //Trigger
   door->trigger=trig[0](U16); 
   //Key
   if(!StrCmp("Yell",key)) {
     door->key=DOOR_LOCK_YELLOW;
   } else if(!StrCmp("Blue",key)) {
     door->key=DOOR_LOCK_BLUE;
   } else if(!StrCmp("Red",key)) {
     door->key=DOOR_LOCK_RED;
   } else if(!StrCmp("No",key)) {
     door->key=0;
   } else
     throw('Door');
   //Speed
  if(!StrCmp("Slow",speed)) {
    door->speed=DOOR_SPEED_SLOW;
  } else if(!StrCmp("Fast",speed)) {
    door->speed=DOOR_SPEED_FAST;
  } else 
    throw('Door');
  //Wait
  if(!StrCmp(wait,"--")) {
    door->wait=0.;
  } else if(StrOcc(wait,'s')) {
    door->wait=Str2F64(wait);
  } else 
    throw('Door');
  //Monster
  if(!StrCmp(monster,"Yes"))
    door->monster=TRUE;
  else if(!StrCmp(monster,"No"))
    door->monster=FALSE;
  else
    throw('Door');
//Action
  if(!StrCmp("Open, Wait, Then Close",action)) {
    door->action=DOOR_ACTION_OPEN_WAIT_CLOSE;
  } else if(!StrCmp("Open and Stay Open",action)) {
    door->action=DOOR_ACTION_OPEN;
  } else if(!StrCmp("Close and Stay Closed",action)) {
    door->action=DOOR_ACTION_CLOSE;
  } else if(!StrCmp("Close, Wait, Then Open",action)) {
    door->action=DOOR_ACTION_CLOSE_WAIT_OPEN;
  } else 
    throw('Door');
skip:
    Free(ln);
  }
  Free(optr);
}
LoadDoors;
#endif