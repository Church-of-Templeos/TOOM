#define DEBUG 1

#include "DoomGr.HC";
//https://doomwiki.org/wiki/WAD
class CWadDirectory {
  U32 ptr;
  U32 lump_size;
  U8 lump_name[8];
};

//https://doomwiki.org/wiki/Thing
class CWadThing {
#define  WAD_THINGF_SKILL12 1
#define  WAD_THINGF_SKILL3 2
#define  WAD_THINGF_SKILL45 4
#define  WAD_THINGF_WAIT 8 //Monster will be waiting
#define  WAD_THINGF_MULTIPLAYER 0x10 //For multiplayer maps 
  I16 x,y,angle,thing_type,flags;
};

//https://doomwiki.org/wiki/Linedef
class CWadLinedef {
  I16 start_vertex;
  I16 end_vertex;
#define WAD_LINEDEFF_WALL 1 //Wall for player and monsters
#define WAD_LINEDEFF_WALL_MONSTER 2 //Wall for monsters only
#define WAD_LINEDEFF_2SIDED 4
#define WAD_LINEDEFF_UPPER_UNPEGGED 8
#define WAD_LINEDEFF_LOWER_UNPEGGED 0x10
#define WAD_LINEDEFF_SECRET 0x20
#define WAD_LINEDEFF_BLOCK_SOUND 0x40
#define WAD_LINEDEFF_NO_SHOW_ON_MAP 0x80
#define WAD_LINEDEFF_SHOW_ON_MAP 0x100
  I16 flags;
  I16 special_type;
  I16 sector_tag;
  I16 front,back; //See CWadSidedef
};

class CWadSidedef {
  I16 x_offset;
  I16 y_offset;
  U8 upper_texture_name[8];
  U8 lower_texture_name[8];
  U8 middle_texture_name[8];
  I16 sector;
};

class CWadSector {
  I16 floor_height;
  I16 ceil_height;
  U8 floor_texture_name[8];
  U8 ceil_texture_name[8];
  I16 light_level;
#define WAD_SECTOR_NORMAL 0
#define WAD_SECTOR_BLINK_RAND 1
#define WAD_SECTOR_BLINK05 2
#define WAD_SECTOR_BLINK1 3
#define WAD_SECTOR_BLINK05_DAM20 4
#define WAD_SECTOR_DAM10 5
#define WAD_SECTOR_DAM5 7
#define WAD_SECTOR_LIGHT 8 //Ossicaltes
#define WAD_SECTOR_SECRET 9
#define WAD_SECTOR_DOOR_CLOSE30 10 //(Ceiling) Door clooses after 30 seconds
#define WAD_SECTOR_END 11 //20 damage a second,level END's when dead
#define WAD_SECTOR_BLINK1_2 12
#define WAD_SECTOR_BLINK05_2 13
#define WAD_SECTOR_DOOR_OPEN300 14 //(Ceiling) Door opens after 300 seconds
#define WAD_SECTOR_DAM20 16
#define WAD_SECTOR_BLINK_RAND_2 17
  I16 special_type;
  I16 tag_number;
};

class CWadVertex {
  I16 x,y;
};

class CWad {
  U8 body[0];
  U8 ident[4];
  U32 lump_cnt;
  U32 directory_ptr;
}; 


CWad *LoadWad(U8 *filename) {
  return FileRead(filename);
}

class CDoomThing:CQue {
  F64 x,y,angle;
  I16 thing_type,flags;
};

class CDoomTexture:CQue {
  CDC *todo;
};

class CDoomSidedef:CQue {
  I16 yoff,xoff;
  CDoomTexture *ceil_texture;
  CDoomTexture *floor_texture;
  CDoomTexture *middle_texture;
  //TODO sector
};

class CBoundBoxI16 {
  I16 y,y2,x,x2;
};

class CWadBSPNode {
  I16 x,y;
  I16 dx,dy;
  CBoundBoxI16 left,right;
//Dont ask me what these do
  I16 left_child,right_child;
};

class CBoundBoxF64 {
  F64 y,y2,x,x2;
};


class CDoomBSPNode:CQue {
  U64 signature;
  F64 x,y;
  F64 dx,dy;  
  CBoundBoxF64 left,right;

};

class CDoomLinedef:CQue {
  CD2 *start,*end;
  CDoomSidedef *front;
  CDoomSidedef *back;
  I16 flags;
  I16 special_type;
  I16 sector_tag;
};

