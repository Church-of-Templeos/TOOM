#ifndef DOOM_WAD
#define DOOM_WAD
#define DEBUG 1

#include "DoomGr.HC";
#include "Numbers/Vector.HC";
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


class CWadSeg {
  I16 start_vertex,end_vertex;
  I16 angle,linedef;
//0 is same dir as linedef,else opposite
  I16 side,offset; 

};


class CWadSubsector {
//Consistys of SEGS
  I16 cnt;
  I16 first;
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
extern class CDoomSector;

class CDoomSidedef:CQue {
  I16 yoff,xoff;
  CDC *upper_texture;
  CDC *lower_texture;
  CDC *middle_texture;
  CDoomSector *sector;
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
  CDoomBSPNode *left_child,*right_child;
  CDoomBSPNode *parent;
  F64 x,y;
  F64 dx,dy;  
  CBoundBoxF64 left,right;

};

Bool BoundBoxF64Inside(F64 x,F64 y,CBoundBoxF64 *box) {
  if(box->x<box->x2) 
    if(!(box->x<=x<=box->x2))
      return FALSE;
  if(box->y<box->y2) 
    if(!(box->y<=y<=box->y2))
      return FALSE;
  if(box->x>box->x2) 
    if(!(box->x2<=x<=box->x))
      return FALSE;
  if(box->y>box->y2) 
    if(!(box->y2<=y<=box->y))
      return FALSE;
  return TRUE;
}

class CDoomLinedef:CQue {
  CD2 *start,*end;
  CDoomSidedef *front;
  CDoomSidedef *back;
  I16 flags;
  I16 special_type;
  I16 sector_tag;
};

class CDoomSeg:CQue {
  F64 x,y,x2,y2;
  CDoomLinedef *linedef;
};

class CDoomSubsector:CQue {
  U64 signature;
  I64 cnt;
  CDoomBSPNode *first;
};

class CDoomGr {
  CRGB *palette;
  I64 pname_cnt;
  U64 *pnames;
};

class CDoomSector:CQue {
  CDC *floor_dc;
  CDC *ceil_dc;
  F64 ceil_height;
  F64 floor_height;
  F64 base_light_level,cur_light_level;
  I64 special_type;
  I64 linedef_cnt;
  CDoomLinedef **linedefs;
//TODO make up polygon(s) lines
};



class CDoomLevel {
  CQue things,sidedefs;
  CQue subsectors;
  CQue bsp_nodes;
  CQue segs;
  CQue sectors;
  CDoomBSPNode *root_node;
  I64 vertice_cnt;
  CD2 *vertices;
  CQue linedefs;
};

class CWadTexturePatch {
  I16 origin_x,origin_y;
  I16 patch_index;
  I16 unused,unused2;
};

class CWadTexture {
  U8 name[8];
  I32 unused;
  I16 w,h;
  I32 unused2;
  I16 patch_cnt; 
  CWadTexturePatch patches[0];
};

class CWadTEXTURE1 {
  I32 num_textures;
  I32 texture_offsets[0];
};

CDC *PNameIndexToDC(I64 idx,CDoomGr *gr) {
  U8 name[9];
  name[8]=0;
  MemCpy(name,&gr->pnames[idx],8);
  return FramePtr(name);
}


U0 LoadWadTEXTUREs(CWadTEXTURE1 *header,CDoomGr *gr) {
  I64 texture,i;
  U8 name[9];
  CDC *result,*patch;
  CWadTexture *map_texture;
  for(texture=0;texture!=header->num_textures;texture++) {
    map_texture=header(U8*)+header->texture_offsets[texture];
    result=DCNew(map_texture->w,map_texture->h);
    DCFill(result,TRANSPARENT);
    name[8]=0;
    MemCpy(name,map_texture->name,8);
    for(i=0;i!=map_texture->patch_cnt;i++) {
      if(patch=PNameIndexToDC(map_texture->patches[i].patch_index,gr))
      GrBlot(result,
	map_texture->patches[i].origin_x,
	map_texture->patches[i].origin_y,
	patch);
    } 
    FramePtrAdd(name,result);
//    GrBlot(,0,0,result);
//    Sleep(10);
  }
}

I64 StrCmp8(U8 *a,U8 *b) {
  if(StrLen(a)>8||StrLen(b)>8)
    return StrNCmp(a,b,8);
  return StrCmp(a,b);
}


//
// W_CheckNumForName
// Returns -1 if name not found.
//

I64 W_CheckNumForName (U8 *name,CWad *doom_wad)
{

    U8 name8[9];    
    
    I32		v1;
    I32		v2;
    CWadDirectory*	lump_p;

    // make the name into two integers for easy compares
    MemCpy (name8,name,8);

    // in case the name was a fill 8 chars
    name8[8] = 0;

    // case insensitive
    for(v1=0;v1!=8;v1++)
      name8[v1]=ToUpper(name8[v1]);

    // scan backwards so patch lump files take precedence
    CWadDirectory *lumpinfo = doom_wad(U8*)+doom_wad->directory_ptr;
    lump_p=lumpinfo+doom_wad->lump_cnt;

    while (lump_p-- != lumpinfo)
    {
	if (!StrCmp8(lump_p->lump_name,name8))
	{
	    return lump_p - lumpinfo;
	}
    }

   return -1;
}

#if 0 //Sorry,make sure the code compiles

//
// W_GetNumForName
// Calls W_CheckNumForName, but bombs out if not found.
//
U0 W_GetNumForName (U8 *name)
{
    int	i;

    i = W_CheckNumForName (name);
    
    if (i == -1)
      PutExcept("W_GetNumForName: %s not found!", name);
      
    return i;
}


//
// W_LumpLength
// Returns the buffer size needed to load the given lump.
//
U0 W_LumpLength (I64 lump)
{
    if (lump >= numlumps)
	PutExcept("W_LumpLength: %i >= numlumps",lump);

    return lumpinfo[lump].size;
}
#endif
//
//Nroot,get lump by num
//
U8 *W_GetLumpPtrFromNum(I64 idx,CWad *wad,I64 *lump_len=NULL) {
  CWadDirectory *dir=wad(U8*)+wad->directory_ptr;
  dir+=idx;
  if(lump_len) *lump_len=dir->lump_size;
  return wad(U8*)+dir->ptr;
} 
//
// Nroot,Get pointer to lump
//
U8 *W_GetLumpPtrFromName(U8 *name,CWad *wad,I64 *lump_len=NULL) {
  I64 idx=W_CheckNumForName(name,wad);
  return W_GetLumpPtrFromNum(idx,wad,lump_len);
}

U0 AddLinedefToSector(CDoomSector *ld,CDoomSector *s) {
  CDoomLinedef **list=MAlloc(8*(s->linedef_cnt+1));
  if(s->linedef_cnt)
    MemCpy(list,s->linedefs,8*s->linedef_cnt);
  Free(s->linedefs);
  s->linedefs=list;
  list[s->linedef_cnt++]=ld;
}

CDoomBSPNode *DoomWhichBSPNode(F64 x,F64 y,CDoomLevel *level,CDoomSubsector **ss=NULL) {
  CDoomBSPNode *cur_node=level->root_node;
  Vector pline;
  Bool left,right;
  CD2 dummy;
  if(ss) *ss=NULL;
  while(TRUE) {
    if(!cur_node)
      break;
    right=left=FALSE;
    if(BoundBoxF64Inside(x,y,&cur_node->left)) {
      left=TRUE;
    }
    if(BoundBoxF64Inside(x,y,&cur_node->right)) {
      right=TRUE;
    }
    if(!left&&!right) return cur_node;
    if(left^^right) { //Check for difference
      if(left) {
lefts:
        if(cur_node->left_child->signature!='NODE') {
	  if(ss) *ss=cur_node->left_child;
	  return cur_node;
	}
        cur_node=cur_node->left_child;
      } else {
rights:
        if(cur_node->right_child->signature!='NODE') {
	  if(ss) *ss=cur_node->right_child;
	  return cur_node;
	}
        cur_node=cur_node->right_child;
      }
    } else if(left&&right) {
//Check which side of parition line
      pline=CreateVector(2);
      dummy.x=x-cur_node->x;
      dummy.y=y-cur_node->y;
      SetVector(pline,cur_node->dx,0);
      SetVector(pline,cur_node->dy,1);
      if(!IsFrontSideOfVector2D(pline,&dummy)) {
        DestroyVector(pline);
	goto lefts;
      }
        DestroyVector(pline);
	goto rights;
//
    }
  }
  return NULL;
}

#include "Intersect.HC"

Bool _DoomClipLinedef(F64 fov,F64 vx,F64 vy,F64 angle,CDoomLinedef *ld,CD2 *left,CD2 *right,Bool swap) {
  CD2 at,view,view_end,tmp,tmp2;
  I64 try_swap;
  Bool hit_left,hit_right,res=TRUE;
  Vector *side=CreateVector(2),*side2=CreateVector(2);
  F64 relx,rely;
  view.x=vx;
  view.y=vy;
  view_end.x=vx+65000*Cos(angle-fov/2);
  view_end.y=vy+65000*Sin(angle-fov/2);
  SetVector(side,view_end.x-vx,0);
  SetVector(side,view_end.y-vy,1);
  hit_left=PlaneIntersect(&at,&view,&view_end,ld->start,ld->end);
  if(!left) left=&tmp;
  if(hit_left) {
    left->x=at.x;
    left->y=at.y;
  } else {
    if(swap) {
      left->x=ld->end->x;
      left->y=ld->end->y;
    } else {
      left->x=ld->start->x;
      left->y=ld->start->y;
    }
  }
  view_end.x=vx+65000*Cos(angle+fov/2);
  view_end.y=vy+65000*Sin(angle+fov/2);
  SetVector(side2,view_end.x-vx,0);
  SetVector(side2,view_end.y-vy,1);
  hit_right=PlaneIntersect(&at,&view,&view_end,ld->start,ld->end);
  if(!right) right=&tmp;
  if(hit_right) {
    right->x=at.x;
    right->y=at.y;
  } else {
    if(swap) {
      right->x=ld->start->x;
      right->y=ld->start->y;
    } else {
      right->x=ld->end->x;
      right->y=ld->end->y;
    }
  }
//Check +/- fov/2 left AND right
  res=TRUE;
  if(!hit_left) {
    tmp2.x=left->x-vx;
    tmp2.y=left->y-vy;
    if(SideOfVector2D(side2,&tmp2)>0) {
      res=FALSE;
    }
    if(SideOfVector2D(side,&tmp2)<0) {
      res=FALSE;
    }
  }
  if(!hit_right) {
    tmp2.x=right->x-vx;
    tmp2.y=right->y-vy;
    if(SideOfVector2D(side2,&tmp2)>0) {
      res=FALSE;
    }
    if(SideOfVector2D(side,&tmp2)<0) {
      res=FALSE;
    }
  }
  DestroyVector(side);
  DestroyVector(side2);
  return res;
}

Bool DoomClipLinedef(F64 fov,F64 vx,F64 vy,F64 angle,CDoomLinedef *ld,CD2 *left,CD2 *right) {
  if(_DoomClipLinedef(fov,vx,vy,angle,ld,left,right,FALSE))
    return TRUE;
  if(_DoomClipLinedef(fov,vx,vy,angle,ld,left,right,TRUE))
    return TRUE;
  return FALSE;
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

U0 DrawBSPNode(CDC *dc,I64 x,I64 y,CDoomBSPNode *node,F64 scale) {
  dc->color=LTGREEN;
  GrDrawBBox(dc,x+node->left.x*scale,y+node->left.y*scale,
        x+node->left.x2*scale,y+node->left.y2*scale);
  dc->color=LTRED;
  GrDrawBBox(dc,x+scale*node->right.x,y+scale*node->right.y,
        x+scale*node->right.x2,y+scale*node->right.y2);
  dc->color=PURPLE;
  GrArrow3(dc,node->x*scale+x,node->y*scale+y,0,
        (node->x+node->dx)*scale+x,(node->y+node->dy)*scale+y,0);
}

U0 DrawLevelOverview(CDoomLevel *level,CDC *dc=gr.dc,F64 scale=1,U8 show_bsp=TRUE) {
  DCFill;
  F64 fov=45*pi/180;
  CD2 left,right;
  CDoomBSPNode *node,*cur_bsp_node;
  CDoomLinedef *wall,*head=&level->linedefs;
  CDoomSubsector *ss;
  CDoomSeg *s;
  dc->color=RED;
  dc->thick=2;
  I64 x=GR_WIDTH/2,y=GR_HEIGHT/2+300,idx;
  for(wall=head->next;wall!=head;wall=wall->next) {
    if(DoomClipLinedef(fov,(ms.pos.x-x)/scale,(ms.pos.y-y)/scale,tS,wall,&left,&right))
      GrLine3(dc,
	  x+left.x*scale,y+left.y*scale,0,
	  x+right.x*scale,y+right.y*scale,0
	  );
  }
  if(show_bsp) {
    head=&level->bsp_nodes;
    cur_bsp_node=DoomWhichBSPNode((ms.pos.x-x)/scale,(ms.pos.y-y)/scale,level,&ss);
    dc->thick=1;
    for(node=head->next;node!=head;node=node->next) {
      if(node==cur_bsp_node) {
        dc->thick=3;
      } else 
        dc->thick=1;
      DrawBSPNode(dc,x,y,node,scale);
      if(ss) {
	dc->color=YELLOW;
        s=ss->first;
        for(idx=0;idx!=ss->cnt;idx++) {
	  GrLine3(dc,s->x*scale+x,s->y*scale+y,0,s->x2*scale+x,s->y2*scale+y,0);
	  s=s->next;
        }
      }
    }
  }
}

class CWadPnames {
  I32 len;
  U64 names[0];
};


I64 PNameIndex(U8 *name,CDoomGr *gr) {
  I64 idx=gr->pname_cnt;
  while(--idx>=0) {
    if(!StrCmp8(&gr->pnames[idx],name))
      return idx;
  }
  return -1;
}

CDoomGr *LoadWadGr(CWad *wad) {
  CDoomGr *ret=CAlloc(sizeof(CDoomGr));
  CWadDirectory *wad_dir;
  I64 idx;
  U8 lump_name[9];
  CWadPnames *pnames;
  CDC *gr;
//Load Player palett
  ret->palette=LoadPLAYPALFromLump(W_GetLumpPtrFromName("PLAYPAL",wad));
//Find the sprites start
  wad_dir=wad->body+wad->directory_ptr;
  wad_dir+=W_CheckNumForName("S_START",wad);
found_sstart:
  wad_dir++; //Move past S_START
  if(StrCmp8(wad_dir->lump_name,"S_END")) {
    gr=ReadDoomImage(wad,wad->body+wad_dir->ptr,ret->palette);
    lump_name[8]=0;
    MemCpy(lump_name,wad_dir->lump_name,8);
    FramePtrAdd(lump_name,gr);
#ifdef DEBUG
//    GrBlot(,0,0,gr);
//    Sleep(10);
#endif
    goto found_sstart;
  }
//Yeah homie,im straight up gunna load Flats. Take a moment to praise God
  wad_dir=wad->body+wad->directory_ptr;
  wad_dir+=W_CheckNumForName("F_START",wad);
found_fstart:
  wad_dir++; //Move past F_START
  if(StrCmp8(wad_dir->lump_name,"F_END")) {
//There are lumps like F1_START/F1_END/F2_START/F2_END
    //There are empty are are used for shareware/registered lumps
    if(wad_dir->lump_size) {
      gr=ReadDoomFlat(wad->body+wad_dir->ptr,ret->palette);
      lump_name[8]=0;
      MemCpy(lump_name,wad_dir->lump_name,8);
      FramePtrAdd(lump_name,gr);
#ifdef DEBUG
//      GrBlot(,0,0,gr);
//      Sleep(10);
#endif
    }
    goto found_fstart;
  }
//Load Wall Patch names
  wad_dir=wad->body+wad->directory_ptr;
  wad_dir+=W_CheckNumForName("PNAMES",wad);
found_pnames:
  pnames=wad->body+wad_dir->ptr;
  ret->pname_cnt=pnames->len;
  ret->pnames=MAlloc(ret->pname_cnt*8);
  MemCpy(ret->pnames,pnames->names,ret->pname_cnt*8);
//Load wall patches
  wad_dir=wad->body+wad->directory_ptr;
  wad_dir+=W_CheckNumForName("P_START",wad);
found_pstart:
  wad_dir++; //Move past S_START
  if(StrCmp8(wad_dir->lump_name,"P_END")) {
//There are lumps like P1_START/P1_END/P2_START/P2_END
    //There are empty are are used for shareware/registered lumps
    if(wad_dir->lump_size) {
      lump_name[8]=0;
      MemCpy(lump_name,wad_dir->lump_name,8);
      gr=ReadDoomImage(wad,wad->body+wad_dir->ptr,ret->palette);
#ifdef DEBUG
//      GrBlot(,0,0,gr);
//      Sleep(10);
#endif
      FramePtrAdd(lump_name,gr);
    }
    goto found_pstart;
  }
  LoadWadTEXTUREs(W_GetLumpPtrFromName("TEXTURE1",wad),ret);
  if(W_GetLumpPtrFromName("TEXTURE2",wad)>=0)
    LoadWadTEXTUREs(W_GetLumpPtrFromName("TEXTURE2",wad),ret);
  return ret;
}

CDoomLevel *LoadWadLevel(CWad *wad,U8 *level_name) {
  I64 idx,cnt;
  U8 name[9];
  CDoomLevel *level=CAlloc(sizeof CDoomLevel);
  CDoomThing *dthing;
  CWadThing *wthing;
  CWadVertex *vertex;
  CWadDirectory *wad_dir;
  CWadBSPNode *wnode;
  CDoomBSPNode *dnode,**dnode_list;
  CWadLinedef *wlinedef;
  CDoomLinedef *dlinedef,**dlinedef_list;
  CDoomSubsector *dss,**sslist;
  CWadSubsector *wss;
  CWadSeg *wseg;
  CDoomSeg *dseg,**dseg_list;
  CWadSector *wsect;
  CDoomSector **dsect_list,*dsect;
  CWadSidedef *wside;
  CDoomSidedef *dside,**dside_list;
  QueInit(&level->sidedefs);
  QueInit(&level->sectors);
  QueInit(&level->things);
  QueInit(&level->linedefs);
  QueInit(&level->bsp_nodes);
  QueInit(&level->subsectors);
  QueInit(&level->segs);
  name[8]=0;
  wad_dir=wad->body+wad->directory_ptr;
  for(idx=0;idx!=wad->lump_cnt;idx++) {
    if(!StrCmp8(wad_dir->lump_name,level_name))
      goto found;
    wad_dir++;
  }
  Free(level);
  return NULL;
found:
//Order of other lumps is important
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
//SIDEDEFS
  cnt=wad_dir[2].lump_size/sizeof(CWadSidedef);
  wside=wad_dir[2].ptr+wad(U8*);
  dside_list=MAlloc(8*cnt);
  if(StrCmp8("SIDEDEFS",wad_dir[2].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dside=CAlloc(sizeof CDoomSidedef);
    dside->xoff=wside->x_offset;
    dside->yoff=wside->y_offset;
    name[8]=0;
    MemCpy(name,wside->middle_texture_name,8);
    dside->middle_texture=FramePtr(name);
    MemCpy(name,wside->upper_texture_name,8);
    dside->upper_texture=FramePtr(name);
    MemCpy(name,wside->lower_texture_name,8);
    dside->lower_texture=FramePtr(name);
    dside_list[idx]=dside;
    wside++;
  }  
//LINEDEFS
  cnt=wad_dir[1].lump_size/sizeof(CWadLinedef);
  wlinedef=wad_dir[1].ptr+wad(U8*);
  dlinedef_list=CAlloc(8*cnt);
  if(StrCmp8("LINEDEFS",wad_dir[1].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dlinedef=CAlloc(sizeof(CDoomLinedef));
    dlinedef->start=wlinedef->start_vertex+level->vertices;
    dlinedef->end=wlinedef->end_vertex+level->vertices;
    if(wlinedef->front!=-1)
      dlinedef->front=dside_list[wlinedef->front];
    if(wlinedef->front!=-1)
      dlinedef->back=dside_list[wlinedef->back];
    dlinedef_list[idx]=dlinedef;
    QueIns(dlinedef,level->linedefs.last);
    wlinedef++;
  }
// Bsp NODES
  cnt=wad_dir[6].lump_size/sizeof(CWadBSPNode);
  wnode=wad_dir[6].ptr+wad(U8*);
  if(StrCmp8("NODES",wad_dir[6].lump_name)) throw('Wad');
  dnode_list=MAlloc(cnt*8);
  for(idx=0;idx!=cnt;idx++) {
    dnode=CAlloc(sizeof CDoomBSPNode);
    dnode->x=wnode->x;
    dnode->y=wnode->y;
    dnode->dx=wnode->dx;
    dnode->dy=wnode->dy;
    dnode->left.x=wnode->left.x;
    dnode->left.y=wnode->left.y;
    dnode->left.x2=wnode->left.x2;
    dnode->left.y2=wnode->left.y2;
    dnode->right.x=wnode->right.x;
    dnode->right.y=wnode->right.y;
    dnode->right.x2=wnode->right.x2;
    dnode->right.y2=wnode->right.y2;
    dnode->signature='NODE';
    QueIns(dnode,&level->bsp_nodes);
    dnode_list[idx]=dnode;
    wnode++;
  } 
//Load SEGS first homie
  cnt=wad_dir[4].lump_size/sizeof(CWadSeg);
  wseg=wad_dir[4].ptr+wad(U8*);
  dseg_list=CAlloc(8*cnt);
  if(StrCmp8("SEGS",wad_dir[4].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dseg=CAlloc(sizeof CDoomSeg);
    dseg->x=level->vertices[wseg->start_vertex].x;
    dseg->y=level->vertices[wseg->start_vertex].y;
    dseg->x2=level->vertices[wseg->end_vertex].x;
    dseg->y2=level->vertices[wseg->end_vertex].y;
    dseg->linedef=dlinedef_list[wseg->linedef];
    dseg_list[idx]=dseg;
    QueIns(dseg,level->segs.last);
    wseg++;
  }  
// SSECTORS 
  cnt=wad_dir[5].lump_size/sizeof(CWadSubsector);
  wss=wad_dir[5].ptr+wad(U8*);
  sslist=CAlloc(cnt*8);
  if(StrCmp8("SSECTORS",wad_dir[5].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dss=CAlloc(sizeof(CDoomSubsector));
    QueIns(dss,&level->subsectors);
    dss->signature='SSECTOR';
    dss->cnt=wss->cnt;
    dss->first=dseg_list[wss->first];
    sslist[idx]=dss;
    wss++;
  }
//Redo again,look for child nodes
  wnode=wad_dir[6].ptr+wad(U8*);
  cnt=wad_dir[6].lump_size/sizeof(CWadBSPNode);
  for(idx=0;idx!=cnt;idx++) {
    if(!(wnode->left_child&(1<<15))) {
      dnode_list[idx]->left_child=dnode_list[wnode->left_child&(1<<15-1)];
      dnode_list[idx]->left_child->parent=dnode_list[idx];
    } else {
//SSECTORS
      dnode_list[idx]->left_child=sslist[wnode->left_child&(1<<15-1)];
    }
    if(!(wnode->right_child&(1<<15))) {
      dnode_list[idx]->right_child=dnode_list[wnode->right_child&(1<<15-1)];
      dnode_list[idx]->right_child->parent=dnode_list[idx];
    } else {
//SSECTORS
      dnode_list[idx]->right_child=sslist[wnode->right_child&(1<<15-1)];
    }
    wnode++;
  }
  level->root_node=dnode_list[cnt-1];
//SECTORS
  cnt=wad_dir[7].lump_size/sizeof(CWadSector);
  wsect=wad_dir[7].ptr+wad(U8*);
  dsect_list=CAlloc(cnt*8);
  if(StrCmp8("SECTORS",wad_dir[7].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dsect=CAlloc(sizeof(CDoomSector));
    QueIns(dsect,&level->sectors);
    dsect->floor_height=wsect->floor_height;
    dsect->ceil_height=wsect->ceil_height;
    MemCpy(name,wsect->floor_texture_name,8);
    dsect->floor_dc=FramePtr(name);
    MemCpy(name,wsect->ceil_texture_name,8);
    dsect->ceil_dc=FramePtr(name);
    dsect->base_light_level=wsect->light_level;
    dsect->cur_light_level=wsect->light_level;
    dsect->special_type=wsect->special_type;
    dsect_list[idx]=dsect;
    wsect++;
  }
//SECTORS(2) Get all the linedefs for the sector
  cnt=wad_dir[1].lump_size/sizeof(CWadLinedef);
  wlinedef=wad_dir[1].ptr+wad(U8*);
  if(StrCmp8("LINEDEFS",wad_dir[1].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    AddLinedefToSector(
	dlinedef_list[idx],
	dsect_list[wlinedef->sector_tag]
	);
  }
//SECTORS(3) Get sidedefs for the sector
  cnt=wad_dir[2].lump_size/sizeof(CWadSidedef);
  wside=wad_dir[2].ptr+wad(U8*);
  for(idx=0;idx!=cnt;idx++) {
    dside_list[idx]->sector=dsect_list[wside->sector];
    wside++;
  }
  Free(dside_list);
  Free(dsect_list);
  Free(sslist);
  Free(dseg_list);
  Free(dnode_list);
  Free(dlinedef_list);
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
//DumpWad(wad);
CDoomGr *dgr=LoadWadGr(wad);
CDoomLevel *l=LoadWadLevel(wad,"E1M1");;
/*DCFill;
if(l)
  while(TRUE) {
    DrawLevelOverview(l,gr.dc,1/8.,FALSE);
    Refresh;
  }
*/
#endif
