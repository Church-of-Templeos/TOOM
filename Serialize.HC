//
// DELETETHISSTUFFWHENDONETESTIN
//

//extern class CDoomAnimationFrame;
class CDoomThing:CQue {
  F64 x,y,angle,height,health;/*
  F64 momx,momy,momz; //Move momentum
  F64 anim_start_tS;
  CDoomAnimationFrame *animation;
  U16 thing_type,pad[3];
  CDoomThingTemplate *template;
  I64 flags;
  Bool solid,anim_no_repeat,pad[6];
  U8 *thinker;*/
};
/*
class CWadBSPNode {
  I16 x,y;
  I16 dx,dy;
  CBoundBoxI16 left,right;
//Dont ask me what these do
  U16 left_child,right_child;
};

class CDoomSidedef:CQue {
  I16 yoff,xoff;
  CDC *upper_texture[4]; //These are for animations
  CDC *lower_texture[4];
  CDC *middle_texture[4];
  CDoomSector *sector;
};
*/

class CDoomLevel 
{
  CQue things;/*//sidedefs;
  CQue subsectors;
  CQue bsp_nodes;
  CQue thinkers;
  CDoomBSPSeg *segs;
  CQue sectors;
  CDoomBSPNode *root_node;
  I64 vertice_cnt;
  CD2 *vertices;
  CQue linedefs;
 I64 block_map_x_off,block_map_y_off;
  I64 block_map_cols,block_map_rows;
  I64 *block_map_offsets;
  I64 skill,episode;
  CDoomSector **block_map_data;
  CDoomLinedef **action_linedefs;
  CLevelStats stats;
//ended is TRUE if we exited the level by pressing a button etc
  Bool has_red_key,has_blue_key,has_yellow_key,ended;
  U8 map_name[5]; //EXMY
 */
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

class CDoomPlayer:CDoomThing 
{
  F64 armor;
  //When you die,the player stares at the thing that killed the player
  CDoomThing *stare_at;
  GunAvail **arsenal;
  Bool running,made_a_sound;
  CQue dummy_que;
};

CDoomPlayer *PlayerNew() {
  U16 gunsInit=0;
  CDoomPlayer *p=CAlloc(sizeof(CDoomPlayer));
  //QueIns(p,&l->things);
  //p->template=doom_thing_types[1];
  //p->flags|=TF_SHOOTABLE;
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
  CDoomLevel *l;
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

U8 *Bin2Str(U8 *data,I64 len)
{
  U8 *str=CAlloc(len*2+1);
  I64 idx=0;
  for(idx=0;idx!=len;idx++) {
    CatPrint(str,"%X%X",data[idx]>>4,data[idx]&0b1111);
  }
  return str;
}

U8 *Bin2StrOld(U8 *data,I64 len)
{
  U8 *str=CAlloc(len*2+1);
  while(--len>=0)
    CatPrint(str,"%X",data[len]);
  return str;
}

U8 *DumpClass(U8 *ptr, U8 *lc=lastclass,I64 off=0)
{
  CHashClass *cls=HashFind(lc,Fs->hash_table,HTT_CLASS),*cls2;
  CMemberLst *mlst;
  U8 *stringToWrite = NULL,*data,*tmp;
  I64 len,total;
  if(!cls) return;
  cls=OptClassFwd(cls);
  while(cls)
    {
    for(mlst=cls->member_lst_and_root;mlst;mlst=mlst->next)
      {
      cls2=mlst->member_class;
      cls2=OptClassFwd(cls2);
      if(cls2->ptr_stars_cnt||cls2->type&HTT_INTERNAL_TYPE) {
"%d,%d\n",off,mlst->offset;
        tmp = MStrPrint("%s%s,%d,%d,%d,%d(%s)\n",stringToWrite,
	      mlst->str,
	      off+mlst->offset,
	      mlst->member_class->raw_type,
	      mlst->member_class->ptr_stars_cnt,
	      mlst->dim.total_cnt,
	      data=Bin2Str(ptr+mlst->offset+off,mlst->size));
        Free(data);
      } else {
	tmp=MStrPrint("%s%s",stringToWrite,data=DumpClass(ptr+mlst->offset+off,cls2->str,off+mlst->offset));
        Free(data);
      }
      Free(stringToWrite); //Free old value
      stringToWrite=tmp;   
    }
    cls=cls->base_class;
  }

  return stringToWrite; 
}

U8 *Str2Bin(U8 *data,I64 len) {
  
  U8 *bin=CAlloc(len>>1);
  U8 buf[3];
  buf[2]=0;
  I64 idx=0,v;
  for(idx=0;idx!=len;idx++) {
    buf[0](U16)=data[idx*2](U16);
    v=Str2I64(buf,16);
    bin[idx]=v;
  }
  return bin;
}
//The address to patch,and the wanted pointer
//The pointer from the disk
U0 LoadClassRlizzler(U8 *to, U8 *lc=lastclass) {
  I64 i;
  CHashClass *cls=HashFind(lc,Fs->hash_table,HTT_CLASS);
  CMemberLst *mlst;
  U8 **ptr_ptr,*tmp;
  while(cls)
  {
   for(mlst=cls->member_lst_and_root;mlst;mlst=mlst->next)
   {
     if(mlst->member_class->ptr_stars_cnt) {
      ptr_ptr=to+mlst->offset;
      "%s,At %P we have %P\n",mlst->str,to+mlst->offset,*ptr_ptr;
      tmp=MStrPrint("RelocFor.%X",to+mlst->offset);
      FramePtrAdd(tmp,*ptr_ptr);
      Free(tmp);
     }
   }
   cls=cls->base_class;
  } 
}
$SP,"<1>",BI=1$$PB$

















//FramePtr(Ptr.[disk_ptr])==new_loaded_ptr
U8 *MapPointerFromDiskToMem(U8 *disk) {
  CHashTable *tab=Fs->hash_table;
  U8 buf[STR_LEN],*buf_ptr=buf;
  U8 *value;
  I64 bucket,best_dist=I64_MAX;
  CHashGeneric *tmph,*best=NULL;
  for(bucket=0;bucket<=tab->mask;bucket++) {
    for(tmph=tab->body[bucket];tmph;tmph=tmph->next) {
      if(StrOcc(tmph->str,'.')) {
        StrScan(tmph->str,"%s.%X",&buf_ptr,&value);
        if(!StrCmp("Ptr",buf)) {
"%x,%x\n",value,disk;
	  if(value<=disk) {
	    if(disk-value<best_dist) {
	      best_dist=disk-value;
	      best=tmph;
	    }
	  }
        }
      }
    }
  }
  if(best) 
    return best->user_data0+best_dist;
  return NULL;
}
U0 PatchItems() {
  CHashTable *tab=Fs->hash_table;
  U8 buf[STR_LEN],*buf_ptr=buf;
  U8 **value,*new_ptr;
  I64 bucket;
  CHashGeneric *tmph;
  for(bucket=0;bucket<=tab->mask;bucket++) {
    for(tmph=tab->body[bucket];tmph;tmph=tmph->next) {
      if(StrOcc(tmph->str,'.')) {
        StrScan(tmph->str,"%s.%X",&buf_ptr,&value);
	if(!StrCmp("RelocFor",buf)) {
	   new_ptr=MapPointerFromDiskToMem(tmph->user_data0);
	   *value=new_ptr;
        }
      }
    }
  }
}



U0 LoadClass(U8 *buffer,U8 *to,U8 *lc=lastclass) {
  CHashClass *cls=HashFind(lc,Fs->hash_table,HTT_CLASS);
  CMemberLst *mlst;
  U8 mname[STR_LEN],*mname_ptr=mname,*bin,*en;
  I64 off,rt,stars,dim;
  while(*buffer&&*buffer!='\n'&&*buffer!='[') {
    buffer=StrScan(buffer,"%s,%d,%d,%d,%d(",&mname_ptr,&off,&rt,&stars,&dim);
    en=StrFirstOcc(buffer,")");
    if(!en) throw('Serial');
    bin=Str2Bin(buffer,en-buffer);$LK,"",A="FI:"$
    MemCpy(to+off,bin,(en-buffer)/2); //2 digits per byte
    Free(bin);
    buffer=en+2; //Skip )\n
  }
  LoadClassRlizzler(to,lc); 

}

CDoomLevel *TESTLoadWadThings()
{
  CDoomLevel *l = MAlloc(sizeof(CDoomLevel));
  QueInit(&l->things);
  CDoomThing *thing = MAlloc(sizeof(CDoomThing));
  thing->x = 10;
  thing->y = 20;
  thing->angle = 42.69;

  QueIns(thing,l->things.last);
  return l;

}

U0 SaveGame(U8 *filename)//in final product, pass in the SaveGame components
{

  CDoomPlayer *p = PlayerNew(),p2;
  //CDoomLevel *l = TESTLoadWadThings();
  QueInit(p);
  QueInit(&p->dummy_que);

  
  U8 *ser;
  ser=DumpClass(p);
  QueCnt(&p->dummy_que);

  //U8 *ser2;
  //ser2=DumpClass(l);
  Print(ser);

  if(!FileFind("/Saves")) DirMk("/Saves");

  CDoc *doc=DocNew(MStrPrint("%s%s%s","/Saves/",filename,".DD"));
  DocPrint(doc,"[PLAYER.%X]:\n%s\n",p,ser);
//  DocPrint(doc,"[LEVEL.%X]:\n%s\n",ser2,);
  DocWrite(doc); //Write to disk
  DocDel(doc);
   
  Free(ser);
}

U0 LoadPreviousGame(U8 *filename)
{
  if(!FileFind(filename)) return;

  CDoc *doc = DocRead(filename);
  U8 *ser = DocSave(doc);
  U8 *optr = ser;

  CDoomPlayer pl;
  //CDoomLevel l;

  U8 buf[STR_LEN],*buf_ptr=buf;;
  U8 *disk_address;
  ser=StrScan(ser,"[%s.%X]:\n",&buf_ptr,&disk_address);//str scan moves the original ptr
  StrPrint(buf,"Ptr.%X",disk_address);
  FramePtrAdd(buf,&pl);

  LoadClass(ser,&pl);
  
  PatchItems;
  //LoadClass2(ser,&pl);
  ClassRep(&pl);
  DocDel(doc);

  Free(optr);
 
}

SaveGame("test");
LoadPreviousGame("/Saves/test.DD");        ”     	Ë  G      ó¶ÍÛ¶­Û¼­][×®mÛæÿÿ?OÒ$I’4I’$I’$i’$I&‰HŠ$I’'I“$IÒ$IÒ$IÒ$I’$É“<É“$M’$I’$IÒ$I‘$I’$I’$I’$I’$I’$I2I%I˜$I˜I’$I¶mÛ°Û†mÃ¶aÛ¶aÛ¶Û¶mØ¶mØ¶mÛæmÛ¼­Ûºm›·mÛ¶mÛ¶mÛ¶mÛ¶mÛ¶mÛ¶mÛ¶u[·u›·mÛ 	!   `      ömÚ¶mÛ¶mÛ¶mÛ	+          ¶mÛ¶mÛ¶mÛ¶mÛ¶mÛö 	   µ   #   ¶m›¶oÛ	!   ´   -   ‘`CmÛl	   Ã   +   R$É’$Ù 	   ½       äI’'	   Ñ   &   ë¶Í¶m	   ¹   9   I	   ±   8   ¤D’$y	   Æ   9   L’$É 	   Î   2   umÛ$)2Ò¶nÛ<	V   &      ¤mÛ¦oÛ¶mÛ·}Û¶íÛ´mÛ¶mÛ¶mÛ¶mÛ¶mÛ¶í	      d   ´mÛ´mß¶mÛ6	#   "   r   ’(Š¢˜l  `Øæ­«	   /   b   ´m›¶M	*   ;   h   $yÛìºmC$IÒþOž4	?   G   e   ôMßôM’”’$I’Ì¶mÛ¶}Û6mßµm	6   d   j   É¶ns»µ#Éó$Ïm]gÛ¾mž$I	   j   x   d’$AÂ„¤D’   