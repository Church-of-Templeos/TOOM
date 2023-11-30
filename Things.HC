#ifndef MONSTER_GR
#define MONSTER_GR "Pushin P"
//https://doomwiki.org/wiki/Thing_types
#define THINGS_FILE "ThingProps.TXT"

class CDoomAnimationFrame {
  U8 chr,pad[7];
  CDC *faces[8];
  Bool reflect[8];
};

class CDoomThingTemplate {
  U8 spr_base_name[4],pad[4];
  U8 *animation;
  CDoomAnimationFrame *_animation;
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

class CDoomProjectileTemplate:CDoomThingTemplate {
  CDoomAnimationFrame *_idle_frames;
  CDoomAnimationFrame *_hit_frames;
  F64 direct,splash,speed;
};
class CDoomMonsterTemplate:CDoomThingTemplate {
  F64 x,y,angle,pain_chance,pain_time,reaction_time;
  F64 damage;
  F64 health,speed,mass,skull_attack_speed;
//These P Pushers are used with FramePtr("state name");
//See CState Enemy.HC
  U8 *spawn_state;
  U8 *see_state;
  U8 *pain_state;
  U8 *melee_state;
  U8 *missile_state;
  U8 *death_state;
  U8 *gib_state; 
//These are NULL terminated
  CDoomAnimationFrame *_idle_frames;
  CDoomAnimationFrame *_chase_frames;
  CDoomAnimationFrame *_attack_frames;
  CDoomAnimationFrame *_melee_frames;
  CDoomAnimationFrame *_hurt_frames;
  CDoomAnimationFrame *_dying_frames;
  CDoomAnimationFrame *_gib_frames;
};

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

U0 ParseThingProps() {
  MemSet(&doom_thing_types,0,8*0x10000);
  CDoomThingTemplate *template;
  U8 *fbuf=FileRead(THINGS_FILE),*line,*o=fbuf;
  U8 flags[STR_LEN],version[STR_LEN],desc[STR_LEN],sprite[STR_LEN],ani[STR_LEN];
  U8 *flagsp,*versionp,*descp,*spritep,*anip;
  I64 dec,hex;
  I64 radius,height;
  StrUtil(fbuf,SUF_REM_CTRL_CHARS); //Remove the poop CH_CURSOR
  while(line=ReadALine(&fbuf)) {
    if(line[0]=='#'||line[0]=='\n'||!StrLen(line))
      goto skip;
    versionp=&version;
    spritep=&sprite;
    anip=&ani;
    flagsp=&flags;
    descp=&desc;
    StrScan(line,"%d\t%X\t%s\t%d\t%d\t%s\t%s\t%s\t%s\n",
	  &dec,
	  &hex,
	  &versionp,
	  &radius,
	  &height,
	  &spritep,
	  &anip,
	  &flagsp,
	  &descp
	  );
    if(StrOcc(version,'2'))
      goto skip;
    template=CAlloc(sizeof CDoomMonsterTemplate);
    MemCpy(template->spr_base_name,sprite,4);
    template->radius=radius;
    template->height=height;
    template->animation=StrNew(ani);
    template->type=dec;
    for(flagsp=flags;*flagsp;flagsp++) {
      switch(*flagsp) {
        case 'A':
	  template->flags|=TF_ARTIFACT;
	  break;
        case 'P':
	  template->flags|=TF_POWERUP;
	  break;
        case 'W':
	  template->flags|=TF_WEAPON;
	  break;
        case 'M':
	  template->flags|=TF_MONSTER;
	  break;
        case 'O':
	  template->flags|=TF_OBSTACLE;
	  break;
        case '*':
	  template->flags|=TF_SHOOTABLE;
	  break;
        case '^':
PrintI("&",dec);
	  template->flags|=TF_FLOATING;
	  break;
      }
    }
    doom_thing_types[dec]=template;
skip:
    Free(line);
  }
  Free(o);
}
CDC *_GetThingFaceSprite(CDoomThingTemplate *template,F64 angle,U8 ani_frame='A',Bool *reflect=NULL) {
  I64 face=1,try_face;
  F64 gap_inc=2.*pi/8.,gap;
  CDC *ret=NULL;
  angle=Wrap(angle,0);
  if(reflect) *reflect=FALSE;
  for(gap=-gap_inc/2;gap<=2*pi;gap+=gap_inc) {
    if(gap<=angle<=gap+gap_inc)
      break;
    face++;
  }
  U8 buttplate[9];
  buttplate[8]=0;
  MemCpy(buttplate,template->spr_base_name,4);
  buttplate[4]=ani_frame;
//TROO[frame]0 //All roations
  buttplate[5]='0';
  buttplate[6]=0;
  if(ret=FramePtr(buttplate))
    return ret;
//TROO[frame][rotaionface]
  buttplate[5]='0'+face;
  if(ret=FramePtr(buttplate))
    return ret;
//TROO[frame][rotaionface][frame][reflected_face]
  buttplate[6]=ani_frame;
  for(try_face=0;try_face!=9;try_face++) {
    buttplate[7]=try_face+'0';
    if(ret=FramePtr(buttplate)) {
       if(reflect) *reflect=TRUE;
       return ret;
    }
  }
//Try opposite order
  buttplate[7]='0'+face;
  for(try_face=0;try_face!=9;try_face++) {
    buttplate[5]=try_face+'0';
    if(ret=FramePtr(buttplate)) {
       return ret;
    }
  }
  return NULL; 
}
static CDoomAnimationFrame *GenerateCacheFrames(CDoomThingTemplate *t,U8 *frames) {
  if(!frames) return NULL;
  I64 cnt=StrLen(frames);
  CDoomAnimationFrame *ret=CAlloc(sizeof(CDoomAnimationFrame)*(cnt+1));
  F64 angle;
  CDC *last_dc;
  Bool last_reflect;
  I64 face,idx,idx2;
  for(idx=0,idx2=0;idx2!=cnt;idx2++)  {
    if(!Bt(char_bmp_alpha,frames[idx2]))
      goto skip;
    ret[idx].chr=frames[idx2];
    for(angle=0,face=0;angle<=2*pi+.1&&face<8;angle+=2*pi/8.,face++) {
      last_dc=_GetThingFaceSprite(t,angle,frames[idx2],&ret[idx].reflect[face]);
      ret[idx].faces[face]=last_dc;
    }
    //Fill in "missing" faces
    for(face=1;face!=8;face++) {
      if(ret[idx].faces[face]) {
	last_dc=ret[idx].faces[face];
	last_reflect=ret[idx].reflect[face];
      } else
        ret[idx].faces[face]=last_dc,ret[idx].reflect[face]=last_reflect;
    }
    idx++;
skip:;
  }
  return ret;
}
F64 AnimationTime(CDoomAnimationFrame *f) {
  if(!f) return 0.;
  I64 frame_cnt=0;
  while(f[frame_cnt].chr)
    frame_cnt++;
  return frame_cnt*1/4.;
}

U0 _CacheAnimationFrames(CDoomThingTemplate *t) {
  t->_animation=GenerateCacheFrames(t,t->animation);
}
U0 CacheAnimationFrames() {
  I64 i=0;
  static I64 init=0;
  if(init)  return;
  init=1;
  for(i=0;i!=0x10000;i++)
    if(doom_thing_types[i])
      _CacheAnimationFrames(doom_thing_types[i]);
}
ParseThingProps;
#endif