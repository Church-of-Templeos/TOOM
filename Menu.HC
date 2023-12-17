#ifndef MENU
#define MENU "poop"
extern U0 PlayLevel();
class CMenuItem {
  U64 value;
  CDC *gr;
  I16 state; //-1 for end
  I16 x,y;
  U8 name[29];
  U8 hot_key;
};
CMenuItem **active_menu=NULL;
I64 active_menu_item=0;
//Free this
CMenuItem *CreateMenu(...) {
  CMenuItem *ret=CAlloc(sizeof(CMenuItem)*(1+argc/3));
  I64 idx;
  for(idx=0;idx<argc/3;idx++) {
    StrCpy(ret[idx].name,argv[idx*3]);
    ret[idx].hot_key=argv[idx*3+2];
    ret[idx].value=argv[idx*3+1];
  }
  ret[idx].state=-1;
  return ret;
}
U0 MenuDraw(CDC *dc,CMenuItem *items,I64 offx,I64 offy,I64 cur_active=0) {
  if(!items) return 0;
  CDC *skull;
  I64 x,y;
  I64 h=0,basey;
  I64 cnt=0,idx;
  h=offy*2;
  for(idx=0;items[idx].state!=-1;idx++) {
    skull=GetGrLump(items[idx].name);
    items[idx].gr=skull;
    items[idx].x=offx*2;
    items[idx].y=h;
    h+=20+skull->height;
    cnt++;
  }
  if(Blink)
    skull=GetGrLump("M_SKULL1");
  else
    skull=GetGrLump("M_SKULL2");
  for(idx=0;idx!=cnt;idx++) {
    GrBlot(dc,items[idx].x,items[idx].y,items[idx].gr);
    if(cur_active==idx) {
      x=items[idx].x-skull->width-10;
      y=items[idx].y+items[idx].gr->height/2-skull->height/2;
      GrBlot(dc,x,y,skull);
    }
  }
}
U64 MenuInteract(CDC *dc,CMenuItem *items,I64 offx,I64 offy) {
  if(!items) return 0;
  static U8 *old_items=NULL;
  if(old_items!=items) {
    old_items=items;
    active_menu_item=0;
  }
  I64 code=INVALID_PTR;
  I64 cur_active=active_menu_item;
  CDC *skull;
  I64 a,b;
  I64 msx=ms.pos.x;
  I64 msy=ms.pos.y;
  I64 cnt=0,idx;
  I64 x,y;
//Update items gr properites
  MenuDraw(dc,items,offx,offy,cur_active);
  for(idx=0;items[idx].state!=-1;idx++)
    cnt++;
retry:
    switch(ScanMsg(&a,&b)) {
      case 0:
	break;
      start:
        msx=ms.pos.x;
        msy=ms.pos.y;
        for(idx=0;idx!=cnt;idx++) {
	  y=items[idx].y;
	  if(y<=msy<=y+items[idx].gr->height) {
	    cur_active=idx;
	    break;
	  }
        }
        case MSG_MS_MOVE:
	  break;
        case MSG_MS_L_DOWN:
	  code=items[cur_active].value;
	  break;
      end:
        goto retry;  //try all events for frame
      case MSG_KEY_DOWN:
        if(b&0xff==SC_CURSOR_UP&&cur_active>0) {
	  cur_active--;
        } else if(b&0xff==SC_CURSOR_DOWN&&cur_active+1<cnt) {
	  cur_active++;
        } else if(a=='\n') {
	  code=items[cur_active].value;
        } else if(a==CH_ESC) {
	  code=0;
          FlushMsgs;
          goto fin;
	} else {
          for(idx=0;idx!=cnt;idx++) {
	    if(items[idx].hot_key==a)
	      code=items[cur_active].value;
	  }
	}
      default:
        goto retry; //try all events for frame
    }
  if(code!=INVALID_PTR) {
    Spawn(&PlaySoundTask,"SWTCHN","snd",0,Fs);
    FlushMsgs;
    active_menu=NULL;
  }
  active_menu_item=cur_active;
  MenuDraw(dc,items,offx,offy,cur_active);
fin:
  return code;
}
U64 EpisodeMenu() {
  static CMenuItem *items=CreateMenu(
    "M_EPI1",'1','1',
    "M_EPI2",'2','2',
    "M_EPI3",'3','3',
    "M_EPI4",'4','4',
  );
  active_menu=items;
  return MenuInteract(gr.dc,items,48,63);
}
U64 NewGameMenu() {
  static CMenuItem *items=CreateMenu(
    "M_JKILL",'1','i',
    "M_ROUGH",'2','h',
    "M_HURT",'3','h',
    "M_ULTRA",'4','u',
    "M_NMARE",'5','n',
  );
  active_menu=items;
  return MenuInteract(gr.dc,items,48,63);
}


U64 MainMenu() {
againm:;
  static I64 state=0,ep,s;
  static CMenuItem *items=CreateMenu(
        "M_NGAME",'NGAME','n',
        "M_LOADG",'LOADG','l',
        "M_SAVEG",'SAVEG','s',
        "M_RDTHIS",'RDTHIS','r',
        "M_QUITG",'QUITG','q'
        );
  U8 level[STR_LEN],next=FALSE;
  U64 r,a,b;
  CDC *dc;
  switch(state) {
    case 0:
      r=MenuInteract(gr.dc,items,97,67);
      if(r=='NGAME') {
        state=1;
      } else if(r=='LOADG') {
	LoadGame("/Poop");
      } else if(r=='SAVEG') {
	SaveGame("/Poop");
      } else if(r=='RDTHIS') {
        state=4;
      } else if(r=='QUITG') {
        DCFill;
        Exit;
      } else if(!r)
        return 0;
      break;
    case 1:
      ep=EpisodeMenu;
      if(ep&&ep!=INVALID_PTR) {
        state=2;
      } else if(!ep)
        state=0;
      break;
    case 2:
      s=NewGameMenu;
      if(s&&s!=INVALID_PTR) {
        state=0;
        StrPrint(level,"E%cM1",ep);
        if(l)
	  FreeLevel(l);
        active_menu=NULL;
        l=LoadWadLevel(wad,level,s-'1'+1);
//This will check if we are in a level,otherwise the world is just swapped with l
        PlayLevel;
        return 0;
      } else if(!s)
        state=1;
      break;
    start:
      switch(ScanMsg(&a,&b)) {
        case MSG_KEY_DOWN:
	  if(a=='\n')
	    next=TRUE;
	  else if(a==CH_ESC)
	    next=TRUE;
	  break;
        case MSG_MS_L_DOWN:
	  next=TRUE;
	  break;
      }
      case 4:
        dc=GetGrLump("HELP1");
        GrBlot(,0,0,dc);
        if(next) {
          state=5;
	  FlushMsgs;
	}
        break;
      case 5:
        dc=GetGrLump("HELP2");
        GrBlot(,0,0,dc);
        if(next) {
	  state=0;
	  FlushMsgs;
	}
        break;
    end:
      ;
  }
  return INVALID_PTR;
}