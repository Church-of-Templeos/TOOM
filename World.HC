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
#define DOOR_SPEED_NORMAL 2.
#define DOOR_SPEED_FAST 3.
#define DOOR_SPEED_TURBO 4.


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

#define FLOOR_DST_LOWEST 1
#define FLOOR_ABS_24 2
#define FLOOR_ABS_512 3
#define FLOOR_DST_HIGHEST_CEIL 4
#define FLOOR_DST_HIGHEST_CEIL_ADD_8 5
#define FLOOR_DST_HIGHEST_FLOOR 6
#define FLOOR_DST_HIGHEST_FLOOR_ADD_8 7
#define FLOOR_DST_LOWEST_CEIL 8
#define FLOOR_DST_LOWEST_CEIL_SUB_8 9
#define FLOOR_DST_LOWEST_FLOOR 10
#define FLOOR_DST_LOWEST_FLOOR_SUB_8 11
#define FLOOR_DST_NEXT_FLOOR 12
#define FLOOR_DST_ANAL_BEADS 13
#define FLOOR_DST_LOWEST_TEXTURE 14

#define FLOOR_DIR_NONE 0
#define FLOOR_DIR_UP 1
#define FLOOR_DIR_DOWN 2


#define FLOOR_MODEL_NONE 0
#define FLOOR_MODEL_TRIGGER 1
#define FLOOR_MODEL_NUMBERED 2

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
  I64 target
};


union CDoomActionSector {
  U64 type;
  CDoomDoor door;
};

CDoomActionSector *action_sector_types[0x10000];
MemSet(action_sector_types,0,0x10000*8);

#define DOOM_DOORS_FILE "Doors.TXT"
#define DOOM_FLOORS_FILE "Floors.TXT"
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

U0 LoadFloors() {
  U8 *optr=FileRead(DOOM_FLOORS_FILE),*fptr,*ln;
  I64 num;
  U8 cls[STR_LEN],*cls_ptr=cls;
  U8 trig[STR_LEN],*trig_ptr=trig;
  U8 direction[STR_LEN],*direction_ptr=direction;
  U8 speed[STR_LEN],*speed_ptr=speed;
  U8 change[STR_LEN],*change_ptr=change;
  U8 mdl[STR_LEN],*mdl_ptr=mdl;
  U8 monster[STR_LEN],*monster_ptr=monster;
  U8 crush[STR_LEN],*crush_ptr=crush;
  U8 target[STR_LEN],*target_ptr=target;
  CDoomFloor *floor;
  StrUtil(optr,SUF_REM_CTRL_CHARS);
  fptr=optr;
  while(ln=ReadALine(&fptr)) {
    if(*ln=='#') goto skip;
    StrScan(ln,"%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
	  &num,
	  &cls_ptr,
	  &trig_ptr,
	  &direction_ptr,
	  &speed_ptr,
	  &change_ptr,
	  &mdl_ptr,
	  &monster_ptr,
	  &crush_ptr,
	  &target_ptr
	  );
    floor=CAlloc(sizeof CDoomFloor);
    floor->type='Floor';
    action_sector_types[num]=floor;
//Todo What the poo poo ants
    if(!StrCmp(cls,"Ext")) {
    } else if(!StrCmp(cls,"Reg")) {
    } else if(!StrCmp(cls,"Gen")) {
    }
//trigga
    floor->trigger=trig[0](U16); 
//Sped
    if(!StrCmp("Slow",speed)) {
      floor->speed=DOOR_SPEED_SLOW;
    } else if(!StrCmp("Fast",speed)) {
      floor->speed=DOOR_SPEED_FAST;
    } else if(!StrCmp("Normal",speed)) {
      floor->speed=DOOR_SPEED_NORMAL;
    } else if(!StrCmp("Turbo",speed)) {
      floor->speed=DOOR_SPEED_TURBO;
    } else if(speed[0]=='-') {
      floor->speed=0;
    } else 
      throw('Floor');
//Durectin
    if(!StrCmp("Up",direction)) {
      floor->direction=FLOOR_DIR_UP;
    } else if(!StrCmp("Dn",direction)) {
      floor->direction=FLOOR_DIR_DOWN;
    } else if(direction[0]=='-') {
      floor->direction=FLOOR_DIR_NONE;
    } else
      throw('Floor');
//cange
    if(!StrCmp("None",change)) {
    } else if(!StrCmp("TxTy",change)) {
      floor->texture_change=TRUE;
      floor->type_change=TRUE;
    } else if(!StrCmp("Tx",change)) {
      floor->texture_change=TRUE;
    } else if(!StrCmp("Ty",change)) {
      floor->type_change=TRUE;
    } else if(change[0]=='-') {
//Nothing to do
    }else
      throw('Floor');
//Instagram thot(model)
    if(!StrCmp("--",mdl)) {
      floor->model=FLOOR_MODEL_NONE;
    } else if(!StrCmp("Trg",mdl)) {
      floor->model=FLOOR_MODEL_TRIGGER;
    } else if(!StrCmp("Num",mdl)) {
      floor->model=FLOOR_MODEL_NUMBERED;
    } else
      throw('Floor');  
//Japanese tencacle pornstar(monster property)
    if(!StrCmp("No",monster)) {
      floor->monster=FALSE;
    } else if(!StrCmp("Yes",monster)) {
      floor->monster=TRUE;
    } else if(monster[0]=='-') {
    } else
      throw('Floor'); 
//Orange Soda (Crush property)
    if(!StrCmp("No",crush)) {
      floor->crush=FALSE;
    } else if(!StrCmp("Yes",crush)) {
      floor->crush=TRUE;
    } else if(crush[0]=='-') {
    } else
      throw('Floor'); 
//Target
    if(!StrCmp("Lowest Neighbor Floor",target)) {
      floor->target=FLOOR_DST_LOWEST;
    } else if(!StrCmp("Next Neighbor Floor",target)) {
      floor->target=FLOOR_DST_NEXT_FLOOR;
    } else if(!StrCmp("Lowest Neighbor Ceiling",target)) {
      floor->target=FLOOR_DST_LOWEST_CEIL;
    } else if(!StrCmp("Lowest Neighbor Ceiling - 8",target)) {
      floor->target=FLOOR_DST_LOWEST_CEIL_SUB_8;
    } else if(!StrCmp("Highest Neighbor Floor",target)) {
      floor->target=FLOOR_DST_HIGHEST_FLOOR;
    } else if(!StrCmp("Highest Neighbor Floor + 8",target)) {
      floor->target=FLOOR_DST_HIGHEST_FLOOR_ADD_8;
    } else if(!StrCmp("Absolute 24",target)) {
      floor->target=FLOOR_ABS_24;
    } else if(!StrCmp("Abs Shortest Lower Texture",target)) {
      floor->target=FLOOR_DST_LOWEST_TEXTURE;
    } else if(!StrCmp("Absolute 512",target)) {
      floor->target=FLOOR_ABS_512;
    } else if(!StrCmp("None",target)) {
    } else 
      throw('Floor');
skip:
    Free(ln);
  }
  Free(optr);
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
  StrUtil(optr,SUF_REM_CTRL_CHARS);
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
LoadFloors;
#endif