class CDoomGr {
  CRGB *palette;
};

class CDoomLevel {
  CQue things;
  CQue bsp_nodes;
  I64 vertice_cnt;
  CD2 *vertices;
  CQue linedefs;
};

I64 StrCmp8(U8 *a,U8 *b) {
  if(StrLen(a)>8||StrLen(b)>8)
    return StrNCmp(a,b,8);
  return StrCmp(a,b);
}


U0 GrDrawBBox(CDC *dc,I64 x,I64 y,I64 x2,I64 y2) {
//Top
  GrLine3(dc,x,y,0,x2,y,0);
//Right
  GrLine3(dc,x2,y,0,x2,y2,0);
//Left
  GrLine3(dc,x,y,0,x,y2,0);
//Bottom
  GrLine3(dc,x,y2,0,x2,y2,0);
}

U0 DrawLevelOverview(CDoomLevel *level,CDC *dc=gr.dc,F64 scale=1,Bool show_bsp=FALSE) {
//INCOMPLETE
  CDoomBSPNode *node;
  CDoomLinedef *wall,*head=&level->linedefs;
  dc->color=RED;
  dc->thick=2;
  I64 x=GR_WIDTH/2,y=GR_HEIGHT/2+200;
  for(wall=head->next;wall!=head;wall=wall->next) {
    GrLine3(dc,
	x+wall->start->x*scale,y+wall->start->y*scale,0,
	x+wall->end->x*scale,y+wall->end->y*scale,0
	);
  }
  if(show_bsp) {
    head=&level->bsp_nodes;
    dc->thick=1;
    for(node=head->next;node!=head;node=node->next) {
      dc->color=LTGREEN;
      GrDrawBBox(dc,x+node->left.x*scale,y+node->left.y*scale,
	x+node->left.x2*scale,y+node->left.y2*scale);
      dc->color=LTRED;
      GrDrawBBox(dc,x+scale*node->right.x,y+scale*node->right.y,
	x+scale*node->right.x2,y+scale*node->right.y2);
      dc->color=PURPLE;
      GrArrow3(dc,node->x*scale+x,node->y*scale+y,0,
	(node->x+node->dx)*scale+x,(node->y+node->dy)*scale+y,0);
    }
  }
}


CDoomGr *LoadWadGr(CWad *wad) {
  CDoomGr *ret=CAlloc(sizeof(CDoomGr));
  CWadDirectory *wad_dir;
  I64 idx;
  U8 lump_name[9];
  CDC *gr;
//Load Play palette
  wad_dir=wad->body+wad->directory_ptr;
  for(idx=0;idx!=wad->lump_cnt;idx++) {
    if(!StrCmp8(wad_dir->lump_name,"PLAYPAL"))
      goto found_pal;
    wad_dir++;
  }
  throw('Wad');
  found_pal:
  ret->palette=LoadPLAYPALFromLump(wad->body+wad_dir->ptr);
//Find the sprites start
  wad_dir=wad->body+wad->directory_ptr;
  for(idx=0;idx!=wad->lump_cnt;idx++) {
    if(!StrCmp8(wad_dir->lump_name,"S_START")) {
      goto found_sstart;
    }
    wad_dir++;
  }
  throw('Wad'); 
found_sstart:
  wad_dir++; //Move past S_START
  if(StrCmp8(wad_dir->lump_name,"S_END")) {
    gr=ReadDoomImage(wad,wad->body+wad_dir->ptr,ret->palette);
    lump_name[8]=0;
    MemCpy(lump_name,wad_dir->lump_name,8);
    FramePtrAdd(lump_name,gr);
#ifdef DEBUG
//    GrBlot(,0,0,gr);
//    Sleep(100);
#endif
    goto found_sstart;
  }
}

