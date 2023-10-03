#ifndef DOOM_WAD
#define DOOM_WAD" Whats Poppin"
#define DEBUG 1

#include "DoomGr.HC";
#include "Numbers/Vector.HC";
#include "World.HC";
#include "Things.HC";
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
  I16 x,y,angle;
  U16 thing_type,flags;
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
  U16 special_type;
  U16 sector_tag;
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
  I16 opposite_side,offset; 

};


class CWadSubsector {
//Consistys of SEGS
  I16 cnt;
  I16 first;
}; 

class CDoomThing:CQue {
  F64 x,y,angle,height;
  I16 thing_type,flags,pad[2];
  CDoomThingTemplate *template;
};
extern class CDoomSector;

class CDoomSidedef:CQue {
  I16 yoff,xoff;
  CDC *upper_texture[4]; //These are for animations
  CDC *lower_texture[4];
  CDC *middle_texture[4];
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
  Bool visited;
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
  union {
    I64 sector_tag;
    CDoomSector *tagged_sector;
  }
  I16 flags;
  CDoomActionSector *special_type;
  I16 pad[2];
//private
  CD2 clip_start,clip_end;
  Bool in_view;
};


class CDoomBSPSeg {
  CD2 *start,*end;
  CDoomLinedef *linedef;
  I64 size,offset;
  Bool same_side;
};

class CDoomSubsector:CQue {
  U64 signature;
  I64 cnt;
  CDoomBSPSeg *first;
};

class CDoomGr {
  CRGB *palette;
  I64 pname_cnt;
  U64 *pnames;
};

class CDoomSector:CQue {
  CDC *floor_dc[4];
  CDC *ceil_dc[4];
  F64 ceil_height;
  F64 floor_height;
  F64 base_ceil_height;
  F64 base_floor_height;
  F64 base_light_level,cur_light_level;
  I64 special_type;
  I64 linedef_cnt;
  CDoomLinedef **linedefs;
//Private
//I will render the floors then I will cast them to the screen
//I tried everything else but I just cant figure out how to draw the floors
  F64 shape_start_x,shape_start_y;
  CDC *shape_dc;
  CDoomLinedef *cur_action_linedef;
  Bool drawn,closing,opening,activated,waiting,pad[3];
  F64 wait_time;
  F64 speed;
  F64 start_tS;
};



