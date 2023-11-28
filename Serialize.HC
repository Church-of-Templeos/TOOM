//
// DELETETHISSTUFFWHENDONETESTIN
//
class CB
{
  I64 three;
  I64 four;
};

class CA
{
  U8 *one;
  CB two;
};

class AmmoType{
  U64 ammo;
  Bool splash;  
};

class GunAvail{
  Bool available;
  I16 baseDamage;
  AmmoType *load;
};
class CDoomThingTemplate {
  U8 spr_base_name[4],pad[4];
  U8 *animation;
  //CDoomAnimationFrame *_animation;
  I64 height,radius,type;
#define TF_POWERUP 1
#define TF_ARTIFACT 2
#define TF_WEAPON 4
#define TF_MONSTER 8
#define TF_OBSTACLE 0x10
#define TF_SHOOTABLE 0x20
#define TF_FLOATING 0x40
#define TF_MISSILE 0x80
  I64 code;
  I64 flags;
} *doom_thing_types[0x10000];

//extern class CDoomAnimationFrame;
class CDoomThing:CQue {
  F64 x,y,angle,height,health;
  F64 momx,momy,momz; //Move momentum
  F64 anim_start_tS;
  //CDoomAnimationFrame *animation;
  U16 thing_type,pad[3];
  CDoomThingTemplate *template;
  I64 flags;
  Bool solid,anim_no_repeat,pad[6];
  U8 *thinker;
};
class CDoomPlayer:CDoomThing 
{
  F64 armor;
  //When you die,the player stares at the thing that killed the player
  CDoomThing *stare_at;
  GunAvail **arsenal;
  Bool running,made_a_sound;
};

CDoomPlayer *PlayerNew() {
  U16 gunsInit=0;
  CDoomPlayer *p=CAlloc(sizeof(CDoomPlayer));
  //QueIns(p,&l->things);
  p->template=doom_thing_types[1];
  p->flags|=TF_SHOOTABLE;
  p->health=100;
  p->armor=100;
  p->arsenal=CAlloc(sizeof(GunAvail*)*8);  
  for(gunsInit=0;gunsInit<8;gunsInit++)
  {
    p->arsenal[gunsInit] = CAlloc(sizeof(GunAvail));
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
        p->arsenal[gunsInit]->load->ammo=0;
        p->arsenal[gunsInit]->baseDamage=4;
        p->arsenal[gunsInit]->load->splash=FALSE;   
        break;
      case 3://chaingun
        p->arsenal[gunsInit]->load = p->arsenal[1]->load;
        p->arsenal[gunsInit]->baseDamage=4;
        break;
      case 4://rocket launcher
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
        p->arsenal[gunsInit]->load->ammo=0;
        p->arsenal[gunsInit]->baseDamage=20;
        p->arsenal[gunsInit]->load->splash=TRUE;
        break;
      case 5://chainsaw
        p->arsenal[gunsInit]->load = p->arsenal[0]->load;
        p->arsenal[gunsInit]->baseDamage=3;
        break;
      case 6://plasma
        p->arsenal[gunsInit]->load = CAlloc(sizeof(AmmoType));
        p->arsenal[gunsInit]->load->ammo=0;
        p->arsenal[gunsInit]->baseDamage=5;
        p->arsenal[gunsInit]->load->splash=FALSE;
        break;
      case 7://bfg
        p->arsenal[gunsInit]->load = p->arsenal[6]->load;
        p->arsenal[gunsInit]->baseDamage=100;
        break;
    }

  }
  p->x=20;
  p->y=10;
  p->angle=90;
  
  return p;
}


//
// REMOVETHEABOVEONCEDONETESTING
//

//STARTSERIALIZATIONCODE

class SaveGame
{
  CDoomPlayer *p;
  //CDoomCamera *c;
  //CDoomLevel *l;
};

U8 *ReadALine(U8 **fbuf)
{
 U8 *en,*st=*fbuf,*buf;
 if(!*st) return NULL;
 if(en=StrFirstOcc(st,"\n")){
  buf=MAlloc(en-st+2);
  MemCpy(buf,st,en-st+1);
  buf[en-st+1]=0;
  *fbuf=en+1;
  return buf;
 }
 *fbuf+=StrLen(st);
 return StrNew(st);
}    

SaveGame *LoadGame(U8 *fileptr)
{
  //initialize
  SaveGame *loaded = MAlloc(sizeof(SaveGame));
  loaded->p = PlayerNew();

  U8 *fptr = FileRead(fileptr), *lnptr,*ln,*temp;
  I32 count=0;
  StrUtil(fptr,SUF_REM_CTRL_CHARS);  
  lnptr=fptr;



  while(ln=ReadALine(&lnptr))
  {
   if(*ln==0)
    goto skip;

   switch(count)
   {
    case 0:
     StrScan(ln,"%s,%f\n",&(loaded->p->armor));
     break;
    case 1:
     break;
   }
   skip:;
   Free(ln);
   count++;


  }


}
U8 *Bin2Str(U8 *data,I64 len) {
  U8 *str=CAlloc(len*2+1);
  while(--len>=0)
    CatPrint(str,"%X",data[len]);
  return str;
}
U8 *DumpClass(U8 *ptr, U8 *lc=lastclass)
{
 CHashClass *cls=HashFind(lc,Fs->hash_table,HTT_CLASS);
 CMemberLst *mlst;
 U8 *stringToWrite = NULL,*data,*tmp;
 I64 len,total;
 if(!cls) return;
 while(cls)
 {
  for(mlst=cls->member_lst_and_root;mlst;mlst=mlst->next)
  {
   tmp = MStrPrint("%s%s,%d,%d,%d,%d(%s)\n",stringToWrite,
	mlst->str,
	mlst->offset,
	mlst->member_class->raw_type,
	mlst->member_class->ptr_stars_cnt,
	mlst->dim.total_cnt,
	data=Bin2Str(ptr+mlst->offset,mlst->size));
   Free(stringToWrite); //Free old value
   Free(data);
   stringToWrite=tmp;   
  }
  cls=cls->base_class;
 }

 return stringToWrite; 
}

U0 SaveGame()//in final product, pass in the SaveGame components
{

  CDoomPlayer *p = PlayerNew(); 
  Print(DumpClass(&p));

  //CA *main = MAlloc(sizeof(CA));
  //main->two = MAlloc(sizeof(CB));
  //DumpClass(&main);
  //Free(main->two);
  //Free(main);


  //Need to Free Player in the main game
 
}

SaveGame;