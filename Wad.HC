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

U0 DumpWad(CWad *wad) {
  I64 lump,ptr,lump_sz,ptr2;
  U8 *name;
DocMax;
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
      "\tANGLE:%n\n",(wad->body+ptr)(CWadThing*)->angle/ToF64(I16_MAX)*2*pi;
      "\tTYPE:%X\n",(wad->body+ptr)(CWadThing*)->thing_type;
    }
    ptr(CWadDirectory*)++;
  }
  
}
DumpWad(LoadWad("DOOM.WAD"));