class CDoomLevel {
  CQue things,sidedefs;
  CQue subsectors;
  CQue bsp_nodes;
  CDoomBSPSeg *segs;
  CQue sectors;
  CDoomBSPNode *root_node;
  I64 vertice_cnt;
  CD2 *vertices;
  CQue linedefs;
 I64 block_map_x_off,block_map_y_off;
  I64 block_map_cols,block_map_rows;
  I64 *block_map_offsets;
  CDoomSector **block_map_data;
  CDoomLinedef **action_linedefs;
  Bool has_red_key,has_blue_key,has_yellow_key;
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
  I64 texture,i,anim_cnt;
  U8 name[9];
  CDC *result,*patch;
  CWadTexture *map_texture;
  for(texture=0;texture!=header->num_textures;texture++) {
    map_texture=header(U8*)+header->texture_offsets[texture];
    result=DCNew(map_texture->w*2,map_texture->h*2);
    DCFill(result,TRANSPARENT);
    name[8]=0;
    MemCpy(name,map_texture->name,8);
    for(i=0;i!=map_texture->patch_cnt;i++) {
      if(patch=PNameIndexToDC(map_texture->patches[i].patch_index,gr))
      GrBlot(result,
	map_texture->patches[i].origin_x*2,
	map_texture->patches[i].origin_y*2,
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


// Patches.
// A patch holds one or more columns.
// Patches are used for sprites and all masked pictures,
// and we compose textures from the TEXTURE1/2 lists
// of patches.
class patch_t 
{ 
    I32 width;		// bounding box size 
    I32 height; 
    I32 leftoffset;	// pixels to the left of origin 
    I32 topoffset;	// pixels below the origin 
    I64 columnofs[8];	// only [width] used
    // the [0] is &columnofs[width] 
};


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
      if(IsFrontSideOfVector2D(pline,&dummy)) {
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

U0 DrawLevelOverview(CDoomLevel *level,CDC *dc=gr.dc,F64 scale=1,U8 show_bsp=TRUE,F64 dude_x,F64 dude_y) {
  DCFill;
  F64 fov=45*pi/180;
  CD2 left,right;
  CDoomBSPNode *node,*cur_bsp_node;
  CDoomLinedef *wall,*head=&level->linedefs;
  CDoomSubsector *ss;
  CDoomBSPSeg *s;
  dc->color=RED;
  dc->thick=2;
  I64 x=GR_WIDTH/2,y=GR_HEIGHT/2+300,idx;
  for(wall=head->next;wall!=head;wall=wall->next) {
/*    if(DoomClipLinedef(fov,(ms.pos.x-x)/scale,(ms.pos.y-y)/scale,tS,wall,&left,&right))
      GrLine3(dc,
	  x+left.x*scale,y+left.y*scale,0,
	  x+right.x*scale,y+right.y*scale,0
	  );*/
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
	  GrLine3(dc,s->start->x*scale+x,s->start->y*scale+y,0,s->end->x*scale+x,s->end->y*scale+y,0);
	  s++;
        }
      }
    }
  }
  dc->color=PURPLE;
  dc->thick=2;
  GrPlot3(dc,dude_x*scale+x,dude_y*scale+y,0);
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
    gr=ReadDoomImage(wad->body+wad_dir->ptr);
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
      gr=ReadDoomImage(wad->body+wad_dir->ptr);
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


Bool InBound(F64 a,F64 l,F64 h) {
  if(l<h)
    return l-.1<=a<=h+.1;
  return h-.1<=a<=l+.1;
}

F64 PassesThroughLineAtY(I64 x,CD2 *a,CD2 *b) {
  F64 slope;
  F64 res;
  if(a->x==b->x) {
    if(x==ToI64(a->x))
      return Max(a->y,b->y);
    return -1;
  }
  slope=(b->y-a->y)/(b->x-a->x);
  res=slope*(x-a->x)+a->y;
  if(InBound(x,a->x,b->x)&&InBound(res,a->y,b->y))
      return res;
  return -1;
}

U0 GenerateSectorShape(CDoomSector *s) {
  I64 max_x=I16_MIN,max_y=I16_MIN;
  I64 min_x=I16_MAX,min_y=I16_MAX;
  I64 x,y;
  I64 maxy,new_maxy,tmp;
  I64 cnt,side,ix,iy,choose_idx;
  CDoomLinedef **array=CAlloc(s->linedef_cnt*8);
  CDC **arr;
  CD2 p1,p2;
  Bool odd;
  for(cnt=0;cnt!=s->linedef_cnt;cnt++) {
    for(side=0;side!=2;side++) {
      if(side) {
        x=s->linedefs[cnt]->start->x;
        y=s->linedefs[cnt]->start->y;
      } else {
        x=s->linedefs[cnt]->end->x;
        y=s->linedefs[cnt]->end->y;
      }
      max_x=MaxI64(max_x,x);
      max_y=MaxI64(max_y,y);
      min_x=MinI64(min_x,x);
      min_y=MinI64(min_y,y);
    }
  }
  s->shape_dc=DCNew((max_x-min_x+2)/2,(max_y-min_y+2)/2);
  DCFill(s->shape_dc,0);
  s->shape_dc->color=YELLOW;
  for(x=0;x<max_x-min_x+1;x+=2) {
    maxy=-1;
    odd=FALSE;
    for(ix=0;ix!=s->linedef_cnt;ix++)
      array[ix]=s->linedefs[ix];
loop:
    choose_idx=-1;
    new_maxy=s->shape_dc->height*2;
    for(cnt=0;cnt!=s->linedef_cnt;cnt++) {
      if(array[cnt]) {
        p1.x=s->linedefs[cnt]->start->x-min_x;
        p1.y=s->linedefs[cnt]->start->y-min_y;
        p2.x=s->linedefs[cnt]->end->x-min_x;
        p2.y=s->linedefs[cnt]->end->y-min_y;
        tmp=PassesThroughLineAtY(x,&p1,&p2);
        if(tmp!=-1) {
	  if(tmp>maxy&&tmp<new_maxy) {
	    choose_idx=cnt;
	    new_maxy=tmp;
	  }
        }
      }
    }
    odd=!odd;
    if(choose_idx!=-1) {
      if(!odd) GrVLine(s->shape_dc,x/2,maxy/2,new_maxy/2);
      array[choose_idx]=NULL;
      maxy=new_maxy;
      goto loop;
    }
    if(!odd) GrVLine(s->shape_dc,x/2,maxy/2,s->shape_dc->height);
  }
//Artifact reduction,any 1 pixel that is lone in a row,remove it
  for(y=0;y!=s->shape_dc->height;y++)
    for(x=1;x<s->shape_dc->width-1;x++) {
       if(GrPeek0(s->shape_dc,x,y)) {
         if(!GrPeek0(s->shape_dc,x-1,y)&&!GrPeek0(s->shape_dc,x+1,y)) {
	   s->shape_dc->color=BLACK;
	   GrPlot0(s->shape_dc,x,y);
	 }
       } else {
         if(GrPeek0(s->shape_dc,x-1,y)&&GrPeek0(s->shape_dc,x+1,y)) {
	   s->shape_dc->color=YELLOW;
	   GrPlot0(s->shape_dc,x,y);
         }
       }
    }
  s->shape_start_x=min_x;
  s->shape_start_y=min_y;
  Free(array);
}

class CWadBlockMapHeader {
  I16 x_off,y_off;
  I16 num_cols,num_rows;
};

CDoomLevel *LoadWadLevel(CWad *wad,U8 *level_name) {
  I64 idx,cnt,x,y,min,max;
  U16 *offs;
  U8 name[9];
  CDC **arr;
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
  CDoomBSPSeg *dseg,*dseg_list;
  CWadSector *wsect;
  CDoomSector **dsect_list,*dsect;
  CWadSidedef *wside;
  CDoomSidedef *dside,**dside_list;
  CWadBlockMapHeader *wbmh;
  QueInit(&level->sidedefs);
  QueInit(&level->sectors);
  QueInit(&level->things);
  QueInit(&level->linedefs);
  QueInit(&level->bsp_nodes);
  QueInit(&level->subsectors);
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
    dthing->template=doom_thing_types[wthing->thing_type];
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
    dside->middle_texture[0]=FramePtr(name);
    MemCpy(name,wside->upper_texture_name,8);
    dside->upper_texture[0]=FramePtr(name);
    MemCpy(name,wside->lower_texture_name,8);
    dside->lower_texture[0]=FramePtr(name);
//https://doomwiki.org/wiki/Animated_wall
    for(x=0;x!=3;x++) {
      switch(x) {
	  break;case 0:
	  arr=dside->middle_texture;
	  MemCpy(name,wside->middle_texture_name,8);
	  break;case 1:
	  arr=dside->upper_texture;
	  MemCpy(name,wside->upper_texture_name,8);
	  break;case 2:
	  arr=dside->lower_texture;
	  MemCpy(name,wside->lower_texture_name,8);
      }
      if(!StrNCmp(name,"BLODGR1",5)) {
	arr[0]=FramePtr("BLODGR1");
        arr[1]=FramePtr("BLODGR2");
        arr[2]=FramePtr("BLODGR3");
        arr[3]=FramePtr("BLODGR4");
      }
      if(!StrNCmp(name,"BLODRIP1",7)) {
	arr[0]=FramePtr("BLODRIP1");
        arr[1]=FramePtr("BLODRIP2");
        arr[2]=FramePtr("BLODRIP3");
        arr[3]=FramePtr("BLODRIP4");
      }
      if(!StrNCmp(name,"FIREBLU1",7)) {
	arr[0]=FramePtr("FIREBLU1");
        arr[1]=FramePtr("FIREBLU2");
      }
      if(!StrNCmp(name,"FIRELAV3",7)) {
	arr[0]=FramePtr("FIRELAVA3");
        arr[1]=FramePtr("FIRELAVA");
      }
      if(!StrNCmp("FIREMAG1",name,7)) {
	arr[0]=FramePtr("FIREMAG1");
        arr[1]=FramePtr("FIREMAG2");
        arr[2]=FramePtr("FIREMAG3");
      }
      if(!StrNCmp("FIREWALA",name,7)) {
	arr[0]=FramePtr("FIREMALA");
        arr[1]=FramePtr("FIREWALB");
        arr[2]=FramePtr("FIREWALL");
      }
      if(!StrNCmp("GSTFONT1",name,7)) {
	arr[0]=FramePtr("GSTFONT1");
        arr[1]=FramePtr("GSTFONT2");
        arr[2]=FramePtr("GSTFONT3");
      }
      if(!StrNCmp("ROCKRED1",name,7)) {
	arr[0]=FramePtr("ROCKRED1");
        arr[1]=FramePtr("ROCKRED2");
        arr[2]=FramePtr("ROCKRED3");
      }
      if(!StrNCmp("SLADRIP1",name,7)) {
	arr[0]=FramePtr("SLADRIP1");
        arr[1]=FramePtr("SLADRIP2");
        arr[2]=FramePtr("SLADRIP3");
      }
    }
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
    dlinedef->sector_tag=wlinedef->sector_tag;
    dlinedef->flags=wlinedef->flags;
    dlinedef->special_type=action_sector_types[wlinedef->special_type];
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
  dseg_list=level->segs=CAlloc(sizeof(CDoomBSPSeg)*cnt);
  if(StrCmp8("SEGS",wad_dir[4].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    dseg=&dseg_list[idx];
    dseg->start=&level->vertices[wseg->start_vertex];
    dseg->end=&level->vertices[wseg->end_vertex];
    dseg->linedef=dlinedef_list[wseg->linedef];
    dseg->offset=wseg->offset;
    dseg->same_side=!wseg->opposite_side;
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
    dss->first=&level->segs[wss->first];
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
    dsect->base_floor_height=wsect->floor_height;
    dsect->base_ceil_height=wsect->ceil_height;
    MemCpy(name,wsect->floor_texture_name,8);
    dsect->floor_dc[0]=FramePtr(name);
    MemCpy(name,wsect->ceil_texture_name,8);
    dsect->ceil_dc[0]=FramePtr(name);
//https://doomwiki.org/wiki/Animated_flat
    for(x=0;x!=2;x++) {
      switch(x) {
	  break;case 0:
	  arr=dsect->floor_dc;
	  MemCpy(name,wsect->floor_texture_name,8);
	  break;case 1: 
	  arr=dsect->ceil_dc;
	  MemCpy(name,wsect->ceil_texture_name,8);
      }
      if(!StrNCmp(name,"NUKAGE",5)){
        arr[0]=FramePtr("NUKAGE1");
        arr[1]=FramePtr("NUKAGE2");
        arr[2]=FramePtr("NUKAGE3");
        arr[3]=FramePtr("NUKAGE4");
      }
      if(!StrNCmp(name,"FWATER",6)){
        arr[0]=FramePtr("FWATER1");
        arr[1]=FramePtr("FWATER2");
        arr[2]=FramePtr("FWATER3");
        arr[3]=FramePtr("FWATER4");
      }
      if(!StrNCmp(name,"LAVA",4)){
        arr[0]=FramePtr("LAVA1");
        arr[1]=FramePtr("LAVA2");
        arr[2]=FramePtr("LAVA3");
        arr[3]=FramePtr("LAVA4");
      }
      if(!StrNCmp(name,"BLOOD",5)){
        arr[0]=FramePtr("BLOOD1");
        arr[1]=FramePtr("BLOOD2");
        arr[2]=FramePtr("BLOOD3");
      }
    }
    dsect->base_light_level=wsect->light_level;
    dsect->cur_light_level=wsect->light_level;
//    dsect->special_type=action_sector_types[wsect->special_type];
    dsect_list[idx]=dsect;
    wsect++;
  }
//SECTORS(2) Get sidedefs for the sector
  cnt=wad_dir[2].lump_size/sizeof(CWadSidedef);
  wside=wad_dir[2].ptr+wad(U8*);
  for(idx=0;idx!=cnt;idx++) {
    dside_list[idx]->sector=dsect_list[wside->sector];
    wside++;
  }
//SECTORS(3) Get all the linedefs for the sector,also assign sectors based on tag
  cnt=wad_dir[1].lump_size/sizeof(CWadLinedef);
  wlinedef=wad_dir[1].ptr+wad(U8*);
  if(StrCmp8("LINEDEFS",wad_dir[1].lump_name)) throw('Wad');
  for(idx=0;idx!=cnt;idx++) {
    if(dlinedef_list[idx]->front) {
      AddLinedefToSector(
	    dlinedef_list[idx],
	    dlinedef_list[idx]->front->sector,
	    );
    }
    if(dlinedef_list[idx]->back) {     
      AddLinedefToSector(
	    dlinedef_list[idx],
	    dlinedef_list[idx]->back->sector,
	    );
    }
    if(dlinedef_list[idx]->sector_tag!=0xffff)
      dlinedef_list[idx]->sector_tag=dsect_list[dlinedef_list[idx]->sector_tag];
  }
//SECTORS(4) Generate sectors shapes
  cnt=wad_dir[7].lump_size/sizeof(CWadSector);
  for(idx=0;idx!=cnt;idx++)
    GenerateSectorShape(dsect_list[idx]);
//BLOCKMAP
  wbmh=wad_dir[9].ptr+wad(U8*);
  if(StrCmp8("BLOCKMAP",wad_dir[9].lump_name)) throw('Wad');
  cnt=wbmh->num_cols*wbmh->num_rows;
  offs=wbmh+1;
  level->block_map_y_off=wbmh->y_off;
  level->block_map_x_off=wbmh->x_off;
  level->block_map_offsets=MAlloc(8*cnt);
  level->block_map_cols=wbmh->num_cols;
  level->block_map_rows=wbmh->num_rows;
  for(x=0;x!=wbmh->num_cols;x++) {
    for(y=0;y!=wbmh->num_rows;y++) {
//These pooparoos are relatvie the the BLOCKMAP header,so get rid of the header/offsets poop
      idx=(offs[x+y*wbmh->num_cols]*2-sizeof(CWadBlockMapHeader)-2*cnt)/2;
      level->block_map_offsets[x+y*wbmh->num_cols]=idx;
    }
  }
  offs+=cnt;
  cnt=(wad_dir[9].lump_size-sizeof(CWadBlockMapHeader)-cnt*sizeof(I16))/sizeof(I16);
  level->block_map_data=MAlloc(8*cnt);
  while(--cnt>=0) {
    if(offs[cnt]==0xFFFF)
      level->block_map_data[cnt]=NULL;
    else
      level->block_map_data[cnt]=dlinedef_list[offs[cnt]];
  }
  Free(sslist);
  Free(dside_list);
  Free(dsect_list);
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

//
CDoomGr *dgr=LoadWadGr(wad);
CDoomLevel *l=LoadWadLevel(wad,"E1M1");;

/*
DCFill;
if(l)
  while(TRUE) {
    DrawLevelOverview(l,gr.dc,1/8.,TRUE);
    Refresh;
  }
*/
#endif