CDoomLevel *LoadWadLevel(CWad *wad,U8 *level_name) {
  I64 idx,cnt;
  CDoomLevel *level=CAlloc(sizeof CDoomLevel);
  CDoomThing *dthing;
  CWadThing *wthing;
  CWadVertex *vertex;
  CWadDirectory *wad_dir;
  CWadBSPNode *wnode;
  CDoomBSPNode *dnode;
  CWadLinedef *wlinedef;
  CDoomLinedef *dlinedef;
  QueInit(&level->things);
  QueInit(&level->linedefs);
  QueInit(&level->bsp_nodes);
  wad_dir=wad->body+wad->directory_ptr;
  for(idx=0;idx!=wad->lump_cnt;idx++) {
    if(!StrCmp8(wad_dir->lump_name,level_name))
      goto found;
    wad_dir++;
  }
  Free(level);
  return NULL;
found:
//Order of other lumps is 
//THINGS
//LINEDEFS
//SIDEDEFS
//VERTEXES
//rest will not be used for now
//Move past level lump
  wad_dir++;
  //Things
  cnt=wad_dir->lump_size/sizeof(CWadThing);
  wthing=wad_dir->ptr+wad->body;
  for(idx=0;idx!=cnt;idx++) {
    dthing=CAlloc(sizeof CDoomThing);
    dthing->x=wthing->x;
    dthing->y=wthing->y;
    dthing->angle=wthing->angle/ToF64(I16_MAX)*2*pi;
    dthing->thing_type=wthing->thing_type;
    dthing->flags=wthing->flags;
    QueIns(dthing,level->things.last);
    wthing++;
  }
  //Load vertexes first P
  cnt=wad_dir[3].lump_size/sizeof(CWadVertex);
  vertex=wad_dir[3].ptr+wad->body;
  level->vertice_cnt=cnt;
  level->vertices=MAlloc(sizeof(CD2)*cnt);
  if(StrCmp8("VERTEXES",wad_dir[3].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    level->vertices[idx].x=vertex->x;
    level->vertices[idx].y=vertex->y;
    vertex++;
  }  
  //LINEDEFS
  cnt=wad_dir[1].lump_size/sizeof(CWadLinedef);
  wlinedef=wad_dir[1].ptr+wad(U8*);
  if(StrCmp8("LINEDEFS",wad_dir[1].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dlinedef=CAlloc(sizeof(CDoomLinedef));
    dlinedef->start=wlinedef->start_vertex+level->vertices;
    dlinedef->end=wlinedef->end_vertex+level->vertices;
    QueIns(dlinedef,level->linedefs.last);
    wlinedef++;
  }
// Bsp NODES
  cnt=wad_dir[6].lump_size/sizeof(CWadBSPNode);
  wnode=wad_dir[6].ptr+wad(U8*);
  if(StrCmp8("NODES",wad_dir[6].lump_name)) throw('Wad');
  while(--cnt>=0) {
    dnode=CAlloc(sizeof CDoomBSPNode);
    dnode->x=wnode->x;
    dnode->y=wnode->y;
    dnode->dx=wnode->dx;
    dnode->dy=wnode->dy;
    dnode->left.x=wnode->left.x;
    dnode->left.y=wnode->left.y;
    dnode->left.x2=wnode->left.x2;
    dnode->left.y2=wnode->left.y2;
//TODO child nodes
    dnode->right.x=wnode->right.x;
    dnode->right.y=wnode->right.y;
    dnode->right.x2=wnode->right.x2;
    dnode->right.y2=wnode->right.y2;
    QueIns(dnode,&level->bsp_nodes);
    wnode++;
  } 
  return level;
}

U0 DumpWad(CWad *wad) {
  I64 lump,ptr,lump_sz,ptr2;
  U8 *name;
  "IDENT:%s\n",wad->ident;
  ptr=wad->directory_ptr;
  for(lump=0;lump!=wad->lump_cnt;lump++) {
    "LUMP:%c(%X)\n",(name=(wad->body+ptr)(CWadDirectory*)->lump_name)(U64*)[0],
	lump_sz=(wad->body+ptr)(CWadDirectory*)->lump_size;
    if(!StrCmp("THINGS",name)) {
      ptr2=(wad->body+ptr)(CWadDirectory*)->ptr;
      "THING:\n"
      "\tX:%d\n",(wad->body+ptr)(CWadThing*)->x;
      "\tY:%d\n",(wad->body+ptr)(CWadThing*)->y;
      "\tANGLE:%n\n",(wad->body+ptr)(CWadThing*)->angle/ToF64(I16_MAX)*2*pi;
      "\tTYPE:%X\n",(wad->body+ptr)(CWadThing*)->thing_type;
    }
    ptr(CWadDirectory*)++;
  }
  
}



CWad *wad=LoadWad("DOOM.WAD");
CDoomLevel *l=LoadWadLevel(wad,"E1M1");
DCFill;
if(l)
  DrawLevelOverview(l,gr.dc,1/8.,TRUE);
DumpWad(wad);
LoadWadGr(wad);
